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

import std/[os, strutils, tables, xmlparser, xmltree]
import types

type
  DataAction* = enum
    # Possible actions to do when loading game data
    add, update, remove

  ToolQuality = object
    ## Store data related to quality of tools needed for train a skill
    level*: Natural   ## The minimal level of a skill which need that quality of tool
    quality*: Natural ## The level of quality of tool needed for training

  SkillRecord* = object
    ## Store data releated to the skills
    name*: string                   ## The name of the skill
    attribute*: Positive            ## The index of the attribute related to the skill
    description*: string            ## The description of the skill
    tool*: string                   ## The type of items used to train the skill
    toolsQuality*: seq[ToolQuality] ## The quality of tool needed for training

  DataLoadingError* = object of CatchableError
    ## Used to mark problems during loading the game data from files

  AttributeRecord* = object
    ## Store data related to the attributes
    name: string        ## The name of the attribute
    description: string ## The description of the attribute

const defaultItemDurability*: ItemsDurability = 100 ## Default durability for the new items

var
  saveDirectory*: string = "data" & DirSep & "saves" &
      DirSep ## The directory where the saved games and logs are stored
  moneyIndex*: Positive ## The item's index of the item used as money in the game
  moneyName*: string                       ## The name of the item used as a money in the game
  skillsList* = initTable[Positive, SkillRecord]() ## The list of all skill available in the game
  basesSyllablesPreList*: seq[string]      ## The list of pre syllables for bases names
  basesSyllablesStartList*: seq[string]    ## The list of start syllables for bases names
  basesSyllablesEndList*: seq[string]      ## The list of end syllables for bases names
  basesSyllablesPostList*: seq[string]     ## The list of post syllables for bases names
  malesSyllablesStartList*: seq[string]    ## The list of start syllables for males names
  malesSyllablesMiddleList*: seq[string]   ## The list of middle syllables for males names
  malesSyllablesEndList*: seq[string]      ## The list of end syllables for males names
  malesVocalsList*: seq[string]            ## The list of vocals for males names
  malesConsonantsList*: seq[string]        ## The list of consonants for males names
  femalesSyllablesStartList*: seq[string]  ## The list of start syllables for females names
  femalesSyllablesMiddleList*: seq[string] ## The list of middle syllables for females names
  femalesSyllablesEndList*: seq[string]    ## The list of end syllables for females names
  femalesVocalsList*: seq[string]          ## The list of vocals for female names
  shipsSyllablesStartList*: seq[string]    ## The list of start syllables for ships names
  shipsSyllablesMiddleList*: seq[string]   ## The list of middle syllables for ships names
  shipsSyllablesEndList*: seq[string]      ## The list of end syllables for ships names
  attributesList*: seq[AttributeRecord]    ## The list of all attributes available in the game
  itemsTypesList*: seq[string] ## The list of all types of items available in the game
  repairTools*: string                     ## The type of item used to repair ships
  cleaningTools*: string                   ## The type of item used to cleaning ships
  alchemyTools*: string                    ## The type of item used as alchemy tools
  corpseIndex*: Positive                   ## The index of item used as prototype for corpses
  missionItemsType*: string                ## The type of item used in missions
  fuelType*: string                        ## The type of item used as fuel for ships
  tradersName*: string ## The word used to mark traders ships in their names
  conditionIndex*: Natural                 ## The index of condition attribute
  strengthIndex*: Natural                  ## The index of strength attribute
  pilotingSkill*: Positive                 ## The index of piloting skill
  engineeringSkill*: Positive              ## The index of engineering skill
  gunnerySkill*: Positive                  ## The index of gunnery skill
  talkingSkill*: Positive                  ## The index of talking skill
  perceptionSkill*: Positive               ## The index of perception skil
  headArmor*: string                       ## The type of items used as head armor
  chestArmor*: string                      ## The type of items used as chest armor
  armsArmor*: string                       ## The type of items used as arms armor
  legsArmor*: string                       ## The type of items used as legs armor
  shieldType*: string                      ## The type of items used as shield
  weaponType*: string                      ## The type of items used as weapon
  dodgeSkill*: Positive                    ## The index of dodge skill
  unarmedSkill*: Positive                  ## The index of unarmed combat skill
  factionsList*: Table[string, FactionData] = initTable[string, FactionData]() ## The list of all available factions in the game
  itemsList* = initTable[Positive, ObjectData]() ## The list of prototypes of all items availabla in the game
  skyBases*: array[BasesRange, BaseRecord] ## The list of all bases in the game
  modulesList* = initTable[Positive, BaseModuleData]() ## The list of prototypes of all ships' modules available in the game
  recipesList* = initTable[string, CraftData]() ## The list of all available crafting recipes in the game
  goalsList* = initTable[Positive, GoalData]() ## The list of available goals in the game
  playerCareer*: string ## Index of the career of the player selected when starting a new game
  knownRecipes*: seq[string]               ## The list of known recipes by the player
  messagesList*: seq[MessageData]          ## The list of in-game messages
  eventsList* = initTable[Positive, EventData]() ## The list of available events in the game
  playerShip*: ShipRecord = ShipRecord(skyX: 1, skyY: 1) ## The player's ship's data
  npcShip*: ShipRecord = ShipRecord(skyX: 1, skyY: 1) ## The npc ship like enemy, trader, etc
  protoShipsList* = initTable[Positive, ProtoShipData]() ## The list of prototypes of ships available in the game

