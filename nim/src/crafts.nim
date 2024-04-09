# Copyright 2022-2024 Bartek thindil Jasicki
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

## Provides code related to crafting items in the player's ship, like setting
## a crafting recipe in a workshop, or checking a recipe's dependecies.

import std/[strutils, tables, xmlparser, xmltree]
import contracts
import crewinventory, game, goals, items, log, messages, shipscargo, shipscrew,
    statistics, types

type
  CraftingNoWorkshopError* = object of CatchableError
    ## Used to mark problems during crafting with lack of proper workshop

  CraftingNoMaterialsError* = object of CatchableError
    ## Used to mark problems during crafting with lack of proper crafting materials

  CraftingNoToolsError* = object of CatchableError
    ## Used to mark problems during crafting with lack of proper crafting tools

proc loadRecipes*(fileName: string) {.sideEffect, raises: [DataLoadingError],
    tags: [WriteIOEffect, ReadIOEffect, RootEffect], contractual.} =
  ## Load the crafting recipes data from the file
  ##
  ## * fileName - the name of the file to load
  require:
    fileName.len > 0
  body:
    let recipesXml: XmlNode = try:
        loadXml(path = fileName)
      except XmlError, ValueError, IOError, OSError, Exception:
        raise newException(exceptn = DataLoadingError,
            message = "Can't load crafting recipes data file. Reason: " &
            getCurrentExceptionMsg())
    for recipeNode in recipesXml:
      if recipeNode.kind != xnElement:
        continue
      let
        recipeIndex: string = recipeNode.attr(name = "index")
        recipeAction: DataAction = try:
            parseEnum[DataAction](s = recipeNode.attr(
                name = "action").toLowerAscii)
          except ValueError:
            DataAction.add
      if recipeAction in [update, remove]:
        if not recipesList.hasKey(key = recipeIndex):
          raise newException(exceptn = DataLoadingError,
              message = "Can't " & $recipeAction & " recipe '" & $recipeIndex & "', there is no recipe with that index.")
      elif recipesList.hasKey(key = recipeIndex):
        raise newException(exceptn = DataLoadingError,
            message = "Can't add recipe '" & $recipeIndex & "', there is a recipe with that index.")
      if recipeAction == DataAction.remove:
        {.warning[ProveInit]: off.}
        {.warning[UnsafeDefault]: off.}
        recipesList.del(key = recipeIndex)
        {.warning[ProveInit]: on.}
        {.warning[UnsafeDefault]: on.}
        logMessage(message = "Recipe removed: '" & $recipeIndex & "'",
            debugType = everything)
        continue
      var recipe: CraftData = if recipeAction == DataAction.update:
          try:
            recipesList[recipeIndex]
          except ValueError:
            CraftData(time: 1, difficulty: 1, toolQuality: 1)
        else:
          CraftData(time: 1, difficulty: 1, toolQuality: 1)
      for material in recipeNode.findAll(tag = "material"):
        let
          amount: Natural = try:
              material.attr(name = "amount").parseInt()
            except ValueError:
              0
          materialType: string = material.attr(name = "type")
        if amount > 0:
          if materialType notin recipe.materialTypes:
            recipe.materialTypes.add(y = materialType)
            recipe.materialAmounts.add(y = amount)
        else:
          var deleteIndex: Natural = 0
          for index, mType in recipe.materialTypes.pairs:
            if mType == materialType:
              deleteIndex = index
              break
          recipe.materialTypes.delete(i = deleteIndex)
          {.warning[UnsafeSetLen]: off.}
          recipe.materialAmounts.delete(i = deleteIndex)
          {.warning[UnsafeSetLen]: on.}
      var attribute: string = recipeNode.attr(name = "result")
      if attribute.len() > 0:
        recipe.resultIndex = try:
          attribute.parseInt()
        except ValueError:
          raise newException(exceptn = DataLoadingError, message = "Can't " &
              $recipeAction & " recipe '" & $recipeIndex & "', invalid value for recipe result index.")
      attribute = recipeNode.attr(name = "crafted")
      if attribute.len() > 0:
        recipe.resultAmount = try:
            attribute.parseInt()
          except ValueError:
            raise newException(exceptn = DataLoadingError, message = "Can't " &
                $recipeAction & " recipe '" & $recipeIndex & "', invalid value for recipe result amount.")
      attribute = recipeNode.attr(name = "workplace")
      if attribute.len() > 0:
        recipe.workplace = try:
            parseEnum[ModuleType](s = attribute.toLowerAscii)
          except ValueError:
            raise newException(exceptn = DataLoadingError, message = "Can't " &
                $recipeAction & " recipe '" & $recipeIndex & "', invalid value for recipe workplace.")
      attribute = recipeNode.attr(name = "skill")
      if attribute.len() > 0:
        let skillIndex: int = findSkillIndex(skillName = attribute)
        if skillIndex == 0:
          raise newException(exceptn = DataLoadingError, message = "Can't " &
              $recipeAction & " recipe '" & $recipeIndex &
              "', no skill named '" &
              attribute & "'.")
        recipe.skill = skillIndex
      attribute = recipeNode.attr(name = "time")
      if attribute.len() > 0:
        recipe.time = try:
            attribute.parseInt()
          except ValueError:
            raise newException(exceptn = DataLoadingError, message = "Can't " &
                $recipeAction & " recipe '" & $recipeIndex & "', invalid value for recipe time.")
      else:
        recipe.time = 15
      attribute = recipeNode.attr(name = "difficulty")
      if attribute.len() > 0:
        recipe.difficulty = try:
            attribute.parseInt()
          except ValueError:
            raise newException(exceptn = DataLoadingError, message = "Can't " &
                $recipeAction & " recipe '" & $recipeIndex & "', invalid value for recipe difficulty.")
      else:
        recipe.difficulty = 1
      attribute = recipeNode.attr(name = "tool")
      if attribute.len() > 0:
        recipe.tool = attribute
      attribute = recipeNode.attr(name = "reputation")
      if attribute.len() > 0:
        recipe.reputation = try:
            attribute.parseInt()
          except ValueError:
            raise newException(exceptn = DataLoadingError, message = "Can't " &
                $recipeAction & " recipe '" & $recipeIndex & "', invalid value for recipe required reputation.")
      else:
        recipe.reputation = -100
      attribute = recipeNode.attr(name = "toolquality")
      if attribute.len() > 0:
        recipe.toolQuality = try:
            attribute.parseInt()
          except ValueError:
            raise newException(exceptn = DataLoadingError, message = "Can't " &
                $recipeAction & " recipe '" & $recipeIndex & "', invalid value for recipe tool quality.")
      else:
        recipe.toolQuality = 100
      if recipeAction == DataAction.add:
        logMessage(message = "Recipe added: '" & $recipeIndex & "'",
            debugType = everything)
      else:
        logMessage(message = "Recipe updated: '" & $recipeIndex & "'",
            debugType = everything)
      recipesList[recipeIndex] = recipe

