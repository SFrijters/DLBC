#!/usr/bin/env python

import glob
import h5py
import os
import sys

def compare(path, prefix, time, accuracy):
    # Read d3q19 array
    d3q19_globstr = os.path.join(path, "d3q19/", prefix + "*%08d*h5" % time)
    d3q19_g = sorted(glob.glob(d3q19_globstr))

    if ( len(d3q19_g) != 1 ):
        if ( path == "reference-data" ):
            return -1
        else:
            return 1

    d3q19_f = h5py.File(d3q19_g[0], 'r')
    d3q19_v = d3q19_f["/OutArray"][:,0,0]
    # print d3q19_v

    # Read d2q9 array
    d2q9_globstr = os.path.join(path, "d2q9/", prefix + "*%08d*h5" % time)
    d2q9_g = sorted(glob.glob(d2q9_globstr))

    if ( len(d2q9_g) != 1 ):
        if ( path == "reference-data" ):
            return -1
        else:
            return 1

    d2q9_f = h5py.File(d2q9_g[0], 'r')
    d2q9_v = d2q9_f["/OutArray"][:,0]
    # print d2q9_v

    # # Read d1q5 array
    # d1q5_globstr = os.path.join(path, "d1q5/", prefix + "*%08d*h5" % time)
    # d1q5_g = sorted(glob.glob(d1q5_globstr))

    # if ( len(d1q5_g) != 1 ):
    #     if ( path == "reference-data" ):
    #         return -1
    #     else:
    #         return 1

    # d1q5_f = h5py.File(d1q5_g[0], 'r')
    # d1q5_v = d1q5_f["/OutArray"][:]
    # print d1q5_v

    # Read d1q3 array
    d1q3_globstr = os.path.join(path, "d1q3/", prefix + "*%08d*h5" % time)
    d1q3_g = sorted(glob.glob(d1q3_globstr))

    if ( len(d1q3_g) != 1 ):
        if ( path == "reference-data" ):
            return -1
        else:
            return 1

    d1q3_f = h5py.File(d1q3_g[0], 'r')
    d1q3_v = d1q3_f["/OutArray"][:]
    # print d1q3_v

    # Subtract and throw error if any difference is more than 1e-14
    diff23 = d3q19_v - d2q9_v
    # print diff23
    diff = [ abs(e) > accuracy for e in diff23 ]
    if any(diff):
        return -1

    diff13 = d3q19_v - d1q3_v
    # print diff13
    diff = [ abs(e) > accuracy for e in diff13 ]
    if any(diff):
        return -1

    return 0

if ( len(sys.argv) > 1 ):
    acc = float(sys.argv[1])
else:
    acc = 1e-14

for s in [ "reference-data", "output" ]:
    for p in [ "density-red", "density-blue" ]:
        r = compare(s, p, 1000, acc)
        if ( r != 0 and r != 1 ):
            exit(-1)


