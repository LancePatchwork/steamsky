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
import game, log, shipscrew2, types, utils

func getCabinQuality*(quality: cint): cstring {.gcsafe, raises: [], tags: [], exportc.} =
  ## Get the description of quality of the selected cabin in the player's ship
  ##
  ## * quality - The numerical value of the cabin's quality which will be
  ##             converted to string
  ##
  ## Returns the string with the description of the cabin's quality
  case quality
  of 0..10:
    return "Empty room"
  of 11..20:
    return "Minimal quality"
  of 21..30:
    return "Basic quality"
  of 31..40:
    return "Second class"
  of 41..50:
    return "Medium quality"
  of 51..60:
    return "First class"
  of 61..70:
    return "Extended quality"
  of 71..80:
    return "Encrusted room"
  of 81..90:
    return "Luxury quality"
  else:
    return "Palace room"

proc generateShipName*(factionIndex: string): string {.sideEffect, raises: [],
    tags: [].} =
  ## Generate the name for the ship, based on its owner's faction. Based
  ## on libtcod names generator
  ##
  ## * factionIndex - the index of the faction to which the ship belongs
  ##
  ## Returns the randomly generated name of the ship
  try:
    if factionsList[factionIndex].namesType == robotic:
      return $generateRoboticName()
  except KeyError:
    discard
  result = shipsSyllablesStartList[getRandom(min = 0, max = (
      shipsSyllablesStartList.len - 1))]
  if getRandom(min = 1, max = 100) < 51:
    result = result & shipsSyllablesMiddleList[getRandom(min = 0, max = (
        shipsSyllablesMiddleList.len - 1))]
  result = result & shipsSyllablesEndList[getRandom(min = 0, max = (
      shipsSyllablesEndList.len - 1))]