proc setRecipeData*(recipeIndex: string): CraftData {.sideEffect, raises: [
    KeyError, ValueError], tags: [], contractual.} =
  ## Set the crafting data for the selected recipe
  ##
  ## * recipeIndex - index of the recipe which data will be set or full action
  ##                 name related to the recipe, like "Study 12"
  ##
  ## Returns CraftData object with information about the crafting recipe
  require:
    recipeIndex.len > 0
  body:
    result = CraftData(time: 15, difficulty: 1, toolQuality: 100)
    var itemIndex: int = 0
    if recipeIndex.len > 6 and recipeIndex[0..4] == "Study":
      itemIndex = recipeIndex[6..^1].strip.parseInt
      result.materialTypes.add(y = itemsList[itemIndex].itemType)
      result.materialAmounts.add(y = 1)
      result.resultIndex = itemIndex
      result.resultAmount = 0
      result.workplace = alchemyLab
      for recipe in recipesList.values:
        if recipe.resultIndex == result.resultIndex:
          result.skill = recipe.skill
          result.time = recipe.difficulty * 15
          break
      result.tool = alchemyTools
      return
    elif recipeIndex.len > 12 and recipeIndex[0..10] == "Deconstruct":
      itemIndex = recipeIndex[12..^1].strip.parseInt
      result.materialTypes.add(y = itemsList[itemIndex].itemType)
      result.materialAmounts.add(y = 1)
      result.workplace = alchemyLab
      for recipe in recipesList.values:
        if recipe.resultIndex == itemIndex:
          result.skill = recipe.skill
          result.time = recipe.difficulty * 15
          result.resultIndex = findProtoItem(itemType = recipe.materialTypes[0])
          result.resultAmount = (recipe.materialAmounts[0].float * 0.8).int
          if result.resultAmount == recipe.resultAmount:
            result.resultAmount.dec
          if result.resultAmount == 0:
            result.resultAmount = 1
          break
      result.tool = alchemyTools
      return
    return recipesList[recipeIndex]

