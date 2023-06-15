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

import std/tables
import config, game, types

type
  StatisticsData* = object
    ## Used to store detailed information about some the player's game's
    ## statistics
    ##
    ## * index  - The index of the prototype object
    ## * amount - The amount of the object
    index*: string
    amount*: Positive

  GameStatsData = object
    ## Used to store information about the player's game's statistics
    ##
    ## * destroyedShips   - The list of destroyed ships
    ## * basesVisited     - The amount of visited bases
    ## * mapVisited       - The amount of visited map fields
    ## * distanceTraveled - The length of the traveled distance
    ## * craftingOrders   - The list of finished crafting orders
    ## * acceptedMissions - The amount of accepted missions
    ## * finishedMissions - The list of finished missions
    ## * finishedGoals    - The list of finished goals
    ## * killedMobs       - The list of enemies killed
    ## * points           - The amount of points gained in the game's session
    destroyedShips*: seq[StatisticsData]
    basesVisited*: BasesRange
    mapVisited*: Positive
    distanceTraveled*: Natural
    craftingOrders*: seq[StatisticsData]
    acceptedMissions*: Natural
    finishedMissions*: seq[StatisticsData]
    finishedGoals*: seq[StatisticsData]
    killedMobs*: seq[StatisticsData]
    points*: Natural

var gameStats* = GameStatsData(basesVisited: 1, mapVisited: 1,
    distanceTraveled: 0, acceptedMissions: 0, points: 0) ## The player's game's statistics

proc updateCraftingOrders*(index: string) {.sideEffect, raises: [], tags: [].} =
  ## Update the list of finished crafting orders in the game statistics
  ##
  ## * index - the index of the crafting order to update
  var updated = false
  for craftingOrder in gameStats.craftingOrders.mitems:
    if craftingOrder.index == index:
      craftingOrder.amount.inc
      updated = true
      break
  if not updated:
    gameStats.craftingOrders.add(y = StatisticsData(index: index, amount: 1))
  gameStats.points = gameStats.points + 5

proc updateFinishedGoals*(index: string) {.sideEffect, raises: [], tags: [].} =
  ## Update the list of finished goals in the game statistics
  ##
  ## * index - the index of the goal to update
  var updated = false
  for goal in goalsList.values:
    if goal.index == index:
      gameStats.points = gameStats.points + (goal.amount * goal.multiplier)
      break
  for goal in gameStats.finishedGoals.mitems:
    if goal.index == index:
      goal.amount.inc
      updated = true
      break
  if not updated:
    for goal in goalsList.values:
      if goal.index == index:
        gameStats.finishedGoals.add(y = StatisticsData(index: goal.index, amount: 1))

proc getGamePoints*(): Natural {.sideEffect, raises: [], tags: [].} =
  ## Get the real amount of the player's game's points, multiplied or divided
  ## by the game's difficulty settings
  ##
  ## Returns the real amount of the player's game's points
  const malusIndexes = [1, 3, 4, 5]
  let difficultyValues = [newGameSettings.enemyDamageBonus,
      newGameSettings.playerDamageBonus, newGameSettings.enemyMeleeDamageBonus,
      newGameSettings.playerMeleeDamageBonus, newGameSettings.experienceBonus,
      newGameSettings.reputationBonus, newGameSettings.upgradeCostBonus]
  var pointsBonus, value = 0.0
  for index, difficulty in difficultyValues.pairs:
    value = difficulty.float
    for malus in malusIndexes:
      if index == malus:
        if value < 1.0:
          value = 1.0 + ((1.0 - value) * 4.0)
        elif value > 1.0:
          value = 1.0 - value
        break
    pointsBonus = pointsBonus + value
  pointsBonus = pointsBonus / difficultyValues.len.float
  if pointsBonus < 0.01:
    pointsBonus = 0.01
  return (gameStats.points.float * pointsBonus).Natural

proc updateFinishedMissions*(mType: string) {.sideEffect, raises: [], tags: [].} =
  var updated = false
  for finishedMission in gameStats.finishedMissions.mitems:
    if finishedMission.index == mType:
      finishedMission.amount.inc
      updated = true
      break
  if not updated:
    gameStats.finishedMissions.add(StatisticsData(index: mType, amount: 1))
  gameStats.points = gameStats.points + 50

# Temporary code for interfacing with Ada

type
  AdaGameStats = object
    basesVisited: cint
    mapVisited: cint
    distanceTraveled: cint
    acceptedMissions: cint
    points: cint

  AdaStatisticsData = object
    index: cstring
    amount: cint

proc updateAdaCraftingOrders(index: cstring) {.raises: [], tags: [], exportc.} =
  updateCraftingOrders(index = $index)

proc getAdaGameStats(stats: AdaGameStats) {.raises: [], tags: [], exportc.} =
  gameStats.basesVisited = stats.basesVisited
  gameStats.mapVisited = stats.mapVisited
  gameStats.distanceTraveled = stats.distanceTraveled
  gameStats.acceptedMissions = stats.acceptedMissions
  gameStats.points = stats.points

proc getAdaGameStatsList(name: cstring; statsList: array[512,
    AdaStatisticsData]) {.raises: [], tags: [], exportc.} =
  var list = case $name
    of "destroyedShips":
      gameStats.destroyedShips
    of "craftingOrders":
      gameStats.craftingOrders
    of "finishedMissions":
      gameStats.finishedMissions
    of "finishedGoals":
      gameStats.finishedGoals
    else:
      gameStats.killedMobs
  list = @[]
  for stat in statsList:
    if stat.index.len == 0:
      break
    list.add(y = StatisticsData(index: $stat.index,
        amount: stat.amount.Positive))
  case $name
  of "destroyedShips":
    gameStats.destroyedShips = list
  of "craftingOrders":
    gameStats.craftingOrders = list
  of "finishedMissions":
    gameStats.finishedMissions = list
  of "finishedGoals":
    gameStats.finishedGoals = list
  else:
    gameStats.killedMobs = list

proc setAdaGameStats(stats: var AdaGameStats) {.raises: [], tags: [], exportc.} =
  stats.basesVisited = gameStats.basesVisited.cint
  stats.mapVisited = gameStats.mapVisited.cint
  stats.distanceTraveled = gameStats.distanceTraveled.cint
  stats.acceptedMissions = gameStats.acceptedMissions.cint
  stats.points = gameStats.points.cint

proc setAdaGameStatsList(name: cstring; statsList: var array[512,
    AdaStatisticsData]) {.raises: [], tags: [], exportc.} =
  var list = case $name
    of "destroyedShips":
      gameStats.destroyedShips
    of "craftingOrders":
      gameStats.craftingOrders
    of "finishedMissions":
      gameStats.finishedMissions
    of "finishedGoals":
      gameStats.finishedGoals
    else:
      gameStats.killedMobs
  for i in 0..statsList.high:
    statsList[i] = AdaStatisticsData(index: "".cstring, amount: 1)
  for index, stat in list.pairs:
    statsList[index] = AdaStatisticsData(index: stat.index.cstring,
        amount: stat.amount.cint)

proc updateAdaFinishedGoals(index: cstring) {.raises: [], tags: [], exportc.} =
  updateFinishedGoals(index = $index)

proc getAdaGamePoints(): cint {.raises: [], tags: [], exportc.} =
  return getGamePoints().cint

proc updateAdaFinishedMissions(mType: cstring) {.raises: [], tags: [], exportc.} =
  updateFinishedMissions(mType = $mType)
