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
    return os.path.abspath(os.path.join(options.dlbc_root, "dlbc-" + configuration + "-" + options.build + "-" + options.compiler))

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
        logDebug("Executing '" + " ".join(command) + "'")
        p = subprocess.Popen(command, cwd=options.dlbc_root)
    else:
        devnull = open('/dev/null', 'w')
        logDebug("Executing '" + " ".join(command) + "'")
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

def getClean(data, fn):
    try:
        return data["clean"]
    except KeyError:
        logFatal("JSON file %s lacks a 'clean' parameter. Please notify the test designer." % fn, -1)

def getNC(map):
    for p in map:
        if ( p[0] == "parallel.nc" ):
            return p[1]
    return "[0,0]"

def getParameters(data, fn):
    try:
        return data["parameters"]
    except KeyError:
        logDebug("JSON file %s lacks a 'parameters' parameter. Assuming no parameters need to be passed to DLBC." % fn)
        return []

def getTags(data, fn):
    try:
        return data["tags"]
    except KeyError:
        logDebug("JSON file %s lacks a 'tags' parameter. Assuming no tags." % fn)
        return []

def getLatex(data, fn):
    try:
        return data["latex"]
    except KeyError:
        logDebug("JSON file %s lacks a 'latex' parameter. Assuming no additional LaTeX." % fn)
        return ""

def mapParameterMatrix(parameters):
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

def makeParameterCommand(tuple):
    command = []
    for p in tuple:
        command.append("--parameter")
        command.append(p[0] + "=" + p[1])
    return command

def getCompare(data, fn):
    try:
        return data["compare"]
    except KeyError:
        logFatal("JSON file %s lacks a 'compare' parameter. Please notify the test designer." % fn, -1)

def makeCompareMatrix(compare, parameters, np):
    for c in compare["comparison"]:
        for p in parameters:
            c["files"] = c["files"].replace("%"+p[0]+"%", p[1])
        c["files"] = c["files"].replace("%np%", str(np))
    return compare

def compareTest(compare, root):
    import glob
    logNotification("Comparing test result to reference data")
    for c in compare["comparison"]:
        if ( c["type"] == "h5diff" ):
            for d in compare["data"]:
                g1 = glob.glob(os.path.join(root, "output", c["files"].replace("%data%", d)))[0]
                g2 = glob.glob(os.path.join(root, "reference-data", c["files"].replace("%data%", d)))[0]
                command = ["h5diff", g1, g2, "/OutArray"]
                logDebug("Executing '" + " ".join(command) + "'")
                p = subprocess.Popen(command)
                p.communicate()
                if ( p.returncode != 0 ):
                    logFatal("h5diff returned %d" % p.returncode, p.returncode)
        else:
            logFatal("Unknown comparison type")
    try:
        for s in compare["shell"]:
            command = [s]
            logDebug("Executing '" + " ".join(command) + "'")
            p = subprocess.Popen(command, cwd=root)
            p.communicate()
            if ( p.returncode != 0 ):
                logFatal("h5diff returned %d" % p.returncode, p.returncode)
    except KeyError:
        logDebug("No additional shell commands specified for testing")
        
def runTest(command, root):
    logDebug("Executing '" + " ".join(command) + "'")
    p = subprocess.Popen(command, cwd=root)
    p.communicate()
    if ( p.returncode != 0 ):
        logFatal("DLBC returned %d" % p.returncode, p.returncode)

def runTests(options, root, configuration, inputFile, np, parameters, compare):
    logNotification("Running tests...")
    exePath = getTargetPath(options, configuration )
    if ( parameters ):
        map, n = mapParameterMatrix(parameters)
        for i, m in enumerate(map):
            # Get the parallel.nc parameter from the parameter set, if it's included
            nc = getNC(m)
            # If it is, set np to the product of its values
            if ( nc != "[0,0]" ):
                np = reduce(lambda x, y: int(x) * int(y), nc[1:-1].split(","), 1)

            if ( options.only_first ):
                logNotification("  Running parameter set %d of %d (only this one will be executed)" % (i+1, n))
            else:
                logNotification("  Running parameter set %d of %d" % (i+1, n))
            command = [ "mpirun", "-np", str(np), exePath, "-p", inputFile, "-v", options.dlbc_verbosity ]
            command = command + makeParameterCommand(m)
            makeCompareMatrix(compare, m, np)
            runTest(command, root)
            compareTest(compare, root)
            if ( options.only_first ): return
    else:
        logNotification("  Running parameter set 1 of 1")
        command = [ "mpirun", "-np", "1", exePath, "-p", inputFile, "-v", options.dlbc_verbosity ]
        runTest(command, root)
        compareTest(compare, root)

