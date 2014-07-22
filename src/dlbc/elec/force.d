module dlbc.elec.force;

import dlbc.elec.elec;
import dlbc.lb.lb: components;
import dlbc.lattice;

import dlbc.range;

@("param") bool enableElectrostatic = true;
@("param") bool enableDielectrophoretic = true;

void addElecForce(T)(ref T L) if (isLattice!T) {
  if ( ( ! enableElec ) || ( ! elecOnFluid ) ) return;

  immutable cv = econn.velocities;

  foreach(immutable p, ef; L.elField ) {
    // Electrostatic force

    if ( enableElectrostatic ) {
      foreach(immutable j; Iota!(0, econn.d) ) {
        double[econn.d] electrostatic = elementaryCharge * ( L.elChargeP[p] - L.elChargeN[p] ) * L.elField[p][j];
        foreach(immutable nc1; 0..L.fluids.length ) {
          L.force[nc1][p][j] += electrostatic[j];
        }
      }
    }

    if ( localDiel && components > 1 && enableDielectrophoretic ) {
      foreach(immutable i; Iota!(0, econn.q) ) {
        econn.vel_t nb;
        foreach(immutable j; Iota!(0, econn.d) ) {
          nb[j] = p[j] - cv[i][j];
        }
        double nb_E2 = 0.0;
        double[econn.d] grad_E2 = 0.0;
        foreach(immutable j; Iota!(0, econn.d) ) {
          nb_E2 += L.elField[p][j] * L.elField[p][j];
        }
        nb_E2 *= 0.5;
        foreach(immutable j; Iota!(0, econn.d) ) {
          grad_E2[j] += nb_E2 * nb[j];
        }
        // Add forces
        foreach(immutable j; Iota!(0, econn.d) ) {
          foreach(immutable nc1; 0..L.fluids.length ) {
            L.force[nc1][p][j] -= 0.5 * ( L.getLocalDiel!(T.dimensions)(p) - averageDiel ) * grad_E2[j];
          }
        }
      }        
    }

  }
}

