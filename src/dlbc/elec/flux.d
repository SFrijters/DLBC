// Written in the D programming language.

/**
   Flux calculations for electric charges.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters
*/

module dlbc.elec.flux;

import dlbc.lb.connectivity;
import dlbc.elec.elec;
import dlbc.fields.parallel;
import dlbc.lattice;
import dlbc.lb.mask;
import dlbc.logging;
import dlbc.parallel;
import dlbc.range;
import dlbc.timers;
import dlbc.lb.lb: components;

import std.math: exp;

/**
   Thermal diffusion coefficient for electric charges.
*/
@("param") double thermalDiffusionCoeff;
/**
   Difference in thermal diffusion coefficient between the positive and negative electric charges.
*/
@("param") double deltaTDC = 0.0;
/**
   Solvation free energy difference between the first and second fluids for the positive ion species.
*/
@("param") double deltaMuPos;
/**
   Solvation free energy difference between the first and second fluids for the negative ion species.
*/
@("param") double deltaMuNeg;
/**
   Enables diffusive charge flux.
*/
@("param") bool enableDiffusiveFlux = true;
/**
   Enables advective charge flux.
*/
@("param") bool enableAdvectiveFlux = true;

// Derived quantities.
private double DPos, DNeg;

/**
   Calculate derived quantities for flux calculations.
*/
// TODO: restore package
void initElecFlux() {
  DPos = thermalDiffusionCoeff + deltaTDC;
  DNeg = thermalDiffusionCoeff - deltaTDC;
  writeLogRI("Derived quantities: DPos = %e, DNeg = %e", DPos, DNeg);
}

/**
   Move the electric charges. This involves first calculating the diffusive and advective fluxes and then applying the final result to the charge fields.

   Returns: whether the fluxes are below the accuracy threshold.
*/
// TODO: restore package
bool moveElecCharges(T)(ref T L) if ( isLattice!T ) {
  bool isEquilibrated;

  startTimer("elec.flux");

  L.resetFlux();
  L.calculateDiffusiveFlux();
  L.calculateAdvectiveFlux();
  isEquilibrated = L.applyFlux();
  L.elChargeP.exchangeHalo();
  L.elChargeN.exchangeHalo();

  stopTimer("elec.flux");

  return isEquilibrated;
}

/**
   Reset elFluxP and elFluxN fields to zero.

   Params:
     L = lattice
*/
private void resetFlux(T)(ref T L) @safe pure nothrow @nogc if ( isLattice!T ) {
  import dlbc.fields.init: initConst;
  L.elFluxP.initConst(0.0);
  L.elFluxN.initConst(0.0);
}

/**
   Calculates the diffusive flux and adds the result to the elFluxP and elFluxN fields.

   Params:
     L = lattice

   Todo: verify multicomponent.
*/
private void calculateDiffusiveFlux(T)(ref T L) nothrow @nogc if ( isLattice!T ) {
  if ( ! enableDiffusiveFlux ) return;
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
            assert(0, "Not yet tested!");
            // immutable nbOp = L.getLocalOP(nb);
            // immutable expDeltaPos = exp( beta * ( elementaryCharge * ( nbPhiTot - curPhiTot ) + 0.5 * deltaMuPos * ( nbOp - curOp ) ) );
            // immutable invExpDeltaPos = 1.0 / expDeltaPos;

            // immutable expDeltaNeg = exp( beta * ( elementaryCharge * ( nbPhiTot - curPhiTot ) + 0.5 * deltaMuNeg * ( nbOp - curOp ) ) );
            // immutable invExpDeltaNeg = 1.0 / expDeltaNeg;

            // immutable fluxLinkPos = -0.5 * DPos * (1.0 + invExpDeltaPos) * ( L.elChargeP[nb] * expDeltaPos - L.elChargeP[p] );
            // immutable fluxLinkNeg = -0.5 * DNeg * (1.0 + expDeltaNeg) * ( L.elChargeN[nb] * invExpDeltaNeg - L.elChargeN[p] );

            // L.elFluxP[p] += fluxLinkPos;
            // L.elFluxN[p] += fluxLinkNeg;
          }
          else {
            immutable expDPhi = exp( beta * elementaryCharge * ( nbPhiTot - curPhiTot ) );
            immutable invExpDPhi = 1.0 / expDPhi;

            immutable fluxLinkPos = -0.5 * DPos * (1.0 + invExpDPhi) * ( L.elChargeP[nb] * expDPhi - L.elChargeP[p] );
            immutable fluxLinkNeg = -0.5 * DNeg * (1.0 + expDPhi) * ( L.elChargeN[nb] * invExpDPhi - L.elChargeN[p] );
            L.elFluxP[p] += fluxLinkPos;
            L.elFluxN[p] += fluxLinkNeg;
          }
        }
      }
    }
  }
}

