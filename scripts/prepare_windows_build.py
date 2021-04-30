#!/usr/bin/env python3
import os
import shutil
import glob
from pathlib import Path
import sys
import urllib.request as request
from contextlib import closing
import zipfile


if sys.platform != "win32":
    print("This script is only needed in windows")
    # sys.exit(0)

if not shutil.which("lib.exe"):
    print("lib.exe is not in the path. Run this script inside a"
          "'Developer Command Prompt for Visual Studio' or a"
          "'Developer Powershell...'. In both cases Visual Studio should"
          "be installed")

root = Path(__file__).parent.parent
loris_base = root / "src" / "loris"
loris_win = root / "src" / "loriswin"
tmp_dir = root / "tmp"

print("Root: ", root)
print("Loris base: ", loris_base)
print("tmp dir: ", tmp_dir)


def python_arch() -> int:
    """ Returns 32 if python is 32-bit, 64 if it is 64-bits"""
    import struct
    return struct.calcsize("P") * 8


def ls(folder=None):
    for f in os.listdir(str(folder)):
        print(f)


arch = python_arch()
assert arch == 32 or arch == 64


def create_cpp_tree(dest, force=False):
    if os.path.exists(dest):
        if not force:
            print(f"{dest} already exists, skipping")
            return
        else:
            shutil.rmtree(dest)
    shutil.copytree(loris_base, dest)
    cfiles = glob.glob(os.path.join(dest, 'src', '*.C'))
    for cfile in cfiles:
        os.rename(cfile, os.path.splitext(cfile)[0] + ".cpp")


def zip_extract(zfile, outfolder):
    outfolder = os.path.abspath(outfolder)
    print(f"Extracting {zfile} to {outfolder}")
    if os.path.exists(outfolder):
        shutil.rmtree(outfolder)
    with zipfile.ZipFile(zfile, 'r') as z:
        z.extractall(outfolder)


def download_fftw(arch):
    if arch == 32:
        url = "ftp://ftp.fftw.org/pub/fftw/fftw-3.3.5-dll32.zip"
        outfile = tmp_dir / "fftw32.zip"
    else:
        url = "ftp://ftp.fftw.org/pub/fftw/fftw-3.3.5-dll64.zip"
        outfile = tmp_dir / "fftw64.zip"
    fftw_folder = tmp_dir / f"fftw{arch}"
    if fftw_folder.exists():
        print(f">> fftw folder already present at {fftw_folder}, skipping")
        return fftw_folder

    print(f">> Downloading fftw from {url}")
    with closing(request.urlopen(url)) as r:
        with open(outfile, 'wb') as f:
            shutil.copyfileobj(r, f)
    print(f">> Saved fftw to {outfile}")
    zip_extract(outfile, fftw_folder)

    return fftw_folder


def generate_lib_files(fftw_folder: Path, arch=32):
    if sys.platform != "win32":
        raise RuntimeError("This operation is only valid in windows")
    cwd = os.getcwd()
    os.chdir(fftw_folder)
    def_files = Path(".").glob("libfftw3*.def")
    libexe = shutil.which("lib.exe")
    if libexe is None:
        print(os.getenv("PATH"))
        raise RuntimeError("lib.exe should be in the path")
    machine = "x86" if arch == 32 else "x64"
    for def_file in def_files:
        os.system(f"lib.exe /machine:{machine} /def:{def_file}")
    os.chdir(cwd)


# In windows, setuptools seems to need the extensions to be .cpp even
# if language is set to c++. The loris sources use .C for c++ files,
# so instead of modifying the loris tree we create a new tree with
# files renamed to .cpp
create_cpp_tree(loris_win)

# Create tmp dir to download the fftw dll binaries
os.makedirs(tmp_dir, exist_ok=True)
fftw_folder = download_fftw(arch)

# The data folder is part of the distributed files and will
# store the fftw .dll
data_folder = fftw_folder.parent.parent / "loristrck/data"
os.makedirs(data_folder, exist_ok=True)
fftwdll = fftw_folder / "libfftw3-3.dll"
if not fftwdll.exists():
    print(f"Did not find {fftwdll}, but it does not exist")
    ls(fftw_folder)
    sys.exit(-1)

# We copy the .dll file for runtime
shutil.copy(fftwdll, data_folder)

# The .lib files are needed for building
if sys.platform == "win32":
    generate_lib_files(fftw_folder, arch=arch)
else:
    print("Not on windows, the .lib files for fftw will not be generated")

print(">> prepare_windows_build: Finished")
