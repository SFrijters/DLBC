module dlbc.lb.mask;

@("param") MaskInit maskInit;

@("param") string maskFile;

import dlbc.fields.init;
import dlbc.io.io;
import dlbc.parallel;
import dlbc.range;

enum MaskInit {
  None,
  File,
  TubeZ,
  WallsX,
}

enum Mask {
  None,
  Solid,
}

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

bool isFluid(Mask bc) @safe pure nothrow {
  final switch(bc) {
  case Mask.None:
    return true;
  case Mask.Solid:
    return false;
  }
}

bool isAdvectable(Mask bc) @safe pure nothrow {
  final switch(bc) {
  case Mask.None:
    return true;
  case Mask.Solid:
    return false;
  }
}

bool isBounceBack(Mask bc) @safe pure nothrow {
  final switch(bc) {
  case Mask.None:
    return false;
  case Mask.Solid:
    return true;
  }
}

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

