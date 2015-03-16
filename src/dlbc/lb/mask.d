// Written in the D programming language.

/**
   Implementation of mask fields. These can be used to implement boundary conditions.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters
*/

module dlbc.lb.mask;

/**
   How to initialize the mask field.
*/
@("param") MaskInit maskInit;
/**
   If $(D maskInit = File), this speficies the file to read from.
*/
@("param") string maskFile;
/**
   Depending on the choice of $(D maskInit), these parameters may have slightly
   different interpretations. Cf. the description of the $(D MaskInit) enum for details.
*/
@("param") Axis initAxis;
/**
   Offset of both walls, towards the centre of the system.
*/
@("param") int wallOffset;

import std.conv: to;

import dlbc.fields.init;
import dlbc.io.io;
import dlbc.logging;
import dlbc.parallel;
import dlbc.range;

/**
   Possible initialisations for the mask field.
*/
enum MaskInit {
  /**
     Initialise the mask field with $(D Mask.None) everywhere.
  */
  None,
  /**
     Read the mask field from a file.
  */
  File,
  /**
     Add walls of $(D Mask.Solid) sites of thickness 1 to the edges of the
     system, forming a tube in the direction $(D initAxis).
  */
  Tube,
  /**
     Add walls of $(D Mask.Solid) sites of thickness 1 perpendicular to the
     $(D initAxis) direction.
  */
  Walls,
  /**
     Add walls of $(D Mask.Solid) sites of thickness 1 to all sides of the system.
  */
  Box,
}

/**
   Boundary conditions that can be speficied per lattice site.
*/
enum Mask {
  /**
     No boundary condition.
  */
  None,
  /**
     Site is treated as a solid site.
  */
  Solid,
}

/**
   Count the global number of sites with a particular $(D Mask) set.

   Params:
     mask = mask to check for.
     field = (mask) field to check.

   Returns:
     Global number of lattice sites which have the particular $(D Mask).
*/
auto countSites(Mask mask, T)(ref T field) @trusted nothrow @nogc {
  int localCount = 0;
  foreach(immutable p, ref e; field) {
    if ( e == mask ) {
      localCount++;
    }
  }
  int globalCount;
  MPI_Allreduce(&localCount, &globalCount, 1, MPI_INT, MPI_SUM, M.comm);
  return globalCount;
}

/// Ditto
auto countFluidSites(T)(ref T field) @safe nothrow @nogc {
  return countSites!(Mask.None)(field);
}

/// Ditto
auto countSolidSites(T)(ref T field) @safe nothrow @nogc {
  return countSites!(Mask.Solid)(field);
}

/**
   Initialise the mask field depending on the $(D maskInit) parameter.

   Params:
     mask = mask field to be initialised.
*/
void initMask(T)(ref T mask) if (isMaskField!T) {
  if ( to!int(initAxis) >= mask.dimensions ) {
    writeLogF("lb.mask.initAxis = %s is out of range (max is %s).", initAxis, to!Axis(mask.dimensions - 1));
  }

  final switch(maskInit) {
  case(MaskInit.None):
    mask.initConst(Mask.None);
    break;
  case(MaskInit.File):
    mask.readField(maskFile);
    break;
  case(MaskInit.Tube):
    mask.initTube(initAxis);
    break;
  case(MaskInit.Walls):
    mask.initWalls(initAxis, wallOffset);
    break;
  case(MaskInit.Box):
    mask.initBox();
    break;
  }
}

/**
   Initialises walls of thickness 1 of $(D Mask.Solid) on all sides of the system.

   Params:
     field = (mask) field to initialise

   Todo: add function attributes once opApply can support it.
*/
void initBox(T)(ref T field) /** @safe nothrow @nogc **/ if ( isMaskField!T ) {
  foreach(immutable p, ref e; field.arr) {
    ptrdiff_t[field.dimensions] gn;
    e = Mask.None;
    foreach(immutable i; Iota!(0, field.dimensions) ) {
      gn[i] = p[i] + M.c[i] * field.n[i] - field.haloSize;
      if ( gn[i] == 0 || gn[i] == (field.n[i] * M.nc[i] - 1) ) {
        e = Mask.Solid;
      }
    }
  }
}

