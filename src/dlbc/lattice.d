module dlbc.lattice;

import dlbc.fields.field;
import dlbc.fields.parallel;
import dlbc.lb.lb;
import dlbc.lb.mask;
import dlbc.logging;
import dlbc.parallel;
import dlbc.range;

@("param") int gnx;
@("param") int gny;
@("param") int gnz;

struct Lattice(alias conn) {
  private size_t _dimensions = conn.d;
  private size_t[conn.d] _lengths;

  @property auto dimensions() {
    return _dimensions;
  }

  @property auto lengths() {
    return _lengths;
  }

  @property auto nx() {
    return _lengths[0];
  }

  @property auto ny() {
    return _lengths[1];
  }

  @property auto nz() {
    return _lengths[2];
  }

  @("field") Field!(double, conn.d, 2) density;
  @("field") Field!(Mask, conn.d, 2) mask;

  @("field") Field!(double[conn.q], conn.d, 2)[] fluids;
  BaseElementType!(typeof(fluids)) advection;

  @("field") Field!(double[conn.d], conn.d, 2)[] force;

  this ( MpiParams M ) {
    import std.conv: to;
    // Check if we can reconcile global lattice size with CPU grid
    if (gnx % M.ncx != 0 || gny % M.ncy != 0 || gnz % M.ncz != 0) {
      writeLogF("Cannot divide lattice %d x %d x %d evenly over a %s grid of processes.", gnx, gny, gnz, makeLengthsString(M.nc));
    }

    // Calculate local lattice size
    int nx = to!int(gnx / M.ncx);
    int ny = to!int(gny / M.ncy);
    int nz = to!int(gnz / M.ncz);

    this._lengths[0] = nx;
    this._lengths[1] = ny;
    this._lengths[2] = nz;

    fluids.length = components;
    force.length = components;

    if ( fieldNames.length != components ) {
      writeLogF("Parameter lb.fieldNames needs to have a number of values equal to lb.components.");
    }

    foreach( ref e; fluids ) {
      e = typeof(e)(lengths);
    }
    foreach( ref e; force ) {
      e = typeof(e)(lengths);
    }
    advection = typeof(advection)(lengths);
    density = typeof(density)(lengths);
    mask = typeof(mask)(lengths);

  }

  void exchangeHalo() {
    import std.algorithm: startsWith;
    import std.traits;
    foreach(e ; __traits(derivedMembers, Lattice)) {
      mixin(`static if(typeof(Lattice.`~e~`).stringof.startsWith("Field!")) { static if (isArray!(typeof(Lattice.`~e~`)) ) { foreach(ref f; Lattice.`~e~`) { f.exchangeHalo!()();} } else {`~e~`.exchangeHalo!()();}}`);
    }
  }
}