def cleanTest(root, clean):
    logNotification("Cleaning test...")
    import shutil
    for c in clean:
        f = os.path.join(root, c)
        if ( os.path.exists(f) ):
            logDebug("  Removing '%s'" % f )
            shutil.rmtree(f)
        
def describeTest(data, fn, n, i, withLines=False):
    import textwrap
    istr = "%02d/%02d " % ((i+1),n)
    if ( withLines ):
        logNotification("\n" + "="*80)
    logNotification(istr + getName(data, fn) + " (" + fn + "):" )
    logNotification(textwrap.fill(getDescription(data, fn),initial_indent=" "*6,subsequent_indent=" "*6, width=80))
    logNotification("")

def processTest(root, filename, options, n, i):
    fn = os.path.join(root, filename)
    jsonData = open(fn)
    try:
        data = json.load(jsonData)
    except ValueError:
        logFatal("JSON file %s seems to be broken. Please notify the test designer." % fn, -1)

    if ( options.only_tag ):
        tags = getTags(data, fn)
        if ( not options.only_tag in tags ):
            logDebug("Test %s does not have the required tag, skipping..." % getName(data, fn))
            return
            
    if ( options.describe ):
        describeTest(data, fn, n, i)
        return

    describeTest(data, fn, n, i, True)
    cleanTest(root, getClean(data, fn))
    if ( options.clean ):
        return
    dubBuild(options, getConfiguration(data, fn))
    runTests(options, root, getConfiguration(data, fn), getInputFile(data, fn), getNP(data, fn), getParameters(data, fn), getCompare(data, fn))
    jsonData.close()

def escapeLaTeX(str):
    str = str.replace("-", "\-")
    return str

def generateLaTeXforTest(root, filename):
    fn = os.path.join(root, filename)
    jsonData = open(fn)
    try:
        data = json.load(jsonData)
    except ValueError:
        logFatal("JSON file %s seems to be broken. Please notify the test designer." % fn, -1)

    name = getName(data, fn)
    description = getDescription(data, fn)
    tags = getTags(data, fn)
    latex = getLatex(data, fn)
    
    print("\\section{%s}\n" % name)
    print("\\textbf{Description:} %s\\\\" % description)
    print("\\textbf{Location:} \\textsc{%s}\\\\" % fn)
    print("\\textbf{Tags:} %s\\\\" % ", ".join(sorted(tags)))
    if ( latex ):
        print(latex)
        print("")
    jsonData.close()

def generateLaTeX():
    matches = []
    for root, dirnames, filenames in os.walk("."):
        for filename in fnmatch.filter(filenames, '*.json'):
            matches.append([root, filename])

    for m in matches:
        generateLaTeXforTest(m[0], m[1])

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
    parser.add_argument("--clean", action="store_true", help="Only clean tests" )
    parser.add_argument("--compiler", default="dmd")
    parser.add_argument("--describe", action="store_true", help="Show test names only")
    parser.add_argument("--dlbc-root", default="../..", help="Relative path to DLBC root")
    parser.add_argument("--dlbc-verbosity", choices=["Debug", "Information", "Notification", "Warning", "Error", "Fatal", "Off"], default="Fatal", help="Verbosity level to be passed to DLBC")
    parser.add_argument("--force", action="store_true", help="Force dub build")
    parser.add_argument("--latex", action="store_true", help="Only write LaTeX output to stdout.")
    parser.add_argument("--only-below", default=".", help="Execute only tests below this path")
    parser.add_argument("--only-first", action="store_true", help="When a parameter matrix is defined, test only the first combination")
    parser.add_argument("--only-tag", help="Only consider tests which have this tag")

    options = parser.parse_args()

    global verbosity
    verbosity = getVerbosityLevel(options.v)
    if ( options.describe ):
        verbosity = 5

    if ( options.latex ):
        generateLaTeX()
        return

    matches = []
    for root, dirnames, filenames in os.walk(options.only_below):
        for filename in fnmatch.filter(filenames, '*.json'):
            matches.append([root, filename])

    for i, m in enumerate(matches):
        processTest(m[0], m[1], options, len(matches), i)

if __name__ == '__main__':
    main()

