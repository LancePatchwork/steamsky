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
import crew, factions, game, items, log, types, utils

proc loadMobs*(fileName: string) {.sideEffect, raises: [DataLoadingError],
    tags: [WriteIOEffect, ReadIOEffect, RootEffect].} =
  ## Load the Mobs data from the file
  ##
  ## * fileName - the name of the file to load
  const
    orderNames = ["Piloting", "Engineering", "Operating guns",
      "Repair ship", "Manufacturing", "Upgrading ship", "Talking in bases",
      "Healing wounded", "Cleaning ship", "Defend ship", "Board enemy ship"]
    equipmentNames = ["Weapon", "Shield", "Head", "Torso", "Arms", "Legs", "Tool"]
  let mobsXml = try:
      loadXml(path = fileName)
    except XmlError, ValueError, IOError, OSError, Exception:
      raise newException(exceptn = DataLoadingError,
          message = "Can't load mobs data file. Reason: " &
          getCurrentExceptionMsg())
  for mobNode in mobsXml:
    if mobNode.kind != xnElement:
      continue
    let
      mobIndex: Natural = try:
          mobNode.attr(name = "index").parseInt()
        except ValueError:
          raise newException(exceptn = DataLoadingError,
              message = "Can't add mob '" & mobNode.attr(name = "index") & "', invalid index.")
      mobAction: DataAction = try:
          parseEnum[DataAction](mobNode.attr(name = "action").toLowerAscii)
        except ValueError:
          DataAction.add
    if mobAction in [update, remove]:
      if mobIndex > protoMobsList.len():
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $mobAction & " mob '" & $mobIndex & "', there is no mob with that index.")
    elif mobIndex < protoMobsList.len():
      raise newException(exceptn = DataLoadingError,
          message = "Can't add mob '" & $mobIndex & "', there is an mob with that index.")
    if mobAction == DataAction.remove:
      {.warning[ProveInit]: off.}
      {.warning[UnsafeDefault]: off.}
      protoMobsList.del(key = mobIndex)
      {.warning[ProveInit]: on.}
      {.warning[UnsafeDefault]: on.}
      logMessage(message = "Mob removed: '" & $mobIndex & "'",
          debugType = everything)
      continue
    var mob: ProtoMobRecord = if mobAction == DataAction.update:
        try:
          protoMobsList[mobIndex]
        except ValueError:
          ProtoMobRecord()
      else:
        ProtoMobRecord()
    for skill in mobNode.findAll(tag = "skill"):
      let skillName = skill.attr(name = "name")
      var skillIndex = if skillName == "WeaponSkill":
          skillsList.len + 1
        else:
          findSkillIndex(skillName = skillName)
      if skillIndex == 0:
        raise newException(exceptn = DataLoadingError, message = "Can't " &
            $mobAction & " mob '" & $mobIndex & "', there no skill named '" &
            skillName & "'.")
      let skillAction: DataAction = try:
          parseEnum[DataAction](skill.attr(name = "action").toLowerAscii)
        except ValueError:
          DataAction.add
      var skillLevel, minLevel, maxLevel = 0
      if skillAction in [DataAction.add, DataAction.update]:
        skillLevel = try:
          skill.attr(name = "level").parseInt()
        except ValueError:
          0
        if skillLevel == 0:
          minLevel = try:
            skill.attr(name = "minlevel").parseInt()
          except ValueError:
            0
          maxLevel = try:
            skill.attr(name = "maxlevel").parseInt()
          except ValueError:
            0
          if minLevel >= maxLevel:
            raise newException(exceptn = DataLoadingError, message = "Can't " &
                $mobAction & " mob '" & $mobIndex &
                "', invalid range for skill '" & skillName & "'.")
      case skillAction
      of DataAction.add:
        if skillLevel > 0:
          mob.skills.add(y = SkillInfo(index: skillIndex, level: skillLevel,
              experience: 0))
        else:
          mob.skills.add(y = SkillInfo(index: skillIndex, level: minLevel,
              experience: maxLevel))
      of DataAction.update:
        for mskill in mob.skills.mitems:
          if mskill.index == skillIndex:
            if skillLevel > 0:
              mskill.level = skillLevel
            else:
              mskill.level = minLevel
              mskill.experience = maxLevel
            break
      of DataAction.remove:
        mob.skills.delete(i = skillIndex)
    let attributes = mobNode.findAll(tag = "attribute")
    for i in attributes.low..attributes.high:
      let attrLevel = try:
          attributes[i].attr(name = "level").parseInt()
        except ValueError:
          0
      if attrLevel > 0:
        if mobAction == DataAction.add:
          mob.attributes.add(y = MobAttributeRecord(level: attrLevel,
              experience: 0))
        else:
          mob.attributes[i] = MobAttributeRecord(level: attrLevel, experience: 0)
      else:
        let minLevel = try:
          attributes[i].attr(name = "minlevel").parseInt()
        except ValueError:
          0
        let maxLevel = try:
          attributes[i].attr(name = "maxlevel").parseInt()
        except ValueError:
          0
        if minLevel >= maxLevel:
          raise newException(exceptn = DataLoadingError, message = "Can't " &
              $mobAction & " mob '" & $mobIndex & "', invalid range for attribute.")
        if mobAction == DataAction.add:
          mob.attributes.add(y = MobAttributeRecord(level: minLevel,
              experience: maxLevel))
        else:
          mob.attributes[i] = MobAttributeRecord(level: minLevel,
              experience: maxLevel)
    for priority in mobNode.findAll(tag = "priority"):
      for index, order in orderNames.pairs:
        if order == priority.attr(name = "name"):
          mob.priorities[index + 1] = if priority.attr(name = "value") == "Normal":
              1
            else:
              2
          break
    var mobOrder = mobNode.attr(name = "order")
    if mobOrder.len > 0:
      mob.order = try:
          parseEnum[CrewOrders](mobOrder.toLowerAscii)
        except ValueError:
          raise newException(exceptn = DataLoadingError,
              message = "Can't " & $mobAction & " mob '" &
                  $mobIndex & "', invalid order for the mob.")
    for item in mobNode.findAll(tag = "item"):
      let itemIndex = try:
            item.attr(name = "index").parseInt()
          except ValueError:
            raise newException(exceptn = DataLoadingError,
                message = "Can't " & $mobAction & " mob '" &
                    $mobIndex & "', invalid index of item.")
      if itemIndex > itemsList.len:
        raise newException(exceptn = DataLoadingError,
            message = "Can't " & $mobAction & " mob '" &
                $mobIndex & "', there is no item with index '" & $itemIndex & "'.")
      let itemAction: DataAction = try:
          parseEnum[DataAction](item.attr(name = "action").toLowerAscii)
        except ValueError:
          DataAction.add
      var amount, minAmount, maxAmount = 0
      if itemAction in [DataAction.add, DataAction.update]:
        amount = try:
            item.attr(name = "amount").parseInt()
          except ValueError:
            0
        if amount == 0:
          minAmount = try:
            item.attr(name = "minamount").parseInt()
          except ValueError:
            0
          maxAmount = try:
            item.attr(name = "maxamount").parseInt()
          except ValueError:
            0
          if minAmount >= maxAmount:
            raise newException(exceptn = DataLoadingError, message = "Can't " &
                $mobAction & " mob '" & $mobIndex &
                "', invalid range for item amount '" & $itemIndex & "'.")
      case itemAction
      of DataAction.add:
        if amount > 0:
          mob.inventory.add(y = MobInventoryRecord(protoIndex: itemIndex,
              minAmount: amount, maxAmount: 0))
        else:
          mob.inventory.add(y = MobInventoryRecord(protoIndex: itemIndex,
              minAmount: minAmount, maxAmount: maxAmount))
      of DataAction.update:
        for mitem in mob.inventory.mitems:
          if mitem.protoIndex == itemIndex:
            if amount > 0:
              mitem = MobInventoryRecord(protoIndex: itemIndex,
                  minAmount: amount, maxAmount: 0)
            else:
              mitem = MobInventoryRecord(protoIndex: itemIndex,
                  minAmount: minAmount, maxAmount: maxAmount)
            break
      of DataAction.remove:
        var deleteIndex = -1
        for index, mitem in mob.inventory.pairs:
          if mitem.protoIndex == itemIndex:
            deleteIndex = index
            break
        if deleteIndex > -1:
          mob.inventory.delete(i = deleteIndex)
    for item in mob.equipment.mitems:
      item = -1
    for item in mobNode.findAll(tag = "equipment"):
      let slotName = item.attr(name = "slot")
      for index, name in equipmentNames.pairs:
        if name == slotName:
          mob.equipment[index.EquipmentLocations] = try:
              item.attr(name = "index").parseInt() - 1
            except ValueError:
              raise newException(exceptn = DataLoadingError,
                  message = "Can't " & $mobAction & " mob '" & $mobIndex &
                  "', invalid equipment index '" & item.attr(name = "index") & "'.")
          break
    if mobAction == DataAction.add:
      logMessage(message = "Mob added: '" & $mobIndex & "'",
          debugType = everything)
    else:
      logMessage(message = "Mob updated: '" & $mobIndex & "'",
          debugType = everything)
    protoMobsList[mobIndex] = mob

