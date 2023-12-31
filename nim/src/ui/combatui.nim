# Copyright 2023 Bartek thindil Jasicki
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

import std/[os, math, strutils, tables]
import ../[combat, config, crewinventory, game, items, maps, messages,
    shipscrew, shipmodules, shipsmovement, tk, types]
import coreui, dialogs, mapsui, utilsui2

proc updateCombatMessages() {.sideEffect, raises: [], tags: [].} =
  ## Update the list of in-game messages in combat, delete old ones and show
  ## the newest to the player
  let messagesView = mainPaned & ".controls.messages.view"
  tclEval(script = messagesView & " configure -state normal")
  tclEval(script = messagesView & " delete 1.0 end")
  var loopStart = 0 - messagesAmount()
  if loopStart == 0:
    tclEval(script = messagesView & " configure -state disable")
    return
  if loopStart < -10:
    loopStart = -10
  var currentTurnTime = "[" & formattedTime() & "]"

  proc showMessage(message: MessageData) =
    let tagNames: array[1 .. 5, string] = ["yellow", "green", "red", "blue", "cyan"]
    if message.message.startsWith(currentTurnTime):
      if message.color == white:
        tclEval(script = messagesView & " insert end {" & message.message & "}")
      else:
        tclEval(script = messagesView & " insert end {" & message.message &
            "} [list " & tagNames[message.color.ord] & "]")
    else:
      tclEval(script = messagesView & " insert end {" & message.message & "} [list gray]")

  if gameSettings.messagesOrder == olderFirst:
    for i in loopStart .. -1:
      if getLastMessageIndex() + i + 1 >= messagesStarts:
        showMessage(getMessage(messageIndex = i + 1))
        if i < -1:
          tclEval(script = messagesView & " insert end {\n}")
    tclEval(script = messagesView & " see end")
  else:
    for i in countdown(-1, loopStart):
      if getLastMessageIndex() + i + 1 < messagesStarts:
        break
      showMessage(getMessage(messageIndex = i + 1))
      if i > loopStart:
        tclEval(script = messagesView & " insert end {\n}")
  tclEval(script = messagesView & " configure -state disable")

