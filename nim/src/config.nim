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

import std/[parsecfg, streams, strutils]
import game, types

type
  AutoMoveBreak* = enum
    ## When to stop auto movement of the player's ship: never, on encounter any
    ## ship, friendly ship, enemy ship
    never, any, friendly, enemy

  MessagesOrder* = enum
    ## In what order show the last messages: older messages first, newer messages
    ## first
    olderFirst = "older_First", newerFirst = "newer_First"

  AutoSaveTime* = enum
    ## When save the game automatically: never, after dock to a base, after
    ## undock from a base, every game day, every game month, every game year
    none, dock, undock, daily, monthly, yearly

  GameSettingsRecord* = object
    ## Used to store the game's configuration
    ##
    ## * autoRest              - If true, auto rest when pilot or engineer need a rest
    ## * undockSpeed           - The default speed of the player's ship after undock from a base
    ## * autoCenter            - If true, back to the player's ship after setting destination for it
    ## * autoReturn            - If true, set the destination for the player's ship to the base after
    ##                           finishing a mission
    ## * autoFinish            - If true, automatically finish the mission if the player's ships is in
    ##                           the proper base
    ## * lowFuel               - The amount of fuel at which the game will show the warning
    ##                           about it
    ## * lowDrinks             - The amount of drinks at which the game will show the warning
    ##                           about it
    ## * lowFood               - The amount of food at which the game will show the warning
    ##                           about it
    ## * autoMoveStop          - When stop the player's ship's auto movement
    ## * windowWidth           - The game window default width
    ## * windowHeight          - The game window default height
    ## * messagesLimit         - The max amount of messages to show in the game
    ## * savedMessages         - The max amount of messages to save to a file
    ## * helpFontSize          - The size of a font used in help
    ## * mapFontSize           - The size of a font used on the map
    ## * interfaceFontSize     - The size of a font used in the game interface
    ## * interfaceTheme        - The name of the current theme of the game interface
    ## * messagesOrder         - In what order the messages should be shown
    ## * autoAskForBases       - If true, auto ask for new bases when the player's ship is
    ##                           docked to a base
    ## * autoAskForEvents      - If true, auto ask for new events when the player's ship is
    ##                           docked to a base
    ## * showTooltips          - Show the in-game tooltips with help information
    ## * showLastMessages      - Show the last messages window below the map
    ## * messagesPosition      - The height of the last messages window
    ## * fullScreen            - Run the game in full screen mode
    ## * autoCloseMessagesTime - The amount of seconds after which messages' dialogs
    ##                           will be closed
    ## * autoSave              - How often the game should save itself automatically
    ## * topicsPosition        - The height of the topics' window position in help window
    ## * showNumbers           - If true, show numbers for speed, skills, attributes, etc.
    ## * rightButton           - If true, use the right mouse button for show menus in various lists
    ## * listsLimit            - The amount of items displayed in various lists
    autoRest*: cint
    undockSpeed*: cint
    autoCenter*: cint
    autoReturn*: cint
    autoFinish*: cint
    lowFuel*: cint
    lowDrinks*: cint
    lowFood*: cint
    autoMoveStop*: cstring
    windowWidth*: cint
    windowHeight*: cint
    messagesLimit*: cint
    savedMessages*: cint
    helpFontSize*: cint
    mapFontSize*: cint
    interfaceFontSize*: cint
    interfaceTheme*: cstring
    messagesOrder*: cstring
    autoAskForBases*: cint
    autoAskForEvents*: cint
    showTooltips*: cint
    showLastMessages*: cint
    messagesPosition*: cint
    fullScreen*: cint
    autoCloseMessagesTime*: cint
    autoSave*: cstring
    topicsPosition*: cint
    showNumbers*: cint
    rightButton*: cint
    listsLimit*: cint

  BonusType* = range[0.0..5.0]
    ## Points' multiplier from various game's settings

  DifficultyType* = enum
    ## The level of the game's difficulty. All setttings except custom are preset
    ## levels
    veryEasy, easy, normal, hard, veryHard, custom

  NewGameRecord* = object
    ## Used to store the default settings for the new game
    ##
    ## * playerName             - The player's character name
    ## * playerGender           - The player's character gender
    ## * shipName               - The player's ship name
    ## * playerFaction          - The player's character faction
    ## * playerCareer           - The player's character career
    ## * startingBase           - The type of the starting base
    ## * enemyDamageBonus       - The bonus to damage for enemies in ship to ship combat
    ## * playerDamageBonus      - The bonus to damage for the player's character and crew in
    ##                            ship to ship combat
    ## * enemyMeleeDamageBonus  - The bonus to damage for enemies in melee combat
    ## * playerMeleeDamageBonus - The bonus to damage for the player's character and crew
    ##                            in melee combat
    ## * experienceBonus        - The bonus to the gained by player's character and crew experience
    ## * reputationBonus        - The bonus to the gained the player's character reputation in bases
    ## * upgradeCostBonus       - The bonus to costs of upgrades the player's ship
    ## * pricesBonus            - The bonus to prices in bases
    ## * difficultyLevel        - The preset level of difficulty for the game
    playerName*: cstring
    playerGender*: char
    shipName*: cstring
    playerFaction*: cstring
    playerCareer*: cstring
    startingBase*: cstring
    enemyDamageBonus*: cfloat
    playerDamageBonus*: cfloat
    enemyMeleeDamageBonus*: cfloat
    playerMeleeDamageBonus*: cfloat
    experienceBonus*: cfloat
    reputationBonus*: cfloat
    upgradeCostBonus*: cfloat
    pricesBonus*: cfloat
    difficultyLevel*: cstring

