#!/usr/bin/env python

"""
Helper script to execute the DLBC runnable test suite.
"""

import glob, fnmatch, json, os, shutil, subprocess, sys

# Logging helper functions

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

# JSON data getter functions
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

def getParameters(data, fn):
    try:
        return data["parameters"]
    except KeyError:
        logDebug("JSON file %s lacks a 'parameters' parameter. Assuming no parameters need to be passed to DLBC." % fn)
        return []

def getCompare(data, fn):
    try:
        return data["compare"]
    except KeyError:
        logFatal("JSON file %s lacks a 'compare' parameter. Please notify the test designer." % fn, -1)

def getCompareShell(data):
    try:
        return data["compare"]["shell"]
    except KeyError:
        logDebug("JSON file lacks a 'compare:shell' parameter. Assuming no additional shell commands need to be run.")
        return []

# Construct paths
def constructTargetPath(options, configuration):
    return os.path.abspath(os.path.join(os.path.dirname(os.path.realpath(__file__)), options.dlbc_root, "dlbc-" + configuration + "-" + options.dub_build + "-" + options.dub_compiler))

def constructDlbcRoot(options):
    return os.path.join(os.path.dirname(os.path.realpath(__file__)), options.dlbc_root)

# Build an executable, if needed
def dubBuild(options, configuration):
    logNotification("Creating executable...")
    targetPath = constructTargetPath(options, configuration )
    if ( not options.dub_force ):
        if ( os.path.isfile(targetPath) ):
            logInformation("Found executable '%s', use --dub-force to force a new build." % targetPath )
            return
 
    logInformation("Building executable...")
    command = ["dub", "build", "--compiler", options.dub_compiler, "-b", options.dub_build, "-c", configuration, "--force"]
    dlbcRoot = constructDlbcRoot(options)
    if ( verbosity >= 5 ):
        logDebug("Executing '" + " ".join(command) + "'")
        p = subprocess.Popen(command, cwd=dlbcRoot)
    else:
        devnull = open('/dev/null', 'w')
        logDebug("Executing '" + " ".join(command) + "'")
        p = subprocess.Popen(command, cwd=dlbcRoot, stdout=devnull)
    p.communicate()
    if ( p.returncode != 0 ):
        logFatal("Dub build command returned %d" % p.returncode, p.returncode)
    shutil.move(os.path.join(dlbcRoot, "dlbc-" + configuration), targetPath)

# Construct the cartesian product of all parameter values
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

# Make a proper command line option for a parameter
def constructParameterCommand(tuple):
    command = []
    for p in tuple:
        command.append("--parameter")
        command.append(p[0] + "=" + p[1])
    return command

# Replace tokens in compare matrix, except %data%
def replaceTokensInCompare(compare, parameters, np):
    for c in compare["comparison"]:
        for p in parameters:
            c["files"] = c["files"].replace("%"+p[0]+"%", p[1])
        c["files"] = c["files"].replace("%np%", str(np))
    return compare

# Run all necessary comparisons for a test
def compareTest(compare, testRoot):
    logNotification("Comparing test result to reference data")
    for c in compare["comparison"]:
        if ( c["type"] == "h5diff" ):
            for d in compare["data"]:
                # Here we replace the %data% token for each item in the data array
                g1 = glob.glob(os.path.join(testRoot, "output", c["files"].replace("%data%", d)))[0]
                g2 = glob.glob(os.path.join(testRoot, "reference-data", c["files"].replace("%data%", d)))[0]
                command = ["h5diff", g1, g2, "/OutArray"]
                logDebug("Executing '" + " ".join(command) + "'")
                p = subprocess.Popen(command)
                p.communicate()
                if ( p.returncode != 0 ):
                    logFatal("h5diff returned %d" % p.returncode, p.returncode)
        else:
            logFatal("Unknown comparison type")
    for s in getCompareShell(compare):
        command = [s]
        logDebug("Executing '" + " ".join(command) + "'")
        p = subprocess.Popen(command, cwd=testRoot)
        p.communicate()
        if ( p.returncode != 0 ):
            logFatal("h5diff returned %d" % p.returncode, p.returncode)

# Run a single parameter set for a single test
def runTest(command, testRoot):
    import time
    logDebug("Executing '" + " ".join(command) + "'")
    t0 = time.time()
    p = subprocess.Popen(command, cwd=testRoot)
    p.communicate()
    if ( p.returncode != 0 ):
        logFatal("DLBC returned %d" % p.returncode, p.returncode)
    logNotification("  Took %f seconds" % (time.time() - t0))

# Get nc from parallel.nc if available
def getNC(map):
    for p in map:
        if ( p[0] == "parallel.nc" ):
            return p[1]
    return "[0,0]"

# Run all parameter sets for a single test
def runTests(options, testRoot, configuration, inputFile, np, parameters, compare):
    logNotification("Running tests...")
    exePath = constructTargetPath(options, configuration )
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
            command = command + constructParameterCommand(m)
            runTest(command, testRoot)
            compare = replaceTokensInCompare(compare, m, np)
            compareTest(compare, testRoot)
            if ( options.only_first ): return
    else:
        logNotification("  Running parameter set 1 of 1")
        command = [ "mpirun", "-np", str(np), exePath, "-p", inputFile, "-v", options.dlbc_verbosity ]
        runTest(command, testRoot)
        compareTest(compare, testRoot)

