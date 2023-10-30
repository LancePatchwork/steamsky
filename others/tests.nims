#!/usr/bin/env -S nim --hints:off

import std/strutils

if not fileExists("steamsky.gpr"):
  echo "This script must be run in the directory where steamsky.gpr file is"
  quit QuitFailure

# Run Nim tests
withDir "nim":
  for i in 1..parseInt(paramStr(paramCount())):
    echo i
    try:
      exec "testament all"
    except:
      discard
    for file in listFiles("newtests"):
      if file.endsWith("nim"):
        exec "nim c --verbosity:0 --NimblePath:/root/.nimble -r " & file
