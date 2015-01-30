#!/usr/bin/env python

#### START HEADER
from mplhelper import *
#### END HEADER

import h5py

# Read data

def plot_dataset(globstr):

    g = glob.glob(globstr)
    f = h5py.File(g[0],'r')
    dset = f['OutArray']
    phi = dset[:,0,0]
    x = range(1,61,1)

    phi0 = phi[0]
    # Scale y-axis
    phi = [ e - phi0 for e in list(phi) ]

    lbl = r"$\Delta \phi_{\mathrm{sim}}$"
    i = 0
    p, = ax.plot(x, phi, marker="None", markeredgecolor=pc(i), mfc="None", label=lbl, color=pc(i))
    p.set_dashes(pd(0))

    # Theoretical curve
    # zx = arange(0,L,0.1)
    # # print zx
    # zy = [ 1.0 / ((cos(K*(e-0.5*L)))**2) for e in list(zx) ]
    # # print zy
    # zx = [ e / L for e in list(zx) ]
    # # print zx
    # p, = ax.plot(zx, zy, ls="None", marker="None", c=tc(i))
    # p.set_dashes([4,4])
    # return Ez

fig, ax = plt.subplots()

plot_dataset(os.path.join(options.relpath,"elPot*h5"))

e1 = 1.0
e2 = 2.0

phi_th = 15.0/e1 + 1.0/((e1 + e2)/2.0) + 15.0/e2

# Styles
ax.set_xlabel(r"$z$")
ax.set_ylabel(r"$\Delta \phi$")

p = plt.axvspan(0, 30, facecolor='0.95')
p = plt.axvspan(30, 60, facecolor='0.85')

k = plt.axvline(x=15.0,color="k",lw=plw,ls="-")
k = plt.axvline(x=46.0,color="k",lw=plw,ls="-")

bbox_props = dict(boxstyle="round", fc="w", ec='k')
ax.annotate(r"$\epsilon_1 = 1.0$", xy=(15, 17), xycoords='data', ha='center', va='baseline',fontsize=palfs,bbox=bbox_props)
ax.annotate(r"$\epsilon_2 = 2.0$", xy=(46, 17), xycoords='data', ha='center', va='baseline',fontsize=palfs,bbox=bbox_props)

ax.annotate(r"$\sigma_- = -\sigma = -1.0$", xy=(13.5, 13), xycoords='data', ha='center', va='baseline',fontsize=palfs,rotation=90)
ax.annotate(r"$\sigma_+ = \sigma = 1.0$", xy=(47.5, 13), xycoords='data', ha='center', va='baseline',fontsize=palfs,rotation=90)

lbl = r"$\Delta \phi_{\mathrm{max, theor}}$"
p, = ax.plot([0,60], [phi_th, phi_th], marker="None", label=lbl, color='k')
p.set_dashes(pd(2))

xmax = 60
ymax = 25

ax.set_xlim(0,xmax)
ymin = get_ymin(ymax)
ax.set_ylim(ymin,ymax)

handles, labels = ax.get_legend_handles_labels()
l = legend(handles, labels, loc='lower right', title=r"", frameon=True)

write_to_file("dielectric-capacitor-3d")

exit()

