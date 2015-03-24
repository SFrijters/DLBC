#!/usr/bin/env python

import glob
import h5py
import os
import sys
import numpy as np

def compareRandomField2d(simulationName, fieldName, relpath, density, relacc):
    globstr = os.path.join(relpath, fieldName + "*" + simulationName + "*h5")
    g = glob.glob(globstr)
    f = h5py.File(g[0], 'r')
    v = f["/OutArray"]
    total = np.sum(v)
    # Random values should not deviate too far from average value.
    relchange = abs(1.0 - ( total / (density * v.shape[0] * v.shape[1])) )
    # print("Relative deviation from expected average for '%s': %e (%e)" % ( fieldName, relchange, relacc ))
    if ( relchange > relacc ):
        return 1

    # All quadrants should be the same, because of random.shiftSeedByRank = false.
    halfx = v.shape[0]/2
    halfy = v.shape[1]/2
    q1 = v[0:halfx,0:halfy,:]
    q2 = v[halfx:,0:halfy,:]
    q3 = v[0:halfx,halfy:,:]
    q4 = v[halfx:,halfy:,:]

    c2 = ( q1 == q2 )
    c3 = ( q1 == q3 )
    c4 = ( q1 == q4 )

    if ( not ( np.all(c2) and np.all(c3) and np.all(c4) ) ):
        return 1

    return 0

