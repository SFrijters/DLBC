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

    try:
        comparisons = compare["comparison"]
    except KeyError:
        logWarning("Parameter compare does not contain any comparisons.")
        comparisons = []

    for c in comparisons:
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
    import re
    compareNew = copy.deepcopy(compare)
    for c in compareNew["comparison"]:
        for p in parameters:
            if ( "[" in p[1] ):
                # Is array
                pstr = "(%" + p[0] + "((\[[0-9]+\])*)%)"
                pattern = re.compile(pstr)
                indices = pattern.search(c["files"])
                if ( indices ):
                    token = indices.groups()[0]
                    ind = indices.groups()[1]
                    values = ind.split("[")[1:]
                    values = [ int(v.replace("]", "")) for v in values ]
                    ev = eval(p[1])
                    if ( len(values) == 1 ):
                        repl = ev[values[0]]
                    elif ( len(values) == 2 ):
                        repl = ev[values[0]][values[1]]
                    c["files"] = c["files"].replace(token, str(repl))
                else:
                    c["files"] = c["files"].replace("%"+p[0]+"%", p[1])
            else:
                c["files"] = c["files"].replace("%"+p[0]+"%", p[1])
        # Replace %np%
        c["files"] = c["files"].replace("%np%", str(np))
    return compareNew

