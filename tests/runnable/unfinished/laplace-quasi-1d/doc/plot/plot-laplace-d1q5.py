#!/usr/bin/env python

#### START HEADER
from mplhelper import *
#### END HEADER

import h5py

def plot_dataset(globstr, i, j):

    print globstr
    x = []
    v = []

    g = sorted(glob.glob(globstr))
    if ( len(g) != 1): return
    f = h5py.File(g[0], 'r')
    v = f["/OutArray"][:]
    print v
    if ( any(isnan(v))): return
    if ( max(v) < 0.0001 ): return

    x = irange(1,len(v), 1)

    lbl = "g = " + str(t)
    lbl = ""
    if ( j == 0 ):
        lbl = "D1Q3, g = %d" % i
    if ( j == 1 ):
        lbl = "D1Q5, g = %d" % i

    p, = ax.plot(x, v, marker="None", markeredgecolor=pc(i), mfc="None", label=lbl, color=pc(i-1))
    p.set_dashes(pd(j))

def plot_dataset_2d(globstr, i, j):

    print globstr
    x = []
    v = []

    g = sorted(glob.glob(globstr))
    if ( len(g) != 1): return
    f = h5py.File(g[0], 'r')
    v = f["/OutArray"][:,0]
    print v
    if ( any(isnan(v))): return
    if ( max(v) < 0.0001 ): return

    x = irange(1,len(v), 1)

    lbl = "D2Q9, g = %d" % i

    p, = ax.plot(x, v, marker="o", markeredgecolor=pc(i), mfc="None", label=lbl, color=pc(i-1))
    p.set_dashes(pd(j))


def plot_dataset_3d(globstr, i, j):

    print globstr
    x = []
    v = []

    g = sorted(glob.glob(globstr))
    if ( len(g) != 1): return
    f = h5py.File(g[0], 'r')
    v = f["/OutArray"][:,0,0]
    print v
    if ( any(isnan(v))): return
    if ( max(v) < 0.0001 ): return

    x = irange(1,len(v), 1)

    lbl = "D3Q19, g = %d" % i

    p, = ax.plot(x, v, marker="s", markeredgecolor=pc(i), mfc="None", label=lbl, color=pc(i-1))
    p.set_dashes(pd(j))

fig, ax = plt.subplots()

relpath = "../../output-d1q3/"

for j, t in enumerate(irange(1, 10, 1)):
    plot_dataset(relpath+r"laplace-1d-gcc%d/colour-red-blue-laplace-d1q3-*-t00100000.h5" % t, t, 0 )

relpath = "../../output-d1q5/"

for j, t in enumerate(irange(1, 10, 1)):
    plot_dataset(relpath+r"laplace-1d-gcc%d/colour-red-blue-laplace-d1q5-*-t00100000.h5" % t, t, 1 )

relpath = "../../output-d2q9/"

for j, t in enumerate(irange(1, 10, 1)):
    plot_dataset_2d(relpath+r"laplace-1d-gcc%d/colour-red-blue-laplace-d2q9-*-t00100000.h5" % t, t, 2 )

relpath = "../../output-d3q19/"

for j, t in enumerate(irange(1, 10, 1)):
    plot_dataset_3d(relpath+r"laplace-1d-gcc%d/colour-red-blue-laplace-d3q19-*-t00100000.h5" % t, t, 3 )


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
l = ax.legend(handles, labels, loc='upper left', title=r"")

write_to_file("laplace-d1q5")

exit()

