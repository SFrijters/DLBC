// Written in the D programming language.

/**
   Implementation of scalar and vector fields on the lattice.

   Copyright: Stefan Frijters 2011-2016

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

*/

module dlbc.fields.field;

import dlbc.logging;

import dlbc.lb.connectivity;

import dlbc.range;

import unstd.multidimarray;
import unstd.generictuple;

/**
   The $(D Field) struct is designed as a template to hold scalars or vectors of
   arbitrary type on a lattice of arbitrary dimension (this will normally match
   the dimensionality of the underlying $(D Lattice) struct).

   Params:
     T = datatype to be held
     c = connectivity of the field
     hs = size of the halo region
*/
struct Field(T, alias c, uint hs) {
  alias type = T;
  alias conn = c;
  enum uint d = conn.d;
  enum uint q = conn.q;
  enum uint haloSize = hs;

  /**
     Allows to access the underlying multidimensional array correctly.
  */
  alias arr this;

  private {
    size_t[conn.d] _lengths;
    size_t[conn.d] _lengthsH;
    size_t _size = 1;
    size_t _sizeH = 1;
    bool _isInitialized = false;
    bool _isStale = true;
  }

  MultidimArray!(T, conn.d) arr, sbuffer, rbuffer;

  /**
     Lengths of the physical dimensions of the field.
  */
  @property const lengths() {
    return _lengths;
  }
  /// Ditto
  alias n = lengths;

  /**
     Length of the physical dimensions with added halo on both sides, i.e. the stored field.
  */
  @property const lengthsH() {
    return _lengthsH;
  }
  /// Ditto
  alias nH = lengthsH;

  /**
     Number of physical sites of the field.
  */
  @property const size() {
    return _size;
  }

  /**
     Number of sites of the field.
  */
  @property const sizeH() {
    return _sizeH;
  }

  /**
     Check if field is initialized.
  */
  @property const isInitialized() {
    return _isInitialized;
  }

  /**
     Check if field is valid.
  */
  @property const isStale() {
    return _isStale;
  }
  // Ditto
  @property const isFresh() {
    return ( ! _isStale );
  }

  /**
     A $(D Field) is constructed by specifying the size of the physical domain and the required halo size.

     Params:
       lengths = lengths of the dimensions of the physical domain
  */
  this (in size_t[conn.d] lengths) {
    import dlbc.range;
    writeLogRD("Initializing %s local field of type '%s' with halo of thickness %d.", lengths.makeLengthsString(), T.stringof, haloSize);
    this._lengths = lengths;
    foreach(immutable i; Iota!(0, conn.d) ) {
      this._size *= lengths[i];
      this._lengthsH[i] = lengths[i] + (2 * hs);
      this._sizeH *= lengthsH[i];
    }
    arr = multidimArray!T(lengthsH);
    this._isInitialized = true;
  }

  /**
     This variant of opApply loops over the physical part of the lattice only
     and overloads the opApply of the underlying multidimArray.
     If the foreach loop is supplied with a reference to the array directly
     it will loop over all lattice sites instead (including the halo).

     Example:
     ----
     foreach(x, y, z, ref el; sfield) {
       // Loops over physical sites of scalar field only.
     }

     foreach(x, y, z, ref el; sfield.arr) {
       // Loops over all lattice sites of scalar field.
     }

     foreach(ref el; sfield.byElementForward) {
       // Loops over all lattice sites of scalar field.
     }
     ---

     Todo: add unittest
  */

  /// Ditto
  int opApply(int delegate(immutable ptrdiff_t[arr.dimensions], ref T) nothrow @nogc dg) nothrow @nogc {
    if(!elements)
      return 0;

    ptrdiff_t[arr.dimensions] indices = haloSize;
    indices[$ - 1] = -1 + haloSize;

    for(;;) {
      foreach_reverse(const plane, ref index; indices) {
        if(++index < arr.lengths[plane] - haloSize)
          break;
        else if(plane)
          index = haloSize;
        else
          return 0;
      }

      if(const res = dg(indices, arr._data[getOffset(indices)]))
        return res;
    }
  }

  /// Ditto
  int opApply(int delegate(immutable ptrdiff_t[arr.dimensions], ref const(T)) nothrow @nogc dg) const nothrow @nogc {
    if(!elements)
      return 0;

    ptrdiff_t[arr.dimensions] indices = haloSize;
    indices[$ - 1] = -1 + haloSize;

    for(;;) {
      foreach_reverse(const plane, ref index; indices) {
        if(++index < arr.lengths[plane] - haloSize)
          break;
        else if(plane)
          index = haloSize;
        else
          return 0;
      }

      if(const res = dg(indices, arr._data[getOffset(indices)]))
        return res;
    }
  }

