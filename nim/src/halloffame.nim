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

import std/[strutils, xmlparser, xmltree]
import game, statistics

type
  HallOfFameData* = object
    ## Used to store data about the hall of fame entry
    ##
    ## * name        - The name of the player on the list
    ## * points      - The amount of points achived by the player
    ## * deathReason - The reason of the death of the player
    name*: string
    points*: Natural
    deathReason*: string

var hallOfFameArray*: array[1..10, HallOfFameData] ## The list of entries in the game's hall of fame

proc loadHallOfFame*() {.sideEffect, raises: [DataLoadingError], tags: [
    WriteIOEffect, ReadIOEffect, RootEffect].} =
  ## Load the game's hall of fame data from file
  if hallOfFameArray[1].name.len > 0:
    return
  for entry in hallOfFameArray.mitems:
    entry = HallOfFameData(name: "", points: 0, deathReason: "")
  let hofXml = try:
      loadXml(path = saveDirectory & "halloffame.dat")
    except XmlError, ValueError, IOError, OSError, Exception:
      return
  var index = 1
  for hofNode in hofXml:
    if hofNode.kind != xnElement:
      continue
    hallOfFameArray[index].name = hofNode.attr(name = "name")
    hallOfFameArray[index].points = try:
        hofNode.attr(name = "points").parseInt()
      except ValueError:
        raise newException(exceptn = DataLoadingError,
            message = "Invalid value for points in hall of fame entry.")
    hallOfFameArray[index].deathReason = hofNode.attr(name = "Death_Reason")
    index.inc

proc updateHallOfFame*(playerName, deathReason: string) {.sideEffect, raises: [
    IOError], tags: [WriteIOEffect].} =
  ## Update the game's hall of fame list with the new entry. If needed, remove
  ## old one to replace it with the new. If new is too low in points, don't
  ## insert it to the hall of fame list.
  ##
  ## * playerName  - the name of the player to add to the list
  ## * deathReason - the reason what killed the player
  var newIndex: Natural = 0
  for index, entry in hallOfFameArray.pairs:
    if entry.points < getGamePoints():
      newIndex = index
      break
  if newIndex == 0:
    return
  hallOfFameArray[newIndex + 1 .. hallOfFameArray.high] = hallOfFameArray[
      newIndex .. hallOfFameArray.high - 1]
  hallOfFameArray[newIndex] = HallOfFameData(name: playerName,
      points: getGamePoints(), deathReason: deathReason)
  var entries: seq[XmlNode]
  for entry in hallOfFameArray:
    if entry.points == 0:
      break
    var element = newElement("entry")
    let values = {"name": entry.name, "points": $entry.points,
        "Death_Reason": entry.deathReason}.toXmlAttributes
    element.attrs = values
    entries.add(y = element)
  let xmlTree = newXmlTree(tag = "halloffame", children = entries)
  writeFile(filename = saveDirectory & "halloffame.dat", content = xmlHeader & $xmlTree)

# Temporary code for interfacing with Ada

type
  AdaHallOfFameData = object
    name: cstring
    points: cint
    deathReason: cstring

proc loadAdaHallOfFame(): cstring {.sideEffect, raises: [], tags: [
    WriteIOEffect, ReadIOEffect, RootEffect], exportc.} =
  try:
    loadHallOfFame()
    return "".cstring
  except DataLoadingError:
    return getCurrentExceptionMsg().cstring

proc getAdaHofEntry(index: cint; entry: var AdaHallOfFameData) {.sideEffect,
    raises: [], tags: [], exportc.} =
  entry = AdaHallOfFameData(name: hallOfFameArray[index].name.cstring,
      points: hallOfFameArray[index].points.cint, deathReason: hallOfFameArray[
      index].deathReason.cstring)

proc updateAdaHallOfFame(playerName, deathReason: cstring) {.sideEffect,
    raises: [], tags: [WriteIOEffect], exportc.} =
  try:
    updateHallOfFame(playerName = $playerName, deathReason = $deathReason)
  except IOError:
    discard
