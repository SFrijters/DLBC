module dlbc.elec.poisson;

import dlbc.lattice;
import dlbc.elec.elec;
import dlbc.fields.parallel;
import dlbc.lb.lb: timestep;
import dlbc.logging;
import dlbc.parallel;
import dlbc.range;

@("param") PoissonSolver solver;

@("param") sorMaxIterations = 0;
@("param") sorCheckIterations = 0;
@("param") sorShowIterations = 0;
@("param") sorToleranceRel = 0.0;

private double radiusSOR;

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

void initPoissonSolver(T)(ref T L) if( isLattice!T ) {
  final switch(solver) {
  case(PoissonSolver.None):
    writeLogF("elec calculations require elec.poisson.solver to be set.");
    break;
  case(PoissonSolver.SOR):
    L.initPoissonSolverSOR();
    break;
  case(PoissonSolver.P3M):
    break;
  }
}

private void initPoissonSolverSOR(T)(ref T L) if( isLattice!T ) {
  import std.math: PI;
  size_t maxLength = L.lengths[0];
  foreach(immutable i; Iota!(0,econn.d) ) {
    if ( L.lengths[i] > maxLength ) {
      maxLength = L.lengths[i];
    }
  }
  radiusSOR = 1.0 - ( 0.5* ( PI / maxLength ) * ( PI / maxLength ) );
  writeLogRI("Initialised SOR Poisson solver with radiusSOR = %e.", radiusSOR);
}

void solvePoisson(T)(ref T L) if( isLattice!T ) {
  if ( ! enableElec ) return;
  final switch(solver) {
  case(PoissonSolver.None):
    writeLogF("elec calculations require elec.poisson.solver to be set.");
    break;
  case(PoissonSolver.SOR):
    L.solvePoissonSOR();
    break;
  case(PoissonSolver.P3M):
    L.solvePoissonP3M();
    break;
  }
}

private void solvePoissonSOR(T)(ref T L) if ( isLattice!T ) {
  import std.math: abs;
  immutable cv = econn.velocities;

  double[2] globalRnorm, localRnorm;
  double sorToleranceAbs = 0.01 * sorToleranceRel;

  localRnorm[0] = 0.0;

  foreach(immutable p, ref e; L.elPot) {
    double depsphi = 0.0;
    double curRho = L.elChargeP[p] - L.elChargeN[p];
    double curPhi = e;
    
    if ( localDiel ) {
      double curDiel = L.getLocalDiel(p);
      foreach(immutable i; 1..cv.length) { // Do not iterate over self vector!
        econn.vel_t nb;
        foreach(immutable j; Iota!(0, econn.d) ) {
          nb[j] = p[j] - cv[i][j];
        }
        double nbPhi = L.getNbPot(p, cv[i]);
        // writeLogRD("%s %s %s", nb, L.elPot[nb], nbPhi);
        double nbDiel = L.getLocalDiel(nb);
        depsphi += ( nbDiel + curDiel ) * ( nbPhi - curPhi );
      }
      depsphi *= 0.5;
    }
    else {
      foreach(immutable i; 1..cv.length) { // Do not iterate over self vector!
        double nbPhi = L.getNbPot(p, cv[i]);
        depsphi += nbPhi;
      }
      depsphi = dielUniform * ( depsphi - 6.0 * curPhi );
    }
    localRnorm[0] += abs(depsphi + curRho);
  }

  // writeLogD("localRnorm[0] = %e", localRnorm[0]);

  int oddity = 0;
  foreach(immutable i; 0..L.M.dim) {
    oddity += L.M.c[i] * L.lengths[i];
  }
  int moddity = oddity % 2;
  double omega = 1.0;

  static if ( L.dimensions == 3 ) {
    foreach(immutable it; 0..sorMaxIterations) {
      int isw, jsw, ksw;
      localRnorm[1] = 0.0;
      ksw = 0;
      foreach(immutable ipass; 0..2) {
        jsw = ksw;
        // Todo: foreach, 2D.
        for(int k = 0; k < L.lengths[2]; k++ ) {
          isw = jsw;
          if ( moddity == 1 ) isw = 1 - isw;
          for (int j = 0; j < L.lengths[1]; j++ ) {
            for (int i = isw; i < L.lengths[0]; i = i+2 ) {
              immutable offset = L.elPot.haloSize;
              immutable ptrdiff_t[3] p = [i+offset,j+offset,k+offset];
              double residual;
              double depsphi = 0.0;
              double curRho = L.elChargeP[p] - L.elChargeN[p];
              double curPhi = L.elPot[p];
              if ( localDiel ) {
                double dielTot = 0.0;
                double curDiel = L.getLocalDiel(p);
                foreach(immutable iv; 1..cv.length) { // Do not iterate over self vector!
                  econn.vel_t nb;
                  foreach(immutable jv; Iota!(0, econn.d) ) {
                    nb[jv] = p[jv] - cv[iv][jv];
                  }
                  double nbPhi = L.getNbPot(p, cv[iv]);
                  // writeLogRD("%s %s %s", nb, nbPhi, L.elPot[nb]);
                  double dielH = 0.5* ( L.getLocalDiel(nb) + curDiel );
                  dielTot += dielH;
                  depsphi += dielH * ( nbPhi - curPhi );
                }
                residual = depsphi + curRho;
                L.elPot[p] += omega * residual / dielTot;
              }
              else {
                foreach(immutable iv; 1..cv.length) { // Do not iterate over self vector!
                  double nbPhi = L.getNbPot(p, cv[iv]);
                  depsphi += nbPhi;
                }
                residual = dielUniform * ( depsphi - 6.0 * curPhi ) + curRho;
                L.elPot[p] += omega * residual / ( 6.0 * dielUniform);
              }
              // writeLogD("L.elPot%s = %e %e %e %e %e %e",p, L.elPot[p], curPhi, curRho, depsphi, residual, dielUniform);
              localRnorm[1] += abs(residual);
            }
            isw = 1 - isw;
          }
          jsw = 1 - jsw;
        }
        ksw = 1 - ksw;

        if ( it == 0 && ipass == 0 ) {
          omega = 1.0 / ( 1.0 - 0.5 * radiusSOR * radiusSOR);
        }
        else {
          omega = 1.0 / ( 1.0 - 0.25 * radiusSOR * radiusSOR * omega);
        }
        // writeLogRD("omega = %e",omega);

        L.elPot.exchangeHalo();
      }

      // writeLogD("localRnorm[1] = %f",localRnorm[1]);

      if ( it % sorCheckIterations == 0 ) {
        MPI_Allreduce(&localRnorm, &globalRnorm, 2, MPI_DOUBLE, MPI_SUM, L.M.comm);
        if ( globalRnorm[1] < sorToleranceAbs || globalRnorm[1] < sorToleranceRel*globalRnorm[0] ) {
          if ( sorShowIterations > 0 ) {
            writeLogRI("Finished SOR iteration = %d at t = %d, rnorm = %e, tolA = %e, tolR = %e.", it + 1, timestep, globalRnorm[1], sorToleranceAbs, sorToleranceRel);
          }
          return;
        }
        else {
          if ( sorShowIterations > 0 && ( it % sorShowIterations == 0 ) ) {
            writeLogRI("Performed SOR iteration = %d at t = %d, rnorm = %e, tolA = %e, tolR = %e.", it + 1, timestep, globalRnorm[1], sorToleranceAbs, sorToleranceRel);
          }
        }
      }
    }
  }
  else {
    assert(0);
  }

  writeLogF("SOR won't converge.");
}