proc checkRecipe*(recipeIndex: string): Positive {.sideEffect, raises: [
    ValueError, CraftingNoWorkshopError, CraftingNoMaterialsError,
    CraftingNoToolsError, TradeNoFreeCargoError], tags: [], contractual.} =
  ## Check if player have all requirements for the selected recipe
  ##
  ## * recipeIndex - index of the recipe which data will be set or full action
  ##                 name related to the recipe, like "Study 12"
  ##
  ## Returns the maximum amount of items which can be crafted with the selected
  ## recipe
  require:
    recipeIndex.len > 0
  body:
    let recipe: CraftData = setRecipeData(recipeIndex = recipeIndex)
    var
      recipeName: string = ""
      itemIndex: Natural = 0
      mType: ModuleType = alchemyLab
    if recipeIndex.len > 6 and recipeIndex[0..4] == "Study":
      itemIndex = recipeIndex[6..^1].strip.parseInt
      recipeName = "studying " & itemsList[itemIndex].name
    elif recipeIndex.len > 12 and recipeIndex[0..10] == "Deconstruct":
      itemIndex = recipeIndex[12..^1].strip.parseInt
      recipeName = "deconstructing " & itemsList[itemIndex].name
    else:
      recipeName = "manufacturing " & itemsList[recipe.resultIndex].name
      mType = recipesList[recipeIndex].workplace
    var haveWorkshop: bool = false
    for module in playerShip.modules:
      if modulesList[module.protoIndex].mType == mType and module.durability > 0:
        haveWorkshop = true
        break
    if not haveWorkshop:
      raise newException(exceptn = CraftingNoWorkshopError,
          message = recipeName)
    result = Positive.high
    var materialIndexes: seq[Natural] = @[]
    if recipeIndex.len > 6 and recipeIndex[0..4] == "Study":
      for i in playerShip.cargo.low..playerShip.cargo.high:
        if itemsList[playerShip.cargo[i].protoIndex].name == itemsList[
            recipe.resultIndex].name:
          materialIndexes.add(y = i)
          break
      result = 1
    elif recipeIndex.len > 12 and recipeIndex[0..10] == "Deconstruct":
      for i in playerShip.cargo.low..playerShip.cargo.high:
        if playerShip.cargo[i].protoIndex == itemIndex:
          materialIndexes.add(y = i)
          result = playerShip.cargo[i].amount
          break
    else:
      for j in recipe.materialTypes.low..recipe.materialTypes.high:
        for i in playerShip.cargo.low..playerShip.cargo.high:
          if itemsList[playerShip.cargo[i].protoIndex].itemType ==
              recipe.materialTypes[j] and playerShip.cargo[i].amount >=
              recipe.materialAmounts[j]:
            materialIndexes.add(y = i)
            if result > (playerShip.cargo[i].amount / recipe.materialAmounts[j]).Positive:
              result = (playerShip.cargo[i].amount / recipe.materialAmounts[j]).Positive
              break
    if materialIndexes.len < recipe.materialTypes.len:
      raise newException(exceptn = CraftingNoMaterialsError,
          message = recipeName)
    var haveTool: bool = false
    if recipe.tool != "None" and findItem(inventory = playerShip.cargo,
        itemType = recipe.tool, quality = recipe.toolQuality) > 0:
      haveTool = true
      if not haveTool:
        raise newException(exceptn = CraftingNoToolsError, message = recipeName)
    var spaceNeeded: Natural = 0
    for i in materialIndexes.low..materialIndexes.high:
      spaceNeeded += (itemsList[playerShip.cargo[materialIndexes[
          i]].protoIndex].weight * recipe.materialAmounts[i])
      if freeCargo(amount = spaceNeeded - (itemsList[
          recipe.resultIndex].weight * recipe.resultAmount)) < 0:
        raise newException(exceptn = TradeNoFreeCargoError, message = "")

