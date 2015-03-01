#!/usr/bin/env python

#### START HEADER
from mpltuehelper import *
#### END HEADER

dirstr = "output/"
globstr = "t00001000"

L = 64
g_br = 0.10

def psi(rho):
    return ( 1.0 - math.exp(-rho) )

def calc_r_mass(od_in, od_out, M_d):
    return ( M_d / (4.0/3.0 * math.pi * ( od_in - od_out ) ) ) ** ( 1.0/3.0 )

def calc_r_mass_2d(od_in, od_out, M_d):
    return ( M_d / ( math.pi * ( od_in - od_out ) ) ) ** ( 1.0/2.0 )

import h5py

g = sorted(glob.glob(dirstr+"od_*"+globstr+"*h5"))
f = h5py.File(g[0],'r')
dset = f['OutArray']
od_in = dset[L/2,L/2,0]
od_out = dset[0,0,0]
od_total = sum(dset[:,:,0])

print od_in, od_out, od_total

g = sorted(glob.glob(dirstr+"wd_*"+globstr+"*h5"))
f = h5py.File(g[0],'r')
dset = f['OutArray']
wd_in = dset[L/2,L/2,0]
wd_out = dset[0,0,0]
wd_total = sum(dset[:,:,0])

print wd_in, wd_out, wd_total

r_mass = calc_r_mass_2d(od_in, od_out, od_total - L*L*od_out)

print r_mass

rho_in = od_in + wd_in
P_in = rho_in / 3.0
Pc_in = P_in + 18.0 * 2.0 * g_br * psi(od_in) * psi(wd_in)/3.0

rho_out = od_out + wd_out
P_out = rho_out / 3.0
Pc_out = P_out + 18.0 * 2.0 * g_br * psi(od_out) * psi(wd_out)/3.0

DPc = Pc_in - Pc_out
sigma = DPc * r_mass

print sigma


exit()

