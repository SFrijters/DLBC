// Written in the D programming language.

/**
   DLBC is a parallel implementation of the lattice Boltzmann method
   for the simulation of fluid dynamics.

   Usage:
   ---
   ./dlbc [options]
   ---
   Options (defaults in brackets):
   ---
     -h                 = show this help message and exit
     -p <path>          = path to parameter file (can be specified multiple times)
     -r <name>          = restore a simulation from a checkpoint; name consists
                          of the name, time, and id of the simulation (e.g. if
                          the file names are of the form
                          "cp-red-foobar-t00000060-20140527T135106.h5", name is
                          "foobar-t00000060-20140527T135106")
     -t                 = show current time when logging messages
     -v <level>         = set verbosity level to one of (Off, Fatal, Error,
                          Warning, Notification, Information, Debug) [%s]
     --version          = show version and exit
     -W                 = warnings and above are fatal
   ---
   Normally, mpirun or a similar command should be used to enable parallel
   execution on n processes.
   ---
   mpirun -np <n> ./dlbc [options]
   ---
   For more information, visit $(HTTP github.com/SFrijters/DLBC, the GitHub page), or look
   at the README.md file.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
        TR = <tr>$0</tr>
        TH = <th>$0</th>
        TD = <td>$0</td>
        TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module main;

public import dlbc.fields.field;
public import dlbc.fields.init;
public import dlbc.fields.parallel;
public import dlbc.getopt;
public import dlbc.io.checkpoint;
public import dlbc.io.io;
public import dlbc.io.hdf5;
public import dlbc.lattice;
public import dlbc.lb.lb;
public import dlbc.logging;
public import dlbc.parallel;
public import dlbc.parameters;
public import dlbc.random;
public import dlbc.timers;
public import dlbc.versions;

import tests.test;

/**
   The Main Is Mother, the Main Is Father.

   Params:
     args = command line arguments

   Returns:
     Zero exit code for success, non-zero exit code for failure.
*/
int main(string[] args ) {
  version(unittest) {
    globalVerbosityLevel = VL.Debug;
  }

  // Process the CLI parameters.
  processCLI(args);

  // Any output before startMpi() has been called will be very spammy, so better avoid it.
  startMpi(args);

  writeLogRN(makeHeaderString("Starting DLBC on %d CPUs.", M.size));

  showGlobalVerbosityLevel();

  // Show build-related information.
  showCompilerInfo!(VL.Information, LRF.Root);
  showRevisionInfo!(VL.Information, LRF.Root);

  // Prepare for HDF5 output.
  startHDF5();

  // Start Main timer.
  initAllTimers();
  Timers.main.start!(VL.Debug, LRF.None);

  // Try and create the local lattice structure.
  if ( ! isTesting() ) {
    initParameters();
    initCommon();
    auto L = Lattice!(gconn)(M);
    initLattice(L);
    runTimeloop(L);
  }
  else {
    version(unittest) {
      runTests();
    }
  }

  Timers.main.stop();

  showFinalAllTimers!(VL.Information, LRF.Root);

  endHDF5();
  endMpi();

  writeLogRN(makeHeaderString("Finished DLBC run."));

  return 0;
}

void runTimeloop(T)(ref T L) {
  L.dumpData(timestep);
  while ( timestep < timesteps ) {
    ++timestep;
    writeLogRN("Starting timestep %d", timestep);

    foreach(ref e; L.fluids) {
      e.advectField!gconn(L.mask, L.advection);
    }
    L.exchangeHalo();

    L.resetForce();
    if ( enableShanChen ) {
      L.addShanChenForce!gconn();
    }

    // L.resetForce();
    // L.addShanChenForce!gconn();

    foreach(i, ref e; L.fluids) {
      e.collideField!gconn(L.mask, L.force[i]);
    }
    L.exchangeHalo(); // Remove one of these?

    // writeLogRI("Global mass = %f", L.red.globalMass(L.mask));
    // writeLogRI("Global momentum = %s", L.red.globalMomentum!(gconn)(L.mask));
    L.dumpData(timestep);
  }
}

void initCommon() {
  // Show name and id of the current simulation.
  broadcastSimulationId();

  // Warn if output paths do not exist.
  checkPaths();

  // Make cartesian grid now that we have values ncx, ncy, ncz everywhere.
  reorderMpi();

  // Initialize random number generator.
  initRNG();
}
