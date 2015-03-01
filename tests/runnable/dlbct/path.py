#!/usr/bin/env python

"""
Construct paths.
"""

# Construct paths
def constructExeTargetPath(configuration, build, compiler, root):
    """ Construct absolute path to target executable. """
    import os
    return os.path.abspath(os.path.join(root, constructExeTargetName(configuration, build, compiler)))

def constructExeTargetName(configuration, build, compiler):
    """ Construct file name for executable. """
    return "dlbc-" + configuration + "-" + build + "-" + compiler

