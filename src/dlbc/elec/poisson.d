// Written in the D programming language.

/**
   Poisson solvers.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters
*/

module dlbc.elec.poisson;

import dlbc.lattice;
import dlbc.elec.elec;
import dlbc.fields.parallel;
import dlbc.lb.lb: timestep;
import dlbc.logging;
import dlbc.parallel;
import dlbc.range;
import dlbc.timers;

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

  startTimer("main.elec.poisson");

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

  stopTimer("main.elec.poisson");
}

private void solvePoissonSOR(T)(ref T L) if ( isLattice!T ) {
  import std.math: abs;
  immutable cv = econn.velocities;

  double[2] globalRnorm, localRnorm;
  double sorToleranceAbs = 0.01 * sorToleranceRel;

  if ( localDiel ) {
    import dlbc.lb.density: precalculateDensities;
    L.precalculateDensities();
  }

  localRnorm[0] = 0.0;

  foreach(immutable p, ref e; L.elPot) {
    double depsphi = 0.0;
    double curRho = L.elChargeP[p] - L.elChargeN[p];
    double curPhi = e;
    
    if ( localDiel ) {
      double curDiel = L.getLocalDiel(p);
      foreach(immutable i; 1..cv.length) { // Do not iterate over self vector!
        econn.vel_t nb;
        double nbPhi = L.getNbPot(p, cv[i], nb);
        double nbDiel = L.getLocalDiel(nb);
        depsphi += ( nbDiel + curDiel ) * ( nbPhi - curPhi );
        // writeLogRD("%s %s %s %s", p, nb, nbPhi, nbDiel);
      }
      depsphi *= 0.5;
    }
    else {
      foreach(immutable i; 1..cv.length) { // Do not iterate over self vector!
        double nbPhi = L.getNbPot(p, cv[i]);
        depsphi += nbPhi;
      }
      depsphi = dielGlobal * ( depsphi - 2.0 * T.dimensions * curPhi );
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

  writeLogRD("Moddity = %d", moddity);

  foreach(immutable it; 0..sorMaxIterations) {
    localRnorm[1] = 0.0;

    static if ( T.dimensions == 3 ) {
      int isw, jsw, ksw;
      ksw = 0;
      foreach(immutable ipass; 0..2) {
        jsw = ksw;
        for(int k = 0; k < L.lengths[2]; ++k ) {
          isw = jsw;
          if ( moddity == 1 ) isw = 1 - isw;
          for (int j = 0; j < L.lengths[1]; ++j ) {
            for (int i = isw; i < L.lengths[0]; i = i+2 ) {
              immutable offset = L.elPot.haloSize;
              immutable ptrdiff_t[3] p = [i+offset, j+offset, k+offset];
              mixin(sorKernel);
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
        writeLogRD("it = %d, ipass = %d, omega = %e", it, ipass, omega);

        L.elPot.exchangeHalo();
      }
    }
    else static if ( T.dimensions == 2 ) {
      assert(moddity == 0);
      foreach(immutable ipass; 0..2) {
        for(int j = 0; j < L.lengths[1]; ++j ) {
          for (int i = (ipass + j%2)%2; i < L.lengths[0]; i=i+2 ) {
            immutable offset = L.elPot.haloSize;
            immutable ptrdiff_t[2] p = [i+offset, j+offset];
            mixin(sorKernel);
          }
        }

        if ( it == 0 && ipass == 0 ) {
          omega = 1.0 / ( 1.0 - 0.5 * radiusSOR * radiusSOR);
        }
        else {
          omega = 1.0 / ( 1.0 - 0.25 * radiusSOR * radiusSOR * omega);
        }
        writeLogRD("it = %d, ipass = %d, omega = %e", it, ipass, omega);

        L.elPot.exchangeHalo();
      }
    }
   else static if ( T.dimensions == 1 ) {
       // assert(moddity == 0);
      foreach(immutable ipass; 0..2) {
        for (int i = ipass%2; i < L.lengths[0]; i=i+2 ) {
          immutable offset = L.elPot.haloSize;
          immutable ptrdiff_t[1] p = [i+offset];
          mixin(sorKernel);
        }

        if ( it == 0 && ipass == 0 ) {
          omega = 1.0 / ( 1.0 - 0.5 * radiusSOR * radiusSOR);
        }
        else {
          omega = 1.0 / ( 1.0 - 0.25 * radiusSOR * radiusSOR * omega);
        }
        writeLogRD("it = %d, ipass = %d, omega = %e", it, ipass, omega);

        L.elPot.exchangeHalo();
      }
    }
    else {
      static assert(0);
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

  writeLogF("SOR won't converge.");
}

private static immutable string sorKernel = q{
  double residual;
  double depsphi = 0.0;
  double curRho = L.elChargeP[p] - L.elChargeN[p];
  double curPhi = L.elPot[p];
  if ( localDiel ) {
    double dielTot = 0.0;
    double curDiel = L.getLocalDiel(p);
    foreach(immutable iv; 1..cv.length) { // Do not iterate over self vector!
      ptrdiff_t[T.dimensions] nb;
      double nbPhi = L.getNbPot(p, cv[iv], nb);
      double dielH = 0.5* ( L.getLocalDiel(nb) + curDiel );
      dielTot += dielH;
      depsphi += dielH * ( nbPhi - curPhi );
      // writeLogRD("%d %d %d %s %e %e %e", p[0] -1, p[1] -1, p[2] -1, nb, nbPhi, dielH, depsphi);
    }
    residual = depsphi + curRho;
    L.elPot[p] += omega * residual / dielTot;
  }
  else {
    foreach(immutable iv; 1..cv.length) { // Do not iterate over self vector!
      double nbPhi = L.getNbPot(p, cv[iv]);
      depsphi += nbPhi;
    }
    residual = dielGlobal * ( depsphi - 2.0 * T.dimensions * curPhi ) + curRho;
    L.elPot[p] += omega * residual / ( 2.0 * T.dimensions * dielGlobal);
  }
  // writeLogD("L.elPot %s = %e %e %e %e %e %e",p, L.elPot[p], curPhi, curRho, depsphi, residual, dielGlobal);
  localRnorm[1] += abs(residual);
};

private void solvePoissonP3M(T)(ref T L) if ( isLattice!T ) {
  assert(0, "elec.poissonSolver == P3M is not yet implemented.");
}

void calculateElectricField(T)(ref T L) if ( isLattice!T ) {
  if ( ! enableElec ) return;

  startTimer("main.elec.field");
  L.calculateElectricFieldFD();
  stopTimer("main.elec.field");
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

double getLocalDiel(alias dims = T.dimensions, T)(ref T L, in ptrdiff_t[dims] p) @safe nothrow @nogc if ( isLattice!T ) {
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

double getLocalOP(alias dims = T.dimensions, T)(ref T L, in ptrdiff_t[dims] p) @safe nothrow @nogc if ( isLattice!T ) {

  if ( components < 2 ) {
    return 1.0;
  }
  else if ( components == 2 ) {
    assert(L.density[0].isFresh);
    assert(L.density[1].isFresh);
    return ( ( L.density[0][p] - L.density[1][p] ) / ( L.density[0][p] + L.density[1][p] ) );
  }
  else {
    assert(0, "Dielectric contrast not implemented for components > 2.");
  }
}

double getNbPot(alias dims = T.dimensions, T)(ref T L, in ptrdiff_t[dims] p, in ptrdiff_t[dims] cv) @safe nothrow @nogc if ( isLattice!T ) {
  econn.vel_t nb;
  return L.getNbPot(p, cv, nb);
 }

double getNbPot(alias dims = T.dimensions, T)(ref T L, in ptrdiff_t[dims] p, in ptrdiff_t[dims] cv, ref ptrdiff_t[dims] nb) @safe nothrow @nogc if ( isLattice!T ) {
  econn.vel_t gp;
  double potShift = 0.0;

  foreach(immutable i; Iota!(0, econn.d) ) {
    gp[i] = p[i] + cv[i] + M.c[i] * L.elPot.n[i] - L.elPot.haloSize;

    if ( gp[i] < 0 ) {
      final switch(boundaryPhi[i][0]) {
        case(BoundaryPhi.Periodic):
          nb[i] = p[i] + cv[i];
          break;
        case(BoundaryPhi.Neumann):
          nb[i] = p[i];
          break;
        case(BoundaryPhi.Drop):
          nb[i] = p[i] + cv[i];
          potShift += dropPhi[i][0];
          break;
        }
    }
    else if ( gp[i] >= L.gn[i] ) {
      final switch(boundaryPhi[i][1]) {
        case(BoundaryPhi.Periodic):
          nb[i] = p[i] + cv[i];
          break;
        case(BoundaryPhi.Neumann):
          nb[i] = p[i];
          break;
        case(BoundaryPhi.Drop):
          nb[i] = p[i] + cv[i];
          potShift -= dropPhi[i][1];
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

