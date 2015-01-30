#!/usr/bin/env python

#### START HEADER
from mplhelper import *
#### END HEADER

import h5py

L = 30

def vth(x):
    return 3.0*0.0001*(x)*(L-(x))

def plot_dataset(globstr, i):

    x = []
    v = []

    g = sorted(glob.glob(globstr))
    if ( len(g) != 1): return
    f = h5py.File(g[0], 'r')
    v = f["/OutArray"][:,0,1]
    x = irange(1,32, 1)
    x_th = [ (e-1.5) for e in list(x) ]

    # Scale x-axis
    x = [ (e-1.5) / L for e in list(x) ]

    v_th = [ vth(e) for e in list(x_th) ]
    v_rel = [ abs( e / f -1.0) for e, f in zip(v,v_th)]

    lbl = ""
    p, = ax.plot(x, v, marker=pm(i), markeredgecolor=pc(i), mfc="None", label=lbl, color=pc(i))
    p, = inset.plot(x, v_rel, marker=pm(i), markeredgecolor=pc(i), mfc="None", label=lbl, color=pc(i),ms=pims)

    # Theoretical curve
    zx = arange(0,32, 0.1)
    zy = [ vth(e) for e in list(zx) ]
    zx = [ e / L for e in list(zx) ]
    p, = ax.plot(zx, zy, ls="None", marker="None", c='k')
    p.set_dashes([4,4])

fig, ax = plt.subplots()

inset = axes([.4, .4, .3, .3])

plot_dataset(os.path.join(options.relpath, "velocity-red-poiseuille-2d-*-t00100000.h5"), 0)
plot_dataset(os.path.join(options.relpath, "velocity-blue-poiseuille-2d-*-t00100000.h5"), 1)

# Styles
ax.set_xlabel(r"$x/L$")
ax.set_ylabel(r"$v_y$")

ax.set_xlim(0.0, 1.0)
ax.set_ylim(0.0, 0.07)

inset.set_xlim(0.0, 1.0)
inset.set_ylim(0.001, 0.1)
inset.set_yscale("log")

handles, labels = ax.get_legend_handles_labels()
l = ax.legend(handles, labels, loc='upper left', title=r"")

write_to_file("poiseuille-2d")

exit()

