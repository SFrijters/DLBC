import field;
import logging;
import parameters;
import parallel;

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

  Field!(int, dim) red;
  Field!(double, dim, 19) blue;

  this ( MpiParams M, ParameterSet P ) {
    // Check if we can reconcile global lattice size with CPU grid
    if (P.nx % M.ncx != 0 || P.ny % M.ncy != 0 || P.nz % M.ncz != 0) {
      writeLogF("Cannot divide lattice %d x %d x %d  evenly over %d x %d x %d grid of processes.", P.nx, P.ny, P.nz, M.ncx, M.ncy, M.ncz);
    }

    // Calculate local lattice size
    int nx = cast(int) (P.nx / M.ncx);
    int ny = cast(int) (P.ny / M.ncy);
    int nz = cast(int) (P.nz / M.ncz);

    this._lengths[0] = nx;
    this._lengths[1] = ny;
    this._lengths[2] = nz;

    // Check for bogus halo
    if (P.haloSize < 1) {
      writeLogF("Halo size < 1 not allowed.");
    }

    blue = Field!(double, dim, 19)(lengths, P.haloSize);
    red = Field!(int, dim)(lengths, P.haloSize);
  }

  void haloExchange() {
    import std.algorithm: startsWith;
    foreach(e ; __traits(derivedMembers, Lattice)) {
      mixin(`static if(typeof(Lattice.`~e~`).stringof.startsWith("Field!")) { `~e~`.haloExchange();};`);
    }
  }
}


