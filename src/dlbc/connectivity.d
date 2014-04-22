// Written in the D programming language.

/**
Pre-calculated connectivity options for various lattice structures.

Copyright: Stefan Frijters 2011-2014

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Stefan Frijters

Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module connectivity;

/**
   D3Q1 connectivity, i.e. the rest vector [0, 0, 0].
*/
static immutable auto d3q1 = generateD3Q1();
/**
   D3Q7 connectivity, i.e. the rest vector, plus connecting vectors of length 1.
*/
static immutable auto d3q7 = generateD3Q7();
/**
   D3Q19 connectivity, i.e. the rest vector, plus connecting vectors of length 1,
   plus connecting vectors of length sqrt(2).
*/
static immutable auto d3q19 = generateD3Q19();

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

