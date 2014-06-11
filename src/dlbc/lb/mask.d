module dlbc.lb.mask;

@("param") MaskInit maskInit;

@("param") string maskFile;

import dlbc.fields.init;
import dlbc.io.io;
import dlbc.parallel;

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

void initMask(T)(ref T mask) {
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

void initTubeZ(T)(ref T field) {
  static assert( is (T.type == Mask ) );

  static if ( field.dimensions == 3 ) {
    foreach( x,y,z, ref e; field.arr) {
      auto gx = x + M.cx * field.nx - field.haloSize;
      auto gy = y + M.cy * field.ny - field.haloSize;
      auto gz = z + M.cz * field.nz - field.haloSize;

      if ( gx == 0 || gx == (field.nx * M.ncx - 1) || gy == 0 || gy == (field.ny * M.ncy - 1 ) ) {
	e = Mask.Solid;
      }
      else {
	e = Mask.None;
      }
    }
  }
  else {
    static assert(0, "initTubeZ not implemented for field.dimensions != 3.");
  }
}

void initWallsX(T)(ref T field) {
  static assert( is (T.type == Mask ) );

  static if ( field.dimensions == 3 ) {
    foreach( x,y,z, ref e; field.arr) {
      auto gx = x + M.cx * field.nx - field.haloSize;
      auto gy = y + M.cy * field.ny - field.haloSize;
      auto gz = z + M.cz * field.nz - field.haloSize;

      if ( gx == 0 || gx == (field.nx * M.ncx - 1) ) {
	e = Mask.Solid;
      }
      else {
	e = Mask.None;
      }
    }
  }
  else {
    static assert(0, "initWallsX not implemented for field.dimensions != 3.");
  }
}

bool isFluid(Mask bc) {
  final switch(bc) {
  case Mask.None:
    return true;
  case Mask.Solid:
    return false;
  }
}

bool isAdvectable(Mask bc) {
  final switch(bc) {
  case Mask.None:
    return true;
  case Mask.Solid:
    return false;
  }
}

bool isBounceBack(Mask bc) {
  final switch(bc) {
  case Mask.None:
    return false;
  case Mask.Solid:
    return true;
  }
}

bool isCollidable(Mask bc) {
  final switch(bc) {
  case Mask.None:
    return true;
  case Mask.Solid:
    return false;
  }
}