const
  defaultGameSettings* = GameSettingsRecord(autoRest: 1,
    undockSpeed: 4, autoCenter: 1, autoReturn: 1,
    autoFinish: 1, lowFuel: 100, lowDrinks: 50, lowFood: 25,
    autoMoveStop: "never", windowWidth: 800, windowHeight: 600,
    messagesLimit: 500, savedMessages: 10, helpFontSize: 14, mapFontSize: 16,
    interfaceFontSize: 14, interfaceTheme: "steamsky",
    messagesOrder: "older_First", autoAskForBases: 0,
    autoAskForEvents: 0,
    showTooltips: 1, showLastMessages: 1, messagesPosition: 213,
    fullScreen: 0, autoCloseMessagesTime: 6, autoSave: "none",
    topicsPosition: 200, showNumbers: 0, rightButton: 0, listsLimit: 25)
    ## The default setting for the game

  defaultNewGameSettings* = NewGameRecord(playerName: "Laeran",
    playerGender: 'M', shipName: "Anaria", playerFaction: "POLEIS",
    playerCareer: "general", startingBase: "Any", enemyDamageBonus: 1.0,
    playerDamageBonus: 1.0, enemyMeleeDamageBonus: 1.0,
    playerMeleeDamageBonus: 1.0, experienceBonus: 1.0, reputationBonus: 1.0,
    upgradeCostBonus: 1.0, pricesBonus: 1.0, difficultyLevel: "normal")
    ## The default setting for the new game

var
  newGameSettings*: NewGameRecord = defaultNewGameSettings ## The settings for new game
  gameSettings*: GameSettingsRecord = defaultGameSettings ## The general settings for the game