proc loadShips*(fileName: string) {.sideEffect, raises: [DataLoadingError],
    tags: [WriteIOEffect, ReadIOEffect, RootEffect].} =
  ## Load the ships data from the file
  ##
  ## * fileName - the name of the file to load
  let shipsXml = try:
      loadXml(path = fileName)
    except XmlError, ValueError, IOError, OSError, Exception:
      raise newException(exceptn = DataLoadingError,
          message = "Can't load ships data file. Reason: " &
          getCurrentExceptionMsg())
  for shipNode in shipsXml:
    if shipNode.kind != xnElement:
      continue
    let
      shipIndex: Natural = try:
          shipNode.attr(name = "index").parseInt()
        except ValueError:
          raise newException(exceptn = DataLoadingError,
              message = "Can't add ship '" & shipNode.attr(name = "index") & "', invalid index.")
      shipAction: DataAction = try:
          parseEnum[DataAction](shipNode.attr(name = "action").toLowerAscii)
        except ValueError:
          DataAction.add
    if shipAction in [update, remove]:
      if shipIndex > protoShipsList.len():
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex & "', there is no ship with that index.")
    elif shipIndex < protoShipsList.len():
      raise newException(exceptn = DataLoadingError,
          message = "Can't add ship '" & $shipIndex & "', there is an ship with that index.")
    if shipAction == DataAction.remove:
      {.warning[ProveInit]: off.}
      {.warning[UnsafeDefault]: off.}
      protoShipsList.del(key = shipIndex)
      {.warning[ProveInit]: on.}
      {.warning[UnsafeDefault]: on.}
      logMessage(message = "Ship removed: '" & $shipIndex & "'",
          debugType = everything)
      continue
    var ship: ProtoShipData = if shipAction == DataAction.update:
        try:
          protoShipsList[shipIndex]
        except ValueError:
          ProtoShipData(combatValue: 1)
      else:
        ProtoShipData(combatValue: 1)
    var attribute = shipNode.attr(name = "name")
    if attribute.len() > 0:
      ship.name = attribute
    for module in shipNode.findAll(tag = "module"):
      let
        moduleAmount = try:
            module.attr(name = "amount").parseInt()
          except ValueError:
            1
        moduleIndex = try:
            module.attr(name = "index").parseInt()
          except ValueError:
          raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex &
                "', invalid value for module index.")
        moduleAction: DataAction = try:
            parseEnum[DataAction](module.attr(name = "action").toLowerAscii)
          except ValueError:
            DataAction.add
      if moduleAction == DataAction.add:
        for i in 1 .. moduleAmount:
          ship.modules.add(y = moduleIndex)
      else:
        for mIndex, pModule in ship.modules.pairs:
          if pModule == moduleIndex:
            {.warning[UnsafeSetLen]: off.}
            ship.modules.delete(i = mIndex)
            {.warning[UnsafeSetLen]: on.}
            break
    attribute = shipNode.attr(name = "accuracy")
    if attribute.len() > 0:
      ship.accuracy.minValue = try:
          attribute.parseInt()
      except ValueError:
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex & "', invalid value for ship bonus accuracy.")
      ship.accuracy.maxValue = 0
    attribute = shipNode.attr(name = "minaccuracy")
    if attribute.len() > 0:
      ship.accuracy.minValue = try:
          attribute.parseInt()
      except ValueError:
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex & "', invalid value for ship bonus minimum accuracy.")
      attribute = shipNode.attr(name = "maxaccuracy")
      ship.accuracy.maxValue = try:
          attribute.parseInt()
      except ValueError:
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex & "', invalid value for ship bonus maximum accuracy.")
      if ship.accuracy.maxValue < ship.accuracy.minValue:
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex & "', invalid range for ship bonus accuracy.")
    attribute = shipNode.attr(name = "combatai")
    if attribute.len() > 0:
      ship.combatAi = try:
          parseEnum[ShipCombatAi](attribute.toLowerAscii)
      except ValueError:
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex & "', invalid value for ship combat AI.")
    attribute = shipNode.attr(name = "evasion")
    if attribute.len() > 0:
      ship.evasion.minValue = try:
          attribute.parseInt()
      except ValueError:
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex & "', invalid value for ship bonus evasion.")
      ship.evasion.maxValue = 0
    attribute = shipNode.attr(name = "minevasion")
    if attribute.len() > 0:
      ship.evasion.minValue = try:
          attribute.parseInt()
      except ValueError:
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex & "', invalid value for ship bonus minimum evasion.")
      attribute = shipNode.attr(name = "maxevasion")
      ship.evasion.maxValue = try:
          attribute.parseInt()
      except ValueError:
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex & "', invalid value for ship bonus maximum evasion.")
      if ship.evasion.maxValue < ship.evasion.minValue:
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex & "', invalid range for ship bonus evasion.")
    attribute = shipNode.attr(name = "loot")
    if attribute.len() > 0:
      ship.loot.minValue = try:
          attribute.parseInt()
      except ValueError:
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex & "', invalid value for ship loot.")
      ship.loot.maxValue = 0
    attribute = shipNode.attr(name = "minloot")
    if attribute.len() > 0:
      ship.loot.minValue = try:
          attribute.parseInt()
      except ValueError:
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex & "', invalid value for ship minimum loot.")
      attribute = shipNode.attr(name = "maxloot")
      ship.loot.maxValue = try:
          attribute.parseInt()
      except ValueError:
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex & "', invalid value for ship maximum loot.")
      if ship.loot.maxValue < ship.loot.minValue:
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex & "', invalid range for ship loot.")
    attribute = shipNode.attr(name = "perception")
    if attribute.len() > 0:
      ship.perception.minValue = try:
          attribute.parseInt()
      except ValueError:
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex & "', invalid value for ship bonus perception.")
      ship.perception.maxValue = 0
    attribute = shipNode.attr(name = "minperception")
    if attribute.len() > 0:
      ship.perception.minValue = try:
          attribute.parseInt()
      except ValueError:
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex & "', invalid value for ship bonus minimum perception.")
      attribute = shipNode.attr(name = "maxperception")
      ship.perception.maxValue = try:
          attribute.parseInt()
      except ValueError:
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex & "', invalid value for ship bonus maximum perception.")
      if ship.perception.maxValue < ship.perception.minValue:
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex & "', invalid range for ship bonus perception.")
    for item in shipNode.findAll(tag = "cargo"):
      let itemIndex = try:
            item.attr(name = "index").parseInt()
          except ValueError:
          raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex &
                "', invalid value for cargo item index.")
      if not itemsList.contains(key = itemIndex):
        raise newException(exceptn = DataLoadingError,
          message = "Can't " & $shipAction & " ship '" & $shipIndex &
              "', invalid value for cargo item index.")
      let
        itemAction: DataAction = try:
            parseEnum[DataAction](item.attr(name = "action").toLowerAscii)
          except ValueError:
            DataAction.add
        itemAmount = try:
            item.attr(name = "amount").parseInt()
          except ValueError:
            0
      var minAmount, maxAmount = 0
      if itemAmount == 0:
        minAmount = try:
              item.attr(name = "minamount").parseInt()
            except ValueError:
            raise newException(exceptn = DataLoadingError,
              message = "Can't " & $shipAction & " ship '" & $shipIndex &
                  "', invalid value for cargo item minamount.")
        maxAmount = try:
            item.attr(name = "maxamount").parseInt()
          except ValueError:
          raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex &
                "', invalid value for cargo item maxamount.")
        if minAmount > maxAmount:
          raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex &
                "', invalid value for cargo item amount range.")
      case itemAction
      of DataAction.add:
        if itemAmount > 0:
          ship.cargo.add(y = MobInventoryRecord(protoIndex: itemIndex,
              minAmount: itemAmount, maxAmount: 0))
        else:
          ship.cargo.add(y = MobInventoryRecord(protoIndex: itemIndex,
              minAmount: minAmount, maxAmount: maxAmount))
      of DataAction.update:
        for cargoItem in ship.cargo.mitems:
          if cargoItem.protoIndex == itemIndex:
            if itemAmount > 0:
              cargoItem.minAmount = itemAmount
              cargoItem.maxAmount = 0
            else:
              cargoItem.minAmount = minAmount
              cargoItem.maxAmount = maxAmount
            break
      of DataAction.remove:
        var cargoIndex = 0
        while cargoIndex < ship.cargo.len:
          if ship.cargo[cargoIndex].protoIndex == itemIndex:
            ship.cargo.delete(i = cargoIndex)
            break
          cargoIndex.inc
    attribute = shipNode.attr(name = "owner")
    if attribute.len() > 0:
      ship.owner = attribute
    for recipe in shipNode.findAll(tag = "recipe"):
      let recipeIndex = recipe.attr(name = "index")
      if not recipesList.contains(key = recipeIndex):
        raise newException(exceptn = DataLoadingError,
          message = "Can't " & $shipAction & " ship '" & $shipIndex &
              "', invalid value for known recipe index.")
      let
        recipeAction: DataAction = try:
            parseEnum[DataAction](recipe.attr(name = "action").toLowerAscii)
          except ValueError:
            DataAction.add
      if recipeAction == DataAction.add:
        ship.knownRecipes.add(y = recipeIndex)
      else:
        for rIndex, knownRecipe in ship.knownRecipes.pairs:
          if knownRecipe == recipeIndex:
            ship.knownRecipes.delete(i = rIndex)
            break
    for member in shipNode.findAll(tag = "member"):
      let memberIndex = try:
            member.attr(name = "index").parseInt()
          except ValueError:
          raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex &
                "', invalid value for crew member index.")
      if not protoMobsList.contains(key = memberIndex):
        raise newException(exceptn = DataLoadingError,
          message = "Can't " & $shipAction & " ship '" & $shipIndex &
              "', invalid value for crew member index.")
      let memberAction: DataAction = try:
            parseEnum[DataAction](member.attr(name = "action").toLowerAscii)
          except ValueError:
            DataAction.add
      var memberAmount = try:
            member.attr(name = "amount").parseInt()
          except ValueError:
            0
      var minAmount, maxAmount = 0
      if memberAmount == 0:
        minAmount = try:
              member.attr(name = "minamount").parseInt()
            except ValueError:
              0
        maxAmount = try:
            member.attr(name = "maxamount").parseInt()
          except ValueError:
            1
        if minAmount > maxAmount:
          raise newException(exceptn = DataLoadingError,
            message = "Can't " & $shipAction & " ship '" & $shipIndex &
                "', invalid value for crew member amount range.")
        if minAmount == 0:
          memberAmount = 1
      case memberAction
      of DataAction.add:
        if memberAmount > 0:
          ship.crew.add(y = ProtoMemberData(protoIndex: memberIndex,
              minAmount: memberAmount, maxAmount: 0))
        else:
          ship.crew.add(y = ProtoMemberData(protoIndex: memberIndex,
              minAmount: minAmount, maxAmount: maxAmount))
      of DataAction.update:
        for crewMember in ship.crew.mitems:
          if crewMember.protoIndex == memberIndex:
            if memberAmount > 0:
              crewMember.minAmount = memberAmount
              crewMember.maxAmount = 0
            else:
              crewMember.minAmount = minAmount
              crewMember.maxAmount = maxAmount
            break
      of DataAction.remove:
        var crewIndex = 0
        while crewIndex < ship.crew.len:
          if ship.crew[crewIndex].protoIndex == memberIndex:
            {.warning[UnsafeSetLen]: off.}
            ship.crew.delete(i = crewIndex)
            {.warning[UnsafeSetLen]: on.}
            break
          crewIndex.inc
    for description in shipNode.findAll(tag = "description"):
      ship.description = description.innerText()

    proc countAmmoValue(itemTypeIndex, multiple: Positive) =
      for item in ship.cargo.items:
        if itemsList[item.protoIndex].itemType == itemsTypesList[itemTypeIndex - 1]:
          ship.combatValue = ship.combatValue + (itemsList[
              item.protoIndex].value[1] * multiple)

    for moduleIndex in ship.modules.items:
      try:
        let module = modulesList[moduleIndex]
        case module.mType
        of ModuleType.hull, ModuleType.gun, ModuleType.batteringRam:
          ship.combatValue = ship.combatValue + module.durability + (
              module.maxValue * 10)
          if module.mType == ModuleType.gun:
            countAmmoValue(itemTypeIndex = module.value, multiple = 10)
        of ModuleType.armor:
          ship.combatValue = ship.combatValue + module.durability
        of ModuleType.harpoonGun:
          ship.combatValue = ship.combatValue + module.durability + (
              module.maxValue * 5)
          countAmmoValue(itemTypeIndex = module.value, multiple = 5)
        else:
          discard
      except KeyError:
        raise newException(exceptn = DataLoadingError,
          message = "Can't " & $shipAction & " ship '" & $shipIndex &
              "', invalid index for module during counting the ship's combat value.")
    ship.combatValue.dec
    if shipAction == DataAction.add:
      logMessage(message = "Ship added: '" & $shipIndex & "'",
          debugType = everything)
    else:
      logMessage(message = "Ship updated: '" & $shipIndex & "'",
          debugType = everything)
    protoShipsList[shipIndex] = ship

