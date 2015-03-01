#!/usr/bin/env python

#### START HEADER
from mplhelper import *
#### END HEADER

import h5py

def plot_dataset(globstr, i, j, gcc):

    x = []
    v = []

    g = sorted(glob.glob(globstr))
    if ( len(g) != 1): return
    f = h5py.File(g[0], 'r')
    v = f["/OutArray"][:]
    # print v
    if ( any(isnan(v))): return
    if ( max(v) < 0.0001 ): return

    x = irange(1,len(v), 1)

    lbl = ""
    if ( j == 0 ):
        lbl = "D1Q3, g = %.2f" % gcc
    if ( j == 1 ):
        lbl = "D1Q5, g = %.2f" % gcc

    p, = ax.plot(x, v, marker="None", markeredgecolor=pc(i), mfc="None", label=lbl, color=pc(i))
    p.set_dashes(pd(j))

def plot_dataset_2d(globstr, i, j, gcc):

    x = []
    v = []

    g = sorted(glob.glob(globstr))
    if ( len(g) != 1): return
    f = h5py.File(g[0], 'r')
    v = f["/OutArray"][:,0]
    # print v
    if ( any(isnan(v))): return
    if ( max(v) < 0.0001 ): return

    x = irange(1,len(v), 1)

    lbl = "D2Q9, g = %.2f" % gcc

    p, = ax.plot(x, v, marker="o", markeredgecolor=pc(i), mfc="None", label=lbl, color=pc(i))
    p.set_dashes(pd(j))


def plot_dataset_3d(globstr, i, j, gcc):

    x = []
    v = []

    g = sorted(glob.glob(globstr))
    if ( len(g) != 1): return
    f = h5py.File(g[0], 'r')
    v = f["/OutArray"][:,0,0]
    # print v
    if ( any(isnan(v))): return
    if ( max(v) < 0.0001 ): return

    x = irange(1,len(v), 1)

    lbl = "D3Q19, g = %.2f" % gcc

    p, = ax.plot(x, v, marker="s", markeredgecolor=pc(i), mfc="None", label=lbl, color=pc(i))
    p.set_dashes(pd(j))

fig, ax = plt.subplots()

plot_dataset(os.path.join(options.relpath, r"d1q3/colour-red-blue-laplace-d1q3-*-t00001000.h5" ), 0, 0, 3.6 )
plot_dataset(os.path.join(options.relpath, r"d1q5/colour-red-blue-laplace-d1q5-*-t00001000.h5" ), 1, 1, 3.6 )
plot_dataset_2d(os.path.join(options.relpath, r"d2q9/colour-red-blue-laplace-d2q9-*-t00001000.h5" ), 2, 2, 3.6 )
plot_dataset_3d(os.path.join(options.relpath, r"d3q19/colour-red-blue-laplace-d3q19-*-t00001000.h5" ), 3, 3, 3.6 )

# Styles
ax.set_xlabel(r"$x$")
ax.set_ylabel(r"$\rho$")

# ax.xaxis.set_major_formatter(FormatStrFormatter(r'%.2f'))
# ax.xaxis.set_major_locator(MultipleLocator(0.25))

# ax.xaxis.set_minor_formatter(FormatStrFormatter(''))
# ax.xaxis.set_minor_locator(MultipleLocator(0.125))

#ax.set_xlim(0.0, 1.0)
#ax.set_ylim(0.0, 0.07)

handles, labels = ax.get_legend_handles_labels()
l = ax.legend(handles, labels, loc='lower center', title=r"")

write_to_file("laplace-quasi-1d")

exit()

