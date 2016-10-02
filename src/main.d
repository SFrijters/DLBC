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
     --parameter        = additional parameter value specified in the form
                          "foo=bar" (overrides values in the parameter files;
                          can be specified multiple times)
     -r <name>          = restore a simulation from a checkpoint; name consists
                          of the name, time, and id of the simulation (e.g. if
                          the file names are of the form
                          "cp-red-foobar-20140527T135106-t00000060.h5", name is
                          "foobar-20140527T135106-t00000060")
     --show-input       = show the plain text version of the parameter input
                          and exit
     --time             = show current time when logging messages
     -v <level>         = set verbosity level to one of (Off, Fatal, Error,
                          Warning, Notification, Information, Debug) [Debug]
     --version          = show version and exit
     --warn-unset       = unset parameters are logged at Warning level [false]
     -W                 = warnings and above are fatal
   ---
   Normally, mpirun or a similar command should be used to enable parallel
   execution on n processes.
   ---
   mpirun -np <n> ./dlbc [options]
   ---
   For more information, visit $(HTTP github.com/SFrijters/DLBC, the GitHub page), or look
   at the README.md file.

   Copyright: Stefan Frijters 2011-2016

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters
*/

module main;

import dlbc.elec.elec;
import dlbc.fields.field;
import dlbc.fields.init;
import dlbc.fields.parallel;
import dlbc.getopt;
import dlbc.hooks;
import dlbc.io.checkpoint;
import dlbc.io.io;
import dlbc.io.hdf5;
import dlbc.lattice;
import dlbc.lb.advection;
import dlbc.lb.collision;
import dlbc.lb.connectivity;
import dlbc.lb.init;
import dlbc.lb.force;
import dlbc.lb.lb;
import dlbc.lb.mask;
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

  // Process the CLI parameters.
  processCLI(args);

  // Any output before startMpi() has been called will be very spammy, so better avoid it.
  startMpi(M, args);

  writeLogRN(makeHeaderString("Starting DLBC on %d CPUs.", M.size));

  showGlobalVerbosityLevel();

  // Show build-related information.
  showCompilerInfo!(VL.Information, LRF.Root)();
  showRevisionInfo!(VL.Information, LRF.Root)();

  // Prepare for HDF5 output.
  startHDF5();

  // Start timers.
  startMainTimer();
  startTimer("preloop");

  // Read, broadcast, and show parameters.
  initParameters();

  // Create, broadcast, and show id of current simulation.
  initSimulationId();

  // Execute all functions registered as plugin initializers.
  pluginRegister.execute();

  // Warn if output paths do not exist.
  checkPaths();

  // Make cartesian grid now that we have values ncx, ncy, ncz everywhere.
  reorderMpi(M, nc);

  // Initialize random number generator.
  initRNG();

  // Create the local lattice structure.
  gconn.show!(VL.Information)();
  auto L = LType(gn, components, fieldNames, M);

  // Prepare various LB related fields: fluids, advection, mask, density.
  L.prepareLBFields();
  // Prepare force and psi fields.
  L.prepareForce();

  // Check parameters, and initialize derived quantities for elec.
  L.initElecConstants();
  // Prepare various elec related fields: elChargeP, elChargeN, elPot,
  // elDiel, elField, elFluxP, elFluxN.
  L.prepareElecFields();

  // Either restore fields from checkpoints or initialize them.
  if ( isRestoring() ) {
    L.readCheckpoint();
    setTimerStartTimestep();
  }
  else {
    L.initMask();
    L.initFluids();
    L.initElec();
  }
  L.exchangeHalo();

  // Report hooks
  preAdvectionHooks.showAllRegisteredFunctions!(VL.Debug, LRF.Root)();
  postAdvectionHooks.showAllRegisteredFunctions!(VL.Debug, LRF.Root)();

  // First data dump
  L.dumpData(timestep);
  stopTimer("preloop");

  // Let's go loopy.
  L.runTimeloop();

  stopMainTimer();

  // Final wrap-up.
  showFinalAllTimers!(VL.Information, LRF.Root)();

  endHDF5();
  endMpi();

  writeLogRN(makeHeaderString("Finished DLBC run."));

  return 0;
}

/**
   The main time loop.

   Params:
     L = the lattice
*/
void runTimeloop(T)(ref T L) if ( isLattice!T ) {
  while ( timestep < timesteps ) {
    ++timestep;
    writeLogRN("Starting timestep %d", timestep);

    L.exchangeHalo();

    // Advection
    L.advectFields();

    // Electric charges
    L.executeElecTimestep();

    // Forces
    L.resetForce();
    L.addShanChenForce();
    L.addElecForce();
    L.distributeForce();

    // Collision
    L.prepareToCollide();
    L.collideFields(tau, globalAcc);

    // Output
    L.dumpData(timestep);
  }
}