proc findSkillIndex*(skillName: string): Natural {.sideEffect, raises: [],
    tags: [].} =
  ## Get the index of the selected skill
  ##
  ## * skillName - the name of the skill which index will be looking for
  ##
  ## Returns the index of the selected skill or 0 if the skill not found
  for key, skill in skillsList.pairs:
    if skill.name == skillName:
      return key
  return 0

proc loadData*(fileName: string) {.sideEffect, raises: [DataLoadingError],
    tags: [WriteIOEffect, ReadIOEffect, RootEffect].} =
  ## Load the game data
  ##
  ## * fileName - the name of the file with the game data to load

  proc findAttributeIndex(attributeName: string): int {.sideEffect,
      raises: [], tags: [].} =
    ## Find the index of the selected attribute
    ##
    ## * attributeName - the name of the attribute which index will be looking
    ##                   for
    ##
    ## Returns the index of the selected attribute or -1 if the attribute not found
    for key, attribute in attributesList.pairs:
      if attribute.name == attributeName:
        return key
    return -1

  let gameXml = try:
      loadXml(path = fileName)
    except XmlError, ValueError, IOError, OSError, Exception:
      raise newException(exceptn = DataLoadingError,
          message = "Can't load game data file. Reason: " &
          getCurrentExceptionMsg())
  var skillIndex: Positive = 1
  for gameNode in gameXml:
    if gameNode.kind != xnElement:
      continue
    case gameNode.tag
    of "basessyllablepre":
      basesSyllablesPreList.add(y = gameNode.attr(name = "value"))
    of "basessyllablestart":
      basesSyllablesStartList.add(y = gameNode.attr(name = "value"))
    of "basessyllableend":
      basesSyllablesEndList.add(y = gameNode.attr(name = "value"))
    of "basessyllablepost":
      basesSyllablesPostList.add(y = gameNode.attr(name = "value"))
    of "malessyllablestart":
      malesSyllablesStartList.add(y = gameNode.attr(name = "value"))
    of "malessyllablemiddle":
      malesSyllablesMiddleList.add(y = gameNode.attr(name = "value"))
    of "malessyllableend":
      malesSyllablesEndList.add(y = gameNode.attr(name = "value"))
    of "malesvocal":
      malesVocalsList.add(y = gameNode.attr(name = "value"))
    of "malesconsonant":
      malesConsonantsList.add(y = gameNode.attr(name = "value"))
    of "femalessyllablestart":
      femalesSyllablesStartList.add(y = gameNode.attr(name = "value"))
    of "femalessyllablemiddle":
      femalesSyllablesMiddleList.add(y = gameNode.attr(name = "value"))
    of "femalessyllableend":
      femalesSyllablesEndList.add(y = gameNode.attr(name = "value"))
    of "femalesvocal":
      femalesVocalsList.add(y = gameNode.attr(name = "value"))
    of "shipssyllablestart":
      shipsSyllablesStartList.add(y = gameNode.attr(name = "value"))
    of "shipssyllablemiddle":
      shipsSyllablesMiddleList.add(y = gameNode.attr(name = "value"))
    of "shipssyllableend":
      shipsSyllablesEndList.add(y = gameNode.attr(name = "value"))
    of "attribute":
      attributesList.add(y = AttributeRecord(name: gameNode.attr(name = "name"),
          description: gameNode.innerText()))
    of "skill":
      var newSkill: SkillRecord = SkillRecord(attribute: 1)
      newSkill.name = gameNode.attr(name = "name")
      newSkill.tool = gameNode.attr(name = "tool")
      let attributeName = gameNode.attr(name = "attribute")
      for index, attribute in attributesList.pairs():
        if attribute.name == attributeName:
          newSkill.attribute = index + 1
          break
      for childNode in gameNode:
        if childNode.kind != xnElement:
          continue
        case childNode.tag
        of "description":
          newSkill.description = childNode.innerText()
        of "toolquality":
          try:
            newSkill.toolsQuality.add(y = ToolQuality(level: childNode.attr(
                name = "level").parseInt(), quality: childNode.attr(
                name = "quality").parseInt()))
          except ValueError:
            raise newException(exceptn = DataLoadingError,
                message = "Can't add skill '" & newSkill.name & "'. Invalid value for tools quality.")
      skillsList[skillIndex] = newSkill
      skillIndex.inc()
    of "itemtype":
      itemsTypesList.add(y = gameNode.attr(name = "value"))
    of "remove":
      case gameNode.attr(name = "name")
      of "skill":
        {.warning[ProveInit]: off.}
        {.warning[UnsafeDefault]: off.}
        try:
          skillsList.del(key = gameNode.attr(name = "value").parseInt())
        except ValueError:
          raise newException(exceptn = DataLoadingError,
              message = "Can't delete skill '" & gameNode.attr(name = "value") & "'. Invalid index.")
        {.warning[ProveInit]: on.}
        {.warning[UnsafeDefault]: on.}
      of "attribute":
        try:
          attributesList.del(i = gameNode.attr(name = "value").parseInt() - 1)
        except ValueError:
          raise newException(exceptn = DataLoadingError,
              message = "Can't delete attribute '" & gameNode.attr(
                  name = "value") & "'. Invalid index.")
      of "itemtype":
        try:
          itemsTypesList.del(i = gameNode.attr(name = "value").parseInt() - 1)
        except ValueError:
          raise newException(exceptn = DataLoadingError,
              message = "Can't delete item type '" & gameNode.attr(
                  name = "value") & "'. Invalid index.")
      else:
        discard
    of "repairtools":
      repairTools = gameNode.attr(name = "value")
    of "cleaningtools":
      cleaningTools = gameNode.attr(name = "value")
    of "alchemytools":
      alchemyTools = gameNode.attr(name = "value")
    of "corpseindex":
      try:
        corpseIndex = gameNode.attr(name = "value").parseInt()
      except ValueError:
        raise newException(exceptn = DataLoadingError,
          message = "Can't set corpse index '" & gameNode.attr(name = "value") & "'. Invalid value.")
    of "missionitemstype":
      missionItemsType = gameNode.attr(name = "value")
    of "fueltype":
      fuelType = gameNode.attr(name = "value")
    of "moneyindex":
      try:
        moneyIndex = gameNode.attr(name = "value").parseInt()
      except ValueError:
        raise newException(exceptn = DataLoadingError,
          message = "Can't set money index '" & gameNode.attr(name = "value") & "'. Invalid value.")
    of "tradersname":
      tradersName = gameNode.attr(name = "value")
    of "conditionname":
      conditionIndex = findAttributeIndex(attributeName = gameNode.attr(
          name = "value"))
    of "strengthname":
      strengthIndex = findAttributeIndex(attributeName = gameNode.attr(
          name = "value"))
    of "pilotingskill":
      pilotingSkill = findSkillIndex(skillName = gameNode.attr(name = "value"))
    of "engineeringskill":
      engineeringSkill = findSkillIndex(skillName = gameNode.attr(
          name = "value"))
    of "gunneryskill":
      gunnerySkill = findSkillIndex(skillName = gameNode.attr(name = "value"))
    of "talkingskill":
      talkingSkill = findSkillIndex(skillName = gameNode.attr(name = "value"))
    of "perceptionskill":
      perceptionSkill = findSkillIndex(skillName = gameNode.attr(
          name = "value"))
    of "headarmor":
      headArmor = gameNode.attr(name = "value")
    of "chestarmor":
      chestArmor = gameNode.attr(name = "value")
    of "armsarmor":
      armsArmor = gameNode.attr(name = "value")
    of "legsarmor":
      legsArmor = gameNode.attr(name = "value")
    of "shieldtype":
      shieldType = gameNode.attr(name = "value")
    of "weapontype":
      weaponType = gameNode.attr(name = "value")
    of "dodgeskill":
      dodgeSkill = findSkillIndex(skillName = gameNode.attr(name = "value"))
    of "unarmedskill":
      unarmedSkill = findSkillIndex(skillName = gameNode.attr(name = "value"))

