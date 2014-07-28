module dlbc.elec.flux;

import dlbc.lb.mask;

void calculateDiffusiveFlux(T)(ref T L) if( isLattice!T ) {
  
  if ( components > 1 ) {
    writeLogF("Diffusive flux not yet implemented for components > 1.");
  }

  foreach(immutable p, ref e; L.mask) {
    if ( isMobileCharge(e) ) {
      double curPhiTot = L.elPot[p];
      foreach(immutable i; Iota!(0, econn.d) ) {
        curPhiTot += p[i] * externalField[i];
      }
      foreach(immutable i; 1..cv.length) { // Do not iterate over self vector!
        econn.vel_t nb;
        foreach(immutable j; Iota!(0, econn.d) ) {
          nb[j] = p[j] - cv[i][j];
        }      
      }   
    }
  }

}

private bool isMobileCharge(Mask bc) @safe pure nothrow {
  final switch(bc) {
  case Mask.None:
    return true;
  case Mask.Solid:
    return false;
  }
}


