#!/usr/bin/env python

"""
Wrapper functions to create and merge code coverage data.
"""

import os
import shutil

from build import *
from logging import *
from path import *
from run import *

def constructCoveragePath(dlbcRoot):
    """ Construct the location where coverage data will be stored. """
    return os.path.normpath(os.path.join(dlbcRoot, "tests/coverage"))

def moveCovLst(dlbcRoot, configuration):
    """ Move a set of coverage .lst files to the coverage path and add a .tmp suffix. """
    import glob
    covpath = constructCoveragePath(dlbcRoot)
    for f in glob.glob(os.path.normpath(os.path.join(covpath,"*.lst"))):
        nf = os.path.basename(f).replace(".lst", "-" + configuration + ".lst.tmp")
        shutil.move(f, os.path.join(covpath, nf))

def cleanCoverage(options):
    """ Clean (remove) the coverage directory. """
    covpath = constructCoveragePath(options.dlbc_root)
    if ( os.path.exists(covpath) ):
        logNotification("Removing coverage directory ...")
        shutil.rmtree(covpath)

def mergeCovLst(f1, f2):
    """ Merge two coverage .lst files, by adding the integer values for each line. """
    logDebug("  Merging coverage file '" + f2 + "' into '" + f1 + "' ...")
    with open(f1) as ff1:
        cov1 = ff1.readlines()
    with open(f2) as ff2:
        cov2 = ff2.readlines()

    merged = []

    for i in range(0, len(cov1)):
        import string
        split1 = string.split(cov1[i], "|", 1)
        if ( len(split1) != 2):
            merged.append(cov1[i])
        else:
            count1 = split1[0].strip()
            line1 = split1[1]
            split2 = string.split(cov2[i], "|", 1)
            count2 = split2[0].strip()
            line2 = split2[1]

            if ( line1 != line2 ):
                logFatal("Coverage file error.", -1)

            if ( count1 == "" and count2 == "" ):
                merged.append(cov1[i])

            else:
                if ( count1 == "" ): count1 = "0"
                if ( count2 == "" ): count2 = "0"
                sum = int(count1) + int(count2)
                merged.append("%d|%s" % ( sum, line1 ) )

    with open(f1, 'w') as ff1:
        for l in merged:
            ff1.write(l)

def mergeCovLstsUnittest(options, covpath):
    """ Merge coverage information generated by running the unittests for different configurations. """
    import glob
    logNotification("Merging unittest coverage information ...")

    # Rename the .lst files for the first configuration - the others will be merged into this one.
    for f in glob.glob(os.path.join(covpath, "*" + dlbcConfigurations[0] + "*.lst.tmp")):
        nf = f.replace(".lst.tmp", ".lst").replace("-" + dlbcConfigurations[0],"")
        shutil.move(f, os.path.join(covpath, nf))

    # Merge the other configurations into the first.
    for c in dlbcConfigurations[1:]:
        for f1 in glob.glob(os.path.join(covpath, "*.lst")):
            f2 = f1.replace(".lst", "-" + c + ".lst.tmp")
            mergeCovLst(f1, f2)
            logDebug("Removing coverage file '" + f2 + "' ...")
            os.remove(f2)

def mergeCovLsts(options, testRoot, covpath):
    """ Merge coverage information for a runnable test into the existing coverage files. """
    logNotification("Merging runnable coverage information ...")
    for f1 in glob.glob(os.path.join(covpath, "*.lst")):
        f2 = os.path.join(testRoot, os.path.basename(f1))
        mergeCovLst(f1, f2)

def runUnittests(options):
    """ Run unittests for all configurations. """
    logNotification("Preparing to run unittests ...")
    nerr = 0
    covpath = constructCoveragePath(options.dlbc_root)
    # Make the "tests/coverage" directory
    if ( not os.path.isdir(covpath)):
        os.mkdir(covpath)
    # Symlink in the src directory so the coverage works
    if ( not os.path.isdir(os.path.join(covpath, "src"))):
        os.symlink(os.path.join(options.dlbc_root, "src"), os.path.join(covpath, "src"))
    for c in dlbcConfigurations:
        exePath = constructExeTargetPath(c, options.dub_build, options.dub_compiler, options.dlbc_root)
        dubBuild(options.dub_compiler, options.dub_build, c, options.dub_force, options.dlbc_root)
        logNotification("Running unittests ...")
        command = [ exePath, "-v", options.dlbc_verbosity, "--version" ]
        nerr += runSubtest(command, covpath)
        moveCovLst(options.dlbc_root, c)
    mergeCovLstsUnittest(options, covpath)