proc damageModule*(ship: var ShipRecord, moduleIndex: Natural, damage: Positive,
    deathReason: string) {.sideEffect, raises: [KeyError, IOError], tags: [
    WriteIOEffect].} =
  ## Damage the selected module, kill its owner if the module was destroyed
  ##
  ## * ship        - the ship in which the module will be damaged
  ## * moduleIndex - the index of the module to damage
  ## * damage      - the amount of damage which the module will taken
  ## * deathReason - the reason of damage, used to inform about the module's
  ##                 owner death
  ##
  ## Returns the updated parameter ship

  proc removeGun(moduleIndex2: Natural; ship: var ShipRecord) =
    if ship.modules[moduleIndex2].owner[0] > -1:
      death(memberIndex = ship.modules[moduleIndex2].owner[0],
          reason = deathReason, ship = ship)

  let realDamage = if damage > ship.modules[moduleIndex].durability:
      ship.modules[moduleIndex].durability
    else:
      damage
  ship.modules[moduleIndex].durability = ship.modules[moduleIndex].durability - realDamage
  if ship.modules[moduleIndex].durability == 0:
    case modulesList[ship.modules[moduleIndex].protoIndex].mType
    of ModuleType.hull, ModuleType.engine:
      if ship.crew == playerShip.crew:
        death(memberIndex = 0, reason = deathReason, ship = playerShip)
    of ModuleType.turret:
      let weaponIndex = ship.modules[moduleIndex].gunIndex
      if weaponIndex > -1:
        ship.modules[weaponIndex].durability = 0
        removeGun(moduleIndex2 = weaponIndex, ship = ship)
    of ModuleType.gun:
      removeGun(moduleIndex2 = moduleIndex, ship = ship)
    of ModuleType.cabin:
      for owner in ship.modules[moduleIndex].owner:
        if owner > -1 and ship.crew[owner].order == rest:
          death(memberIndex = owner, reason = deathReason, ship = ship)
    else:
      if ship.modules[moduleIndex].owner.len > 0:
        if ship.modules[moduleIndex].owner[0] > -1 and ship.crew[ship.modules[
            moduleIndex].owner[0]].order != rest:
          death(memberIndex = ship.modules[moduleIndex].owner[0],
              reason = deathReason, ship = ship)