proc updateCombatUi() {.sideEffect, raises: [], tags: [].} =
  ## Update the combat UI, remove the old elements and add new, depending
  ## on the information to show
  var frame = mainPaned & ".combatframe.crew.canvas.frame"
  tclEval(script = "bind . <" & generalAccelerators[0] & "> {InvokeButton " &
      frame & ".maxmin}")
  tclEval(script = "bind . <" & generalAccelerators[2] & "> {InvokeButton " &
      mainPaned & ".combatframe.damage.canvas.frame.maxmin}")
  tclEval(script = "bind . <" & generalAccelerators[1] & "> {InvokeButton " &
      mainPaned & ".combatframe.enemy.canvas.frame.maxmin}")
  tclEval(script = "bind . <" & generalAccelerators[3] & "> {InvokeButton " &
      mainPaned & ".combatframe.status.canvas.frame.maxmin}")
  var comboBox = frame & ".pilotcrew"

  proc getCrewList(position: Natural): string =
    result = "Nobody"
    for index, member in playerShip.crew:
      if member.skills.len > 0:
        result = result & " {" & member.name & getSkillMarks(skillIndex = (
            if position == 0: pilotingSkill elif position ==
            1: engineeringSkill else: gunnerySkill), memberIndex = index) & "}"

  tclEval(script = comboBox & " configure -values [list " & getCrewList(
      position = 0) & "]")
  tclEval(script = comboBox & " current " & $(findMember(order = pilot) + 1))
  comboBox = frame & ".pilotorder"
  tclEval(script = comboBox & " current " & $(pilotOrder - 1))
  let faction = try:
      factionsList[playerShip.crew[0].faction]
    except:
      tclEval(script = "bgerror {Can't update combat UI, no faction: " &
          playerShip.crew[0].faction & "}")
      return
  if "sentientships" notin faction.flags and findMember(order = pilot) == -1:
    tclEval(script = "grid remove " & comboBox)
  else:
    tclEval(script = "grid " & comboBox)
  comboBox = frame & ".engineercrew"
  tclEval(script = comboBox & " configure -values [list " & getCrewList(
      position = 1) & "]")
  tclEval(script = comboBox & " current " & $(findMember(order = engineer) + 1))
  comboBox = frame & ".engineerorder"
  tclEval(script = comboBox & " current " & $(engineerOrder - 1))
  if "sentientships" notin faction.flags and findMember(order = engineer) == -1:
    tclEval(script = "grid remove " & comboBox)
  else:
    tclEval(script = "grid " & comboBox)
  var
    tclResult = tclEval2(script = "grid size " & frame).split(" ")
    rows: Positive = try:
        tclResult[1].parseInt()
      except:
        1
  deleteWidgets(startIndex = 4, endIndex = rows - 1, frame = frame)
  var
    haveAmmo, hasGunner = false
    ammoAmount = 0
  let gunnersOrders: array[1..6, string] = ["{Don't shoot", "{Precise fire ",
      "{Fire at will ", "{Aim for their engine ", "{Aim for their weapon ", "{Aim for their hull "]

  proc getGunSpeed(position: Natural; index: Positive): string =
    result = ""
    var gunSpeed = modulesList[playerShip.modules[guns[position][
        1]].protoIndex].speed
    case index
    of 1:
      gunSpeed = 0
    of 3:
      discard
    else:
      gunSpeed = (if gunSpeed > 0: (gunSpeed.float /
          2.0).ceil.int else: gunSpeed - 1)
    if gunSpeed > 0:
      return "(" & $gunSpeed & "/round)"
    elif gunSpeed < 0:
      return "(1/" & $gunSpeed & " rounds)"

  # Show the guns settings
  for gunIndex, gun in guns:
    haveAmmo = false
    hasGunner = false
    let aIndex = (if playerShip.modules[gun[1]].mType ==
        ModuleType2.gun: playerShip.modules[gun[
        1]].ammoIndex else: playerShip.modules[gun[1]].harpoonIndex)
    try:
      if aIndex in playerShip.cargo.low .. playerShip.cargo.high and itemsList[
          playerShip.cargo[aIndex].protoIndex].itemType == itemsTypesList[modulesList[
          playerShip.modules[gun[1]].protoIndex].value]:
        ammoAmount = playerShip.cargo[aIndex].amount
        haveAmmo = true
    except:
      tclEval(script = "bgerror {Can't show the player's ship's gun settings. No proto item with index: " &
          $playerShip.cargo[aIndex].protoIndex & "}")
      return
    if not haveAmmo:
      ammoAmount = 0
      for itemIndex, item in itemsList:
        try:
          if item.itemType == itemsTypesList[modulesList[playerShip.modules[gun[
              1]].protoIndex].value]:
            let ammoIndex = findItem(inventory = playerShip.cargo,
                protoIndex = itemIndex)
            if ammoIndex > -1:
              ammoAmount = ammoAmount + playerShip.cargo[ammoIndex].amount
        except:
          tclEval(script = "bgerror {Can't show the gun's ammo information. No proto module with index: " &
              $playerShip.modules[gun[1]].protoIndex & "}")
          return
    let label = frame & ".gunlabel" & $gunIndex
    tclEval(script = "ttk::label " & label & " -text {" & playerShip.modules[
        gun[1]].name & ": \n(Ammo: " & $ammoAmount & ")}")
    tclEval(script = "grid " & label & " -row " & $(gunIndex + 4) & " -padx {5 0}")
    tclEval(script = "SetScrollbarBindings " & label & " $combatframe.crew.scrolly")
    var comboBox = frame & ".guncrew" & $(gunIndex + 1)
    tclEval(script = "ttk::combobox " & comboBox & " -values [list " &
        getCrewList(position = 2) & "] -width 10 -state readonly")
    if playerShip.modules[gun[1]].owner[0] == 0:
      tclEval(script = comboBox & " current 0")
    else:
      if playerShip.crew[playerShip.modules[gun[1]].owner[0]].order == gunner:
        tclEval(script = comboBox & " current " & $(playerShip.modules[gun[
            1]].owner[0] + 1))
        hasGunner = true
      else:
        tclEval(script = comboBox & " current 0")
    tclEval(script = "grid " & comboBox & " -row " & $(gunIndex + 4) & " -column 1")
    tclEval(script = "bind " & comboBox & " <Return> {InvokeButton " &
        mainPaned & ".combatframe.next}")
    tclEval(script = "bind " & comboBox &
        " <<ComboboxSelected>> {SetCombatPosition gunner " & $(gunIndex + 1) & "}")
    tclEval(script = "tooltip::tooltip " & comboBox & " \"Select the crew member which will be the operate the gun during\nthe combat. The sign + after name means that this crew member\nhas gunnery skill, the sign ++ after name means that they\ngunnery skill is the best in the crew\"")
    var gunnerOrders = ""
    for orderIndex, order in gunnersOrders:
      try:
        gunnerOrders = gunnerOrders & " " & order & getGunSpeed(
            position = gunIndex, index = orderIndex) & "}"
      except:
        tclEval(script = "bgerror {Can't show gunner's order. Reason: " &
            getCurrentExceptionMsg() & "}")
        return
    comboBox = frame & ".gunorder" & $(gunIndex + 1)
    if tclEval2(script = "winfo exists " & comboBox) == "0":
      tclEval(script = "ttk::combobox " & comboBox & " -values [list " &
          gunnerOrders & "] -state readonly")
    tclEval(script = comboBox & " current " & $(gun[2] - 1))
    if hasGunner:
      tclEval(script = "grid " & comboBox & " -row " & $(gunIndex + 4) & " -column 2 -padx {0 5}")
    else:
      tclEval(script = "grid remove " & comboBox)
    tclEval(script = "bind " & comboBox & " <Return> {InvokeButton " &
        mainPaned & ".combatframe.next}")
    tclEval(script = "bind " & comboBox &
        " <<ComboboxSelected>> {SetCombatOrder " & $(gunIndex + 1) & "}")
    tclEval(script = "tooltip::tooltip " & comboBox & " \"Select the order for the gunner. Shooting in the selected\npart of enemy ship is less precise but always hit the\nselected part.\"")
  # Show boarding/defending settings
  try:
    if (harpoonDuration > 0 or game.enemy.harpoonDuration > 0) and
        protoShipsList[enemyShipIndex].crew.len > 0:
      var button = frame & ".boarding"
      tclEval(script = "ttk::button " & button & " -text {Boarding party:} -command {SetCombatParty boarding}")
      tclEval(script = "grid " & button & " -padx 5")
      tclEval(script = "tooltip::tooltip " & comboBox & " \"Set your boarding party. If you join it, you will be able\nto give orders them, but not your gunners or engineer.\"")
      button = frame & ".defending"
      tclEval(script = "ttk::button " & button & " -text {Defenders:} -command {SetCombatParty defenders}")
      tclEval(script = "grid " & button & " -sticky we -padx 5 -pady 5")
      tclEval(script = "tooltip::tooltip " & comboBox & " \"Set your ship's defenders against the enemy party.\"")
      var boardingParty, defenders = ""
      for member in playerShip.crew:
        case member.order
        of boarding:
          boardingParty = boardingParty & member.name & ", "
        of defend:
          defenders = defenders & member.name & ", "
        else:
          discard
      if boardingParty.len > 0:
        boardingParty = boardingParty[0 .. ^2]
      var label = frame & ".boardparty"
      let labelLength = tclEval2(script = "winfo reqwidth " & frame &
            ".engineercrew").parseInt + tclEval2(script = "winfo reqwidth " &
            frame & ".engineerorder").parseInt
      if tclEval2(script = "winfo exists " & label) == "0":
        tclEval(script = "ttk::label " & label & " -text {" & boardingParty &
            "} -wraplength " & $labelLength)
        tclEval(script = "grid " & label & " -row " & $(guns.len + 4) & " -column 1 -columnspan 2 -sticky w")
        tclEval(script = "SetScrollbarBindings " & label & " $combatframe.crew.scrolly")
      else:
        tclEval(script = label & " configure -text {" & boardingParty & "}")
      if defenders.len > 0:
        defenders = defenders[0 .. ^2]
      label = frame & ".defenders"
      if tclEval2(script = "winfo exists " & label) == "0":
        tclEval(script = "ttk::label " & label & " -text {" & defenders &
            "} -wraplength " & $labelLength)
        tclEval(script = "grid " & label & " -row " & $(guns.len + 5) & " -column 1 -columnspan 2 -sticky w")
        tclEval(script = "SetScrollbarBindings " & label & " $combatframe.crew.scrolly")
      else:
        tclEval(script = label & " configure -text {" & defenders & "}")
  except:
    tclEval(script = "bgerror {Can't show information about boarding party and defenders. Reason: " &
        getCurrentExceptionMsg() & "}")
    return
  tclEval(script = "update")
  var combatCanvas = mainPaned & ".combatframe.crew.canvas"
  tclEval(script = combatCanvas & " configure -scrollregion [list " &
      tclEval2(script = combatCanvas & " bbox all") & "]")
  tclEval(script = combatCanvas & " xview moveto 0.0")
  tclEval(script = combatCanvas & " yview moveto 0.0")
  # Show the player's ship damage info if needed
  frame = mainPaned & ".combatframe.damage.canvas.frame"
  tclResult = tclEval2(script = "grid size " & frame).split(" ")
  try:
    rows = tclResult[1].parseInt()
    deleteWidgets(startIndex = 0, endIndex = rows - 1, frame = frame)
  except:
    discard
  var button = frame & ".maxmin"
  tclEval(script = "ttk::button " & button & " -style Small.TButton -image movemapupicon -command {CombatMaxMin damage show combat}")
  tclEval(script = "grid " & button & " -sticky w -padx 5 -row 0 -column 0")
  tclEval(script = "tooltip::tooltip " & button & " \"Maximize/minimize the ship status info\"")
  var row = 1
  for module in playerShip.modules:
    var label = frame & ".lbl" & $row
    tclEval(script = "ttk::label " & label & " -text {" & module.name & "}" &
        (if module.durability ==
        0: " -font OverstrikedFont -style Gray.TLabel" else: ""))
    tclEval(script = "grid " & label & " -row " & $row & " -sticky w -padx 5")
    tclEval(script = "SetScrollbarBindings " & label & " $combatframe.damage.scrolly")
    let
      damagePercent = module.durability.float / module.maxDurability.float
      progressBar = frame & ".dmg" & $row
    tclEval(script = "ttk::progressbar " & progressBar &
        " -orient horizontal -length 150 -maximum 1.0 -value " &
        $damagePercent & (if damagePercent ==
        1.0: " -style green.Horizontal.TProgressbar" elif damagePercent >
        0.24: " -style yellow.Horizontal.TProgressbar" else: " -style Horizontal.TProgressbar"))
    tclEval(script = "grid " & progressBar & " -row " & $row & " -column 1")
    tclEval(script = "SetScrollbarBindings " & progressBar & " $combatframe.damage.scrolly")
    tclEval(script = "grid columnconfigure " & progressBar & " -weight 1")
    tclEval(script = "grid rowconfigure " & progressBar & " -weight 1")
    row.inc
  tclEval(script = "update")
  combatCanvas = mainPaned & ".combatframe.damage.canvas"
  tclEval(script = combatCanvas & " configure -scrollregion [list " & tclEval2(
      script = combatCanvas & " bbox all") & "]")
  tclEval(script = combatCanvas & " xview moveto 0.0")
  tclEval(script = combatCanvas & " yview moveto 0.0")
  var enemyInfo = "Name: " & enemyName & "\nType: " & game.enemy.ship.name &
      "\nHome: " & skyBases[game.enemy.ship.homeBase].name & "\nDistance:" & (
      if game.enemy.distance >= 15_000: "Escaped" elif game.enemy.distance in
      10_000 ..
      15_000: "Long" elif game.enemy.distance in 5_000 ..
      10_000: "Medium" elif game.enemy.distance in 1_000 ..
      5_000: "Short" else: "Close") & "\nStatus: "
  if game.enemy.distance < 15_000:
    if game.enemy.ship.modules[0].durability == 0:
      enemyInfo = enemyInfo & "Destroyed"
    else:
      var enemyStatus = "Ok"
      for module in game.enemy.ship.modules:
        if module.durability < module.maxDurability:
          enemyStatus = "Damaged"
          break
      enemyInfo = enemyInfo & enemyStatus
    for module in game.enemy.ship.modules:
      if module.durability > 0:
        try:
          case modulesList[module.protoIndex].mType
          of armor:
            enemyInfo = enemyInfo & " (armored)"
          of gun:
            enemyInfo = enemyInfo & " (gun)"
          of batteringRam:
            enemyInfo = enemyInfo & " (battering ram)"
          of harpoonGun:
            enemyInfo = enemyInfo & " (harpoon gun)"
          else:
            discard
        except:
          tclEval(script = "bgerror {Can't show information about the enemy's ship. No proto module with index:" &
              $module.protoIndex & "}")
          return
  else:
    enemyInfo = enemyInfo & "Unknown"
  enemyInfo = enemyInfo & "\nSpeed: "
  if game.enemy.distance < 15_000:
    case game.enemy.ship.speed
    of fullStop:
      enemyInfo = enemyInfo & "Stopped"
    of quarterSpeed:
      enemyInfo = enemyInfo & "Slow"
    of halfSpeed:
      enemyInfo = enemyInfo & "Medium"
    of fullSpeed:
      enemyInfo = enemyInfo & "Fast"
    else:
      discard
    if game.enemy.ship.speed != fullStop:
      let speedDiff = try:
          realSpeed(ship = game.enemy.ship) - realSpeed(ship = playerShip)
        except:
          tclEval(script = "bgerror {Can't count the speed difference. Reason:" &
              getCurrentExceptionMsg() & "}")
          return
      if speedDiff > 250:
        enemyInfo = enemyInfo & " (much faster)"
      elif speedDiff > 0:
        enemyInfo = enemyInfo & " (faster)"
      elif speedDiff == 0:
        enemyInfo = enemyInfo & " (equal)"
      elif speedDiff > -250:
        enemyInfo = enemyInfo & " (slowed)"
      else:
        enemyInfo = enemyInfo & " (much slower)"
  else:
    enemyInfo = enemyInfo & "Unknown"
  if game.enemy.ship.description.len > 0:
    enemyInfo = enemyInfo & "\n\n" & game.enemy.ship.description
  var label = mainPaned & ".combatframe.enemy.canvas.frame.info"
  tclEval(script = label & " configure -text {" & enemyInfo & "}")
  tclEval(script = "update")
  combatCanvas = mainPaned & ".combatframe.enemy.canvas"
  tclEval(script = combatCanvas & " configure -scrollregion [list " & tclEval2(
      script = combatCanvas & " bbox all") & "]")
  tclEval(script = combatCanvas & " xview moveto 0.0")
  tclEval(script = combatCanvas & " yview moveto 0.0")
  # Show the enemy's ship damage info
  frame = mainPaned & ".combatframe.status.canvas.frame"
  tclResult = tclEval2(script = "grid size " & frame).split(" ")
  try:
    rows = tclResult[1].parseInt()
    deleteWidgets(startIndex = 0, endIndex = rows - 1, frame = frame)
  except:
    tclEval(script = "bgerror {Can't show the information about the enemy's ship's status. Reason: " &
        getCurrentExceptionMsg() & "}")
    return
  row = 1
  if endCombat:
    game.enemy.distance = 100
  for module in game.enemy.ship.modules.mitems:
    if endCombat:
      module.durability = 0
    label = frame & ".lbl" & $row
    try:
      tclEval(script = "ttk::label " & label & " -text {" & (
          if game.enemy.distance > 1_000: getModuleType(
          moduleIndex = module.protoIndex) else: modulesList[
          module.protoIndex].name) & "}" & (if module.durability ==
          0: " -font OverstrikedFont -style Gray.TLabel" else: ""))
    except:
      tclEval(script = "bgerror {Can't create the label with enemy module info. Reason: " &
          getCurrentExceptionMsg() & "}")
    tclEval(script = "grid " & label & " -row " & $row & " -column 0 -sticky w -padx 5")
    tclEval(script = "SetScrollbarBindings " & label & " $combatframe.status.scrolly")
    let
      damagePercent = (module.durability.float / module.maxDurability.float)
      progressBar = frame & ".dmg" & $row
    tclEval(script = "ttk::progressbar " & progressBar &
        " -orient horizontal -length 150 -maximum 1.0 -value " &
        $damagePercent & (if damagePercent ==
        1.0: " -style green.Horizontal.TProgressbar" elif damagePercent >
        0.24: " -style yellow.Horizontal.TProgressbar" else: " -style Horizontal.TProgressbar"))
    tclEval(script = "grid " & progressBar & " -row " & $row & " -column 1")
    tclEval(script = "SetScrollbarBindings " & progressBar & " $combatframe.status.scrolly")
    tclEval(script = "grid columnconfigure " & progressBar & " -weight 1")
    tclEval(script = "grid rowconfigure " & progressBar & " -weight 1")
    row.inc
  tclEval(script = "update")
  combatCanvas = mainPaned & ".combatframe.status.canvas"
  tclEval(script = combatCanvas & " configure -scrollregion [list " & tclEval2(
      script = combatCanvas & " bbox all") & "]")
  tclEval(script = combatCanvas & " xview moveto 0.0")
  tclEval(script = combatCanvas & " yview moveto 0.0")
  updateCombatMessages()

