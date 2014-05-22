// Written in the D programming language.

/**
Process command line arguments.

This module uses $(D std.getopt) as a parser, and processes the result
according to the need of this program.

Copyright: Stefan Frijters 2011-2014

License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

Authors: Stefan Frijters

Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.getopt;

import std.getopt;

import dlbc.logging;
import dlbc.parameters: parameterFileNames;
import dlbc.revision;

/**
   Usage help text.
*/
private auto usage = `
DLBC: a parallel implementation of the lattice Boltzmann method
for the simulation of fluid dynamics.

Usage:
%s [options]

Options (defaults in brackets):
  -h                   show this help message and exit
  -p <path>            path to parameter file (can be specified multiple times)
  -t                   show current time when logging messages
  -v <level>           set verbosity level to one of (Off, Fatal, Error,
                       Warning, Notification, Information, Debug) [%s]
  --version            show version and exit
  -W                   warnings and above are fatal

For more information, visit https://github.com/SFrijters/DLBC, or look
at the README.md file.
`;

/**
   Process the command line arguments using $(D std.getopt).

   Params:
     args = command line arguments
*/
void processCLI(string[] args) {
  bool showHelp = false;
  bool showVersion = false;
  if ( args.length <= 1 ) {
    showHelp = true;
  }

  VL verbosityLevel = getGlobalVerbosityLevel();

  getopt( args,
          "h", &showHelp,
          "p|parameterfile", &parameterFileNames,
	  "t|time", &showTime,
          "v|verbose", &verbosityLevel,
	  "version", &showVersion,
          "W", &warningsAreFatal,
          );

  if ( showHelp ) {
    import std.stdio: writefln;
    import std.c.stdlib: exit;
    writefln(usage, revisionDesc, args[0], verbosityLevel);
    exit(0);
  }

  if ( showVersion ) {
    import std.stdio: writefln;
    import std.c.stdlib: exit;
    writefln("%s", revisionDesc);
    exit(0);
  }

  setGlobalVerbosityLevel(verbosityLevel);
}

