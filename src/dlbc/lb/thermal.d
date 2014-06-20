// Written in the D programming language.

/**
   Thermal fields.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.lb.thermal;

import dlbc.lattice;
import dlbc.fields.field;
import dlbc.lb.lb;
import dlbc.parallel;
import dlbc.range;

@("param") bool enableThermal;

double globalTemperature;

private template thermalConnOf(alias conn) {
  static if ( conn.d == 3 ) {
    alias thermalConnOf = d3q7;
  }
  else static if ( conn.d == 2 ) {
    alias thermalConnOf = d2q5;
  }
  else {
    static assert(0);
  }
}

alias tconn = thermalConnOf!gconn;

void initThermal(T)(ref T L) if (isLattice!T) {
  if ( ! enableThermal ) return;
  initThermalWall(L.thermal, 3.0, 1.0, 1.0, L.mask);
}

private void initThermalWall(T, U)(ref T field, const double density1, const double density2, const double density3, const ref U mask) if ( isField!T && is(U.type == Mask ) ) {
  import dlbc.lb.collision;
  import dlbc.lb.connectivity;
  import dlbc.lb.mask;

  alias conn = field.conn;
  double[conn.q] pop0 = 0.0;
  pop0[0] = 1.0;
  double[conn.d] dv = 0.0;
  typeof(pop0) pop1 = density1*eqDist!conn(pop0, dv)[];
  typeof(pop0) pop2 = density2*eqDist!conn(pop0, dv)[];
  typeof(pop0) pop3 = density3*eqDist!conn(pop0, dv)[];

  foreach(immutable p, ref e; field.arr) {
    if ( mask[p] == Mask.Solid ) {

      ptrdiff_t[field.dimensions] gn;
      foreach(immutable i; Iota!(0, field.dimensions) ) {
	gn[i] = p[i] + M.c[i] * field.n[i] - field.haloSize;
      }
      if ( gn[0]  < field.n[0] * M.nc[0] / 2 ) {
	e = pop1;
      }
      else {
	e = pop2;
      }
    }
    else {
      e = pop3;
    }
  }
}

void advectThermalField(T, U)(ref T field, const ref U mask, ref T tempField) if ( isField!T && is(U.type == Mask) ) {
  if ( ! enableThermal ) return;
  import std.algorithm: swap;
  import dlbc.range: Iota;
  static assert(haveCompatibleDims!(field, mask, tempField));
  assert(haveCompatibleLengthsH(field, mask, tempField));

  alias conn = field.conn;

  double localTemperature = 0.0;

  immutable cv = conn.velocities;
  foreach(immutable p, ref pop; tempField.arr) {
    if ( p.isOnEdge!conn(field.lengthsH) ) continue;
    assert(pop.length == cv.length);
    foreach(immutable i, ref e; pop ) {
      conn.vel_t nb;
      foreach(immutable j; Iota!(0, conn.d) ) {
	nb[j] = p[j] - cv[i][j];
      }
      if ( isAdvectable(mask[p]) || isAdvectable(mask[nb]) ) {
	e = field[nb][i];
      }
      else {
	e = field[p][i];
      }
      localTemperature += e;
    }
  }
  swap(field, tempField);
  MPI_Allreduce(&localTemperature, &globalTemperature, 1, mpiTypeof!(double), MPI_SUM, M.comm);
  import dlbc.logging;
  writeLogRD("T = %f", globalTemperature / ( 128 *128));
}

void collideThermalField(T, U, V)(ref T field, const ref U mask, ref V fluidField) if ( isField!T && is(U.type == Mask) && isField!V ) {
  if ( ! enableThermal ) return;
  static assert(haveCompatibleDims!(field, mask, fluidField ));
  assert(haveCompatibleLengthsH(field, mask, fluidField));

  alias conn = field.conn;

  enum omega = 1.0;
  foreach(immutable p, ref pop; field) {
    if ( isCollidable(mask[p]) ) {
      double[conn.d] dv;
      immutable vel = fluidField[p].velocity!gconn();
      immutable eq = eqDist!conn(pop, vel);
      foreach(immutable i; Iota!(0,conn.q) ) {
	pop[i] -= omega * ( pop[i] - eq[i] );
      }
    }
  }
}

void addBuoyancyForce(T)(ref T L) if (isLattice!T) {
  if ( ! enableThermal ) return;

  alias conn = L.lbconn;
  immutable cv = conn.velocities;
  immutable cw = conn.weights;

  /++
  // It's actually faster to pre-calculate the densities, apparently...
  L.calculateDensity();

  // Do all combinations of two fluids.
  foreach(immutable nc1; 0..L.fluids.length ) {
    foreach(immutable nc2; 0..L.fluids.length ) {
      // This interaction has a particular coupling constant.
      immutable cc = gccm[nc1][nc2];
      // Skip zero interactions.
      if ( cc == 0.0 ) continue;
      foreach(immutable p, ref force ; L.force[nc1] ) {
        // Only do lattice sites on which collision will take place.
	if ( isCollidable(L.mask[p]) ) {
	  immutable psiden1 = psi(L.density[nc1][p]);
	  foreach(immutable i; Iota!(0, conn.q) ) {
	    conn.vel_t nb;
	    // Todo: better array syntax.
	    foreach(immutable j; Iota!(0, conn.d) ) {
	      nb[j] = p[j] - cv[i][j];
	    }
            // Only do lattice sites that are not walls.
	    immutable psiden2 = ( isBounceBack(L.mask[nb]) ? psi(L.density[nc2][p]) : psi(L.density[nc2][nb]));
	    immutable prefactor = psiden1 * psiden2 * cc;
	    // The SC force function.
	    foreach(immutable j; Iota!(0, conn.d) ) {
	      force[j] += prefactor * cv[i][j];
	    }
	  }
	}
      }
    }

    // Wall interactions
    immutable wc = gwc[nc1];
    if ( wc == 0.0 ) continue;
    foreach(immutable p, ref force ; L.force[nc1] ) {
      // Only do lattice sites on which collision will take place.
      if ( isCollidable(L.mask[p]) ) {
	immutable psiden1 = psi(L.density[nc1][p]);
	foreach(immutable i; Iota!(0, conn.q) ) {
	  conn.vel_t nb;
	  // Todo: better array syntax.
	  foreach(immutable j; Iota!(0, conn.d) ) {
	    nb[j] = p[j] - cv[i][j];
	  }
	  if ( isBounceBack(L.mask[nb]) ) {
	    immutable prefactor = psiden1 * L.density[nc1][nb] * wc;
	    // The SC force function.
	    foreach(immutable j; Iota!(0, conn.d) ) {
	      force[j] += prefactor * cv[i][j];
	    }
	  }
	}
      }
    }
  }
+/
}

private auto eqDist(alias conn, T)(const ref T population, const double[conn.d] v) {
  static assert(population.length == conn.q);

  import std.numeric: dotProduct;

  immutable cv = conn.velocities;
  immutable cw = conn.weights;
  immutable rho0 = population.density();

  T dist;
  foreach(i; Iota!(0,conn.q)) {
    immutable vdotcv = v.dotProduct(cv[i]);
    dist[i] = rho0 * cw[i] * ( 1.0 + 0.25 * vdotcv );
  }
  return dist;
}