proc loadConfig*() {.sideEffect, raises: [], tags: [RootEffect].} =
  ## Load the game and new game settings from the file
  let fileName = saveDirectory & "game.cfg"
  var configFile = newFileStream(filename = fileName, mode = fmRead)
  if configFile == nil:
    return
  var parser: CfgParser
  try:
    parser.open(input = configFile, filename = fileName)
  except OSError, IOError, Exception:
    echo "Can't initialize configuration file parser. Reason: " &
        getCurrentExceptionMsg()
    return

  proc parseAdaFloat(value: string): cfloat =
    ## Temporary function, for backward compatibility with Ada code
    var newValue = value
    newValue.removeSuffix(c = 'E')
    return newValue.parseFloat().cfloat
  proc parseAdaBool(value: string): cint =
    ## Temporary function, for backward compatibility with Ada code
    if value == "Yes":
      return 1
    return 0

  while true:
    try:
      let entry = parser.next()
      case entry.kind
      of cfgEof:
        break
      of cfgKeyValuePair, cfgOption:
        case entry.key
        of "PlayerName":
          newGameSettings.playerName = entry.value.cstring
        of "PlayerGender":
          newGameSettings.playerGender = entry.value[0]
        of "ShipName":
          newGameSettings.shipName = entry.value.cstring
        of "PlayerFaction":
          newGameSettings.playerFaction = entry.value.cstring
        of "PlayerCareer":
          newGameSettings.playerCareer = entry.value.cstring
        of "StartingBase":
          newGameSettings.startingBase = entry.value.cstring
        of "EnemyDamageBonus":
          newGameSettings.enemyDamageBonus = entry.value.parseAdaFloat()
        of "PlayerDamageBonus":
          newGameSettings.playerDamageBonus = entry.value.parseAdaFloat()
        of "EnemyMeleeDamageBonus":
          newGameSettings.enemyMeleeDamageBonus = entry.value.parseAdaFloat()
        of "PlayerMeleeDamageBonus":
          newGameSettings.playerMeleeDamageBonus = entry.value.parseAdaFloat()
        of "ExperienceBonus":
          newGameSettings.experienceBonus = entry.value.parseAdaFloat()
        of "ReputationBonus":
          newGameSettings.reputationBonus = entry.value.parseAdaFloat()
        of "UpgradeCostBonus":
          newGameSettings.upgradeCostBonus = entry.value.parseAdaFloat()
        of "PricesBonus":
          newGameSettings.pricesBonus = entry.value.parseAdaFloat()
        of "DifficultyLevel":
          newGameSettings.difficultyLevel = ($parseEnum[DifficultyType](
              entry.value.toLowerAscii)).cstring
        of "AutoRest":
          gameSettings.autoRest = entry.value.parseAdaBool()
        of "UndockSpeed":
          gameSettings.undockSpeed = (parseEnum[ShipSpeed](
              entry.value.toLowerAscii)).ord.cint
        of "AutoCenter":
          gameSettings.autoCenter = entry.value.parseAdaBool()
        of "AutoReturn":
          gameSettings.autoReturn = entry.value.parseAdaBool()
        of "AutoFinish":
          gameSettings.autoFinish = entry.value.parseAdaBool()
        of "LowFuel":
          gameSettings.lowFuel = entry.value.parseInt().cint
        of "LowDrinks":
          gameSettings.lowDrinks = entry.value.parseInt().cint
        of "LowFood":
          gameSettings.lowFood = entry.value.parseInt().cint
        of "AutoMoveStop":
          gameSettings.autoMoveStop = ($parseEnum[AutoMoveBreak](
              entry.value.toLowerAscii)).cstring
        of "WindowWidth":
          gameSettings.windowWidth = entry.value.parseInt().cint
        of "WindowHeight":
          gameSettings.windowHeight = entry.value.parseInt().cint
        of "MessagesLimit":
          gameSettings.messagesLimit = entry.value.parseInt().cint
        of "SavedMessages":
          gameSettings.savedMessages = entry.value.parseInt().cint
        of "HelpFontSize":
          gameSettings.helpFontSize = entry.value.parseInt().cint
        of "MapFontSize":
          gameSettings.mapFontSize = entry.value.parseInt().cint
        of "InterfaceFontSize":
          gameSettings.interfaceFontSize = entry.value.parseInt().cint
        of "InterfaceTheme":
          gameSettings.interfaceTheme = entry.value.cstring
        of "MessagesOrder":
          gameSettings.messagesOrder = ($parseEnum[MessagesOrder](
              entry.value.toLowerAscii)).cstring
        of "AutoAskForBases":
          gameSettings.autoAskForBases = entry.value.parseAdaBool()
        of "AutoAskForEvents":
          gameSettings.autoAskForEvents = entry.value.parseAdaBool()
        of "ShowTooltips":
          gameSettings.showTooltips = entry.value.parseAdaBool()
        of "ShowLastMessages":
          gameSettings.showLastMessages = entry.value.parseAdaBool()
        of "MessagesPosition":
          gameSettings.messagesPosition = entry.value.parseInt().cint
        of "FullScreen":
          gameSettings.fullScreen = entry.value.parseAdaBool()
        of "AutoCloseMessagesTime":
          gameSettings.autoCloseMessagesTime = entry.value.parseInt().cint
        of "AutoSave":
          gameSettings.autoSave = ($parseEnum[AutoSaveTime](
              entry.value.toLowerAscii)).cstring
        of "TopicsPosition":
          gameSettings.topicsPosition = entry.value.parseInt().cint
        of "ShowNumbers":
          gameSettings.showNumbers = entry.value.parseAdaBool()
        of "RightButton":
          gameSettings.rightButton = entry.value.parseAdaBool()
        of "ListsLimit":
          gameSettings.listsLimit = entry.value.parseInt().cint
        else:
          discard
      of cfgError:
        echo entry.msg
      of cfgSectionStart:
        discard
    except ValueError, OSError, IOError:
      echo "Invalid data in the game configuration file. Details: " &
          getCurrentExceptionMsg()
      continue
  try:
    parser.close()
  except OSError, IOError, Exception:
    echo "Can't close configuration file parser. Reason: " &
        getCurrentExceptionMsg()

