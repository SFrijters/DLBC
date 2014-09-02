#!/bin/bash -e
h5diff output/mask-dielectric-capacitor-*-t00000000.h5 reference-data/mask-dielectric-capacitor-*-t00000000.h5 /OutArray
h5diff output/elChargeN-dielectric-capacitor-*-t00000000.h5 reference-data/elChargeN-dielectric-capacitor-*-t00000000.h5 /OutArray
h5diff output/elChargeP-dielectric-capacitor-*-t00000000.h5 reference-data/elChargeP-dielectric-capacitor-*-t00000000.h5 /OutArray
h5diff output/elPot-dielectric-capacitor-*-t00000000.h5 reference-data/elPot-dielectric-capacitor-*-t00000000.h5 /OutArray
h5diff output/elDiel-dielectric-capacitor-*-t00000000.h5 reference-data/elDiel-dielectric-capacitor-*-t00000000.h5 /OutArray
h5diff output/elField-dielectric-capacitor-*-t00000000.h5 reference-data/elField-dielectric-capacitor-*-t00000000.h5 /OutArray