proc generateMob*(mobIndex: Natural, factionIndex: string): MemberData {.sideEffect,
    raises: [KeyError], tags: [].} =
  ## Generate random mob from the selected prototype and the faction.
  ##
  ## * mobIndex     - the index of the prototype of the mob from which the new
  ##                  will be generated
  ## * factionIndex - the index of the faction to which the mob will be belong
  ##
  ## Returns the newly created mob from the selected prototype and faction.
  result = MemberData(homeBase: 1)
  result.faction = (if getRandom(min = 1, max = 100) <
      99: factionIndex else: getRandomFaction())
  result.gender = 'M'
  let faction = factionsList[result.faction]
  if "nogender" notin faction.flags and getRandom(min = 1,
      max = 100) > 50:
    result.gender = 'F'
  result.name = generateMemberName(gender = result.gender,
      factionIndex = result.faction)
  var weaponSkillLevel, highestSkillLevel = 1
  let protoMob = protoMobsList[mobIndex]
  for skill in protoMob.skills:
    let skillIndex = (if skill.index > skillsList.len: faction.weaponSkill else: skill.index)
    if skill.experience == 0:
      result.skills.add(y = SkillInfo(index: skillIndex, level: skill.level,
          experience: 0))
    else:
      result.skills.add(y = SkillInfo(index: skillIndex, level: getRandom(
          min = skill.level, max = skill.experience), experience: 0))
    if skillIndex == faction.weaponSkill:
      weaponSkillLevel = result.skills[^1].level
    if result.skills[^1].level > highestSkillLevel:
      highestSkillLevel = result.skills[^1].level
  for attribute in protoMob.attributes:
    if attribute.experience == 0:
      result.attributes.add(y = attribute)
    else:
      result.attributes.add(y = MobAttributeRecord(level: getRandom(
          min = attribute.level, max = attribute.experience), experience: 0))
  for item in protoMob.inventory:
    let amount = if item.maxAmount > 0:
        getRandom(min = item.minAmount, max = item.maxAmount)
      else:
        item.minAmount
    result.inventory.add(y = InventoryData(protoIndex: item.protoIndex,
        amount: amount, name: "", durability: defaultItemDurability, price: 0))
  result.equipment = protoMob.equipment
  for i in weapon .. legs:
    if result.equipment[i] == -1:
      var equipmentItemIndex = 0
      if getRandom(min = 1, max = 100) < 95:
        let equipmentItemsList = case i
          of weapon:
            weaponsList
          of shield:
            shieldsList
          of helmet:
            headArmorsList
          of torso:
            chestArmorsList
          of arms:
            armsArmorsList
          else:
            legsArmorsList
        equipmentItemIndex = getRandomItem(itemsIndexes = equipmentItemsList,
            equipIndex = i, highestLevel = highestSkillLevel,
            weaponSkillLevel = weaponSkillLevel, factionIndex = result.faction)
      if equipmentItemIndex > 0:
        result.inventory.add(y = InventoryData(protoIndex: equipmentItemIndex,
            amount: 1, name: "", durability: defaultItemDurability, price: 0))
        result.equipment[i] = result.inventory.high
  result.orders = protoMob.priorities
  result.order = protoMob.order
  result.orderTime = 15
  result.previousOrder = rest
  result.health = 100
  result.tired = 0
  result.hunger = 0
  result.thirst = 0
  result.payment = [1: 20.Natural, 2: 0.Natural]
  result.contractLength = -1
  result.morale = [1: (if "fanaticism" in
      faction.flags: 100.Natural else: 50.Natural), 2: 0.Natural]
  result.loyalty = 100
  result.homeBase = 1

