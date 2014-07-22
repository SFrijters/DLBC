module dlbc.elec.init;

@("param") ElecChargeInit chargeInit;

@("param") double chargeSolid;
@("param") double chargeDensitySolid;
@("param") double saltConc;

@("param") ElecDielInit dielInit;

@("param") double dielUniform;
@("param") double bjerrumLength;

import dlbc.elec.elec;
import dlbc.fields.field;
import dlbc.fields.init;
import dlbc.lb.mask;
import dlbc.lattice;
import dlbc.logging;
import dlbc.parameters;

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
  /**
     Place charge $(D chargeDensitySolid) on solid sites, and distribute an opposite
     charge evenly over fluid sites, with an additional salt concentration $(D saltConc).
  */
  UniformDensity,
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
  UniformFromBjerrumLength,
}

void initElec(T)(ref T L) if ( isLattice!T ) {
  if ( ! enableElec ) return;

  import dlbc.lb.lb: components;
  import std.algorithm: sum;
  import std.conv: to;

  checkArrayParameterLength(externalField, "lb.elec.externalField", L.lbconn.d);
  checkArrayParameterLength(fluidDiel, "lb.elec.fluidDiel", components);

  averageDiel = sum(fluidDiel) / to!double(components);
  if ( localDiel && components > 2 ) {
    writeLogF("Warning: local dielectric not supported with components > 2.");
  }
  else {
    if ( components == 2 ) {
      dielContrast = ( fluidDiel[1] - fluidDiel[0] ) / ( fluidDiel[1] + fluidDiel[0] );
    }
    else {
      dielContrast = 1.0;
    }
  }

  L.initPoissonSolver();

  L.elPot.initConst(0);
  L.elField.initConst(0);
  L.elDiel.initDielElec();

  L.initChargeElec();
  L.equilibrateElec();
}

private void equilibrateElec(T)(ref T L) if ( isLattice!T ) {
  L.solvePoisson();
}

private void initChargeElec(T)(ref T L) if ( isLattice!T ) {
  final switch(chargeInit) {
  case(ElecChargeInit.None):
    break;
  case(ElecChargeInit.Uniform):
    L.initChargeElecUniform(false);
    break;
  case(ElecChargeInit.UniformDensity):
    L.initChargeElecUniform(true);
    break;
  }
}

private void initDielElec(T)(ref T diel) if ( isField!T ) {
  final switch(dielInit) {
  case(ElecDielInit.None):
    break;
  case(ElecDielInit.Uniform):
    diel.initConst(dielUniform);
    break;
  case(ElecDielInit.UniformFromBjerrumLength):
    import std.math: PI;
    dielUniform = beta * elementaryCharge * elementaryCharge / ( 4.0 * PI * bjerrumLength );
    writeLogRI("Setting dielUniform = %e from Bjerrum length.", dielUniform);
    diel.initConst(dielUniform);
    break;
  }
}

private void initChargeElecUniform(T)(ref T L, bool asDensity) if ( isLattice!T ) {
  import std.conv: to;
  auto nFluidSites = L.mask.countFluidSites();
  auto nSolidSites = L.mask.countSolidSites();

  writeLogRD("Fluid sites: %d wall sites: %d",nFluidSites, nSolidSites);

  double rhoSolid, rhoSolidP, rhoSolidN;
  if ( nSolidSites > 0 ) {
    if ( asDensity ) {
      rhoSolid = chargeDensitySolid;
      chargeSolid = chargeDensitySolid *  to!double(nSolidSites);
    }
    else {
      chargeDensitySolid = chargeSolid / to!double(nSolidSites);
      rhoSolid = chargeDensitySolid;
    }
    
    rhoSolidP =  0.5*rhoSolid;
    rhoSolidN = -0.5*rhoSolid;
  }
  else {
    chargeSolid = 0.0;
    rhoSolid = 0.0;
    rhoSolidP = 0.0;
    rhoSolidN = 0.0;
  }

  double chargeFluid, rhoFluid, rhoFluidP, rhoFluidN;
  if ( nFluidSites > 0 ) {
    chargeFluid = -chargeSolid;
    rhoFluid = chargeFluid / to!double(nFluidSites);
  }
  else {
    chargeFluid = 0.0;
    rhoFluid = 0.0;
  }

  if ( rhoFluid > 0 ) {
    rhoFluidP = 0.5*saltConc + rhoFluid;
    rhoFluidN = 0.5*saltConc;
  }
  else {
    rhoFluidP = 0.5*saltConc;
    rhoFluidN = 0.5*saltConc - rhoFluid;
  }

  foreach(immutable p, ref e; L.elChargeP) {
    if ( L.mask[p] == Mask.Solid ) {
      e = rhoSolidP;
    }
    else {
      e = rhoFluidP;
    }
  }

  foreach(immutable p, ref e; L.elChargeN) {
    if ( L.mask[p] == Mask.Solid ) {
      e = rhoSolidN;
    }
    else {
      e = rhoFluidN;
    }
  }

  import std.math: approxEqual;  
  auto globalCharge = L.calculateGlobalCharge();
  assert(approxEqual(globalCharge, 0.0));
}

double calculateGlobalCharge(T)(ref T L) if ( isLattice!T ) {
  import dlbc.parallel;
  double localChargeP = 0;
  foreach(immutable p, e; L.elChargeP) {
    localChargeP += e;
  }
  double localChargeN = 0;
  foreach(immutable p, e; L.elChargeN) {
    localChargeN += e;
  }
  double globalChargeP, globalChargeN;
  MPI_Allreduce(&localChargeP, &globalChargeP, 1, MPI_DOUBLE, MPI_SUM, M.comm);
  MPI_Allreduce(&localChargeN, &globalChargeN, 1, MPI_DOUBLE, MPI_SUM, M.comm);
  
  return globalChargeP - globalChargeN;
}

