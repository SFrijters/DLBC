module dlbc.elec.flux;

import dlbc.lb.connectivity;
import dlbc.elec.elec;
import dlbc.fields.init;
import dlbc.fields.parallel;
import dlbc.lattice;
import dlbc.lb.mask;
import dlbc.logging;
import dlbc.parallel;
import dlbc.range;

import std.math: exp;

@("param") double thermalDiffusionCoeff;
@("param") double deltaTDC = 0.0;

@("param") double deltaMuPos;
@("param") double deltaMuNeg;

@("param") double fluxToleranceRel;

private double DPos, DNeg;

void initElecFlux() {
  DPos = thermalDiffusionCoeff + deltaTDC;
  DNeg = thermalDiffusionCoeff - deltaTDC;
  writeLogRD("thermalDiffusionCoefficient = %e, deltaTDC = %e", thermalDiffusionCoeff, deltaTDC);
  writeLogRI("Setting DPos = %e, DNeg = %e", DPos, DNeg);
}

bool moveElecCharges(T)(ref T L) if ( isLattice!T ) {
  bool isEquilibrated;
  L.resetFlux();
  L.calculateDiffusiveFlux();
  L.calculateAdvectiveFlux();
  isEquilibrated = L.applyFlux();
  L.elChargeP.exchangeHalo();
  L.elChargeN.exchangeHalo();
  // import dlbc.io.io;
  // L.elPot.dumpField("testPhi", timestep);
  // L.elChargeP.dumpField("testP", timestep);
  // L.elChargeN.dumpField("testN", timestep);
  // L.elFluxP.dumpField("fluxP", timestep);
  // L.elFluxN.dumpField("fluxN", timestep);
  return isEquilibrated;
}

private void resetFlux(T)(ref T L) if ( isLattice!T ) {
  L.elFluxP.initConst(0.0);
  L.elFluxN.initConst(0.0);
}

private void calculateDiffusiveFlux(T)(ref T L) if ( isLattice!T ) {
  immutable cv = econn.velocities;
  if ( components > 2 ) {
    assert(0, "Diffusive flux not yet implemented for components > 2.");
  }

  foreach(immutable p, ref m; L.mask) {
    if ( isMobileCharge(m) ) {
      double curPhiTot = L.elPot[p];
      foreach(immutable vd; Iota!(0, econn.d) ) {
        curPhiTot += p[vd] * externalField[vd];
      }
      immutable curOp = L.getLocalOP(p);
      foreach(immutable vq; Iota!(1, econn.q - 1)) { // Do not iterate over self vector!
        econn.vel_t nb;
        foreach(immutable vd; Iota!(0, econn.d) ) {
          nb[vd] = p[vd] + cv[vq][vd];
        }
        if ( isMobileCharge(L.mask[nb]) ) {
          double nbPhiTot = L.getNbPot(p, cv[vq]);
          foreach(immutable vd; Iota!(0, econn.d) ) {
            nbPhiTot += nb[vd] * externalField[vd];
          }
          if ( fluidOnElec && components > 1 ) {
            writeLogF("Not yet tested!");
            immutable nbOp = L.getLocalOP(nb);
            immutable expDeltaPos = exp( beta * ( elementaryCharge * ( nbPhiTot - curPhiTot ) + 0.5 * deltaMuPos * ( nbOp - curOp ) ) );
            immutable invExpDeltaPos = 1.0 / expDeltaPos;

            immutable expDeltaNeg = exp( beta * ( elementaryCharge * ( nbPhiTot - curPhiTot ) + 0.5 * deltaMuNeg * ( nbOp - curOp ) ) );
            immutable invExpDeltaNeg = 1.0 / expDeltaNeg;

            immutable fluxLinkPos = -0.5 * DPos * (1.0 + invExpDeltaPos) * ( L.elChargeP[nb] * expDeltaPos - L.elChargeP[p] );
            immutable fluxLinkNeg = -0.5 * DNeg * (1.0 + expDeltaNeg) * ( L.elChargeN[nb] * invExpDeltaNeg - L.elChargeN[p] );

            L.elFluxP[p] += fluxLinkPos;
            L.elFluxN[p] += fluxLinkNeg;
          }
          else {
            immutable expDPhi = exp( beta * elementaryCharge * ( nbPhiTot - curPhiTot ) );
            immutable invExpDPhi = 1.0 / expDPhi;
            
            immutable fluxLinkPos = -0.5 * DPos * (1.0 + invExpDPhi) * ( L.elChargeP[nb] * expDPhi - L.elChargeP[p] );
            immutable fluxLinkNeg = -0.5 * DNeg * (1.0 + expDPhi) * ( L.elChargeN[nb] * invExpDPhi - L.elChargeN[p] );
            L.elFluxP[p] += fluxLinkPos;
            L.elFluxN[p] += fluxLinkNeg;
            if ( p[1] == 2 && nb[1] == 2) {
              writeLogD("p = %s, nb = %s, fluxLinkNeg = %e", p, nb, fluxLinkNeg);
            }
          }

        }

      }
    }
  }
}