proc showCombatFrame(frameName: string) {.sideEffect, raises: [], tags: [].} =
  ## Switch between ship to ship combat and boarding UI. Hide the old UI
  ## elements and show the new
  ##
  ## * frameName - the name of the UI's frame to show
  let
    combatFrame = ".gameframe.paned.combatframe"
    combatChildren = [".crew", ".damage", ".enemy", ".status", ".next"]
    boardingChildren = [".left", ".right", ".next"]
  var childFrame = tclEval2(script = "grid slaves " & combatFrame & " -row 0 -column 0")
  if frameName == ".combat":
    if childFrame == combatFrame & combatChildren[0]:
      return
    for child in boardingChildren:
      tclEval(script = "grid remove " & combatFrame & child)
    for child in combatChildren:
      tclEval(script = "grid " & combatFrame & child)
  else:
    if childFrame == combatFrame & boardingChildren[0]:
      return
    for child in combatChildren:
      tclEval(script = "grid remove " & combatFrame & child)
    for child in boardingChildren:
      tclEval(script = "grid " & combatFrame & child)

proc updateBoardingUi() {.sideEffect, raises: [], tags: [].} =
  ## Update the boarding combat UI, remove the old elements and add new,
  ## depending on the information to show
  let frameName = mainPaned & ".combatframe"
  var frame = frameName & ".right.canvas.frame"
  tclEval(script = "bind . <" & generalAccelerators[0] & "> {InvokeButton " &
      frame & ".maxmin}")
  tclEval(script = "bind . <" & generalAccelerators[1] & "> {InvokeButton .left.canvas.frame.maxmin}")
  var
    tclResult = tclEval2(script = "grid size " & frame).split(" ")
    rows: Positive = try:
        tclResult[1].parseInt()
      except:
        1
  deleteWidgets(startIndex = 1, endIndex = rows - 1, frame = frame)
  var ordersList = ""
  for index, member in game.enemy.ship.crew:
    ordersList.add("{Attack " & member.name & "} ")
    let button = frame & ".name" & $(index + 1)
    tclEval(script = "ttk::button " & button & " -text {" & member.name &
        "} -command {ShowCombatInfo enemy " & $(index + 1) & "}")
    tclEval(script = "tooltip::tooltip " & button & " \"Show more information about the enemy's crew member.\"")
    tclEval(script = "grid " & button & " -row " & $(index + 1) & " -padx {5 0}")
    let progressBar = frame & ".health" & $(index + 1)
    tclEval(script = "ttk::progressbar " & progressBar &
        " -orient horizontal -value " & $member.health & " -length 150" & (
        if member.health >
        74: " -style green.Horizontal.TProgressbar" elif member.health >
        24: " -style yellow.Horizontal.TProgressbar" else: " -style Horizontal.TProgressbar"))
    tclEval(script = "tooltip::tooltip " & progressBar & " \"Enemy's health\"")
    tclEval(script = "grid " & progressBar & " -column 1 -row " & $(index + 1) & " -padx 5")
    tclEval(script = "SetScrollbarBindings " & progressBar & " $combatframe.right.scrolly")
    let label = frame & ".order" & $(index + 1)
    tclEval(script = "ttk::label " & label & " -text {" & (
        $member.order).capitalizeAscii & "}")
    tclEval(script = "tooltip::tooltip " & label & " \"Enemy's current order.\"")
    tclEval(script = "grid " & label & " -column 2 -row " & $(index + 1) & " -padx {0 5}")
    tclEval(script = "SetScrollbarBindings " & label & " $combatframe.right.scrolly")
  tclEval(script = "update")
  var combatCanvas = frameName & ".right.canvas"
  tclEval(script = combatCanvas & " configure -scrollregion [list " & tclEval2(
      script = combatCanvas & " bbox all") & "]")
  tclEval(script = combatCanvas & " xview moveto 0.0")
  tclEval(script = combatCanvas & " yview moveto 0.0")
  ordersList.add(" {Back to the ship}")
  frame = frameName & ".left.canvas.frame"
  tclResult = tclEval2(script = "grid size " & frame).split(" ")
  rows = try:
      tclResult[1].parseInt()
    except:
      1
  deleteWidgets(startIndex = 1, endIndex = rows - 1, frame = frame)
  var orderIndex = 0
  for index, member in playerShip.crew:
    if member.order != boarding:
      continue
    let button = frame & ".name" & $(index + 1)
    tclEval(script = "ttk::button " & button & " -text {" & member.name &
        "} -command {ShowCombatInfo player " & $(index + 1) & "}")
    tclEval(script = "tooltip::tooltip " & button & " \"Show more information about the crew member.\"")
    tclEval(script = "grid " & button & " -row " & $(index + 1) & " -padx {5 0}")
    let progressBar = frame & ".health" & $(index + 1)
    tclEval(script = "ttk::progressbar " & progressBar &
        " -orient horizontal -value " & $member.health & " -length 150" & (
        if member.health >
        74: " -style green.Horizontal.TProgressbar" elif member.health >
        24: " -style yellow.Horizontal.TProgressbar" else: " -style Horizontal.TProgressbar"))
    tclEval(script = "tooltip::tooltip " & progressBar & " \"The crew member health\"")
    tclEval(script = "grid " & progressBar & " -column 1 -row " & $(index + 1) & " -padx 5")
    tclEval(script = "SetScrollbarBindings " & progressBar & " $combatframe.left.scrolly")
    let comboBox = frame & ".order" & $(index + 1)
    tclEval(script = "ttk::combobox " & comboBox & " -values [list " &
        ordersList & "] -state readonly -width 15")
    tclEval(script = comboBox & " current " & $boardingOrders[orderIndex])
    tclEval(script = "bind " & comboBox &
        "<<ComboboxSelected>> {SetBoardingOrder " & $(index + 1) & " " & $(
        orderIndex + 1) & "}")
    tclEval(script = "tooltip::tooltip " & comboBox & " \"The crew member current order.\"")
    tclEval(script = "grid " & comboBox & " -column 2 -row " & $(index + 1) & " -padx {0 5}")
    orderIndex.inc
  tclEval(script = "update")
  combatCanvas = frameName & ".left.canvas"
  tclEval(script = combatCanvas & " configure -scrollregion [list " & tclEval2(
      script = combatCanvas & " bbox all") & "]")
  tclEval(script = combatCanvas & " xview moveto 0.0")
  tclEval(script = combatCanvas & " yview moveto 0.0")
  updateCombatMessages()

