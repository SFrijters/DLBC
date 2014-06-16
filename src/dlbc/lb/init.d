module dlbc.lb.init;

@("param") FluidInit[] fluidInit;

@("param") double[] fluidDensity;

@("param") double[] fluidDensity2;

@("param") double sphereRadius;

import dlbc.lb.lb;
import dlbc.fields.init;

import dlbc.logging;

/**
   Lattice-Boltzmann initial conditions.
*/
enum FluidInit {
  /**
     No-op, use this only when a routine other than initFluid takes care of things.
  */
  None,
  /**
     Initialize all sites of fluid i with $(D fluidDensity[i]) on all populations.
  */
  Const,
  /**
     Initialize all sites of fluid i with the equilibrium population for density $(D fluidDensity[i]).
  */
  EqDist,
  /**
     Initialize all sites of fluid i with values chosen at random from the interval
     $(D 0.. 2 fluidDensity[i]) on all populations, such that the average density
     is $(D fluidDensity[i]) per population.
  */
  ConstRandom,
  /**
     Initialize all sites of fluid i with the equilibrium population for
     a random density in the interval $(D 0..2 fluidDensity[i]), such that
     the average density is $(D fluidDensity[i]).
  */
  EqDistRandom,
  /**
     Initialize all sites of fluid i within a radius $(D sphereRadius) from the centre
     of the system with the equilibrium population for density $(D fluidDensity[i]), and 
     all other sites  with the equilibrium population for density $(D fluidDensity2[i]).
  */
  EqDistSphere,
  /**
     Initialize all sites of fluid i within a radius $(D sphereRadius * system size)
     from the centre of the system with the equilibrium population for density
     $(D fluidDensity[i]), and all other sites  with the equilibrium population
     for density $(D fluidDensity2[i]). Here, system size is taken to be the shortest
     axis of the system.
  */
  EqDistSphereFrac,
}

void initFluid(alias conn, T)(ref T field, const size_t i) {
  import dlbc.parameters: checkVectorParameterLength;

  checkVectorParameterLength(fluidInit, "lb.init.fluidInit", components);
  checkVectorParameterLength(fluidDensity, "lb.init.fluidDensity", components);
  checkVectorParameterLength(fluidDensity2, "lb.init.fluidDensity2", components);

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
  case(FluidInit.EqDistSphere):
    field.initEqDistSphere!conn(fluidDensity[i], fluidDensity2[i], sphereRadius);
    break;
  case(FluidInit.EqDistSphereFrac):
    field.initEqDistSphereFrac!conn(fluidDensity[i], fluidDensity2[i], sphereRadius);
    break;
  }
}

