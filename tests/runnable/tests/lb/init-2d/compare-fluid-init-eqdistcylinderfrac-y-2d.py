#!/usr/bin/env python

import csymm
import cfrac

relpath = "reference-data"

nerr = 0

for fn in [ "population-red", "population-blue", "colour-red-blue" ]:
    nerr += csymm.checkMirrorSymmetryY2d("fluid-init-eqdistcylinderfrac-y-2d", fn, relpath)
    nerr += cfrac.checkEqualFrac2d("fluid-init-eqdistcylinderfrac-y-2d", "fluid-init-eqdistcylinder-y-2d", fn, relpath)

if ( nerr > 0 ):
    exit(1)

