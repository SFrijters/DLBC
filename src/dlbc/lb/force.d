// Written in the D programming language.

/**
   Lattice Boltzmann force and acceleration calculations.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

*/

module dlbc.lb.force;

import dlbc.lb.lb;
import dlbc.fields.init;
import dlbc.lattice;
import dlbc.logging;
import dlbc.range;
import dlbc.timers;

/**
   Global acceleration.
*/
@("param") double[] globalAcc;
/**
   Toggle Shan-Chen style interactions between fluids.
*/
@("param") bool enableShanChen;
/**
   Matrix of interaction strength parameters for the Shan-Chen model.
*/
@("param") double[][] gcc;
/**
   Array of interaction strength parameters for the Shan-Chen model
   to model wettable walls.
*/
@("param") double[] gwc;
/**
   Shape of the Shan-Chen \(\Psi\) function.
*/
@("param") PsiForm psiForm;

/**
   Possible forms of the Shan-Chen \(\Psi\) function.
*/
enum PsiForm {
  /**
     \(\Psi(\rho) = \rho\)
  */
  Linear,
  /**
     \(\Psi(\rho) = 1 - e^{-\rho}\)
  */
  Exponential,
}

/**
   Initialisation of the force systems. This should be run before the time loop starts.

   The forces to be applied to the fluids L.fluids are stored in L.force.

   Params:
     L = lattice
*/
void initForce(T)(ref T L) if ( isLattice!T ) {
  import dlbc.parameters: checkArrayParameterLength;
  import std.string: format;
  // Firstly, the acceleration vector is checked for length.
  alias conn = L.lbconn;
  checkArrayParameterLength(globalAcc, "lb.force.globalAcc", conn.d);

  // If the Shan-Chen model is enabled, some more prep is needed.
  if ( enableShanChen ) {
    // Again, we need to check the length of an array.
    // Shan-Chen model with only zero interaction strength is pointless, so there is
    // no default initialisation for this vector.
    checkArrayParameterLength(gcc, "lb.force.gcc", components, true);
    foreach(immutable i, ref g; gcc) {
      auto name = format("lb.force.gcc[%d]", i);
      checkArrayParameterLength(g, name, components, true);
    }
    checkArrayParameterLength(gwc, "lb.force.gwc", components);

    string header = "Shan-Chen enabled - interaction matrix:\n\n         ";
    string lines;
    foreach(immutable i; 0..components ) {
      header ~= format("%8d ",i);
      lines ~= format("%8d ",i);
      foreach(immutable j; 0..components) {
        lines ~= format("%8f ",gcc[i][j]);
        if ( i > j ) {
          if ( gcc[i][j] != gcc[j][i] ) {
            writeLogRW("Shan-Chen interaction not symmetric.");
          }
        }
      }
      lines ~= "\n";
    }
    writeLogRI(header ~ "\n" ~ lines);
  }

  // Because doubles are initialised as NaNs we set zeros here.
  L.resetForce();
}

/**
   Reset all force arrays L.force[] to zero.

   Params:
     L = lattice
*/
void resetForce(T)(ref T L) if (isLattice!T) {
  foreach(ref e; L.force) {
    e.initConst(0.0);
  }
  L.forceDistributed.initConst(0.0);
}

/**
   Forces saved into the $(D L.forceDistributed) array are distributed according to the 
   relative densities of the fluids on the lattice site.

   Params:
     L = lattice
*/
void distributeForce(T)(ref T L) if (isLattice!T) {
  startTimer("main.force.distr");
  foreach(immutable p, ref e; L.forceDistributed) {
    double totalDensity = 0.0;
    foreach(immutable i; 0..components ) {
      totalDensity += L.fluids[i][p].density();
    }
    foreach(immutable i; 0..components ) {
      foreach(immutable j; 0..L.lbconn.d ) {
        L.force[i][p][j] += L.forceDistributed[p][j] * ( L.fluids[i][p].density() / totalDensity );
      }
    }
  }
  stopTimer("main.force.distr");
}

