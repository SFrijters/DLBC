// Written in the D programming language.

/**
   Lattice Boltzmann force and acceleration calculations.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
        TR = <tr>$0</tr>
        TH = <th>$0</th>
        TD = <td>$0</td>
        TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
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
   Array of interaction strength parameters for the Shan-Chen model.
   This array will be transformed into a square array, so the length
   should be equal to lb.components * lb.components.
*/
@("param") double[] gcc;

/**
   Array of interaction strength parameters for the Shan-Chen model
   to model wettable walls.
*/
@("param") double[] gwc;

/**
   Shan-Chen interaction strength parameters in matrix form.
*/
double[][] gccm;

/**
   Initialisation of the force systems. This should be run before the time loop starts.

   The forces to be applied to the fluids L.fluids are stored in L.force.

   Params:
     L = lattice
     conn = connectivity
*/
void initForce(T)(ref T L) if ( isLattice!T ) {
  import dlbc.parameters: checkArrayParameterLength;
  // Firstly, the acceleration vector is checked for length.
  alias conn = L.lbconn;
  checkArrayParameterLength(globalAcc, "lb.force.globalAcc", conn.d);

  // If the Shan-Chen model is enabled, some more prep is needed.
  if ( enableShanChen ) {
    // Again, we need to check the length of an array.
    // Shan-Chen model with only zero interaction strength is pointless, so there is
    // no default initialisation for this vector.
    checkArrayParameterLength(gcc, "lb.force.gcc", components*components, true);
    checkArrayParameterLength(gwc, "lb.force.gwc", components);

    // It's convenient to store the interaction strengths in matrix form, and
    // at this point we also show the matrix and warn for asymmetry if necessary.
    gccm.length = components;
    import std.string;
    string header = "Shan-Chen enabled - interaction matrix:\n\n         ";
    string lines;
    foreach(immutable i; 0..components ) {
      header ~= format("%8d ",i);
      lines ~= format("%8d ",i);
      gccm[i].length = components;
      foreach(immutable j; 0..components) {
        gccm[i][j] = gcc[i+j*components];
        lines ~= format("%8f ",gccm[i][j]);
        if ( i > j ) {
          if ( gccm[i][j] != gccm[j][i] ) {
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
void resetForce(T)(ref T L) {
  foreach(ref e; L.force) {
    e.initConst(0.0);
  }
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

   Params:
     L = lattice
     conn = connectivity

   Todo: add unittest.
*/
void addShanChenForce(T)(ref T L) if (isLattice!T) {
  if ( ! enableShanChen ) return;
  Timers.forceSC.start();
  alias conn = L.lbconn;
  immutable cv = conn.velocities;
  immutable cw = conn.weights;

  // It's actually faster to pre-calculate the densities, apparently...
  L.calculateDensity();

  // Do all combinations of two fluids.
  foreach(immutable nc1; 0..L.fluids.length ) {
    foreach(immutable nc2; 0..L.fluids.length ) {
      // This interaction has a particular coupling constant.
      immutable cc = gccm[nc1][nc2];
      // Skip zero interactions.
      if ( cc == 0.0 ) continue;
      foreach(immutable p, ref force ; L.force[nc1] ) {
        // Only do lattice sites on which collision will take place.
        if ( isCollidable(L.mask[p]) ) {
          immutable psiden1 = psi(L.density[nc1][p]);
          foreach(immutable i; Iota!(0, conn.q) ) {
            conn.vel_t nb;
            // Todo: better array syntax.
            foreach(immutable j; Iota!(0, conn.d) ) {
              nb[j] = p[j] - cv[i][j];
            }
            // Only do lattice sites that are not walls.
            immutable psiden2 = ( isBounceBack(L.mask[nb]) ? psi(L.density[nc2][p]) : psi(L.density[nc2][nb]));
            immutable prefactor = psiden1 * psiden2 * cc;
            // The SC force function.
            foreach(immutable j; Iota!(0, conn.d) ) {
              force[j] += prefactor * cv[i][j];
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
        immutable psiden1 = psi(L.density[nc1][p]);
        foreach(immutable i; Iota!(0, conn.q) ) {
          conn.vel_t nb;
          // Todo: better array syntax.
          foreach(immutable j; Iota!(0, conn.d) ) {
            nb[j] = p[j] - cv[i][j];
          }
          if ( isBounceBack(L.mask[nb]) ) {
            immutable prefactor = psiden1 * L.density[nc1][nb] * wc;
            // The SC force function.
            foreach(immutable j; Iota!(0, conn.d) ) {
              force[j] += prefactor * cv[i][j];
            }
          }
        }
      }
    }
  }
  Timers.forceSC.stop();
}

/**
   Default form for the Shan-Chen \(\Psi\) function: \(\Psi(\rho) = 1 - e^{-\rho}\).

   Params:
     den = density \(\rho\)

   Returns: \(\Psi(\rho)\).
*/
double psi(const double den) pure nothrow @safe {
  import std.math;
  return ( 1.0 - exp(-den) );
}

