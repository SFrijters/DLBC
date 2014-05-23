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
  

void initTubeZ(T)(ref T field) {
  static assert( is (T.type == Mask ) );

  foreach( x,y,z, ref e; field.arr) {
    auto gx = x + M.cx * field.nx - field.haloSize;
    auto gy = y + M.cy * field.ny - field.haloSize;
    auto gz = z + M.cz * field.nz - field.haloSize;

    if ( gx == 0 || gx == (field.nx * M.ncx - 1) || gy == 0 || gy == (field.ny * M.ncy - 1 ) ) {
      e = Mask.Solid;
    }
    else {
      e = Mask.None;
    }
  }
}

void initWallsX(T)(ref T field) {
  static assert( is (T.type == Mask ) );

  foreach( x,y,z, ref e; field.arr) {
    auto gx = x + M.cx * field.nx - field.haloSize;
    auto gy = y + M.cy * field.ny - field.haloSize;
    auto gz = z + M.cz * field.nz - field.haloSize;

    if ( gx == 0 || gx == (field.nx * M.ncx - 1) ) {
      e = Mask.Solid;
    }
    else {
      e = Mask.None;
    }
  }
}