proc resetOrder(module: var ModuleData; moduleOwner, toolIndex,
    crafterIndex: int) {.sideEffect, raises: [KeyError, CrewNoSpaceError,
    Exception], tags: [RootEffect], contractual.} =
  ## Reset the crafting order for the crafter and for the ship's module
  ##
  ## * module       - the player's ship's module which setting will be resetted
  ## * moduleOwner  - the index of the crafter in the player's ship's module who
  ##                  will have order resetted
  ## * toolIndex    - the index of the tool used for crafting
  ## * crafterIndex - the index of the crew member who crafts currently
  ##
  ## Returns the modified parameter module
  if toolIndex in 0..playerShip.crew[crafterIndex].inventory.high:
    updateCargo(ship = playerShip, protoIndex = playerShip.crew[
        crafterIndex].inventory[toolIndex].protoIndex, amount = 1,
        durability = playerShip.crew[crafterIndex].inventory[
        toolIndex].durability)
    updateInventory(memberIndex = crafterIndex, amount = -1,
        inventoryIndex = toolIndex, ship = playerShip)
  var haveWorker: bool = false
  for i in module.owner.low..module.owner.high:
    if module.owner[i] == moduleOwner or moduleOwner == -1:
      if module.owner[i] in 0..playerShip.crew.high:
        giveOrders(ship = playerShip, memberIndex = module.owner[i],
            givenOrder = rest)
      module.owner[i] = -1
    if module.owner[i] > -1:
      haveWorker = true
  if not haveWorker:
    module.craftingIndex = ""
    module.craftingTime = 0
    module.craftingAmount = 0

proc getMaterialIndexes(module: ModuleData; recipe: CraftData): seq[
    Positive] {.sideEffect, raises: [KeyError, ValueError], tags: [],
    contractual.} =
  ## Find indexes of materials needed to execute the selected crafting order
  ##
  ## * module - the player's ship' module in which the crafting order is set
  ## * recipe - the crafting order which will be executed
  ##
  ## Returns the list of indexes of materials needed to execute the crafting
  ## order
  if module.craftingIndex.len > 6 and module.craftingIndex[0..4] == "Study":
    for j in 1..itemsList.len:
      if itemsList[j].name == itemsList[recipe.resultIndex].name:
        result.add(y = j)
        break
  elif module.craftingIndex.len > 12 and module.craftingIndex[1..10] == "Deconstruct":
    result.add(y = module.craftingIndex[12..^1].strip.parseInt)
  else:
    for materialType in recipe.materialTypes:
      for j in 1..itemsList.len:
        if itemsList[j].itemType == materialType:
          result.add(y = j)
          break

proc crafterGainExp(recipe: CraftData; workTime: var int;
    module: var ModuleData; owner, toolIndex, crafterIndex: int) {.sideEffect,
    raises: [KeyError, Exception], tags: [RootEffect], contractual.} =
  ## Count and update experience gained by the crafter in the crafting skill
  ##
  ## * recipe       - the executed crafting recipe
  ## * workTime     - the amount of time spent on executing
  ## * module       - the player's ship's module in which the crafting order
  ##                  was executed
  ## * owner        - the index of the crafter in the player's ship's module
  ## * toolIndex    - the index of the tool used for crafting
  ## * crafterIndex - the index of the crew member who crafts currently
  var gainedExp: Natural = 0
  while workTime <= 0:
    gainedExp.inc
    workTime += 15
  if gainedExp > 0:
    gainExp(amount = gainedExp, skillNumber = recipe.skill,
        crewIndex = crafterIndex)
  playerShip.crew[crafterIndex].orderTime = workTime
  if module.craftingAmount == 0:
    resetOrder(module = module, moduleOwner = owner,
        toolIndex = toolIndex, crafterIndex = crafterIndex)

proc finishCrafting(recipe: CraftData; module: ModuleData; crafterIndex: int;
    craftedAmount: Natural) {.sideEffect, raises: [KeyError], tags: [],
    contractual.} =
  ## Show the summary message about crafting and update the current player's
  ## goal if needed
  ##
  ## * recipe        - the executed crafting recipe
  ## * module        - the player's ship's module in which the crafting order
  ##                   was executed
  ## * crafterIndex  - the index of the crew member who crafts currently
  ## * craftedAmount - the amount of crafted items
  if recipe.resultAmount > 0:
    if module.craftingIndex.len > 12 and module.craftingIndex[0..10] == "Deconstruct":
      addMessage(message = playerShip.crew[crafterIndex].name &
          " has recovered " & $craftedAmount & " " & itemsList[
          recipe.resultIndex].name & ".", mType = craftMessage, color = green)
    else:
      addMessage(message = playerShip.crew[crafterIndex].name &
          " has manufactured " & $craftedAmount & " " & itemsList[
          recipe.resultIndex].name & ".", mType = craftMessage, color = green)
    for key, protoRecipe in recipesList:
      if protoRecipe.resultIndex == recipe.resultIndex:
        updateGoal(goalType = GoalTypes.craft, targetIndex = key,
            amount = craftedAmount)
        break
    if currentGoal.targetIndex.len > 0:
      updateGoal(goalType = GoalTypes.craft, targetIndex = itemsList[
          recipe.resultIndex].itemType, amount = craftedAmount)
      if itemsList[recipe.resultIndex].showType.len > 0:
        updateGoal(goalType = GoalTypes.craft, targetIndex = itemsList[
            recipe.resultIndex].showType, amount = craftedAmount)
  else:
    addMessage(message = playerShip.crew[crafterIndex].name &
        " has discovered recipe for " & itemsList[
        recipe.resultIndex].name, mType = craftMessage, color = green)
    updateGoal(goalType = GoalTypes.craft, targetIndex = "")

