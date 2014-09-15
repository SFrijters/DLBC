#!/usr/bin/env python

import glob
import sys

# Parser
try:
    import argparse
except ImportError:
    print( "\nImportError while loading argparse -- module details follow.")
    print_versions()

parser = argparse.ArgumentParser(description="Style helper script for matplotlib")
parser.add_argument("-V", "--version", action="store_true", help="Show versions")
parser.add_argument("--dpi", help="Set output DPI", type=int, default=600)

options = parser.parse_args()

def print_versions():
    print( "\nPython       " + sys.version)
    try:
        import matplotlib
        print( "\nMatplotlib   " + matplotlib.__version__)
        print( "             " + matplotlib.__file__)
    except ImportError:
        print( "\nImportError while loading Matplotlib.")

    try:
        import numpy
        print( "\nNumPy        " + numpy.__version__)
        print( "             " + numpy.__file__)
    except ImportError:
        print( "\nImportError while loading NumPy.")

    try:
        import scipy
        print( "\nSciPy        " + scipy.__version__)
        print( "             " + scipy.__file__)
    except ImportError:
        print( "\nImportError while loading SciPy.")

    try:
        import Cython
        print( "\nCython       " + Cython.__version__)
        print( "             " + Cython.__file__)
    except ImportError:
        print( "\nImportError while loading Cython.")

    try:
        import h5py
        print( "\nH5py         " + h5py.version.version)
        print( "             " + h5py.__file__)
        print( "  HDF5       " + h5py.version.hdf5_version)
    except ImportError:
        print( "\nImportError while loadting H5py.")

    import os
    print( "\nMplHelper " )
    print( "             " + os.path.realpath(__file__) )
    print( "" )
    exit()

# Show version info and exit
if ( options.version ):
    print_versions()

mplformat = "PDF"

try:
    import matplotlib
except ImportError:
    print( "\nImportError while loading matplotlib -- module details follow.")
    print_versions()

# matplotlib.use() must be called *before* pylab, matplotlib.pyplot,
# or matplotlib.backends is imported for the first time.
matplotlib.use(mplformat)

try:
    from matplotlib import pyplot as plt
    from numpy import *
    from pylab import *
except ImportError:
    print( "\nImportError while loading matplotlib.pyplot, numpy, pylab -- module details follow.")
    print_versions()

# Set output DPI
outDpi = options.dpi

# TU/e main colours
plotwhite   = '#FFFFFF'
plotred1    = '#F73131'
plotred2    = '#D6004A'
plotred3    = '#D6007B'
plotpurple  = '#AD20AD'
plotblue1   = '#00A2DE'
plotblue2   = '#0066CC'
plotblue3   = '#101073'
plotyellow1 = '#FF9A00'
plotyellow2 = '#FFDD00'
plotyellow3 = '#CEDF00'
plotgreen1  = '#84D200'
plotgreen2  = '#00AC82'
plotgreen3  = '#0092B5'
plotblack   = '#000000'
plotcolours = [ plotred2, plotblue2, plotgreen2, plotpurple, plotyellow1, plotgreen1, plotred1, plotblue1 ]

# Marker and line styles
plotmarkers = [ "s", "o", "d", "^", "v", "<", ">" ]
plotdashes  = [ (None, None), (5, 5), (5, 2, 1, 2, 1, 2), (7, 2, 1, 2), (4, 2) ]

# Widths and sizes
plw = 1.5
pms = 15.0
pmew = 1.5

# Inset widths and sizes
pilw = 1.5
pims = 10.0
pimew = 1.5

# Font defaults
# Title
patfs = 36
# Axes label
palfs = 20
# Tick label
ptlfs = 20
# Legend label
pllfs = 20

# Inset Axes label
pialfs = 16
# Inset Tick label
pitlfs = 16
# Inset Legend label
pillfs = 16

# Style helper functions
def pc(i):
    return plotcolours[mod(i,len(plotcolours))]

def pm(i):
    return plotmarkers[mod(i,len(plotmarkers))]

def pd(i):
    return plotdashes[mod(i,len(plotdashes))]

# Use TeX
rcParams['text.usetex'] = True

tff = "sans-serif"
rcParams['font.family'] = tff
rcParams['font.serif'] = "Computer Modern Roman"
rcParams['font.sans-serif'] = "Computer Modern Sans serif"
rcParams['font.cursive'] = "Zapf Chancery"
rcParams['font.monospace'] = "Computer Modern Typewriter"
rcParams['text.latex.preamble'].append(r"\usepackage{sfmath}")

