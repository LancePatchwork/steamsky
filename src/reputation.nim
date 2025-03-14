# Copyright 2025 Bartek thindil Jasicki
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

## Provides code for the player's reputation system with bases and factions,
## like updating reputation, storing it, etc.

import std/[tables, xmltree, strutils]
import contracts
import config, factions, types, game

type
  ReputationObject = object
    ## Used to store data about the player's reputation in the selected faction
    factionIndex: string       ## Index of faction to which the reputation is related
    reputation: ReputationData ## The information about the reputation

var
  reputationsList: seq[ReputationObject] = @[]
    ## The list of player's reputation with all factions

proc resetReputations*() {.raises: [KeyError], tags: [],
    contractual.} =
  ## Reset the player's reputation with all factions
  reputationsList = @[]
  for index, faction in factionsList:
    let reputationLevel: int = if index == newGameSettings.playerFaction or
        isFriendly(sourceFaction = newGameSettings.playerFaction,
            targetFaction = index): 1 else: -1
    reputationsList.add(y = ReputationObject(factionIndex: index,
        reputation: ReputationData(level: reputationLevel, experience: 0)))

proc updateReputation*(baseIndex: BasesRange; amount: int) {.raises: [
    ReputationError], tags: [], contractual.} =
  ## Update the reputation in factions
  ##
  ## * baseIndex - the index of the base in which the reputation will be
  ##               updated
  ## * amount    - the amount of the reputation to be added or removed from
  ##               the player's reputations' levels
  let factionIndex: string = skyBases[baseIndex].owner
  var repIndex: int = -1
  for index, reputation in reputationsList:
    if reputation.factionIndex == factionIndex:
      repIndex = index
      break
  if repIndex == -1:
    raise newException(exceptn = ReputationError,
        message = "Can't find index of the faction")

  proc updateRep(index: Natural; points: int) {.raises: [], tags: [],
      contractual.} =
    ## Update reputation in the selected faction
    ##
    ## * index  - the index of the reputation which will be updated
    ## * points - the amount of reputation's points to gain or lose
    # Don't lose reputation below the lowest value
    if reputationsList[index].reputation.level == -100 and points < 0:
      return
    # Don't gain reputation above the highest value
    if reputationsList[index].reputation.level == 100 and points > 0:
      return
    # Gain or lose reputation with the faction
    var newPoints: int = reputationsList[index].reputation.experience + (
        points.float * newGameSettings.reputationBonus).int
    while newPoints < 0:
      reputationsList[repIndex].reputation.level.dec
      newPoints += abs(x = reputationsList[index].reputation.level * 500)
      if newPoints >= 0:
        reputationsList[index].reputation.experience = newPoints
        return
    while newPoints > abs(x = reputationsList[index].reputation.level * 500):
      newPoints -= abs(x = reputationsList[index].reputation.level * 500)
      reputationsList[index].reputation.level.inc
    reputationsList[index].reputation.experience = newPoints

  updateRep(index = repIndex, points = amount)
  # Gain or lose reputation with other factions, depending if they are friends
  # or enemies of the main faction
  for index, reputation in reputationsList:
    try:
      if isFriendly(sourceFaction = factionIndex,
          targetFaction = reputation.factionIndex):
        updateRep(index = index, points = amount)
      else:
        updateRep(index = index, points = (amount * -1))
    except:
      raise newException(exceptn = ReputationError,
          message = getCurrentExceptionMsg())

proc getReputation*(factionIndex: string): int {.raises: [], tags: [],
    contractual.} =
  ## Get the level of the player's reputation with the selected faction
  ##
  ## * factionIndex - the index of faction with which the reputaion will be get
  ##
  ## Returns the player's reputation's level with the selected faction.
  for reputation in reputationsList:
    if reputation.factionIndex == factionIndex:
      return reputation.reputation.level
  return 0

proc saveReputation*(saveTree: var XmlNode) {.raises: [], tags: [],
    contractual.} =
  ## Save the reputation's data in file
  ##
  ## * saveTree - the XML tree with save data
  ##
  ## Returns modified parameter saveTree.
  for reputation in reputationsList:
    var repElement: XmlNode = newElement(tag = "reputation")
    repElement.attrs = {"faction": reputation.factionIndex,
        "level": $reputation.reputation.level,
        "experience": $reputation.reputation.experience}.toXmlAttributes
    saveTree.add(son = repElement)

proc loadReputation*(savedGame: XmlNode) {.raises: [ValueError], tags: [],
    contractual.} =
  ## Load the reputation's data from the file
  ##
  ## * savedGame - the XML tree with save data
  for item in savedGame.findAll(tag = "reputation"):
    reputationsList.add(y = ReputationObject(factionIndex: item.attr(
        name = "faction"), reputation: ReputationData(level: item.attr(
        name = "level").parseInt, experience: item.attr(
        name = "experience").parseInt)))