proc craftItem(amount: var int; recipe: CraftData; resultAmount: Natural;
    recipeName: string; module: var ModuleData; owner, toolIndex,
    crafterIndex: int): bool {.sideEffect, raises: [KeyError, Exception],
    tags: [RootEffect], contractual.} =
  ## Craft or deconstruct the selected item
  ##
  ## * amount       - the amount of space needed for new items
  ## * recipe       - the executed crafting recipe
  ## * resultAmount - the amount of items crafted
  ## * module       - the player's ship's module in which the crafting order
  ##                  was executed
  ## * owner        - the index of the crafter in the player's ship's module
  ## * toolIndex    - the index of the tool used for crafting
  ## * crafterIndex - the index of the crew member who crafts currently
  ##
  ## Returns the modified parameter amount. Additionally, returns true if the
  ## crafting should stop otherwise false
  amount -= (itemsList[recipe.resultIndex].weight * resultAmount)
  if freeCargo(amount = amount) < 0:
    addMessage(message = "You don't have the free cargo space for " &
        recipeName, mType = craftMessage, color = red)
    resetOrder(module = module, moduleOwner = owner,
        toolIndex = toolIndex, crafterIndex = crafterIndex)
    return true
  if module.craftingIndex.len > 11 and module.craftingIndex[0..10] == "Deconstruct":
    updateCargo(ship = playerShip, protoIndex = recipe.resultIndex,
        amount = resultAmount)
  else:
    updateCargo(ship = playerShip, protoIndex = recipesList[
        module.craftingIndex].resultIndex, amount = resultAmount)
  for key, protoRecipe in recipesList:
    if protoRecipe.resultIndex == recipe.resultIndex:
      updateCraftingOrders(index = key)
      break
  return false

