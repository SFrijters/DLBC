#!/usr/bin/env python

"""
Wrapper to plot test data.
"""

from logging import *

import os
import subprocess

def plotTest(thisTest, reference):
    """ # Execute plotting scripts for a single test. """

    if ( not thisTest.plot ):
        logNotification("Plotting data for test ... nothing to be done.")
        return

    logNotification("Plotting data for test ...")
    # Add the path to mplhelper.py
    penv = os.environ.copy()
    penv["PYTHONPATH"] = penv["PYTHONPATH"] + ":" + os.path.dirname(os.path.realpath(__file__))
    for p in thisTest.plot:
        path = os.path.join(thisTest.testRoot, p)
        logDebug("  Executing '%s' ..." % path)
        if ( reference ):
            command = [ path, "--relpath", "reference-data" ]
        else:
            command = [ path, "--relpath", "output" ]

        p = subprocess.Popen(command, cwd=thisTest.testRoot, env=penv)
        p.communicate()
        if ( p.returncode != 0 ):
            logFatal("Plotting script '%s' returned %d." % ( path, p.returncode ), p.returncode)

    logInformation("  Done!")

