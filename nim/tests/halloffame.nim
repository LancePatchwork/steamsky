import ../src/[game, halloffame, statistics]
import unittest2

suite "Unit tests for halloffame module":
  for entry in hallOfFameArray.mitems:
    entry = HallOfFameData(name: "", points: 0, deathReason: "")
  gameStats.points = 100
  saveDirectory = "."

  test "Testing updateHallOfFame.":
    updateHallOfFame("TestPlayer", "TestDeath")
    check:
      hallOfFameArray[1].name == "TestPlayer"
