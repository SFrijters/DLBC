#!/usr/bin/env python

"""
Wrappers for the dub build process for DLBC.
"""

import os
import shutil
import subprocess

from logging import *
from path import *

buildTimers = {}

dubCompilerChoices = [ "dmd", "gdc", "ldc2" ]
dubBuildChoices = [ "release", "cov", "unittest-cov", "profile" ]
dubBuildBuildAll = [ "release", "cov", "unittest-cov" ]
dlbcConfigurations = [ "d1q3", "d1q5", "d2q9", "d3q19" ]

def dubBuild(compiler, build, configuration, force, dlbcRoot):
    """ Build a DLBC executable for a particular compiler/build/configuration, if needed. """
    import dlbct.logging
    logNotification("Preparing executable '%s' ..." % constructExeTargetName(configuration, build, compiler))
    exePath = constructExeTargetPath(configuration, build, compiler, dlbcRoot)
    if ( not force ):
        if ( os.path.isfile(exePath) ):
            logInformation("  Found executable '%s'." % exePath )
            return

    logInformation("  Building executable '%s' ..." % exePath)
    command = ["dub", "build", "--compiler", compiler, "-b", build, "-c", configuration, "--force"]
    if ( dlbct.logging.verbosityLevel < 6 ):
        command.append("--vquiet")
    logDebug("  Executing '" + " ".join(command) + "'.")
    p = subprocess.Popen(command, cwd=dlbcRoot)
    p.communicate()
    if ( p.returncode != 0 ):
        logFatal("Dub build command returned %d." % p.returncode, p.returncode)
    shutil.move(os.path.join(dlbcRoot, "dlbc-" + configuration), exePath)

def buildAll(options):
    """ Build all combinations of build type and configuration for the current compiler. """
    nCombinations = len(dlbcConfigurations) * len(dubBuildBuildAll)
    n = 1
    import time
    for c in dlbcConfigurations:
        for b in dubBuildBuildAll:
            logNotification("Building executable %d of %d ..." % ( n, nCombinations) )
            t0 = time.time()
            dubBuild(options.dub_compiler, b, c, options.dub_force, options.dlbc_root)
            timeElapsed = time.time() - t0
            timerName = constructExeTargetName(c, b, options.dub_compiler)
            buildTimers[timerName] = timeElapsed
            logInformation("  Took %f seconds." % timeElapsed)
            n += 1

def reportBuildTimers(warnTime):
    """ Report on the contents of the buildTimers dictionary. """
    bnlen = max([len(t) for t in buildTimers])

    logNotification("\n" + "="*80 + "\n")
    logNotification("  %*s %12s" % (bnlen, "build", "time (s)"))
    logNotification("%s" % "_"*(bnlen+15))

    totalTime = 0.0
    warnings = 0
    for build in sorted(buildTimers):
        time = buildTimers[build]
        totalTime += time
        if ( time > warnTime ):
            logNotification("! %*s %12e" % (bnlen, build, time))
            warnings += 1
        else:
            logNotification("  %*s %12e" % (bnlen, build, time))

    logNotification("%s" % "_"*(bnlen+15))

    import time
    fTime = time.strftime("%H:%M:%S", time.gmtime(totalTime))

    logNotification("  %*s %12e" % (bnlen, "total", totalTime))
    logNotification("  %*s %12s" % (bnlen, "", fTime))

    if ( warnings > 0 ):
        if ( warnings == 1 ):
            logNotification("Encountered %d time warning." % warnings)
        else:
            logNotification("Encountered %d time warnings." % warnings)
    else:
        logNotification("Encountered zero time warnings.")


