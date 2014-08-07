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
@("param") double[] fluidDensity;
/// Ditto
@("param") double[] fluidDensity2;
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

import dlbc.fields.field;
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
     Initialize all sites of fluid i with the equilibrium population for density
     $(D fluidDensity[i]).
  */
  EqDist,
  /**
     Initialize all sites of fluid i with the equilibrium population for density
     $(D fluidDensity[i]) plus or minus a random value from the interval
     $(D fluidPerturb[i]).
  */
  EqDistPerturb,
  /**
     Initialize all sites of fluid i with the equilibrium population for density
     $(D fluidDensity[i]) times one plus or minus a random value from the interval
     $(D fluidPerturb[i]).
  */
  EqDistPerturbFrac,
  /**
     Initialize all sites of fluid i with values chosen at random from the interval
     $(D 0.. 2 * fluidDensity[i]) on all populations, such that the average density
     is $(D fluidDensity[i]) per population.
  */
  ConstRandom,
  /**
     Initialize all sites of fluid i with the equilibrium population for
     a random density in the interval $(D 0..2 * fluidDensity[i]), such that
     the average density is $(D fluidDensity[i]).
  */
  EqDistRandom,
  /**
     Initialize all sites of fluid i within a radius $(D initRadius) from the centre
     of the system with offset $(D initOffset) the equilibrium population for density
     $(D fluidDensity[i]), and all other sites  with the equilibrium population
     for density $(D fluidDensity2[i]). The interface is modeled by a linear transition
     with a length $(D interfaceThickness).
  */
  EqDistSphere,
  /**
     Initialize all sites of fluid i within a radius $(D initRadius) * system size
     from the centre of the system with offset $(D initOffset) * system size
     with the equilibrium population for density $(D fluidDensity[i]), and all other
     sites with the equilibrium population for density $(D fluidDensity2[i]).
     Here, system size is taken to be the shortest axis of the system. The interface
     is modeled by a linear transition with a length $(D interfaceThickness).
  */
  EqDistSphereFrac,
  /**
     Initialize all sites of fluid i within a radius $(D initRadius) from the centre
     $(D preferredAxis)-axis of the system with offset $(D initOffset) with the
     equilibrium population for density $(D fluidDensity[i]), and all other sites
     with the equilibrium population for density $(D fluidDensity2[i]). The interface
     is modeled by a linear transition with a length $(D interfaceThickness).
  */
  EqDistCylinder,
  /**
     Initialize all sites of fluid i within a radius $(D initRadius) * system size
     from the centre $(D preferredAxis)-axis of the system  with offset $(D initOffset)
     * system size with the equilibrium population for density $(D fluidDensity[i]),
     and all other sites  with the equilibrium population for density
     $(D fluidDensity2[i]). Here, system size is taken to be the shortest remaining
     axis of the system. The interface is modeled by a linear transition with
     a length $(D interfaceThickness).
  */
  EqDistCylinderFrac,
}

/**
   Initialize a field according to the choice of $(D fluidInit).

   Params:
     field = fluid field to initialize
     i = number of the fluid field
*/
void initFluid(T)(ref T field, const size_t i) if ( isPopulationField!T ) {
  import dlbc.parameters: checkArrayParameterLength;
  import std.conv: to;

  alias conn = field.conn;

  checkArrayParameterLength(fluidInit, "lb.init.fluidInit", components);
  checkArrayParameterLength(fluidDensity, "lb.init.fluidDensity", components);
  checkArrayParameterLength(fluidDensity2, "lb.init.fluidDensity2", components);
  checkArrayParameterLength(fluidPerturb, "lb.init.fluidPerturb", components);
  checkArrayParameterLength(initOffset, "lb.init.sphereOffset", conn.d);

  if ( to!int(initAxis) >= field.dimensions ) {
    writeLogF("lb.init.initAxis = %s is out of range (max is %s).", initAxis, to!Axis(field.dimensions - 1));
  }

  final switch(fluidInit[i]) {
  case(FluidInit.None):
    break;
  case(FluidInit.Const):
    field.initConst(fluidDensity[i]);
    break;
  case(FluidInit.EqDist):
    field.initEqDist(fluidDensity[i]);
    break;
  case(FluidInit.EqDistPerturb):
    field.initEqDistPerturb(fluidDensity[i], fluidPerturb[i]);
    break;
  case(FluidInit.EqDistPerturbFrac):
    field.initEqDistPerturbFrac(fluidDensity[i], fluidPerturb[i]);
    break;
  case(FluidInit.ConstRandom):
    field.initConstRandom(fluidDensity[i]);
    break;
  case(FluidInit.EqDistRandom):
    field.initEqDistRandom(fluidDensity[i]);
    break;
  case(FluidInit.EqDistSphere):
    field.initEqDistSphere(fluidDensity[i], fluidDensity2[i], initRadius, initOffset, interfaceThickness);
    break;
  case(FluidInit.EqDistSphereFrac):
    field.initEqDistSphereFrac(fluidDensity[i], fluidDensity2[i], initRadius, initOffset, interfaceThickness);
    break;
  case(FluidInit.EqDistCylinder):
    field.initEqDistCylinder(fluidDensity[i], fluidDensity2[i], initAxis, initRadius, initOffset, interfaceThickness);
    break;
  case(FluidInit.EqDistCylinderFrac):
    field.initEqDistCylinderFrac(fluidDensity[i], fluidDensity2[i], initAxis, initRadius, initOffset, interfaceThickness);
    break;
  }
}