proc endGame*(save: bool) {.sideEffect, raises: [], tags: [].} =
  ## Save or not the game and clear the temporary data
  ##
  ## * save - if true, save the current game
  messagesList = @[]
  knownRecipes = @[]
  {.warning[ProveInit]: off.}
  {.warning[UnsafeDefault]: off.}
  eventsList.clear()
  {.warning[ProveInit]: on.}
  {.warning[UnsafeDefault]: on.}

# Temporary code for interfacing with Ada

proc loadAdaData(fileName: cstring): cstring {.raises: [], tags: [WriteIOEffect,
    ReadIOEffect, RootEffect], exportc.} =
  try:
    loadData(fileName = $fileName)
    return "".cstring
  except DataLoadingError:
    return getCurrentExceptionMsg().cstring

proc getAdaItemType(itemIndex: cint): cstring {.raises: [], tags: [], exportc.} =
  if itemIndex >= itemsTypesList.len():
    return ""
  return itemsTypesList[itemIndex].cstring

proc getAdaAttribute(itemIndex: cint; attribute: var array[2,
    cstring]) {.raises: [], tags: [], exportc.} =
  attribute = ["".cstring, "".cstring]
  if itemIndex >= attributesList.len():
    return
  attribute = [attributesList[itemIndex].name.cstring, attributesList[
      itemIndex].description.cstring]

