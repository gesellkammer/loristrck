import numpy as np
from typing import List
import sys
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection
import matplotlib.cm

_EPS = sys.float_info.epsilon


def amp2db_np(amp, out=None):
    # type: (np.ndarray) -> np.ndarray
    """
    convert amp to dB for arrays
    """
    if out is None:
        X = np.maximum(amp, _EPS)
    else:
        X = np.maximum(amp, _EPS, out=out)
    X = np.log10(X, out=X)
    X *= 20
    return X


def _plotpartial(ax, partial, downsample=1, cmap='inferno', exp=1, linewidth=2, avg=True):
    X = partial[:,0]
    Y = partial[:,1]
    Z = partial[:,2]
    if downsample > 1:
        X = X[::downsample]
        Y = Y[::downsample]
        Z = Z[::downsample]
    if avg:
        Z = Z[:-1] + Z[1:]
        Z *= 0.5
    if exp != 1:
        Z **= exp
    points = np.array([X, Y]).T.reshape(-1, 1, 2)
    segments = np.concatenate([points[:-1], points[1:]], axis=1)
    lc = LineCollection(segments, cmap=cmap)
    # Set the values used for colormapping
    lc.set_array(Z)
    lc.set_linewidth(linewidth)
    lc.set_alpha(None)
    ax.add_collection(lc)
    

def plotpartials(sp: List[np.ndarray], downsample=1, cmap='inferno', exp=1, 
                 linewidth=2, ax=None):
    """
    Plot the partials in sp using matplotlib

    Returns a matplotlib axes
    """
    downsample = max(downsample, 1)
    if ax is None:
        ax = plt.subplot(111)
    bg = matplotlib.cm.inferno(0.002)[:3]
    ax.set_facecolor(bg)
    for p in sp:
        if p.shape[0] > downsample:
            _plotpartial(ax, p, downsample, cmap=cmap, exp=exp, linewidth=linewidth)
    ax.autoscale()
    return ax