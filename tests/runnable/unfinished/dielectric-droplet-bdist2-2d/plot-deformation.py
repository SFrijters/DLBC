#!/usr/bin/env python

#### START HEADER
from mpltuehelper import *
#### END HEADER

R = 15.6752971034
sigma = 0.0478287440648

R = 15.5126750356
sigma = 0.0546486764016

def calc_deformation(denzip):
    cutoff = 0.35
    Ry = 0.0
    Rz = 0.0
    M = 0.0

    for e in denzip:
	if ( e[0] > cutoff):
	  M  += e[0]
	  Ry += e[0]*e[1]
	  Rz += e[0]*e[2]

    Ry /= M
    Rz /= M;
    # print Ry, Rz

    # Use CoM as offset

    dy = Ry
    dz = Rz

    Iyy = 0.0
    Iyz = 0.0
    Izz = 0.0

    for e in denzip:
        y = e[1] - dy
        z = e[2] - dz
	if ( e[0] > cutoff):
            Iyy += e[0]*(z*z)
            Iyz += e[0]*(y*z)
            Izz += e[0]*(y*y)

    import scipy.linalg

    # print Iyy, Izz

    lb = scipy.linalg.eigvals([ [Iyy, Iyz ], [Iyz, Izz] ] )
    l = real(sqrt(5.0*max(lb) / M))
    b = real(sqrt(5.0*min(lb) / M))
    D = (( l - b ) / ( l + b ))
    print "D = " + str(D), l, b
    return D, l ,b

def plot_dataset(dirstr,globstr, delta_phi):
    x = []
    y = []
    z = []
    rho_p = []
    rho_m = []
    phi = []
    eps = []
    Ez = []
    g = sorted(glob.glob(dirstr+"elec_*"+globstr+"*asc"))
    # print g
    if (len(g) == 0): return 0,0
    print "Adding dataset" + str(g)
    for f in g:
        # print f
        cols = make_column_list(f, ["x", "y", "z", "rho_p", "rho_m", "phi", "eps", "Ez" ])
        x1, y1, z1, rho_p1, rho_m1, phi1, eps1, Ez1 = loadtxt(f, unpack=True, usecols=cols)
        x.extend(x1)
        y.extend(y1)
        z.extend(z1)
        rho_p.extend(rho_p1)
        rho_m.extend(rho_m1)
        phi.extend(phi1)
        eps.extend(eps1)
        Ez.extend(Ez1)

    # Sort data
    zipped = zip(x, y, z, rho_p, rho_m, phi, eps, Ez)
    # Take only single profile / cut off walls
    zipped = filter(lambda e: (e[0] == 1),zipped)
    # Sort in x-direction
    zipped.sort(key = lambda t: t[2])
    x, y, z, rho_p, rho_m, phi, eps, Ez = zip(*zipped)

    y = [ e - 1 for e in list(y) ]
    z = [ e - 1 for e in list(z) ]

    phi0 = phi[0]
    # Scale y-axis
#    phi = [ e - phi0 for e in list(phi) ]

#     import numpy as np
#     import matplotlib.pyplot as plt
#     import scipy.interpolate

#     # Set up a regular grid of interpolation points
#     print "Set up grid"
#     yi, zi = np.linspace(min(y), max(y), 100), np.linspace(min(z), max(z), 100)
#     yi, zi = np.meshgrid(yi, zi)

#     # Interpolate
#     print "Interpolate"
#     # rbf = scipy.interpolate.Rbf(y, z, phi, function='linear')
#     # phii = rbf(yi, zi)

#     phii = scipy.interpolate.griddata((y, z), phi, (yi, zi), method='linear')

