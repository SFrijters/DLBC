#!/usr/bin/env python

"""
Helper script to execute the DLBC runnable test suite.
"""

import glob
import sys
import fnmatch
import os
import json
import subprocess

def getVerbosityLevel(str):
    if ( str == "Debug" ):
        return 6
    if ( str == "Information" ):
        return 5
    if ( str == "Notification" ):
        return 4
    if ( str == "Warning"):
        return 3
    if ( str == "Error"):
        return 2
    if ( str == "Fatal"):
        return 1
    return 0 # Off

verbosity = getVerbosityLevel("Fatal")

def logNotification(str):
    if ( verbosity >= 4 ):
        print("[N] " + str)

def logFatal(str):
    if ( verbosity >= 1 ):
        print("[F] " + str)
    exit(-1)

def dubBuild(options, configuration):
    command = ["dub", "build", "--compiler", options.compiler, "-b", options.build, "-c", configuration]
    if ( options.force ):
        command.append("--force")
    p = subprocess.Popen(command, cwd=options.dlbc_root)
    p.communicate()

def getDescription(data, fn):
    try:
        return data["description"]
    except KeyError:
        logFatal("JSON file %s lacks a description. Please notify the test designer." % fn)

def getConfiguration(data, fn):
    try:
        return data["configuration"]
    except KeyError:
        logFatal("JSON file %s lacks a configuration. Please notify the test designer." % fn)
    
def processTest(root, filename, options):
    fn = os.path.join(root, filename)
    jsonData = open(fn)
    try:
        data = json.load(jsonData)
    except ValueError:
        logFatal("JSON file %s seems to be broken. Please notify the test designer." % fn)

    if ( options.describe ):
        logNotification(fn + " : " + getDescription(data, fn))
        return

    logNotification(fn + " : " + getDescription(data, fn))
    dubBuild(options, getConfiguration(data, fn))
    jsonData.close()

def main():
    # Parser
    try:
        import argparse
    except ImportError:
        print( "\nImportError while loading argparse.")
        exit(-1)

    parser = argparse.ArgumentParser(description="Helper script to execute the DLBC runnable test suite")
    parser.add_argument("-v", choices=["Debug", "Information", "Notification", "Warning", "Error", "Fatal", "Off"], default="Fatal", help="Verbosity level")
    parser.add_argument("--build", choices=["release", "test"], default="release", help="Dub build type" )
    parser.add_argument("--compiler", default="dmd")
    parser.add_argument("--describe", action="store_true", help="Show test names only")
    parser.add_argument("--dlbc-root", default="../..", help="Relative path to DLBC root")
    parser.add_argument("--force", action="store_true", help="Force dub build")
    parser.add_argument("--test-single", nargs=1, help="Execute only the single specified test")
    parser.add_argument("positional", nargs="*")

    options = parser.parse_args()

    global verbosity
    verbosity = getVerbosityLevel(options.v)
    if ( options.describe ):
        verbosity = 5

    if ( options.test_single ):
        root = os.path.split(options.test_single[0])[0]
        filename = os.path.split(options.test_single[0])[1]
        processTest(root, filename, options)
    else:
        for root, dirnames, filenames in os.walk('.'):
            for filename in fnmatch.filter(filenames, '*.json'):
                processTest(root, filename, options)

if __name__ == '__main__':
    main()

