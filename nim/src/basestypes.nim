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

import std/[strutils, tables, xmlparser, xmltree]
import game, log, types

type
  PricesArray* = array[1..2, Natural]
    ## FUNCTION
    ##
    ## Used to set base buy and sell price for an item in the base type.
    ## 1 - sell price, 2 - buy price

  BaseTypeData* = object
    ## FUNCTION
    ##
    ## Used to store informaiton about bases types
    name: string ## The name of the base type
    color: string ## The color used to show a base of that type on the map
    trades: Table[Positive, PricesArray] ## The list of items available to trade in the base type
    recipes: seq[string] ## The list of crafting recipes available on sale in the base type
    flags: seq[string] ## Additional flags for the base type like SHIPYARD, BARRACKS, etc
    description: string ## The description of the base type, show in the new game screen

var basesTypesList* = initTable[string, BaseTypeData]()
  ## FUNCTION
  ##
  ## The list of all available bases types in the game

proc loadBasesTypes*(fileName: string) {.sideEffect, raises: [DataLoadingError],
    tags: [WriteIOEffect, ReadIOEffect, RootEffect].} =
  ## FUNCTION
  ##
  ## Load available bases types from the data file
  ##
  ## PARAMETERS
  ##
  ## * fileName - the path to the file with bases types data which will be loaded
  let basesTypesXml = try:
      loadXml(path = fileName)
    except XmlError, ValueError, IOError, OSError, Exception:
      raise newException(exceptn = DataLoadingError,
          message = "Can't load bases types data file. Reason: " &
          getCurrentExceptionMsg())
  for baseTypeNode in basesTypesXml:
    if baseTypeNode.kind != xnElement:
      continue
    let
      baseTypeIndex = baseTypeNode.attr(name = "index")
      baseTypeAction: DataAction = try:
          parseEnum[DataAction](baseTypeNode.attr(name = "action").toLowerAscii)
        except ValueError:
          DataAction.add
    if baseTypeAction in [update, remove]:
      if basesTypesList.hasKey(key = baseTypeIndex):
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $baseTypeAction & " base type '" &
            baseTypeIndex & "', there is no base type with that index,")
    elif basesTypesList.hasKey(key = baseTypeIndex):
      raise newException(exceptn = DataLoadingError,
          message = "Can't add base type '" & baseTypeIndex & "', there is a base type with that index.")
    if baseTypeAction == DataAction.remove:
      basesTypesList.del(key = baseTypeIndex)
      logMessage(message = "Base type removed: '" & baseTypeIndex & "'",
          debugType = everything)
      continue
    var baseType: BaseTypeData = if baseTypeAction == DataAction.update:
        try:
          basesTypesList[baseTypeIndex]
        except KeyError:
          BaseTypeData()
      else:
        BaseTypeData()
    var attribute = baseTypeNode.attr(name = "name")
    if attribute.len() > 0:
      baseType.name = attribute
    attribute = baseTypeNode.attr(name = "color")
    if attribute.len() > 0:
      baseType.color = attribute
    for childNode in baseTypeNode:
      if childNode.kind != xnElement:
        continue
      case childNode.tag
      of "description":
        baseType.description = childNode.innerText()
      of "item":
        let
          itemIndex = try:
              childNode.attr(name = "index").parseInt()
            except ValueError:
              raise newException(exceptn = DataLoadingError,
                  message = "Can't " & $baseTypeAction & " base type '" &
                  baseTypeIndex & "', invalid item index '" & childNode.attr(
                  name = "index") & "'.")
          subAction = try:
              parseEnum[DataAction](childNode.attr(
                  name = "action").toLowerAscii)
            except ValueError:
              DataAction.add
        if not itemsList.hasKey(key = itemIndex):
          raise newException(exceptn = DataLoadingError,
              message = "Can't " & $baseTypeAction & " base type '" &
              baseTypeIndex & "', no item with index '" & $itemIndex & "'.")
        if subAction == DataAction.add and baseType.trades.hasKey(
            key = itemIndex):
          raise newException(exceptn = DataLoadingError,
              message = "Can't add base type '" & baseTypeIndex &
              "', item with index '" & $itemIndex & "' already added.")
        if subAction == DataAction.remove:
          {.warning[ProveInit]: off.}
          {.warning[UnsafeDefault]: off.}
          baseType.trades.del(key = itemIndex)
          {.warning[UnsafeDefault]: on.}
          {.warning[ProveInit]: on.}
        else:
          let
            buyPrice: Natural = try:
                childNode.attr(name = "buyprice").parseInt()
              except ValueError:
                0
            sellPrice: Natural = try:
                childNode.attr(name = "sellprice").parseInt()
              except ValueError:
                0
          baseType.trades[itemIndex] = [1: sellPrice, 2: buyPrice]
      of "recipe":
        let
          recipeIndex = childNode.attr(name = "index")
          subAction = try:
              parseEnum[DataAction](childNode.attr(
                  name = "action").toLowerAscii)
            except ValueError:
              DataAction.add
        if subAction == DataAction.add and recipeIndex in baseType.recipes:
          raise newException(exceptn = DataLoadingError,
              message = "Can't add base type '" & baseTypeIndex &
              "', recipe with index '" & recipeIndex & "' already added.")
        if subAction == DataAction.remove:
          for index, recipe in baseType.recipes.pairs:
            if recipe == recipeIndex:
              baseType.recipes.delete(i = index)
              break
        else:
          baseType.recipes.add(y = recipeIndex)
      of "flag":
        let
          flagName = childNode.attr(name = "name")
          subAction = try:
              parseEnum[DataAction](childNode.attr(
                  name = "action").toLowerAscii)
            except ValueError:
              DataAction.add
        if subAction == DataAction.add and flagName in baseType.flags:
          raise newException(exceptn = DataLoadingError,
              message = "Can't add base type '" & baseTypeIndex &
              "', flag '" & flagName & "' already added.")
        if subAction == DataAction.remove:
          for index, flag in baseType.flags.pairs:
            if flag == flagName:
              baseType.flags.delete(i = index)
              break
        else:
          baseType.flags.add(y = flagName)
    if baseTypeAction == DataAction.add:
      logMessage(message = "Base type added: '" & baseTypeIndex & "'",
          debugType = everything)
    else:
      logMessage(message = "Base type updated: '" & baseTypeIndex & "'",
          debugType = everything)
    basesTypesList[baseTypeIndex] = baseType

