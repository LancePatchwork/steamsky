discard """
  exitcode: 0
  output: '''Loading the game data.
Testing generateBaseName.
Testing askForEvents.
Testing askForBases.'''
"""

import std/tables
import ../../src/[bases, bases2, basestypes, careers, crafts, factions, game,
    items, maps, mobs, shipmodules, ships, types, utils]

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

echo "Testing generateBaseName."
try:
  assert generateBaseName("POLEIS").len() > 0
except AssertionDefect:
  echo "Failed to generate a base's name."

playerShip.skyX = 200
playerShip.skyY = 200
playerShip.crew = @[]
playerShip.crew.add(MemberData(morale: [1: 50.Natural, 2: 0.Natural],
    homeBase: 1, faction: "POLEIS", orders: [0.Natural, 0, 0, 1, 1, 1, 2, 1, 1,
    1, 0, 0], order: talk, loyalty: 100, skills: @[SkillInfo(index: 4, level: 4,
    experience: 0)], attributes: @[MobAttributeRecord(level: 3, experience: 0),
    MobAttributeRecord(level: 3, experience: 0), MobAttributeRecord(level: 3,
    experience: 0), MobAttributeRecord(level: 3, experience: 0)], health: 100))
playerShip.modules = @[]
playerShip.modules.add(ModuleData(mType: ModuleType2.armor, protoIndex: 57,
    durability: 100))
playerShip.modules.add(ModuleData(mType: ModuleType2.turret, protoIndex: 86,
    durability: 100))
playerShip.modules.add(ModuleData(mType: ModuleType2.gun, protoIndex: 160,
    durability: 100, damage: 100, owner: @[-1]))
skyBases[1].population = 100
skyBases[1].baseType = "1"
skyBases[1].owner = "POLEIS"
skyBases[1].askedForEvents = DateRecord(year: 0, month: 0, day: 0, hour: 0, minutes: 0)
gameDate = DateRecord(year: 1600, month: 1, day: 1, hour: 8, minutes: 0)
skyBases[1].visited = gameDate
skyBases[1].known = true
skyBases[1].askedForBases = false
skyBases[1].skyX = 200
skyBases[1].skyY = 200
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

echo "Testing askForEvents."
askForEvents()
try:
  assert eventsList.len > 0
except AssertionDefect:
  echo "Failed to generate new events."

echo "Testing askForBases."
askForBases()
try:
  assert skyBases[1].askedForBases
except AssertionDefect:
  echo "Failed to ask for bases in a base."
