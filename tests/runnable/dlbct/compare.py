#!/usr/bin/env python

"""
Compare test results to its reference data.
"""

from logging import *

import glob
import os
import string
import subprocess

def compareSingleTest(options, thisTest):
    compareTest(options, thisTest, 0, None, None)

def compareTest(options, thisTest, i, m, np):
    """ Run all necessary comparisons for a single subtest. """

    logNotification("Comparing test result to reference data ...")

    if ( options.fast and thisTest.fast ):
        compare = thisTest.fast["compare"]
    else:
        compare = thisTest.compare

    if ( m ):
        compare = replaceTokensInCompare(compare, m, np)

    try:
        comparisons = compare["comparison"]
    except KeyError:
        logWarning("Parameter compare does not contain any comparisons.")
        comparisons = []

    try:
        data = compare["data"]
    except KeyError:
        logWarning("Parameter compare does not contain any data.")
        data = []

    for c in comparisons:
        try:
            ctype = c["type"]
        except KeyError:
            logFatal("Comparison requires a 'type' parameter. Please notify the test designer.", -1)

        try:
            cfiles = c["files"]
        except KeyError:
            logFatal("Comparison requires a 'files' parameter. Please notify the test designer.", -1)

        try:
            cacc = c["accuracy"]
        except KeyError:
            logDebug("Comparison lacks an 'accuracy' parameter. Assuming no laxness.")
            cacc = None

        if ( ctype == "h5diff" ):
            for d in data:
                # Here we replace the %data% token for each item in the data array
                try:
                    search = os.path.join(thisTest.testRoot, "output", cfiles.replace("%data%", d))
                    g1 = glob.glob(search)[0]
                except IndexError:
                    logFatal("Could not find any files matching '%s'." % search, -1)

                try:
                    search = os.path.join(thisTest.testRoot, "reference-data", cfiles.replace("%data%", d))
                    g2 = glob.glob(search)[0]
                except IndexError:
                    logFatal("Could not find any files matching '%s'." % search, -1)

                command = [ "h5diff" ]
                if ( not options.compare_strict and options.dub_compiler != "dmd" and cacc ):
                    logDebug("  Applying non-strict accuracy cutoff '%s' ..." % cacc )
                    command += [ "-d", cacc ]
                if ( options.compare_lax and options.dub_compiler == "dmd" and cacc ):
                    logDebug("  Applying lax accuracy cutoff '%s' ..." % cacc )
                    command += [ "-d", cacc ]
                command += [ g1, g2, "/OutArray" ]

                logDebug("  Executing '" + " ".join(command) + "'.")
                p = subprocess.Popen(command)
                p.communicate()
                if ( p.returncode != 0 ):
                    thisTest.errors[i] += 1
                    logError("h5diff returned %d." % p.returncode)
        else:
            logFatal("Unknown comparison type '%s'." % ctype)

    try:
        cshellscripts = compare["shell"]
    except KeyError:
        logDebug("JSON file lacks a 'compare:shell' parameter. Assuming no additional shell commands need to be run.")
        cshellscripts = []

    if ( len(cshellscripts) > 0 ):
        logNotification("Running additional compare scripts ...")
    for s in cshellscripts:
        command = string.split(s, " ")
        logDebug("  Executing '" + " ".join(command) + "'.")
        p = subprocess.Popen(command, cwd=thisTest.testRoot)
        p.communicate()
        if ( p.returncode != 0 ):
            thisTest.errors[i] += 1           
            logError("Script '%s' returned %d." % ( s, p.returncode) )

    if ( thisTest.errors[i] == 0 ):
        logInformation("  No errors found.")

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

