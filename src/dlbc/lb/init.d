module dlbc.lb.init;

@("param") FluidInit fluidInit;

@("param") double[] fluidDensity;

import dlbc.lb.lb;
import dlbc.fields.init;

import dlbc.logging;

enum FluidInit {
  None,
  Const,
  EqDist,
  ConstRandom,
  EqDistRandom,
}

void initFluid(alias conn, T)(ref T field, const size_t i) {
  if ( fluidDensity.length == 0 ) {
    fluidDensity.length = components;
    fluidDensity[] = 0.0;
  }
  else if ( fluidDensity.length != components ) {
    writeLogF("Array variable lb.init.fluidDensity must have length %d.", components * components);
  }

  final switch(fluidInit) {
  case(FluidInit.None):
    break;
  case(FluidInit.Const):
    field.initConst(fluidDensity[i]);
    break;
  case(FluidInit.EqDist):
    field.initEqDist!conn(fluidDensity[i]);
    break;
  case(FluidInit.ConstRandom):
    field.initConstRandom(fluidDensity[i]);
    break;
  case(FluidInit.EqDistRandom):
    field.initEqDistRandom!conn(fluidDensity[i]);
    break;
  }
}


