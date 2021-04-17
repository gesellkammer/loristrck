#!/usr/bin/env python3
import loristrck as lt
from loristrck import util
from emlib import doctools
from typing import List, Callable
import io
import os
import argparse
from emlib import doctools


def main(destfolder: str):
    utilFuncNames = util.__all__
    utilFuncs = [eval("util." + name) for name in utilFuncNames]
    docstr = doctools.generateDocsForFunctions(utilFuncs, title="loristrck.util", pretext=util.__doc__)
    utildocs = os.path.join(destfolder, "util.md")
    open(utildocs, "w").write(docstr)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--docs", default="docs")
    args = parser.parse_args()
    main(args.docs)