proc nextTurnCommand(clientData: cint; interp: PInterp; argc: cint;
    argv: openArray[cstring]): TclResults {.sideEffect, raises: [], tags: [
        WriteIOEffect, RootEffect].} =
  ## Excecute the combat orders and go the next turn
  ##
  ## * clientData - the additional data for the Tcl command
  ## * interp     - the Tcl interpreter on which the command was executed
  ## * argc       - the amount of arguments entered for the command
  ## * argv       - the list of the command's arguments
  ##
  ## The procedure always return tclOk
  ##
  ## Tcl:
  ## NextTurn
  try:
    combatTurn()
  except:
    tclEval(script = "bgerror {Can't make next turn in combat, reason: " &
        getCurrentExceptionMsg() & "}")
    return tclOk
  updateHeader()
  let combatFrame = mainPaned & ".combatframe"
  var frame = combatFrame & ".crew"
  if endCombat:
    for accel in generalAccelerators:
      tclEval(script = "bind . <" & accel & "> {}")
    updateCombatUi()
    tclEval(script = closeButton & " configure -command {ShowSkyMap}")
    tclSetVar(varName = "gamestate", newValue = "general")
    tclEval(script = "grid " & closeButton & " -row 0 -column 1")
    let frame = combatFrame & ".left"
    if tclEval2(script = "winfo ismapped " & frame) == "1":
      showCombatFrame(frameName = ".combat")
    let nextButton = combatFrame & ".next"
    tclEval(script = "grid remove " & nextButton)
    return tclOk
  if playerShip.crew[0].order == boarding and tclEval2(
      script = "winfo ismapped " & frame) == "1":
    updateBoardingUi()
    showCombatFrame(frameName = ".boarding")
    return tclOk
  if playerShip.crew[0].order != boarding and tclEval2(
      script = "winfo ismapped " & frame) == "0":
    updateCombatUi()
    showCombatFrame(frameName = ".combat")
    return tclOk
  if tclEval2(script = "winfo ismapped " & frame) == "1":
    updateCombatUi()
  else:
    updateBoardingUi()
  return tclOk

