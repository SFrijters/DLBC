module dlbc.elec.init;

@("param") ElecChargeInit chargeInit;

@("param") double chargeSolid;
@("param") double chargeDensitySolid;
@("param") double saltConc;

@("param") ElecDielInit dielInit;

@("param") double dielUniform;

import dlbc.elec.elec;
import dlbc.fields.field;
import dlbc.fields.init;
import dlbc.lb.mask;
import dlbc.lattice;
import dlbc.logging;

/**
   Electric charge initial conditions.
*/
enum ElecChargeInit {
  /**
     No-op, use this only when a routine other than initElec takes care of things.
  */
  None,
  /**
     Distribute total charge $(D chargeSolid) evenly over solid sites, and distribute an opposite
     charge evenly over fluid sites, with an additional salt concentration $(D saltConc).
  */
  Uniform,
}

/**
   Dielectric constant initial conditions.
*/
enum ElecDielInit {
  /**
     No-op, use this only when a routine other than initElec takes care of things.
  */
  None,
  /**
     Uniform dielectric constant $(D dielUniform) everywhere.
  */
  Uniform,
}

void initElec(T)(ref T L) if ( isLattice!T ) {
  if ( ! enableElec ) return;
  // import dlbc.parameters: checkArrayParameterLength;
  // checkArrayParameterLength(sphereOffset, "lb.init.sphereOffset", conn.d);

  L.elPot.initConst(0);
  L.elField.initConst(0);
  L.elDiel.initDielElec();

  L.initQElec();
}

void initQElec(T)(ref T L) if ( isLattice!T ) {
  final switch(qInit) {
  case(ElecQInit.None):
    break;
  case(ElecQInit.Uniform):
    L.initQElecUniform();
    break;
  }
}

void initDielElec(T)(ref T diel) if ( isField!T ) {
  final switch(dielInit) {
  case(ElecDielInit.None):
    break;
  case(ElecDielInit.Uniform):
    diel.initConst(dielUniform);
    break;
  }
}

void initQElecUniform(T)(ref T L) if ( isLattice!T ) {
  auto nFluidSites = L.mask.countFluidSites();
  auto nSolidSites = L.mask.countSolidSites();

  writeLogD("Fluid sites: %d wall sites: %d",nFluidSites, nSolidSites);

}

