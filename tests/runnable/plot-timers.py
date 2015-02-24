#!/usr/bin/env python

"""
Helper script to plot timer data for DLBC.

Files for the available compilers will be combined into a single plot.
"""

from tester.mplhelper import *

rcParams['figure.subplot.left'] = 0.15
rcParams['figure.subplot.right'] = 0.9
rcParams['figure.subplot.bottom'] = 0.2
rcParams['figure.subplot.top'] = 0.92

dubCompilerChoices = [ "dmd", "gdc", "ldc2" ]

def stripFile(f):
    """ Strip file names to determine which plots have to be generated. """
    import re
    subbed = re.sub(options.relpath + "/?timers-", "", f)
    stripped = re.sub("-[a-z0-9]*?\.asc", "", subbed)
    return stripped

def readDataset(prefix, compiler):
    """ Read dataset from file. """
    filename = os.path.join(options.relpath, "timers-" + prefix + "-" + compiler + ".asc")
    if ( not os.path.isfile(filename) ): return
    data = np.genfromtxt(filename, dtype=None, unpack=True)
    data = np.sort(data)
    main = filter(lambda x: x[0] == "main", data)
    data = filter(lambda x: x[0] != "main", data)
    timers = map(lambda x: x[0], data)
    t = map(lambda x: x[2], data)
    return timers, t, main[0][2]

os.chdir(options.testpath)

files = glob.glob(os.path.join(options.relpath, "timers*.asc"))
strippedFiles = list(set(map(stripFile, files)))

for prefix in strippedFiles:

    fig, ax1 = plt.subplots()
    fig.suptitle(prefix)
    width = 0.3

    ax2 = ax1.twinx()

    rects = []
    compilers = []

    for i, compiler in enumerate(dubCompilerChoices):
        compilers.append(compiler)
        timers, t, main = readDataset(prefix, compiler)
        ind = np.arange(len(timers))
        t_rescaled = map(lambda x: float(x) / main, t)
        rect = ax1.bar(i*width, main, width, color=pc(i))
        rect = ax2.bar(2 + ind + i*width, t_rescaled, width, color=pc(i))
        rects.append(rect[0])

    # Styles
    ax1.set_xlabel(r"Timer")
    ax1.set_ylabel(r"Time (ms)")
    ax2.set_ylabel(r"Relative")
    ticks = [ 0.5 ]
    ticks.extend(ind + 2.5)
    ax1.set_xticks(ticks)
    import string
    timers = map(lambda s: string.replace(s, "main.", ""), timers)
    timers = ["main"] + timers
    ax1.set_xticklabels( timers, rotation=45, fontsize=8)

    ax1.legend( rects, compilers, loc='upper right', title=r"" )

    write_to_file(prefix)

exit()