# Temporary code for interfacing with Ada

type
  AdaMobData = object
    attributes: array[6, array[2, cint]]
    skills: array[6, array[3, cint]]
    order: cint
    priorities: array[1..12, cint]
    inventory: array[20, array[3, cint]]
    equipment: array[7, cint]

proc loadAdaMobs(fileName: cstring): cstring {.sideEffect, raises: [], tags: [
    WriteIOEffect, ReadIOEffect, RootEffect], exportc.} =
  try:
    loadMobs(fileName = $fileName)
    return "".cstring
  except DataLoadingError:
    return getCurrentExceptionMsg().cstring

proc getAdaMob(index: cint; adaMob: var AdaMobData) {.sideEffect, raises: [
    ], tags: [], exportc.} =
  adaMob = AdaMobData()
  if not protoMobsList.hasKey(key = index):
    return
  let mob = try:
      protoMobsList[index]
    except KeyError:
      return
  for attribute in adaMob.attributes.mitems:
    attribute = [0.cint, 0.cint]
  for index, attribute in mob.attributes.pairs:
    adaMob.attributes[index] = [attribute.level.cint, attribute.experience.cint]
  for skill in adaMob.skills.mitems:
    skill = [0.cint, 0.cint, 0.cint]
  for index, skill in mob.skills.pairs:
    adaMob.skills[index] = [skill.index.cint, skill.level.cint,
        skill.experience.cint]
  adaMob.order = mob.order.ord.cint
  for index, priority in mob.priorities.pairs:
    adaMob.priorities[index] = priority.cint
  for item in adaMob.inventory.mitems:
    item = [0.cint, 0.cint, 0.cint]
  for index, item in mob.inventory.pairs:
    adaMob.inventory[index] = [item.protoIndex.cint, item.minAmount.cint,
        item.maxAmount.cint]
  for index, item in mob.equipment.pairs:
    adaMob.equipment[index.ord] = item.cint + 1

proc adaGenerateMob(mobIndex: cint, factionIndex: cstring;
    adaMember: var AdaMemberData, adaInventory: var array[128,
    AdaInventoryData]) {.raises: [], tags: [], exportc.} =
  try:
    let member = generateMob(mobIndex = mobIndex, factionIndex = $factionIndex)
    adaMember = adaMemberFromNim(member = member)
    adaInventory = inventoryToAda(inventory = member.inventory)
  except KeyError:
    discard

proc adaGetProtoMobsAmount(): cint {.raises: [], tags: [], exportc.} =
  return protoMobsList.len.cint
