'''
LORISTRCK: a library for sound analysis based on the partial-tracking library Loris

The unerlying c++ library is included as part of the project --there is no need
to install it independently.

'''

import os
import sys
import glob
from setuptools import setup, Extension

VERSION = '1.2.0'

class get_numpy_include(str):
    def __str__(self):
        import numpy
        return numpy.get_include()

# -----------------------------------------------------------------------------
# Global
# -----------------------------------------------------------------------------

include_dirs = [
    'loristrck',
    'src/loristrck',
    'src/loris',
]

library_dirs = []
libs = ['m', 'fftw3']
compile_args = ['-DMERSENNE_TWISTER', '-DHAVE_FFTW3_H', 
                '-g', '-std=c++11']


def append_if_exists(seq, folder):
    if os.path.exists(folder):
        seq.append(folder)

#######################################
# Mac OSX
######################################


if sys.platform == 'darwin':
    # On some systems, these are not in the path
    include_dirs.append('/usr/local/include')
    library_dirs.append('/usr/local/lib')
    # Macports support
    append_if_exists(include_dirs, '/opt/local/include')
    append_if_exists(library_dirs, '/opt/local/lib')
elif sys.platform == 'linux2':
    os.environ['CC'] = "ccache gcc"
######################################
# Windows
######################################
elif sys.platform == 'win32':
    for folder in ('/src/fftw', '/lib/fftw'):
        append_if_exists(include_dirs, folder)
        append_if_exists(library_dirs, folder)
    compile_args.append("-march-i686")
    print("""
NB: make sure that the FFTW dlls are in the windows PATH")
If FFTW is not found during build, go to http://www.fftw.org/install/windows.html
Download the DLLs for your system (try the 32-bit package first) and unzip them
to a directory of your choice. Something like C:\lib\fftw.
Then add this directory to your PATH. Alternatively, pass the path to the
setup script as:

    python setup.py install -LC:\my\path\to\fftw`

See README for more information
""")

sources = []

# -----------------------------------------------------------------------------
# Loris
# -----------------------------------------------------------------------------
loris_base = os.path.join('src', 'loris', 'src')
loris_sources = glob.glob(os.path.join(loris_base, '*.C'))
loris_headers = glob.glob(os.path.join(loris_base, '*.h'))
loris_exclude = []
loris_exclude += [os.path.join(loris_base, filename) for filename in (
    "ImportLemur.C",
    "Dilator.C",
    "Morpher.C",
    "SpectralSurface.C",
    "lorisNonObj_pi.C",
    "Channelizer.C",
    "Distiller.C",
    "PartialUtils.C",
    "lorisUtilities_pi.C",
    "lorisPartialList_pi.C",
    "lorisAnalyzer_pi.C",
    "lorisBpEnvelope_pi.C",
    "Harmonifier.C",
    "Collator.C",
    "lorisException_pi.C"
)]

loris_sources = list(set(loris_sources) - set(loris_exclude))
sources.extend(loris_sources)

setup(
    name='loristrck',
    python_requires='>=3.8',
    ext_modules = [
        Extension(
            'loristrck._core',
            sources=sources + ['loristrck/_core.pyx'],
            depends=loris_headers,
            include_dirs=include_dirs + [get_numpy_include()],
            libraries=libs,
            library_dirs=library_dirs,
            extra_compile_args=compile_args,
            language='c++'
        )
    ],
    packages=['loristrck'],
    scripts=['bin/loristrck_analyze', 'bin/loristrck_pack', 'bin/loristrck_play',
             'bin/loristrck_chord'],
    setup_requires=[
        'numpy>=1.8',
        'cython>=0.25'
    ],
    install_requires=[
        'numpy>=1.8',
        'cython>=0.25',
        'numpyx',
        'soundfile',
        'sounddevice',
        'pysdif3>=0.6.0'
    ],
    
    url='https://github.com/gesellkammer/loristrck',
    download_url='https://github.com/gesellkammer/loristrck',
    license='GPL',
    author='Eduardo Moguillansky',
    author_email='eduardo.moguillansky@gmail.com',
    platforms=['Linux', 'Mac OS-X', 'Windows'],
    version=VERSION,
    description="A wrapper around the partial-tracking library Loris",
    long_description=__doc__            
)