proc showCombatUi*(newCombat: bool = true) {.sideEffect, raises: [], tags: [RootEffect].}
  ## Show the combat UI to the player
  ##
  ## * newCombat - if true, starts a new combat with an enemy's ship

proc showCombatUiCommand(clientData: cint; interp: PInterp; argc: cint;
    argv: openArray[cstring]): TclResults {.sideEffect, raises: [], tags: [RootEffect].} =
  ## Show combat UI
  ##
  ## * clientData - the additional data for the Tcl command
  ## * interp     - the Tcl interpreter on which the command was executed
  ## * argc       - the amount of arguments entered for the command
  ## * argv       - the list of the command's arguments
  ##
  ## The procedure always return tclOk
  ##
  ## Tcl:
  ## ShowCombatUI
  try:
    showCombatUi(newCombat = false)
  except:
    tclEval(script = "bgerror {Can't show the combat UI. Reason: " &
        getCurrentExceptionMsg() & "}")
  return tclOk

proc setCombatOrderCommand(clientData: cint; interp: PInterp; argc: cint;
    argv: openArray[cstring]): TclResults {.sideEffect, raises: [], tags: [].} =
  ## Set the combat order for the selected the player's ship's crew member
  ##
  ## * clientData - the additional data for the Tcl command
  ## * interp     - the Tcl interpreter on which the command was executed
  ## * argc       - the amount of arguments entered for the command
  ## * argv       - the list of the command's arguments
  ##
  ## The procedure always return tclOk
  ##
  ## Tcl:
  ## SetCombatOrder Position
  ## Position argument can be pilot, engineer or number of the gun which
  ## gunner will take a new combat order
  let
    frameName = mainPaned & ".combatframe.crew.canvas.frame"
    faction = try:
        factionsList[playerShip.crew[0].faction]
      except:
        tclEval(script = "bgerror {Can't get the player's faction. Reason: " &
            getCurrentExceptionMsg() & "}")
        return tclOk
  if argv[1] == "pilot":
    let comboBox = frameName & ".pilotorder"
    pilotOrder = try:
        tclEval2(script = comboBox & " current").parseInt + 1
      except:
        tclEval(script = "bgerror {Can't get the pilot's order. Reason: " &
            getCurrentExceptionMsg() & "}")
        return tclOk
    if "sentientships" in faction.flags:
      addMessage(message = "Order for ship was set on: " & tclEval2(
          script = comboBox & " get"), mType = combatMessage)
    else:
      addMessage(message = "Order for " & playerShip.crew[findMember(
          order = pilot)].name & " was set on: " & tclEval2(script = comboBox &
          " get"), mType = combatMessage)
  elif argv[1] == "engineer":
    let comboBox = frameName & ".engineerorder"
    engineerOrder = try:
        tclEval2(script = comboBox & " current").parseInt + 1
      except:
        tclEval(script = "bgerror {Can't get the engineer's order. Reason: " &
            getCurrentExceptionMsg() & "}")
        return tclOk
    if "sentientships" in faction.flags:
      addMessage(message = "Order for ship was set on: " & tclEval2(
          script = comboBox & " get"), mType = combatMessage)
    else:
      addMessage(message = "Order for " & playerShip.crew[findMember(
          order = engineer)].name & " was set on: " & tclEval2(
          script = comboBox &
          " get"), mType = combatMessage)
  else:
    let
      comboBox = frameName & ".gunorder" & $argv[1]
      gunIndex = try:
          ($argv[1]).parseInt - 1
        except:
          tclEval(script = "bgerror {Can't get the gun's index. Reason: " &
              getCurrentExceptionMsg() & "}")
          return tclOk
    guns[gunIndex][2] = try:
        tclEval2(script = comboBox & " current").parseInt + 1
      except:
        tclEval(script = "bgerror {Can't set the gunners's order. Reason: " &
            getCurrentExceptionMsg() & "}")
        return tclOk
    guns[gunIndex][3] = (if tclEval2(script = comboBox & " current") ==
      "0": 0 else:
        try:
          modulesList[playerShip.modules[guns[gunIndex][1]].protoIndex].speed
        except:
          tclEval(script = "bgerror {Can't set the gunners's shooting order. Reason: " &
              getCurrentExceptionMsg() & "}")
          return tclOk)
    addMessage(message = "Order for " & playerShip.crew[playerShip.modules[guns[
        gunIndex][1]].owner[0]].name & " was set on: " & tclEval2(
        script = comboBox &
        " get"), mType = combatMessage)
  updateCombatMessages()
  return tclOk

