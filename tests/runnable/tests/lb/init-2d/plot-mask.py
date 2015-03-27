#!/usr/bin/env python

#### START HEADER
from mplhelper import *
#### END HEADER

relpath = "output"

g = sorted(glob.glob(relpath + "/mask-*h5"))
for fn in g:
    print fn
    dsname = fn.replace(relpath + "/mask-","").replace("-t00000000.h5","")
    fig, ax = plt.subplots()
    
    f = h5py.File(fn,'r')
    dset = f['OutArray']
    colour = dset[:,:]

    ax.set_xticks([-0.5, colour.shape[1]/2 - 0.5, colour.shape[1] - 0.5])
    ax.set_xticklabels(["0", str(colour.shape[1]/2), str(colour.shape[1])])

    ax.set_yticks([-0.5, colour.shape[0]/2 - 0.5, colour.shape[0] - 0.5])
    ax.set_yticklabels(["0", str(colour.shape[0]/2), str(colour.shape[0])])

    density = plt.imshow(colour)
    grid(True, which='major')

    density.set_cmap('gray')    
    plt.colorbar()
    plt.axvline(0.5,color='k')
    plt.axhline(31.5,color='k')
    plt.show()
    write_to_file(dsname)

exit()