proc getPrice*(baseType: string; itemIndex: Positive): Natural {.sideEffect,
    raises: [KeyError], tags: [].} =
  ## FUNCTION
  ##
  ## Get the price of the selected item in the selected type of bases
  ##
  ## PARAMETERS
  ##
  ## * baseType  - the type of base from which the price will be taken
  ## * itemIndex - the index of the item's prototype which price will be taken
  ##
  ## RETURNS
  ##
  ## The price of the selected item
  if itemsList[itemIndex].price == 0:
    return 0
  if basesTypesList[baseType].trades.hasKey(key = itemIndex):
    if basesTypesList[baseType].trades[itemIndex][1] > 0:
      return basesTypesList[baseType].trades[itemIndex][1]
    elif basesTypesList[baseType].trades[itemIndex][2] > 0:
      return basesTypesList[baseType].trades[itemIndex][2]
  return itemsList[itemIndex].price

proc isBuyable*(baseType: string; itemIndex: Positive; checkFlag: bool = true;
    baseIndex: ExtendedBasesRange = 0): bool {.sideEffect, raises: [KeyError],
    tags: [].} =
  ## FUNCTION
  ##
  ## Check if the selected item is buyable in the selected bases type
  ##
  ## PARAMETERS
  ##
  ## * baseType  - the type of base in which the item will be check
  ## * itemIndex - the index of the item's prototype which will be check
  ## * checkFlag - if true, check if the base type is black market. Can be
  ##               empty. Default value is true
  ## * baseIndex - if greater than 0, check the player reputation in the
  ##               selected base. Can be empty. Default value is 0.
  ##
  ## RETURNS
  ##
  ## True if the item is buyable in the selected bases type, otherwise
  ## false.
  if baseIndex > 0 and skyBases[baseIndex].reputation.level < itemsList[
      itemIndex].reputation:
    return false
  if checkFlag and "blackmarket" in basesTypesList[baseType].flags and getPrice(
      baseType = baseType, itemIndex = itemIndex) > 0:
    return true
  if not basesTypesList[baseType].trades.hasKey(key = itemIndex):
    return false
  if basesTypesList[baseType].trades[itemIndex][1] == 0:
    return false
  return true

