#!/usr/bin/env python

#### START HEADER
from mplhelper import *
#### END HEADER

# Read data

def calc_deformation(denzip):
    print "Calculating deformation..."
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

    print "Ry = %f" % Ry
    print "Rz = %f" % Rz

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

    print "Iyy = %f" % Iyy
    print "Izz = %f" % Izz

    lb = scipy.linalg.eigvals([ [Iyy, Iyz ], [Iyz, Izz] ] )
    print lb
    l = real(sqrt(5.0*max(lb) / M))
    b = real(sqrt(5.0*min(lb) / M))
    print "l = %f, b = %f" % (l, b)
    D = (( l - b ) / ( l + b ))
    print "D = %f" % D
    return D, l ,b

def plot_dataset(dirstr,globstr):

#    L = 20.0
#    lambda_B = 0.4 

#     x = []
#     y = []
#     z = []
#     rho_p = []
#     rho_m = []
#     phi = []
#     eps = []
#     Ez = []

#     g = sorted(glob.glob(dirstr+"elec_*"+globstr+"*asc"))
#     print "globbing '%s'" % g
#     for f in g:
#         #print f
#         cols = make_column_list(f, ["x", "y", "z", "rho_p", "rho_m", "phi", "eps", "Ez" ])
#         x1, y1, z1, rho_p1, rho_m1, phi1, eps1, Ez1 = loadtxt(f, unpack=True, usecols=cols)
#         x.extend(x1)
#         y.extend(y1)
#         z.extend(z1)
#         rho_p.extend(rho_p1)
#         rho_m.extend(rho_m1)
#         phi.extend(phi1)
#         eps.extend(eps1)
#         Ez.extend(Ez1)

#     # Sort data
#     zipped = zip(x, y, z, rho_p, rho_m, phi, eps, Ez)
#     # Take only single profile / cut off walls
#     zipped = filter(lambda e: (e[0] == 1),zipped)
#     # Sort in x-direction
#     zipped.sort(key = lambda t: t[2])
#     x, y, z, rho_p, rho_m, phi, eps, Ez = zip(*zipped)

#     y = [ e - 1 for e in list(y) ]
#     z = [ e - 1 for e in list(z) ]

#     phi0 = phi[0]
#     # Scale y-axis
# #    phi = [ e - phi0 for e in list(phi) ]

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
# #     plt.imshow(phii, vmin=min(phi), vmax=max(phi), origin='lower',
# #                extent=[min(y), max(y), min(z), max(z)])
# #     print "scatter"
# # #    plt.scatter(y, z, c=phi)
# #     plt.colorbar()
# #    plt.show()

#     CS = plt.contour(yi,zi,phii,50)
#     plt.clabel(CS, inline=1, fontsize=10)

    # lbl = r"$\Delta \phi_{\mathrm{sim}}$"
    # i = 0
    # p, = ax.contour(y,z,phi)

    import h5py

    g = sorted(glob.glob(dirstr+"colour-red-blue-*"+globstr+"*h5"))
    f = h5py.File(g[0],'r')
    dset = f['OutArray']
    a = dset[:,:]
    #a = -a
    density = plt.imshow(a)
    density.set_cmap('gray')

    #print a
    #print y
    #print z

    # print "imshow"
    # plt.imshow(phii, vmin=min(phi), vmax=max(phi), origin='lower',
    #            extent=[min(y), max(y), min(z), max(z)])
    # print "scatter"
    # plt.scatter(y, z, c=phi)
    plt.colorbar()
    plt.show()

#     # Set up a regular grid of interpolation points
#     print "Set up grid"
#     yi, zi = np.linspace(1,50,100), np.linspace(1, 50, 100)
#     yi, zi = np.meshgrid(yi, zi)

#     den = [item for sublist in a for item in sublist]

#     ymin = 50
#     ymax = 0
#     zmin = 50
#     zmax = 0

#     denzip = zip(den,y,z)

# #    print denzip

#     for e in denzip:
#         if ( e[0] > 0.1 ):
#             ymin = min(ymin, e[1])
#             zmin = min(zmin, e[2])
#             ymax = max(ymax, e[1])
#             zmax = max(zmax, e[2])

#     print "ymin = %f, ymax = %f, zmin = %f, zmax = %f" % (ymin, ymax, zmin, zmax)
#     b = ymax - ymin
#     l = zmax - zmin
#     D = (l - b)/(l + b)
#     print "D = %f" % D

#     print "len(eps) = %d" % len(eps)

#     D, l, b = calc_deformation(denzip)

#     #print len(y), len(z), len(yi), len(zi), len(den)

#     # Interpolate
#     print "Interpolate"
#     den = scipy.interpolate.griddata((y, z), den, (yi, zi), method='linear')