proc countCombatValue*(): Natural {.sideEffect, raises: [KeyError], tags: [].} =
  ## Count the combat value of the player's ship based on its modules,
  ## weapons and ammunition.
  ##
  ## Returns the combat value of the player's ship.
  proc countAmmoValue(itemTypeIndex: Natural; multiple: Positive): Natural =
    for item in playerShip.cargo.items:
      if itemsList[item.protoIndex].itemType == itemsTypesList[itemTypeIndex]:
        result = result + itemsList[item.protoIndex].value[1] * multiple

  for module in playerShip.modules:
    case modulesList[module.protoIndex].mType
    of ModuleType.batteringRam:
      result = result + module.damage2
    of ModuleType.gun:
      result = result + module.maxDurability + (module.damage * 10)
      result = result + countAmmoValue(itemTypeIndex = modulesList[
          module.protoIndex].value, multiple = 10)
    of ModuleType.armor:
      result = result + module.maxDurability
    of ModuleType.harpoonGun:
      result = result + module.maxDurability + (module.duration * 5)
      result = result + countAmmoValue(itemTypeIndex = modulesList[
          module.protoIndex].value, multiple = 5)
    of ModuleType.hull:
      result = result + module.maxDurability + (module.maxModules * 10)
    else:
      discard

# Temporary code for interfacing with Ada