/**
   Calculates the advective flux and adds the result to the elFluxP and elFluxN fields.

   Params:
     L = lattice

   Todo: implement this.
*/
private void calculateAdvectiveFlux(T)(ref T L) if ( isLattice!T ) {
  import dlbc.lb.lb: timestep;
  if ( ! fluidOnElec || ! enableAdvectiveFlux || timestep == 0 || components == 0 ) return; // Do not advect during initial equilibration.
  assert(0, "Advective flux not yet implemented.");
}

/**
   Applies the fluxes stored in elFluxP and elFluxN to the charge fields.

   Params:
     L = lattice

   Returns: whether the fluxes are below the accuracy threshold.

   Todo: minimize parallel communication by clever use of flags.

   Bugs: check asserts
*/
private bool applyFlux(T)(ref T L) @trusted nothrow @nogc if ( isLattice!T ) {
  if ( ( ! enableAdvectiveFlux ) && ( ! enableDiffusiveFlux ) ) return true;
  import std.math: approxEqual, abs;
  import std.algorithm: max;
  double localTotalFluxP = 0.0;
  double localTotalFluxN = 0.0;
  double localMaxRelFlux = 0.0;
  foreach(immutable p, ref m; L.mask) {
    if ( isMobileCharge(m) ) {
      // Move charges
      L.elChargeP[p] -= L.elFluxP[p];
      L.elChargeN[p] -= L.elFluxN[p];

      localTotalFluxP -= L.elFluxP[p];
      localTotalFluxN -= L.elFluxN[p];

      localMaxRelFlux = max(localMaxRelFlux, abs(L.elFluxP[p] / L.elChargeP[p] ) );
      localMaxRelFlux = max(localMaxRelFlux, abs(L.elFluxN[p] / L.elChargeN[p] ) );
    }
  }

  // This should not be done in release mode.
  double globalTotalFluxP, globalTotalFluxN, globalMaxRelFlux;
  MPI_Allreduce(&localTotalFluxP, &globalTotalFluxP, 1, MPI_DOUBLE, MPI_SUM, M.comm);
  MPI_Allreduce(&localTotalFluxN, &globalTotalFluxN, 1, MPI_DOUBLE, MPI_SUM, M.comm);
  // assert(approxEqual(globalTotalFluxP, 0.0) );
  // assert(approxEqual(globalTotalFluxN, 0.0) );

  // This should only be done during initial equilibration.
  MPI_Allreduce(&localMaxRelFlux, &globalMaxRelFlux, 1, MPI_DOUBLE, MPI_MAX, M.comm);
  return ( globalMaxRelFlux < initFluxToleranceRel );
}

/**
   Wrapper function which checks if a mask allows movable charges.

   Params:
     bc = mask to check

   Returns: whether a mask allows movable charges.
*/
// TODO: restore private
bool isMobileCharge(Mask bc) @safe pure nothrow @nogc {
  final switch(bc) {
  case Mask.None:
    return true;
  case Mask.Solid:
    return false;
  }
}