proc setBoardingOrderCommand(clientData: cint; interp: PInterp; argc: cint;
    argv: openArray[cstring]): TclResults {.sideEffect, raises: [], tags: [].} =
  ## Set the boarding order for the selected the player's ship's crew member
  ##
  ## * clientData - the additional data for the Tcl command
  ## * interp     - the Tcl interpreter on which the command was executed
  ## * argc       - the amount of arguments entered for the command
  ## * argv       - the list of the command's arguments
  ##
  ## The procedure always return tclOk
  ##
  ## Tcl:
  ## SetBoardingOrder EnemyIndex
  ## EnemyIndex parameter is the index of the enemy in the enemy ship crew
  ## which will be set as target for the selected player ship crew member.
  let
    comboBox = mainPaned & ".combatframe.left.canvas.frame.order" & $argv[1]
    newOrder = try:
        tclEval2(script = comboBox & " current").parseInt + 1
      except:
        tclEval(script = "bgerror {Can't get the boarding order for a crew member. Reason: " &
            getCurrentExceptionMsg() & "}")
        return tclOk
  try:
    boardingOrders[($argv[2]).parseInt] = if newOrder >
        game.enemy.ship.crew.len: -1 else: newOrder
  except:
    tclEval(script = "bgerror {Can't set the boarding order for a crew member. Reason: " &
        getCurrentExceptionMsg() & "}")
  return tclOk

proc setCombatPartyCommand(clientData: cint; interp: PInterp; argc: cint;
    argv: openArray[cstring]): TclResults {.sideEffect, raises: [], tags: [].} =
  ## Set the melee combat party (boarding or defenders)
  ##
  ## * clientData - the additional data for the Tcl command
  ## * interp     - the Tcl interpreter on which the command was executed
  ## * argc       - the amount of arguments entered for the command
  ## * argv       - the list of the command's arguments
  ##
  ## The procedure always return tclOk
  ##
  ## Tcl:
  ## SetCombatParty partytype
  ## Partytype is a type of party to set. Possible options are boarding or
  ## defenders
  let
    crewDialog = createDialog(name = ".boardingdialog",
        title = "Assign a crew members to " & (if argv[1] ==
        "boarding": "boarding party" else: "defenders"), titleWidth = 245)
    buttonsFrame = crewDialog & ".selectframe"
  tclEval(script = "ttk::frame " & buttonsFrame)
  var button = buttonsFrame & ".selectallbutton"
  tclEval(script = "ttk::button " & button &
      " -image selectallicon -command {ToggleAllCombat select " & $argv[1] & "} -style Small.TButton")

  tclEval(script = "tooltip::tooltip " & button & " \"Select all crew members.\"")
  tclEval(script = "grid " & button & " -padx {5 2}")
  button = buttonsFrame & ".unselectallbutton"
  tclEval(script = "ttk::button " & button &
      " -image unselectallicon -command {ToggleAllCombat unselect " & $argv[1] & "} -style Small.TButton")

  tclEval(script = "tooltip::tooltip " & button & " \"Unselect all crew members.\"")
  tclEval(script = "grid " & button & " -sticky w -row 0 -column 1")
  tclEval(script = "grid " & buttonsFrame & " -columnspan 2 -sticky w")
  let yScroll = crewDialog & ".yscroll"
  tclEval(script = "ttk::scrollbar " & yScroll &
      " -orien vertical -command [list " & crewDialog & ".canvas yview]")
  let crewCanvas = crewDialog & ".canvas"
  tclEval(script = "canvas " & crewCanvas & " -yscrollcommand [list " &
      yScroll & " set]")
  tclEval(script = "grid " & crewCanvas & " -sticky nwes -padx 5 -pady  5")
  tclEval(script = "grid " & yScroll & " -sticky ns -padx {0 5} -pady {5 0} -row 2 -column 1")
  let buttonsBox2 = crewDialog & ".buttons"
  tclEval(script = "ttk::frame " & buttonsBox2)
  tclEval(script = "grid " & buttonsBox2 & " -pady {0 5} -columnspan 2")
  let acceptButton = crewDialog & ".buttons.button2"
  tclEval(script = "ttk::button " & acceptButton &
      " -text Assign -command {SetParty " & $argv[1] & "; CloseDialog " &
      crewDialog & "} -image giveordericon -style Dialog.TButton")
  tclEval(script = "grid " & acceptButton & " -padx {5 2}")
  let closeDialogButton = crewDialog & ".buttons.button"
  tclEval(script = "ttk::button " & closeDialogButton &
      " -text Cancel -command {CloseDialog " & crewDialog & "} -image cancelicon -style Dialog.TButton")
  tclEval(script = "grid " & closeDialogButton & " -sticky w -row 0 -column 1")
  tclEval(script = "focus " & closeDialogButton)
  tclEval(script = "::autoscroll::autoscroll " & yScroll)
  let
    order = (if argv[1] == "boarding": boarding else: defend)
    crewFrame = crewCanvas & ".frame"
  tclEval(script = "ttk::frame " & crewFrame)
  var
    height = 10
    width = 250
  for index, member in playerShip.crew:
    let crewButton = crewFrame & ".crewbutton" & $(index + 1)
    tclEval(script = "ttk::checkbutton " & crewButton & " -text {" &
        member.name & "}")
    if member.order == order:
      tclSetVar(varName = crewButton, newValue = "1")
    else:
      tclSetVar(varName = crewButton, newValue = "0")
    tclEval(script = "pack " & crewButton & " -anchor w")
    height = try:
        height + tclEval2(script = "winfo reqheight " & crewButton).parseInt
      except:
        tclEval(script = "bgerror {Can't set the height of the dialog. Reason: " &
            getCurrentExceptionMsg() & "}")
        return tclOk
    try:
      if tclEval2(script = "winfo reqwidth " & crewButton).parseInt + 10 > width:
        width = tclEval2(script = "winfo reqwidth " & crewButton).parseInt + 10
    except:
      tclEval(script = "bgerror {Can't set the width of the dialog. Reason: " &
          getCurrentExceptionMsg() & "}")
      return tclOk
    tclEval(script = "bind " & crewButton & " <Escape> {" & closeDialogButton & " invoke;break}")
    tclEval(script = "bind " & crewButton & " <Tab> {focus [GetActiveButton " &
        $(index + 1) & "];break}")
  if height > 500:
    height = 500
  tclEval(script = crewCanvas & " create window 0 0 -anchor nw -window " & crewFrame)
  tclEval(script = "update")
  tclEval(script = crewCanvas & " configure -scrollregion [list " & tclEval2(
      script = crewCanvas & " bbox all") & "] -height " & $height & " -width " & $width)
  tclEval(script = "bind " & closeDialogButton & " <Escape> {" &
      closeDialogButton & " invoke;break}")
  tclEval(script = "bind " & closeDialogButton & " <Tab> {focus [GetActiveButton 0];break}")
  showDialog(dialog = crewDialog, relativeY = 0.2)
  return tclOk