private void calculateAdvectiveFlux(T)(ref T L) if ( isLattice!T ) {
  if ( ! fluidOnElec || timestep == 0 || components == 0 ) return; // Do not advect during initial equilibration.
  assert(0, "Advective flux not yet implemented.");
}

private bool applyFlux(T)(ref T L) if ( isLattice!T ) {
  import std.math: approxEqual, abs;
  import std.algorithm: max;
  double localTotalFluxP = 0.0;
  double localTotalFluxN = 0.0;
  double localMaxFlux = 0.0;
  double localMaxRelFlux = 0.0;
  foreach(immutable p, ref m; L.mask) {
    if ( isMobileCharge(m) ) {
      // Move charges
      L.elChargeP[p] -= L.elFluxP[p];
      L.elChargeN[p] -= L.elFluxN[p];

      localTotalFluxP -= L.elFluxP[p];
      localTotalFluxN -= L.elFluxN[p];

      localMaxFlux = max(localMaxFlux, abs(L.elFluxP[p]));
      localMaxFlux = max(localMaxFlux, abs(L.elFluxN[p]));

      localMaxRelFlux = max(localMaxRelFlux, abs(L.elFluxP[p] / L.elChargeP[p] ) );
      localMaxRelFlux = max(localMaxRelFlux, abs(L.elFluxN[p] / L.elChargeN[p] ) );
    }
  }

  double globalTotalFluxP, globalTotalFluxN, globalMaxFlux, globalMaxRelFlux;
  MPI_Allreduce(&localTotalFluxP, &globalTotalFluxP, 1, MPI_DOUBLE, MPI_SUM, M.comm);
  MPI_Allreduce(&localTotalFluxN, &globalTotalFluxN, 1, MPI_DOUBLE, MPI_SUM, M.comm);
  assert(approxEqual(globalTotalFluxP, 0.0) );
  assert(approxEqual(globalTotalFluxN, 0.0) );

  MPI_Allreduce(&localMaxFlux, &globalMaxFlux, 1, MPI_DOUBLE, MPI_MAX, M.comm);
  MPI_Allreduce(&localMaxRelFlux, &globalMaxRelFlux, 1, MPI_DOUBLE, MPI_MAX, M.comm);

  if ( approxEqual(globalTotalFluxN, 0.0) ) {
    writeLogRD("total fluxes: %e %e", globalTotalFluxP, globalTotalFluxN);
  }
  else {
    writeLogF("total fluxes: %e %e", globalTotalFluxP, globalTotalFluxN);
  }

  writeLogRI("globalMaxRelFlux = %e", globalMaxRelFlux);
  return ( globalMaxRelFlux < fluxToleranceRel );
}

private bool isMobileCharge(Mask bc) @safe pure nothrow @nogc {
  final switch(bc) {
  case Mask.None:
    return true;
  case Mask.Solid:
    return false;
  }
}


