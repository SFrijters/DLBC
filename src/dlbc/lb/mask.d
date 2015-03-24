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

import dlbc.lb.connectivity;
import dlbc.logging;
import dlbc.range;

import std.conv: to;

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
auto countSites(Mask mask, T)(ref T field) nothrow @nogc {
  import dlbc.parallel;
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
auto countFluidSites(T)(ref T field) nothrow @nogc {
  return countSites!(Mask.None)(field);
}

/// Ditto
auto countSolidSites(T)(ref T field) nothrow @nogc {
  return countSites!(Mask.Solid)(field);
}

/**
   Initialise the mask field depending on the $(D maskInit) parameter.

   Params:
     L = lattice
*/
void initMask(T)(ref T L) if (isLattice!T) {
  import dlbc.fields.init;

  if ( to!int(initAxis) >= L.mask.dimensions ) {
    writeLogRW("lb.mask.initAxis = %s is out of range (max is %s).", initAxis, to!Axis(L.mask.dimensions - 1));
  }

  final switch(maskInit) {
  case(MaskInit.None):
    L.mask.initConst(Mask.None);
    break;
  case(MaskInit.File):
    import dlbc.io.io: readField;
    L.mask.readField(maskFile);
    break;
  case(MaskInit.Tube):
    L.mask.initTube(Mask.Solid, Mask.None, initAxis);
    break;
  case(MaskInit.Walls):
    L.mask.initWalls(Mask.Solid, Mask.None, initAxis, wallOffset);
    break;
  case(MaskInit.Box):
    L.mask.initBox(Mask.Solid, Mask.None);
    break;
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

import dlbc.fields.field;
/**
   Type of mask Field matching Field T.

   Params:
     T = field to match
*/
template MaskFieldOf(T) if ( isField!(BaseElementType!T) ) {
  alias BT = BaseElementType!(T);
  alias MaskFieldOf = Field!(Mask, dimOf!(BT.conn), BT.haloSize);
}

import dlbc.lattice: isLattice;
/**
   Prepare the mask field.
*/
void prepareMaskField(T)(ref T L) if ( isLattice!T ) {
  L.mask = typeof(L.mask)(L.lengths);
}

