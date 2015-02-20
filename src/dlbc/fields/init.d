// Written in the D programming language.

/**
   Helper functions to initialize generic fields.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

*/

module dlbc.fields.init;

import dlbc.fields.field;
import dlbc.lb.eqdist;
import dlbc.lb.mask;
import dlbc.lb.connectivity: Axis;
import dlbc.logging;
import dlbc.parallel;
import dlbc.random;

import dlbc.range;

import std.traits;

void initRank(T)(ref T field) @safe pure nothrow @nogc if ( isField!T ) {
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

void initConst(T, U)(ref T field, in U fill) @safe pure nothrow @nogc if ( isField!T ) {
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

void initConstRandom(T)(ref T field, in double fill) if ( isField!T ) {
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

void initEqDist(T)(ref T field, in double density) @safe nothrow @nogc if ( isField!T ) {
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

void initEqDistPerturb(T)(ref T field, in double density, in double perturb) if ( isField!T ) {
  import dlbc.lb.collision;
  import dlbc.lb.connectivity;
  alias conn = field.conn;
  double[conn.d] dv = 0.0;
  double[conn.q] pop0 = 0.0;
  pop0[0] = 1.0;
  foreach( ref e; field.byElementForward) {
    typeof(pop0) pop = (density + uniform(-perturb, perturb, rng) ) * eqDist!conn(pop0, dv)[];
    e = pop;
  }
}

void initEqDistPerturbFrac(T)(ref T field, in double density, in double perturb) if ( isField!T ) {
  import dlbc.lb.collision;
  import dlbc.lb.connectivity;
  alias conn = field.conn;
  double[conn.d] dv = 0.0;
  double[conn.q] pop0 = 0.0;
  pop0[0] = 1.0;
  foreach( ref e; field.byElementForward) {
    typeof(pop0) pop = density * (1.0 + uniform(-perturb, perturb, rng) ) * eqDist!conn(pop0, dv)[];
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

void initEqDistSphere(T)(ref T field, in double density1, in double density2,
                         in double initSphereRadius, in double[] initSphereOffset, in double interfaceThickness) if ( isField!T ) {
  import dlbc.lb.collision, dlbc.lb.connectivity, dlbc.range;
  import std.math, std.conv, std.numeric;
  alias conn = field.conn;

  immutable r = initSphereRadius;
  double[conn.q] pop0 = 0.0;
  pop0[0] = 1.0;
  double[conn.d] dv = 0.0;
  typeof(pop0) eqpop = eqDist!conn(pop0, dv)[];
  foreach(immutable p, ref e; field.arr) {
    double[conn.d] gn, offset;
    foreach(immutable i; Iota!(0, conn.d) ) {
      gn[i] = p[i] + M.c[i] * field.n[i] - to!double(field.haloSize);
      offset[i] = gn[i] - to!double(M.nc[i] * field.n[i] * 0.5 + initSphereOffset[i]) + 0.5;
    }
    immutable relpos = sqrt(offset.dotProduct(offset)) - r;
    e = relpos.symmetricLinearTransition(interfaceThickness, density1, density2)*eqpop[];
  }
}

void initEqDistSphereFrac(T)(ref T field, in double density1, in double density2,
                             in double initSphereFrac, in double[] initSphereOffset, in double interfaceThickness) if ( isField!T ) {
  import dlbc.lb.collision, dlbc.lb.connectivity, dlbc.range, dlbc.lattice;
  import std.math, std.conv, std.numeric;
  alias conn = field.conn;

  auto smallSize = gn[0];
  foreach(immutable i; 0..gn.length) {
    if ( gn[i] < smallSize ) {
      smallSize = gn[i];
    }
  }

  immutable r = initSphereFrac * smallSize;
  double[conn.q] pop0 = 0.0;
  pop0[0] = 1.0;
  double[conn.d] dv = 0.0;
  typeof(pop0) eqpop = eqDist!conn(pop0, dv)[];
  foreach(immutable p, ref e; field.arr) {
    double[conn.d] gn, offset;
    foreach(immutable i; Iota!(0, conn.d) ) {
      gn[i] = p[i] + M.c[i] * field.n[i] - to!double(field.haloSize);
      offset[i] = gn[i] - to!double(M.nc[i] * field.n[i] * ( 0.5 + initSphereOffset[i]) ) + 0.5;
    }
    immutable relpos = sqrt(offset.dotProduct(offset)) - r;
    e = relpos.symmetricLinearTransition(interfaceThickness, density1, density2)*eqpop[];
  }
}

void initEqDistCylinder(T)(ref T field, in double density1, in double density2, in Axis preferredAxis,
                           in double initSphereRadius, in double[] initSphereOffset, in double interfaceThickness) if ( isField!T ) {
  import dlbc.lb.collision, dlbc.lb.connectivity, dlbc.range;
  import std.math, std.conv, std.numeric;
  alias conn = field.conn;

  immutable r = initSphereRadius;
  double[conn.q] pop0 = 0.0;
  pop0[0] = 1.0;
  double[conn.d] dv = 0.0;
  typeof(pop0) eqpop = eqDist!conn(pop0, dv)[];
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
    immutable relpos = sqrt(offset.dotProduct(offset)) - r;
    e = relpos.symmetricLinearTransition(interfaceThickness, density1, density2)*eqpop[];
  }
}

void initEqDistCylinderFrac(T)(ref T field, in double density1, in double density2, in Axis preferredAxis,
                               in double initSphereFrac, in double[] initSphereOffset, in double interfaceThickness) if ( isField!T ) {
  import dlbc.lb.collision, dlbc.lb.connectivity, dlbc.range, dlbc.lattice;
  import std.math, std.conv, std.numeric;
  alias conn = field.conn;

  size_t smallSize = 0;
  foreach(immutable i; 0..gn.length) {
    if ( i != to!int(preferredAxis) ) {
      if ( gn[i] < smallSize || smallSize == 0 ) {
        smallSize = gn[i];
      }
    }
  }

  immutable r = initSphereFrac * smallSize;
  double[conn.q] pop0 = 0.0;
  pop0[0] = 1.0;
  double[conn.d] dv = 0.0;
  typeof(pop0) eqpop = eqDist!conn(pop0, dv)[];
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
    immutable relpos = sqrt(offset.dotProduct(offset)) - r;
    e = relpos.symmetricLinearTransition(interfaceThickness, density1, density2)*eqpop[];
  }
}

void initEqDistWall(T, U)(ref T field, in double density, ref U mask) if ( isField!T && isMaskField!U ) {
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

void initEqDistLamellae(T, U)(ref T field, in U[] values, in double[] widths, in Axis preferredAxis, in double interfaceThickness) if ( isField!T ) {
  import std.math: abs;
  import std.algorithm: sum;
  assert(widths.length == values.length);

  alias conn = field.conn;
  double[conn.q] pop0 = 0.0;
  pop0[0] = 1.0;
  double[conn.d] dv = 0.0;
  typeof(pop0) eqpop = eqDist!conn(pop0, dv)[];

  size_t ax = to!int(preferredAxis);

  auto interfaces = [0.0 ] ~ widths.dup;
  foreach(immutable i, ref w; interfaces) {
    if ( i > 0 ) {
      w += interfaces[i-1];
    }
  }
  interfaces[] -= 0.5;

  foreach(immutable p, ref e; field.arr) {
    double gp = p[ax] + M.c[ax] * field.n[ax] - to!double(field.haloSize);
    ptrdiff_t closestInterface;
    double minDiff;
    foreach(immutable i, ref w; interfaces) {
      if ( i == 0 ) {
        minDiff = abs(interfaces[i] - gp);
        closestInterface = i;
      }
      else {
        double diff = abs(interfaces[i] - gp);
        if ( diff < minDiff ) {
          minDiff = diff;
          closestInterface = i;
        }
      }
    }

    minDiff = gp - interfaces[closestInterface];
    if ( closestInterface == 0 ) {
      e = minDiff.symmetricLinearTransition(interfaceThickness, values[$-1], values[closestInterface])*eqpop[];
    }
    else if ( closestInterface == values.length ) {
      e = minDiff.symmetricLinearTransition(interfaceThickness, values[closestInterface-1], values[0])*eqpop[];
    }
    else {
      e = minDiff.symmetricLinearTransition(interfaceThickness, values[closestInterface-1], values[closestInterface])*eqpop[];
    }
  }
}


void initEqDistLamellaeFrac(T, U)(ref T field, in U[] values, in double[] widthsFrac, in Axis preferredAxis, in double interfaceThickness) if ( isField!T ) {
  import std.math: abs;
  import std.algorithm: sum;
  assert(widthsFrac.length == values.length);

  alias conn = field.conn;
  double[conn.q] pop0 = 0.0;
  pop0[0] = 1.0;
  double[conn.d] dv = 0.0;
  typeof(pop0) eqpop = eqDist!conn(pop0, dv)[];

  size_t ax = to!int(preferredAxis);

  auto interfaces = [0.0 ] ~ widthsFrac.dup;
  foreach(immutable i, ref w; interfaces ) {
    import dlbc.lattice: gn;
    interfaces[i] *= gn[ax]; // Fractional
    if ( i > 0 ) {
      w += interfaces[i-1];
    }
  }
  interfaces[] -= 0.5;

  foreach(immutable p, ref e; field.arr) {
    double gp = p[ax] + M.c[ax] * field.n[ax] - to!double(field.haloSize);
    ptrdiff_t closestInterface;
    double minDiff;
    foreach(immutable i, ref w; interfaces) {
      if ( i == 0 ) {
        minDiff = abs(interfaces[i] - gp);
        closestInterface = i;
      }
      else {
        double diff = abs(interfaces[i] - gp);
        if ( diff < minDiff ) {
          minDiff = diff;
          closestInterface = i;
        }
      }
    }

    minDiff = gp - interfaces[closestInterface];
    if ( closestInterface == 0 ) {
      e = minDiff.symmetricLinearTransition(interfaceThickness, values[$-1], values[closestInterface])*eqpop[];
    }
    else if ( closestInterface == values.length ) {
      e = minDiff.symmetricLinearTransition(interfaceThickness, values[closestInterface-1], values[0])*eqpop[];
    }
    else {
      e = minDiff.symmetricLinearTransition(interfaceThickness, values[closestInterface-1], values[closestInterface])*eqpop[];
    }
  }
}

/// Only inits physical sites!
void initLamellae(T, U)(ref T field, in U[] values, in ptrdiff_t[] widths, in Axis preferredAxis) if ( isField!T ) {
  assert(widths.length == values.length);
  size_t i = to!int(preferredAxis);
  foreach(immutable p, ref e; field) {
    auto gp = p[i] + M.c[i] * field.n[i] - field.haloSize;
    e = values[gp.findLamella(widths)];
  }
}

private ptrdiff_t findLamella(in ptrdiff_t pos, in double[] widths) @safe pure {
  import std.math;
  ptrdiff_t i = 0;
  ptrdiff_t upper = to!ptrdiff_t(floor(widths[0]));
  while ( pos > upper ) {
    i++;
    upper += widths[i];
  }
  return i;
}

private ptrdiff_t findLamella(in ptrdiff_t pos, in ptrdiff_t[] widths) @safe pure nothrow @nogc {
  import std.math;
  ptrdiff_t i = 0;
  ptrdiff_t upper = widths[0];
  while ( pos >= upper ) {
    i++;
    upper += widths[i];
  }
  return i;
}

private U symmetricLinearTransition(T, U)(in T pos, in T width, in U negval, in U posval) @safe pure nothrow @nogc {
  if ( width == 0.0 ) {
    if ( pos < 0 ) {
      return negval;
    }
    else {
      return posval;
    }
  }
  else {
    if ( pos < -0.5*width ) {
      return negval;
    }
    else if ( pos > 0.5*width ) {
      return posval;
    }
    else {
      return ( negval * ( 0.5 - pos / width ) + posval * ( 0.5 + pos / width ) );
    }
  }
}

