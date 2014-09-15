#!/usr/bin/env python

#### START HEADER
from mplhelper import *
#### END HEADER

import h5py

L = 20.0
lambda_B = 0.4
e = 1.0
E = 0.025
eta = 1.0/6.0

def vth(x, K):
    v0 = ( e * E ) / ( eta * 2.0 * math.pi * lambda_B )
    return ( v0 * log( (cos(K*(x-0.5*L))) / cos( 0.5*K*L) ) )

def plot_dataset(globstr, sigma, K, t, sv, np, i, j):

    x = []
    v = []

    g = sorted(glob.glob(globstr))
    if ( len(g) != 1): return
    f = h5py.File(g[0], 'r')
    v = f["/OutArray"][:,0,1]
    x = irange(1,22, 1)

    # Scale x-axis
    xs = [ (e-1.5) / L for e in list(x) ]
    x = [ (e-1.5) for e in list(x) ]
    
    # Scale y-axis
    v = [ -e for e in list(v) ]
    v_th = [ vth(e, K) for e in list(x) ]
    v_rel = [ abs( e / f -1.0) for e, f in zip(v,v_th)]

    if ( j == 0 ):
        lbl = "$\sigma$ = " + str(sigma)
    else:
        lbl = r""
    p, = ax.plot(xs, v, marker=pm(j), markeredgecolor=pc(i), mfc="None", label=lbl, color=pc(i))
    #p.set_dashes(td(0))
    p, = inset.plot(xs, v_rel, marker=pm(j), markeredgecolor=pc(i), mfc="None", label=lbl, color=pc(i),ms=pims)
    #p.set_dashes(td(0))

    # Theoretical curve
    zx = arange(0,L,0.1)
    zy = [ vth(e, K) for e in list(zx) ]
    # print zy
    zx = [ e / L for e in list(zx) ]
    # print zx
    p, = ax.plot(zx, zy, ls="None", marker="None", c=pc(i))
    p.set_dashes([4,4])

fig, ax = plt.subplots()

inset = axes([.65, .4, .3, .3])

relpath = "../../reference-data/"
plot_dataset(relpath+"sigma0.003125-np1-SOR/velocity-*-t00010000.h5", 0.003125, 0.02766, 10000, "sor", 1, 0, 0)
plot_dataset(relpath+"sigma0.003125-np2-SOR/velocity-*-t00010000.h5", 0.003125, 0.02766, 10000, "sor", 2, 0, 1)
plot_dataset(relpath+"sigma0.03125-np1-SOR/velocity-*-t00010000.h5", 0.03125, 0.07854, 10000, "sor", 1, 1, 0)
plot_dataset(relpath+"sigma0.03125-np2-SOR/velocity-*-t00010000.h5", 0.03125, 0.07854, 10000, "sor", 2, 1, 1)
plot_dataset(relpath+"sigma0.3125-np1-SOR/velocity-*-t00010000.h5", 0.3125, 0.1395, 10000, "sor", 1, 2, 0)
plot_dataset(relpath+"sigma0.3125-np2-SOR/velocity-*-t00010000.h5", 0.3125, 0.1395, 10000, "sor", 1, 2, 1)

# Styles
ax.set_xlabel(r"$x/L$")
ax.set_ylabel(r"$v_y$")

ax.xaxis.set_major_formatter(FormatStrFormatter(r'%.2f'))
ax.xaxis.set_major_locator(MultipleLocator(0.25))

ax.xaxis.set_minor_formatter(FormatStrFormatter(''))
ax.xaxis.set_minor_locator(MultipleLocator(0.125))

inset.set_ylabel(r"$\rho_{\mathrm{err}}$", fontsize=pialfs)

inset.xaxis.set_major_formatter(FormatStrFormatter(r''))
inset.xaxis.set_major_locator(MultipleLocator(0.25))

inset.xaxis.set_minor_formatter(FormatStrFormatter(''))
inset.xaxis.set_minor_locator(MultipleLocator(0.125))

setp(inset.get_xticklabels(), rotation='horizontal', fontsize=pitlfs)
setp(inset.get_yticklabels(), rotation='horizontal', fontsize=pitlfs)

ax.set_xlim(0.0, 0.5)
#ax.set_ylim(0.0, 0.2)

inset.set_xlim(0.0, 0.5)
inset.set_ylim(0.001, 1.0)
inset.set_yscale("log")

handles, labels = ax.get_legend_handles_labels()
l = ax.legend(handles, labels, loc='upper left', title=r"")

write_to_file("electroosmotic-flow-2d")

exit()

