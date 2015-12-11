#!/usr/bin/env python

"""
Helper script to execute the various elements of DLBC runnable test suite.
"""

import glob, fnmatch, os, shutil, subprocess, sys

from dlbct.build import *
from dlbct.coverage import cleanCoverage, runUnittests
from dlbct.latex import *
from dlbct.logging import *
from dlbct.plot import *
from dlbct.run import *
from dlbct.test import Test
    
def processTest(thisTest, options, n, i, singleTest):
    """ Do everything required for a single test. """

    # Always execute a test if a json file has been passed explicitly
    if ( singleTest ):
        thisTest.disabled = False

    # Skip the test if it does not have the required tag
    if ( options.only_tag and ( not options.only_tag in thisTest.tags ) ):
        thisTest.skipped = True
        logDebug("Test '%s' does not have the required tag '%s', skipping ..." % ( thisTest.name, options.only_tag ) )
        return

    # If --describe has been passed, only describe the tests
    if ( options.describe ):
        thisTest.describe(n, i)
        return

    thisTest.describe(n, i, True)

    # Do not do anything for disabled tests
    if ( thisTest.disabled ):
        logNotification("Test '%s' has been disabled, skipping ..." % thisTest.name )
        return

    if ( options.timers_clean ):
        cleanTimersData(thisTest)
        return

    if ( options.plot_reference ):
        plotTest(thisTest, True)
        return

    cleanTest(thisTest)
    if ( options.clean ):
        return

    nerr = 0

    dubBuild(options.dub_compiler, options.dub_build, thisTest.configuration, options.dub_force, options.dlbc_root)

    # Need to symlink so the .d source files are in the same relative paths as from the DLBC root dir
    if ( options.coverage ):
        if ( not os.path.isdir(os.path.join(thisTest.testRoot, "src"))):
            os.symlink(os.path.join(options.dlbc_root, "src"), os.path.join(thisTest.testRoot, "src"))

    # Run the tests
    runTest(options, thisTest)

    if ( options.coverage ):
        # Clean up the symlink
        os.remove(os.path.join(thisTest.testRoot, "src"))

    if ( options.plot ):
        plotTest(thisTest, False)

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
    parser.add_argument("--compare-none", action="store_true", help="do not run comparison tests")
    parser.add_argument("--compare-strict", action="store_true", help="do not allow non-dmd compilers to use the accuracy parameter for comparison tests")
    parser.add_argument("--coverage", action="store_true", help="generate merged coverage information for unittests and runnable tests")
    parser.add_argument("--coverage-unittest", action="store_true", help="generate merged coverage information for unittests")
    parser.add_argument("--describe", action="store_true", help="only show test descriptions")
    parser.add_argument("--dlbc-root", default="../..", help="relative path to DLBC root", metavar="")
    parser.add_argument("--dlbc-verbosity", choices=verbosityChoices, default="Fatal", help="verbosity level to be passed to DLBC [%s]" % ", ".join(verbosityChoices), metavar="")
    parser.add_argument("--dub-build", choices=dubBuildChoices, default="release", help="build type to be passed to dub [%s]" % ", ".join(dubBuildChoices), metavar="" )
    parser.add_argument("--dub-compiler", choices=dubCompilerChoices, default="dmd", help="compiler to be passed to dub [%s]" % ", ".join(dubCompilerChoices), metavar="")
    parser.add_argument("--dub-force", action="store_true", help="force dub build")
    parser.add_argument("--fast", action="store_true", help="run shorter versions of long tests")
    parser.add_argument("--latex", action="store_true", help="only write LaTeX output to stdout")
    parser.add_argument("--log-prefix", action="store_true", help="prefix log messages with the log level")
    parser.add_argument("--log-time", action="store_true", help="prefix log messages with the time")
    parser.add_argument("--only-below", default=".", help="only execute tests below this path", metavar="")
    parser.add_argument("--only-doc", action="store_true", help="only build the documentation")
    parser.add_argument("--only-dmd", default=".", help="only continue when using the dmd compiler of the requested version", metavar="")
    parser.add_argument("--only-first", action="store_true", help="only the first combination of parameters whenever a parameter matrix is defined")
    parser.add_argument("--only-serial", action="store_true", help="only run tests which use one rank")
    parser.add_argument("--only-tag", help="only consider tests which have this tag", metavar="")
    parser.add_argument("--plot", action="store_true", help="plot results of the tests")
    parser.add_argument("--plot-reference", action="store_true", help="only plot the reference data of the tests")
    parser.add_argument("--timers", action="store_true", help="run tests and write timer information and plot")
    parser.add_argument("--timers-all", action="store_true", help="run with all compilers and write timer information and plot")
    parser.add_argument("--timers-clean", action="store_true", help="clean timer data")

    options = parser.parse_args()

    options.dlbc_root = os.path.normpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), options.dlbc_root))

    # Set global verbosity level
    import dlbct.logging
    dlbct.logging.verbosityLevel = getVerbosityLevel(options.v)
    dlbct.logging.logPrefix = options.log_prefix
    dlbct.logging.logTime = options.log_time

    if ( not isCorrectDMD(options.dub_compiler, options.only_dmd) ):
        logNotification("Compiler is not the requested dmd version (%s), aborting..." % options.only_dmd)
        return

    searchRoot = os.path.join(os.path.dirname(os.path.realpath(__file__)), options.only_below)

    if ( options.coverage ):
        warnTime = 5.0
    else:
        if ( options.fast ):
            warnTime = 30.0
        else:
            warnTime = 300.0

    if ( options.latex ):
        generateLaTeX(searchRoot)
        return

    if ( options.only_doc ):
        buildDoc(options.dub_compiler, options.dlbc_root)
        return

    if ( options.build_all ):
        buildAll(options)
        reportBuildTimers(120.0)
        return

    if ( options.describe ):
        dlbct.logging.verbosityLevel = 5

    if ( options.clean ):
        # Clean coverage files here, tests will be cleaned later
        cleanCoverage(options)

    unittests = []
    if ( options.coverage or options.coverage_unittest ):
        if ( options.dub_compiler != "dmd" ):
            logNotification("Coverage information is generated only by dmd, skipping unittest coverage...")
            return
        options.dub_build = "unittest-cov"
        cleanCoverage(options)
        unittests = runUnittests(options)
        if ( not options.coverage ):
            reportRunTimers(unittests, warnTime)
            return
        options.dub_build = "cov"

    # Populate list of matching tests.
    matchingTests = []
    if ( os.path.isfile(searchRoot) ):
        testRoot = os.path.dirname(searchRoot)
        filename = os.path.basename(searchRoot)
        matchingTests.append(Test(testRoot, filename))
        singleTest = True
    else:
        singleTest = False
        for testRoot, dirnames, filenames in os.walk(searchRoot):
            for filename in fnmatch.filter(filenames, '*.json*'):
                matchingTests.append(Test(testRoot, filename))

    nerr = 0
    ntests = len(matchingTests)
    for i, test in enumerate(sorted(matchingTests, key=lambda test: test.filePath)):
        if ( options.timers_all ):
            for compiler in dubCompilerChoices:
                options.dub_compiler = compiler
                processTest(test, options, ntests, i, singleTest)
                nerr += sum(test.errors)
            plotTimersData(m[0], options.v)
        elif ( options.timers ):
            processTest(test, options, ntests, i, singleTest)
            nerr += sum(test.errors)
            plotTimersData(m[0], options.v)
        else:
            processTest(test, options, ntests, i, singleTest)
            nerr += sum(test.errors)

    if ( options.describe ):
        return

    # reportRunTimers(matchingTests + unittests, warnTime)

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

