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

import dlbc.fields.field;
import dlbc.fields.init;
import dlbc.fields.parallel;
import dlbc.getopt;
import dlbc.io.io;
import dlbc.io.hdf5;
import dlbc.lattice;
import dlbc.lb.lb;
import dlbc.logging;
import dlbc.parallel;
import dlbc.parameters;
import dlbc.random;
import dlbc.timers;
import dlbc.versions;

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

  // Read, broadcast, and show parameters.
  if (M.isRoot) {
    readParameterSetFromCliFiles();
  }
  bcastParameters();
  showParameters!(VL.Information, LRF.Root);

  // Set secondary values based on parameters.
  processParameters();

  // Show name and id of the current simulation.
  broadcastSimulationId();

  // Warn if output paths do not exist.
  checkPaths();

  // Make cartesian grid now that we have values ncx, ncy, ncz everywhere.
  reorderMpi();

  // Initialize random number generator.
  initRNG();

  // Try and create the local lattice structure.
  auto L = Lattice!(gconn)(M);

  initForce!gconn(L);

  // foreach(ref e; L.fluids) {
  //   e.initEquilibriumDensity!gconn(0.5);
  // }
  // L.fluids[0].initEquilibriumDensity!gconn(1.0);
  // L.fluids[1].initEquilibriumDensity!gconn(0.5);

  // L.fluids[0][2,2,2] = 2.0/gconn.q;

  L.mask.initMask();

  foreach(ref e; L.fluids) {
    e.initRandomEquilibriumDensity!gconn(0.5);
  }

  L.mask.dumpField("mask", 0);
  L.exchangeHalo();
  L.dumpData(timestep);
  L.dumpCheckpoint(timestep);

  for ( timestep = 1; timestep <= timesteps; ++timestep ) {
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
    L.dumpCheckpoint(timestep);
  }

  Timers.main.stop();

  showFinalAllTimers!(VL.Information, LRF.Root);

  endHDF5();
  endMpi();

  writeLogRN(makeHeaderString("Finished DLBC run."));

  return 0;
}

