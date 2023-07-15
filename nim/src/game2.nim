# Copyright 2023 Bartek thindil Jasicki
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

import std/[os, strutils, tables, xmlparser, xmltree]
import bases, basescargo, basesship, basestypes, careers, config, crafts, crew,
    events, factions, game, gamesaveload, goals, help, items, log, maps,
    messages, missions, mobs, shipmodules, ships, shipscrew, shipsrepairs,
    shipsupgrade, statistics, stories, types, utils

proc updateGame*(minutes: Positive; inCombat: bool = false) {.sideEffect,
    raises: [KeyError, IOError, Exception], tags: [WriteIOEffect,
    RootEffect].} =
  ## Update the game (player ship, bases, crafting, etc)
  ##
  ## * minutes  - the amount of in-game minutes which passes
  ## * inCombat - if true, the player is in combat
  var needCleaning, needSaveGame = false

  proc updateDay() =
    gameDate.day.inc
    for module in playerShip.modules.mitems:
      if module.mType == ModuleType2.cabin and module.cleanliness > 0:
        module.cleanliness.dec
        needCleaning = true
    if needCleaning:
      updateOrders(ship = playerShip)
    if playerShip.speed == docked:
      payForDock()
    dailyPayment()
    if $gameSettings.autoSave == $daily:
      needSaveGame = true

  var tiredPoints = 0
  for i in 1 .. minutes:
    if (gameDate.minutes + i) mod 15 == 0:
      tiredPoints.inc
  let addedMinutes = minutes mod 60
  gameDate.minutes = gameDate.minutes + addedMinutes
  if gameDate.minutes > 59:
    gameDate.minutes = gameDate.minutes - 60
    gameDate.hour.inc
  var addedHours = (minutes / 60).int
  while addedHours > 23:
    addedHours = addedHours - 24
    updateDay()
  gameDate.hour = gameDate.hour + addedHours
  while gameDate.hour > 23:
    gameDate.hour = gameDate.hour - 24
    updateDay()
  if needSaveGame:
    saveGame()
  if gameDate.month > 12:
    gameDate.month = 1
    gameDate.year.inc
    if $gameSettings.autoSave == $yearly:
      saveGame()
  updateCrew(minutes = minutes, tiredPoints = tiredPoints, inCombat = inCombat)
  repairShip(minutes = minutes)
  manufacturing(minutes = minutes)
  upgradeShip(minutes = minutes)
  let baseIndex = skyMap[playerShip.skyX][playerShip.skyY].baseIndex
  if baseIndex > 0:
    if skyBases[baseIndex].visited.year == 0:
      gameStats.basesVisited.inc
      gameStats.points.inc
      updateGoal(goalType = visit, targetIndex = skyBases[baseIndex].owner)
    skyBases[baseIndex].visited = gameDate
    if not skyBases[baseIndex].known:
      skyBases[baseIndex].known = true
      addMessage(message = "You discovered base " & skyBases[baseIndex].name &
          ".", mType = otherMessage)
    updatePopulation()
    generateRecruits()
    generateMissions()
    generateCargo()
    updatePrices()
    updateOrders(ship = playerShip)
  if not skyMap[playerShip.skyX][playerShip.skyY].visited:
    gameStats.mapVisited.inc
    gameStats.points.inc
    updateGoal(goalType = discover, targetIndex = "")
    skyMap[playerShip.skyX][playerShip.skyY].visited = true
  updateEvents(minutes = minutes)
  updateMissions(minutes = minutes)

