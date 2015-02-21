#!/usr/bin/env python

"""
Wrappers to easily create and visualize timing information.
"""

import glob
import os
import fnmatch
import re
import shutil

from logging import *

def constructTimersPath(testRoot):
    """ Construct absolute path to timers output for a test. """
    return os.path.join(testRoot, 'timers')

def moveTimersData(testRoot, compiler):
    """ Move freshly generated timers data to the timers path. """
    matches = []
    for root, dirnames, filenames in os.walk(os.path.join(testRoot, 'output')):
        for filename in fnmatch.filter(filenames, 'timers*.asc'):
            matches.append(os.path.join(root, filename))

    timersPath = constructTimersPath(testRoot)
    if ( not os.path.isdir(timersPath)):
        os.mkdir(timersPath)

    for t in matches:
        sourceFileName = os.path.basename(t)
        targetFileName = re.sub("-[0-9]{8}T[0-9]{6}-t[0-9]{8}", "", sourceFileName)
        targetFile = os.path.join(timersPath, targetFileName.replace(".asc", "-" + compiler + ".asc"))
        shutil.move(t, targetFile)

