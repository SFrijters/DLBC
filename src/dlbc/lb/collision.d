// Written in the D programming language.

/**
   Lattice Boltzmann collision for population fields.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters
*/

module dlbc.lb.collision;

import dlbc.fields.field;
import dlbc.lb.connectivity;
import dlbc.lb.density;
import dlbc.lb.eqdist;
import dlbc.lb.force;
import dlbc.lb.mask;
import dlbc.lb.velocity;
import dlbc.range;
import dlbc.timers;
import dlbc.lattice;

import dlbc.logging;

/**
   Perform operations just before the collision step.

   Currently, this pre-calculates the weighted velocities required by the BDist2
   equilibrium distribution function, if necessary.

   Params:
     L = lattice
*/
void prepareToCollide(T)(ref T L) if ( isLattice!T ) {
  alias conn = L.lbconn;

  if ( L.fluids.length == 0 ) return;

  startTimer("main.coll.prep");
  if ( eqDistForm == EqDistForm.BDist2 ) {
    L.calculateWeightedVelocity();
  }
  stopTimer("main.coll.prep");
}

/**
   Let the populations of the field collide.

   Params:
     field = field of populations
     mask = mask field
     force = force field
     tau = relaxation time
*/
void collideFields(T)(ref T L, in double[] tau, in double[] globalAcc) if ( isLattice!T ) {

  if ( L.fluids.length == 0 ) return;

  startTimer("main.coll.coll");
  final switch(eqDistForm) {
    // Calls appropriate collideFieldEqDist
    mixin(edfMixin());
  }
  stopTimer("main.coll.coll");
}

/// Ditto
private void collideFieldsKernel(EqDistForm eqDistForm, T)(ref T L, in double[] tau, in double[] globalAcc) if ( isLattice!T ) {
  assert(tau.length == L.fluids.length);
  assert(globalAcc.length == L.lbconn.d);

  alias conn = L.lbconn;

  L.calculateDensities();

  foreach(immutable f; 0..L.fluids.length) {
    immutable omega = 1.0 / tau[f];
    foreach(immutable p, ref pop; L.fluids[f]) {
      if ( isCollidable(L.mask[p]) ) {
	immutable den = L.density[f][p];
	double[conn.d] dv;
	foreach(immutable vd; Iota!(0,conn.d) ) {
	  dv[vd] = tau[f] * ( globalAcc[vd] + L.force[f][p][vd] / den);
	  // BDist2 requires the addition of the weighted velocity array
	  static if (eqDistForm == EqDistForm.BDist2) {
	    dv[vd] += weightedVelocityBDist2[p][vd];
	  }
	}
	immutable eq = eqDist!(eqDistForm, conn)(pop, dv, den);
	foreach(immutable vq; Iota!(0,conn.q) ) {
	  pop[vq] = pop[vq] * ( 1.0 - omega ) + omega * eq[vq];
	}
      }
    }
  }
}

/**
   Generate final switch mixin for all eqDistForm.
*/
private string edfMixin() {
  import std.traits: EnumMembers;
  import std.conv: to;
  string mixinString;
  foreach(immutable edf; EnumMembers!EqDistForm) {
    mixinString ~= "case eqDistForm." ~ to!string(edf) ~ ":\n";
    mixinString ~= "  L.collideFieldsKernel!(eqDistForm." ~ to!string(edf) ~ ")(tau, globalAcc);";
    mixinString ~= "  break;\n";
  }
  return mixinString;
}

/**
   The weighted velocity field needs to match the halo of the other fields.
   We cannot use VectorFieldOf here because the lattice is not available?
*/
static if ( gconn.d == 1 && gconn.q == 5 ) {
  // Careful! S-C needs one more site than just neighbours,
  // but D1Q5 has vectors with length == 2, so we need a halo
  // of 2 + 2 instead of 1 + 1.
  private Field!(double[gconn.q], dimOf!gconn, 4) weightedVelocityBDist2;
}
else {
  private Field!(double[gconn.q], dimOf!gconn, 2) weightedVelocityBDist2;
}

/**
   The weighted velocities are required for the BDist2 equilibrium distribution function.

   Params:
     L = lattice
*/
private void calculateWeightedVelocity(T)(ref T L) if ( isLattice!T ) {
  import dlbc.lb.lb: tau;

  alias conn = L.lbconn;
  immutable cv = conn.velocities;

  // Initialize field if necessary.
  if ( ! weightedVelocityBDist2.isInitialized ) {
    weightedVelocityBDist2 = typeof(weightedVelocityBDist2)(L.lengths);
  }

  // For all fluids, combine momentum and viscosity.
  foreach(immutable p, ref wv; weightedVelocityBDist2) {
    wv = 0.0;
    foreach(immutable f; 0..L.fluids.length) {
      double[conn.d] perFluid = 0.0;
      foreach(immutable vq; Iota!(0,conn.q) ) {
	foreach(immutable vd; Iota!(0, conn.d) ) {
	  perFluid[vd] += L.fluids[f][p][vq] * cv[vq][vd];
	}
      }
      foreach(immutable vd; Iota!(0, conn.d) ) {
	wv[vd] += perFluid[vd] / tau[f];
      }
    }
  }

  L.calculateDensities();

  // Divide by total densities.
  foreach(immutable p, ref wv; weightedVelocityBDist2) {
    double totalDensity = 0.0;
    foreach(density; L.density) {
      totalDensity += density[p];
    }
    foreach(immutable vd; Iota!(0, conn.d) ) {
      wv[vd] /= totalDensity;
    }
  }
}

