module dlbc.lb.init;

@("param") FluidInit[] fluidInit;

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
  import dlbc.parameters: checkVectorParameterLength;

  checkVectorParameterLength(fluidInit, "lb.init.fluidInit", components);
  checkVectorParameterLength(fluidDensity, "lb.init.fluidDensity", components);

  final switch(fluidInit[i]) {
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

