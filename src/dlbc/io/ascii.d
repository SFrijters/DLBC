// Written in the D programming language.

/**
   Functions that handle ASCII output to disk.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
        TR = <tr>$0</tr>
        TH = <th>$0</th>
        TD = <td>$0</td>
        TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.io.ascii;

import dlbc.io.io;
import dlbc.logging;
import dlbc.timers;
import std.stdio;

void dumpProfiles(T)(ref T L, const string name, const uint time) {
  Timers.io.start();

  auto fileName = makeFilenameOutput!(FileFormat.Ascii)(name ~ "x", time);
  writeLogRI("Attempting to write profile to file '%s'.", fileName);

  auto f = File(fileName, "w"); // open for writing
  f.writeln("Not yet implemented!");
  Timers.io.stop();
}