# Temporary code for interfacing with Ada

type
  AdaBaseTypeData* = object
    name: cstring
    color: cstring
    description: cstring

  AdaPricesArray* = array[1..2, cint]

proc loadAdaBasesTypes(fileName: cstring) {.sideEffect, raises: [
    DataLoadingError], tags: [WriteIOEffect, ReadIOEffect, RootEffect], exportc.} =
  loadBasesTypes(fileName = $fileName)

proc getAdaBaseType(index: cstring; adaBaseType: var AdaBaseTypeData) {.sideEffect,
    raises: [], tags: [], exportc.} =
  adaBaseType = AdaBaseTypeData(name: "".cstring, color: "".cstring,
      description: "".cstring)
  let baseTypeKey = strip(s = $index)
  if not basesTypesList.hasKey(key = baseTypeKey):
    return
  let baseType = try:
      basesTypesList[baseTypeKey]
    except KeyError:
      return
  adaBaseType.name = baseType.name.cstring
  adaBaseType.color = baseType.color.cstring
  adaBaseType.description = baseType.description.cstring

proc getAdaBaseData(baseIndex: cstring; index: cint;
    adaDataType: cstring): cstring {.sideEffect, raises: [], tags: [], exportc.} =
  let baseTypeKey = strip(s = $baseIndex)
  if not basesTypesList.hasKey(key = baseTypeKey):
    return ""
  let dataList = try:
      if adaDataType == "recipe":
        basesTypesList[baseTypeKey].recipes
      else:
        basesTypesList[baseTypeKey].flags
    except KeyError:
      return ""
  if index >= dataList.len():
    return ""
  return dataList[index].cstring

proc getAdaBaseTrade(baseIndex: cstring; index: cint;
    adaBaseTrade: var AdaPricesArray): cstring {.sideEffect, raises: [], tags: [], exportc.} =
  adaBaseTrade = [1: 0.cint, 2: 0.cint]
  let baseTypeKey = strip(s = $baseIndex)
  if not basesTypesList.hasKey(key = baseTypeKey):
    return ""
  try:
    if index > basesTypesList[baseTypeKey].trades.len():
      return ""
  except KeyError:
    return ""
  var currIndex = 1
  try:
    for tradeIndex, trade in basesTypesList[baseTypeKey].trades.pairs:
      currIndex.inc()
      if currIndex < index:
        continue
      adaBaseTrade = [1: trade[1].cint, 2: trade[2].cint]
      let newIndex = $tradeIndex
      return newIndex.cstring
  except KeyError:
    return ""

proc getAdaPrice(baseType: cstring; itemIndex: cint): cint {.exportc.} =
  return getPrice(baseType = $baseType, itemIndex = itemIndex).cint

proc isAdaBuyable(baseType: cstring; itemIndex, checkFlag, baseIndex,
    reputationLevel, reputationExperience: cint): cint {.exportc.} =
  if baseIndex > 0:
    skyBases[baseIndex].reputation = ReputationData(level: reputationLevel,
        experience: reputationExperience)
  return isBuyable(baseType = $baseType, itemIndex = itemIndex, checkFlag = (
      if checkFlag == 1: true else: false), baseIndex = baseIndex).ord.cint

proc hasAdaFlag(baseType, flag: cstring): cint {.exportc.} =
  if not basesTypesList.hasKey(key = $baseType):
    return 0
  if $flag in basesTypesList[$baseType].flags:
    return 1
  return 0

proc getAdaBasesTypes(basesTypes: var array[0..15, cstring]) {.exportc.} =
  var i = 0
  for key in basesTypesList.keys:
    basesTypes[i] = key.cstring
    i.inc
  i.inc
  for index in i..15:
    basesTypes[i] = ""
