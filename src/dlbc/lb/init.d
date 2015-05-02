// Written in the D programming language.

/**
   Initialisation choices for fluid fields.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters
*/

module dlbc.lb.init;

/**
   Array of initialisation options, chosen per fluid component.
*/
@("param") FluidInit[] fluidInit;
/**
   Depending on the choice of $(D fluidInit), these parameters may have slightly
   different interpretations. Cf. the description of the $(D FluidInit) enum for details.
*/
@("param") double[][] fluidDensities;
/// Ditto
@("param") double[] fluidPerturb;
/// Ditto
@("param") bool[] randomReseed;
/// Ditto
@("param") int[] randomSeed;
/// Ditto
@("param") double initRadius;
/// Ditto
@("param") double[] initOffset;
/// Ditto
@("param") double[] initSeparation;
/// Ditto
@("param") Axis initAxis;
/// Ditto
@("param") double interfaceThickness = 0.0;
/// Ditto
@("param") double[] lamellaeWidths;
/// Ditto
@("param") string[] fluidFiles;

import dlbc.fields.field;
import dlbc.hooks;
import dlbc.lb.lb;
import dlbc.fields.init;
import dlbc.logging;
import dlbc.parameters: checkArrayParameterLength;
import dlbc.random;
import dlbc.timers;

TVoidHooks!(LType, "preLbInitHooks") preLbInitHooks;
TVoidHooks!(LType, "postLbInitHooks") postLbInitHooks;

/**
   Prepare various LB related fields: fluids, advection, mask, density.
*/
void prepareLBFields(T)(ref T L) if ( isLattice!T ) {

  writeLogRI("Preparing LB fields.");

  assert(L.fluids.length == 0);
  L.fluids.length = components;
  foreach(immutable f; 0..L.fluids.length ) {
    L.fluids[f] = typeof(L.fluids[f])(L.lengths);
  }
  L.advection = typeof(L.advection)(L.lengths);
  L.prepareMaskField();
  L.prepareDensityFields();
}

/**
   Initialize fluid fields.
*/
void initFluids(T)(ref T L) if ( isLattice!T ) {
  alias conn = T.lbconn;

  writeLogRN("Initializing fluids.");

  // Run pre-LB-init hooks
  if ( preLbInitHooks.length > 0 ) {
    startTimer("pre");
    preLbInitHooks.execute(L);
    stopTimer("pre");
  }

  checkArrayParameterLength(fluidInit, "lb.init.fluidInit", components);
  checkArrayParameterLength(fluidDensities, "lb.init.fluidDensities", components);
  checkArrayParameterLength(fluidPerturb, "lb.init.fluidPerturb", components);
  checkArrayParameterLength(initOffset, "lb.init.initOffset", conn.d);
  checkArrayParameterLength(initSeparation, "lb.init.initSeparation", conn.d);
  checkArrayParameterLength(randomReseed, "lb.init.randomReseed", components);
  checkArrayParameterLength(randomSeed, "lb.init.randomSeed", components);
  checkArrayParameterLength(fluidFiles, "lb.init.fluidFiles", components);
  // If we don't actually want to collide at least once, we don't care about tau
  if ( timesteps > 0 ) {
    checkArrayParameterLength(tau, "lb.lb.tau", components, true);
  }
  else {
    checkArrayParameterLength(tau, "lb.lb.tau", components, false);
  }

  if ( to!int(initAxis) >= conn.d ) {
    writeLogRW("lb.init.initAxis = %s is out of range (max is %s), this may have unintended consequences.", initAxis, to!Axis(conn.d - 1));
  }

  foreach(immutable f; 0..L.fluids.length) {
    if ( randomReseed[f] ) {
      RNG lrng;
      if ( shiftSeedByRank ) {
	lrng.seed(randomSeed[f] + M.rank);
      }
      else {
	lrng.seed(randomSeed[f]);
      }
      L.fluids[f].initFluid(f, lrng);
    }
    else {
      L.fluids[f].initFluid(f, rng);
    }
    // Coloured walls.
    L.fluids[f].initEqDistWall(L.mask);
  }

  // Run post-LB-init hooks
  if ( postLbInitHooks.length > 0 ) {
    startTimer("post");
    postLbInitHooks.execute(L);
    stopTimer("post");
  }

}

