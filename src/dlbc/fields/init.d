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

void initConstRandom(T)(ref T field, const double fill) {
  foreach( ref e; field.byElementForward) {
    static if ( isIterable!(typeof(e))) {
      foreach( ref c; e ) {
	c = fill * uniform(0.0, 2.0, rng);
      }
    }
    else {
      e = fill * uniform(0.0, 2.0, rng);
    }
  }
}

void initEqDist(alias conn, T)(ref T field, const double density) {
  import dlbc.lb.collision;
  import dlbc.lb.connectivity;
  double[conn.q] pop0 = 0.0;
  pop0[0] = 1.0;
  double[conn.d] dv = 0.0;
  typeof(pop0) pop = density*eqDist!conn(pop0, dv)[];
  foreach( ref e; field.byElementForward) {
    e = pop;
  }
}

void initEqDistRandom(alias conn, T)(ref T field, const double density) {
  import dlbc.lb.collision;
  import dlbc.lb.connectivity;
  double[conn.q] pop0;
  double[conn.d] dv = 0.0;
  foreach( ref e; field.byElementForward) {
    pop0 = 0.0;
    pop0[0] = uniform(0.0, 2.0, rng);
    e = density*eqDist!conn(pop0, dv)[];
  }
}

void initEqDistSphere(alias conn, T)(ref T field, const double density1, const double density2, const double initSphereRadius) {
  import dlbc.lb.collision;
  import dlbc.lb.connectivity;
  import std.math;
  import std.conv: to;
  double[conn.q] pop0 = 0.0;
  pop0[0] = 1.0;
  double[conn.d] dv = 0.0;
  typeof(pop0) pop1 = density1*eqDist!conn(pop0, dv)[];
  typeof(pop0) pop2 = density2*eqDist!conn(pop0, dv)[];
  static if ( field.dimensions == 3 ) {
    foreach( x, y, z, ref e; field.arr) {
      auto gx = x + M.c[0] * field.nx - to!double(field.haloSize);
      auto gy = y + M.c[1] * field.ny - to!double(field.haloSize);
      auto gz = z + M.c[2] * field.nz - to!double(field.haloSize);
      auto ox = gx - to!double(M.nc[0] * field.nx / 2);
      auto oy = gy - to!double(M.nc[1] * field.ny / 2);
      auto oz = gz - to!double(M.nc[2] * field.nz / 2);
      double offset = sqrt(ox*ox + oy*oy + oz*oz);
      if ( offset < initSphereRadius ) {
	e = pop1;
      }
      else {
	e = pop2;
      }
    }
  }
  else static if ( field.dimensions == 2 ) {
    foreach( x, y, ref e; field.arr) {
      auto gx = x + M.c[0] * field.nx - to!double(field.haloSize);
      auto gy = y + M.c[1] * field.ny - to!double(field.haloSize);
      auto ox = gx - to!double(M.nc[0] * field.nx / 2);
      auto oy = gy - to!double(M.nc[1] * field.ny / 2);
      double offset = sqrt(ox*ox + oy*oy);
      if ( offset < initSphereRadius ) {
	e = pop1;
      }
      else {
	e = pop2;
      }
    }
  }
  else {
    assert(0, "initEqDistSphere not implemented for field.dimensions != 2 or 3.");
  }
}

