discard """
  exitcode: 0
  output: '''Loading the game data.
Testing repairShip.'''
"""

import std/tables
import ../../src/[basesship2, basestypes, careers, crafts, factions, game,
    items, maps, mobs, ships, shipmodules, types, utils]

echo "Loading the game data."
if basesTypesList.len == 0:
  loadData("../bin/data/game.dat")
  loadItems("../bin/data/items.dat")
  loadCareers("../bin/data/careers.dat")
  loadFactions("../bin/data/factions.dat")
  loadBasesTypes("../bin/data/bases.dat")
if modulesList.len == 0:
  loadModules("../bin/data/shipmodules.dat")
if recipesList.len == 0:
  loadRecipes("../bin/data/recipes.dat")
if protoMobsList.len == 0:
  loadMobs("../bin/data/mobs.dat")
if protoShipsList.len == 0:
  loadShips("../bin/data/ships.dat")

skyBases[1].reputation = ReputationData(level: 1, experience: 1)
playerShip.skyX = 1
playerShip.skyY = 1
playerShip.crew = @[]
playerShip.crew.add(MemberData(morale: [1: 50.Natural, 2: 0.Natural],
    homeBase: 1, faction: "POLEIS", orders: [0.Natural, 0, 0, 1, 1, 1, 2, 1, 1,
    1, 0, 0], order: talk, loyalty: 100, skills: @[SkillInfo(index: 4, level: 4,
    experience: 0)], attributes: @[MobAttributeRecord(level: 3, experience: 0),
    MobAttributeRecord(level: 3, experience: 0), MobAttributeRecord(level: 3,
    experience: 0), MobAttributeRecord(level: 3, experience: 0)], health: 100))
playerShip.crew.add(MemberData(morale: [1: 50.Natural, 2: 0.Natural],
    homeBase: 1, faction: "POLEIS", orders: [0.Natural, 0, 0, 1, 1, 1, 0, 1, 1,
    1, 0, 0], order: gunner, loyalty: 100))
playerShip.modules = @[]
playerShip.modules.add(ModuleData(mType: ModuleType2.hull, protoIndex: 1,
    durability: 100, maxDurability: 100, maxModules: 10))
playerShip.modules.add(ModuleData(mType: cargoRoom, protoIndex: 7,
    durability: 100))
playerShip.modules.add(ModuleData(mType: ModuleType2.armor, protoIndex: 57,
    durability: 100))
playerShip.modules.add(ModuleData(mType: ModuleType2.turret, protoIndex: 86,
    durability: 100))
playerShip.modules.add(ModuleData(mType: ModuleType2.gun, protoIndex: 160,
    durability: 100, damage: 100, owner: @[-1]))
playerShip.cargo = @[]
playerShip.cargo.add(InventoryData(protoIndex: 1, amount: 2000,
    durability: 100))
playerShip.speed = docked
for x in 1 .. 1024:
  for y in 1 .. 1024:
    skyMap[x][y].eventIndex = -1
    skyMap[x][y].baseIndex = 0
skyMap[playerShip.skyX][playerShip.skyY].baseIndex = 1
skyMap[playerShip.skyX][playerShip.skyY].eventIndex = -1
for index, base in skyBases.mpairs:
  if index == 1:
    continue
  base.skyX = getRandom(1, 1_024)
  base.skyY = getRandom(1, 1_024)
  base.baseType = $getRandom(0, 4)
  base.owner = "POLEIS"
  base.population = getRandom(100, 400)
  skyMap[base.skyX][base.skyY].baseIndex = index
skyBases[1].population = 100
skyBases[1].baseType = "1"
skyBases[1].owner = "POLEIS"
gameDate = DateRecord(year: 1600, month: 1, day: 1, hour: 8, minutes: 0)

echo "Testing repairShip."
playerShip.modules[0].durability -= 5
repairShip(0)
try:
  assert playerShip.modules[0].durability == playerShip.modules[0].maxDurability
except AssertionDefect:
  writeLine(stderr, "Failed to repair the player's ship in the base.")
playerShip.modules[0].durability -= 5
repairShip(-1)
try:
  assert playerShip.modules[0].durability == playerShip.modules[0].maxDurability
except AssertionDefect:
  writeLine(stderr, "Failed to repair the whole player's ship in the base.")
