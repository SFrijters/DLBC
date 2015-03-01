#!/usr/bin/env python

#### START HEADER
from mplhelper import *
#### END HEADER

rcParams['figure.subplot.top'] = 0.93
rcParams['figure.subplot.right'] = 0.93

# Both codes
DTherm = 0.01
deltaDTherm = 0.0025
DPlus = DTherm + deltaDTherm
DMinus = DTherm - deltaDTherm
rho0 = 0.01
deltarho0 = 0.0001
L = 128.0
e = 1.0

print "DTherm = " + str(DTherm)
print "deltaDTherm = " + str(deltaDTherm)
print "DPlus = " + str(DPlus)
print "DMinus = " + str(DMinus)
print "rho0 = " + str(rho0)
print "deltarho0 = " + str(deltarho0)
print "L = " + str(L)
print "e = " + str(e)

# Stuff
eps = 3.3e3
debye_length = 1.0/0.4264
bjerrum_length = 0.7235
beta = (4.0 * math.pi * eps * bjerrum_length ) / ( e**2 )
betaInv = 1.0 / beta

print "epsilon = " + str(eps)
print "betaInv = " + str(betaInv)
print "beta = " + str(beta)
print "bjerrum_length = " + str(bjerrum_length)
print "debye_length = " + str(debye_length)

# Derived quantities
DeltaPsiP = ( ( DPlus - DMinus ) * 2.0 * deltarho0 ) / ( beta * e * ( DPlus + DMinus ) * rho0 )
tau_e = eps / ( beta * e * e * ( DPlus + DMinus ) * rho0 )
tau_d = L * L / ( 2.0 * math.pi * math.pi * ( DPlus + DMinus) )

print "DeltaPsiP = " + str(DeltaPsiP)
print "tau_e = " + str(tau_e)
print "tau_d = " + str(tau_d)

def DeltaPsi(t):
    summation = 0.0
    n = int(round(L / ( math.pi * debye_length) ))
    n *= 100
    for k in range(1,n):
        k = float(k)
        summation += math.sin(k * math.pi / 2.0)**3 * exp(-k*k*t/tau_d) / k

    x = DeltaPsiP * ( 1.0 - exp(-t/tau_e)) * ( 4.0 / math.pi ) * summation
    return x

tx_sor = []
ty_sor = []
tx_p3m = []
ty_p3m = []
tx_theor = []
dpsi_theor = []

L = 128.0

def add_dataset(globstr, t):
    g = sorted(glob.glob(globstr))
    if ( len(g) != 1 ) : return
    f = h5py.File(g[0], 'r')
    phi = f["/OutArray"][:]

    tx_sor.append(t)
    ty_sor.append((max(phi)-min(phi)))
    dpsi_theor.append(DeltaPsi(t))
    tx_theor.append(t)

stride = 100
for t in irange(0,10000,stride):
    add_dataset(os.path.join(options.relpath, "elPot*-t%08d.h5" % t), t)

stride = 1000
for t in irange(11000,100000,stride):
    add_dataset(os.path.join(options.relpath, "elPot*-t%08d.h5" % t), t)


if (len(tx_theor) == 0):
    print("Run extended simulation first to obtain the necessary data by using 'make extended-plot' in the simulation directory.")
    exit(-1)

fig, ax = plt.subplots()

tx3_p3m = [ e / 1000.0 for e in tx_p3m ]
tx3_sor = [ e / 1000.0 for e in tx_sor ]
tx3_theor = [ e / 1000.0 for e in tx_theor ]

lbl = "$\Delta \phi_{\mathrm{sor}}$"
p, = ax.plot(tx3_sor, ty_sor, marker="None", markeredgecolor=pc(0), mfc="None", label=lbl, color=pc(0))
p.set_dashes(pd(1))

# lbl = "$\Delta \phi_{\mathrm{p3m}}$"
# p, = ax.plot(tx3_p3m, ty_p3m, marker="None", markeredgecolor=pc(1), mfc="None", label=lbl, color=pc(1))
# p.set_dashes(pd(2))

lbl = "$\Delta \phi_{\mathrm{theor}}$"
p, = ax.plot(tx3_theor, dpsi_theor, marker="None", markeredgecolor='k', mfc="None", label=lbl, color='k')
p.set_dashes(pd(0))

lbl = "$\Delta \phi_s$"
p, = ax.plot(tx3_theor, [ DeltaPsiP for e in tx3_theor ], marker="None", markeredgecolor=pc(2), mfc="None", label=lbl, color='k')
p.set_dashes(pd(3))

ax.set_xlabel(r"$t (\times 1000)$")
ax.set_ylabel(r"$\Delta \phi$")

ax.set_xlim(0,100)

handles, labels = ax.get_legend_handles_labels()
l = legend(handles, labels, loc='lower left', title=r"")

inset = axes([.6, .5, .3, .3])
p, = inset.plot(tx3_sor, ty_sor, marker="None", markeredgecolor=pc(0), mfc="None", label=lbl, color=pc(0))
p.set_dashes(pd(1))
# p, = inset.plot(tx3_p3m, ty_p3m, marker="None", markeredgecolor=pc(1), mfc="None", label=lbl, color=pc(1))
# p.set_dashes(pd(2))
p, = inset.plot(tx3_theor, dpsi_theor, marker="None", markeredgecolor='k', mfc="None", label=lbl, color='k')
p.set_dashes(pd(0))
p, = inset.plot(tx3_theor, [ DeltaPsiP for e in tx3_theor ], marker="None", markeredgecolor=pc(2), mfc="None", label=lbl, color='k')
p.set_dashes(pd(3))

inset.set_xlim(0,10)
inset.set_ylim(0,2e-7)

setp(inset.get_xticklabels(), rotation='horizontal', fontsize=pitlfs)
setp(inset.get_yticklabels(), rotation='horizontal', fontsize=pitlfs)

write_to_file("liquidjunction-1d")

exit()

