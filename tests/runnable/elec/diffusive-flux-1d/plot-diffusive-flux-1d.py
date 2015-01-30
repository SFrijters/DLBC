#!/usr/bin/env python

#### START HEADER
from mplhelper import *
#### END HEADER

L = 20.0
lambda_B = 0.4

def rho(x, K):
    return 1.0 / ((cos(K*(x-0.5*L)))**2)

def plot_dataset(globstr, sigma, K, sv, np, i, j):

    x = []
    rho_p = []
    rho_m = []

    g = sorted(glob.glob(globstr))
    if ( len(g) != 1): return
    f = h5py.File(g[0], 'r')
    rho_m = f["/OutArray"]
    x = irange(1,22, 1)

    # Scale x-axis
    xs = [ (e-1.5) / L for e in list(x) ]
    x = [ (e-1.5) for e in list(x) ]

    # Scale y-axis
    rho0 = ( K * K ) / ( 2.0 * math.pi * lambda_B )
    rho_m = [ e / rho0 for e in list(rho_m) ]
    rho_th = [ rho(e, K) for e in list(x) ]
    rho_rel = [ abs(e / f - 1.0) for e, f in zip(rho_m,rho_th )]

    if ( j == 0 ):
        lbl = "$\sigma$ = " + str(sigma)
    else:
        lbl = r""
    p, = ax.plot(xs, rho_m, marker=pm(j), markeredgecolor=pc(i), mfc="None", label=lbl, color=pc(i))
    #p.set_dashes(pd(0))
    p, = inset.plot(xs, rho_rel, marker=pm(j), markeredgecolor=pc(i), mfc="None", label=lbl, color=pc(i), ms=pims)
    #p.set_dashes(pd(0))

    # Theoretical curve
    zx = arange(0,L,0.1)
    # print zx
    zy = [ rho(e, K) for e in list(zx) ]
    # print zy
    zx = [ e / L for e in list(zx) ]
    # print zx
    p, = ax.plot(zx, zy, ls="None", marker="None", c=pc(i))
    p.set_dashes([4,4])

fig, ax = plt.subplots()

inset = axes([.65, .4, .3, .3])

plot_dataset(os.path.join(options.relpath,"sigma0.003125-np1-SOR/elChargeN-diffusive-flux-1D-*-t00000000.h5"), 0.003125, 0.02766, "sor", 1, 0, 0)
plot_dataset(os.path.join(options.relpath,"sigma0.003125-np2-SOR/elChargeN-diffusive-flux-1D-*-t00000000.h5"), 0.003125, 0.02766, "sor", 2, 0, 1)

plot_dataset(os.path.join(options.relpath,"sigma0.03125-np1-SOR/elChargeN-diffusive-flux-1D-*-t00000000.h5"), 0.03125, 0.07854, "sor", 1, 1, 0)
plot_dataset(os.path.join(options.relpath,"sigma0.03125-np2-SOR/elChargeN-diffusive-flux-1D-*-t00000000.h5"), 0.03125, 0.07854, "sor", 2, 1, 1)

plot_dataset(os.path.join(options.relpath,"sigma0.3125-np1-SOR/elChargeN-diffusive-flux-1D-*-t00000000.h5"), 0.3125, 0.1395, "sor", 1, 2, 0)
plot_dataset(os.path.join(options.relpath,"sigma0.3125-np2-SOR/elChargeN-diffusive-flux-1D-*-t00000000.h5"), 0.3125, 0.1395, "sor", 2, 2, 1)

# Styles
ax.set_xlabel(r"$x/L$")
ax.set_ylabel(r"$\rho / \rho_0$")

ax.xaxis.set_major_formatter(FormatStrFormatter(r'%.2f'))
ax.yaxis.set_major_formatter(FormatStrFormatter(r'%d'))
ax.xaxis.set_major_locator(MultipleLocator(0.25))
ax.yaxis.set_major_locator(MultipleLocator(2))

ax.xaxis.set_minor_formatter(FormatStrFormatter(''))
ax.yaxis.set_minor_formatter(FormatStrFormatter(''))
ax.xaxis.set_minor_locator(MultipleLocator(0.125))
ax.yaxis.set_minor_locator(MultipleLocator(1))

inset.set_ylabel(r"$\rho_{\mathrm{err}}$", fontsize=pialfs)

inset.xaxis.set_major_formatter(FormatStrFormatter(r''))
inset.xaxis.set_major_locator(MultipleLocator(0.25))

inset.xaxis.set_minor_formatter(FormatStrFormatter(''))
inset.xaxis.set_minor_locator(MultipleLocator(0.125))

setp(inset.get_xticklabels(), rotation='horizontal', fontsize=pitlfs)
setp(inset.get_yticklabels(), rotation='horizontal', fontsize=pitlfs)

ax.set_xlim(0.0, 0.5)
ax.set_ylim(0.0, 12.0)
inset.set_xlim(0.0, 0.5)
inset.set_ylim(0.0001, 0.1)
inset.set_yscale("log")

handles, labels = ax.get_legend_handles_labels()
l = ax.legend(handles, labels, loc='upper right', title=r"")

write_to_file("diffusive-flux-1d")

exit()