type
  AdaShipData = object
    name: cstring
    skyX: cint
    skyY: cint
    speed: cint
    upgradeModule: cint
    destinationX: cint
    destinationY: cint
    repairModule: cint
    description: cstring
    homeBase: cint

  AdaModuleData = object
    name: cstring
    protoIndex: cint
    weight: cint
    durability: cint
    maxDurability: cint
    owner: array[1..10, cint]
    upgradeProgress: cint
    upgradeAction: cint
    mType: cint
    data: array[1..3, cint]
    data2: cstring

  AdaProtoShipData = object
    name: cstring
    accuracy: array[2, cint]
    combatAi: cint
    evasion: array[2, cint]
    loot: array[2, cint]
    perception: array[2, cint]
    combatValue: cint
    description: cstring
    owner: cstring

proc generateAdaShipName(factionIndex: cstring): cstring {.sideEffect, raises: [
    ], tags: [], exportc.} =
  return generateShipName(factionIndex = $factionIndex).cstring

proc getAdaShip(shipData: AdaShipData; getPlayerShip: cint = 1) {.raises: [],
    tags: [], exportc.} =
  if getPlayerShip == 1:
    playerShip.name = $shipData.name
    playerShip.skyX = shipData.skyX
    playerShip.skyY = shipData.skyY
    playerShip.speed = shipData.speed.ShipSpeed
    playerShip.upgradeModule = shipData.upgradeModule - 1
    playerShip.destinationX = shipData.destinationX
    playerShip.destinationY = shipData.destinationY
    playerShip.repairModule = shipData.repairModule - 1
    playerShip.description = $shipData.description
    playerShip.homeBase = shipData.homeBase
  else:
    npcShip.name = $shipData.name
    npcShip.skyX = shipData.skyX
    npcShip.skyY = shipData.skyY
    npcShip.speed = shipData.speed.ShipSpeed
    npcShip.upgradeModule = shipData.upgradeModule - 1
    npcShip.destinationX = shipData.destinationX
    npcShip.destinationY = shipData.destinationY
    npcShip.repairModule = shipData.repairModule - 1
    npcShip.description = $shipData.description
    npcShip.homeBase = shipData.homeBase

proc getAdaShipModules(modules: array[1..75, AdaModuleData];
    getPlayerShip: cint = 1) {.raises: [], tags: [], exportc.} =
  if getPlayerShip == 1:
    playerShip.modules = @[]
  else:
    npcShip.modules = @[]
  for adaModule in modules:
    if adaModule.mType == -1:
      return
    var module: ModuleData
    case adaModule.mType.ModuleType2
    of ModuleType2.engine:
      module = ModuleData(mType: ModuleType2.engine,
          fuelUsage: adaModule.data[1], power: adaModule.data[2],
          disabled: adaModule.data[3] == 1)
    of ModuleType2.cabin:
      module = ModuleData(mType: ModuleType2.cabin, cleanliness: adaModule.data[
          1], quality: adaModule.data[2])
    of ModuleType2.turret:
      module = ModuleData(mType: ModuleType2.turret, gunIndex: adaModule.data[
          1] - 1)
    of ModuleType2.gun:
      module = ModuleData(mType: ModuleType2.gun, damage: adaModule.data[1],
          ammoIndex: adaModule.data[2] - 1)
    of ModuleType2.hull:
      module = ModuleData(mType: ModuleType2.hull,
          installedModules: adaModule.data[1], maxModules: adaModule.data[2])
    of ModuleType2.workshop:
      module = ModuleData(mType: ModuleType2.workshop,
          craftingIndex: $adaModule.data2, craftingTime: adaModule.data[1],
              craftingAmount: adaModule.data[2])
    of ModuleType2.trainingRoom:
      module = ModuleData(mType: ModuleType2.trainingRoom,
          trainedSkill: adaModule.data[1])
    of ModuleType2.batteringRam:
      module = ModuleData(mType: ModuleType2.batteringRam,
          damage2: adaModule.data[1], coolingDown: adaModule.data[2] == 1)
    of ModuleType2.harpoonGun:
      module = ModuleData(mType: ModuleType2.harpoonGun,
          duration: adaModule.data[1], harpoonIndex: adaModule.data[2] - 1)
    of ModuleType2.any:
      module = ModuleData(mType: ModuleType2.any, data: [1: adaModule.data[
          1].int, 2: adaModule.data[2].int, 3: adaModule.data[3].int])
    of ModuleType2.cargoRoom:
      module = ModuleData(mType: ModuleType2.cargoRoom)
    of ModuleType2.medicalRoom:
      module = ModuleData(mType: ModuleType2.medicalRoom)
    of ModuleType2.cockpit:
      module = ModuleData(mType: ModuleType2.cockpit)
    of ModuleType2.armor:
      module = ModuleData(mType: ModuleType2.armor)
    module.name = $adaModule.name
    module.protoIndex = adaModule.protoIndex
    module.weight = adaModule.weight
    module.durability = adaModule.durability
    module.maxDurability = adaModule.maxDurability
    module.upgradeProgress = adaModule.upgradeProgress
    module.upgradeAction = adaModule.upgradeAction.ShipUpgrade
    for owner in adaModule.owner:
      if owner == 0:
        break
      module.owner.add(y = owner - 1)
    if module.owner.len == 0:
      module.owner.add(y = -1)
    if getPlayerShip == 1:
      playerShip.modules.add(y = module)
    else:
      npcShip.modules.add(y = module)

