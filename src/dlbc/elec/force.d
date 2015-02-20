// Written in the D programming language.

/**
   Force calculations for electric charges.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

*/

module dlbc.elec.force;

import dlbc.elec.elec;
import dlbc.lb.lb: components;
import dlbc.lattice;

import dlbc.logging;

import dlbc.range;

/**
   Enable electrostatic force.
*/
@("param") bool enableElectrostatic = true;
/**
   Enable dielectrophoretic force.
*/
@("param") bool enableDielectrophoretic = true;

/**
   Calculate electric forces and add them to the global force field.

   Params:
     L = lattice

   Todo: add solvation force.
*/
void addElecForce(T)(ref T L) if (isLattice!T) {
  if ( ( ! enableElec ) || ( ! elecOnFluid ) ) return;

  immutable cv = econn.velocities;

  foreach(immutable p, ref F; L.forceDistributed ) {
    // Electrostatic force

    if ( enableElectrostatic ) {
      foreach(immutable j; Iota!(0, econn.d) ) {
        double[econn.d] electrostatic = elementaryCharge * ( L.elChargeP[p] - L.elChargeN[p] ) * L.elField[p][j];
        F[j] += electrostatic[j];
      }
    }

    if ( enableDielectrophoretic && localDiel && components > 1 ) {
      double[econn.d] grad_E2 = 0.0;
      foreach(immutable i; 1..cv.length ) {
        // Calculate neighbour
        econn.vel_t nb;
        foreach(immutable j; Iota!(0, econn.d) ) {
          nb[j] = p[j] + cv[i][j];
        }

        // Calculate E2 at the neighbour
        double nb_E2 = 0.0;
        foreach(immutable j; Iota!(0, econn.d) ) {
          nb_E2 += L.elField[nb][j] * L.elField[nb][j];
        }

        // Calculate the gradient
        nb_E2 *= 0.5;
        foreach(immutable j; Iota!(0, econn.d) ) {
          grad_E2[j] += nb_E2 * cv[i][j];
        }
      }

      // Add forces
      foreach(immutable j; Iota!(0, econn.d) ) {
        F[j] += 0.5 * ( L.getLocalDiel(p) - averageDiel ) * grad_E2[j];
      }
      //writeLogRI("forceDistributed%s = %s", p, L.forceDistributed[p]) ;
    }
  }
}


