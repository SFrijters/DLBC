// Written in the D programming language.

/**
   Lattice Boltzmann collision for population fields.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
        TR = <tr>$0</tr>
        TH = <th>$0</th>
        TD = <td>$0</td>
        TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.lb.collision;

import dlbc.fields.field;
import dlbc.lb.connectivity;
import dlbc.lb.density;
import dlbc.lb.eqdist;
import dlbc.lb.force;
import dlbc.lb.mask;
import dlbc.lb.velocity;
import dlbc.range;
import dlbc.timers;

import dlbc.logging;

/**
   Let the populations of the field collide.

   Params:
     field = field of populations
     mask = mask field
     force = force field
     tau = relaxation time
*/
void collideField(T, U, V)(ref T field, in ref U mask, in ref V force, in double tau) if ( isPopulationField!T && isMaskField!U && isMatchingVectorField!(V,T) ) {
  Timers.coll.start();
  final switch(eqDistForm) {
    case eqDistForm.SecondOrder:
      field.collideFieldEqDist!(eqDistForm.SecondOrder)(mask, force, globalAcc, tau);
      break;
    case eqDistForm.ThirdOrder:
      field.collideFieldEqDist!(eqDistForm.ThirdOrder)(mask, force, globalAcc, tau);
      break;
  }
  Timers.coll.stop();
}

/// Ditto
private void collideFieldEqDist(EqDistForm eqDistForm, T, U, V)(ref T field, in ref U mask, in ref V force, in double[] globalAcc, in double tau) @safe nothrow @nogc if ( isPopulationField!T && isMaskField!U && isMatchingVectorField!(V,T) ) {
  static assert(haveCompatibleDims!(field, mask, force));
  assert(haveCompatibleLengthsH(field, mask, force));
  assert(globalAcc.length == field.dimensions);

  alias conn = field.conn;

  immutable omega = 1.0 / tau;
  foreach(immutable p, ref pop; field) {
    if ( isCollidable(mask[p]) ) {
      immutable den = pop.density();
      double[conn.d] dv;
      foreach(immutable vd; Iota!(0,conn.d) ) {
        dv[vd] = tau * ( globalAcc[vd] + force[p][vd] / den);
      }
      immutable eq = eqDist!(eqDistForm, conn)(pop, dv);
      foreach(immutable vq; Iota!(0,conn.q) ) {
        pop[vq] = pop[vq] * ( 1.0 - omega ) + omega * eq[vq];
      }
    }
  }
}

