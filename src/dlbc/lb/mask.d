// Written in the D programming language.

/**
   Implementation of mask fields. These can be used to implement boundary conditions.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
        TR = <tr>$0</tr>
        TH = <th>$0</th>
        TD = <td>$0</td>
        TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
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

import dlbc.fields.init;
import dlbc.io.io;
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
  TubeZ,
  WallsX,
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
auto countSites(Mask mask, T)(ref T field) {
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
auto countFluidSites(T)(ref T field) {
  return countSites!(Mask.None)(field);
}

/// Ditto
auto countSolidSites(T)(ref T field) {
  return countSites!(Mask.Solid)(field);
}

/**
   Initialise the mask field depending on the $(D maskInit) parameter.

   Params:
     mask = mask field to be initialised.
*/
void initMask(T)(ref T mask) if (isMaskField!T) {
  final switch(maskInit) {
  case(MaskInit.None):
    mask.initConst(Mask.None);
    break;
  case(MaskInit.File):
    mask.readField(maskFile);
    break;
  case(MaskInit.TubeZ):
    mask.initTubeZ();
    break;
  case(MaskInit.WallsX):
    mask.initWallsX();
    break;
  }
}

void initTubeZ(T)(ref T field) if ( isMaskField!T ) {
  foreach(immutable p, ref e; field.arr) {
    ptrdiff_t[field.dimensions] gn;
    foreach(immutable i; Iota!(0, field.dimensions) ) {
      gn[i] = p[i] + M.c[i] * field.n[i] - field.haloSize;
    }
    if ( gn[0] == 0 || gn[0] == (field.n[0] * M.nc[0] - 1) || gn[1] == 0 || gn[1] == (field.n[1] * M.nc[1] - 1 ) ) {
      e = Mask.Solid;
    }
    else {
      e = Mask.None;
    }
  }
}

void initWallsX(T)(ref T field) if ( isMaskField!T ) {
  foreach(immutable p, ref e; field.arr) {
    ptrdiff_t[field.dimensions] gn;
    foreach(immutable i; Iota!(0, field.dimensions) ) {
      gn[i] = p[i] + M.c[i] * field.n[i] - field.haloSize;
    }
    if ( gn[0] == 0 || gn[0] == (field.n[0] * M.nc[0] - 1) ) {
      e = Mask.Solid;
    }
    else {
      e = Mask.None;
    }
  }
}

/**
   Wrapper functions to check if a $(D Mask) can be treated as another property.

   Params:
     bc = boundary condition to check
*/
bool isFluid(Mask bc) @safe pure nothrow {
  final switch(bc) {
  case Mask.None:
    return true;
  case Mask.Solid:
    return false;
  }
}
/// Ditto
bool isAdvectable(Mask bc) @safe pure nothrow {
  final switch(bc) {
  case Mask.None:
    return true;
  case Mask.Solid:
    return false;
  }
}
/// Ditto
bool isBounceBack(Mask bc) @safe pure nothrow {
  final switch(bc) {
  case Mask.None:
    return false;
  case Mask.Solid:
    return true;
  }
}
/// Ditto
bool isCollidable(Mask bc) @safe pure nothrow {
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

