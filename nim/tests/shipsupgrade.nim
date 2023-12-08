import ../src/[game, careers, factions, items, shipmodules, shipsupgrade, types]
import unittest2

suite "Unit tests for shipsupgrade module":

  checkpoint "Loading the game data."
  loadData("../bin/data/game.dat")
  loadItems("../bin/data/items.dat")
  loadCareers("../bin/data/careers.dat")
  loadFactions("../bin/data/factions.dat")
  loadModules("../bin/data/shipmodules.dat")

  playerShip.modules = @[]
  playerShip.modules.add(ModuleData(mType: ModuleType2.engine, protoIndex: 3,
      durability: 100, fuelUsage: 4, power: 2000, disabled: false,
      maxDurability: 100, upgradeProgress: 20, upgradeAction: durability))
  playerShip.upgradeModule = 0
  playerShip.cargo = @[]
  playerShip.cargo.add(InventoryData(protoIndex: 61, amount: 5, durability: 100))
  playerShip.cargo.add(InventoryData(protoIndex: 5, amount: 100, durability: 100))
  playerShip.crew = @[]
  playerShip.crew.add(MemberData(morale: [1: 50.Natural, 2: 0.Natural],
      homeBase: 1, faction: "POLEIS", orders: [0.Natural, 0, 0, 1, 1, 1, 2, 1, 1,
      1, 0, 0], order: upgrading, loyalty: 100, skills: @[SkillInfo(index: 4,
      level: 4,
      experience: 0)], attributes: @[MobAttributeRecord(level: 3, experience: 0),
      MobAttributeRecord(level: 3, experience: 0), MobAttributeRecord(level: 3,
      experience: 0), MobAttributeRecord(level: 3, experience: 0)]))
  playerShip.crew[0].equipment[tool] = -1


  test "Testing upgradeShip.":
    upgradeShip(15)
    check:
      playerShip.modules[0].upgradeProgress < 20
    playerShip.upgradeModule = -1
    upgradeShip(15)

  test "Testing startUpgrading.":
    startUpgrading(0, 1)
    check:
      playerShip.upgradeModule == 0
