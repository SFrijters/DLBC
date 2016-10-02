// Written in the D programming language.

/**
   Process command line arguments.

   This module uses $(D std.getopt) as a parser, and processes the result
   according to the need of this program.

   Copyright: Stefan Frijters 2011-2016

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters
*/

module dlbc.getopt;

import std.getopt;

import dlbc.lb.connectivity: gconn;
import dlbc.io.io: restoreString;
import dlbc.logging;
import dlbc.parameters: commandLineParameters, parameterFileNames, showInputFileDataRaw, warnUnset;
import dlbc.revision;

/**
   Usage help text.
*/
private auto usage = `
DLBC (version %s, D%dQ%d): a parallel implementation of the lattice Boltzmann method
for the simulation of fluid dynamics.

Executable built using %s compiler (%s); front-end version %d.%03d.

Usage:
%s [options]

Options (defaults in brackets):
  -h                   show this help message and exit
  -p <path>            path to parameter file (can be specified multiple times)
  --parameter          additional parameter value specified in the form
                       "foo=bar" (overrides values in the parameter files;
                       can be specified multiple times)
  -r <name>            restore a simulation from a checkpoint; name consists
                       of the name, time, and id of the simulation (e.g. if
                       the file names are of the form
                       "cp-red-foobar-20140527T135106-t00000060.h5", name is
                       "foobar-20140527T135106-t00000060")
  --show-input         show the plain text version of the parameter input
                       and exit
  --time               show current time when logging messages
  -v <level>           set verbosity level to one of (Off, Fatal, Error,
                       Warning, Notification, Information, Debug) [%s]
  --version            show version and exit
  --warn-unset         unset parameters are logged at Warning level [false]
  -W                   warnings and above are treated as fatal errors

Normally, mpirun or a similar command should be used to enable parallel
execution on n processes.

mpirun -np <n> ./dlbc [options]

For more information, visit https://github.com/SFrijters/DLBC, or look
at the README.md file.
`;

/**
   Process the command line arguments using $(D std.getopt).

   Params:
     args = command line arguments
*/
void processCLI(string[] args) {
  import std.compiler;
  import std.c.stdlib: exit;
  import std.stdio: writefln;
  import std.conv, std.string;
  bool showHelp = false;
  bool showInput = false;
  bool showVersion = false;
  if ( args.length <= 1 ) {
    showHelp = true;
  }

  VL verbosityLevel = getGlobalVerbosityLevel();

  try {
    getopt( args,
            "h", &showHelp,
            "p|parameterfile", &parameterFileNames,
            "parameter", &commandLineParameters,
            "r|restore", &restoreString,
            "show-input", &showInput,
            "time", &showTime,
            "v|verbose", &verbosityLevel,
            "version", &showVersion,
            "warn-unset", &warnUnset,
            "W", &warningsAreFatal,
            );
  }
  catch(GetOptException e) {
    writeLogF("%s",e.toString().splitLines()[0]);
  }
  catch(ConvException e) {
    writeLogF("%s",e.toString().splitLines()[0]);
  }

  if ( showHelp ) {
    writefln(usage, revisionDesc, gconn.d, gconn.q, std.compiler.name, to!string(std.compiler.vendor), std.compiler.version_major, std.compiler.version_minor, args[0], verbosityLevel);
    exit(0);
  }

  if ( showVersion ) {
    writefln("%s", revisionDesc);
    exit(0);
  }

  if ( showInput ) {
    showInputFileDataRaw();
    exit(0);
  }

  setGlobalVerbosityLevel(verbosityLevel);
}