proc manufacturing*(minutes: Positive) {.sideEffect, raises: [ValueError,
    Exception], tags: [RootEffect], contractual.} =
  ## Execute the currently set crafting orders in the player's ship
  ##
  ## * minutes - the amount of minutes passed in the game time
  var toolIndex, crafterIndex: int = -1
  for module in playerShip.modules.mitems:
    if module.mType != ModuleType2.workshop:
      continue
    if module.craftingIndex.len == 0:
      continue
    for owner in module.owner:
      if owner == -1:
        continue
      crafterIndex = owner
      if playerShip.crew[crafterIndex].order != craft:
        continue
      var
        currentMinutes: int = minutes
        recipeTime: int = module.craftingTime
        recipeName: string = ""
      let recipe: CraftData = setRecipeData(recipeIndex = module.craftingIndex)
      if module.craftingIndex.len > 6 and module.craftingIndex[0..4] == "Study":
        recipeName = "studying " & itemsList[recipe.resultIndex].name
      elif module.craftingIndex.len > 12 and module.craftingIndex[0..10] == "Deconstruct":
        recipeName = "deconstructing " & itemsList[module.craftingIndex[
            12..^1].strip.parseInt].name
      else:
        recipeName = "manufacturing " & itemsList[recipe.resultIndex].name
      if module.durability == 0:
        addMessage(message = module.name & " is destroyed, so " &
            playerShip.crew[crafterIndex].name & " can't work on " &
            recipeName & ".", mType = craftMessage, color = red)
        resetOrder(module = module, moduleOwner = owner, toolIndex = toolIndex,
            crafterIndex = crafterIndex)
        currentMinutes = 0
      var
        workTime: int = playerShip.crew[crafterIndex].orderTime
        craftedAmount: Natural = 0
      while currentMinutes > 0:
        if currentMinutes < recipeTime:
          recipeTime.dec(y = currentMinutes)
          workTime.dec(y = currentMinutes)
          currentMinutes = 0
          break
        recipeTime -= currentMinutes
        workTime = workTime - currentMinutes - recipeTime
        currentMinutes = 0 - recipeTime
        recipeTime = recipe.time
        var materialIndexes: seq[Positive] = getMaterialIndexes(module = module,
            recipe = recipe)
        var craftingMaterial: int = -1
        for materialIndex in materialIndexes.mitems:
          craftingMaterial = findItem(inventory = playerShip.cargo,
              itemType = itemsList[materialIndex].itemType)
          if craftingMaterial == -1:
            addMessage(message = "You don't have the crafting materials for " &
                recipeName & ".", mType = craftMessage, color = red)
            resetOrder(module = module, moduleOwner = owner,
                toolIndex = toolIndex, crafterIndex = crafterIndex)
            break
          elif playerShip.cargo[craftingMaterial].protoIndex != materialIndex:
            materialIndex = playerShip.cargo[craftingMaterial].protoIndex
        if craftingMaterial == -1:
          break
        if recipe.tool == "None":
          toolIndex = -1
        else:
          toolIndex = findTools(memberIndex = crafterIndex,
              itemType = recipe.tool, order = craft,
              toolQuality = recipe.toolQuality)
          if toolIndex == -1:
            addMessage(message = "You don't have the tool for " & recipeName &
                ".", mType = craftMessage, color = red)
            break
        var amount: Natural = 0
        for j in 0..materialIndexes.high:
          amount += (itemsList[materialIndexes[j]].weight *
              recipe.materialAmounts[j])
        var resultAmount: Natural = recipe.resultAmount + (
            recipe.resultAmount.float * (getSkillLevel(member = playerShip.crew[
            crafterIndex], skillIndex = recipe.skill).float / 100.0)).int
        let damage: float = 1.0 - (module.durability.float /
            module.maxDurability.float)
        resultAmount -= (resultAmount.float * damage).int
        if resultAmount == 0:
          resultAmount = 1
        var haveMaterial: bool = false
        for j in 0..materialIndexes.high:
          haveMaterial = false
          for item in playerShip.cargo:
            if itemsList[item.protoIndex].itemType == itemsList[
                materialIndexes[j]].itemType and item.amount >=
                    recipe.materialAmounts[j]:
              haveMaterial = true
              break
          if not haveMaterial:
            break
        if not haveMaterial:
          addMessage(message = "You don't have enough crafting materials for " &
              recipeName & ".", mType = craftMessage, color = red)
          resetOrder(module = module, moduleOwner = owner,
              toolIndex = toolIndex, crafterIndex = crafterIndex)
          break
        craftedAmount += resultAmount
        module.craftingAmount.dec
        for j in 0..materialIndexes.high:
          var cargoIndex: Natural = 0
          while cargoIndex <= playerShip.cargo.high:
            var material: InventoryData = playerShip.cargo[cargoIndex]
            if itemsList[material.protoIndex].itemType == itemsList[
                materialIndexes[j]].itemType:
              if material.amount > recipe.materialAmounts[j]:
                let newAmount: Natural = material.amount -
                    recipe.materialAmounts[j]
                material.amount = newAmount
                playerShip.cargo[cargoIndex] = material
                break
              elif material.amount == recipe.materialAmounts[j]:
                playerShip.cargo.delete(i = cargoIndex)
                if toolIndex > cargoIndex:
                  toolIndex.dec
                break
            cargoIndex.inc
        if toolIndex > -1:
          damageItem(inventory = playerShip.crew[crafterIndex].inventory,
              itemIndex = toolIndex, skillLevel = getSkillLevel(
              member = playerShip.crew[crafterIndex],
              skillIndex = recipe.skill), memberIndex = crafterIndex,
              ship = playerShip)
        if module.craftingIndex.len < 6 or (module.craftingIndex.len > 6 and
            module.craftingIndex[0..4] != "Study"):
          if craftItem(amount = amount, recipe = recipe,
              resultAmount = resultAmount, recipeName = recipeName,
              module = module, owner = owner, toolIndex = toolIndex,
              crafterIndex = crafterIndex):
            break
        else:
          for key, recipe in recipesList:
            if recipe.resultIndex == recipe.resultIndex:
              knownRecipes.add(y = key)
      module.craftingTime = recipeTime
      if craftedAmount > 0:
        finishCrafting(recipe = recipe, module = module,
            crafterIndex = crafterIndex, craftedAmount = craftedAmount)
      if playerShip.crew[crafterIndex].order == craft:
        crafterGainExp(recipe = recipe, workTime = workTime, module = module,
            owner = owner, toolIndex = toolIndex, crafterIndex = crafterIndex)

