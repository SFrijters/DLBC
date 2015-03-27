#!/usr/bin/env python

import cfrac
import csymm

relpath = "reference-data"

nerr = 0

for fn in [ "population-red", "population-blue", "colour-red-blue" ]:
    nerr += csymm.checkQuasi1dX2d("fluid-init-eqdistlamellaefrac-y-2d", fn, relpath)
    nerr += cfrac.checkEqualFrac2d("fluid-init-eqdistlamellaefrac-y-2d", "fluid-init-eqdistlamellae-y-2d", fn, relpath)

if ( nerr > 0 ):
    exit(1)

