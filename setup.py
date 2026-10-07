import os
import sys
import glob
from setuptools import setup, Extension
from pathlib import Path


VERSION = '1.7.2'


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


def append_if_exists(seq: list[str], folders: list[str]):
    for folder in folders:
        if os.path.exists(folder):
            seq.append(folder)


def python_arch() -> int:
    """ Returns 32 if python is 32-bit, 64 if it is 64-bits"""
    import struct
    return struct.calcsize("P") * 8

#######################################
# Mac OSX
######################################

package_data = {'loristrck': ['__init__.pyi', '_core.pyi', 'py.typed', "data/*"]}

print("Platform", sys.platform, flush=True)

if sys.platform == 'darwin':
    libs = ["m", "fftw3"]
    include_dirs.append('src/loris')
    append_if_exists(include_dirs, ['/opt/homebrew/include', '/opt/local/include', '/usr/local/include'])
    append_if_exists(library_dirs, ['/opt/homebrew/lib', '/opt/local/lib', '/usr/local/lib'])
    if os.path.exists('/opt/homebrew/Cellar/fftw'):
        p = Path('/opt/homebrew/Cellar/fftw')
        candidates = sorted(
            (s for s in p.glob("*") if (s / "include").exists() and (s / "lib").exists()),
            key=lambda s: s.name,
            reverse=True,
        )
        if candidates:
            include_dirs.append((candidates[0] / "include").as_posix())
            library_dirs.append((candidates[0] / "lib").as_posix())

    compile_args.append("-g")
    compile_args.append("-std=c++11")
    loris_base = os.path.join('src', 'loris', 'src')

elif sys.platform == 'linux':
    libs = ["m", "fftw3"]
    compile_args.append("-g")
    compile_args.append("-std=c++11")
    include_dirs.append('src/loris')
    loris_base = os.path.join('src', 'loris', 'src')

elif sys.platform == 'win32':
    if not os.path.exists('src/loriswin'):
        raise RuntimeError(
            "Source files for windows not found. From a 'Developer Command Prompt' "
            "run scripts/prepare_windows_build.py first")

    if not os.path.exists('loristrck/data/libfftw3-3.dll'):
        raise RuntimeError(
            "fftw dll not found. Run scripts/prepare_windows_build.py first"
            ". Make sure to run that from a terminal in which lib.exe is in the path"
            " (for example, from a 'Developer Powershell...')")

    libs = ["libfftw3-3"]
    include_dirs.append('src/loriswin')
    include_dirs.append('tmp/fftw3')
    library_dirs.append('tmp/fftw3')
    loris_base = os.path.join('src', 'loriswin', 'src')

    compile_args += [
        "/std:c++14",
        "-D_USE_MATH_DEFINES",
    ]
else:
    raise RuntimeError(f"Unsupported platform: {sys.platform}")

if not os.path.exists(loris_base):
    raise RuntimeError(f"Loris sources not found at {loris_base!r}")

sources = []

# -----------------------------------------------------------------------------
# Loris
# -----------------------------------------------------------------------------
loris_sources = glob.glob(os.path.join(loris_base, '*.C'))
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

loris_sources = sorted(set(loris_sources) - set(loris_exclude))
sources.extend(loris_sources)
print("Loris Base: ", loris_base, flush=True)
print("Sources:", len(sources), "files", flush=True)

with open("README.rst", encoding="utf-8") as f:
    long_description = f.read()

setup(
    name='loristrck',
    python_requires='>=3.10',
    ext_modules=[
        Extension(
            'loristrck._core',
            sources=sources + ['loristrck/_core.pyx'],
            depends=sorted(loris_headers),
            include_dirs=include_dirs + [get_numpy_include()],
            libraries=libs,
            library_dirs=library_dirs,
            extra_compile_args=compile_args,
            language='c++'
        )
    ],
    packages=['loristrck'],
    scripts=['bin/loristrck_analyze', 'bin/loristrck_pack', 'bin/loristrck_synth',
             'bin/loristrck_chord'],
    package_data=package_data,
    url='https://github.com/gesellkammer/loristrck',
    download_url='https://github.com/gesellkammer/loristrck',
    license='GPL-2.0-or-later',
    author='Eduardo Moguillansky',
    author_email='eduardo.moguillansky@gmail.com',
    platforms=['Linux', 'Mac OS-X', 'Windows'],
    version=VERSION,
    description="A wrapper around the partial-tracking library Loris",
    long_description=long_description
)
