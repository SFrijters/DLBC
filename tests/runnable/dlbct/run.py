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

def runTest(options, thisTest):
    from coverage import mergeCovLsts
    """ Run all parameter sets for a single test. Returns number of errors encountered. """
    logNotification("Running subtests ...")

    np = thisTest.np

    if ( thisTest.parameters ):
        map = mapParameterMatrix(thisTest)
        for i, m in enumerate(map):
            # Get the parallel.nc parameter from the parameter set, if it's included
            # If it is, set np to the product of its values
            nc = getNC(m)
            if ( nc ):
                np = reduce(lambda x, y: int(x) * int(y), nc[1:-1].split(","), 1)

            if ( options.only_first ):
                if ( i == 0 ):
                    logInformation("  Running parameter set %d of %d (only this one will be executed) ..." % (i+1, thisTest.nSubtests))
                else:
                    logInformation("  Skipping parameter set %d of %d ..." % (i+1, thisTest.nSubtests))
                    thisTest.skipped[i] = True
                    continue
            elif ( options.only_serial and np > 1):
                thisTest.skipped[i] = True
                logInformation("  Parameter set %d of %d has np > 1, skipping ..." % (i+1, thisTest.nSubtests))
                continue
            else:
                logInformation("  Running parameter set %d of %d ..." % (i+1, thisTest.nSubtests))

            # Prepare command
            command = prepareSubtestCommand(options, thisTest, m)

            # Run subtest
            runSubtest(command, thisTest, i)

            # Postprocessing
            if ( options.timers or options.timers_all ):
                moveTimersData(thisTest.testRoot, options.dub_compiler)

            if ( not options.coverage ):
                if ( not options.compare_none ):
                    compareTest(options, thisTest, i, m, np)
            else:
                if ( thisTest.errors[i] == 0 ):
                    covpath = constructCoveragePath(options.dlbc_root)
                    mergeCovLsts(options, thisTest.testRoot, covpath)
                else:
                    logNotification("No succesful tests, not merging coverage information ...")

    else:
        if ( options.only_serial and np > 1):
            thisTest.skipped[0] = True
            logInformation("  Parameter set 1 of 1 has np > 1, skipping ...")
            return

        logInformation("  Running parameter set 1 of 1 ...")

        command = prepareSubtestCommand(options, thisTest)

        runSubtest(command, thisTest, 0)

        if ( options.timers or options.timers_all ):
            moveTimersData(thisTest.testRoot, options.dub_compiler)

        if ( not options.coverage ):
            if ( not options.compare_none ):
                compareSingleTest(options, thisTest)
        else:
            if ( thisTest.errors[0] == 0 ):
                covpath = constructCoveragePath(options.dlbc_root)
                mergeCovLsts(options, thisTest.testRoot, covpath)
            else:
                logNotification("No succesful tests, not merging coverage information ...")

def runSubtest(command, thisTest, i):
    """ Run a single parameter set for a single test. Returns number of errors encountered. """
    import time
    logDebug("  Executing '" + " ".join(command) + "'")
    t0 = time.time()
    p = subprocess.Popen(command, cwd=thisTest.testRoot)
    p.communicate()
    timeElapsed = time.time() - t0
    thisTest.timers[i] = timeElapsed
    if ( p.returncode != 0 ):
        logError("DLBC returned %d" % p.returncode)
        thisTest.errors[i] += 1
    logInformation("  Took %f seconds." % timeElapsed)

def getNC(map):
    """ Get nc from parallel.nc if available. """
    for p in map:
        if ( p[0] == "parallel.nc" ):
            return p[1]
    return "[0,0]"

def mapParameterMatrix(thisTest):
    """ Construct the cartesian product of all parameter values. """
    tuples = []
    for p in thisTest.parameters:
        values = []
        for v in p["values"]:
            values.append((p["parameter"],v))
        tuples.append(values)
    import itertools
    return itertools.product(*tuples)

def cleanTest(thisTest):
    """ Clean a single test. This removes all coverage *.lst files, as well as all paths listed in clean. """
    import glob
    import shutil
    logNotification("Cleaning test ...")

    testRoot = thisTest.testRoot
    for c in thisTest.clean:
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

def prepareSubtestCommand(options, thisTest, m = None):

    exePath = constructExeTargetPath(thisTest.configuration, options.dub_build, options.dub_compiler, options.dlbc_root)
    command = [ "mpirun", "-np", str(thisTest.np), exePath, "-p", thisTest.inputFile, "-v", options.dlbc_verbosity, "--parameter", "timers.enableIO=true"]

    if ( thisTest.parameters ):
        command = command + constructParameterCommand(m)

    command = command + coverageCommand(options, thisTest)
    command = command + fastCommand(options, thisTest)
    command = command + checkpointCommand(options, thisTest)
    return command

