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
import dlbc.lb.thermal;
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
     dim = dimensionality of the lattice
*/
struct Lattice(uint dim) {

  private enum Exchange;

  enum uint dimensions = dim;

  private {
    size_t[dim] _lengths;
    size_t[dim] _gn;
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

  alias lbconn = gconn;

  /**
     Fluid fields.
  */
  @Exchange Field!(double[lbconn.q], lbconn, 2)[] fluids;
  /**
     Mask field.
  */
  @Exchange MaskFieldOf!(typeof(fluids)) mask;
  /**
     Temporary fields to store densities.
  */
  ScalarFieldOf!(typeof(fluids))[] density;
  /**
     Force fields.
  */
  VectorFieldOf!(typeof(fluids))[] force;
  /**
     Temporary field to store advected fluids.
  */
  BaseElementType!(typeof(fluids)) advection;
  /**
     Thermal population field.
  */
  @Exchange Field!(double[tconn.q], tconn, 2) thermal;
  /**
     Temporary field to store advected thermal populations.
  */
  typeof(thermal) advThermal;

  /**
     The constructor will verify that the local lattices can be set up correctly
     with respect to the parallel decomposition, and allocate the fields.
  */
  this ( MpiParams M ) {
    import dlbc.parameters: checkArrayParameterLength;
    import std.conv: to;

    checkArrayParameterLength(.gn, "lattice.gn", dimensions, true);
    checkArrayParameterLength(fieldNames, "lb.fieldNames", components, true);

    _gn = .gn;

    // Check if we can reconcile global lattice size with CPU grid
    if (! canDivide(gn, M.nc) ) {
      writeLogF("Cannot divide lattice %s evenly over a %s grid of processes.", makeLengthsString(gn), makeLengthsString(M.nc));
    }

    // Set the local sizes
    foreach(immutable i; Iota!(0, dimensions) ) {
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

    if ( enableThermal ) {
      thermal = typeof(thermal)(lengths);
      advThermal = typeof(advThermal)(lengths);
    }
  }

  private static bool isExchangeField (string field)() @safe pure nothrow {
    import std.typetuple;
    alias attrs = TypeTuple!(__traits(getAttributes, mixin("Lattice."  ~ field)));
    return staticIndexOf!(Exchange, attrs) != -1;
  }

  /**
     Calls exchangeHalo on all member fields of the lattice.

     Todo: implement UDA to only exchange necessary fields when this function is called.
  */
  void exchangeHalo() {
    import std.algorithm: startsWith;
    import std.traits;
    foreach(e ; __traits(derivedMembers, Lattice)) {
      static if (isExchangeField!(e)) {
        static if (isField!(typeof(mixin(e))) ) {
          mixin(e~".exchangeHalo!()();");
        }
        else {
          foreach(ref f; mixin(e) ) {
            f.exchangeHalo!()();
          }
        }
      }
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
   Template to check if a type is a lattice.
*/
template isLattice(T) {
  enum isLattice = is(T:Lattice!(dim), uint dim);
}

/**
   Initialization of the lattice: initialize the force arrays, and the fluids and mask,
   unless we are restoring, in which case read the checkpoint.

   Params:
     L = the lattice
*/
void initLattice(T)(ref T L) if (isLattice!T) {
  L.initForce();

  if ( isRestoring() ) {
    L.readCheckpoint();
    L.exchangeHalo();
  }
  else {
    L.mask.initMask();
    foreach(immutable i, ref e; L.fluids) {
      e.initFluid(i);
      // Coloured walls.
      import dlbc.fields.init: initEqDistWall;
      e.initEqDistWall(1.0, L.mask);
    }
    L.initThermal();
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
private bool canDivide(const size_t[] gn, const int[] nc) @safe pure nothrow {
  assert(gn.length == nc.length);
  foreach(immutable i, g; gn) {
    if ( g % nc[i] != 0 ) {
      return false;
    }
  }
  return true;
}

