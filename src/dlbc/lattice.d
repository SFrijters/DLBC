// Written in the D programming language.

/**
   The lattice implementation of lattice Boltzmann.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.lattice;

import dlbc.fields.field;
import dlbc.fields.parallel;
import dlbc.io.checkpoint;
import dlbc.lb.lb;
import dlbc.lb.mask;
import dlbc.logging;
import dlbc.parallel;
import dlbc.range;

/**
   Global size of the lattice.
*/
@("param") size_t[] gn;

/**
   The lattice struct holds various fields, and information on the shape of these fields.

   Params:
     conn = connecvitiy of the fluid fields
*/
struct Lattice(alias conn) {

  enum uint dimensions = conn.d;

  private {
    size_t[conn.d] _lengths;
    size_t[conn.d] _gn;
    size_t _size = 1;
    size_t _gsize = 1;
  }

  /**
     Size of the local lattice.
  */
  @property const lengths() {
    return _lengths;
  }
  /// Ditto
  alias n = lengths;

  /**
     Vector containing the size of the global lattice
  */
  @property const gn() {
    return _gn;
  }

  /**
     Number of physical sites of the local lattice.
  */
  @property const size() {
    return _size;
  }

  /**
     Number of physical sites of the local lattice.
  */
  @property const gsize() {
    return _gsize;
  }

  /**
     Fluid fields.
  */
  Field!(double[conn.q], conn.d, 2)[] fluids;
  /**
     Mask field.
  */
  Field!(Mask, conn.d, 2) mask;
  /**
     Temporary fields to store densities.
  */
  Field!(double, conn.d, 2)[] density;
  /**
     Force fields.
  */
  Field!(double[conn.d], conn.d, 2)[] force;
  /**
     Temporary field to store advected fluids.
  */
  BaseElementType!(typeof(fluids)) advection;

  /**
     The constructor will verify that the local lattices can be set up correctly
     with respect to the parallel decomposition, and allocate the fields.
  */
  this ( MpiParams M ) {
    import dlbc.parameters: checkVectorParameterLength;
    import std.conv: to;

    checkVectorParameterLength(.gn, "lattice.gn", dimensions, true);
    checkVectorParameterLength(fieldNames, "lb.fieldNames", components, true);

    _gn = .gn;

    // Check if we can reconcile global lattice size with CPU grid
    if (! canDivide(gn, M.nc) ) {
      writeLogF("Cannot divide lattice %s evenly over a %s grid of processes.", makeLengthsString(gn), makeLengthsString(M.nc));
    }

    // Set the local sizes
    foreach(immutable i; Iota!(0, conn.d) ) {
      this._lengths[i] = to!int(gn[i] / M.nc[i]);
    }

    // Determine number of fluid arrays
    fluids.length = components;
    force.length = components;
    density.length = components;

    // Initialize arrays
    foreach(ref e; fluids ) {
      e = typeof(e)(lengths);
    }
    foreach(ref e; force ) {
      e = typeof(e)(lengths);
    }
    foreach(ref e; density ) {
      e = typeof(e)(lengths);
    }
    mask = typeof(mask)(lengths);
    advection = typeof(advection)(lengths);
  }

  /**
     Calls exchangeHalo on all member fields of the lattice.

     Todo: implement UDA to only exchange necessary fields when this function is called.
  */
  void exchangeHalo() {
    import std.algorithm: startsWith;
    import std.traits;
    foreach(e ; __traits(derivedMembers, Lattice)) {
      mixin(`static if(typeof(Lattice.`~e~`).stringof.startsWith("Field!")) { static if (isArray!(typeof(Lattice.`~e~`)) ) { foreach(ref f; Lattice.`~e~`) { f.exchangeHalo!()();} } else {`~e~`.exchangeHalo!()();}}`);
    }
  }

  /**
     Fills the lattice density arrays by recomputing the values from the populations.
  */
  void calculateDensity() {
    foreach(immutable nc1; 0..fluids.length ) {
      fluids[nc1].densityField(mask, density[nc1]);
    }
  }
}

/**
   Initialization of the lattice: initialize the force arrays, and the fluids and mask,
   unless we are restoring, in which case read the checkpoint.

   Params:
     L = the lattice
*/
void initLattice(T)(ref T L) {
  L.initForce!gconn();

  if ( isRestoring() ) {
    L.readCheckpoint();
    L.exchangeHalo();
  }
  else {
    foreach(immutable i, ref e; L.fluids) {
      e.initFluid!gconn(i);
    }
    L.mask.initMask();
    L.exchangeHalo();
  }
}

/**
   Check if all global lattice lengths are divisible by
   the number of processes in that direction.

   Params:
     gn = global lattice size
     nc = number of processes
*/
private bool canDivide(const size_t[] gn, const int[] nc) {
  assert(gn.length == nc.length);
  foreach(immutable i, g; gn) {
    if ( g % nc[i] != 0 ) {
      return false;
    }
  }
  return true;
}