# #     print "imshow"
#     plt.imshow(phii, vmin=min(phi), vmax=max(phi), origin='lower',
#                extent=[min(y), max(y), min(z), max(z)])
#     print "scatter"
# #    plt.scatter(y, z, c=phi)
#     plt.colorbar()
#    plt.show()

    # CS = plt.contour(yi,zi,phii,50)
    # plt.clabel(CS, inline=1, fontsize=10)

    # # lbl = r"$\Delta \phi_{\mathrm{sim}}$"
    # # i = 0
    # # p, = ax.contour(y,z,phi)

    import h5py

    g = sorted(glob.glob(dirstr+"od_*"+globstr+"*h5"))
    f = h5py.File(g[0],'r')
    dset = f['OutArray']
    a = dset[:,:,1]
    #a = -a
    # density = plt.imshow(a)
    # density.set_cmap('gray')

    #print a
    #print y
    #print z

    # print "imshow"
    # plt.imshow(phii, vmin=min(phi), vmax=max(phi), origin='lower',
    #            extent=[min(y), max(y), min(z), max(z)])
    # print "scatter"
    # plt.scatter(y, z, c=phi)
    # plt.colorbar()
    # plt.show()

    # Set up a regular grid of interpolation points
    # print "Set up grid"
    yi, zi = np.linspace(1,50,100), np.linspace(1, 50, 100)
    yi, zi = np.meshgrid(yi, zi)

    den = [item for sublist in a for item in sublist]

    ymin = 50
    ymax = 0
    zmin = 50
    zmax = 0

    denzip = zip(den,y,z)

    for e in denzip:
        if ( e[0] > 0.1 ):
            ymin = min(ymin, e[1])
            zmin = min(zmin, e[2])
            ymax = max(ymax, e[1])
            zmax = max(zmax, e[2])

    print ymin, ymax, zmin, zmax
    b = ymax - ymin
    l = zmax - zmin
    D = (l - b)/(l + b)
    print D

    D, l, b = calc_deformation(denzip)

    #print len(y), len(z), len(yi), len(zi), len(den)

    # # Interpolate
    # print "Interpolate"
    # den = scipy.interpolate.griddata((y, z), den, (yi, zi), method='linear')

    # CS = plt.contour(yi,zi,den,[ 0.0 ],colors='k')
    # plt.clabel(CS, inline=1, fontsize=10)

    #R = l

    L = 64.0
    E0  = delta_phi / L

    x = []
    y = []
    z = []
    rho_p = []
    rho_m = []
    phi = []
    eps = []
    Ez = []

    g = sorted(glob.glob(dirstr+"elec_*"+globstr+"*asc"))
    for f in g:
        # print f
        cols = make_column_list(f, ["x", "y", "z", "rho_p", "rho_m", "phi", "eps", "Ez" ])
        x1, y1, z1, rho_p1, rho_m1, phi1, eps1, Ez1 = loadtxt(f, unpack=True, usecols=cols)
        x.extend(x1)
        y.extend(y1)
        z.extend(z1)
        rho_p.extend(rho_p1)
        rho_m.extend(rho_m1)
        phi.extend(phi1)
        eps.extend(eps1)
        Ez.extend(Ez1)

    # Sort data
    zipped = zip(x, y, z, rho_p, rho_m, phi, eps, Ez)
    # Take only single profile / cut off walls
    zipped = filter(lambda e: (e[0] == 1 and e[1] == int(L/2)),zipped)
    # Sort in x-direction
    zipped.sort(key = lambda t: t[2])
    x, y, z, rho_p, rho_m, phi, eps, Ez = zip(*zipped)

    ew = eps[0]
    eo = eps[int(L/2)]

    print ew, eo

    gamma = (ew - eo)/(ew + eo)

    print gamma

 #   eps_bar = 1.0/(1.6*math.pi)

    eps_bar = ( ew + eo ) / 2.0

    D_theor = 0.25 * gamma * gamma * ( 1.0 + gamma ) * ( eps_bar * E0 * E0 * R / sigma )
    print "DATA eps_bar = %f, gamma = %f, E0 = %f, D = %f, D_theor = %f, D/D_theor = %f" % (eps_bar, gamma, E0, D, D_theor, D/D_theor)

    norm = ( eps_bar * E0 * E0 * R / sigma )
    print "Norm = %e" % norm

    D_norm = D / norm

    return D_norm, gamma

fig, ax = plt.subplots()

# Theoretical curve
scale = 1000.0
ff = 0.1
gamma_t = arange(0,1,0.01)
D_norm_t = [ scale*ff*0.25*(e*e)*(e + 1.0) for e in list(gamma_t) ]
p, = ax.plot(gamma_t, D_norm_t, ls="None", marker="None", c='k',label=r"$%.3f \times 0.25 \gamma^2 ( 1 + \gamma )$" % ff)
p.set_dashes([4,4])

gamma_t = arange(0,1,0.01)
globstr = "t00001100-??????????"

