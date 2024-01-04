# Copyright 2024 Bartek thindil Jasicki
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

import std/[algorithm, os, strutils, times]
import ../[config, game, tk]
import mainmenucommands, table, utilsui

var mainMenuFrame = ""

proc showMainMenu*()

type SaveSortOrders = enum
  playerAsc, playerDesc, shipAsc, shipDesc, timeAsc, timeDesc

var
  loadTable: TableWidget
  saveSortOrder = timeDesc

proc showLoadGameCommand(clientData: cint; interp: PInterp; argc: cint;
    argv: openArray[cstring]): TclResults =
  if loadTable.rowHeight == 1:
    loadTable = createTable(parent = ".loadmenu.list", headers = @[
        "Player name", "Ship name", "Last saved"], command = "SortSaves",
        tooltipText = "Press mouse button to sort the saved games.")
  else:
    clearTable(table = loadTable)
  type SaveRecord = object
    playerName, shipName, saveTime, fileName: string
  var saves: seq[SaveRecord]
  for file in walkFiles(saveDirectory & "*.sav"):
    let
      (_, name, _) = splitFile(path = file)
      parts = name.split('_')
    if parts.len == 3:
      saves.add(SaveRecord(playerName: parts[0], shipName: parts[1],
          saveTime: file.getLastModificationTime.format("yyyy-MM-dd hh:mm:ss"),
          fileName: file))
    else:
      saves.add(SaveRecord(playerName: "Unknown", shipName: "Unknown",
          saveTime: file.getLastModificationTime.format("yyyy-MM-dd hh:mm:ss"),
          fileName: file))

  proc sortSaves(x, y: SaveRecord): int =
    case saveSortOrder
    of playerAsc:
      if x.playerName < y.playerName:
        return 1
      else:
        return -1
    of playerDesc:
      if x.playerName > y.playerName:
        return 1
      else:
        return -1
    of shipAsc:
      if x.shipName < y.shipName:
        return 1
      else:
        return -1
    of shipDesc:
      if x.shipName > y.shipName:
        return 1
      else:
        return -1
    of timeAsc:
      if x.saveTime < y.saveTime:
        return 1
      else:
        return -1
    of timeDesc:
      if x.saveTime > y.saveTime:
        return 1
      else:
        return -1
  saves.sort(cmp = sortSaves)
  for save in saves:
    addButton(table = loadTable, text = save.playerName,
        tooltip = "Press mouse " & (
        if gameSettings.rightButton: "right" else: "left") &
        " button to show available option", command = "ShowLoadGameMenu " &
        save.fileName, column = 1)
    addButton(table = loadTable, text = save.shipName,
        tooltip = "Press mouse " & (
        if gameSettings.rightButton: "right" else: "left") &
        " button to show available option", command = "ShowLoadGameMenu " &
        save.fileName, column = 2)
    addButton(table = loadTable, text = save.saveTime,
        tooltip = "Press mouse " & (
        if gameSettings.rightButton: "right" else: "left") &
        " button to show available option", command = "ShowLoadGameMenu " &
        save.fileName, column = 3, newRow = true)
  updateTable(table = loadTable)
  if loadTable.row == 1:
    tclEval(script = "bind . <Alt-b> {}")
    tclEval(script = "bind . <Escape> {}")
    tclEval(script = "pack forget .loadmenu")
    showMainMenu()
  return tclOk

proc createMainMenu*() =
  let
    uiDirectory = dataDirectory & "ui" & DirSep
    iconPath = uiDirectory & "images" & DirSep & "icon.png"
    mainWindow = "."
  if not dirExists(iconPath):
    tclEval(script = "wm withdraw " & mainWindow)
    tclEval(script = "tk_messageBox -message {Couldn't not find the game data files and the game have to stop. Are you sure that directory \"" &
        dataDirectory & "\" is the proper place where the game data files exists?} -icon error -type ok")
    tclEval(script = "exit 1")
    return
  let icon = tclEval2(script = "image create photo logo -file {" & iconPath & "}")
  mainmenucommands.addCommands()
  addCommand("ShowLoadGame", showLoadGameCommand)

proc showMainMenu() =
  let mainWindow = "."
  var
    x: int = ((tclEval2(script = "winfo vrootwidth " & mainWindow).parseInt -
        600) / 2).int
    y: int = ((tclEval2(script = "winfo vrootheight " & mainWindow).parseInt -
        400) / 2).int
  if x < 0:
    x = 0
  if y < 0:
    y = 0
  if gameSettings.fullScreen:
    tclEval(script = "wm attributes " & mainWindow & " -fullscreen 0")
  if tclGetVar(varName = "tlc_platform(os)") == "Linux":
    tclEval(script = "wm attributes " & mainWindow & " -zoomed 0")
  else:
    tclEval(script = "wm state " & mainWindow & " normal")
  tclEval(script = "wm title " & mainWindow & " {Steam Sky - Main Menu}")
  tclEval(script = "wm geometry " & mainWindow & " 600x400+" & $x & "+" & $y)
  let gameFrame = ".gameframe"
  if tclEval2(script = "winfo exists " & gameFrame) == "1":
    tclEval(script = "pack forget " & gameFrame)
