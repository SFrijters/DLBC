#!/usr/bin/env python

import glob
import h5py
import os

def compare(path, prefix, time, relpath, accuracy):
    # Read 3d array
    d3_globstr = os.path.join(path, prefix + "*%08d*h5" % time)
    g3 = sorted(glob.glob(d3_globstr))
    if ( len(g3) != 1 ):
        if ( path == "reference-data" ):
            return -1
        else:
            return 1

    f3 = h5py.File(g3[0], 'r')
    v3 = f3["/OutArray"][0,0,:]

    # Read 2d array
    d2_globstr = os.path.join(relpath, path, prefix + "*%08d*h5" % time)
    g2 = sorted(glob.glob(d2_globstr))

    if ( len(g2) != 1 ):
        if ( path == "reference-data" ):
            return -1
        else:
            return 1

    f2 = h5py.File(g2[0], 'r')
    v2 = f2["/OutArray"][:,0]

    # Subtract and throw error if any difference is more than 1e-14
    diff23 = v3 - v2
    diff = [ abs(e) > accuracy for e in diff23 ]
    if any(diff):
        return -1

    return 0
   
for s in [ "reference-data", "output" ]:
    for p in [ "density-red", "density-blue" ]:
        r = compare(s, p, 10, "../bdist2-2d", 1e-14)
        if ( r != 0 and r != 1 ):
            exit(-1)

