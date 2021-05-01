import os
import sys
import pathlib
import shutil

if sys.platform != "win32":
    print("This script is supposed to run in windows.")
    sys.exit(-1)

assert os.path.exists("setup.py"), "This script should be called at the package's root"

HOME = str(pathlib.Path.home())

py39_64 = f"{HOME}\\AppData\\Local\\Programs\\Python\\Python39"
py39_32 = f"{HOME}\\AppData\\Local\\Programs\\Python\\Python39-32"
py38_64 = f"{HOME}\\AppData\\Local\\Programs\\Python\\Python38"
py38_32 = f"{HOME}\\AppData\\Local\\Programs\\Python\\Python38-32"

pyversions = [py39_64, py39_32, py38_64, py38_32]

os.makedirs("wheelhouse", exist_ok=True)

for py in pyversions:
    pyexe = py + "\\python.exe"
    if not os.path.exists(pyexe):
        print(f"Version {py} not found skipping")
        continue
    print(f"Building wheel for {py}")
    os.system(f"{pyexe} setup.py bdist_wheel -d wheelhouse")

print("Uploading")
os.system("twine upload --skip-existing wheelhouse\\*.whl")