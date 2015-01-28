#!/usr/bin/env python

"""
Helper script to execute the DLBC runnable test suite.
"""

import glob
import sys
import fnmatch
import os
import json
import subprocess

def getVerbosityLevel(str):
    if ( str == "Debug" ):
        return 6
    if ( str == "Information" ):
        return 5
    if ( str == "Notification" ):
        return 4
    if ( str == "Warning"):
        return 3
    if ( str == "Error"):
        return 2
    if ( str == "Fatal"):
        return 1
    return 0 # Off

verbosity = getVerbosityLevel("Fatal")

def logDebug(str):
    if ( verbosity >= 6 ):
        print(str)
        # print("[D] " + str)

def logInformation(str):
    if ( verbosity >= 5 ):
        print(str)
        # print("[I] " + str)

def logNotification(str):
    if ( verbosity >= 4 ):
        print(str)
        # print("[N] " + str)

def logWarning(str):
    if ( verbosity >= 3 ):
        print(str)
        # print("[W] " + str)

def logError(str):
    if ( verbosity >= 2 ):
        print(str)
        # print("[E] " + str)

def logFatal(str, returncode):
    if ( verbosity >= 1 ):
        print("FATAL ERROR: " + str)
        # print("[F] " + str)
    exit(returncode)

def getTargetPath(options, configuration):
    return os.path.abspath(os.path.join(options.dlbc_root, "dlbc-" + configuration + "-" + options.build))

def dubBuild(options, configuration):
    logNotification("Creating executable...")
    targetPath = getTargetPath(options, configuration )
    if ( not options.force ):
        if ( os.path.isfile(targetPath) ):
            logInformation("Found executable '%s', use --force to force a new build." % targetPath )
            return
                             
    logInformation("Building executable")
    command = ["dub", "build", "--compiler", options.compiler, "-b", options.build, "-c", configuration]
    command.append("--force")
    if ( verbosity >= 5 ):
        p = subprocess.Popen(command, cwd=options.dlbc_root)
    else:
        devnull = open('/dev/null', 'w')
        p = subprocess.Popen(command, cwd=options.dlbc_root, stdout=devnull)
    p.communicate()
    if ( p.returncode != 0 ):
        logFatal("Dub build command returned %d" % p.returncode, p.returncode)
    p = subprocess.call(["mv", os.path.join(options.dlbc_root, "dlbc-" + configuration), targetPath ])

def getName(data, fn):
    try:
        return data["name"]
    except KeyError:
        logFatal("JSON file %s lacks a name. Please notify the test designer." % fn, -1)

def getDescription(data, fn):
    try:
        return data["description"]
    except KeyError:
        logFatal("JSON file %s lacks a description. Please notify the test designer." % fn, -1)

def getConfiguration(data, fn):
    try:
        return data["configuration"]
    except KeyError:
        logFatal("JSON file %s lacks a configuration. Please notify the test designer." % fn, -1)

def getInputFile(data, fn):
    try:
        return data["input-file"]
    except KeyError:
        logFatal("JSON file %s lacks a path to an input file. Please notify the test designer." % fn, -1)

def getNP(data, fn):
    try:
        return data["np"]
    except KeyError:
        logDebug("JSON file %s lacks an 'np' parameter. Set to 1 by default." % fn)
        return 1

def getParameters(data, fn):
    try:
        return data["parameters"]
    except KeyError:
        logDebug("JSON file %s lacks a 'parameters' parameter. Assuming no parameters need to be passed to DLBC." % fn)
        return []

def mapParameterMatrix(parameters):
    tuples = []
    for p in parameters:
        values = []
        for v in p["values"]:
            values.append((p["parameter"],v))
        tuples.append(values)
    import itertools
    return itertools.product(*tuples)

def makeParameterCommand(tuple):
    command = []
    for p in tuple:
        command.append("--parameter")
        command.append(p[0] + "=" + p[1])
    return command

def runTest(command, root):
    p = subprocess.Popen(command, cwd=root)
    p.communicate()
    if ( p.returncode != 0 ):
        logFatal("DLBC returned %d" % p.returncode, p.returncode)


def runTests(options, root, configuration, inputFile, np, parameters):
    logNotification("Running tests...")
    exePath = getTargetPath(options, configuration )
    if ( parameters ):
        map = mapParameterMatrix(parameters)
        for m in map:
            command = [ "mpirun", "-np", str(np), exePath, "-p", inputFile, "-v", options.dlbc_verbosity ]
            command = command + makeParameterCommand(m)
            runTest(command, root)
    else:
        command = [ "mpirun", "-np", str(np), exePath, "-p", inputFile, "-v", options.dlbc_verbosity ]
        runTest(command, root)

def describeTest(data, fn, n, i):
    import textwrap
    istr = "%2d " % (i+1)
    logNotification(istr + getName(data, fn) + " (" + fn + "):" )
    logNotification(textwrap.fill(getDescription(data, fn),initial_indent="     ",subsequent_indent="     ", width=80))

def processTest(root, filename, options, n, i):
    fn = os.path.join(root, filename)
    jsonData = open(fn)
    try:
        data = json.load(jsonData)
    except ValueError:
        logFatal("JSON file %s seems to be broken. Please notify the test designer." % fn, -1)

    describeTest(data, fn, n, i)
    if ( options.describe ):
        return

    dubBuild(options, getConfiguration(data, fn))
    runTests(options, root, getConfiguration(data, fn), getInputFile(data, fn), getNP(data, fn), getParameters(data, fn))
    jsonData.close()

def main():
    # Parser
    try:
        import argparse
    except ImportError:
        print( "\nImportError while loading argparse.")
        exit(-1)

    parser = argparse.ArgumentParser(description="Helper script to execute the DLBC runnable test suite")
    parser.add_argument("-v", choices=["Debug", "Information", "Notification", "Warning", "Error", "Fatal", "Off"], default="Notification", help="Verbosity level of this script")
    parser.add_argument("--build", choices=["release", "test"], default="release", help="Dub build type" )
    parser.add_argument("--compiler", default="dmd")
    parser.add_argument("--describe", action="store_true", help="Show test names only")
    parser.add_argument("--dlbc-root", default="../..", help="Relative path to DLBC root")
    parser.add_argument("--dlbc-verbosity", choices=["Debug", "Information", "Notification", "Warning", "Error", "Fatal", "Off"], default="Fatal", help="Verbosity level to be passed to DLBC")
    parser.add_argument("--force", action="store_true", help="Force dub build")
    parser.add_argument("--test-single", nargs=1, help="Execute only the single specified test")
    parser.add_argument("positional", nargs="*")

    options = parser.parse_args()

    global verbosity
    verbosity = getVerbosityLevel(options.v)
    if ( options.describe ):
        verbosity = 5

    if ( options.test_single ):
        root = os.path.split(options.test_single[0])[0]
        filename = os.path.split(options.test_single[0])[1]
        processTest(root, filename, options, 1, 1)
    else:
        matches = []
        for root, dirnames, filenames in os.walk('.'):
            for filename in fnmatch.filter(filenames, '*.json'):
                matches.append([root, filename])

        logNotification("Found %d tests" % len(matches))
        for i, m in enumerate(matches):
            processTest(m[0], m[1], options, len(matches), i)

if __name__ == '__main__':
    main()

