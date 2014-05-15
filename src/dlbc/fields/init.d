module dlbc.fields.init;

import dlbc.fields.field;
import dlbc.logging;
import dlbc.parallel;
import dlbc.random;

import dlbc.range;

import std.traits;

import std.random;

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

void initRandom(T)(ref T field) {
  foreach( ref e; field.byElementForward) {
    static if ( isIterable!(typeof(e))) {
      foreach( ref c; e ) {
	c = uniform(0.0, 1.0, rng) / e.length;
      }
    }
    else {
      e = uniform(0.0, 1.0, rng);
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


