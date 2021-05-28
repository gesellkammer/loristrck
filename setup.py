import os
import sys
import glob
from setuptools import setup, Extension
import shutil

VERSION = '1.3.0'

class get_numpy_include(str):
    def __str__(self):
        import numpy
        return numpy.get_include()

# -----------------------------------------------------------------------------
# Global
# -----------------------------------------------------------------------------


include_dirs = [
    'loristrck'
]

library_dirs = []
compile_args = ['-DMERSENNE_TWISTER',
                '-DHAVE_FFTW3_H']


def append_if_exists(seq, folder):
    if os.path.exists(folder):
        seq.append(folder)


def python_arch() -> int:
    """ Returns 32 if python is 32-bit, 64 if it is 64-bits"""
    import struct
    return struct.calcsize("P") * 8

#######################################
# Mac OSX
######################################

package_data = {}
print("Platform", sys.platform)

if sys.platform == 'darwin':
    libs = ["m", "fftw3"]
    include_dirs.append('src/loris')
    include_dirs.append('/usr/local/include')
    library_dirs.append('/usr/local/lib')
    # Macports support
    append_if_exists(include_dirs, '/opt/local/include')
    append_if_exists(library_dirs, '/opt/local/lib')
    compile_args.append("-g")
    compile_args.append("-std=c++11")
    loris_base = os.path.join('src', 'loris', 'src')

elif sys.platform == 'linux':
    libs = ["m", "fftw3"]
    if shutil.which("ccache"):
        os.environ['CC'] = "ccache gcc"
    compile_args.append("-g")
    compile_args.append("-std=c++11")
    include_dirs.append('src/loris')
    loris_base = os.path.join('src', 'loris', 'src')

######################################
# Windows
######################################
elif sys.platform == 'win32':
    assert os.path.exists('src/loriswin'), (
        "Source files for windows not found. From a 'Developer Command Prompt' "
        "run scripts/prepare_windows_build.py first")

    assert os.path.exists('loristrck/data/libfftw3-3.dll'), (
        "fftw dll not found. Run scripts/prepare_windows_build.py first"
        ". Make sure to run that from a terminal in which lib.exe is in the path"
        " (for example, from a 'Developer Powershell...')")

    libs = ["libfftw3-3"]
    include_dirs.append('src/loriswin')
    # possible_dirs = ['/src/fftw', '/lib/fftw']
    possible_dirs = []
    loris_base = os.path.join('src', 'loriswin', 'src')
    if python_arch() == 32:
        possible_dirs.append("tmp/fftw32")
    else:
        possible_dirs.append("tmp/fftw64")
    for folder in possible_dirs:
        append_if_exists(include_dirs, folder)
        append_if_exists(library_dirs, folder)
    # compile_args.append("-march-i686")
    compile_args += [
        "/std:c++14",
        #  "-DHAVE_CONFIG_H",
        "-D_USE_MATH_DEFINES",
    ]
    package_data['loristrck'] = ['data/*']
assert os.path.exists(loris_base)

sources = []

# -----------------------------------------------------------------------------
# Loris
# -----------------------------------------------------------------------------
loris_sources  = glob.glob(os.path.join(loris_base, '*.C'))
loris_sources += glob.glob(os.path.join(loris_base, '*.cpp'))
loris_headers = glob.glob(os.path.join(loris_base, '*.h'))
_exclude = [
    "ImportLemur",
    "Dilator",
    "Morpher",
    "SpectralSurface",
    "lorisNonObj_pi",
    "Channelizer",
    "Distiller",
    "PartialUtils",
    "lorisUtilities_pi",
    "lorisPartialList_pi",
    "lorisAnalyzer_pi",
    "lorisBpEnvelope_pi",
    "Harmonifier",
    "Collator",
    "lorisException_pi"
]
loris_exclude = []
loris_exclude += [os.path.join(loris_base, f) + ".C" for f in _exclude]
loris_exclude += [os.path.join(loris_base, f) + ".cpp" for f in _exclude]

loris_sources = list(set(loris_sources) - set(loris_exclude))
sources.extend(loris_sources)
print("Loris Base: ", loris_base)
print("Sources:", sources)
print("Package Data", package_data)

setup(
    name='loristrck',
    python_requires='>=3.8',
    ext_modules = [
        Extension(
            'loristrck._core',
            sources=sources + ['loristrck/_core.pyx'],
            # sources=sources + ['loristrck/_core.cpp'],

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
    package_data=package_data,
    # include_package_data=bool(package_data),

    url='https://github.com/gesellkammer/loristrck',
    download_url='https://github.com/gesellkammer/loristrck',
    license='GPL',
    author='Eduardo Moguillansky',
    author_email='eduardo.moguillansky@gmail.com',
    platforms=['Linux', 'Mac OS-X', 'Windows'],
    version=VERSION,
    description="A wrapper around the partial-tracking library Loris",
    long_description=open("README.rst").read()
)
