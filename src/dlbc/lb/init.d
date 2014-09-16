// Written in the D programming language.

/**
   Initialisation choices for fluid fields.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
        TR = <tr>$0</tr>
        TH = <th>$0</th>
        TD = <td>$0</td>
        TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
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
@("param") double initRadius;
/// Ditto
@("param") double[] initOffset;
/// Ditto
@("param") Axis initAxis;
/// Ditto
@("param") double interfaceThickness = 0.0;
/// Ditto
@("param") double[] lamellaeWidths;

import dlbc.fields.field;
import dlbc.lb.lb;
import dlbc.fields.init;
import dlbc.logging;
import dlbc.parameters: checkArrayParameterLength;

/**
   Lattice-Boltzmann initial conditions.
*/
enum FluidInit {
  /**
     No-op, use this only when a routine other than initFluid takes care of things.
  */
  None,
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
     of the system with offset $(D initOffset) the equilibrium population for density
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
void initFluid(T)(ref T field, in size_t i) if ( isPopulationField!T ) {
  import std.conv: to;

  alias conn = field.conn;

  checkArrayParameterLength(fluidInit, "lb.init.fluidInit", components);
  checkArrayParameterLength(fluidDensities, "lb.init.fluidDensities", components);
  checkArrayParameterLength(fluidPerturb, "lb.init.fluidPerturb", components);
  checkArrayParameterLength(initOffset, "lb.init.sphereOffset", conn.d);
  checkArrayParameterLength(tau, "lb.lb.tau", components, true);

  if ( to!int(initAxis) >= field.dimensions ) {
    writeLogF("lb.init.initAxis = %s is out of range (max is %s).", initAxis, to!Axis(field.dimensions - 1));
  }

  final switch(fluidInit[i]) {
  case(FluidInit.None):
    break;
  case(FluidInit.Const):
    checkFDArrayParameterLength(1);
    field.initConst(fluidDensities[i][0]);
    break;
  case(FluidInit.EqDist):
    checkFDArrayParameterLength(1);
    field.initEqDist(fluidDensities[i][0]);
    break;
  case(FluidInit.EqDistPerturb):
    checkFDArrayParameterLength(1);
    field.initEqDistPerturb(fluidDensities[i][0], fluidPerturb[i]);
    break;
  case(FluidInit.EqDistPerturbFrac):
    checkFDArrayParameterLength(1);
    field.initEqDistPerturbFrac(fluidDensities[i][0], fluidPerturb[i]);
    break;
  case(FluidInit.ConstRandom):
    checkFDArrayParameterLength(1);
    field.initConstRandom(fluidDensities[i][0]);
    break;
  case(FluidInit.EqDistRandom):
    checkFDArrayParameterLength(1);
    field.initEqDistRandom(fluidDensities[i][0]);
    break;
  case(FluidInit.EqDistSphere):
    checkFDArrayParameterLength(2);
    field.initEqDistSphere(fluidDensities[i][0], fluidDensities[i][1], initRadius, initOffset, interfaceThickness);
    break;
  case(FluidInit.EqDistSphereFrac):
    checkFDArrayParameterLength(2);
    field.initEqDistSphereFrac(fluidDensities[i][0], fluidDensities[i][1], initRadius, initOffset, interfaceThickness);
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
    field.initEqDistLamellae(fluidDensities[i], lamellaeWidths, initAxis, interfaceThickness);
    break;
  case(FluidInit.EqDistLamellaeFrac):
    checkFDArrayParameterLength(lamellaeWidths.length);
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

