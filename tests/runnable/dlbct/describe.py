#!/usr/bin/env python

"""
Print pretty description for tests.
"""

from logging import *
from parsejson import *

import os

def describeTest(data, fn, n, i, withLines=False):
    """ Print pretty description for single test. """
    import textwrap
    istr = "%02d/%02d " % ((i+1),n)
    initialIndent = " "*6
    subsequentIndent = " "*6
    if ( withLines ):
        logPlainAtLevel("\n" + "="*80, 4)
    logNotification(istr + getName(data, fn) + " (" + os.path.relpath(fn) + ") [" + getConfiguration(data, fn) + "]:" )
    logNotification(textwrap.fill(getDescription(data, fn), initial_indent=initialIndent, subsequent_indent=subsequentIndent, width=80))
    logNotification("")
    return getName(data, fn)

