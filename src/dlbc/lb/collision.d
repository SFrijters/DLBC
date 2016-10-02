// Written in the D programming language.

/**
   Lattice Boltzmann collision for population fields.

   Copyright: Stefan Frijters 2011-2016

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters
*/

module dlbc.lb.collision;

import dlbc.fields.field;
import dlbc.hooks;
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

TVoidHooks!(LType, "preCollisionHooks") preCollisionHooks;
TVoidHooks!(LType, "postCollisionHooks") postCollisionHooks;

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

  startTimer("lb.coll.prep");
  if ( eqDistForm == EqDistForm.BDist2 ) {
    L.precalculateWeightedVelocity();
  }
  stopTimer("lb.coll.prep");
}

/**
   Let the populations of the field collide.

   Params:
     L = lattice
     tau = relaxation time
     globalAcc = global acceleration vector
*/
void collideFields(T)(ref T L, in double[] tau, in double[] globalAcc) if ( isLattice!T ) {

  if ( L.fluids.length == 0 ) return;

  startTimer("lb.coll.coll");

  // Run pre-collision hooks
  if ( preCollisionHooks.length > 0 ) {
    startTimer("pre");
    preCollisionHooks.execute(L);
    stopTimer("pre");
  }

  final switch(eqDistForm) {
    // Calls appropriate collideFieldEqDist
    mixin(edfMixin());
  }

  // Run post-collision hooks
  if ( postCollisionHooks.length > 0 ) {
    startTimer("post");
    postCollisionHooks.execute(L);
    stopTimer("post");
  }

  stopTimer("lb.coll.coll");
}

/// Ditto
private void collideFieldsKernel(EqDistForm eqDistForm, T)(ref T L, in double[] tau, in double[] globalAcc) if ( isLattice!T ) {
  assert(tau.length == L.fluids.length);
  assert(globalAcc.length == L.lbconn.d);

  alias conn = L.lbconn;

  L.precalculateDensities();

  foreach(immutable f; 0..L.fluids.length) {
    immutable omega = 1.0 / tau[f];
    foreach(immutable p, ref pop; L.fluids[f]) {
      if ( isCollidable(L.mask[p]) ) {
	assert(L.density[f].isFresh);
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
private void precalculateWeightedVelocity(T)(ref T L) if ( isLattice!T ) {
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

  L.precalculateDensities();

  // Divide by total densities.
  foreach(immutable p, ref wv; weightedVelocityBDist2) {
    double totalDensity = 0.0;
    foreach(immutable f; 0..L.density.length) {
      assert(L.density[f].isFresh);
      totalDensity += L.density[f][p];
    }
    foreach(immutable vd; Iota!(0, conn.d) ) {
      wv[vd] /= totalDensity;
    }
  }
}

unittest {
  version(D_Coverage) {
    cast(void) edfMixin();
  }
}

