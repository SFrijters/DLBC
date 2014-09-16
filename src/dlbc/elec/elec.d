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

public import dlbc.elec.flux;
public import dlbc.elec.force;
public import dlbc.elec.init;
public import dlbc.elec.poisson;

import dlbc.lb.connectivity;
import dlbc.lattice;

/**
   Enable electric effects.
*/
@("param") bool enableElec;
/**
   Enable local dielectric constant.
*/
@("param") bool localDiel;
/**
   Value of the global dielectric constant (only used when $(D localDiel == false)).
*/
@("param") double dielGlobal;
/**
   Enable effects of the fluids on the electric fields. This includes both charge advection
   and local dielectric constant if multiple fluids are present.
*/
@("param") bool fluidOnElec;
/**
   Enable effects of the electric fields on the fluids. This currently means forces.
*/
@("param") bool elecOnFluid;
/**
   Inverse temperature.
*/
@("param") double beta = 1.0;
/**
   Value of homogeneous external electric field.
*/
@("param") double[] externalField;
/**
   Dielectric constants of the fluid species.
*/
@("param") double[] fluidDiel;
/**
   Dielectric constant of solid sites.
*/
@("param") double solidDiel = 1.0;
/**
   Boundary conditions for the electric potential.
*/
@("param") BoundaryPhi[][] boundaryPhi;
/**
   When $(D boundaryPhi == BoundaryPhi.Drop)$, the magnitude of the potential drops.
*/
@("param") double[][] dropPhi;

// Derived quantities.
double dielContrast;
double averageDiel;

/**
   Magnitude of the elementary charge.
*/
enum elementaryCharge = 1.0;

/**
   Connectivity for electric fields as derived from another connectivity.

   Params:
     conn = connectivity to match
*/
private template elecConnOf(alias conn) {
  static if ( conn.d == 3 ) {
    alias elecConnOf = d3q7;
  }
  else static if ( conn.d == 2 ) {
    alias elecConnOf = d2q5;
  }
  else static if ( conn.d == 1 ) {
    alias elecConnOf = d1q3;
  }
  else {
    static assert(0);
  }
}

/**
   Electric connectivity.
*/
alias econn = elecConnOf!gconn;

/**
   Possible values of the boundary condition for the electric potential.
*/
enum BoundaryPhi {
  /**
     Periodic.
  */
  Periodic,
  /**
     Von Neumann boundary condition: the derivative of the potential is zero at an edge.
  */
  Neumann,
  /**
     Potential drop: the potential values of the neighbour on the other side of the system edge is
     shifted by $(D dropPhi).
  */
  Drop,
}

/**
   Executes one timestep for the electric fields.

   Params:
     L = lattice

   Returns: whether the movement of electric charges is below the threshold $(D fluxToleranceRel).
*/
bool executeElecTimestep(T)(ref T L) if ( isLattice!T ) {
  if ( ! enableElec ) return true;
  bool isEquilibrated;
  isEquilibrated = L.moveElecCharges();
  L.solvePoisson();
  L.calculateElectricField();
  return isEquilibrated;
}

