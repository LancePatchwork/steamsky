discard """
  exitcode: 0
"""

import std/tables
import ../../src/[basestypes, careers, factions, game, items, maps, missions,
    missions2, shipmodules, types]

if itemsList.len == 0:
  loadData("../bin/data/game.dat")
  loadItems("../bin/data/items.dat")
  loadCareers("../bin/data/careers.dat")
  loadFactions("../bin/data/factions.dat")
  loadModules("../bin/data/shipmodules.dat")
if basesTypesList.len == 0:
  loadBasesTypes("../bin/data/bases.dat")

playerShip.skyX = 1
playerShip.skyY = 1
playerShip.crew = @[]
playerShip.crew.add(MemberData(morale: [1: 50.Natural, 2: 0.Natural],
    homeBase: 1, faction: "POLEIS", orders: [0.Natural, 0, 0, 1, 1, 1, 2, 1, 1,
    1, 0, 0], order: pilot, loyalty: 100, health: 100, tired: 0, hunger: 0,
    thirst: 0, skills: @[SkillInfo(index: 4,
    level: 4, experience: 0)], attributes: @[MobAttributeRecord(level: 3,
        experience: 0),
    MobAttributeRecord(level: 3, experience: 0), MobAttributeRecord(level: 3,
    experience: 0), MobAttributeRecord(level: 3, experience: 0)]))
playerShip.crew.add(MemberData(morale: [1: 50.Natural, 2: 0.Natural],
    homeBase: 1, faction: "POLEIS", orders: [0.Natural, 0, 0, 1, 1, 1, 2, 1, 1,
    1, 0, 0], order: engineer, loyalty: 100, health: 100, tired: 0, hunger: 0,
    thirst: 0, skills: @[SkillInfo(index: 4,
    level: 4, experience: 0)], attributes: @[MobAttributeRecord(level: 3,
        experience: 0),
    MobAttributeRecord(level: 3, experience: 0), MobAttributeRecord(level: 3,
    experience: 0), MobAttributeRecord(level: 3, experience: 0)]))
playerShip.modules = @[]
playerShip.modules.add(ModuleData(mType: cargoRoom, protoIndex: 7,
    durability: 100))
playerShip.modules.add(ModuleData(mType: ModuleType2.engine, protoIndex: 3,
    durability: 100, fuelUsage: 4, power: 2000, disabled: false,
    maxDurability: 100))
playerShip.modules.add(ModuleData(mType: ModuleType2.cockpit, protoIndex: 5,
    durability: 100, maxDurability: 100))
playerShip.modules.add(ModuleData(mType: ModuleType2.cabin, protoIndex: 4,
    durability: 100, owner: @[0]))
playerShip.modules.add(ModuleData(mType: ModuleType2.cabin, protoIndex: 4,
    durability: 100, owner: @[1]))
playerShip.cargo = @[]
playerShip.cargo.add(InventoryData(protoIndex: 1, amount: 100, durability: 100))
playerShip.speed = docked
skyMap[1][1].baseIndex = 1
skyMap[1][1].eventIndex = -1
skyBases[1] = BaseRecord(skyX: 1, skyY: 1, population: 100, baseType: "1",
    owner: "POLEIS")
skyMap[2][2].missionIndex = 0
gameDate = DateRecord(year: 1600, month: 1, day: 1, hour: 8, minutes: 0)
skyBases[1].missionsDate = gameDate

acceptedMissions = @[]
acceptedMissions.add(y = MissionData(mType: explore, time: 1000, targetX: 2,
    targetY: 2, reward: 1, startBase: 1, finished: true, multiplier: 1.0, target: 0))
finishMission(0)
assert acceptedMissions.len == 0, "Failed to finish an accepted mission."
playerShip.crew.add(MemberData(morale: [1: 50.Natural, 2: 0.Natural],
    homeBase: 1, faction: "DRONES", orders: [0.Natural, 0, 0, 1, 1, 1, 2, 1, 1,
    1, 0, 0], loyalty: 100, health: 100, tired: 0, hunger: 0,
    thirst: 0, skills: @[], attributes: @[], contractLength: 1000))
acceptedMissions.add(y = MissionData(mType: passenger, time: 1000, targetX: 1,
    targetY: 1, reward: 1, startBase: 1, finished: false, multiplier: 1.0, data: 2))
finishMission(0)
assert acceptedMissions.len == 0, "Failed to finish an accepted passenger mission."

acceptedMissions = @[]
acceptedMissions.add(y = MissionData(mType: explore, time: 1000, targetX: 2,
    targetY: 2, reward: 1, startBase: 1, finished: true, multiplier: 1.0, target: 0))
assert autoFinishMissions().len == 0 and acceptedMissions.len == 0, "Failed to auto finish accepted missions."
