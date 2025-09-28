# Copyright 2024-2025 Bartek thindil Jasicki
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

## Provides code related to showing the main game's menu, like creating it.

import std/[os, tables]
import contracts
import ../[basestypes, careers, config, game, game2, tk]
import dialogs2, errordialog, goalsui, mainmenucommands, showmainmenu,
    table, themes, utilsui, utilsui2

proc createMainMenu*() =
  ## Create and show the main game menu
  if not gameSettings.showTooltips:
    tclEval(script = "tooltip::tooltip disable")
  setFonts(newSize = gameSettings.mapFontSize, fontType = mapFont)
  setFonts(newSize = gameSettings.helpFontSize, fontType = helpFont)
  setFonts(newSize = gameSettings.interfaceFontSize, fontType = interfaceFont)
  const versionLabel: string = ".mainmenu.version"
  tclEval(script = versionLabel & " configure -text {" & gameVersion & " development}")
  try:
    dataError = loadGameData()
  except:
    dataError = getCurrentExceptionMsg()
    showMainMenu()
  if dataError.len > 0:
    return
  const playerFrameName: string = ".newgamemenu.canvas.player"
  var textEntry: string = playerFrameName & ".playername"
  tclEval(script = textEntry & " delete 0 end")
  tclEval(script = textEntry & " insert 0 {" & newGameSettings.playerName & "}")
  tclSetVar(varName = "playergender", newValue = $newGameSettings.playerGender)
  textEntry = playerFrameName & ".shipname"
  tclEval(script = textEntry & " delete 0 end")
  tclEval(script = textEntry & " insert 0 {" & newGameSettings.shipName & "}")
  var values: string = ""
  for faction in factionsList.values:
    if faction.careers.len > 0:
      values = values & " {" & faction.name & "}"
  values.add(y = " Random")
  var comboBox: string = playerFrameName & ".faction"
  tclEval(script = comboBox & " configure -values [list" & values & "]")
  if newGameSettings.playerFaction == "random":
    tclEval(script = comboBox & " set Random")
  else:
    try:
      discard tclEval(script = comboBox & " set {" & factionsList[
          newGameSettings.playerFaction].name & "}")
    except:
      showError(message = "Can't set player's faction.")
  tclEval(script = "SetFaction")
  comboBox = playerFrameName & ".career"
  if newGameSettings.playerCareer == "random":
    tclEval(script = comboBox & " set Random")
  else:
    try:
      discard tclEval(script = comboBox & " set {" & careersList[
          newGameSettings.playerCareer].name & "}")
    except:
      showError(message = "Can't set player's career")
  comboBox = playerFrameName & ".base"
  try:
    discard tclEval(script = comboBox & " set " & (
        if newGameSettings.startingBase == "Any": "Any" else: "{" &
        basesTypesList[newGameSettings.startingBase].name & "}"))
  except:
    showError(message = "Can't set starting base.")
  const difficultyFrameName: string = ".newgamemenu.canvas.difficulty"
  comboBox = difficultyFrameName & ".difficultylevel"
  var spinBox: string = difficultyFrameName & ".enemydamage"
  tclEval(script = spinBox & " set " & $((newGameSettings.enemyDamageBonus *
      100.0).Natural))
  spinBox = difficultyFrameName & ".playerdamage"
  tclEval(script = spinBox & " set " & $((newGameSettings.playerDamageBonus *
      100.0).Natural))
  spinBox = difficultyFrameName & ".enemymeleedamage"
  tclEval(script = spinBox & " set " & $((
      newGameSettings.enemyMeleeDamageBonus * 100.0).Natural))
  spinBox = difficultyFrameName & ".playermeleedamage"
  tclEval(script = spinBox & " set " & $((
      newGameSettings.playerMeleeDamageBonus * 100.0).Natural))
  spinBox = difficultyFrameName & ".experience"
  tclEval(script = spinBox & " set " & $((newGameSettings.experienceBonus *
      100.0).Natural))
  spinBox = difficultyFrameName & ".reputation"
  tclEval(script = spinBox & " set " & $((newGameSettings.reputationBonus *
      100.0).Natural))
  spinBox = difficultyFrameName & ".upgrade"
  tclEval(script = spinBox & " set " & $((newGameSettings.upgradeCostBonus *
      100.0).Natural))
  spinBox = difficultyFrameName & ".prices"
  tclEval(script = spinBox & " set " & $((newGameSettings.pricesBonus *
      100.0).Natural))
  tclEval(script = "SetPoints")
  tclEval(script = comboBox & " current " & $(
      newGameSettings.difficultyLevel.ord))
  tclEval(script = "event generate " & comboBox & " <<ComboboxSelected>>")
  var button: string = ".newgamemenu.canvas.player.randomplayer"
  tclEval(script = button & " configure -image randomicon")
  button = ".newgamemenu.canvas.player.randomship"
  tclEval(script = button & " configure -image randomicon")
  button = ".newgamemenu.canvas.player.gender.male"
  tclEval(script = button & " configure -image maleicon")
  button = ".newgamemenu.canvas.player.gender.female"
  tclEval(script = button & " configure -image femaleicon")
  showMainMenu()
