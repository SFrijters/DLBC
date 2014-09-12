// Written in the D programming language.

/**
   Pre-calculated connectivity options for various lattice structures.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
        TR = <tr>$0</tr>
        TH = <th>$0</th>
        TD = <td>$0</td>
        TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.lb.connectivity;

import dlbc.logging;

/**
   Global connectivity parameter.
*/
version(D1Q3) {
  alias gconn = d1q3;
}
else version(D1Q5) {
  alias gconn = d1q5;
}
else version(D2Q9) {
  alias gconn = d2q9;
}
else {
  alias gconn = d3q19;
}

/**
   The Connectivity struct contains information about the links between lattice sites.
   It is a static struct, so no need to instantiate it.
   The case of _q = 0 is a special case: no connectivity exists at all. This is required for
   non-population fields, like simple scalars, or vectors.

   Params:
     _d = number of dimensions
     _q = number of connecting vectors
*/
static immutable struct Connectivity(uint _d, uint _q) {
  static {
    static if ( _q > 0 ) {
      /**
         Type of a connecting vector.
      */
      alias vel_t = ptrdiff_t[_d];
      /**
         Number of dimensions.
      */
      enum uint d = _d;
      /// Ditto
      alias dimensions = d;
      /**
         Number of velocities.
      */
      enum uint q = _q;
      /**
         Array of velocity vectors.
      */
      enum ptrdiff_t[d][q] velocities = generateVelocities!(d, q)();
      /**
         Array of indices which point to the velocity vector in the opposite direction.
      */
      enum ptrdiff_t[q] bounce = generateBounce(generateVelocities!(d, q)());
      /**
         Weigths of the velocity vectors.
      */
      enum double[q] weights = generateWeights!(d, q)();
      /**
         Speed of sound.
      */
      enum double css = generateSpeedOfSound!(d, q)();
      /**
         Show information about the layout of the grid of processes.
      */
      void show(VL vl)() {
        import std.math;
        writeLog!(vl, LRF.Root)("Connectivity D%dQ%d:\n  velocities: %s\n  bounce: %s\n  weights: %s\n  speed of sound: %f", d, q, velocities, bounce, weights, sqrt(css));
      }
    }
    else {
      /**
         Type of a connecting vector.
      */
      alias vel_t = ptrdiff_t[_d];
      /**
         Number of dimensions.
      */
      enum uint d = _d;
      /// Ditto
      alias dimensions = d;
      /**
         Number of velocities.
      */
      enum uint q = _q;
    }
  }
}

/**
   Human readable axis identifiers.
*/
enum Axis {
  /**
     x-axis (first axis).
  */
  X,
  /**
     y-axis (second axis).
  */
  Y,
  /**
     z-axis (third axis).
  */
  Z,
}

/**
   D3Q19 connectivity, i.e. the rest vector, plus connecting vectors of length 1,
   plus connecting vectors of length sqrt(2).
*/
alias d3q19 = Connectivity!(3,19);

/**
   D3Q7 connectivity, i.e. the rest vector, plus connecting vectors of length 1.
*/
alias d3q7 = Connectivity!(3,7);

/**
   D3Q1 connectivity, i.e. only the rest vector.
*/
alias d3q1 = Connectivity!(3,1);

/**
   D3Q0 connectivity, i.e. no populations.
*/
alias d3q0 = Connectivity!(3,0);

/**
   D2Q9 connectivity, i.e. the rest vector, plus connecting vectors of length 1,
   plus connecting vectors of length sqrt(2).
*/
alias d2q9 = Connectivity!(2,9);

/**
   D2Q5 connectivity, i.e. the rest vector, plus connecting vectors of length 1.
*/
alias d2q5 = Connectivity!(2,5);

/**
   D2Q1 connectivity, i.e. only the rest vector.
*/
alias d2q1 = Connectivity!(2,1);

/**
   D2Q0 connectivity, i.e. no populations.
*/
alias d2q0 = Connectivity!(2,0);

/**
   D1Q5 connectivity.
*/
alias d1q5 = Connectivity!(1,5);

/**
   D1Q3 connectivity.
*/
alias d1q3 = Connectivity!(1,3);

/**
   D1Q1 connectivity, i.e. only the rest vector.
*/
alias d1q1 = Connectivity!(1,1);

/**
   D1Q0 connectivity, i.e. no populations.
*/
alias d1q0 = Connectivity!(1,0);

