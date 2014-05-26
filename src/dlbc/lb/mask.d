module dlbc.lb.mask;

@("param") string maskFile;

@("param") MaskInit maskInit;

import dlbc.fields.init;
import dlbc.io.io;

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

