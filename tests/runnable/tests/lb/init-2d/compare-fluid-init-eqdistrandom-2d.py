#!/usr/bin/env python

import crandom

relpath = "reference-data"

nerr = 0
nerr += crandom.compareRandomField2d("fluid-init-eqdistrandom-2d", "population-red", relpath, 0.5, 1e-2)
nerr += crandom.compareRandomField2d("fluid-init-eqdistrandom-2d", "population-blue", relpath, 1.0, 5e-2)

exit(nerr)