#     CS = plt.contour(yi,zi,den,[ 0.0 ],colors='k')
#     plt.clabel(CS, inline=1, fontsize=10)

#     R = l

#     L = 64.0
#     delta_phi = 10.0
#     E0  = delta_phi / L

#     x = []
#     y = []
#     z = []
#     rho_p = []
#     rho_m = []
#     phi = []
#     eps = []
#     Ez = []

#     g = sorted(glob.glob(dirstr+"elec_*"+globstr+"*asc"))
#     for f in g:
#         #print f
#         cols = make_column_list(f, ["x", "y", "z", "rho_p", "rho_m", "phi", "eps", "Ez" ])
#         x1, y1, z1, rho_p1, rho_m1, phi1, eps1, Ez1 = loadtxt(f, unpack=True, usecols=cols)
#         x.extend(x1)
#         y.extend(y1)
#         z.extend(z1)
#         rho_p.extend(rho_p1)
#         rho_m.extend(rho_m1)
#         phi.extend(phi1)
#         eps.extend(eps1)
#         Ez.extend(Ez1)

#     # Sort data
#     zipped = zip(x, y, z, rho_p, rho_m, phi, eps, Ez)
#     # Take only single profile / cut off walls
#     zipped = filter(lambda e: (e[0] == 1 and e[1] == int(L/2)),zipped)
#     # Sort in x-direction
#     zipped.sort(key = lambda t: t[2])
#     x, y, z, rho_p, rho_m, phi, eps, Ez = zip(*zipped)

#     ew = eps[0]
#     eo = eps[int(L/2)]

#     print "ew = %f, eo = %f" % (ew, eo)

#     gamma = (ew - eo)/(ew + eo)

#     print "gamma = %f" % gamma

#  #   eps_bar = 1.0/(1.6*math.pi)

#     eps_bar = ( ew + eo ) / 2.0

#     R = 15.5126750356
#     sigma = 0.0562049362915

#     D_theor = 0.25 * gamma * gamma * ( 1 + gamma ) * ( eps_bar * E0 * E0 * R / sigma )
#     print "D_theor = %f" % D_theor

    return D, R
#     # # Theoretical curve
#     # zx = arange(0,L,0.1)
#     # # print zx
#     # zy = [ 1.0 / ((cos(K*(e-0.5*L)))**2) for e in list(zx) ]
#     # # print zy
#     # zx = [ e / L for e in list(zx) ]
#     # # print zx
#     # p, = ax.plot(zx, zy, ls="None", marker="None", c=tc(i))
#     # p.set_dashes([4,4])
#     # return Ez

def plot_E(dirstr,globstr,D,R):

    L = 64.0
    delta_phi = 1.0
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
        #print f
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

    # y = [ e - 1 for e in list(y) ]
    # z = [ e - 1 for e in list(z) ]

#    print eps

    ew = eps[0]
    eo = eps[int(L/2)]

 #   print ew, eo

    gamma = (ew - eo)/(ew + eo)

  #  print gamma

 #   eps_bar = 1.0/(1.6*math.pi)

    eps_bar = ( ew + eo ) / 2.0
    
    # R = R * 0.5
    # sigma = 0.0143
    # D /= ( eps_bar * E * E * R / sigma )
    # print eps_bar, L, E, R, sigma, D

    print "L = %f, E0 = %f, R = %f" % (L, E0, R)

    lbl = r"$E_{\mathrm{sim}}$"
    p, = ax.plot(z,Ez, marker="None", label=lbl, color=tuered2)
    p.set_dashes(td(0))

    def E(r):
        rad = abs(r - ( L/2 - 0.5)) 
        if ( rad > R ):
            return E0 * ( 1 - gamma * R *R / (rad * rad ) )
        return E0 * (1 + gamma)

    zi = np.linspace(min(z), max(z), 200)
    E_theor = [ E(e) for e in z ]

    lbl = r"$E_{\mathrm{theor}}$"
    p, = ax.plot(z,E_theor, marker="None", label=lbl, color='k')
    p.set_dashes(td(2))

    lbl = r"$\epsilon$"
    p, = ax.plot(z,[ e/100.0 for e in eps], marker="None", label=lbl, color=tueblue2,lw=1.0)
    p.set_dashes(td(0))

    print "sum(E_theor) = %f" % sum(E_theor)
    print "sum(Ez) = %f" % sum(Ez)

    import h5py

    g = sorted(glob.glob(dirstr+"od_*"+globstr+"*h5"))
    f = h5py.File(g[0],'r')
    dset = f['OutArray']
    a = 0.5*dset[:,50,0]

    lbl = r"$\rho_r / 2$"
    p, = ax.plot(z,a, marker="None", label=lbl, color=tuegreen2,lw=1.0)
    p.set_dashes(td(0))