proc loadGameData*(): string {.sideEffect, raises: [DataLoadingError, KeyError,
    OSError], tags: [WriteIOEffect, RootEffect].} =
  ## Load the game's data from files
  ##
  ## Returns empty string if the data loaded properly, otherwise message with
  ## information what was wrong.
  result = ""
  if protoShipsList.len > 0:
    return

  proc loadSelectedData(dataName, fileName: string): string {.sideEffect,
      raises: [DataLoadingError, KeyError, OSError], tags: [WriteIOEffect,
      RootEffect].} =

    var localFileName: string
    proc loadDataFile(localDataName: string): string {.sideEffect, raises: [
        DataLoadingError, KeyError], tags: [WriteIOEffect, RootEffect].} =
      let dataXml = try:
          loadXml(path = localFileName)
        except XmlError, ValueError, IOError, OSError, Exception:
          return getCurrentExceptionMsg()
      var dataType: string
      dataType = dataXml.tag
      if dataType == localDataName or localDataName.len == 0:
        logMessage(message = "Loading " & dataType & " file: " & localFileName,
            debugType = everything)
        case dataType
        of "factions":
          loadFactions(fileName = localFileName)
        of "goals":
          loadGoals(fileName = localFileName)
        of "help":
          loadHelp(fileName = localFileName)
        of "items":
          loadItems(fileName = localFileName)
        of "mobiles":
          loadMobs(fileName = localFileName)
        of "recipes":
          loadRecipes(fileName = localFileName)
        of "bases":
          loadBasesTypes(fileName = localFileName)
        of "modules":
          loadModules(fileName = localFileName)
        of "ships":
          loadShips(fileName = localFileName)
        of "stories":
          loadStories(fileName = localFileName)
        of "data":
          loadData(fileName = localFileName)
        of "careers":
          loadCareers(fileName = localFileName)
        else:
          return "Can't load the game data. Unknown type of data: " & dataType

    if fileName.len == 0:
      for file in walkFiles(dataName & DirSep & "*.dat"):
        localFileName = file
        result = loadDataFile(localDataName = "")
        if result.len > 0:
          return
    else:
      localFileName = dataDirectory & fileName
      result = loadDataFile(localDataName = dataName)

  type DataTypeRecord = object
    name: string
    fileName: string
  const dataTypes: array[1..12, DataTypeRecord] = [DataTypeRecord(name: "data",
      fileName: "game.dat"), DataTypeRecord(name: "items",
      fileName: "items.dat"), DataTypeRecord(name: "modules",
      fileName: "shipmodules.dat"), DataTypeRecord(name: "recipes",
      fileName: "recipes.dat"), DataTypeRecord(name: "bases",
      fileName: "bases.dat"), DataTypeRecord(name: "mobiles",
      fileName: "mobs.dat"), DataTypeRecord(name: "careers",
      fileName: "careers.dat"), DataTypeRecord(name: "factions",
      fileName: "factions.dat"), DataTypeRecord(name: "help",
      fileName: "help.dat"), DataTypeRecord(name: "ships",
      fileName: "ships.dat"), DataTypeRecord(name: "goals",
      fileName: "goals.dat"), DataTypeRecord(name: "stories",
      fileName: "stories.dat")]
  # Load the standard game data
  for dataType in dataTypes:
    result = loadSelectedData(dataName = dataType.name,
        fileName = dataType.fileName)
    if result.len > 0:
      return
  # Load the modifications
  for modDirectory in walkDirs(modsDirectory & "*"):
    result = loadSelectedData(dataName = modDirectory, fileName = "")
    if result.len > 0:
      return
  setToolsList()

proc endGame*(save: bool) {.sideEffect, raises: [KeyError, IOError, OSError],
    tags: [WriteIOEffect, RootEffect].} =
  ## Save or not the game and clear the temporary data
  ##
  ## * save - if true, save the current game
  if save:
    saveGame()
  else:
    removeFile(saveName)
  saveConfig()
  clearGameStats()
  clearCurrentGoal()
  messagesList = @[]
  knownRecipes = @[]
  eventsList = @[]

