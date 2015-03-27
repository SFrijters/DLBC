#!/usr/bin/env python

import glob
import h5py
import os
import sys
import numpy as np

def checkEqualFrac2d(simulationName, simulationNameFrac, fieldName, relpath):
    globstr = os.path.join(relpath, fieldName + "*" + simulationName + "*h5")
    g = glob.glob(globstr)
    f = h5py.File(g[0], 'r')
    vabs = f["/OutArray"][:,:]

    globstr = os.path.join(relpath, fieldName + "*" + simulationNameFrac + "*h5")
    g = glob.glob(globstr)
    f = h5py.File(g[0], 'r')
    vfrac = f["/OutArray"][:,:]

    c = ( vabs == vfrac )
    if ( not np.all(c) ):
        return 1

    return 0