proc setCombatPositionCommand(clientData: cint; interp: PInterp; argc: cint;
    argv: openArray[cstring]): TclResults {.sideEffect, raises: [], tags: [RootEffect].} =
  ## Set crew member position (pilot, engineer, gunner) in combat
  ##
  ## * clientData - the additional data for the Tcl command
  ## * interp     - the Tcl interpreter on which the command was executed
  ## * argc       - the amount of arguments entered for the command
  ## * argv       - the list of the command's arguments
  ##
  ## The procedure always return tclOk
  ##
  ## Tcl:
  ## SetCombatPosition position ?gunindex?
  ## Position is the combat crew member position which will be set. For gunner
  ## additional parameter is gunindex, index of the gun to take
  let frameName = ".gameframe.paned.combatframe.crew.canvas.frame"
  var comboBox = ""
  if argv[1] == "pilot":
    comboBox = frameName & ".pilotcrew"
    var crewIndex = try:
        tclEval2(script = comboBox & " current").parseInt - 1
      except:
        tclEval(script = "bgerror {Can't get the pilot index. Reason: " &
            getCurrentExceptionMsg() & "}")
        return tclOk
    if crewIndex > -1:
      try:
        giveOrders(ship = playerShip, memberIndex = crewIndex,
            givenOrder = pilot)
      except:
        tclEval(script = "bgerror {Can't give order to the pilot. Reason: " &
            getCurrentExceptionMsg() & "}")
        return tclOk
    else:
      crewIndex = findMember(order = pilot)
      if crewIndex > -1:
        try:
          giveOrders(ship = playerShip, memberIndex = crewIndex,
              givenOrder = rest)
        except:
          tclEval(script = "bgerror {Can't give rest order to the pilot. Reason: " &
              getCurrentExceptionMsg() & "}")
          return tclOk
  elif argv[1] == "engineer":
    comboBox = frameName & ".engineercrew"
    var crewIndex = try:
        tclEval2(script = comboBox & " current").parseInt - 1
      except:
        tclEval(script = "bgerror {Can't get the engineer index. Reason: " &
            getCurrentExceptionMsg() & "}")
        return tclOk
    if crewIndex > -1:
      try:
        giveOrders(ship = playerShip, memberIndex = crewIndex,
            givenOrder = engineer)
      except:
        tclEval(script = "bgerror {Can't give order to the engineer. Reason: " &
            getCurrentExceptionMsg() & "}")
        return tclOk
    else:
      crewIndex = findMember(order = engineer)
      if crewIndex > -1:
        try:
          giveOrders(ship = playerShip, memberIndex = crewIndex,
              givenOrder = rest)
        except:
          tclEval(script = "bgerror {Can't give rest order to the engineer. Reason: " &
              getCurrentExceptionMsg() & "}")
          return tclOk
  else:
    comboBox = frameName & ".guncrew" & $argv[2]
    let gunIndex = try:
        ($argv[2]).parseInt - 1
      except:
        tclEval(script = "bgerror {Can't get the gun index. Reason: " &
            getCurrentExceptionMsg() & "}")
        return tclOk
    var crewIndex = try:
          tclEval2(script = comboBox & " current").parseInt - 1
        except:
          tclEval(script = "bgerror {Can't get the gunner index. Reason: " &
              getCurrentExceptionMsg() & "}")
          return tclOk
    if crewIndex > -1:
      try:
        giveOrders(ship = playerShip, memberIndex = crewIndex,
            givenOrder = gunner, moduleIndex = guns[gunIndex][1])
      except:
        tclEval(script = "bgerror {Can't give order to the gunner. Reason: " &
            getCurrentExceptionMsg() & "}")
        return tclOk
    else:
      crewIndex = playerShip.modules[guns[gunIndex][1]].owner[0]
      if crewIndex > -1:
        try:
          giveOrders(ship = playerShip, memberIndex = crewIndex,
              givenOrder = rest)
        except:
          tclEval(script = "bgerror {Can't give rest order to the gunner. Reason: " &
              getCurrentExceptionMsg() & "}")
          return tclOk
  updateCombatUi()
  return tclOk

proc showCombatInfoCommand(clientData: cint; interp: PInterp; argc: cint;
    argv: openArray[cstring]): TclResults {.sideEffect, raises: [], tags: [].} =
  ## Show information about the selected mob in combat
  ##
  ## * clientData - the additional data for the Tcl command
  ## * interp     - the Tcl interpreter on which the command was executed
  ## * argc       - the amount of arguments entered for the command
  ## * argv       - the list of the command's arguments
  ##
  ## The procedure always return tclOk
  ##
  ## Tcl:
  ## ShowCombatInfo player|enemy index
  ## Player or enemy means to show information about the mob from the player's
  ## ship or the enemy's ship. Index is the index of the mob in the ship's crew
  let crewIndex = try:
      ($argv[2]).parseInt - 1
    except:
      tclEval(script = "bgerror {Can't get the index of the crew member. Reason: " &
          getCurrentExceptionMsg() & "}")
      return tclOk
  var info = "Uses: "
  if argv[1] == "player":
    for item in playerShip.crew[crewIndex].equipment:
      if item > -1:
        info = info & "\n" & getItemName(item = playerShip.crew[
            crewIndex].inventory[item])
  else:
    for item in game.enemy.ship.crew[crewIndex].equipment:
      if item > -1:
        info = info & "\n" & getItemName(item = game.enemy.ship.crew[
            crewIndex].inventory[item])
  showInfo(text = info, title = "More info")
  return tclOk

proc combatMaxMinCommand(clientData: cint; interp: PInterp; argc: cint;
    argv: openArray[cstring]): TclResults {.sideEffect, raises: [], tags: [].} =
  ## Maximize or minimize the selected section of the combat UI
  ##
  ## * clientData - the additional data for the Tcl command
  ## * interp     - the Tcl interpreter on which the command was executed
  ## * argc       - the amount of arguments entered for the command
  ## * argv       - the list of the command's arguments
  ##
  ## The procedure always return tclOk
  ##
  ## Tcl:
  ## CombatMaxMin framename show|hide combat|boarding
  ## Framename is name of the frame to maximize or minimize, show or hide is
  ## the name of action to take, combat or boarding is the name of the combat
  ## screen in which the section will be maximized or minimized
  type FrameInfo = object
    name: string
    column: Natural
    row: Natural
  let
    combatFrames: array[1 .. 4, FrameInfo] = [FrameInfo(name: "crew", column: 0,
        row: 0), FrameInfo(name: "damage", column: 0, row: 1), FrameInfo(
        name: "enemy", column: 1, row: 0), FrameInfo(name: "status", column: 1, row: 1)]
    boardingFrames: array[1 .. 4, FrameInfo] = [FrameInfo(name: "left",
        column: 0, row: 0), FrameInfo(name: "right", column: 1, row: 0),
        FrameInfo(name: "", column: 0, row: 0), FrameInfo(name: "", column: 0, row: 0)]
    frames = (if argv[3] == "combat": combatFrames else: boardingFrames)
    button = mainPaned & ".combatframe." & $argv[1] & ".canvas.frame.maxmin"
  if argv[2] == "show":
    for frameInfo in frames:
      let frameName = mainPaned & ".combatframe." & frameInfo.name
      if frameInfo.name == $argv[1]:
        tclEval(script = "grid configure " & frameName & " -columnspan 2 -rowspan 2 -row 0 -column 0")
      else:
        tclEval(script = "grid remove " & frameName)
    tclEval(script = button & " -image movemapdownicon -commnad {CombatMaxMix " &
        $argv[1] & " hide " & $argv[3] & "}")
  else:
    for frameInfo in frames:
      let frameName = mainPaned & ".combatframe." & frameInfo.name
      if frameInfo.name == $argv[1]:
        tclEval(script = "grid " & frameName)
      else:
        tclEval(script = "grid configure " & frameName &
            " -columnspan 1 -rowspan 1 -column " & $frameInfo.column &
            " -row " & $frameInfo.row)
    tclEval(script = button & " -image movemapdownicon -commnad {CombatMaxMix " &
        $argv[1] & " show " & $argv[3] & "}")
  return tclOk

