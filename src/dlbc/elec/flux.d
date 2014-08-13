module dlbc.elec.flux;

import dlbc.lb.connectivity;
import dlbc.elec.elec;
import dlbc.fields.init;
import dlbc.fields.parallel;
import dlbc.lattice;
import dlbc.lb.mask;
import dlbc.logging;
import dlbc.range;

void moveElecCharges(T)(ref T L) if ( isLattice!T ) {
  L.resetFlux();
  L.calculateDiffusiveFlux();
  L.calculateAdvectiveFlux();
  L.applyFlux();
  L.elChargeP.exchangeHalo();
  L.elChargeN.exchangeHalo();
}

private void resetFlux(T)(ref T L) if ( isLattice!T ) {
  L.elFluxP.initConst(0.0);
  L.elFluxN.initConst(0.0);
}

private void calculateDiffusiveFlux(T)(ref T L) if ( isLattice!T ) {
  immutable cv = econn.velocities;  
  if ( components > 1 ) {
    writeLogF("Diffusive flux not yet implemented for components > 1.");
  }

  foreach(immutable p, ref m; L.mask) {
    if ( isMobileCharge(m) ) {
      double curPhiTot = L.elPot[p];
      foreach(immutable vd; Iota!(0, econn.d) ) {
        curPhiTot += p[vd] * externalField[vd];
      }
      foreach(immutable vq; Iota!(1, econn.q - 1)) { // Do not iterate over self vector!
        econn.vel_t nb;
        foreach(immutable vd; Iota!(0, econn.d) ) {
          nb[vd] = p[vd] - cv[vq][vd];
        }
      } 
    }
  }
}

private void calculateAdvectiveFlux(T)(ref T L) if ( isLattice!T ) {
  if ( ! fluidOnElec || timestep == 0 ) return; // Do not advect during initial equilibration.
}

private void applyFlux(T)(ref T L) if ( isLattice!T ) {

}

private bool isMobileCharge(Mask bc) @safe pure nothrow @nogc {
  final switch(bc) {
  case Mask.None:
    return true;
  case Mask.Solid:
    return false;
  }
}


