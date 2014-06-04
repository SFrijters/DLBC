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
  private size_t _dimensions = conn.d;
  private size_t[conn.d] _lengths;

  private size_t[conn.d] _gn;

  /**
     Dimensions of the lattice.
  */
  @property auto dimensions() {
    return _dimensions;
  }
  /**
     Size of the local lattice.
  */
  @property auto lengths() {
    return _lengths;
  }

  /**
     Size of the local lattice in x-direction.
  */
  @property auto nx() {
    return _lengths[0];
  }

  /**
     Size of the local lattice in y-direction.
  */
  @property auto ny() {
    return _lengths[1];
  }

  /**
     Size of the local lattice in z-direction.
  */
  @property auto nz() {
    return _lengths[2];
  }

  /**
     Vector containing the size of the global lattice
  */
  @property auto gn() {
    return _gn;
  }

  /**
     Size of the global lattice in x-direction.
  */
  @property auto gnx() {
    return _gn[0];
  }

  /**
     Size of the global lattice in y-direction.
  */
  @property auto gny() {
    return _gn[1];
  }

  static if ( conn.d > 2 ) {
    /**
       Number of processes in z-direction.
    */
    @property auto gnz() {
      return _gn[2];
    }
  }

  /**
     Fluid fields.
  */
  Field!(double[conn.q], conn.d, 2)[] fluids;
  /**
     Temporary field to store advected fluids.
  */
  BaseElementType!(typeof(fluids)) advection;
  /**
     Mask field
  */
  Field!(Mask, conn.d, 2) mask;
  /**
     Density field
  */
  Field!(double, conn.d, 2) density;
  /**
     Force field
  */
  Field!(double[conn.d], conn.d, 2)[] force;

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
    if (gn[0] % M.nc[0] != 0 || gn[1] % M.nc[1] != 0 || gn[2] % M.nc[2] != 0) {
      writeLogF("Cannot divide lattice %s evenly over a %s grid of processes.", makeLengthsString(gn), makeLengthsString(M.nc));
    }

    // Set the local sizes
    for ( size_t i = 0; i < conn.d; i++ ) {
      this._lengths[i] = to!int(gn[i] / M.nc[i]);
    }

    // Determine number of fluid arrays
    fluids.length = components;
    force.length = components;

    // Initialize arrays
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
}

void initLattice(T)(ref T L) {
  L.initForce!gconn();

  if ( isRestoring() ) {
    L.readCheckpoint();
    L.exchangeHalo();
  }
  else {
    foreach(i, ref e; L.fluids) {
      e.initFluid!gconn(i);
    }
    L.mask.initMask();
    L.exchangeHalo();
  }
}