  void markAsStale() {
    _isStale = true;
  }

  void markAsFresh() {
    _isStale = false;
  }

  /**
     Wrapper for toString that takes care of verbosity and rank.

     Params:
       vl = verbosity level to write at
       logRankFormat = which processes should write
  */
  void show(VL vl, LRF logRankFormat)() {
    writeLog!(vl, logRankFormat)(this.toString());
  }
}

/**
   Template to check if a type is a Field.

   Params:
     T = type to check
*/
template isField(T) {
  enum isField = is(T:Field!(U, Connectivity!(d,q), hs), U, uint d, uint q, uint hs);
}

/**
   Template to check if a type is a Field and has non-zero connectivity.

   Params:
     T = type to check
*/
template isPopulationField(T) {
  enum isPopulationField = ( isField!T && T.q > 0 );
}

/**
   Template to check if two types are Fields and have the same dimension and connectivity.

   Params:
     T = type to check
     U = field to compare to
*/
template isMatchingField(T, U) {
  import dlbc.range;
  enum isMatchingField = ( isField!T && isField!U && (T.d == U.d) && ( T.q == U.q ) );
}

/**
   Template to check if two types are Fields and have the same dimension, and 
   the first field has type length 1.

   Params:
     T = field to check
     U = field to compare to
*/
template isMatchingScalarField(T, U) {
  import dlbc.range;
  enum isMatchingScalarField = ( isField!T && isField!U && (T.d == U.d) && (T.q == 0) && ( LengthOf!(T.type) == 1 ) );
}

/**
   Template to check if two types are Fields and have the same dimension,
   and type length equal to the other field's dimensionality.

   Params:
     T = field to check
     U = field to compare to
*/
template isMatchingVectorField(T, U) {
  import dlbc.range;
  enum isMatchingVectorField = ( isField!T && isField!U && (T.d == U.d) && (T.q == 0) && ( LengthOf!(T.type) == U.d ) );
}

/**
   Template to check if two types are Fields and have the same dimension, and 
   the first field is also a MaskField.

   Params:
     T = field to check
     U = field to compare to
*/
template isMatchingMaskField(T, U) {
  import dlbc.range;
  import dlbc.lb.mask;
  enum isMatchingMaskField = ( isMaskField!T && isField!U && (T.d == U.d) );
}

/**
   Checks if all arguments have the same (enum) dimensions.
   This is useful for some static asserts in functions that take
   fields as arguments.

   Params:
     T = fields to check
*/
template haveCompatibleDims(T...) {
  static if ( T.length > 1 ) {
    static if ( T.length > 2 ) {
      enum haveCompatibleDims = haveCompatibleDims!(T[1..$]);
    }
    else {
      enum haveCompatibleDims = ( T[0].dimensions == T[1].dimensions );
    }
  }
  else {
    enum haveCompatibleDims = true;
  }
}

/**
   Type of scalar Field matching population Field T.
   
   Params:
     T = field to match
*/
template ScalarFieldOf(T) if ( isPopulationField!(BaseElementType!T) ) {
  alias BT = BaseElementType!(T);
  alias ScalarFieldOf = Field!(BaseElementType!(BT.type), dimOf!(BT.conn), BT.haloSize);
}

/**
   Type of vector Field matching population Field T.
   
   Params:
     T = field to match
*/
template VectorFieldOf(T) if ( isPopulationField!(BaseElementType!T) ) {
  alias BT = BaseElementType!(T);
  alias VectorFieldOf = Field!(BaseElementType!(BT.type)[BT.d], dimOf!(BT.conn), BT.haloSize);
}

/**
   Checks if all arguments have the same lengthsH. This is useful for asserts.

   Params:
     fields = fields whose lengthsH to check
*/
bool haveCompatibleLengthsH(T...)(in T fields) @safe pure nothrow @nogc {
  if ( fields.length < 2 ) return true;
  immutable lengthsH = fields[0].lengthsH;
  foreach(ref field; fields) {
    if ( field.lengthsH != lengthsH ) {
      return false;
    }
  }
  return true;
}

/**
   Checks if all arguments have the same lengths. This is useful for asserts.

   Params:
     fields = fields whose lengths to check
*/
bool haveCompatibleLengths(T...)(in T fields) @safe pure nothrow @nogc {
  if ( fields.length < 2 ) return true;
  immutable lengths = fields[0].lengths;
  foreach(ref field; fields) {
    if ( field.lengths != lengths ) {
      return false;
    }
  }
  return true;
}

