// Written in the D programming language.

/**
Functions that handle (parallel) output to disk.

Copyright: Stefan Frijters 2011-2014

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Stefan Frijters

Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.io.io;

import std.datetime;

import dlbc.logging;
import dlbc.io.hdf5;

@("param") FileFormat outputFormat;
@("param") string simulationName;

immutable string simulationId;

enum FileFormat {
  Ascii,
  HDF5,
}

static this() {
  simulationId = Clock.currTime().toISOString();
}

void showSimulationName() {
  writeLogRI("The name of the simulation is `%s' and its id is `%s'.", simulationName, simulationId);
}