proc newGame*() =
  # Save the game configuration
  saveConfig()
  # Set the game statistics
  clearGameStats()
  if newGameSettings.playerFaction == "random":
    newGameSettings.playerCareer = "random"
    var index = 1
    let roll = getRandom(1, factionsList.len)
    for faction in factionsList.keys:
      if index == roll:
        newGameSettings.playerFaction = faction
        break
      index.inc
  let playerFaction = factionsList[newGameSettings.playerFaction]
  if newGameSettings.playerCareer == "random":
    let roll = getRandom(1, playerFaction.careers.len)
    var index = 1
    for career in playerFaction.careers.keys:
      if index == roll:
        newGameSettings.playerCareer = career
        break
      index.inc
  # Set the game time
  gameDate = startDate
  # Generate the game's world
  for x in MapXRange.low .. MapXRange.high:
    for y in MapYRange.low .. MapYRange.high:
      skyMap[x][y] = SkyCell(baseIndex: 0, visited: false, eventIndex: -1,
          missionIndex: -1)
  var
    maxSpawnRoll = 0
    basesArray = initTable[string, seq[Positive]]()
  for index, faction in factionsList:
    maxSpawnRoll = maxSpawnRoll + faction.spawnChance
    basesArray[index] = @[]
  for i in skyBases.low .. skyBases.high:
    var
      baseOwner, baseType: string
      basePopulation, baseReputation: Natural
      factionRoll = getRandom(1, maxSpawnRoll)
      baseSize: BasesSize
    for index, faction in factionsList:
      if factionRoll < faction.spawnChance:
        baseOwner = index
        basePopulation = (if faction.population[1] == 0: faction.population[
            0] else: getRandom(faction.population[0], faction.population[1]))
        baseReputation = getReputation(sourceFaction = newGameSettings.playerFaction,
            targetFaction = index)
        var maxBaseSpawnRoll = 0
        for spawnChance in faction.basesTypes.values:
          maxBaseSpawnRoll = maxBaseSpawnRoll + spawnChance
        var baseTypeRoll = getRandom(min = 1, max = maxBaseSpawnRoll)
        for tindex, baseTypeChance in faction.basesTypes:
          if baseTypeRoll <= baseTypeChance:
            baseType = tindex
            break
          baseTypeRoll = baseTypeRoll - baseTypeChance
      factionRoll = factionRoll - faction.spawnChance
    baseSize = (if basePopulation == 0: getRandom(0,
        2).BasesSize elif basePopulation < 150: small elif basePopulation <
        300: medium else: big)
    skyBases[i].name = generateBaseName(factionIndex = baseOwner)
    skyBases[i].visited = DateRecord(year: 0, month: 0, day: 0, hour: 0, minutes: 0)
    skyBases[i].skyX = 1
    skyBases[i].skyY = 1
    skyBases[i].baseType = baseType
    skyBases[i].population = basePopulation
    skyBases[i].recruitDate = DateRecord(year: 0, month: 0, day: 0, hour: 0, minutes: 0)
    skyBases[i].known = false
    skyBases[i].askedForBases = false
    skyBases[i].askedForEvents = DateRecord(year: 0, month: 0, day: 0, hour: 0, minutes: 0)
    skyBases[i].reputation = ReputationData(level: baseReputation, experience: 0)
    skyBases[i].missionsDate = DateRecord(year: 0, month: 0, day: 0, hour: 0, minutes: 0)
    skyBases[i].missions = @[]
    skyBases[i].owner = baseOwner
    skyBases[i].size = baseSize
    skyBases[i].recruits = @[]
    let baseFaction = factionsList[baseOwner]
    if "loner" in baseFaction.flags:
      factionRoll = getRandom(min = 1, max = maxSpawnRoll)
      for index, faction in factionsList:
        if factionRoll > faction.spawnChance:
          factionRoll = factionRoll - faction.spawnChance
        else:
          baseOwner = index
    basesArray[baseOwner].add(i)
  for factionBases in basesArray.values:
    for index, faction in factionBases:
      var
        attempts = 1
        posX, posY: cint = 0
      while true:
        var validLocation = true
        if index == factionBases.low or ("loner" in factionsList[skyBases[
            factionBases[0]].owner].flags and "loner" in factionsList[skyBases[
            faction].owner].flags):
          posX = getRandom(min = BasesRange.low + 5, max = BasesRange.high - 5).cint
          posY = getRandom(min = BasesRange.low + 5, max = BasesRange.high - 5).cint
        else:
          posX = getRandom(min = skyBases[factionBases[index - 1]].skyX - 20,
              max = skyBases[factionBases[index - 1]].skyX + 20).cint
          normalizeCoord(coord = posX)
          posY = getRandom(min = skyBases[factionBases[index - 1]].skyY - 20,
              max = skyBases[factionBases[index - 1]].skyY + 20).cint
          normalizeCoord(coord = posY, isXAxis = 0)
          attempts.inc
          if attempts > 250:
            posX = getRandom(min = BasesRange.low, max = BasesRange.high).cint
            posY = getRandom(min = BasesRange.low, max = BasesRange.high).cint
            attempts = 1
        for j in -5 .. 5:
          var tempX: cint = posX + j.cint
          normalizeCoord(coord = tempX)
          for k in -5 .. 5:
            var tempY: cint = posY + k.cint
            normalizeCoord(coord = tempY, isXAxis = 0)
            if skyMap[tempX][tempY].baseIndex > 0:
              validLocation = false
              break
          if not validLocation:
            break
        if skyMap[posX][posY].baseIndex > 0:
          validLocation = false
        if validLocation:
          break
      skyMap[posX][posY] = SkyCell(baseIndex: faction, visited: false,
          eventIndex: -1, missionIndex: -1)
  # Place the player's ship in a random large base
  var randomBase: Positive
  while true:
    randomBase = getRandom(min = 1, max = 1024)
    if skyBases[randomBase].population > 299:
      if newGameSettings.startingBase == "Any":
        break
      elif skyBases[randomBase].owner == newGameSettings.playerFaction and
          skyBases[randomBase].baseType == newGameSettings.startingBase:
        break
  # Create the player's ship
  playerShip = createShip(protoIndex = playerFaction.careers[
      newGameSettings.playerCareer].shipIndex, name = newGameSettings.shipName,
      x = skyBases[randomBase].skyX, y = skyBases[randomBase].skyY,
      speed = docked, randomUpgrades = false)
  # Add the player to the ship
  let
    playerIndex2 = playerFaction.careers[
        newGameSettings.playerCareer].playerIndex.parseInt
    protoPlayer = protoMobsList[playerIndex2]
  var tmpInventory: seq[InventoryData]
  for item in protoPlayer.inventory:
    let amount = (if item.maxAmount > 0: getRandom(min = item.minAmount,
        max = item.maxAmount) else: item.minAmount)
    tmpInventory.add(y = InventoryData(protoIndex: item.protoIndex,
        amount: amount, name: "", durability: 100, price: 0))

# Temporary code for interfacing with Ada

proc updateAdaGame(minutes, inCombat: cint) {.raises: [], tags: [WriteIOEffect,
    RootEffect], exportc.} =
  try:
    updateGame(minutes = minutes, inCombat = inCombat == 1)
  except ValueError, IOError, Exception:
    discard

proc loadAdaGameData(): cstring {.raises: [], tags: [WriteIOEffect, RootEffect], exportc.} =
  try:
    return loadGameData().cstring
  except DataLoadingError, KeyError, OSError:
    return getCurrentExceptionMsg().cstring

proc endAdaGame(save: cint) {.raises: [], tags: [WriteIOEffect, RootEffect], exportc.} =
  try:
    endGame(save = (if save == 1: true else: false))
  except KeyError, OSError, IOError:
    discard
