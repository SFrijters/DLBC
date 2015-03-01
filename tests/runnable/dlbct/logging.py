#!/usr/bin/env python

"""
Helper functions for logging with particular verbosity levels.

The levels match the ones in DLBC.
"""

verbosityChoices = ["Debug", "Information", "Notification", "Warning", "Error", "Fatal", "Off"]

def getVerbosityLevel(str):
    """ Convert string representation of verbosity to an integer. """
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

def getTimePrefix(usePrefix):
    """ Create a time prefix. """
    if ( not usePrefix ):
        return ""
    from time import strftime
    return strftime("%H:%M:%S ")

def getVerbosityPrefix(usePrefix, logLevel):
    """ Get the verbosity prefix corresponding to logLevel. """
    if ( not usePrefix ):
        return ""
    if ( logLevel == 6 ):
        return "[D] "
    if ( logLevel == 5 ):
        return "[I] "
    if ( logLevel == 4 ):
        return "[N] "
    if ( logLevel == 3 ):
        return "[W] "
    if ( logLevel == 2 ):
        return "[E] "
    if ( logLevel == 1 ):
        return "[E] "

def logAtLevel(str, logLevel, returncode=0):
    """ Log a message at logLevel. """
    if ( verbosityLevel >= logLevel ):
        print getTimePrefix(logTime) + getVerbosityPrefix(logPrefix, logLevel) + str
    if ( logLevel == 2 ):
        return 1
    if ( logLevel < 2 ):
        exit(returncode)

def logPlainAtLevel(str, logLevel, returncode=0):
    """ Log a message at logLevel, assuming logTime and logPrefix are False. """
    if ( verbosityLevel >= logLevel ):
        print str
    if ( logLevel == 2 ):
        return 1
    if ( logLevel < 2 ):
        exit(returncode)

def logDebug(str):
    """ Log at Debug level. """
    return logAtLevel(str, 6)

def logInformation(str):
    """ Log at Information level. """
    return logAtLevel(str, 5)

def logNotification(str):
    """ Log at Notification level. """
    return logAtLevel(str, 4)

def logWarning(str):
    """ Log at Warning level. """
    return logAtLevel(str, 3)

def logError(str):
    """ Log at Error level. Return 1 to represent 1 error. """
    return logAtLevel(str, 2)

def logFatal(str, returncode):
    """ Log at Fatal level. Exit the program with the specified return code. """
    return logAtLevel(str, 1, returncode)

verbosityLevel = getVerbosityLevel("Debug")
logPrefix = False
logTime = False

