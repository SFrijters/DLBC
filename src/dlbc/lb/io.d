// Written in the D programming language.

/**
   Functions that handle output for LB modules.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

*/

module dlbc.lb.io;

/**
   Frequency at which fluid population fields should be written to disk.
*/
@("param") int populationFreq;
/**
   Frequency at which fluid density fields should be written to disk.
*/
@("param") int densityFreq;
/**
   Frequency at which fluid density difference fields (colour) should be written to disk.
*/
@("param") int colourFreq;
/**
   Frequency at which velocity fields should be written to disk.
*/
@("param") int velocitiesFreq;
/**
   Frequency at which force fields should be written to disk.
*/
@("param") int forceFreq;
/**
   Frequency at which mask fields should be written to disk.
*/
@("param") int maskFreq;
/**
   Frequency at which Laplace data should be written to disk.
*/
@("param") int laplaceFreq;

import dlbc.lb.lb;
import dlbc.io.io;
import dlbc.lattice;

/**
   Dump LB data to disk, based on the current lattice and the current timestep.

   Params:
     L = current lattice
     t = current timestep
*/
void dumpLBData(T)(ref T L, uint t) if ( isLattice!T ) {

  if (dumpNow(populationFreq,t)) {
    foreach(immutable i, ref e; L.fluids) {
      e.dumpField("population-"~fieldNames[i], t);
    }
  }

  if (dumpNow(densityFreq,t)) {
    foreach(immutable i, ref e; L.fluids) {
      e.densityField(L.mask, L.density[i]);
      L.density[i].dumpField("density-"~fieldNames[i], t);
    }
  }

  if (dumpNow(colourFreq,t)) {
    foreach(immutable i, ref e; L.fluids) {
      foreach(immutable j; i+1..L.fluids.length) {
        auto colour = colourField(L.fluids[i], L.fluids[j], L.mask);
        colour.dumpField("colour-"~fieldNames[i]~"-"~fieldNames[j],t);
      }
    }
  }

  if (dumpNow(velocitiesFreq,t)) {
    foreach(immutable i, ref e; L.fluids) {
      auto velocity = e.velocityField(L.mask);
      velocity.dumpField("velocity-"~fieldNames[i], t);
    }
  }

  if (dumpNow(forceFreq,t)) {
    foreach(immutable i, ref e; L.force) {
      e.dumpField("force-"~fieldNames[i], t);
    }
  }

  if (dumpNow(maskFreq,t)) {
    L.mask.dumpField("mask", t);
  }

  if (dumpNow(laplaceFreq,t)) {
    L.dumpLaplace(t);
  }

}

