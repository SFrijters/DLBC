#!/usr/bin/env python

"""
Wrappers to run tests and compare the results to their reference datasets.
"""

import os
import subprocess

from compare import *
from logging import *
from path import *
from plot import *
from timers import *

def mapParameterMatrix(parameters):
    """ Construct the cartesian product of all parameter values. """
    tuples = []
    n = 1
    for p in parameters:
        values = []
        for v in p["values"]:
            values.append((p["parameter"],v))
        n *= len(values)
        tuples.append(values)
    import itertools
    return itertools.product(*tuples), n

def constructParameterCommand(tuple):
    """ Make a proper command line option for a parameter. """
    command = []
    for p in tuple:
        command.append("--parameter")
        command.append(p[0] + "=" + p[1])
    return command

def runSubtest(command, testRoot):
    """ Run a single parameter set for a single test. Returns number of errors encountered. """
    import time
    nerr = 0
    logDebug("  Executing '" + " ".join(command) + "'")
    t0 = time.time()
    p = subprocess.Popen(command, cwd=testRoot)
    p.communicate()
    if ( p.returncode != 0 ):
        nerr += logError("DLBC returned %d" % p.returncode)
    logInformation("  Took %f seconds." % (time.time() - t0))
    return nerr

def getNC(map):
    """ Get nc from parallel.nc if available. """
    for p in map:
        if ( p[0] == "parallel.nc" ):
            return p[1]
    return "[0,0]"

def runTest(options, testRoot, configuration, inputFile, np, parameters, compare, plot):
    """ Run all parameter sets for a single test. Returns number of errors encountered. """
    logNotification("Running subtests ...")
    nerr = 0
    exePath = constructExeTargetPath(configuration, options.dub_build, options.dub_compiler, options.dlbc_root)
    if ( parameters ):
        map, nSubtests = mapParameterMatrix(parameters)
        for i, m in enumerate(map):
            # Get the parallel.nc parameter from the parameter set, if it's included
            nc = getNC(m)
            # If it is, set np to the product of its values
            if ( nc != "[0,0]" ):
                np = reduce(lambda x, y: int(x) * int(y), nc[1:-1].split(","), 1)

            if ( options.only_first ):
                logInformation("  Running parameter set %d of %d (only this one will be executed) ..." % (i+1, nSubtests))
            else:
                logInformation("  Running parameter set %d of %d ..." % (i+1, nSubtests))
            command = [ "mpirun", "-np", str(np), exePath, "-p", inputFile, "-v", options.dlbc_verbosity ]
            if ( options.coverage ):
                command.append("--coverage")
            command = command + constructParameterCommand(m)
            if ( options.timers or options.timers_all):
                command.append("--parameter")
                command.append("timers.enableIO=true")
            nerr += runSubtest(command, testRoot)

            if ( options.timers or options.timers_all ):
                moveTimersData(testRoot, options.dub_compiler)

            if ( not options.coverage ):
                compareThis = replaceTokensInCompare(compare, m, np)
                nerr += compareTest(compareThis, testRoot, options.dub_compiler, options.compare_strict, options.compare_lax )

            if ( options.only_first ):
                break

    else:
        logInformation("  Running parameter set 1 of 1 ...")
        command = [ "mpirun", "-np", str(np), exePath, "-p", inputFile, "-v", options.dlbc_verbosity ]
        if ( options.coverage ):
            command.append("--coverage")
        if ( options.timers or options.timers_all ):
            command.append("--parameter")
            command.append("timers.enableIO=true")
        nerr += runSubtest(command, testRoot)

        if ( options.timers or options.timers_all ):
            moveTimersData(testRoot, options.dub_compiler)

        if ( not options.coverage ):
            nerr += compareTest(compare, testRoot, options.dub_compiler, options.compare_strict, options.compare_lax )
    if ( options.plot ):
        plotTest(testRoot, plot, False)
    return nerr

def cleanTest(testRoot, clean):
    """ Clean a single test. This removes all coverage *.lst files, as well as all paths listed in clean. """
    import glob
    import shutil
    logNotification("Cleaning test ...")
    for c in clean:
        f = os.path.join(testRoot, c)
        if ( os.path.exists(f) ):
            logDebug("  Removing '%s'" % f )
            shutil.rmtree(f)
    for c in glob.glob(os.path.join(testRoot, "*.lst")):
        f = os.path.join(testRoot, c)
        if ( os.path.exists(f) ):
            logDebug("  Removing '%s'" % f )
            os.remove(f)
    src = os.path.join(testRoot, "src")
    if ( os.path.exists(src) ):
        os.remove(src)
    for c in glob.glob(os.path.join(testRoot, "dlbc-*-*-*")):
        f = os.path.join(testRoot, c)
        if ( os.path.exists(f) ):
            logDebug("  Removing '%s'" % f )
            os.remove(f)

