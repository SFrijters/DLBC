#!/usr/bin/env python

"""
Compare test results to its reference data.
"""

from logging import *
from parsejson import *

import glob
import os
import string
import subprocess

def compareTest(compare, testRoot, compiler, strict, lax):
    """ Run all necessary comparisons for a single subtest. """
    logNotification("Comparing test result to reference data ...")
    nerr = 0
    for c in compare["comparison"]:
        ctype = getCompareType(c)
        acc = getCompareAccuracy(c)
        if ( ctype == "h5diff" ):
            for d in compare["data"]:
                # Here we replace the %data% token for each item in the data array
                try:
                    search = os.path.join(testRoot, "output", c["files"].replace("%data%", d))
                    g1 = glob.glob(search)[0]
                except IndexError:
                    logFatal("Could not find any files matching '%s'." % search, -1)

                try:
                    search = os.path.join(testRoot, "reference-data", c["files"].replace("%data%", d))
                    g2 = glob.glob(search)[0]
                except IndexError:
                    logFatal("Could not find any files matching '%s'." % search, -1)

                command = [ "h5diff" ]
                if ( not strict and compiler != "dmd" and acc != "" ):
                    logDebug("  Applying non-strict accuracy cutoff '%s' ..." % acc )
                    command += [ "-d", acc ]
                if ( lax and compiler == "dmd" ):
                    logDebug("  Applying lax accuracy cutoff '%s' ..." % acc )
                    command += [ "-d", acc ]
                command += [ g1, g2, "/OutArray" ]
                logDebug("  Executing '" + " ".join(command) + "'.")
                p = subprocess.Popen(command)
                p.communicate()
                if ( p.returncode != 0 ):
                    nerr += logError("h5diff returned %d." % p.returncode)
        else:
            logFatal("Unknown comparison type '%s'." % ctype)

    shellscripts = getCompareShell(compare)
    if ( len(shellscripts) > 0 ):
        logNotification("Running additional compare scripts ...")
    for s in shellscripts:
        command = string.split(s, " ")
        logDebug("  Executing '" + " ".join(command) + "'.")
        p = subprocess.Popen(command, cwd=testRoot)
        p.communicate()
        if ( p.returncode == 1 ):
            logInformation("  Script '%s' returned %d - ignored." % ( s, p.returncode) )
        elif ( p.returncode != 0 ):
            nerr += logError("Script '%s' returned %d." % ( s, p.returncode) )
    if ( nerr == 0 ):
        logInformation("  No errors found.")
    return nerr

def replaceTokensInCompare(compare, parameters, np):
    """ Replace tokens in compare matrix, except %data%. """
    import copy
    compareNew = copy.deepcopy(compare)
    for c in compareNew["comparison"]:
        for p in parameters:
            c["files"] = c["files"].replace("%"+p[0]+"%", p[1])
        c["files"] = c["files"].replace("%np%", str(np))
    return compareNew

