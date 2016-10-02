// Written in the D programming language.

/**
   Functions that handle output for elec modules.

   Copyright: Stefan Frijters 2011-2016

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters
*/

module dlbc.elec.io;

/**
   Frequency at which electric charge fields should be written to disk.
*/
@("param") int chargeFreq;
/**
   Frequency at which electric potentials should be written to disk.
*/
@("param") int potFreq;
/**
   Frequency at which dielectric constants should be written to disk.
*/
@("param") int dielFreq;
/**
   Frequency at which electric fields should be written to disk.
*/
@("param") int fieldFreq;

import dlbc.elec.elec;
import dlbc.io.io;
import dlbc.lattice;

/**
   Dump elec data to disk, based on the current lattice and the current timestep.

   Params:
     L = current lattice
     t = current timestep
*/
void dumpElecData(T)(ref T L, uint t) if ( isLattice!T ) {
  if ( ! enableElec ) return;

  if ( dumpNow(chargeFreq,t) ) {
    L.elChargeP.dumpField("elChargeP", t);
    L.elChargeN.dumpField("elChargeN", t);
  }

  if ( dumpNow(potFreq,t) ) {
    L.elPot.dumpField("elPot", t);
  }

  if ( dumpNow(dielFreq,t) ) {
    if ( fluidOnElec ) {
      L.calculateDielField();
    }
    L.elDiel.dumpField("elDiel", t);
  }

  if ( dumpNow(fieldFreq,t) ) {
    L.elField.dumpField("elField", t);
  }
}

/**
   Write into the field for the dielectric constant, based on $(D getLocalDiel).

   Params:
     L = lattice
*/
void calculateDielField(T)(ref T L) if ( isLattice!T ) {
  import dlbc.elec.poisson;

  if ( localDiel ) {
    import dlbc.lb.density: precalculateDensities;
    L.precalculateDensities();
  }

  foreach(immutable p, e; L.elDiel) {
    L.elDiel[p] = L.getLocalDiel(p);
  }
}

