module dlbc.elec.poisson;

import dlbc.lattice;
import dlbc.elec.elec;
import dlbc.logging;

/**
   Poisson solver to be used.
*/
enum PoissonSolver {
  /**
     No solver.
  */
  None,
  /**
     Successive over-relaxation.
  */
  SOR,
  /**
     Particle-Particle-Particle-Mesh.
  */
  P3M,
}

void solvePoisson(T)(ref T L) if( isLattice!T ) {
  final switch(poissonSolver) {
  case(PoissonSolver.None):
    writeLogF("elec calculations require elec.poissonSolver to be set.");
    break;
  case(PoissonSolver.SOR):
    L.solvePoissonSOR();
    break;
  case(PoissonSolver.P3M):
    L.solvePoissonP3M();
    break;
  }
}

void solvePoissonSOR(T)(ref T L) if ( isLattice!T ) {
  immutable cv = econn.velocities;

  // foreach(immutable p, ref e; L.elPot) {
  //   double depsphi = 0.0;
  //   double curRho = L.elChargeP[p] - L.elChargeN[p];
  //   double curPhi = e;
    
  //   if ( localDiel ) {
  //     double curDiel = L.getLocalDiel!(T.dimensions)(p);
  //     foreach(immutable i, e; cv) {
  //       econn.vel_t nb;
  //       foreach(immutable j; Iota!(0, econn.d) ) {
  //         nb[j] = p[j] - cv[i][j];
  //       }
  //       double nbPhi = L.elPot[nb];
  //       double nbDiel = L.getLocalDiel!(T.dimensions)(nb);
  //       depsphi += ( nbDiel + curDiel ) * ( nbPhi - curPhi );
  //     }
  //     depsphi *= 0.5;
  //   }
  //   else {
      
  //   }
  // }
}

void solvePoissonP3M(T)(ref T L) if ( isLattice!T ) {
  assert(0, "elec.poissonSolver == P3M is not yet implemented.");
}

/**
   Todo: should not need to pass dims parameter explicitly; why not use T.dimensions?
*/
double getLocalDiel(uint dims, T)(ref T L, const ptrdiff_t[dims] p) if ( isLattice!T ) {
  if ( fluidOnElec ) {
    assert(0, "fluidOnElec not yet implemented.");
  }
  else {
    return L.elDiel[p];
  }
}