proc toggleAllCombatCommand(clientData: cint; interp: PInterp; argc: cint;
    argv: openArray[cstring]): TclResults {.sideEffect, raises: [], tags: [].} =
  ## Select or deselect all crew members in boarding and defending parties
  ## setting
  ##
  ## * clientData - the additional data for the Tcl command
  ## * interp     - the Tcl interpreter on which the command was executed
  ## * argc       - the amount of arguments entered for the command
  ## * argv       - the list of the command's arguments
  ##
  ## The procedure always return tclOk
  ##
  ## Tcl:
  ## ToggleAllCombat action order
  ## Action is the action which will be performed. Possible values are
  ## select or deselect. Order is the order to give to the player's ship
  ## crew. Possible values are boarding and defending.
  boardingOrders = @[]
  for index, member in playerShip.crew:
    tclSetVar(varName = ".boardingdialog.canvas.frame.crewbutton" & $(index +
        1), newValue = (if argv[1] == "select": "1" else: "0"))
  return tclOk

proc setPartyCommand(clientData: cint; interp: PInterp; argc: cint;
    argv: openArray[cstring]): TclResults {.sideEffect, raises: [], tags: [RootEffect].} =
  ## Set crew members in or out of boarding and defending party
  ##
  ## * clientData - the additional data for the Tcl command
  ## * interp     - the Tcl interpreter on which the command was executed
  ## * argc       - the amount of arguments entered for the command
  ## * argv       - the list of the command's arguments
  ##
  ## The procedure always return tclOk
  ##
  ## Tcl:
  ## SetParty order
  ## Order is the order to give to the player's ship crew. Possible
  ## values are boarding and defending.
  boardingOrders = @[]
  let order = (if argv[1] == "boarding": boarding else: defend)
  for index, member in playerShip.crew:
    let selected = tclGetVar(varName = ".boardingdialog.canvas.frame.crewbutton" &
        $(index + 1)) == "1"
    if member.order == order and not selected:
      try:
        giveOrders(ship = playerShip, memberIndex = index, givenOrder = rest)
      except:
        tclEval(script = "bgerror {Can't give order to not selected crew member. Reason: " &
            getCurrentExceptionMsg() & "}")
        return tclOk
    elif selected and member.order != order:
      try:
        giveOrders(ship = playerShip, memberIndex = index, givenOrder = order,
            moduleIndex = -1)
      except:
        tclEval(script = "bgerror {Can't give order to selected crew member. Reason: " &
            getCurrentExceptionMsg() & "}")
        return tclOk
      if order == boarding:
        boardingOrders.add(0)
  updateCombatUi()
  return tclOk

proc showCombatUi(newCombat: bool = true) =
  tclEval(script = "grid remove " & closeButton)
  var combatStarted = false
  let combatFrame = mainPaned & ".combatframe"
  if newCombat:
    try:
      if skyMap[playerShip.skyX][playerShip.skyY].eventIndex > -1 and
          enemyName != protoShipsList[eventsList[skyMap[playerShip.skyX][
          playerShip.skyY].eventIndex].shipIndex].name:
        combatStarted = startCombat(enemyIndex = eventsList[skyMap[
            playerShip.skyX][playerShip.skyY].eventIndex].shipIndex,
            newCombat = false)
        if not combatStarted:
          return
    except:
      tclEval(script = "bgerror {Can't start the combat. Reason: " &
          getCurrentExceptionMsg() & "}")
      return
    if tclEval2(script = "winfo exists " & combatFrame) == "0":
      tclEvalFile(fileName = dataDirectory & "ui" & DirSep & "combat.tcl")
      pilotOrder = 2
      engineerOrder = 3
      try:
        addCommand("NextTurn", nextTurnCommand)
        addCommand("ShowCombatUI", showCombatUiCommand)
        addCommand("SetCombatOrder", setCombatOrderCommand)
        addCommand("SetBoardingOrder", setBoardingOrderCommand)
        addCommand("SetCombatParty", setCombatPartyCommand)
        addCommand("SetCombatPosition", setCombatPositionCommand)
        addCommand("ShowCombatInfo", showCombatInfoCommand)
        addCommand("CombatMaxMix", combatMaxMinCommand)
        addCommand("ToggleAllCombat", toggleAllCombatCommand)
        addCommand("SetParty", setPartyCommand)
      except:
        tclEval(script = "bgerror {Can't add a Tcl command. Reason: " &
            getCurrentExceptionMsg() & "}")
        return
    else:
      let
        button = combatFrame & ".next"
        enemyFrame = combatFrame & ".status"
      tclEval(script = "grid " & button)
      tclEval(script = "grid " & enemyFrame)
    tclEval(script = closeButton & " configure -command ShowCombatUI")
    tclSetVar(varName = "gamestate", newValue = "combat")
    for member in playerShip.crew.mitems:
      if member.order == rest and member.previousOrder in {pilot, engineer, gunner}:
        member.order = member.previousOrder
        member.orderTime = 15
        addMessage(message = member.name & " back to work for combat.",
            mType = orderMessage)
  if playerShip.crew[0].order == boarding:
    updateBoardingUi()
    showCombatFrame(frameName = ".boarding")
  else:
    updateCombatUi()
    showCombatFrame(frameName = ".combat")
  showScreen(newScreenName = "combatframe")

# Temporary code for interfacing with Ada

proc updateCombatAdaMessages() {.raises: [], tags: [], exportc.} =
  updateCombatMessages()

proc updateAdaCombatUi() {.raises: [], tags: [], exportc.} =
  updateCombatUi()

proc showAdaCombatFrame(frameName: cstring) {.raises: [], tags: [], exportc.} =
  showCombatFrame($frameName)

proc updateAdaBoardingUi() {.raises: [], tags: [], exportc.} =
  try:
    updateBoardingUi()
  except:
    echo getCurrentExceptionMsg()
    echo getStackTrace(getCurrentException())

proc showAdaCombatUi(newCombat: cint) {.raises: [], tags: [RootEffect], exportc.} =
  try:
    showCombatUi(newCombat = newCombat == 1)
  except:
    discard