/**
   For a connectivity DdQq returns the connectivity for DdQ0.

   Params:
     conn = connectivity
*/
template dimOf(alias conn) {
  alias dimOf = Connectivity!(conn.d, 0);
}

/**
   Find velocity vectors pointing in the opposite direction and
   fill an array such that $(D velocities[bounce[i]] = -velocities[i]).
*/
private auto generateBounce(T)(const T velocities) @safe pure nothrow @nogc {
  import std.algorithm: any;
  size_t[velocities.length] bounce;
  int[velocities[0].length] diff;
  foreach(i, e1 ; velocities) {
    foreach(j, e2; velocities ) {
      diff[] = e1[] + e2[];
      if ( !any(diff[]) ) {
        bounce[i] = j;
        break;
      }
    }
  }
  return bounce;
}

private auto generateSpeedOfSound(uint d, uint q)() @safe pure nothrow @nogc {
  // 3D
  static if      ( d == 3 && q == 19 ) {
    return 1.0/3.0;
  }
  else static if ( d == 3 && q == 7 ) {
    return 1.0/3.0;
  }
  else static if ( d == 3 && q == 1 ) {
    return 1.0/3.0;
  }
  // 2D
  else static if ( d == 2 && q == 9 ) {
    return 1.0/3.0;
  }
  else static if ( d == 2 && q == 5 ) {
    return 1.0/3.0;
  }
  else static if ( d == 2 && q == 1 ) {
    return 1.0/3.0;
  }
  // 1D
  else static if ( d == 1 && q == 5 ) {
    return 1.0;
  }
  else static if ( d == 1 && q == 3 ) {
    return 1.0/3.0;
  }
  else static if ( d == 1 && q == 1 ) {
    return 1.0/3.0;
  }
  else {
    static assert(0);
  }
}

unittest {
  assert(generateSpeedOfSound!(3,19) == 1.0/3.0);
  assert(generateSpeedOfSound!(2,9) == 1.0/3.0);
  assert(generateSpeedOfSound!(1,5) == 1.0);
  assert(generateSpeedOfSound!(1,3) == 1.0/3.0);
}

private auto generateWeights(uint d, uint q)() @safe pure nothrow @nogc {
  double[q] weights;
  // 3D
  static if      ( d == 3 && q == 19 ) {
    weights[0] = 1.0/3.0;
    weights[1..7] = 1.0/18.0;
    weights[7..$] = 1.0/36.0;
  }
  else static if ( d == 3 && q == 7 ) {
    weights[0] = 1.0/4.0;
    weights[1..7] = 1.0/8.0;
  }
  else static if ( d == 3 && q == 1 ) {
    weights[0] = 1.0;
  }
  // 2D
  else static if ( d == 2 && q == 9 ) {
    weights[0] = 4.0/9.0;
    weights[1..5] = 1.0/9.0;
    weights[5..$] = 1.0/36.0;
  }
  else static if ( d == 2 && q == 5 ) {
    weights[0] = 1.0/3.0;
    weights[1..$] = 1.0/6.0;
  }
  else static if ( d == 2 && q == 1 ) {
    weights[0] = 1.0;
  }
  // 1D
  else static if ( d == 1 && q == 5 ) {
    weights[0] = 6.0/12.0;
    weights[1..3] = 2.0/12.0;
    weights[3..$] = 1.0/12.0;
  }
  else static if ( d == 1 && q == 3 ) {
    weights[0] = 4.0/6.0;
    weights[1..$] = 1.0/6.0;
  }
  else static if ( d == 1 && q == 1 ) {
    weights[0] = 1.0;
  }
  else {
    static assert(0);
  }
  return weights;
}

unittest {
  import std.algorithm: sum;
  import std.numeric: approxEqual;
  assert(approxEqual(sum(generateWeights!(3, 19)[]), 1.0));
  assert(sum(generateWeights!(3, 7)[]) == 1.0);
  assert(sum(generateWeights!(3, 1)[]) == 1.0);
  assert(sum(generateWeights!(2, 9)[]) == 1.0);
  assert(sum(generateWeights!(2, 5)[]) == 1.0);
  assert(sum(generateWeights!(2, 1)[]) == 1.0);
  assert(sum(generateWeights!(1, 5)[]) == 1.0);
  assert(sum(generateWeights!(1, 3)[]) == 1.0);
  assert(sum(generateWeights!(1, 1)[]) == 1.0);
}

