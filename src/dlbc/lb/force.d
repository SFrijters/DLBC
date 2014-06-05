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
void initForce(alias conn, T)(ref T L) {
  import dlbc.parameters: checkVectorParameterLength;
  // Firstly, the acceleration vector is checked for length
  checkVectorParameterLength(globalAcc, "lb.force.globalAcc", conn.d);

  // If the Shan-Chen model is enabled, some more prep is needed.
  if ( enableShanChen ) {
    // Again, we need to check the length of a vector.
    // Shan-Chen model with only zero interaction strength is pointless, so there is
    // no default initialisation for this vector.
    checkVectorParameterLength(gcc, "lb.force.gcc", components*components, true);

    // It's convenient to store the interaction strengths in matrix form, and
    // at this point we also show the matrix and warn for asymmetry if necessary.
    gccm.length = components;
    import std.string;
    string header = "Shan-Chen enabled - interaction matrix:\n\n         ";
    string lines;
    for(int i = 0; i < components; i++ ) {
      header ~= format("%8d ",i);
      lines ~= format("%8d ",i);
      gccm[i].length = components;
      for(int j = 0; j < components; j++ ) {
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
  foreach( ref e; L.force) {
    e.initConst(0.0);
  }
}

/**
   Add the Shan-Chen force to force arrays L.force[].
   The force is calculated according to \(\vec{F}^c = - \Psi(\rho(\vec{x})) \sum_{c'} g_{cc'} \sum_{\vec{x}'} \Psi(\rho(\vec{x}'))(\vec{x} -\vec{x}')\),
   where \(c'\) runs over all fluid species and \(\vec{x}'\) runs over all connected lattice sites.
   Note that self-interaction is possible if \(g_{cc} \ne 0\).

   Params:
     L = lattice
     conn = connectivity

   Todo: adapt isBounceBack restriction to implement wetting walls.
*/
void addShanChenForce(alias conn, T)(ref T L) {
  auto cv = conn.velocities;
  auto cw = conn.weights;
  double[conn.d] df;
  // Do all combinations of two fluids.
  for( int nc1 = 0; nc1 < L.fluids.length; nc1++ ) {
    for( int nc2 = 0; nc2 < L.fluids.length; nc2++ ) {
      // This interaction has a particular coupling constant.
      auto cc = gccm[nc1][nc2];
      // Skip zero interactions.
      if ( cc == 0.0 ) continue;
      foreach( x, y, z, ref force ; L.force[nc1] ) {
        // Only do lattice sites on which collision will take place.
	if ( isCollidable(L.mask[x,y,z]) ) {
	  auto psiden1 = psi(L.fluids[nc1][x,y,z].density());
	  foreach( i, ref c; cv ) {
	    auto nbx = x-cv[i][0];
	    auto nby = y-cv[i][1];
	    auto nbz = z-cv[i][2];
            // Only do lattice sites that are not walls.
	    if ( ! isBounceBack(L.mask[nbx,nby,nbz]) ) {
	      auto psiden2 = psi(L.fluids[nc2][nbx,nby,nbz].density());
              // The SC force function.
	      force[0] += psiden1 * psiden2 * cc * cv[i][0];
	      force[1] += psiden1 * psiden2 * cc * cv[i][1];
	      force[2] += psiden1 * psiden2 * cc * cv[i][2];
	    }
	  }
	}
      }
    }
  }
}

/**
   Default form for the Shan-Chen \(\Psi\) function: \(\Psi(\rho) = 1 - e^{-\rho}\).

   Params:
     den = density \(\rho\)

   Returns: \(\Psi(\rho)\).
*/
double psi(double den) pure nothrow @safe {
  import std.math;
  return ( 1.0 - exp(-den) );
}