/**
   Add the Shan-Chen force to force arrays L.force[].

   We calculate the force on $(D isCollidable) sites only.

   First, the fluid-fluid forces are calculated according to
   \(\vec{F}^c = - \Psi(\rho(\vec{x})) \sum_{c'} g_{cc'} \sum_{\vec{x}'} \Psi(\rho(\vec{x}'))(\vec{x} -\vec{x}')\),
   where \(c'\) runs over all fluid species and \(\vec{x}'\) runs over all connected fluid lattice sites.
   Note that self-interaction is possible if \(g_{cc} \ne 0\).

   Second, the fluid-wall forces are calculated according to
   \(\vec{F}^c = - \Psi(\rho(\vec{x})) g_{wc} \sum_{\vec{x}'} \rho(\vec{x}')(\vec{x} -\vec{x}')\),
   where \(c'\) runs over all fluid species and \(\vec{x}'\) runs over all connected wall lattice sites.
   Note that the effect of the psi-function are assumed to be adsorbed into the interaction strength
   and/or the density set on the wall. Currently, this density is unity always.

   The global parameter $(D psiForm) determines the shape of the \(\Psi\) function. To avoid runtime overhead
   a single switch statement passes a template parameter to the inner function.

   Params:
     L = lattice

   Todo: add unittest.
*/
void addShanChenForce(T)(ref T L) if (isLattice!T) {
  if ( ! enableShanChen ) return;
  startTimer("main.force.addSC");
  // Use a final switch here so we don't need to bother with a switch for psi in the inner loop later.
  final switch(psiForm) {
    case PsiForm.Linear:
      L.addShanChenForcePsi!(PsiForm.Linear)(gcc, gwc);
      break;
    case PsiForm.Exponential:
      L.addShanChenForcePsi!(PsiForm.Exponential)(gcc, gwc);
      break;
  }
  stopTimer("main.force.addSC");
}
/// Ditto
private void addShanChenForcePsi(PsiForm psiForm, T)(ref T L, in double[][] gcc, in double[] gwc) if (isLattice!T) {
  alias conn = L.lbconn;
  immutable cv = conn.velocities;
  immutable cw = conn.weights;

  // Need to assert this to make sure we can safely skip the zero component
  // in the loop [*] below.
  foreach(immutable vd; Iota!(0, conn.d) ) {
    assert(cv[0][vd] == 0);
  }

  // It's actually faster to pre-calculate the densities, apparently...
  L.calculateDensities();

  // Do all combinations of two fluids.
  foreach(immutable nc1; 0..L.fluids.length ) {
    foreach(immutable nc2; 0..L.fluids.length ) {
      // This interaction has a particular coupling constant.
      immutable cc = gcc[nc1][nc2];
      // Skip zero interactions.
      if ( cc == 0.0 ) continue;
      foreach(immutable p, ref force ; L.force[nc1] ) {
        // Only do lattice sites on which collision will take place.
        if ( isCollidable(L.mask[p]) ) {
          immutable psiden1 = psi!psiForm(L.density[nc1][p]);
          foreach(immutable vq; Iota!(1, conn.q - 1) ) { // [*]
            conn.vel_t nb;
            // Todo: better array syntax.
            foreach(immutable vd; Iota!(0, conn.d) ) {
              nb[vd] = p[vd] + cv[vq][vd];
            }
            // Only do lattice sites that are not walls.
            immutable psiden2 = ( isBounceBack(L.mask[nb]) ? psi!psiForm(L.density[nc2][p]) : psi!psiForm(L.density[nc2][nb]));
            immutable prefactor = cw[vq] * psiden1 * psiden2 * cc;
            // The SC force function.
            foreach(immutable vd; Iota!(0, conn.d) ) {
              force[vd] -= prefactor * cv[vq][vd];
            }
          }
        }
      }
    }

    // Wall interactions
    immutable wc = gwc[nc1];
    if ( wc == 0.0 ) continue;
    foreach(immutable p, ref force ; L.force[nc1] ) {
      // Only do lattice sites on which collision will take place.
      if ( isCollidable(L.mask[p]) ) {
        immutable psiden1 = psi!psiForm(L.density[nc1][p]);
        foreach(immutable vq; Iota!(0, conn.q) ) {
          conn.vel_t nb;
          // Todo: better array syntax.
          foreach(immutable vd; Iota!(0, conn.d) ) {
            nb[vd] = p[vd] + cv[vq][vd];
          }
          if ( isBounceBack(L.mask[nb]) ) {
            immutable prefactor = cw[vq] * psiden1 * L.density[nc1][nb] * wc;
            // The SC force function.
            foreach(immutable vd; Iota!(0, conn.d) ) {
              force[vd] -= prefactor * cv[vq][vd];
            }
          }
        }
      }
    }
  }
}

/**
   Shan-Chen \(\Psi\) functions: $(D PsiForm.Linear): \(\Psi(\rho) = \rho\), $(D PsiForm.Exponential): \(\Psi(\rho) = 1 - e^{-\rho}\).

   Params:
     psiForm = form of the function
     den = density \(\rho\)

   Returns: \(\Psi(\rho)\).
*/
double psi(PsiForm psiForm)(in double den) @safe pure nothrow @nogc {
  import std.math;

  static if ( psiForm == PsiForm.Linear ) {
    return den;
  }
  else static if ( psiForm == PsiForm.Exponential ) {
    return ( 1.0 - exp(-den) );
  }
  else {
    static assert(0);
  }
}

///
unittest {
  import std.math: approxEqual;
  double density = 0.0;
  assert(psi!(PsiForm.Linear)(density) == 0.0);
  assert(psi!(PsiForm.Exponential)(density) == 0.0);
  density = 0.7;
  assert(psi!(PsiForm.Linear)(density) == 0.7);
  assert(approxEqual(psi!(PsiForm.Exponential)(density), 0.5034146962) );
  density = 1.0;
  assert(psi!(PsiForm.Linear)(density) == 1.0);
  assert(approxEqual(psi!(PsiForm.Exponential)(density), 0.63212055882) );
  density = 2.0;
  assert(psi!(PsiForm.Linear)(density) == 2.0);
  assert(approxEqual(psi!(PsiForm.Exponential)(density), 0.86466471676) );
}

