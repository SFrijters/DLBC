module dlbc.fields.init;

import dlbc.fields.field;
import dlbc.lb.mask;
import dlbc.logging;
import dlbc.parallel;
import dlbc.random;

import dlbc.range;

import std.traits;

void initRank(T)(ref T field) {
  foreach( ref e; field.byElementForward) {
    static if ( isIterable!(typeof(e))) {
      foreach( ref c; e ) {
	c = M.rank;
      }
    }
    else {
      e = M.rank;
    }
  }
}

void initRandom(T)(ref T field, const double fill = 1.0) {
  foreach( ref e; field.byElementForward) {
    static if ( isIterable!(typeof(e))) {
      foreach( ref c; e ) {
	c = fill * uniform(0.0, 2.0, rng) / e.length;
      }
    }
    else {
      e = fill * uniform(0.0, 2.0, rng);
    }
  }
}

void initConst(T, U)(ref T field, const U fill) {
  foreach( ref e; field.byElementForward) {
    static if ( isIterable!(typeof(e))) {
      foreach( ref c; e ) {
	c = fill;
      }
    }
    else {
      e = fill;
    }
  }
}

void initEquilibriumDensity(alias conn, T)(ref T field, const double density) {
  import dlbc.lb.collision;
  import dlbc.lb.connectivity;
  double[conn.q] pop0 = [ 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
				    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  double[conn.d] dv = 0.0;
  typeof(pop0) pop = density*eqDist!conn(pop0, dv)[];
  foreach( ref e; field.byElementForward) {
    e = pop;
  }
}

void initRandomEquilibriumDensity(alias conn, T)(ref T field, const double density) {
  import dlbc.lb.collision;
  import dlbc.lb.connectivity;
  double[conn.q] pop0;
  double[conn.d] dv = 0.0;
  foreach( ref e; field.byElementForward) {
    pop0 = [ uniform(0.0, 2.0, rng), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
	     0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    e = density*eqDist!conn(pop0, dv)[];
  }
}

