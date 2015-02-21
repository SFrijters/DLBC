#!/usr/bin/env python

"""
Get the values required for the DLBC tests from a JSON dataset.
"""

from logging import *

import json

def getName(data, fn):
    """ Get test name. """
    try:
        return data["name"]
    except KeyError:
        logFatal("JSON file %s lacks a name. Please notify the test designer." % fn, -1)

def getDescription(data, fn):
    """ Get test description. """
    try:
        return data["description"]
    except KeyError:
        logFatal("JSON file %s lacks a description. Please notify the test designer." % fn, -1)

def getTags(data, fn):
    """ Get test tags. """
    try:
        return data["tags"]
    except KeyError:
        logDebug("JSON file %s lacks a 'tags' parameter. Assuming no tags." % fn)
        return []

def getLatex(data, fn):
    """ Get test latex file name. """
    try:
        return data["latex"]
    except KeyError:
        logDebug("JSON file %s lacks a 'latex' parameter. Assuming no additional LaTeX." % fn)
        return ""

def getPlot(data, fn):
    """ Get list of plotting scripts. """
    try:
        return data["plot"]
    except KeyError:
        logDebug("JSON file %s lacks a 'plot' parameter. Assuming no plot." % fn)
        return []

def getConfiguration(data, fn):
    """ Get required configuration. """
    try:
        return data["configuration"]
    except KeyError:
        logFatal("JSON file %s lacks a configuration. Please notify the test designer." % fn, -1)

def getInputFile(data, fn):
    """ Get input file name. """
    try:
        return data["input-file"]
    except KeyError:
        logFatal("JSON file %s lacks a path to an input file. Please notify the test designer." % fn, -1)

def getNP(data, fn):
    """ Get number of ranks requested. """
    try:
        return data["np"]
    except KeyError:
        logDebug("JSON file %s lacks an 'np' parameter. Set to 1 by default." % fn)
        return 1

def getClean(data, fn):
    """ Get list of paths to be cleaned. """
    try:
        return data["clean"]
    except KeyError:
        logFatal("JSON file %s lacks a 'clean' parameter. Please notify the test designer." % fn, -1)

def getParameters(data, fn):
    """ Get list of parameters with their values. """
    try:
        return data["parameters"]
    except KeyError:
        logDebug("JSON file %s lacks a 'parameters' parameter. Assuming no parameters need to be passed to DLBC." % fn)
        return []

def getCompare(data, fn):
    """ Get list of comparison operations to be performed. """
    try:
        return data["compare"]
    except KeyError:
        logFatal("JSON file %s lacks a 'compare' parameter. Please notify the test designer." % fn, -1)

def getCompareShell(compare):
    """ Get list of shell scripts to be executed during compare. """
    try:
        return compare["shell"]
    except KeyError:
        logDebug("JSON file lacks a 'compare:shell' parameter. Assuming no additional shell commands need to be run.")
        return []


def getCompareType(comparison):
    """ Get optional accuracy parameter for h5diff from comparison. """
    try:
        return comparison["type"]
    except KeyError:
        logFatal("Comparison requires a 'type' parameter. Please notify the test designer.", -1)
        return ""

def getCompareAccuracy(comparison):
    """ Get optional accuracy parameter for h5diff from comparison. """
    try:
        return comparison["accuracy"]
    except KeyError:
        logDebug("Comparison lacks an 'accuracy' parameter. Assuming no laxness.")
        return ""


