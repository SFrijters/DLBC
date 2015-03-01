#!/usr/bin/env python

import numpy
from mayavi import mlab
import h5py
import glob

mlab.options.offscreen = True

for fn in sorted(glob.glob("output/colour*.h5")):
    outfile = fn.replace("h5", "png")
    print("Rendering '%s' ..." % outfile)
    f = h5py.File(fn, 'r')
    data = f["/OutArray"][()]

    a = mlab.contour3d(data, color=(1,1,1), contours=[0.0])
    o = mlab.outline(a, color=(0,0,0), extent=[0, 64, 0, 64, 0, 64])

    mlab.view(
        azimuth=0,
        elevation=0,
        distance=200.0,
        focalpoint=[32,32,32],
    )

    mlab.savefig(outfile)
    a.remove()
    o.remove()