for i,dropz in enumerate([ "1.0", "2.0", "5.0", "10.0" ]):
    D_norm_a = []
    gamma_a = []
    for eps_b in [ "0.378" ]:
        for eps_r in [ "0.24", "0.30", "0.31", "0.32", "0.33", "0.34", "0.35","0.36", "0.37" ]:
            D_norm, gamma = plot_dataset("output/droplet-eps_r%s-eps_b%s-phi_dropz%s/" % (eps_r, eps_b, dropz), globstr, float(dropz))
            D_norm_a.append(D_norm)
            gamma_a.append(gamma)
    lbl = r"$\Delta \phi = %s$" % dropz
    p, = ax.plot(gamma_a, [ scale * e for e in D_norm_a], ls="None", marker=tm(i), mec=tc(i), c=tc(i),label=lbl)    

# Styles
ax.set_xlabel(r"$\gamma$",fontsize=talfs, family=tff)
ax.set_ylabel(r"$D / (\overline{\epsilon} E^2 R_d / \sigma ) \times 10^{-3}$",fontsize=talfs, family=tff)

# ax.xaxis.set_major_formatter(FormatStrFormatter(r'%.2f'))
# ax.yaxis.set_major_formatter(FormatStrFormatter(r'%d'))
# ax.xaxis.set_major_locator(MultipleLocator(0.25))
# ax.yaxis.set_major_locator(MultipleLocator(2))

# ax.xaxis.set_minor_formatter(FormatStrFormatter(''))
# ax.yaxis.set_minor_formatter(FormatStrFormatter(''))
# ax.xaxis.set_minor_locator(MultipleLocator(0.125))
# ax.yaxis.set_minor_locator(MultipleLocator(1))

ax.set_xlim(0.0, 0.12)
ax.set_ylim(0.0, 0.0005 * scale)

handles, labels = ax.get_legend_handles_labels()
l = legend(handles, labels, loc='upper left')

write_to_file("test-droplet-zoom")

fig, ax = plt.subplots()

# Theoretical curve
ff = 0.1
gamma_t = arange(0,1,0.01)
D_norm_t = [ ff*0.25*(e*e)*(e + 1.0) for e in list(gamma_t) ]
p, = ax.plot(gamma_t, D_norm_t, ls="None", marker="None", c='k',label=r"$%.3f \times 0.25 \gamma^2 ( 1 + \gamma )$" % ff)
p.set_dashes([4,4])

gamma_t = arange(0,1,0.01)
globstr = "t00001100-??????????"

for i,dropz in enumerate([ "1.0", "2.0", "5.0", "10.0" ]):
    D_norm_a = []
    gamma_a = []
    for eps_b in [ "0.378" ]:
        for eps_r in [ "0.0199", "0.04", "0.08", "0.12", "0.18", "0.24", "0.30", "0.31", "0.32", "0.33", "0.34", "0.35","0.36", "0.37" ]:
            D_norm, gamma = plot_dataset("output/droplet-eps_r%s-eps_b%s-phi_dropz%s/" % (eps_r, eps_b, dropz), globstr, float(dropz))
            D_norm_a.append(D_norm)
            gamma_a.append(gamma)
    lbl = r"$\Delta \phi = %s$" % dropz
    p, = ax.plot(gamma_a, D_norm_a, ls="None", marker=tm(i), mec=tc(i), c=tc(i),label=lbl)    

# Styles
ax.set_xlabel(r"$\gamma$",fontsize=talfs, family=tff)
ax.set_ylabel(r"$D / (\overline{\epsilon} E^2 R_d / \sigma )$",fontsize=talfs, family=tff)

# ax.xaxis.set_major_formatter(FormatStrFormatter(r'%.2f'))
# ax.yaxis.set_major_formatter(FormatStrFormatter(r'%d'))
# ax.xaxis.set_major_locator(MultipleLocator(0.25))
# ax.yaxis.set_major_locator(MultipleLocator(2))

# ax.xaxis.set_minor_formatter(FormatStrFormatter(''))
# ax.yaxis.set_minor_formatter(FormatStrFormatter(''))
# ax.xaxis.set_minor_locator(MultipleLocator(0.125))
# ax.yaxis.set_minor_locator(MultipleLocator(1))

ax.set_xlim(0.0, 1.0)
ax.set_ylim(0.0, 0.04)

handles, labels = ax.get_legend_handles_labels()
l = legend(handles, labels, loc='upper left')

write_to_file("test-droplet")

exit()