proc saveConfig*() =
  var config = newConfig()

  proc saveAdaBoolean(value: cint, name: string) =
    ## Temporary function, for backward compatibility with Ada code
    if value == 1:
      config.setSectionKey("", name, "Yes")
    else:
      config.setSectionKey("", name, "No")

  config.setSectionKey("", "PlayerName", $newGameSettings.playerName)
  config.setSectionKey("", "PlayerGender", $newGameSettings.playerGender)
  config.setSectionKey("", "ShipName", $newGameSettings.shipName)
  config.setSectionKey("", "PlayerFaction", $newGameSettings.playerFaction)
  config.setSectionKey("", "PlayerCareer", $newGameSettings.playerCareer)
  config.setSectionKey("", "StartingBase", $newGameSettings.startingBase)
  config.setSectionKey("", "EnemyDamageBonus",
      $newGameSettings.enemyDamageBonus)
  config.setSectionKey("", "PlayerDamageBonus",
      $newGameSettings.playerDamageBonus)
  config.setSectionKey("", "EnemyMeleeDamageBonus",
      $newGameSettings.enemyMeleeDamageBonus)
  config.setSectionKey("", "PlayerMeleeDamageBonus",
      $newGameSettings.playerMeleeDamageBonus)
  config.setSectionKey("", "ExperienceBonus", $newGameSettings.experienceBonus)
  config.setSectionKey("", "ReputationBonus", $newGameSettings.reputationBonus)
  config.setSectionKey("", "UpgradeCostBonus",
      $newGameSettings.upgradeCostBonus)
  config.setSectionKey("", "PricesBonus", $newGameSettings.pricesBonus)
  config.setSectionKey("", "DifficultyLevel", (
      $newGameSettings.difficultyLevel).toUpperAscii)
  saveAdaBoolean(value = gameSettings.autoRest, name = "AutoRest")
  config.setSectionKey("", "UndockSpeed", (
      $gameSettings.undockSpeed).toUpperAscii)
  saveAdaBoolean(value = gameSettings.autoCenter, name = "AutoCenter")
  saveAdaBoolean(value = gameSettings.autoReturn, name = "AutoReturn")
  saveAdaBoolean(value = gameSettings.autoFinish, name = "AutoFinish")
  config.setSectionKey("", "LowFuel", $gameSettings.lowFuel)
  config.setSectionKey("", "LowDrinks", $gameSettings.lowDrinks)
  config.setSectionKey("", "LowFood", $gameSettings.lowFood)
  config.setSectionKey("", "AutoMoveStop", (
      $gameSettings.autoMoveStop).toUpperAscii)
  config.setSectionKey("", "WindowWidth", $gameSettings.windowWidth)
  config.setSectionKey("", "WindowHeight", $gameSettings.windowHeight)
  config.setSectionKey("", "MessagesLimit", $gameSettings.messagesLimit)
  config.setSectionKey("", "SavedMessages", $gameSettings.savedMessages)
  config.setSectionKey("", "HelpFontSize", $gameSettings.helpFontSize)
  config.setSectionKey("", "MapFontSize", $gameSettings.mapFontSize)
  config.setSectionKey("", "InterfaceFontSize", $gameSettings.interfaceFontSize)
  config.setSectionKey("", "InterfaceTheme", $gameSettings.interfaceTheme)
  config.setSectionKey("", "MessagesOrder", $gameSettings.messagesOrder)
  saveAdaBoolean(value = gameSettings.autoAskForBases, name = "AutoAskForBases")
  saveAdaBoolean(value = gameSettings.autoAskForEvents,
      name = "AutoAskForEvents")
  saveAdaBoolean(value = gameSettings.showTooltips, name = "ShowTooltips")
  saveAdaBoolean(value = gameSettings.showLastMessages,
      name = "ShowLastMessages")
  config.setSectionKey("", "MessagesPosition", $gameSettings.messagesPosition)
  saveAdaBoolean(value = gameSettings.fullScreen, name = "FullScreen")
  config.setSectionKey("", "AutoCloseMessagesTime",
      $gameSettings.autoCloseMessagesTime)
  config.setSectionKey("", "AutoSave", ($gameSettings.autoSave).toUpperAscii)
  config.setSectionKey("", "TopicsPosition", $gameSettings.topicsPosition)
  saveAdaBoolean(value = gameSettings.showNumbers, name = "ShowNumbers")
  saveAdaBoolean(value = gameSettings.rightButton, name = "RightButton")
  config.setSectionKey("", "ListsLimit", $gameSettings.listsLimit)
  config.writeConfig(saveDirectory & "game.cfg")

