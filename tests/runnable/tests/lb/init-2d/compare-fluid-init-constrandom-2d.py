#!/usr/bin/env python

import crandom

relpath = "reference-data"

nerr = 0
nerr += crandom.compareRandomField2d("fluid-init-constrandom-2d", "population-red", relpath, 9*0.5, 1e-2)
nerr += crandom.compareRandomField2d("fluid-init-constrandom-2d", "population-blue", relpath, 9*1.0, 1e-2)

exit(nerr)

