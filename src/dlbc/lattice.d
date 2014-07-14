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

import dlbc.elec.elec;
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
struct Lattice(alias conn) {

  private enum Exchange;

  alias lbconn = conn;
  enum uint dimensions = conn.d;

  private {
    size_t[conn.d] _lengths;
    size_t[conn.d] _gn;
    string[] _fieldNames;
    MpiParams!(conn.d) _M;
    size_t _size = 1;
    size_t _gsize = 1;
  }

  /**
     Size of the local lattice.
  */
  @property const lengths() @safe pure nothrow {
    return _lengths;
  }
  /// Ditto
  alias n = lengths;
  /**
     Vector containing the size of the global lattice
  */
  @property const gn() @safe pure nothrow {
    return _gn;
  }
  /**
     Names of the fluid fields.
  */
  @property const fieldNames() @safe pure nothrow {
    return _fieldNames;
  }
  /**
     Number of physical sites of the local lattice.
  */
  @property const size() @safe pure nothrow {
    return _size;
  }
  /**
     Number of physical sites of the local lattice.
  */
  @property const gsize() @safe pure nothrow {
    return _gsize;
  }


  /**
     Parallelization properties.
  */
  @property const M() @safe pure nothrow {
    return _M;
  }

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
     Density of positive ions (used by elec only).
  */
  @Exchange ScalarFieldOf!(typeof(fluids)) elQp;
  /**
     Density of negative ions (used by elec only).
  */
  @Exchange ScalarFieldOf!(typeof(fluids)) elQn;
  /**
     Electric potential (used by elec only).
  */
  @Exchange ScalarFieldOf!(typeof(fluids)) elPot;
  /**
     Dielectric constant (used by elec only).
  */
  @Exchange ScalarFieldOf!(typeof(fluids)) elDiel;
  /**
     Electric field (used by elec only).
  */
  @Exchange VectorFieldOf!(typeof(fluids)) elField;

  /**
     The constructor will verify that the local lattices can be set up correctly
     with respect to the parallel decomposition, and allocate the fields.

     Params:
       gn = global size of the lattice
       components = number of fluid components
       fieldNames = names of the fluid fields
       M = MPI parameters
  */
  this (T)( size_t[] gn, uint components, string[] fieldNames, T M ) if ( isMpiParams!T ) {
    import dlbc.parameters: checkArrayParameterLength;
    import std.conv: to;

    checkArrayParameterLength(gn, "lattice.gn", dimensions, true);
    checkArrayParameterLength(fieldNames, "lb.fieldNames", components, true);

    _gn = gn;
    _fieldNames = fieldNames;
    _M = M;

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

    // Global boolean
    if ( enableThermal ) {
      thermal = typeof(thermal)(lengths);
      advThermal = typeof(advThermal)(lengths);
    }

    // Global boolean
    if ( enableElec ) {
      elQp = typeof(elQp)(lengths);
      elQn = typeof(elQn)(lengths);
      elPot = typeof(elPot)(lengths);
      elDiel = typeof(elDiel)(lengths);
      elField = typeof(elField)(lengths);
    }
  }

  private static bool isExchangeField (string field)() @safe pure nothrow {
    import std.typetuple;
    alias attrs = TypeTuple!(__traits(getAttributes, mixin("Lattice."  ~ field)));
    return staticIndexOf!(Exchange, attrs) != -1;
  }

  /**
     Calls exchangeHalo on all member fields of the lattice that are marked as @Exchange,
     and on all members of arrays of fields that are marked as @Exchange.
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
  enum isLattice = is(T:Lattice!(Connectivity!(d,q)), uint d, uint q);
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
    L.initElec();
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