/**
   Lattice-Boltzmann initial conditions.
*/
enum FluidInit {
  /**
     No-op, use this only when a routine other than initFluid takes care of things.
  */
  None,
  /**
     Read fluid populations of fluid i from $(D fluidFiles[i]).
  */
  File,
  /**
     Initialize all sites of fluid i with $(D fluidDensities[i][0]) on all populations.
  */
  Const,
  /**
     Initialize all sites of fluid i with the equilibrium population for density
     $(D fluidDensities[i][0]).
  */
  EqDist,
  /**
     Initialize all sites of fluid i with the equilibrium population for density
     $(D fluidDensities[i][0]) plus or minus a random value from the interval
     $(D fluidPerturb[i]).
  */
  EqDistPerturb,
  /**
     Initialize all sites of fluid i with the equilibrium population for density
     $(D fluidDensities[i][0]) times one plus or minus a random value from the interval
     $(D fluidPerturb[i]).
  */
  EqDistPerturbFrac,
  /**
     Initialize all sites of fluid i with values chosen at random from the interval
     $(D 0..2 * fluidDensities[i][0]) on all populations, such that the average density
     is $(D fluidDensities[i][0]) per population.
  */
  ConstRandom,
  /**
     Initialize all sites of fluid i with the equilibrium population for
     a random density in the interval $(D 0..2 * fluidDensities[i][0]), such that
     the average density is $(D fluidDensities[i][0]).
  */
  EqDistRandom,
  /**
     Initialize all sites of fluid i within a radius $(D initRadius) from the centre
     of the system with offset $(D initOffset) with the equilibrium population for density
     $(D fluidDensities[i][0]), and all other sites with the equilibrium population
     for density $(D fluidDensities[i][1]). The interface is modeled by a linear transition
     with a length $(D interfaceThickness).
  */
  EqDistSphere,
  /**
     Initialize all sites of fluid i within a radius $(D initRadius) * system size
     from the centre of the system with offset $(D initOffset) * system size
     with the equilibrium population for density $(D fluidDensities[i][0]), and all other
     sites with the equilibrium population for density $(D fluidDensities[i][1]).
     Here, system size is taken to be the shortest axis of the system. The interface
     is modeled by a linear transition with a length $(D interfaceThickness).
  */
  EqDistSphereFrac,
  /**
     Initialize all sites of fluid i within a radius $(D initRadius) from the centre
     $(D preferredAxis)-axis of the system with offset $(D initOffset) with the
     equilibrium population for density $(D fluidDensities[i][0]), and all other sites
     with the equilibrium population for density $(D fluidDensities[i][1]). The interface
     is modeled by a linear transition with a length $(D interfaceThickness).
  */
  EqDistCylinder,
  /**
     Initialize all sites of fluid i within a radius $(D initRadius) * system size
     from the centre $(D preferredAxis)-axis of the system with offset $(D initOffset)
     * system size with the equilibrium population for density $(D fluidDensities[i][0]),
     and all other sites  with the equilibrium population for density
     $(D fluidDensities[i][1]). Here, system size is taken to be the shortest remaining
     axis of the system. The interface is modeled by a linear transition with
     a length $(D interfaceThickness).
  */
  EqDistCylinderFrac,
  /**
     Initialize all sites of fluid i, within a radius $(D initRadius) from the centre of
     either of two spheres, whose centres are separated by a distance $(D initSeparation)
     and whose combined centre of mass is located at the centre of the system with offset
     $(D initOffset), with the equilibrium population for density
     $(D fluidDensities[i][0]), and all other sites with the equilibrium population
     for density $(D fluidDensities[i][1]). The interface is modeled by a linear transition
     with a length $(D interfaceThickness).
  */
  EqDistTwoSpheres,
  /**
     Initialize all sites of fluid i, within a radius $(D initRadius) * system size
     from the centre of either of two spheres, whose centres are separated by a distance
     $(D initSeparation) * system size and whose combined centre of mass is located at the
     centre of the system with offset $(D initOffset) * system size, with the equilibrium
     population for density $(D fluidDensities[i][0]), and all other sites with the
     equilibrium population for density $(D fluidDensities[i][1]). Here, system size is taken
     to be the shortest axis of the system. The interface is modeled by a linear
     transition with a length $(D interfaceThickness).
  */
  EqDistTwoSpheresFrac,
  /**
     Initialize all sites of fluid i with $(D preferredAxis)-coordinate inside a
     particular lamella of a set of lamellae of width $(D lamellaeWidths) with the
     equilibrium population for density $(D fluidDensities[i][j])$ where j is the number
     of the lamella. The interfaces are modeled by a linear transition with
     a length $(D interfaceThickness).
  */
  EqDistLamellae,
  /**
     Initialize all sites of fluid i with $(D preferredAxis)-coordinate inside a
     particular lamella of a set of lamellae of width $(D lamellaeWidths) * system size
     with the equilibrium population for density $(D fluidDensities[i][j])$ where j is
     the number of the lamella and the system size is taking along the preferred axis.
     The interfaces are modeled by a linear transition with a length $(D interfaceThickness).
  */
  EqDistLamellaeFrac,
}