private void solvePoissonP3M(T)(ref T L) if ( isLattice!T ) {
  assert(0, "elec.poissonSolver == P3M is not yet implemented.");
}

void calculateElectricField(T)(ref T L) if ( isLattice!T ) {
  if ( ! enableElec ) return;
  L.calculateElectricFieldFD();
}

private void calculateElectricFieldFD(T)(ref T L) if ( isLattice!T ) {
  import dlbc.lb.advection: isOnEdge;
  immutable cv = econn.velocities;
  foreach(immutable p, ref e; L.elField.arr) {
    if ( p.isOnEdge!econn(L.elField.lengthsH) ) continue;
    e = 0.0;
    foreach(immutable iv; 1..cv.length) { // Do not iterate over self vector!
      double nbPhi = L.getNbPot(p, cv[iv]);
      foreach(immutable jv; Iota!(0, econn.d) ) {
        e[jv] += -0.5 * cv[iv][jv] * nbPhi;
      }
    }
    foreach(immutable jv; Iota!(0, econn.d) ) {
      e[jv] += externalField[jv];
    }
  }
}

double getLocalDiel(alias dims = T.dimensions, T)(ref T L, const ptrdiff_t[dims] p) if ( isLattice!T ) {
  import dlbc.lb.mask;
  if ( fluidOnElec ) {
    if ( L.mask[p] == Mask.Solid ) {
      return solidDiel;
    }
    else {
      return averageDiel * ( 1.0 - dielContrast * L.getLocalOP(p) );
    }
  }
  else {
    return L.elDiel[p];
  }
}

double getLocalOP(alias dims = T.dimensions, T)(ref T L, const ptrdiff_t[dims] p) if ( isLattice!T ) {
  import dlbc.lb.density;
  if ( components < 2 ) {
    return 1.0;
  }
  else if ( components == 2 ) {
    return ( ( L.fluids[0][p].density() - L.fluids[1][p].density() ) / ( L.fluids[0][p].density() + L.fluids[1][p].density() ) );
  }
  else {
    assert(0);
  }
}

double getNbPot(alias dims = T.dimensions, T)(ref T L, const ptrdiff_t[dims] p, const ptrdiff_t[dims] cv) if ( isLattice!T ) {

  econn.vel_t nb;
  econn.vel_t gp;
  double potShift = 0.0;

  foreach(immutable i; Iota!(0, econn.d) ) {
    gp[i] = p[i] + cv[i] + M.c[i] * L.elPot.n[i] - L.elPot.haloSize;

    if ( gp[i] < 0 ) {
      final switch(boundaryPhi[2*i]) {
        case(BoundaryPhi.Periodic):
          nb[i] = p[i] + cv[i];
          break;
        case(BoundaryPhi.Neumann):
          nb[i] = p[i];
          break;
        case(BoundaryPhi.Drop):
          nb[i] = p[i] + cv[i];
          potShift += dropPhi[2*i];
          break;
        }
    }
    else if ( gp[i] >= L.gn[i] ) {
      final switch(boundaryPhi[2*i+1]) {
        case(BoundaryPhi.Periodic):
          nb[i] = p[i] + cv[i];
          break;
        case(BoundaryPhi.Neumann):
          nb[i] = p[i];
          break;
        case(BoundaryPhi.Drop):
          nb[i] = p[i] + cv[i];
          potShift -= dropPhi[2*i+1];
          break;
        }
    }
    else {
      nb[i] = p[i] + cv[i];
    }
  }
  double pot = L.elPot[nb] + potShift;
  //writeLogRD("p = %s, cv = %s, nb = %s %s, gp = %s, L.gn = %s",p,cv,nb, pot, gp, L.gn);
  return pot;
}

