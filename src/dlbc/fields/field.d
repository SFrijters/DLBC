// Written in the D programming language.

/**
   Implementation of scalar and vector fields on the lattice.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.fields.field;

import dlbc.logging;

import unstd.multidimarray;
import unstd.generictuple;

/**
   The $(D Field) struct is designed as a template to hold scalars or vectors of
   arbitrary type on a lattice of arbitrary dimension (this will normally match
   the dimensionality of the underlying $(D Lattice) struct).

   Params:
     T = datatype to be held
     dim = dimensionality of the field
     hs = size of the halo region
*/
struct Field(T, uint dim, uint hs) {
  enum uint dimensions = dim;
  enum uint haloSize = hs;
  alias type = T;

  /**
     Allows to access the underlying multidimensional array correctly.
  */
  alias arr this;

  private {
    size_t[dim] _lengths;
    size_t[dim] _lengthsH;
    size_t _size = 1;
    size_t _sizeH = 1;
  }

  MultidimArray!(T, dim) arr, sbuffer, rbuffer;

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
     A $(D Field) is constructed by specifying the size of the physical domain and the required halo size.

     Params:
       lengths = lengths of the dimensions of the physical domain
  */
  this (const size_t[dim] lengths) {
    import dlbc.range;
    writeLogRD("Initializing %s local field of type '%s' with halo of thickness %d.", lengths.makeLengthsString(), T.stringof, haloSize);
    this._lengths = lengths;
    foreach(immutable i; Iota!(0, dim) ) {
      this._size *= lengths[i];
      this._lengthsH[i] = lengths[i] + (2 * hs);
      this._sizeH *= lengthsH[i];
    }
    arr = multidimArray!T(lengthsH);
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
  int opApply(int delegate(RepeatTuple!(arr.dimensions, size_t), ref T) dg) {
    if(!elements)
      return 0;

    RepeatTuple!(arr.dimensions, size_t) indices = haloSize;
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
  int opApply(int delegate(immutable ptrdiff_t[arr.dimensions], ref T) dg) {
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
  const int opApply(int delegate(immutable ptrdiff_t[arr.dimensions], ref const(T)) dg) {
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


