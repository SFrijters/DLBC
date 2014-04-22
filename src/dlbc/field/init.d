module dlbc.field.init;

import dlbc.field.field;
import dlbc.logging;
import dlbc.random;

import std.random;
import std.stdio;

void initRandom(T)(ref T field) {
  foreach( ref e; field.byElementForward) {
    e = uniform(0.0, 1.0, rng);
  }
}

