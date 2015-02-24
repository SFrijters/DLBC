#!/usr/bin/env python

"""
Wrappers for the dub build process for DLBC.
"""

import os
import shutil
import subprocess

from logging import *
from path import *

dubCompilerChoices = [ "dmd", "gdc", "ldc2" ]
dubBuildChoices = [ "release", "cov", "unittest-cov", "profile" ]
dubBuildBuildAll = [ "release", "cov", "unittest-cov" ]
dlbcConfigurations = [ "d1q3", "d1q5", "d2q9", "d3q19" ]

def dubBuild(compiler, build, configuration, force, dlbcRoot):
    """ Build a DLBC executable for a particular compiler/build/configuration, if needed. """
    import tester.logging
    logNotification("Preparing executable '%s' ..." % constructExeTargetName(configuration, build, compiler))
    exePath = constructExeTargetPath(configuration, build, compiler, dlbcRoot)
    if ( not force ):
        if ( os.path.isfile(exePath) ):
            logInformation("  Found executable '%s'." % exePath )
            return

    logInformation("  Building executable '%s' ..." % exePath)
    command = ["dub", "build", "--compiler", compiler, "-b", build, "-c", configuration, "--force"]
    if ( tester.logging.verbosityLevel < 6 ):
        command.append("--vquiet")
    logDebug("  Executing '" + " ".join(command) + "'.")
    p = subprocess.Popen(command, cwd=dlbcRoot)
    p.communicate()
    if ( p.returncode != 0 ):
        logFatal("Dub build command returned %d." % p.returncode, p.returncode)
    shutil.move(os.path.join(dlbcRoot, "dlbc-" + configuration), exePath)
    return exePath

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
            logInformation("  Took %f seconds." % (time.time() - t0))
            n += 1

