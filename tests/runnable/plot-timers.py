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

os.chdir(options.testpath)

files = glob.glob(os.path.join(options.relpath, "timers*.asc"))
strippedFiles = list(set(map(stripFile, files)))

for prefix in strippedFiles:

    fig, ax1 = plt.subplots()
    fig.suptitle(prefix)
    
    barwidth = 0.8/len(dubCompilerChoices)

    ax2 = ax1.twinx()

    rects = []
    compilers = []

    for i, compiler in enumerate(dubCompilerChoices):
        filename = os.path.join(options.relpath, "timers-" + prefix + "-" + compiler + ".asc")
        if ( not os.path.isfile(filename) ): continue
        compilers.append(compiler)
        data = np.genfromtxt(filename, dtype=None, unpack=True)
        data = np.sort(data)
        main = filter(lambda x: x[0] == "main", data)[0][2]
        data = filter(lambda x: x[0] != "main", data)
        timers = map(lambda x: x[0], data)
        t = map(lambda x: x[2], data)
        t_rescaled = map(lambda x: float(x) / main, t)
        t_rescaled.append(1.0 - sum(t_rescaled))
        timers.append("other")
        ind = np.arange(len(timers))
        main *= 0.001 # rescale to seconds
        rect = ax1.bar(0.1 + i*barwidth, main, barwidth, color=pc(i))
        rect = ax2.bar(2.1 + ind + i*barwidth, t_rescaled, barwidth, color=pc(i))
        rects.append(rect[0])

    # Styles
    ax1.set_xlabel(r"Timer")
    ax1.set_ylabel(r"Time (s)")
    ax2.set_ylabel(r"Fraction of main")
    ticks = [ 0.5 ]
    ticks.extend(ind + 2.5)
    ax1.set_xticks(ticks)
    import string
    timers = map(lambda s: string.replace(s, "main.", ""), timers)
    timers = ["main"] + timers
    ax1.set_xticklabels( timers, rotation=45, fontsize=8)
    ax1.yaxis.get_major_formatter().set_powerlimits((0, 1))

    ax1.legend( rects, compilers, loc='upper right', title=r"" )

    logInformation("  Writing plot '%s' ..." % ( os.path.normpath(os.path.join(options.testpath, options.relpath, prefix + ".pdf"))) )
    write_to_file(prefix)

exit()