proc setRecipe*(workshop: Natural; amount: Positive;
    recipeIndex: string) {.sideEffect, raises: [ValueError, CrewOrderError,
    CrewNoSpaceError, Exception], tags: [RootEffect], contractual.} =
  ## Set the selected crafting recipe for the selected workshop in the player's
  ## ship
  ##
  ## * workshop    - the index of the workshop in which the recipe will be set
  ## * amount      - how many times the recipe will be made
  ## * recipeIndex - the index of the crafting recipe to set
  require:
    workshop < playerShip.modules.len
    recipeIndex.len > 0
  body:
    playerShip.modules[workshop].craftingAmount = amount
    var
      itemIndex: Natural = 0
      recipeName: string = ""
    if recipeIndex.len > 6 and recipeIndex[0..4] == "Study":
      itemIndex = recipeIndex[6..^1].strip.parseInt
      for recipe in recipesList.values:
        if recipe.resultIndex == itemIndex:
          playerShip.modules[workshop].craftingTime = recipe.difficulty * 15
          break
      recipeName = "Studying " & itemsList[itemIndex].name
      playerShip.modules[workshop].craftingIndex = recipeIndex
    elif recipeIndex.len > 12 and recipeIndex[0..10] == "Deconstruct":
      itemIndex = recipeIndex[12..^1].strip.parseInt
      for recipe in recipesList.values:
        if recipe.resultIndex == itemIndex:
          playerShip.modules[workshop].craftingTime = recipe.difficulty * 15
          break
      recipeName = "Deconstructing " & itemsList[itemIndex].name
      playerShip.modules[workshop].craftingIndex = recipeIndex
    else:
      playerShip.modules[workshop].craftingIndex = recipeIndex.strip
      playerShip.modules[workshop].craftingTime = recipesList[recipeIndex].time
      recipeName = itemsList[recipesList[recipeIndex].resultIndex].name
    addMessage(message = recipeName & " was set as manufacturing order in " &
        playerShip.modules[workshop].name & ".",
        mType = orderMessage)
    updateOrders(ship = playerShip)

proc getWorkshopRecipeName*(workshop: Natural): string {.sideEffect, raises: [
    KeyError, ValueError], tags: [], contractual.} =
  ## Get the name of the recipe set as working order for the selected workshop
  ##
  ## * workshop - the index of the workshop which crafting order recipe name
  ##              will be get
  ##
  ## Returns the name of the recipe set as the crafting order or empty string if nothing
  ## is set
  require:
    workshop < playerShip.modules.len
  body:
    let module: ModuleData = playerShip.modules[workshop]
    if module.craftingIndex.len > 0:
      if module.craftingIndex.len > 6 and module.craftingIndex[0..4] == "Study":
        return "Studying " & itemsList[module.craftingIndex[
            6..^1].strip.parseInt].name
      elif module.craftingIndex.len > 12 and module.craftingIndex[0..10] == "Deconstruct":
        return "Deconstructing " & itemsList[module.craftingIndex[
            12..^1].strip.parseInt].name
      else:
        return "Manufacturing " & $module.craftingAmount & "x " & itemsList[
            recipesList[module.craftingIndex].resultIndex].name
    return ""

# Temporary code for interfacing with Ada

type
  AdaCraftData = object
    materialTypes: array[0..4, cstring]
    materialAmounts: array[0..4, cint]
    resultIndex: cint
    resultAmount: cint
    workplace: cint
    skill: cint
    time: cint
    difficulty: cint
    tool: cstring
    reputation: cint
    toolQuality: cint

proc getAdaCraftData(index: cstring; adaRecipe: var AdaCraftData) {.sideEffect,
    raises: [], tags: [], exportc, contractual.} =
  ## Temporary C binding
  adaRecipe = AdaCraftData(resultIndex: 0, resultAmount: 0, workplace: 0,
      skill: 0, time: 1, difficulty: 1, tool: "".cstring, reputation: -100,
      toolQuality: 1)
  for i in 0..4:
    adaRecipe.materialTypes[i] = "".cstring
    adaRecipe.materialAmounts[i] = 0
  let recipeKey: string = strip(s = $index)
  if not recipesList.hasKey(key = recipeKey):
    return
  let recipe: CraftData = try:
      recipesList[recipeKey]
    except KeyError:
      return
  adaRecipe.resultIndex = recipe.resultIndex.cint
  adaRecipe.resultAmount = recipe.resultAmount.cint
  adaRecipe.workplace = recipe.workplace.ord().cint
  adaRecipe.skill = recipe.skill.cint
  adaRecipe.time = recipe.time.cint
  adaRecipe.difficulty = recipe.difficulty.cint
  adaRecipe.tool = recipe.tool.cstring
  adaRecipe.toolQuality = recipe.toolQuality.cint
  adaRecipe.reputation = recipe.reputation.cint
  for i in 0..recipe.materialTypes.high:
    adaRecipe.materialTypes[i] = recipe.materialTypes[i].cstring
    adaRecipe.materialAmounts[i] = recipe.materialAmounts[i].cint

