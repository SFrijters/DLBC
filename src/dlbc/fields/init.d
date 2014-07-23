module dlbc.fields.init;

import dlbc.fields.field;
import dlbc.lb.mask;
import dlbc.lb.connectivity: Axis;
import dlbc.logging;
import dlbc.parallel;
import dlbc.random;

import dlbc.range;

import std.traits;

void initRank(T)(ref T field) if ( isField!T ) {
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

void initConst(T, U)(ref T field, const U fill) if ( isField!T ) {
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

void initConstRandom(T)(ref T field, const double fill) if ( isField!T ) {
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

void initEqDist(T)(ref T field, const double density) if ( isField!T ) {
  import dlbc.lb.collision;
  import dlbc.lb.connectivity;
  alias conn = field.conn;
  double[conn.q] pop0 = 0.0;
  pop0[0] = 1.0;
  double[conn.d] dv = 0.0;
  typeof(pop0) pop = density*eqDist!conn(pop0, dv)[];
  foreach( ref e; field.byElementForward) {
    e = pop;
  }
}

void initEqDistRandom(T)(ref T field, const double density) if ( isField!T ) {
  import dlbc.lb.collision;
  import dlbc.lb.connectivity;
  alias conn = field.conn;
  double[conn.q] pop0;
  double[conn.d] dv = 0.0;
  foreach( ref e; field.byElementForward) {
    pop0 = 0.0;
    pop0[0] = uniform(0.0, 2.0, rng);
    e = density*eqDist!conn(pop0, dv)[];
  }
}

void initEqDistSphere(T)(ref T field, const double density1, const double density2,
                                     const double initSphereRadius, const double[] initSphereOffset) if ( isField!T ) {
  import dlbc.lb.collision, dlbc.lb.connectivity, dlbc.range;
  import std.math, std.conv, std.numeric;
  alias conn = field.conn;
  immutable r2 = initSphereRadius * initSphereRadius;
  double[conn.q] pop0 = 0.0;
  pop0[0] = 1.0;
  double[conn.d] dv = 0.0;
  typeof(pop0) pop1 = density1*eqDist!conn(pop0, dv)[];
  typeof(pop0) pop2 = density2*eqDist!conn(pop0, dv)[];
  foreach(immutable p, ref e; field.arr) {
    double[conn.d] gn, offset;
    foreach(immutable i; Iota!(0, conn.d) ) {
      gn[i] = p[i] + M.c[i] * field.n[i] - to!double(field.haloSize);
      offset[i] = gn[i] - to!double(M.nc[i] * field.n[i] * 0.5 + initSphereOffset[i]) + 0.5;
    }
    if ( offset.dotProduct(offset) < r2 ) {
      e = pop1;
    }
    else {
      e = pop2;
    }
  }
}

void initEqDistSphereFrac(T)(ref T field, const double density1, const double density2,
                                         const double initSphereFrac, const double[] initSphereOffset) if ( isField!T ) {
  import dlbc.lb.collision, dlbc.lb.connectivity, dlbc.range, dlbc.lattice;
  import std.math, std.conv, std.numeric;
  alias conn = field.conn;
  auto smallSize = gn[0];
  foreach(immutable i; 0..gn.length) {
    if ( gn[i] < smallSize ) {
      smallSize = gn[i];
    }
  }
  immutable r2 = initSphereFrac * initSphereFrac * smallSize * smallSize;
  double[conn.q] pop0 = 0.0;
  pop0[0] = 1.0;
  double[conn.d] dv = 0.0;
  typeof(pop0) pop1 = density1*eqDist!conn(pop0, dv)[];
  typeof(pop0) pop2 = density2*eqDist!conn(pop0, dv)[];
  foreach(immutable p, ref e; field.arr) {
    double[conn.d] gn, offset;
    foreach(immutable i; Iota!(0, conn.d) ) {
      gn[i] = p[i] + M.c[i] * field.n[i] - to!double(field.haloSize);
      offset[i] = gn[i] - to!double(M.nc[i] * field.n[i] * ( 0.5 + initSphereOffset[i]) ) + 0.5;
    }
    if ( offset.dotProduct(offset) < r2 ) {
      e = pop1;
    }
    else {
      e = pop2;
    }
  }
}

void initEqDistCylinder(T)(ref T field, const double density1, const double density2, const Axis preferredAxis,
                                     const double initSphereRadius, const double[] initSphereOffset) if ( isField!T ) {
  import dlbc.lb.collision, dlbc.lb.connectivity, dlbc.range;
  import std.math, std.conv, std.numeric;
  alias conn = field.conn;
  immutable r2 = initSphereRadius * initSphereRadius;
  double[conn.q] pop0 = 0.0;
  pop0[0] = 1.0;
  double[conn.d] dv = 0.0;
  typeof(pop0) pop1 = density1*eqDist!conn(pop0, dv)[];
  typeof(pop0) pop2 = density2*eqDist!conn(pop0, dv)[];
  foreach(immutable p, ref e; field.arr) {
    double[conn.d] gn, offset;
    foreach(immutable i; Iota!(0, conn.d) ) {
      if ( i == to!int(preferredAxis) ) {
        offset[i] = 0.0;
      }
      else {
        gn[i] = p[i] + M.c[i] * field.n[i] - to!double(field.haloSize);
        offset[i] = gn[i] - to!double(M.nc[i] * field.n[i] * 0.5 + initSphereOffset[i]) + 0.5;
      }
    }
    if ( offset.dotProduct(offset) < r2 ) {
      e = pop1;
    }
    else {
      e = pop2;
    }
  }
}

void initEqDistCylinderFrac(T)(ref T field, const double density1, const double density2, const Axis preferredAxis,
                                         const double initSphereFrac, const double[] initSphereOffset) if ( isField!T ) {
  import dlbc.lb.collision, dlbc.lb.connectivity, dlbc.range, dlbc.lattice;
  import std.math, std.conv, std.numeric;

  alias conn = field.conn;
  size_t smallSize = 0;
  foreach(immutable i; 0..gn.length) {
    if ( i != to!int(preferredAxis) ) {
      if ( gn[i] < smallSize || smallSize == 0  ) {
        smallSize = gn[i];
      }
    }
  }
  immutable r2 = initSphereFrac * initSphereFrac * smallSize * smallSize;
  double[conn.q] pop0 = 0.0;
  pop0[0] = 1.0;
  double[conn.d] dv = 0.0;
  typeof(pop0) pop1 = density1*eqDist!conn(pop0, dv)[];
  typeof(pop0) pop2 = density2*eqDist!conn(pop0, dv)[];
  foreach(immutable p, ref e; field.arr) {
    double[conn.d] gn, offset;
    foreach(immutable i; Iota!(0, conn.d) ) {
      if ( i == to!int(preferredAxis) ) {
        offset[i] = 0.0;
      }
      else {
        gn[i] = p[i] + M.c[i] * field.n[i] - to!double(field.haloSize);
        offset[i] = gn[i] - to!double(M.nc[i] * field.n[i] * ( 0.5 + initSphereOffset[i]) ) + 0.5;
      }
    }
    if ( offset.dotProduct(offset) < r2 ) {
      e = pop1;
    }
    else {
      e = pop2;
    }
  }
}

void initEqDistWall(T, U)(ref T field, const double density, ref U mask) if ( isField!T && isMaskField!U ) {
  import dlbc.lb.collision;
  import dlbc.lb.connectivity;
  import dlbc.lb.mask;
  alias conn = field.conn;
  foreach(immutable p, ref e; field.arr) {
    if ( mask[p] == Mask.Solid ) {
      e = 0.0;
      e[0] = density;
    }
  }
}

