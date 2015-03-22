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

runSubtestTimers = {}
runSubtestErrors = {}

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

def runSubtest(command, testRoot, timerName):
    """ Run a single parameter set for a single test. Returns number of errors encountered. """
    import time
    nerr = 0
    logDebug("  Executing '" + " ".join(command) + "'")
    t0 = time.time()
    p = subprocess.Popen(command, cwd=testRoot)
    p.communicate()
    if ( p.returncode != 0 ):
        nerr += logError("DLBC returned %d" % p.returncode)
    timeElapsed = time.time() - t0
    runSubtestTimers[timerName] = timeElapsed
    runSubtestErrors[timerName] = p.returncode
    logInformation("  Took %f seconds." % timeElapsed)
    return nerr

def getNC(map):
    """ Get nc from parallel.nc if available. """
    for p in map:
        if ( p[0] == "parallel.nc" ):
            return p[1]
    return "[0,0]"

def runTest(options, testRoot, testName, configuration, inputFile, np, parameters, checkpoint, compare, plot, coverageOverrides, fastOverrides):
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
                timerName = os.path.relpath(os.path.join(testRoot, testName), "tests")
            elif ( options.only_serial and np > 1):
                logInformation("  Parameter set %d of %d has np > 1, skipping ..." % (i+1, nSubtests))
                continue
            else:
                logInformation("  Running parameter set %d of %d ..." % (i+1, nSubtests))
                timerName = os.path.relpath(os.path.join(testRoot, testName), "tests") + " %2d" % (i+1)

            # Prepare command
            command = [ "mpirun", "-np", str(np), exePath, "-p", inputFile, "-v", options.dlbc_verbosity, "--parameter", "timers.enableIO=true" ]
            command = command + constructParameterCommand(m)

            command = command + coverageCommand(options, coverageOverrides)
            command = command + fastCommand(options, fastOverrides)
            command = command + checkpointCommand(options, checkpoint)

            # Run subtest
            nerr += runSubtest(command, testRoot, timerName)

            # Postprocessing
            if ( options.timers or options.timers_all ):
                moveTimersData(testRoot, options.dub_compiler)

            if ( not options.coverage ):
                compareThis = replaceTokensInCompare(compare, m, np)
                if ( not options.compare_none ):
                    nerr += compareTest(compareThis, testRoot, options.dub_compiler, options.compare_strict, options.compare_lax )

            if ( options.only_first ):
                break

    else:
        if ( options.only_serial and np > 1):
            logInformation("  Parameter set 1 of 1 has np > 1, skipping ...")
            return nerr
        logInformation("  Running parameter set 1 of 1 ...")
        timerName = os.path.relpath(os.path.join(testRoot, testName), "tests")
        command = [ "mpirun", "-np", str(np), exePath, "-p", inputFile, "-v", options.dlbc_verbosity, "--parameter", "timers.enableIO=true"]

        command = command + coverageCommand(options, coverageOverrides)
        command = command + fastCommand(options, fastOverrides)
        command = command + checkpointCommand(options, checkpoint)

        nerr += runSubtest(command, testRoot, timerName)

        if ( options.timers or options.timers_all ):
            moveTimersData(testRoot, options.dub_compiler)

        if ( not options.coverage ):
            if ( not options.compare_none ):
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

def coverageCommand(options, coverageOverrides):
    command = []
    if ( options.coverage and coverageOverrides ):
        try:
            parameters = coverageOverrides["parameters"]
            for p in parameters:
                command.append("--parameter")
                command.append(p["parameter"] + "=" + p["value"])
        except KeyError:
            logFatal("coverage parameter does not have a well-formed parameters parameter.")
    return command

def fastCommand(options, fastOverrides):
    command = []
    if ( options.fast and fastOverrides):
        try:
            parameters = fastOverrides["parameters"]
            for p in parameters:
                command.append("--parameter")
                command.append(p["parameter"] + "=" + p["value"])
        except KeyError:
            logFatal("fast parameter does not have a well-formed parameters parameter.")
    return command

def checkpointCommand(options, checkpoint):
    command = []
    if ( checkpoint ):
        try:
            name = checkpoint["name"]
            command.append("-r")
            command.append(name)
        except KeyError:
            logFatal("checkpoint parameter does not have a well-formed name parameter.")
    return command

def reportRunTimers(warnTime):
    totalTime = 0.0
    timeWarnings = 0

    if ( len(runSubtestTimers) > 0 ):
        tnlen = max([len(t) for t in runSubtestTimers])

        logNotification("\n" + "="*80 + "\n")
        logNotification("  %*s %12s" % (tnlen, "test", "time (s)"))
        logNotification("%s" % "_"*(tnlen+15))

        for test in sorted(runSubtestTimers):
            time = runSubtestTimers[test]
            err = runSubtestErrors[test]
            totalTime += time
            prefix = " "
            if ( time > warnTime ):
                prefix = "!"
                timeWarnings += 1

            if ( err > 0 ):
                prefix = "X"

            logNotification("%s %*s %12e" % (prefix, tnlen, test, time))

        logNotification("%s" % "_"*(tnlen+15))

        import time
        fTime = time.strftime("%H:%M:%S", time.gmtime(totalTime))

        logNotification("  %*s %12e" % (tnlen, "total", totalTime))
        logNotification("  %*s %12s" % (tnlen, "", fTime))

    if ( timeWarnings > 0 ):
        if ( timeWarnings == 1 ):
            logNotification("\nEncountered %d time warning (t > %.1f seconds)." % (timeWarnings, warnTime))
        else:
            logNotification("\nEncountered %d time warnings (t > %.1f seconds)." % (timeWarnings, warnTime))
    else:
        logNotification("\nEncountered zero time warnings (t > %.1f seconds)." % warnTime)

