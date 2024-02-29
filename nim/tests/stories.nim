import ../src/[careers, factions, items]
import unittest2
include ../src/stories

suite "Unit tests for stories module":

  checkpoint "Loading the game data."
  loadData("../bin/data/game.dat")
  loadItems("../bin/data/items.dat")
  loadCareers("../bin/data/careers.dat")
  loadFactions("../bin/data/factions.dat")
  loadStories("../bin/data/stories.dat")

  test "Testing getStepData.":
    checkpoint "Get finish data of the selected step."
    check:
      getStepData(storiesList["1"].steps[0].finishData, "condition") == "Rhetoric"
    checkpoint "Get finish data of the non-existing step."
    check:
      getStepData(storiesList["1"].steps[0].finishData, "sdfdsf").len == 0

  test "Testing startStory.":
    playerShip.crew = @[]
    playerShip.crew.add(MemberData(morale: [1: 50.Natural, 2: 0.Natural],
        homeBase: 1, faction: "POLEIS", orders: [0.Natural, 0, 0, 1, 1, 1, 2, 1,
        1, 1, 0, 0], order: talk, loyalty: 100, skills: @[SkillInfo(index: 4,
        level: 4, experience: 0)], attributes: @[MobAttributeRecord(level: 3,
        experience: 0), MobAttributeRecord(level: 3, experience: 0),
        MobAttributeRecord(level: 3, experience: 0), MobAttributeRecord(
        level: 3, experience: 0)]))
    for i in 1 .. 1_000_000:
      startStory("Undead", dropItem)
      if currentStory.index.len > 0:
        break
    check:
      currentStory.index.len > 0

  test "Testing getCurrentStoryText.":
    currentStory.finishedStep = askInBase
    check:
      getCurrentStoryText().len > 0

  test "Testing clearCurrentStory.":
    let oldStory = currentStory
    clearCurrentStory()
    check:
      currentStory.index.len == 0
    currentStory = oldStory

  test "Testing getStoryLocation.":
    let (x, y) = getStoryLocation()
    check:
      x > 0 and y > 0