proc getAdaWorkshopRecipeName(workshop: cint): cstring {.raises: [], tags: [],
    exportc, contractual.} =
  ## Temporary C binding
  try:
    return getWorkshopRecipeName(workshop = workshop).cstring
  except ValueError:
    return "".cstring

proc setAdaRecipe(workshop, amount: cint; recipeIndex: cstring) {.raises: [],
    tags: [RootEffect], exportc, contractual.} =
  ## Temporary C binding
  try:
    setRecipe(workshop = workshop.Natural - 1, amount = amount.Positive,
        recipeIndex = $recipeIndex)
  except ValueError, Exception:
    discard

proc setAdaRecipeData(recipeIndex: cstring;
    adaRecipe: var AdaCraftData) {.raises: [], tags: [], exportc,
        contractual.} =
  ## Temporary C binding
  adaRecipe = AdaCraftData(resultIndex: 0, resultAmount: 0, workplace: 0,
      skill: 0, time: 1, difficulty: 1, tool: "".cstring, reputation: -100,
      toolQuality: 1)
  for i in 0..4:
    adaRecipe.materialTypes[i] = "".cstring
    adaRecipe.materialAmounts[i] = 0
  try:
    let recipe: CraftData = setRecipeData(recipeIndex = $recipeIndex)
    adaRecipe.resultIndex = recipe.resultIndex.cint
    adaRecipe.resultAmount = recipe.resultAmount.cint
    adaRecipe.workplace = recipe.workplace.ord().cint
    adaRecipe.skill = recipe.skill.cint
    adaRecipe.time = recipe.time.cint
    adaRecipe.difficulty = recipe.difficulty.cint
    adaRecipe.tool = recipe.tool.cstring
    adaRecipe.toolQuality = recipe.toolQuality.cint
    adaRecipe.reputation = recipe.reputation.cint
    for i in 0..recipe.materialTypes.high:
      adaRecipe.materialTypes[i] = recipe.materialTypes[i].cstring
      adaRecipe.materialAmounts[i] = recipe.materialAmounts[i].cint
  except ValueError:
    discard

proc checkAdaRecipe(recipeIndex: cstring): cint {.raises: [], tags: [], exportc,
    contractual.} =
  ## Temporary C binding
  try:
    return checkRecipe(recipeIndex = $recipeIndex).cint
  except ValueError:
    return 0
  except TradeNoFreeCargoError:
    return -1
  except CraftingNoWorkshopError:
    return -2
  except CraftingNoMaterialsError:
    return -3
  except CraftingNoToolsError:
    return -4

proc adaManufacturing(minutes: cint) {.raises: [], tags: [RootEffect], exportc,
    contractual.} =
  ## Temporary C binding
  try:
    manufacturing(minutes = minutes.Positive)
  except ValueError, Exception:
    discard

proc getAdaRecipesAmount(): cint {.raises: [], tags: [], exportc,
    contractual.} =
  ## Temporary C binding
  return recipesList.len.cint

proc isAdaKnownRecipe(recipeIndex: cstring): cint {.raises: [], tags: [],
    exportc, contractual.} =
  ## Temporary C binding
  if $recipeIndex in knownRecipes:
    return 1
  return 0

proc addAdaKnownRecipe(recipeIndex: cstring) {.raises: [], tags: [], exportc,
    contractual.} =
  ## Temporary C binding
  knownRecipes.add(y = $recipeIndex)

proc getAdaKnownRecipe(index: cint): cstring {.raises: [], tags: [], exportc,
    contractual.} =
  ## Temporary C binding
  if index < knownRecipes.len:
    return knownRecipes[index].cstring
  return "".cstring

proc getAdaKnownRecipesAmount(): cint {.raises: [], tags: [], exportc,
    contractual.} =
  ## Temporary C binding
  return knownRecipes.len.cint
