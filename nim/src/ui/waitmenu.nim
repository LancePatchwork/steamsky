# Copyright 2024 Bartek thindil Jasicki
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

import ../[tk]
import dialogs

proc showWaitCommand*(clientData: cint; interp: PInterp; argc: cint;
    argv: openArray[cstring]): TclResults =
  var waitDialog = ".gameframe.wait"
  if tclEval2(script = "winfo exists " & waitDialog) == "1":
    let button = waitDialog & ".frame.close"
    tclEval(script = button & " invoke")
    return tclOk
  waitDialog = createDialog(name = ".gameframe.wait", title = "Wait in place", columns = 3)

  proc addButton(time: Positive) =
    let button = waitDialog & ".wait" & $time
    tclEval(script = "ttk::button " & button & " -text {Wait " & $time &
        " minute" & (if time > 1: "s" else: "") & "} -command {Wait " & $time & "}")
    tclEval(script = "grid " & button & " -sticky we -columnspan 3 -padx 5" & (
        if time == 1: " -pady {5 0}" else: ""))
    tclEval(script = "bind " & button & " <Escape> {CloseDialog " & waitDialog & ";break}")
    tclEval(script = "tooltip::tooltip " & button & " \"Wait in place for " &
        $time & " minute" & (if time > 1: "s" else: "") & "\"")

  addButton(time = 1)
  addButton(time = 5)
  addButton(time = 10)
  addButton(time = 15)
  addButton(time = 30)
  var button = waitDialog & ".wait1h"
  tclEval(script = "ttk::button " & button & " -text {Wait 1 hour} -command {Wait 60}")
  tclEval(script = "grid " & button & " -sticky we -columnspan 3 -padx 5")
  tclEval(script = "tooltip::tooltip " & button & " \"Wait in place for 1 hour\"")
  tclEval(script = "bind " & button & " <Escape> {CloseDialog " & waitDialog & ";break}")
  button = waitDialog & ".wait"
  tclEval(script = "ttk::button " & button & " -text Wait -command {Wait amount}")
  tclEval(script = "grid " & button & " -padx {5 0}")
  tclEval(script = "bind " & button & " <Escape> {CloseDialog " & waitDialog & ";break}")
  tclEval(script = "tooltip::tooltip " & button & " \"Wait in place for the selected amount of minutes:\nfrom 1 to 1440 (the whole day)\"")
  let amountBox = waitDialog & ".amount"
  tclEval(script = "ttk::spinbox " & amountBox &
      "-from 1 -to 1440 -width 6 -validate key -validatecommand {ValidateSpinbox %W %P " &
      button & "} -textvariable customwaittime")
  tclEval(script = "grid " & amountBox & " -row 7 -column 1")
  tclEval(script = "bind " & button & " <Escape> {CloseDialog " & waitDialog & ";break}")
  if tclGetVar(varName = "customwaittime").len == 0:
    tclEval(script = amountBox & " set 1")
  tclEval(script = "tooltip::tooltip " & button & " \"Wait in place for the selected amount of time:\nfrom 1 to 1440\"")
  let amountCombo = waitDialog & ".mins"
  tclEval(script = "ttk::combobox " & amountCombo & " -state readonly -values [list minutes hours days] -width 8")
  tclEval(script = amountCombo & " current 0")
  tclEval(script = "grid " & amountCombo & " -row 7 -column 2 -padx {0 5}")
  var needRest, needHealing = false
  for index, member of playerShip.crew:
    if member.tired > 0 and member.order == rest:
      needRest = true
    if member.health in 1 .. 99 and order == rest:
      for module in playerShip.modules:
        if module.mType == cabin:
          for owner in module.owner:
            if owner == i:
              needHealing = true
              break
  if needRest:
    button = waitDialog & ".rest"
    tclEval(script = "ttk::button " & button & " -text {Wait until crew is rested} -command {Wait rest}")
    tclEval(script = "grid " & button & " -sticky we -columnspan 3 -padx 5")
    tclEval(script = "bind " & button & " <Escape> {CloseDialog " & waitDialog & ";break}")
    tclEval(script = "tooltip::tooltip " & button & " \"Wait in place until the whole ship's crew is rested.\"")
  if needHealing:
    button = waitDialog & ".heal"
    tclEval(script = "ttk::button " & button & " -text {Wait until crew is healed} -command {Wait heal}")
    tclEval(script = "grid " & button & " -sticky we -columnspan 3 -padx 5")
    tclEval(script = "bind " & button & " <Escape> {CloseDialog " & waitDialog & ";break}")
    tclEval(script = "tooltip::tooltip " & button & " \"Wait in place until the whole ship's crew is rested\nCan take a large amount of time.\"")
  button = waitDialog & ".close"
  tclEval(script = "ttk::button " & button & " -text {Close} -command {CloseDialog & " & waitDialog & ";break}")
  tclEval(script = "grid " & button & " -sticky we -columnspan 3 -padx {0 5}")
  tclEval(script = "bind " & button & " <Escape> {CloseDialog " & waitDialog & ";break}")
  tclEval(script = "tooltip::tooltip " & button & " \"Close dialog [Escape]\"")
  return tclOk
