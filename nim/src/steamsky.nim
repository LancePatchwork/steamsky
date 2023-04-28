# Copyright 2022-2023 Bartek thindil Jasicki
#
# This file is part of Steam Sky.
#
# Steam Sky is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Steam Sky is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Steam Sky.  If not, see <http://www.gnu.org/licenses/>.

import std/[os, parseopt, strutils]
import bases, basescargo, basestypes, careers, crafts, combat, config, crew,
    crewinventory, events, factions, game, goals, halloffame, items, log, maps,
    messages, missions, mobs, shipmodules, ships, shipscargo, shipscrew,
    shipscrew2, shipsmovement, shipsrepairs, shipsupgrade, statistics, tk, utils
import ui/utilsui

proc steamsky(params: cstring): PInterp {.exportc, raises: [TclError, IOError,
    OSError, ValueError], tags: [ReadIOEffect, RootEffect].} =
  ## The main procedure of the game.
  ##
  ## Returns the pointer to the newly created Tcl interpreter

  # Get the command line params if any
  if params.len() > 0:
    var gameParams = initOptParser(cmdLine = $params)
    for kind, key, val in gameParams.getopt():
      case key
      of "savedir":
        saveDirectory = val & DirSep
        normalizePath(saveDirectory)
      of "debug":
        debugMode = parseEnum[DebugTypes](val)

  # Create the game directories
  createDir(dir = saveDirectory)

  # Start logging
  startLogging()

  # Load the game configuration. TODO: temporary disabled, enable it again
  # when will be needed
  # loadConfig()

  # Create Tcl interpreter
  result = tclCreateInterp()
  # If creation failed, report error and quit
  if result == nil:
    raise newException(exceptn = TclError,
        message = "Can't create Tcl interpreter.")
  # Initialize Tcl. Quit if failed
  if tclInit(interp = result) == tclError:
    raise newException(exceptn = TclError,
        message = "Can't initialize Tcl interpreter.")
  # Initialize Tk. Quit if failed
  if tkInit(interp = result) == tclError:
    raise newException(exceptn = TclError, message = "Can't initialize Tk.")
  setInterp(interp = result)

  # Initialize needed packages
  for package in ["tooltip", "tksvg", "autoscroll"]:
    if result.tclEval(script = ("package require " & package).cstring) == tclError:
      raise newException(exceptn = TclError, message = "Can't initialize " &
          package & " package.")