private auto generateVelocities(uint d, uint q)() @safe pure nothrow @nogc {
  // 3D
  static if      ( d == 3 && q == 19 ) {
    return generateD3Q19();
  }
  else static if ( d == 3 && q == 7 ) {
    return generateD3Q7();
  }
  else static if ( d == 3 && q == 1 ) {
    return generateD3Q1();
  }
  // 2D
  else static if ( d == 2 && q == 9 ) {
    return generateD2Q9();
  }
  else static if ( d == 2 && q == 5 ) {
    return generateD2Q5();
  }
  else static if ( d == 2 && q == 1 ) {
    return generateD2Q1();
  }
  // 1D
  else static if ( d == 1 && q == 5 ) {
    return generateD1Q5();
  }
  else static if ( d == 1 && q == 3 ) {
    return generateD1Q3();
  }
  else static if ( d == 1 && q == 1 ) {
    return generateD1Q1();
  }
  else {
    static assert(0);
  }
}

private auto generateD1Q1() @safe pure nothrow @nogc {
  int[1][1] d1q1;
  d1q1[0] = [0];
  return d1q1;
}

private auto generateD1Q3() @safe pure nothrow @nogc {
  int[1][3] d1q3;
  d1q3[0..1] = generateD1Q1();
  d1q3[1] = [  1 ];
  d1q3[2] = [ -1 ];
  return d1q3;
}

private auto generateD1Q5() @safe pure nothrow @nogc {
  int[1][5] d1q5;
  d1q5[0..3] = generateD1Q3();
  d1q5[3] = [  2 ];
  d1q5[4] = [ -2 ];
  return d1q5;
}

private auto generateD2Q1() @safe pure nothrow @nogc {
  int[2][1] d2q1;
  d2q1[0] = [0, 0];
  return d2q1;
}

private auto generateD2Q5() @safe pure nothrow @nogc {
  int[2][5] d2q5;
  d2q5[0..1] = generateD2Q1();

  d2q5[1] = [1, 0];
  d2q5[2] = [-1, 0];
  d2q5[3] = [0, 1];
  d2q5[4] = [0, -1];
  return d2q5;
}

private auto generateD2Q9() @safe pure nothrow @nogc {
  int[2][9] d2q9;
  d2q9[0..5] = generateD2Q5();

  d2q9[5] = [1, 1];
  d2q9[6] = [1, -1];
  d2q9[7] = [-1, 1];
  d2q9[8] = [-1, -1];
  return d2q9;
}

private auto generateD3Q1() @safe pure nothrow @nogc {
  int[3][1] d3q1;
  d3q1[0] = [0, 0, 0];
  return d3q1;
}

private auto generateD3Q7() @safe pure nothrow @nogc {
  int[3][7] d3q7;
  d3q7[0..1] = generateD3Q1();
  d3q7[1] = [ 1, 0, 0];
  d3q7[2] = [ -1, 0, 0];
  d3q7[3] = [ 0, 1, 0];
  d3q7[4] = [ 0, -1, 0];
  d3q7[5] = [ 0, 0, 1];
  d3q7[6] = [ 0, 0, -1];
  return d3q7;
}

private auto generateD3Q19() @safe pure nothrow @nogc {
  int[3][19] d3q19;
  d3q19[0..7] = generateD3Q7();
  d3q19[7] = [ 1, 1, 0];
  d3q19[8] = [ -1, 1, 0];
  d3q19[9] = [ 0, 1, 1];
  d3q19[10] = [ 0, -1, 1];
  d3q19[11] = [ 1, 0, 1];
  d3q19[12] = [ 1, 0, -1];

  d3q19[13] = [ 1, -1, 0];
  d3q19[14] = [ -1, -1, 0];
  d3q19[15] = [ 0, 1, -1];
  d3q19[16] = [ 0, -1, -1];
  d3q19[17] = [ -1, 0, 1];
  d3q19[18] = [ -1, 0, -1];
  return d3q19;
}

/**
   Template to check if a population vector type matches a connectivity.

   Params:
     T = type to check
     conn = connectivity to match
*/
template isMatchingPopulation(T, conn) {
  import dlbc.range;
  enum isMatchingPopulation = ( T.length == conn.q );
}