proc getAdaShipCargo(cargo: array[1..128, AdaInventoryData];
    getPlayerShip: cint = 1) {.raises: [], tags: [], exportc.} =
  if getPlayerShip == 1:
    playerShip.cargo = @[]
  else:
    npcShip.cargo = @[]
  for adaItem in cargo:
    if adaItem.protoIndex == 0:
      return
    if getPlayerShip == 1:
      playerShip.cargo.add(y = InventoryData(protoIndex: adaItem.protoIndex,
          amount: adaItem.amount, name: $adaItem.name,
          durability: adaItem.durability, price: adaItem.price))
    else:
      npcShip.cargo.add(y = InventoryData(protoIndex: adaItem.protoIndex,
          amount: adaItem.amount, name: $adaItem.name,
          durability: adaItem.durability, price: adaItem.price))

proc setAdaShipCargo(cargo: var array[1..128, AdaInventoryData];
    getPlayerShip: cint = 1) {.raises: [], tags: [], exportc.} =
  let nimCargo = if getPlayerShip == 1:
      playerShip.cargo
    else:
      npcShip.cargo
  for index in cargo.low..cargo.high:
    if index <= nimCargo.len:
      cargo[index] = AdaInventoryData(protoIndex: nimCargo[index -
          1].protoIndex.cint, amount: nimCargo[index - 1].amount.cint,
          name: nimCargo[index - 1].name.cstring, durability: nimCargo[index -
          1].durability.cint, price: nimCargo[index - 1].price.cint)
    else:
      cargo[index] = AdaInventoryData(protoIndex: 0)

proc getAdaShipCrew(crew: array[1..128, AdaMemberData];
    getPlayerShip: cint = 1) {.raises: [], tags: [], exportc.} =
  if getPlayerShip == 1:
    playerShip.crew = @[]
  else:
    npcShip.crew = @[]
  for adaMember in crew:
    if adaMember.name.len == 0:
      return
    if getPlayerShip == 1:
      playerShip.crew.add(y = adaMemberToNim(adaMember = adaMember))
    else:
      npcShip.crew.add(y = adaMemberToNim(adaMember = adaMember))

proc getAdaCrewInventory(inventory: array[1..128, AdaInventoryData];
    memberIndex: cint; getPlayerShip: cint = 1) {.raises: [], tags: [], exportc.} =
  if getPlayerShip == 1:
    playerShip.crew[memberIndex - 1].inventory = @[]
  else:
    npcShip.crew[memberIndex - 1].inventory = @[]
  for adaItem in inventory:
    if adaItem.protoIndex == 0:
      return
    if getPlayerShip == 1:
      playerShip.crew[memberIndex - 1].inventory.add(y = InventoryData(
          protoIndex: adaItem.protoIndex, amount: adaItem.amount,
          name: $adaItem.name,
          durability: adaItem.durability, price: adaItem.price))
    else:
      npcShip.crew[memberIndex - 1].inventory.add(y = InventoryData(
          protoIndex: adaItem.protoIndex, amount: adaItem.amount,
          name: $adaItem.name,
          durability: adaItem.durability, price: adaItem.price))

proc setAdaCrewInventory(inventory: var array[1..128, AdaInventoryData];
    memberIndex: cint; getPlayerShip: cint = 1) {.raises: [], tags: [], exportc.} =
  let nimInventory = if getPlayerShip == 1:
      playerShip.crew[memberIndex - 1].inventory
    else:
      npcShip.crew[memberIndex - 1].inventory
  for index in inventory.low..inventory.high:
    if index <= nimInventory.len:
      inventory[index] = AdaInventoryData(protoIndex: nimInventory[index -
          1].protoIndex.cint, amount: nimInventory[index - 1].amount.cint,
          name: nimInventory[index - 1].name.cstring, durability: nimInventory[
          index - 1].durability.cint, price: nimInventory[index - 1].price.cint)
    else:
      inventory[index] = AdaInventoryData(protoIndex: 0)

