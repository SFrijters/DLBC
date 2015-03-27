#!/usr/bin/env python

import glob
import h5py
import os
import sys
import numpy as np

def checkMirrorSymmetryY2d(simulationName, fieldName, relpath):
    globstr = os.path.join(relpath, fieldName + "*" + simulationName + "*h5")
    g = glob.glob(globstr)
    f = h5py.File(g[0], 'r')
    v = f["/OutArray"]

    half = v.shape[1]/2

    left = v[:,0:half]
    right = v[:,half:]

    for i in range(0, half):
        l = left[:,i]
        r = right[:,31-i]
        c = l == r
        if ( not np.all(c) ):
            return 1

    return 0