rcParams['axes.color_cycle'] = plotcolours
rcParams['axes.titlesize'] = patfs
rcParams['axes.labelsize'] = palfs
rcParams['axes.linewidth'] = plw

rcParams['lines.linewidth'] = plw
rcParams['lines.linestyle'] = "None"
rcParams['lines.markeredgewidth'] = pmew
rcParams['lines.markersize'] = pms

rcParams['xtick.labelsize'] = ptlfs
rcParams['ytick.labelsize'] = ptlfs

rcParams['legend.frameon'] = False
rcParams['legend.fancybox'] = True
rcParams['legend.numpoints'] = 1
rcParams['legend.fontsize'] = pllfs
rcParams['legend.markerscale'] = 0.75
rcParams['legend.borderpad'] = 1.0
rcParams['legend.labelspacing'] = 0.1
rcParams['legend.handletextpad'] = 0.5
rcParams['legend.handlelength'] = 2.0

rcParams['figure.subplot.left'] = 0.12
rcParams['figure.subplot.right'] = 0.96
rcParams['figure.subplot.bottom'] = 0.12
rcParams['figure.subplot.top'] = 0.96
rcParams['figure.subplot.wspace'] = 0.2
rcParams['figure.subplot.hspace'] = 0.2

# Default arrow properties
papd = dict(fc=plotblack, arrowstyle="-|>,head_width=0.3,head_length=0.5", lw=plw, shrinkA=10,shrinkB=0)

# Why? Because it was there...
ioff()

# Write to file
def write_to_file(fname):
    show()
    import string
    savefig(string.replace(fname,".","_")+"."+mplformat.lower(),dpi=outDpi,format=mplformat)

# Make LaTeX exponents
def latex_sci(f, p):
    fstr = "%." + str(p) + "e"
    lstr = fstr % f
    m = lstr.split("e")[0]
    e = lstr.split("e")[1]
    return m + " \cdot 10^{" + str(int(e)) + "}"

# Reading data from files by column header name
import re
import bz2
def read_file_columns(fname_raw):
    m = re.match(r".*\.bz2$",fname_raw)
    if m is not None:
        bf = bz2.BZ2File(fname_raw, "r")
        f = bf.readlines()
    else:
        f = open(fname_raw,"r")

    for line in f:
        line = re.sub(r"\n","",line)
        match = re.match(r"^#\?",line)
        # print( line )
        if match is not None:
            line = re.sub(r"[ \n]+"," ",line)
            headers = line.split(' ')[1:]
            if m is None:
                f.close()
            return headers
    if m is None:
        f.close()

def make_column_list(fname, colnames):
    cols = []
    headers = read_file_columns(fname)
    for cn in colnames:
        cols.append(headers.index(cn))
    return cols

# Error propagation helper
def uncorr_error_quot(a, s_a, b, s_b):
    f2 = (a/b)*(a/b)
    s_f2 =  f2 * ( (s_a/a) * (s_a/a) + (s_b/b) * (s_b/b) )
    return sqrt(f2), sqrt(s_f2)

def uncorr_error_product(a, s_a, b, s_b):
    f2 = (a*b)*(a*b)
    s_f2 =  f2 * ( (s_a/a) * (s_a/a) + (s_b/b) * (s_b/b) )
    return sqrt(f2), sqrt(s_f2)

def calculate_stdev(data):
    n = 0
    Sum = 0
    Sum_sqr = 0

    for x in data:
        n = n + 1
        Sum = Sum + x
        Sum_sqr = Sum_sqr + x*x

    mean = Sum/n

    if ( n == 1):
        variance = 0
    else:
        variance = (Sum_sqr - Sum*mean)/(n - 1)

    if (variance < 0):
        variance = 0

    return mean, math.sqrt(variance)

# Make a colour without alpha channel out of a colour with transparency
def alpha_blending(hex_color, alpha):
    """ alpha blending as if on the white background.
    """
    foreground_tuple  = matplotlib.colors.hex2color(hex_color)
    foreground_arr = np.array(foreground_tuple)
    final = tuple( (1. -  alpha) + foreground_arr*alpha )
    return(final)

# In case we want an offset of the zero point, make sure it's always at the same height in a standard plot.
def get_ymin(ymax):
    return (-ymax/19.0)

irange = lambda start, end, step: range(start, end+step, step)

