#!/usr/bin/env python3
import os
import argparse
import sys

try:
    from loristrck import util
    from emlib import doctools
except ImportError:
    print("\nWARNING: Trying to update documentation, but the python present in the current environment"
          " does not have the needed packages (loristrck, emlib). Documentation will not be"
          " updated\n")
    sys.exit(0)


def main(destfolder: str):
    utilFuncNames = util.__all__
    utilFuncs = [eval("util." + name) for name in utilFuncNames]
    docstr = doctools.generateDocsForFunctions(utilFuncs, title="loristrck.util", pretext=util.__doc__)
    utildocs = os.path.join(destfolder, "util.md")
    open(utildocs, "w").write(docstr)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--destfolder", default="docs", help="Destination forlder for documentation")
    args = parser.parse_args()
    assert os.path.exists(args.destfolder)
    main(args.destfolder)
