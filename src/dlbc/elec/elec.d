// Written in the D programming language.

/**
   Collection of modules related to the implementation of electric charges.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
        TR = <tr>$0</tr>
        TH = <th>$0</th>
        TD = <td>$0</td>
        TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.elec.elec;

public import dlbc.elec.force;
public import dlbc.elec.init;
public import dlbc.elec.poisson;

import dlbc.lb.connectivity;

@("param") bool enableElec;

@("param") bool localDiel;

@("param") bool fluidOnElec;

@("param") bool elecOnFluid;

@("param") double beta = 1.0;

@("param") double[] externalField;

@("param") double[] fluidDiel;

@("param") double solidDiel = 1.0;

@("param") BoundaryPhi[] boundaryPhi;

@("param") double[] dropPhi;

double dielContrast;
double averageDiel;

enum elementaryCharge = 1.0;

private template elecConnOf(alias conn) {
  static if ( conn.d == 3 ) {
    alias elecConnOf = d3q7;
  }
  else static if ( conn.d == 2 ) {
    alias elecConnOf = d2q5;
  }
  else {
    static assert(0);
  }
}

alias econn = elecConnOf!gconn;

enum BoundaryPhi {
  Periodic,
  Neumann,
  Drop,
}

