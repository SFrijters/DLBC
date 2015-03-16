// Written in the D programming language.

/**
   Collection of modules related to the lattice Boltzmann algorithm.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

*/

module dlbc.lb.lb;

public import dlbc.lb.advection;
public import dlbc.lb.collision;
public import dlbc.lb.connectivity;
public import dlbc.lb.density;
public import dlbc.lb.eqdist;
public import dlbc.lb.force;
public import dlbc.lb.init;
public import dlbc.lb.io;
public import dlbc.lb.laplace;
public import dlbc.lb.mask;
public import dlbc.lb.momentum;
public import dlbc.lb.velocity;

/**
   Number of timesteps that the simulation should run.
*/
@("param") int timesteps;
/**
   Number of fluid components.
*/
@("param") int components = 1;
/**
   Human-readable names of the fluid components.
*/
@("param") string[] fieldNames;
/**
   Relaxation times of the fluids.
*/
@("param") double[] tau;
/**
   Current timestep of the simulation.
*/
@("global") uint timestep = 0;