def constructParameterCommand(tuple):
    """ Make a proper command line option for a parameter. """
    command = []
    for p in tuple:
        command.append("--parameter")
        command.append(p[0] + "=" + p[1])
    return command

def coverageCommand(options, thisTest):
    command = []
    if ( options.coverage and thisTest.coverage ):
        coverageOverrides = thisTest.coverage
        try:
            parameters = coverageOverrides["parameters"]
            for p in parameters:
                command.append("--parameter")
                command.append(p["parameter"] + "=" + p["value"])
        except KeyError:
            logFatal("coverage parameter does not have a well-formed parameters parameter.")
    return command

def fastCommand(options, thisTest):
    command = []
    if ( options.fast and thisTest.fast and not options.coverage ):
        fastOverrides = thisTest.fast
        try:
            parameters = fastOverrides["parameters"]
            for p in parameters:
                command.append("--parameter")
                command.append(p["parameter"] + "=" + p["value"])
        except KeyError:
            logFatal("fast parameter does not have a well-formed parameters parameter.")
    return command

def checkpointCommand(options, thisTest):
    command = []
    if ( thisTest.checkpoint ):
        checkpoint = thisTest.checkpoint
        try:
            name = checkpoint["name"]
            command.append("-r")
            command.append(name)
        except KeyError:
            logFatal("checkpoint parameter does not have a well-formed name parameter.")
    return command

def reportRunTimers(testList, warnTime):
    totalTime = 0.0
    timeWarnings = 0

    tests = 0
    skipped = 0
    errors = 0
    disabled = 0

    if ( len(testList) > 0 ):
        tnlen = max(max([len(t.timerName) for t in testList]), 16) # 16 is the length of a parameter set name

        logNotification("\n" + "="*80 + "\n")
        logNotification("  %*s %12s" % (tnlen, "test", "time (s)"))
        logNotification("%s" % "_"*(tnlen+15))

        for test in sorted(testList, key=lambda test: test.timerName):
            nSubtests = test.nSubtests
            if ( not test.disabled ):
                tests += nSubtests

            time = sum(test.timers)
            err = sum(test.errors)
            totalTime += time
            prefix = " "

            if ( nSubtests == 1 or test.disabled ):
                if ( time > warnTime ):
                    prefix = "!"
                    timeWarnings += 1

                if ( err > 0 ):
                    prefix = "X"
                    errors += 1
                elif ( test.skipped[0] ):
                    prefix = "s"
                    skipped += 1
                elif ( test.disabled ):
                    prefix = "D"
                    disabled += 1

                if ( time == 0 ):
                    logNotification("%s %*s %12s" % (prefix, tnlen, test.timerName, "---"))
                else:
                    logNotification("%s %*s %12e" % (prefix, tnlen, test.timerName, time))
            else:
                logNotification("%s %*s %12e" % (prefix, tnlen, test.timerName, time))

                for i in range(0, nSubtests):

                    if ( test.timers[i] > warnTime ):
                        prefix = "!"
                        timeWarnings += 1

                    if ( test.errors[i] > 0 ):
                        prefix = "X"
                        errors += 1
                    elif ( test.skipped[i] ):
                        prefix = "s"
                        skipped += 1

                    name = "Parameter set %2d" % ( i + 1 )
                    time = test.timers[i]
                    if ( time == 0 ):
                        logNotification("%s %*s %12s" % (prefix, tnlen, name, "---"))
                    else:
                        logNotification("%s %*s %12e" % (prefix, tnlen, name, time))

        logNotification("%s" % "_"*(tnlen+15))

        import time
        fTime = time.strftime("%H:%M:%S", time.gmtime(totalTime))

        logNotification("  %*s %12e" % (tnlen, "total", totalTime))
        logNotification("  %*s %12s" % (tnlen, "", fTime))

    logNotification("\nFound %d subtests (%d tests are disabled) and skipped %d; executed %d." % ( tests, disabled, skipped, tests-disabled-skipped ) )

    if ( timeWarnings == 1 ):
        logNotification("  Encountered %d time warning (t > %.1f seconds)." % (timeWarnings, warnTime))
    elif ( timeWarnings > 1 ):
        logNotification("  Encountered %d time warnings (t > %.1f seconds)." % (timeWarnings, warnTime))
    else:
        logNotification("  Encountered zero time warnings (t > %.1f seconds)." % warnTime)

    if ( errors == 1 ):
        logNotification("  Encountered %d error." % errors)
    elif ( errors > 1 ):
        logNotification("  Encountered %d errors." % errors)
    else:
        logNotification("  Encountered zero errors.")


