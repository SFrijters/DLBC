module dlbc.fields.init;

import dlbc.fields.field;
import dlbc.logging;
import dlbc.random;

import std.random;
import std.stdio;

void initRandom(T)(ref T field) {
  foreach( ref e; field.byElementForward) {
    foreach( ref c; e ) {
      c = uniform(0.0, 1.0, rng);
    }
  }
}

