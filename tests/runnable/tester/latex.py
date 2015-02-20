#!/usr/bin/env python

"""
Generate LaTeX output from selected tests.
"""

from logging import *
from parsejson import *

import fnmatch
import os

def replaceTokensInLaTeX(latex, testRoot):
    """ Replace %path% token to allow for pdf plot includes. """
    return latex.replace("%path%", os.path.join(testRoot, "reference-data/"))

def generateLaTeXforTest(testRoot, filename):
    """ Generate LaTeX code for a single test. """
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
    print("\\label{sssec:%s}\n" % name)
    print("\\textbf{Description:} %s\\\\" % description)
    print("\\textbf{Location:} \\textsc{%s}\\\\" % os.path.relpath(fn, os.path.dirname(os.path.realpath(__file__))))
    print("\\textbf{Tags:} %s\\\\" % ", ".join(sorted(tags)))
    if ( latex ):
        f = open(os.path.join(testRoot, latex), 'r')
        print(replaceTokensInLaTeX(f.read(), testRoot))
        f.close()
    else:
        print("\\todo{Long description}")
    jsonData.close()

def generateLaTeX(searchRoot):
    """ Generate LaTeX for all tests below searchRoot. """
    matches = []
    for testRoot, dirnames, filenames in os.walk(searchRoot):
        for filename in fnmatch.filter(filenames, '*.json'):
            matches.append([testRoot, filename])

    for m in sorted(matches):
        generateLaTeXforTest(m[0], m[1])

