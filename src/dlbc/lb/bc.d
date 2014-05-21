module dlbc.lb.bc;

enum BoundaryCondition {
  None,
  Solid,
}
alias BoundaryCondition BC;

bool isFluid(BoundaryCondition bc) {
  final switch(bc) {
  case BC.None:
    return true;
  case BC.Solid:
    return false;
  }
}

bool isAdvectable(BoundaryCondition bc) {
  final switch(bc) {
  case BC.None:
    return true;
  case BC.Solid:
    return false;
  }
}

bool isBounceBack(BoundaryCondition bc) {
  final switch(bc) {
  case BC.None:
    return false;
  case BC.Solid:
    return true;
  }
}

bool isCollidable(BoundaryCondition bc) {
  final switch(bc) {
  case BC.None:
    return true;
  case BC.Solid:
    return false;
  }
}

