#!/usr/bin/env python

"""
Generate LaTeX output from selected tests.
"""

from logging import *
from test import Test

import fnmatch
import os

def replaceTokensInLaTeX(latex, testRoot):
    """ Replace %path% token to allow for pdf plot includes. """
    return latex.replace("%path%", os.path.join(testRoot, "reference-data/"))

def generateLaTeXforTest(thisTest, searchRoot):
    """ Generate LaTeX code for a single test. """

    name = thisTest.name
    if ( thisTest.disabled ):
        name = name + " (disabled)"

    print("\\subsubsection{%s}\n" % name)
    print("\\label{sssec:%s}\n" % name)
    print("\\textbf{Description:} %s\\\\" % thisTest.description)
    print("\\textbf{Location:} \\textsc{%s}\\\\" % os.path.relpath(thisTest.filePath, searchRoot) )
    print("\\textbf{Tags:} %s\\\\" % ", ".join(sorted(thisTest.tags)))
    if ( thisTest.latex ):
        f = open(os.path.join(thisTest.testRoot, thisTest.latex), 'r')
        print(replaceTokensInLaTeX(f.read(), thisTest.testRoot))
        f.close()
    else:
        print("\\todo{Long description}")

def generateLaTeX(searchRoot):
    """ Generate LaTeX for all tests below searchRoot. """
    matchingTests = []
    for testRoot, dirnames, filenames in os.walk(searchRoot):
        for filename in fnmatch.filter(filenames, '*.json*'):
            matchingTests.append(Test(testRoot, filename))

    for test in sorted(matchingTests, key=lambda test: test.filePath):
        generateLaTeXforTest(test, searchRoot)

