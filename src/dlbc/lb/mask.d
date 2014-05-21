module dlbc.lb.mask;

enum Mask {
  None,
  Solid,
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

