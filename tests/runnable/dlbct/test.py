#!/usr/bin/env python

import json
import os

from logging import *

class Test:

    nSubtests = 1
    disabled = False
    skipped = None
    timers = None
    errors = None

    def __init__(self, testRoot, fileName):
        self.testRoot = testRoot
        self.fileName = fileName
        self.filePath = os.path.join(testRoot, fileName)

        self.jsonData = open(self.filePath)

        # Try to parse the json
        try:
            self.data = json.load(self.jsonData)
        except ValueError:
            self.jsonData.close()
            logFatal("JSON file '%s' seems to be broken. Please notify the test designer." % self.filePath, -1)

        self.jsonData.close()

        # Read name
        try:
            self.name = self.data["name"]
        except KeyError:
            logFatal("JSON file '%s' lacks a name. Please notify the test designer." % self.filePath, -1)

        # Read description
        try:
            self.description = self.data["description"]
        except KeyError:
            logFatal("JSON file '%s' lacks a description. Please notify the test designer." % self.filePath, -1)

        try:
            self.configuration = self.data["configuration"]
        except KeyError:
            logFatal("JSON file '%s' lacks a configuration. Please notify the test designer." % self.filePath, -1)

        try:
            self.inputFile = self.data["input-file"]
        except KeyError:
            logFatal("JSON file '%s' lacks a path to an input file. Please notify the test designer." % self.filePath, -1)

        try:
            self.clean = self.data["clean"]
        except KeyError:
            logFatal("JSON file %s lacks a 'clean' parameter. Please notify the test designer." % self.filePath, -1)

        try:
            self.compare = self.data["compare"]
        except KeyError:
            logFatal("JSON file %s lacks a 'compare' parameter. Please notify the test designer." % self.filePath, -1)

        # Read tags
        try:
            self.tags = self.data["tags"]
        except KeyError:
            logDebug("JSON file '%s' lacks a 'tags' parameter. Assuming no tags." % self.filePath)
            self.tags = []

        # Read LaTeX filename
        try:
            self.latex = self.data["latex"]
        except KeyError:
            logDebug("JSON file '%s' lacks a 'latex' parameter. Assuming no additional LaTeX." % self.filePath)
            self.latex = None

        try:
            self.plot = self.data["plot"]
        except KeyError:
            logDebug("JSON file '%s' lacks a 'plot' parameter. Assuming no plot." % self.filePath)
            self.plot = None

        try:
            self.checkpoint = self.data["checkpoint"]
        except KeyError:
            logDebug("JSON file '%s' lacks a 'checkpoint' parameter. Assuming no checkpoint restore." % self.filePath)
            self.checkpoint = None

        try:
            self.np = self.data["np"]
        except KeyError:
            logDebug("JSON file '%s' lacks an 'np' parameter. Set to 1 by default." % self.filePath)
            self.np = 1

        try:
            self.parameters = self.data["parameters"]
        except KeyError:
            logDebug("JSON file '%s' lacks a 'parameters' parameter. Assuming no parameters need to be passed to DLBC." % self.filePath)
            self.parameters = None

        try:
            self.coverage = self.data["coverage"]
        except KeyError:
            logDebug("JSON file '%s' lacks a 'coverage' parameter. Assuming no special options are needed." % self.filePath)
            self.coverage = None

        try:
            self.fast = self.data["fast"]
        except KeyError:
            logDebug("JSON file '%s' lacks a 'fast' parameter. Assuming no special options are needed." % self.filePath)
            self.fast = None

        if ( "disabled" in self.fileName ):
            self.disabled = True

        if ( self.parameters ):
            self.nSubtests = reduce(lambda x, y: int(x) * int(y), [ len(p["values"]) for p in self.parameters ], 1)

        self.timerName = os.path.relpath(os.path.join(testRoot, self.name), "tests")

        self.errors = [ 0 ] * self.nSubtests
        self.timers = [ 0 ] * self.nSubtests
        self.skipped = [ False ] * self.nSubtests

    def describe(self, n, i, withLines=False):
        """ Print pretty description for single test. """
        import textwrap
        istr = "%02d/%02d " % ((i+1),n)
        initialIndent = " "*6
        subsequentIndent = " "*6
        if ( withLines ):
            logPlainAtLevel("\n" + "="*80, 4)
        logNotification(istr + self.name + " (" + os.path.relpath(self.filePath) + ") [" + self.configuration + "]:" )
        logNotification(textwrap.fill(self.description, initial_indent=initialIndent, subsequent_indent=subsequentIndent, width=80))
        logNotification("")

class Unittest(Test):

    def __init__(self, name, root):
        self.name = name
        self.testRoot = root
        self.errors = [ 0 ]
        self.timers = [ 0 ]
        self.skipped = [ 0 ]
        self.timerName = name
        self.nSubtests = 1
        

        