fig, ax = plt.subplots()

globstr = "t00002600"

#D, R = plot_dataset("../../output/",globstr)

import h5py

g = sorted(glob.glob("../../output/colour-red-blue-*"+globstr+"*h5"))
f = h5py.File(g[],'r')
dset = f['OutArray']
a = dset[:,:]

g = sorted(glob.glob("../../output/colour-red-blue-*t00002000*h5"))
f = h5py.File(g[0],'r')
dset = f['OutArray']
ref = dset[:,:]

#a = -a

diff = a - ref

density = plt.imshow(diff)
density.set_cmap('gray')

plt.colorbar()
plt.show()

#Ez = plot_dataset("output/elec_*t00000100*asc")

# e1 = 1.0
# e2 = 2.0

# phi_th = 15.0/e1 + 1.0/((e1 + e2)/2.0) + 15.0/e2

# # Styles
# ax.set_xlabel(r"$z$",fontsize=talfs, family=tff)
# ax.set_ylabel(r"$\Delta \phi$",fontsize=talfs, family=tff)

# p = plt.axvspan(0, 30, facecolor='0.95')
# p = plt.axvspan(30, 60, facecolor='0.85')

# k = plt.axvline(x=15.0,color="k",lw=tlw,ls="-")
# k = plt.axvline(x=46.0,color="k",lw=tlw,ls="-")

# bbox_props = dict(boxstyle="round", fc="w", ec='k')
# ax.annotate(r"$\epsilon_1 = 1.0$", xy=(15, 17),  xycoords='data', ha='center', va='baseline',fontsize=talfs,bbox=bbox_props)
# ax.annotate(r"$\epsilon_2 = 2.0$", xy=(46, 17),  xycoords='data', ha='center', va='baseline',fontsize=talfs,bbox=bbox_props)

# ax.annotate(r"$\sigma_- = -\sigma = -1.0$", xy=(13.5, 13),  xycoords='data', ha='center', va='baseline',fontsize=talfs,rotation=90)
# ax.annotate(r"$\sigma_+ = \sigma = 1.0$", xy=(47.5, 13),  xycoords='data', ha='center', va='baseline',fontsize=talfs,rotation=90)


# ax.annotate(r"$E_z = 0$", xy=(7.5, 0.3),  xycoords='data', ha='center', va='baseline',fontsize=talfs)
# ax.annotate(r"$E_z = %.2f$" % Ez[20], xy=(22.5, 11),  xycoords='data', ha='center', va='baseline',rotation=60,fontsize=talfs)
# ax.annotate(r"$E_z = %.2f$" % Ez[40], xy=(37.5, 21.3),  xycoords='data', ha='center', va='baseline',rotation=43,fontsize=talfs)
# ax.annotate(r"$E_z = 0$", xy=(52.5, 23.4),  xycoords='data', ha='center', va='baseline',fontsize=talfs)

# lbl = r"$\Delta \phi_{\mathrm{max, theor}}$"
# p, = ax.plot([0,60], [phi_th, phi_th], marker="None", label=lbl, color='k')
# p.set_dashes(td(2))

# # ax.xaxis.set_major_formatter(FormatStrFormatter(r'%.2f'))
# # ax.yaxis.set_major_formatter(FormatStrFormatter(r'%d'))
# # ax.xaxis.set_major_locator(MultipleLocator(0.25))
# # ax.yaxis.set_major_locator(MultipleLocator(2))

# # ax.xaxis.set_minor_formatter(FormatStrFormatter(''))
# # ax.yaxis.set_minor_formatter(FormatStrFormatter(''))
# # ax.xaxis.set_minor_locator(MultipleLocator(0.125))
# # ax.yaxis.set_minor_locator(MultipleLocator(1))

# xmax = 60
# ymax = 25

# ax.set_xlim(0,xmax)
# ymin = get_ymin(ymax)
# ax.set_ylim(ymin,ymax)

# # ax.set_xlim(0.0, 0.5)
# # ax.set_ylim(0.0, 10.0)

# handles, labels = ax.get_legend_handles_labels()
# l = legend(handles, labels, loc='lower right', title=r"", frameon=True)

write_to_file("test-droplet")

# fig, ax = plt.subplots()
# ax.set_xlabel(r"$z$")
# ax.set_ylabel(r"$\Delta \phi$",fontsize=talfs, family=tff)

# plot_E("output/",globstr,D,R)
# handles, labels = ax.get_legend_handles_labels()
# l = legend(handles, labels, loc='center right', title=r"")
# write_to_file("test-E")

exit()