/**
   Initialize a field according to the choice of $(D fluidInit).

   Params:
     field = fluid field to initialize
     i = number of the fluid field
*/
void initFluid(T)(ref T field, in size_t i, ref RNG lrng) if ( isPopulationField!T ) {
  alias conn = T.conn;
  import std.conv: to;

  writeLogRI("  Initializing fluid %d.", i);

  final switch(fluidInit[i]) {
  case(FluidInit.None):
    break;
  case(FluidInit.File):
    import dlbc.io.io: readField;
    field.readField(fluidFiles[i]);
    break;
  case(FluidInit.Const):
    checkFDArrayParameterLength(1);
    field.initConst(fluidDensities[i][0]);
    break;
  case(FluidInit.ConstRandom):
    checkFDArrayParameterLength(1);
    field.initConstRandom(fluidDensities[i][0], lrng);
    break;
  case(FluidInit.EqDist):
    checkFDArrayParameterLength(1);
    field.initEqDist(fluidDensities[i][0]);
    break;
  case(FluidInit.EqDistRandom):
    checkFDArrayParameterLength(1);
    field.initEqDistRandom(fluidDensities[i][0], lrng);
    break;
  case(FluidInit.EqDistPerturb):
    checkFDArrayParameterLength(1);
    field.initEqDistPerturb(fluidDensities[i][0], fluidPerturb[i], lrng);
    break;
  case(FluidInit.EqDistPerturbFrac):
    checkFDArrayParameterLength(1);
    field.initEqDistPerturbFrac(fluidDensities[i][0], fluidPerturb[i], lrng);
    break;
  case(FluidInit.EqDistSphere):
    checkFDArrayParameterLength(2);
    field.initEqDistSphere(fluidDensities[i][0], fluidDensities[i][1], initRadius, initOffset, interfaceThickness);
    break;
  case(FluidInit.EqDistSphereFrac):
    checkFDArrayParameterLength(2);
    field.initEqDistSphereFrac(fluidDensities[i][0], fluidDensities[i][1], initRadius, initOffset, interfaceThickness);
    break;
  case(FluidInit.EqDistTwoSpheres):
    checkFDArrayParameterLength(2);
    field.initEqDistTwoSpheres(fluidDensities[i][0], fluidDensities[i][1], initRadius, initOffset, interfaceThickness, initSeparation);
    break;
  case(FluidInit.EqDistTwoSpheresFrac):
    checkFDArrayParameterLength(2);
    field.initEqDistTwoSpheresFrac(fluidDensities[i][0], fluidDensities[i][1], initRadius, initOffset, interfaceThickness, initSeparation);
    break;
  case(FluidInit.EqDistCylinder):
    checkFDArrayParameterLength(2);
    field.initEqDistCylinder(fluidDensities[i][0], fluidDensities[i][1], initAxis, initRadius, initOffset, interfaceThickness);
    break;
  case(FluidInit.EqDistCylinderFrac):
    checkFDArrayParameterLength(2);
    field.initEqDistCylinderFrac(fluidDensities[i][0], fluidDensities[i][1], initAxis, initRadius, initOffset, interfaceThickness);
    break;
  case(FluidInit.EqDistLamellae):
    checkFDArrayParameterLength(lamellaeWidths.length);
    if ( to!int(initAxis) >= conn.d ) {
      writeLogF("lb.init.initAxis = %s is out of range (max is %s), this is not allowed for FluidInit.EqDistLamellae", initAxis, to!Axis(conn.d - 1));
    }
    field.initEqDistLamellae(fluidDensities[i], lamellaeWidths, initAxis, interfaceThickness);
    break;
  case(FluidInit.EqDistLamellaeFrac):
    checkFDArrayParameterLength(lamellaeWidths.length);
    if ( to!int(initAxis) >= conn.d ) {
      writeLogF("lb.init.initAxis = %s is out of range (max is %s), this is not allowed for FluidInit.EqDistLamellaeFrac", initAxis, to!Axis(conn.d - 1));
    }
    field.initEqDistLamellaeFrac(fluidDensities[i], lamellaeWidths, initAxis, interfaceThickness);
    break;
  }
}

private void checkFDArrayParameterLength(in size_t len) {
  import std.string: format;
  foreach(immutable i, ref d; fluidDensities) {
    auto name = format("lb.init.fluidDensities[%d]", i);
    checkArrayParameterLength(fluidDensities, name, components, true);
  }
}

