#!/usr/bin/env python

"""
Helper script to execute the various elements of DLBC runnable test suite.
"""

import glob, fnmatch, os, shutil, subprocess, sys

from tester.build import *
from tester.coverage import *
from tester.describe import *
from tester.latex import *
from tester.logging import *
from tester.plot import *
from tester.parsejson import *
from tester.run import *
    
def processTest(testRoot, filename, options, n, i):
    """ Do everything required for a single test. """

    nerr = 0
    fn = os.path.join(testRoot, filename)
    jsonData = open(fn)
    try:
        data = json.load(jsonData)
    except ValueError:
        logFatal("JSON file %s seems to be broken. Please notify the test designer." % fn, -1)

    if ( options.only_tag ):
        tags = getTags(data, fn)
        if ( not options.only_tag in tags ):
            logDebug("Test %s does not have the required tag, skipping ..." % getName(data, fn))
            return nerr

    if ( options.describe ):
        describeTest(data, fn, n, i)
        return nerr

    describeTest(data, fn, n, i, True)

    if ( options.plot_reference ):
        plotTest(testRoot, getPlot(data, fn), True)
        return nerr

    cleanTest(testRoot, getClean(data, fn))
    if ( options.clean ):
        return nerr

    dubBuild(options.dub_compiler, options.dub_build, getConfiguration(data, fn), options.dub_force, options.dlbc_root)

    # Need to symlink so the .d source files are in the same relative paths as from the DLBC root dir
    if ( options.coverage ):
        if ( not os.path.isdir(os.path.join(testRoot, "src"))):
            os.symlink(os.path.join(options.dlbc_root, "src"), os.path.join(testRoot, "src"))

    # Run the tests
    nerr += runTest(options, testRoot, getConfiguration(data, fn), getInputFile(data, fn), getNP(data, fn), getParameters(data, fn), getCompare(data, fn), getPlot(data, fn))

    if ( options.coverage ):
        covpath = constructCoveragePath(options.dlbc_root)
        mergeCovLsts(options, testRoot, covpath)
        # Clean up the symlink
        os.remove(os.path.join(testRoot, "src"))
    jsonData.close()
    return nerr

def main():
    # Argument parser
    try:
        import argparse
    except ImportError:
        print( "\nImportError while loading argparse.")
        exit(-1)

    parser = argparse.ArgumentParser(description="Helper script to execute the DLBC runnable test suite")
    parser.add_argument("-v", choices=verbosityChoices, default="Information", help="verbosity level of this script [%s]" % ", ".join(verbosityChoices), metavar="")
    parser.add_argument("--build-all", action="store_true", help="only build all configurations and build types for the current compiler")
    parser.add_argument("--clean", action="store_true", help="only clean tests")
    parser.add_argument("--compare-lax", action="store_true", help="allow even the dmd compiler to use the accuracy parameter for comparison tests")
    parser.add_argument("--compare-strict", action="store_true", help="do not allow non-dmd compilers to use the accuracy parameter for comparison tests")
    parser.add_argument("--coverage", action="store_true", help="generate merged coverage information for unittests and runnable tests")
    parser.add_argument("--coverage-unittest", action="store_true", help="generate merged coverage information for unittests")
    parser.add_argument("--describe", action="store_true", help="only show test descriptions")
    parser.add_argument("--dlbc-root", default="../..", help="relative path to DLBC root", metavar="")
    parser.add_argument("--dlbc-verbosity", choices=verbosityChoices, default="Fatal", help="verbosity level to be passed to DLBC [%s]" % ", ".join(verbosityChoices), metavar="")
    parser.add_argument("--dub-build", choices=dubBuildChoices, default="release", help="build type to be passed to dub [%s]" % ", ".join(dubBuildChoices), metavar="" )
    parser.add_argument("--dub-compiler", choices=dubCompilerChoices, default="dmd", help="compiler to be passed to dub [%s]" % ", ".join(dubCompilerChoices), metavar="")
    parser.add_argument("--dub-force", action="store_true", help="force dub build")
    parser.add_argument("--latex", action="store_true", help="only write LaTeX output to stdout")
    parser.add_argument("--log-prefix", action="store_true", help="prefix log messages with the log level")
    parser.add_argument("--log-time", action="store_true", help="prefix log messages with the time")
    parser.add_argument("--only-below", default=".", help="only execute tests below this path", metavar="")
    parser.add_argument("--only-first", action="store_true", help="only the first combination of parameters whenever a parameter matrix is defined")
    parser.add_argument("--only-tag", help="only consider tests which have this tag", metavar="")
    parser.add_argument("--plot", action="store_true", help="plot results of the tests")
    parser.add_argument("--plot-reference", action="store_true", help="only plot the reference data of the tests")
    parser.add_argument("--timers", action="store_true", help="run with all compilers and write timer information")

    options = parser.parse_args()

    options.dlbc_root = os.path.normpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), options.dlbc_root))

    # Set global verbosity level
    import tester.logging
    tester.logging.verbosityLevel = getVerbosityLevel(options.v)
    tester.logging.logPrefix = options.log_prefix
    tester.logging.logTime = options.log_time

    if ( options.build_all ):
        buildAll(options)
        return

    if ( options.describe ):
        tester.logging.verbosityLevel = 5

    searchRoot = os.path.join(os.path.dirname(os.path.realpath(__file__)), options.only_below)

    if ( options.latex ):
        generateLaTeX(searchRoot)
        return

    if ( options.clean ):
        # Clean coverage files here, tests will be cleaned later
        cleanCoverage(options)

    if ( options.coverage or options.coverage_unittest ):
        if ( options.dub_compiler != "dmd" ):
            logNotification("Coverage information is generated only by dmd, skipping unittest coverage...")
            return
        options.dub_build = "unittest-cov"
        cleanCoverage(options)
        runUnittests(options)
        if ( not options.coverage ):
            return
        options.dub_build = "cov"

    # Populate list of matching json files.
    matches = []
    for testRoot, dirnames, filenames in os.walk(searchRoot):
        for filename in fnmatch.filter(filenames, '*.json'):
            matches.append([testRoot, filename])

    nerr = 0
    for i, m in enumerate(sorted(matches)):
        if ( options.timers ):
            for compiler in dubCompilerChoices:
                options.dub_compiler = compiler
                nerr += processTest(m[0], m[1], options, len(matches), i)
        else:
            nerr += processTest(m[0], m[1], options, len(matches), i)

    if ( options.describe ):
        return

    # Final report
    logNotification("\n" + "="*80)
    if ( nerr > 0 ):
        if ( nerr == 1 ):
            logFatal("Encountered %d error." % nerr, -1)
        else:
            logFatal("Encountered %d errors." % nerr, -1)
    logNotification("Encountered zero errors.")

if __name__ == '__main__':
    main()

