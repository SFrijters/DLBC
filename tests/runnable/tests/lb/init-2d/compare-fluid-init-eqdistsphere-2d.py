#!/usr/bin/env python

import csymm

relpath = "reference-data"

nerr = 0

for fn in [ "population-red", "population-blue", "colour-red-blue" ]:
    nerr += csymm.checkMirrorSymmetryY2d("fluid-init-eqdistsphere-2d", fn, relpath)

if ( nerr > 0 ):
    exit(1)