proc getAdaSkillToolsAmount(skillIndex: cint): cint {.raises: [], tags: [], exportc.} =
  if not skillsList.contains(key = skillIndex):
    return 0
  try:
    return skillsList[skillIndex].toolsQuality.len().cint
  except KeyError:
    return 0

type AdaSkillRecord = object
  name: cstring
  attribute: cint
  description: cstring
  tool: cstring

proc getAdaSkill(skillIndex: cint; skill: var AdaSkillRecord) {.raises: [],
    tags: [], exportc.} =
  skill = AdaSkillRecord(name: "".cstring, attribute: 0,
      description: "".cstring, tool: "".cstring)
  if not skillsList.contains(key = skillIndex):
    return
  try:
    skill.name = skillsList[skillIndex].name.cstring
    skill.attribute = skillsList[skillIndex].attribute.cint
    skill.description = skillsList[skillIndex].description.cstring
    skill.tool = skillsList[skillIndex].tool.cstring
  except KeyError:
    return

proc getAdaSkillTools(skillIndex: cint; tools: var array[16, array[2,
    cint]]) {.raises: [], tags: [], exportc.} =
  tools[0] = [-1.cint, -1.cint]
  if not skillsList.contains(key = skillIndex):
    return
  var index = 0
  try:
    for toolQuality in skillsList[skillIndex].toolsQuality:
      tools[index] = [toolQuality.level.cint, toolQuality.quality.cint]
      index.inc()
  except KeyError:
    return

proc findAdaSkillIndex(skillName: cstring): cint {.raises: [], tags: [], exportc.} =
  return findSkillIndex(skillName = $skillName).cint

proc getAdaGameStrings(values: var array[0..11, cstring]) {.raises: [], tags: [], exportc.} =
  values = [repairTools.cstring, cleaningTools.cstring, alchemyTools.cstring,
      missionItemsType.cstring, fuelType.cstring, tradersName.cstring,
      headArmor.cstring, chestArmor.cstring, armsArmor.cstring,
      legsArmor.cstring, shieldType.cstring, weaponType.cstring]

proc getAdaGameIntegers(values: var array[0..10, cint]) {.raises: [], tags: [], exportc.} =
  values = [corpseIndex.cint, moneyIndex.cint, conditionIndex.cint,
      (strengthIndex + 1).cint, pilotingSkill.cint, engineeringSkill.cint,
      gunnerySkill.cint, talkingSkill.cint, perceptionSkill.cint,
      dodgeSkill.cint, unarmedSkill.cint]

proc getAdaGameString(name, value: cstring) {.raises: [], tags: [], exportc.} =
  case $name
  of "playerCareer":
    playerCareer = $value
  else:
    discard

proc endAdaGame(save: cint) {.raises: [], tags: [], exportc.} =
  endGame(save = (if save == 1: true else: false))