func adaMemberFromNim*(member: MemberData): AdaMemberData {.raises: [], tags: [].} =
  result = AdaMemberData()
  for attribute in result.attributes.mitems:
    attribute = [0.cint, 0.cint]
  for index, attribute in member.attributes.pairs:
    result.attributes[index + 1] = [attribute.level.cint,
        attribute.experience.cint]
  for skill in result.skills.mitems:
    skill = [0.cint, 0.cint, 0.cint]
  for index, skill in member.skills.pairs:
    result.skills[index + 1] = [skill.index.cint, skill.level.cint,
        skill.experience.cint]
  result.name = member.name.cstring
  result.gender = member.gender
  result.health = member.health.cint
  result.tired = member.tired.cint
  result.hunger = member.hunger.cint
  result.thirst = member.thirst.cint
  result.order = member.order.ord.cint
  result.previousOrder = member.previousOrder.ord.cint
  result.orderTime = member.orderTime.cint
  for index, order in member.orders.pairs:
    result.orders[index] = order.ord.cint
  for index, item in member.equipment:
    result.equipment[index.ord.cint] = item.cint
  result.payment = [1: member.payment[1].cint, 2: member.payment[2].cint]
  result.contractLength = member.contractLength.cint
  result.morale = [1: member.morale[1].cint, 2: member.morale[2].cint]
  result.loyalty = member.loyalty.cint
  result.homeBase = member.homeBase
  result.faction = member.faction.cstring

proc setAdaShipCrew(crew: var array[1..128, AdaMemberData];
    getPlayerShip: cint = 1) {.raises: [], tags: [], exportc.} =
  let nimCrew = if getPlayerShip == 1:
      playerShip.crew
    else:
      npcShip.crew
  var index = 1
  for member in nimCrew:
    crew[index] = adaMemberFromNim(member = member)
    index.inc
  crew[index].name = "".cstring

proc setAdaShip(shipData: var AdaShipData; getPlayerShip: cint = 1) {.raises: [
    ], tags: [], exportc.} =
  let nimShip = if getPlayerShip == 1:
      playerShip
    else:
      npcShip
  shipData.name = nimShip.name.cstring
  shipData.skyX = nimShip.skyX.cint
  shipData.skyY = nimShip.skyY.cint
  shipData.speed = nimShip.speed.ord.cint
  shipData.upgradeModule = nimShip.upgradeModule.cint + 1
  shipData.destinationX = nimShip.destinationX.cint
  shipData.destinationY = nimShip.destinationY.cint
  shipData.repairModule = nimShip.repairModule.cint + 1
  shipData.description = nimShip.description.cstring
  shipData.homeBase = nimShip.homeBase.cint

proc setAdaShipModules(modules: var array[1..75, AdaModuleData];
    getPlayerShip: cint = 1) {.raises: [], tags: [], exportc.} =
  for i in modules.low..modules.high:
    modules[i] = AdaModuleData(name: "".cstring)
  let nimModules = if getPlayerShip == 1:
      playerShip.modules
    else:
      npcShip.modules
  var index = 1
  for module in nimModules:
    var
      adaModule = AdaModuleData(name: module.name.cstring,
          protoIndex: module.protoIndex.cint, weight: module.weight.cint,
          durability: module.durability.cint,
          maxDurability: module.maxDurability.cint,
          upgradeProgress: module.upgradeProgress.cint,
          upgradeAction: module.upgradeAction.ord.cint,
          mType: module.mType.ModuleType2.ord.cint)
      secondIndex = 1
    case module.mType
    of ModuleType2.engine:
      adaModule.data = [module.fuelUsage.cint, module.power.cint, (
          if module.disabled: 1 else: 0)]
    of ModuleType2.cabin:
      adaModule.data = [module.cleanliness.cint, module.quality.cint, 0]
    of ModuleType2.turret:
      adaModule.data = [(module.gunIndex + 1).cint, 0.cint, 0.cint]
    of ModuleType2.gun:
      adaModule.data = [module.damage.cint, (module.ammoIndex + 1).cint, 0.cint]
    of ModuleType2.hull:
      adaModule.data = [module.installedModules.cint, module.maxModules.cint, 0.cint]
    of ModuleType2.workshop:
      adaModule.data = [module.craftingTime.cint, module.craftingAmount.cint, 0.cint]
      adaModule.data2 = module.craftingIndex.cstring
    of ModuleType2.trainingRoom:
      adaModule.data = [module.trainedSkill.cint, 0.cint, 0.cint]
    of ModuleType2.batteringRam:
      adaModule.data = [module.damage2.cint, (if module.coolingDown: 1 else: 0), 0.cint]
    of ModuleType2.harpoonGun:
      adaModule.data = [module.duration.cint, (module.harpoonIndex + 1).cint, 0.cint]
    else:
      discard
    for owner in module.owner:
      adaModule.owner[secondIndex] = (owner + 1).cint
      secondIndex.inc
    modules[index] = adaModule
    index.inc