# Clean a single test
def cleanTest(testRoot, clean):
    logNotification("Cleaning test...")
    for c in clean:
        f = os.path.join(testRoot, c)
        if ( os.path.exists(f) ):
            logDebug("  Removing '%s'" % f )
            shutil.rmtree(f)

# Print pretty description for single test
def describeTest(data, fn, n, i, withLines=False):
    import textwrap
    istr = "%02d/%02d " % ((i+1),n)
    if ( withLines ):
        logNotification("\n" + "="*80)
    logNotification(istr + getName(data, fn) + " (" + os.path.relpath(fn) + "):" )
    logNotification(textwrap.fill(getDescription(data, fn),initial_indent=" "*6,subsequent_indent=" "*6, width=80))
    logNotification("")

# Do everything required for a single test
def processTest(testRoot, filename, options, n, i):
    fn = os.path.join(testRoot, filename)
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
    cleanTest(testRoot, getClean(data, fn))
    if ( options.clean ):
        return
    dubBuild(options, getConfiguration(data, fn))
    runTests(options, testRoot, getConfiguration(data, fn), getInputFile(data, fn), getNP(data, fn), getParameters(data, fn), getCompare(data, fn))
    jsonData.close()

# Generate LaTeX code for a single test
def generateLaTeXforTest(testRoot, filename):
    fn = os.path.join(testRoot, filename)
    jsonData = open(fn)
    try:
        data = json.load(jsonData)
    except ValueError:
        logFatal("JSON file %s seems to be broken. Please notify the test designer." % fn, -1)

    name = getName(data, fn)
    description = getDescription(data, fn)
    tags = getTags(data, fn)
    latex = getLatex(data, fn)

    print("\\subsubsection{%s}\n" % name)
    print("\\textbf{Description:} %s\\\\" % description)
    print("\\textbf{Location:} \\textsc{%s}\\\\" % fn)
    print("\\textbf{Tags:} %s\\\\" % ", ".join(sorted(tags)))
    if ( latex ):
        print(latex)
        print("")
    jsonData.close()

# Generate LaTeX for all tests (subject to filters)
def generateLaTeX():
    matches = []
    for testRoot, dirnames, filenames in os.walk(os.path.dirname(os.path.realpath(__file__))):
        for filename in fnmatch.filter(filenames, '*.json'):
            matches.append([testRoot, filename])

    for m in matches:
        generateLaTeXforTest(m[0], m[1])

def main():
    # Parser
    try:
        import argparse
    except ImportError:
        print( "\nImportError while loading argparse.")
        exit(-1)

    verbosityChoices = ["Debug", "Information", "Notification", "Warning", "Error", "Fatal", "Off"]
    dubBuildChoices = ["release", "test"]
    dubCompilerChoices = ["dmd", "gdc", "ldc2"]

    parser = argparse.ArgumentParser(description="Helper script to execute the DLBC runnable test suite")
    parser.add_argument("-v", choices=verbosityChoices, default="Notification", help="verbosity level of this script [%s]" % ", ".join(verbosityChoices), metavar="")
    parser.add_argument("--clean", action="store_true", help="only clean tests" )
    parser.add_argument("--describe", action="store_true", help="only show test descriptions")
    parser.add_argument("--dlbc-root", default="../..", help="relative path to DLBC root", metavar="")
    parser.add_argument("--dlbc-verbosity", choices=verbosityChoices, default="Fatal", help="verbosity level to be passed to DLBC [%s]" % ", ".join(verbosityChoices), metavar="")
    parser.add_argument("--dub-build", choices=["release", "test"], default="release", help="build type to be passed to Dub [%s]" % ", ".join(dubBuildChoices), metavar="" )
    parser.add_argument("--dub-compiler", choices=dubCompilerChoices, default="dmd", help="compiler to be passed to Dub [%s]" % ", ".join(dubCompilerChoices), metavar="")
    parser.add_argument("--dub-force", action="store_true", help="force dub build")
    parser.add_argument("--latex", action="store_true", help="only write LaTeX output to stdout")
    parser.add_argument("--only-below", default=".", help="only execute tests below this path", metavar="")
    parser.add_argument("--only-first", action="store_true", help="only the first combination of parameters whenever a parameter matrix is defined")
    parser.add_argument("--only-tag", help="only consider tests which have this tag", metavar="")

    options = parser.parse_args()

    global verbosity
    verbosity = getVerbosityLevel(options.v)
    if ( options.describe ):
        verbosity = 5

    if ( options.latex ):
        generateLaTeX()
        return

    matches = []
    for testRoot, dirnames, filenames in os.walk(os.path.join(os.path.dirname(os.path.realpath(__file__)), options.only_below)):
        for filename in fnmatch.filter(filenames, '*.json'):
            matches.append([testRoot, filename])

    for i, m in enumerate(matches):
        processTest(m[0], m[1], options, len(matches), i)

if __name__ == '__main__':
    main()

