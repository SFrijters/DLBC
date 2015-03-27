#!/usr/bin/env python

import csymm

relpath = "reference-data"

nerr = 0
nerr += csymm.checkMirrorSymmetryY("fluid-init-eqdisttwospheresfrac-2d", "population-red", relpath)
nerr += csymm.checkMirrorSymmetryY("fluid-init-eqdisttwospheresfrac-2d", "population-blue", relpath)
nerr += csymm.checkMirrorSymmetryY("fluid-init-eqdisttwospheresfrac-2d", "colour-red-blue", relpath)

exit(nerr)