proc loadAdaShips(fileName: cstring): cstring {.sideEffect, raises: [],
    tags: [WriteIOEffect, ReadIOEffect, RootEffect], exportc.} =
  try:
    loadShips(fileName = $fileName)
    return "".cstring
  except DataLoadingError:
    return getCurrentExceptionMsg().cstring

proc getAdaProtoShip(index: cint; adaProtoShip: var AdaProtoShipData) {.sideEffect,
    raises: [], tags: [], exportc.} =
  adaProtoShip = AdaProtoShipData(name: "".cstring, accuracy: [0.cint, 0.cint],
      combatAi: -1, evasion: [0.cint, 0.cint], loot: [0.cint, 0.cint],
      perception: [0.cint, 0.cint], combatValue: -1, description: "".cstring,
      owner: "".cstring)
  if not protoShipsList.hasKey(key = index):
    return
  let ship = try:
      protoShipsList[index]
    except KeyError:
      return
  adaProtoShip.name = ship.name.cstring
  adaProtoShip.accuracy = [ship.accuracy.minValue.cint,
      ship.accuracy.maxValue.cint]
  adaProtoShip.combatAi = ship.combatAi.ord.cint
  adaProtoShip.evasion = [ship.evasion.minValue.cint,
      ship.evasion.maxValue.cint]
  adaProtoShip.loot = [ship.loot.minValue.cint, ship.loot.maxValue.cint]
  adaProtoShip.perception = [ship.perception.minValue.cint,
      ship.perception.maxValue.cint]
  adaProtoShip.combatValue = ship.combatValue.cint
  adaProtoShip.description = ship.description.cstring
  adaProtoShip.owner = ship.owner.cstring

proc getAdaProtoShipData(index, crew: cint; adaData: var array[15,
    array[3, cint]]) {.sideEffect, raises: [], tags: [], exportc.} =
  for data in adaData.mitems:
    data = [0.cint, 0.cint, 0.cint]
  if not protoShipsList.hasKey(key = index):
    return
  let ship = try:
      protoShipsList[index]
    except KeyError:
      return
  if crew == 1:
    for index, mob in ship.crew.pairs:
      adaData[index] = [mob.protoIndex.cint, mob.minAmount.cint,
          mob.maxAmount.cint]
  else:
    for index, cargo in ship.cargo.pairs:
      adaData[index] = [cargo.protoIndex.cint, cargo.minAmount.cint,
          cargo.maxAmount.cint]

proc getAdaProtoShipModules(index: cint; adaModules: var array[64,
    cint]) {.sideEffect, raises: [], tags: [], exportc.} =
  for module in adaModules.mitems:
    module = 0.cint
  if not protoShipsList.hasKey(key = index):
    return
  let ship = try:
      protoShipsList[index]
    except KeyError:
      return
  for mIndex, module in ship.modules.pairs:
    adaModules[mIndex] = module.cint

proc getAdaProtoShipRecipes(index: cint; adaRecipes: var array[15,
    cstring]) {.sideEffect, raises: [], tags: [], exportc.} =
  for recipe in adaRecipes.mitems:
    recipe = "".cstring
  if not protoShipsList.hasKey(key = index):
    return
  let ship = try:
      protoShipsList[index]
    except KeyError:
      return
  for rIndex, recipe in ship.knownRecipes.pairs:
    adaRecipes[rIndex] = recipe.cstring

proc damageAdaModule(inPlayerShip, moduleIndex, damage: cint;
    deathReason: cstring) {.raises: [], tags: [WriteIOEffect], exportc.} =
  try:
    if inPlayerShip == 1:
      damageModule(ship = playerShip, moduleIndex = moduleIndex - 1,
          damage = damage, deathReason = $deathReason)
    else:
      damageModule(ship = npcShip, moduleIndex = moduleIndex - 1,
          damage = damage, deathReason = $deathReason)
  except KeyError, IOError:
    discard

proc countAdaCombatValue(): cint {.raises: [], tags: [], exportc.} =
  try:
    return countCombatValue().cint
  except KeyError:
    return 0
