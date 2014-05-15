module dlbc.lattice;

import dlbc.fields.field;
import dlbc.logging;
import dlbc.parallel;

@("param") int gnx;
@("param") int gny;
@("param") int gnz;

struct Lattice(uint dim) {
  private uint _dimensions = dim;
  private uint[dim] _lengths;

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

  Field!(double[19], dim, 2) red;
  Field!(double[19], dim, 2) temp;
  Field!(int, dim, 1) index;

  this ( MpiParams M ) {
    // Check if we can reconcile global lattice size with CPU grid
    if (gnx % M.ncx != 0 || gny % M.ncy != 0 || gnz % M.ncz != 0) {
      writeLogF("Cannot divide lattice %d x %d x %d  evenly over %d x %d x %d grid of processes.", gnx, gny, gnz, M.ncx, M.ncy, M.ncz);
    }

    // Calculate local lattice size
    int nx = cast(int) (gnx / M.ncx);
    int ny = cast(int) (gny / M.ncy);
    int nz = cast(int) (gnz / M.ncz);

    this._lengths[0] = nx;
    this._lengths[1] = ny;
    this._lengths[2] = nz;

    red = Field!(double[19], dim, 2)(lengths);
    temp = Field!(double[19], dim, 2)(lengths);
    index = Field!(int, dim, 1)(lengths);
  }

  void exchangeHalo() {
    import std.algorithm: startsWith;
    foreach(e ; __traits(derivedMembers, Lattice)) {
      mixin(`static if(typeof(Lattice.`~e~`).stringof.startsWith("Field!")) { `~e~`.exchangeHalo!()();};`);
    }
  }
}


