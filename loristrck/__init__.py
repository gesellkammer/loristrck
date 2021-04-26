from __future__ import absolute_import
import os
import sys

# Needed in windows to add the fftw dlls to the search path
# We ship the dll as data
if sys.platform == "win32":
    _datadir = os.path.join(os.path.split(__file__)[0], "data")
    os.add_dll_directory(_datadir)

from ._core import *
from . import util
from .util import write_sdif
