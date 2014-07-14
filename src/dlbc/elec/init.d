module dlbc.elec.init;

@("param") ElecQInit elecQInit;

@("param") ElecDielInit elecDielInit;

import dlbc.elec.elec;
import dlbc.fields.init;
import dlbc.lattice;
import dlbc.logging;

/**
   Electric charge initial conditions.
*/
enum ElecQInit {
  /**
     No-op, use this only when a routine other than initElec takes care of things.
  */
  None,
}

/**
   Dielectric constant initial conditions.
*/
enum ElecDielInit {
  /**
     No-op, use this only when a routine other than initElec takes care of things.
  */
  None,
}

void initElec(T)(ref T L) if ( isLattice!T ) {
  if ( ! enableElec ) return;
  // import dlbc.parameters: checkArrayParameterLength;
  // checkArrayParameterLength(sphereOffset, "lb.init.sphereOffset", conn.d);

  L.elPot.initConst(0);
  L.elField.initConst(0);

  // final switch(fluidInit[i]) {
  // case(FluidInit.None):
  //   break;
  // case(FluidInit.Const):
  //   field.initConst(fluidDensity[i]);
  //   break;
  // case(FluidInit.EqDist):
  //   field.initEqDist(fluidDensity[i]);
  //   break;
  // case(FluidInit.ConstRandom):
  //   field.initConstRandom(fluidDensity[i]);
  //   break;
  // case(FluidInit.EqDistRandom):
  //   field.initEqDistRandom(fluidDensity[i]);
  //   break;
  // case(FluidInit.EqDistSphere):
  //   field.initEqDistSphere(fluidDensity[i], fluidDensity2[i], sphereRadius, sphereOffset);
  //   break;
  // case(FluidInit.EqDistSphereFrac):
  //   field.initEqDistSphereFrac(fluidDensity[i], fluidDensity2[i], sphereRadius, sphereOffset);
  //   break;
  // }
}

