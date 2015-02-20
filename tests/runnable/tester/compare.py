#!/usr/bin/env python

"""
Compare test results to its reference data.
"""

from logging import *
from parsejson import *

import glob
import os
import subprocess

def compareTest(compare, testRoot):
    """ Run all necessary comparisons for a single subtest. """
    logNotification("Comparing test result to reference data ...")
    nerr = 0
    for c in compare["comparison"]:
        if ( c["type"] == "h5diff" ):
            for d in compare["data"]:
                # Here we replace the %data% token for each item in the data array
                g1 = glob.glob(os.path.join(testRoot, "output", c["files"].replace("%data%", d)))[0]
                g2 = glob.glob(os.path.join(testRoot, "reference-data", c["files"].replace("%data%", d)))[0]
                command = ["h5diff", g1, g2, "/OutArray"]
                logDebug("  Executing '" + " ".join(command) + "'.")
                p = subprocess.Popen(command)
                p.communicate()
                if ( p.returncode != 0 ):
                    nerr += logError("h5diff returned %d." % p.returncode)
        else:
            logFatal("Unknown comparison type.")

    if ( len(getCompareShell(compare)) > 0 ):
        logNotification("Running additional compare scripts ...")
    for s in getCompareShell(compare):
        command = [s]
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
