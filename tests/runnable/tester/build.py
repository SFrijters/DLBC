#!/usr/bin/env python

"""
Wrappers for the dub build process for DLBC.
"""

import os
import shutil
import subprocess

from logging import *
from path import *

dlbcConfigurations = [ "d1q3", "d1q5", "d2q9", "d3q19" ]
dubBuildChoices = ["release", "test"]
dubCompilerChoices = ["dmd", "gdc", "ldc2"]

def dubBuild(compiler, build, configuration, force, dlbcRoot):
    """ Build a DLBC executable for a particular compiler/build/configuration, if needed. """
    logNotification("Preparing executable '%s' ..." % constructExeTargetName(configuration, build, compiler))
    exePath = constructExeTargetPath(configuration, build, compiler, dlbcRoot)
    if ( not force ):
        if ( os.path.isfile(exePath) ):
            logInformation("  Found executable '%s'." % exePath )
            return
 
    logInformation("  Building executable '%s' ..." % exePath)
    command = ["dub", "build", "--compiler", compiler, "-b", build, "-c", configuration, "--force"]
    if ( verbosity >= 5 ):
        logDebug("  Executing '" + " ".join(command) + "'.")
        p = subprocess.Popen(command, cwd=dlbcRoot)
    else:
        devnull = open('/dev/null', 'w')
        logDebug("  Executing '" + " ".join(command) + "'.")
        p = subprocess.Popen(command, cwd=dlbcRoot, stdout=devnull)
    p.communicate()
    if ( p.returncode != 0 ):
        logFatal("Dub build command returned %d." % p.returncode, p.returncode)
    shutil.move(os.path.join(dlbcRoot, "dlbc-" + configuration), exePath)

