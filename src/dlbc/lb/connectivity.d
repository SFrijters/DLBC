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

immutable struct Connectivity(uint _d, uint _q) {
  enum int d = _d;
  enum int q = _q;
  enum int[d][q] velocities = generateVelocities!(d, q);
  enum int[q] bounce = generateBounce(generateVelocities!(d, q));
  enum double[q] weights = generateWeights(generateVelocities!(d, q));
  enum double css = 1.0/3.0;
}

/**
   D3Q19 connectivity, i.e. the rest vector, plus connecting vectors of length 1,
   plus connecting vectors of length sqrt(2).
*/
auto d3q19 = new immutable Connectivity!(3,19);

auto d2q9 = new immutable Connectivity!(2,9);

/**
   Global connectivity parameter.
*/
alias gconn = d3q19;

private auto generateBounce(T)(const T velocities) {
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

private auto generateWeights(T)(const T velocities) {
  import std.algorithm: reduce;
  double[velocities.length] weights;
  weights[0] = 1.0/3.0;
  weights[1..7] = 1.0/18.0;
  weights[7..$] = 1.0/36.0;
  return weights;
}

private auto generateVelocities(uint d, uint q)() {
  static if ( d == 3 ) {
    static if ( q == 1) {
      return generateD3Q1();
    }
    else static if ( q == 7 ) {
      return generateD3Q7();
    }
    else static if ( q == 19 ) {
      return generateD3Q19();
    }
    else {
      static assert(0);
    }
  }
  else static if ( d == 2 ) {
    static if ( q == 9 ) {
      return generateD2Q9();
    }
    else {
      static assert(0);
    }
  }
  else {
    static assert(0);
  }
}

private auto generateD2Q9() pure @safe nothrow {
  int[2][9] d2q9;
  d2q9[0] = [0, 0];

  d2q9[1] = [1, 0];
  d2q9[2] = [-1, 0];
  d2q9[3] = [0, 1];
  d2q9[4] = [0, -1];
  d2q9[5] = [1, 1];
  d2q9[6] = [1, -1];
  d2q9[7] = [-1, 1];
  d2q9[8] = [-1, -1];
  return d2q9;
}

private auto generateD3Q1() pure @safe nothrow {
  int[3][1] d3q1;
  d3q1[0] = [0, 0, 0];
  return d3q1;
}

private auto generateD3Q7() pure @safe nothrow {
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

private auto generateD3Q19() pure @safe nothrow {
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

