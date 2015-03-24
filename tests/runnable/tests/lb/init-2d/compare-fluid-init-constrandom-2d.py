#!/usr/bin/env python

import glob
import h5py
import os
import sys

import numpy as np

relacc = 1e-2
relpath = "reference-data"

globstrr = os.path.join(relpath, "population-red*fluid-init-constrandom*h5")
gr = glob.glob(globstrr)
fr = h5py.File(gr[0], 'r')
vr = fr["/OutArray"]
totalr = np.sum(vr)
# Random values should not deviate too far from average value.
relchanger = abs(1 - ( totalr / (9 * 0.5 * 64 * 64)) )
if ( relchanger > relacc ): exit(1)

# All quadrants should be the same, because of random.shiftSeedByRank = false.
q1 = vr[0:32,0:32,:]
q2 = vr[32:,0:32,:]
q3 = vr[0:32,32:,:]
q4 = vr[32:,32:,:]

c2 = ( q1 == q2 )
c3 = ( q1 == q3 )
c4 = ( q1 == q4 )

if ( not np.all(c2) ): exit(1)
if ( not np.all(c3) ): exit(1)
if ( not np.all(c4) ): exit(1)

globstrb = os.path.join(relpath, "population-blue*fluid-init-constrandom*h5")
gb = glob.glob(globstrb)
fb = h5py.File(gb[0], 'r')
vb = fb["/OutArray"]
totalb = np.sum(vb)
# Random values should not deviate too far from average value.
relchangeb = abs(1 - (totalb / (9 * 1.0 * 64 * 64)) )
if ( relchangeb > relacc ): exit(1)

# All quadrants should be the same, because of random.shiftSeedByRank = false.
q1 = vb[0:32,0:32,:]
q2 = vb[32:,0:32,:]
q3 = vb[0:32,32:,:]
q4 = vb[32:,32:,:]

c2 = ( q1 == q2 )
c3 = ( q1 == q3 )
c4 = ( q1 == q4 )

if ( not np.all(c2) ): exit(1)
if ( not np.all(c3) ): exit(1)
if ( not np.all(c4) ): exit(1)



