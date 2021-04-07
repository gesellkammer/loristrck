import loristrck as lt
from loristrck import util
from emlib import doctools
from typing import List, Callable
import io
import os
import argparse

def generateDocsForFunctions(funcs: List[Callable], title:str, pretext:str="") -> str:
    stream = io.StringIO()
    sep = "\n----------\n"
    _ = stream.write
    _(f"# {title}\n\n")
    if pretext:
        _(pretext)
    lasti = len(funcs) - 1
    for i, func in enumerate(funcs):
        print("Parsing func ", func)
        parsedDef = doctools.parseFunctionDefinition(func)
        print("... rendering documentation")
        docstr = doctools.renderDocumentation(parsedDef, startLevel=2, fmt="markdown", docfmt="markdown")
        _(docstr)
        if i < lasti:
            _(sep)
    return stream.getvalue()


def main(destfolder: str):
    utilFuncNames = util.__all__
    utilFuncs = [eval("util." + name) for name in utilFuncNames]
    docstr = generateDocsForFunctions(utilFuncs, "loristrck.util", pretext=util.__doc__)
    utildocs = os.path.join(destfolder, "util.md")
    open(utildocs, "w").write(docstr)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--docs", default="docs")
    args = parser.parse_args()
    main(args.docs)
