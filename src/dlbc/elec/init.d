module dlbc.elec.init;

@("param") ElecChargeInit chargeInit;

@("param") double chargeSolid;
@("param") double chargeDensitySolid;
@("param") double saltConc;

@("param") ElecDielInit dielInit;

@("param") double dielUniform;
@("param") double bjerrumLength;
@("param") double dielCapacitor;
@("param") double dielCapacitor2;

@("param") Axis initAxis;

@("param") int initMaxIterations;
/**
   Tolerance of maximum relative flux for system to be considered to be in equilibrium.
*/
@("param") double initFluxToleranceRel;

import dlbc.elec.elec;
import dlbc.fields.field;
import dlbc.fields.init;
import dlbc.fields.parallel;
import dlbc.lb.mask;
import dlbc.lattice;
import dlbc.logging;
import dlbc.parallel;
import dlbc.parameters;
import dlbc.range;

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
  /**
     Place charge $(D chargeDensitySolid) on solid sites which are positioned in
     the lower half of the system (according to ($D initAxis)), 
     charge -$(D chargeDensitySolid) on other solid sites, and zero anywhere else.
  */
  CapacitorDensity,
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
  Capacitor,
}

void initElec(T)(ref T L) if ( isLattice!T ) {
  if ( ! enableElec ) return;

  // Initialize elec fields.
  L.elPot.initConst(0);
  L.elField.initConst(0);
  L.initDielElec();
  L.initChargeElec();

  // Equilibrate.
  L.exchangeHalo();
  L.equilibrateElec();
}

void initElecConstants(T)(ref T L) if ( isLattice!T ) {
  if ( ! enableElec ) return;

  import dlbc.lb.lb: components;
  import std.algorithm: sum;
  import std.conv: to;
  checkArrayParameterLength(externalField, "lb.elec.externalField", L.lbconn.d);
  checkArrayParameterLength(fluidDiel, "lb.elec.fluidDiel", components);
  checkArrayParameterLength(boundaryPhi, "lb.elec.boundaryPhi", 2*L.lbconn.d);
  checkArrayParameterLength(dropPhi, "lb.elec.dropPhi", 2*L.lbconn.d);

  if ( ( fluidOnElec || elecOnFluid ) && components < 1 ) {
    writeLogF("Fluid-elec interactions elec.fluidOnElec and elec.elecOnFluid not supported with components < 1.");
  }

  averageDiel = sum(fluidDiel) / to!double(components);
  if ( localDiel && fluidOnElec && components > 2 ) {
    writeLogF("Local dielectric elec.localDiel with elec.fluidOnElec not supported with components > 2.");
  }
  else {
    if ( components == 2 ) {
      dielContrast = ( fluidDiel[1] - fluidDiel[0] ) / ( fluidDiel[1] + fluidDiel[0] );
    }
    else {
      dielContrast = 1.0;
    }
  }
  writeLogRI("Derived quantity: averageDiel = %e, dielContrast = %e", averageDiel, dielContrast);
  L.initPoissonSolver();
  initElecFlux();
}

private void equilibrateElec(T)(ref T L) if ( isLattice!T ) {

  writeLogRI("Elec initial equilibration.");
  writeLogRI("Suppressing electric field for now.");
  typeof(externalField) externalFieldTmp;
  externalFieldTmp.length = externalField.length;
  foreach(immutable vd; Iota!(0,econn.d) ) {
    externalFieldTmp[vd] = externalField[vd];
    externalField[vd] = 0.0;
  }
  writeLogRI("Solving initial Poisson equation...");
  L.solvePoisson();
  L.calculateElectricField();
  writeLogRI("Equilibrating charges without field...");

  bool isEquilibrated;
  foreach(immutable it; 0..initMaxIterations) {
    isEquilibrated = L.executeElecTimestep();
    if ( isEquilibrated ) {
      writeLogRI("Charge flux equilibrated with requested accuracy after %d iterations.", it);
      break;
    }
  }

  foreach(immutable vd; Iota!(0,econn.d) ) {
    externalField[vd] = externalFieldTmp[vd];
  }

  writeLogRI("Equilibrating charges with external field %s enabled...", externalField);
  foreach(immutable it; 0..initMaxIterations) {
    isEquilibrated = L.executeElecTimestep();
    if ( isEquilibrated ) {
      writeLogRI("Charge flux equilibrated with requested accuracy after %d iterations.", it);
      break;
    }
  }

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
  case(ElecChargeInit.CapacitorDensity):
    L.initChargeElecCapacitorDensity(chargeDensitySolid, initAxis);
    break;
  }
}

private void initDielElec(T)(ref T L) if ( isLattice!T ) {
  if ( localDiel ) {
    final switch(dielInit) {
    case(ElecDielInit.None):
      break;
    case(ElecDielInit.Uniform):
      L.elDiel.initConst(dielUniform);
      break;
    case(ElecDielInit.UniformFromBjerrumLength):
      import std.math: PI;
      dielUniform = beta * elementaryCharge * elementaryCharge / ( 4.0 * PI * bjerrumLength );
      writeLogRI("Setting dielUniform = %e from Bjerrum length.", dielUniform);
      L.elDiel.initConst(dielUniform);
      break;
    case(ElecDielInit.Capacitor):
      L.initDielCapacitor(dielCapacitor, dielCapacitor2, initAxis);
      break;
    }
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

void initChargeElecCapacitorDensity(T)(ref T L, in double chargeDensity, in Axis initAxis) if ( isLattice!T ) {
  size_t i = to!int(initAxis);
  foreach(immutable p, ref e; L.mask) {
    if ( e == Mask.Solid ) {
      auto gp = p[i] + M.c[i] * L.mask.n[i] - L.mask.haloSize; 
      if ( gp < L.gn[i] / 2 ) {
        L.elChargeP[p] =  0.5*chargeDensity;
        L.elChargeN[p] = -0.5*chargeDensity;
      }
      else {
        L.elChargeP[p] = -0.5*chargeDensity;
        L.elChargeN[p] =  0.5*chargeDensity;
      }
    }
    else {
      L.elChargeP[p] = 0.0;
      L.elChargeN[p] = 0.0;
    }
  }

  import std.math: approxEqual;  
  auto globalCharge = L.calculateGlobalCharge();
  assert(approxEqual(globalCharge, 0.0));
}

private double calculateGlobalCharge(T)(ref T L) if ( isLattice!T ) {
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

void initDielCapacitor(T)(ref T L, in double dielConstant, in double dielConstant2, in Axis initAxis) if ( isLattice!T ) {
  size_t i = to!int(initAxis);
  L.elDiel.initLamellae([L.gn[i]/2, L.gn[i]/2],[dielConstant, dielConstant2], initAxis);
  L.elDiel.exchangeHalo();
}

