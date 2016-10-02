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
/**
   Thickness of all walls when $(D maskInit == MaskInit.Walls).
*/
@("param") int wallThickness = 1;
/**
   Whether or not to put walls on the bottom or top of the various dimensions of the system.
*/
@("param") bool[][] dimensionHasWall;

import dlbc.lb.connectivity;
import dlbc.logging;
import dlbc.parameters;
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
     Add walls of $(D Mask.Solid) sites of thickness 1 perpendicular to the
     $(D initAxis) direction, offset by $(D wallOffset).
  */
  Plates,
  /**
     Add walls of $(D Mask.Solid) sites of thickness 1 to the edges of the
     system, forming a tube in the direction $(D initAxis).
  */
  Tube,
  /**
     Add walls of $(D Mask.Solid) sites of thickness 1 to all sides of the system.
  */
  Box,
  /**
     Add walls of $(D Mask.Solid) sites of thickness $(D wallThickness) to
     the sides of the system specified by $(D dimensionHasWall).
  */
  Walls,
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
  import std.string: format;
  import dlbc.fields.init;

  if ( to!int(initAxis) >= L.mask.dimensions ) {
    writeLogRW("lb.mask.initAxis = %s is out of range (max is %s), this may have unintended consequences.", initAxis, to!Axis(L.mask.dimensions - 1));
  }

  checkArrayParameterLength(dimensionHasWall, "lb.mask.dimensionHasWall", L.lbconn.d);
  foreach(immutable i, ref dhw; dimensionHasWall) {
    auto name = format("lb.mask.dimensionHasWall[%d]", i);
    checkArrayParameterLength(dhw, name, 2);
  }

  final switch(maskInit) {
  case(MaskInit.None):
    L.mask.initConst(Mask.None);
    break;
  case(MaskInit.File):
    import dlbc.io.io: readField;
    L.mask.readField(maskFile);
    break;
  case(MaskInit.Box):
    L.mask.initBox(Mask.Solid, Mask.None);
    break;
  case(MaskInit.Tube):
    L.mask.initTube(Mask.Solid, Mask.None, initAxis);
    break;
  case(MaskInit.Plates):
    if ( to!int(initAxis) >= L.mask.dimensions ) {
      writeLogF("lb.mask.initAxis = %s is out of range (max is %s), this is not allowed for MaskInit.Walls.", initAxis, to!Axis(L.mask.dimensions - 1));
    }
    L.mask.initPlates(Mask.Solid, Mask.None, initAxis, wallOffset);
    break;
  case(MaskInit.Walls):
    L.mask.initWalls(Mask.Solid, Mask.None, dimensionHasWall, wallThickness);
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