# Temporary code for interfacing with Ada

proc loadAdaConfig(adaNewGameSettings: var NewGameRecord;
    adaGameSettings: var GameSettingsRecord) {.sideEffect, raises: [], tags: [
    RootEffect], exportc.} =
  ## Temporary code to load the game configuration and copy it to the Ada
  ## code
  ##
  ## * adaNewGameSettings - The new game settings which will be copied
  ## * adaGameSettings    - The game settings which will be copied
  ##
  ## Returns the updated parameters adaNewGameSettings and adaGameSettings
  loadConfig()
  adaNewGameSettings = newGameSettings
  adaGameSettings = gameSettings

proc getAdaNewGameSettings(adaNewGameSettings: NewGameRecord) {.sideEffect,
    raises: [], tags: [], exportc.} =
  newGameSettings = adaNewGameSettings

proc setAdaMessagesPosition(newValue: cint) {.sideEffect, raises: [], tags: [], exportc.} =
  gameSettings.messagesPosition = newValue


proc saveAdaConfig(adaNewGameSettings: NewGameRecord;
    adaGameSettings: GameSettingsRecord) {.sideEffect, raises: [], tags: [
    RootEffect], exportc.} =
  # Temporary disabled, enable it after finished Ada code
  #newGameSettings = adaNewGameSettings
  #gameSettings = adaGameSettings
  try:
    saveConfig()
  except KeyError, IOError, OSError:
    discard
