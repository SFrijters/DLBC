// Written in the D programming language.

/**
   Collection of modules related to the lattice Boltzmann algorithm.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.lb.lb;

public import dlbc.lb.advection;
public import dlbc.lb.collision;
public import dlbc.lb.connectivity;
public import dlbc.lb.density;
public import dlbc.lb.force;
public import dlbc.lb.init;
public import dlbc.lb.mask;
public import dlbc.lb.momentum;
public import dlbc.lb.thermal;
public import dlbc.lb.velocity;

@("param") int timesteps;
@("param") int components = 1;
@("param") string[] fieldNames;

@("global") uint timestep = 0;

