#!/usr/bin/env python3
import os
import shutil
import glob
import argparse
from pathlib import Path
import sys
import urllib.request as request
from contextlib import closing
import zipfile


if sys.platform != "win32":
    print("This script is only needed in windows")
    sys.exit(0)


root = Path(__file__).parent.parent
loris_base = root / "src" / "loris"
loris_win = root / "src" / "loriswin"
lib_dir = root / "lib"


def python_arch() -> int:
    """ Returns 32 if python is 32-bit, 64 if it is 64-bits"""
    import struct 
    return struct.calcsize("P") * 8    


arch = python_arch()


def create_cpp_tree(dest):
    shutil.copytree(loris_base, dest, dirs_exist_ok=True)
    cfiles = glob.glob(os.path.join(loris_base, 'src', '*.C'))
    for cfile in cfiles:
        os.rename(cfile, os.path.splitext(cfile)[0] + ".cpp")


def download_fftw(arch=32):
    if arch == 32:
        url = "ftp://ftp.fftw.org/pub/fftw/fftw-3.3.5-dll32.zip"
        outfile = lib_dir / "fftw32.zip"
    else:
        url = "ftp://ftp.fftw.org/pub/fftw/fftw-3.3.5-dll64.zip"
        outfile = lib_dir / "fftw64.zip"
    fftw_folder = lib_dir / f"fftw{arch}"
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


def zip_extract(zfile, outfolder):
    with zipfile.ZipFile(zfile, 'r') as z:
        z.extractall(outfolder)


def generate_lib_files(fftw_folder: Path, arch=32):
    if sys.platform != "win32":
        raise RuntimeError("This operation is only valid in windows")

    def_files = fftw_folder.glob("libfftw3*.def")
    libexe = shutil.which("lib.exe")
    if libexe is None:
        raise RuntimeError("lib.exe should be in the path")
    machine = "x86" if arch == 32 else "x64"
    for def_file in def_files:
        os.system(f"lib.exe /machine:{machine} /def:{def_file}")


create_cpp_tree(loris_win)
os.makedirs(lib_dir, exist_ok=True)
fftw_folder = download_fftw(arch)
generate_lib_files(fftw_folder, arch=arch)

print(">> prepare_windows_build: Finished")