/**
   Initialises walls of thickness 1 of $(D Mask.Solid) to form a tube in
   the direction of $(D initAxis).

   Params:
     field = (mask) field to initialise
     initAxis = direction of the tube

   Todo: add function attributes once opApply can support it.
*/
void initTube(T)(ref T field, in Axis initAxis) /** @safe nothrow @nogc **/ if ( isMaskField!T ) {
  foreach(immutable p, ref e; field.arr) {
    ptrdiff_t[field.dimensions] gn;
    e = Mask.None;
    foreach(immutable i; Iota!(0, field.dimensions) ) {
      gn[i] = p[i] + M.c[i] * field.n[i] - field.haloSize;
      if ( i != to!int(initAxis) && ( ( gn[i] == 0 || gn[i] == (field.n[i] * M.nc[i] - 1) ) ) ) {
        e = Mask.Solid;
      }
    }
  }
}

/**
   Initialises walls of thickness 1 of $(D Mask.Solid) to form solid planes
   perpendicular to the $(D initAxis) direction.

   Params:
     field = (mask) field to initialise
     initAxis = walls are placed perpendicular to this axis
     wallOffset = distance from the side of the domain at which walls are placed

   Todo: add function attributes once opApply can support it.
*/
void initWalls(T)(ref T field, in Axis initAxis, in int wallOffset) /** @safe nothrow @nogc **/ if ( isMaskField!T ) {
  foreach(immutable p, ref e; field.arr) {
    ptrdiff_t[field.dimensions] gn;
    e = Mask.None;
    foreach(immutable i; Iota!(0, field.dimensions) ) {
      gn[i] = p[i] + M.c[i] * field.n[i] - field.haloSize;
      if ( i == to!int(initAxis) && ( gn[i] == wallOffset || gn[i] == (field.n[i] * M.nc[i] - 1 - wallOffset) ) ) {
        e = Mask.Solid;
      }
    }
  }
}

/**
   Wrapper functions to check if a $(D Mask) can be treated as another property.

   Params:
     bc = boundary condition to check
*/
bool isFluid(Mask bc) @safe pure nothrow @nogc {
  final switch(bc) {
  case Mask.None:
    return true;
  case Mask.Solid:
    return false;
  }
}
/// Ditto
bool isAdvectable(Mask bc) @safe pure nothrow @nogc {
  final switch(bc) {
  case Mask.None:
    return true;
  case Mask.Solid:
    return false;
  }
}
/// Ditto
bool isBounceBack(Mask bc) @safe pure nothrow @nogc {
  final switch(bc) {
  case Mask.None:
    return false;
  case Mask.Solid:
    return true;
  }
}
/// Ditto
bool isCollidable(Mask bc) @safe pure nothrow @nogc {
  final switch(bc) {
  case Mask.None:
    return true;
  case Mask.Solid:
    return false;
  }
}

/**
   Template to check if a type is a mask.
*/
template isMaskField(T) {
  import dlbc.fields.field;
  enum isMaskField = ( isField!T && is(T.type == Mask) );
}

/**
   Type of mask Field matching Field T.
   
   Params:
     T = field to match
*/
import dlbc.fields.field;
import dlbc.lb.connectivity;
template MaskFieldOf(T) if ( isField!(BaseElementType!T) ) {
  alias BT = BaseElementType!(T);
  alias MaskFieldOf = Field!(Mask, dimOf!(BT.conn), BT.haloSize);
}

import dlbc.lattice: isLattice;

/**
   Initialize mask field.
*/
void initMaskField(T)(ref T L) if ( isLattice!T ) {
  L.mask = typeof(L.mask)(L.lengths);
}

