Ifrom __future__ import absolute_import
import os
import sys

# Needed in windows to add the fftw dlls to the search path
# We ship the dll as data within the windows wheel. When installing
# loristrck from a source distribution the script scripts/prepare_windows_build.py
# needs to be executed manually
if sys.platform == "win32":
    _fftwdll = "libfftw3-3.dll"
    _datadir = os.path.join(os.path.split(__file__)[0], "data")
    if not os.path.exists(os.path.join(_datadir, _fftwdll):
        raise IOError(f"{_fftwdll} not found. If you are not running loristrck "
                      f"from a wheel, run scripts/prepare_windows_build.py to " 
                      f"download the fftw dll to {_datadir} where it can be found")
    os.add_dll_directory(_datadir)

from ._core import *
from . import util
from .util import write_sdif
