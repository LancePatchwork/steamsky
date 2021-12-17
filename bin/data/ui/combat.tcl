# Copyright (c) 2020-2021 Bartek thindil Jasicki <thindil@laeran.pl>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set combatframe [ttk::frame .gameframe.paned.combatframe]

# Ship to ship combat
# Player ship crew orders
grid [ttk::labelframe $combatframe.crew -text {Your ship crew orders:}] \
   -padx 5 -pady {0 5} -sticky nwes
set combatcanvas [canvas $combatframe.crew.canvas \
   -yscrollcommand [list $combatframe.crew.scrolly set] \
   -xscrollcommand [list $combatframe.crew.scrollx set]]
pack [ttk::scrollbar $combatframe.crew.scrolly -orient vertical \
   -command [list $combatcanvas yview]] -side right -fill y
pack [ttk::scrollbar $combatframe.crew.scrollx -orient horizontal \
   -command [list $combatcanvas xview]] -fill x -side bottom
pack $combatcanvas -side top -fill both -expand true
SetScrollbarBindings $combatcanvas $combatframe.crew.scrolly
ttk::frame $combatcanvas.frame
SetScrollbarBindings $combatcanvas.frame $combatframe.crew.scrolly
# Minimize/maximize button
grid [ttk::button $combatcanvas.frame.maxmin -style Small.TButton \
   -text "[format %c 0xf106]" -command {CombatMaxMin crew show}] -sticky w \
   -padx 5
tooltip::tooltip $combatcanvas.frame.maxmin \
   {Maximize/minimize the ship crew orders}
grid [ttk::label $combatcanvas.frame.position -text {Position}]
SetScrollbarBindings $combatcanvas.frame.position $combatframe.crew.scrolly
grid [ttk::label $combatcanvas.frame.name -text {Name}] -row 1 -column 1
SetScrollbarBindings $combatcanvas.frame.name $combatframe.crew.scrolly
grid [ttk::label $combatcanvas.frame.order -text {Order}] -row 1 -column 2
SetScrollbarBindings $combatcanvas.frame.order $combatframe.crew.scrolly
grid [ttk::label $combatcanvas.frame.pilotlabel -text {Pilot:}] -row 2 \
   -sticky w -padx {5 0} -pady {0 5}
SetScrollbarBindings $combatcanvas.frame.pilotlabel $combatframe.crew.scrolly
grid [ttk::combobox $combatcanvas.frame.pilotcrew -state readonly -width 10] \
   -row 2 -column 1 -pady {0 5}
tooltip::tooltip $combatcanvas.frame.pilotcrew "Select the crew member which will be the pilot during the combat.\nThe sign + after name means that this crew member has\npiloting skill, the sign ++ after name means that his/her\npiloting skill is the best in the crew"
bind $combatcanvas.frame.pilotcrew <Return> {InvokeButton $combatframe.next}
bind $combatcanvas.frame.pilotcrew <<ComboboxSelected>> \
   {SetCombatPosition pilot}
grid [ttk::combobox $combatcanvas.frame.pilotorder -state readonly \
   -values [list {Go closer} {Keep distance} {Evade} {Escape}]] -row 2 \
   -column 2 -padx {0 5} -pady {0 5}
tooltip::tooltip $combatcanvas.frame.pilotorder "Select the order for the pilot"
bind $combatcanvas.frame.pilotorder <Return> {InvokeButton $combatframe.next}
bind $combatcanvas.frame.pilotorder <<ComboboxSelected>> {SetCombatOrder pilot}
grid [ttk::label $combatcanvas.frame.engineerlabel -text {Engineer:}] -row 3 \
   -sticky w -padx {5 0} -pady {5 0}
SetScrollbarBindings $combatcanvas.frame.engineerlabel $combatframe.crew.scrolly
grid [ttk::combobox $combatcanvas.frame.engineercrew -state readonly -width 10] \
   -row 3 -column 1 -pady {5 0}
tooltip::tooltip $combatcanvas.frame.engineercrew "Select the crew member which will be the engineer during the combat.\nThe sign + after name means that this crew member has\nengineering skill, the sign ++ after name means that his/her\nengineering skill is the best in the crew"
bind $combatcanvas.frame.engineercrew <Return> {InvokeButton $combatframe.next}
bind $combatcanvas.frame.engineercrew <<ComboboxSelected>> \
   {SetCombatPosition engineer}
grid [ttk::combobox $combatcanvas.frame.engineerorder -state readonly \
   -values [list {All stop} {Quarter speed} {Half speed} {Full speed}]] \
   -row 3 -column 2 -padx {0 5} -pady {5 0}
tooltip::tooltip $combatcanvas.frame.engineerorder "Set the ship speed. The faster ship move the harder is\nto hit it, but also it is harder to hit the enemy"
bind $combatcanvas.frame.engineerorder <Return> {InvokeButton $combatframe.next}
bind $combatcanvas.frame.engineerorder <<ComboboxSelected>> \
   {SetCombatOrder engineer}
$combatcanvas create window 0 0 -anchor nw -window $combatcanvas.frame
::autoscroll::autoscroll $combatframe.crew.scrolly
::autoscroll::autoscroll $combatframe.crew.scrollx
# Player ship damage
grid [ttk::labelframe $combatframe.damage -text {Your ship damage:}] -padx 5 \
   -pady 5 -sticky nwes
set combatcanvas [canvas $combatframe.damage.canvas \
   -yscrollcommand [list $combatframe.damage.scrolly set] \
   -xscrollcommand [list $combatframe.damage.scrollx set]]
pack [ttk::scrollbar $combatframe.damage.scrolly -orient vertical \
   -command [list $combatcanvas yview]] -side right -fill y
pack [ttk::scrollbar $combatframe.damage.scrollx -orient horizontal \
   -command [list $combatcanvas xview]] -fill x -side bottom
pack $combatcanvas -side top -fill both -expand true
SetScrollbarBindings $combatcanvas $combatframe.damage.scrolly
ttk::frame $combatcanvas.frame
SetScrollbarBindings $combatcanvas.frame $combatframe.damage.scrolly
# Minimize/maximize button
grid [ttk::button $combatcanvas.frame.maxmin -style Small.TButton \
   -text "[format %c 0xf106]" -command {CombatMaxMin damage show}] -sticky w \
   -padx 5
tooltip::tooltip $combatcanvas.frame.maxmin \
   {Maximize/minimize the ship damage}
$combatcanvas create window 0 0 -anchor nw -window $combatcanvas.frame
::autoscroll::autoscroll $combatframe.damage.scrolly
::autoscroll::autoscroll $combatframe.damage.scrollx
# Enemy ship info
grid [ttk::labelframe $combatframe.enemy -text {Enemy info:}] -sticky nwes \
   -padx 5 -pady {0 5} -column 1 -row 0
set combatcanvas [canvas $combatframe.enemy.canvas \
   -yscrollcommand [list $combatframe.enemy.scrolly set] \
   -xscrollcommand [list $combatframe.enemy.scrollx set]]
pack [ttk::scrollbar $combatframe.enemy.scrolly -orient vertical \
   -command [list $combatcanvas yview]] -side right -fill y
pack [ttk::scrollbar $combatframe.enemy.scrollx -orient horizontal \
   -command [list $combatcanvas xview]] -fill x -side bottom
pack $combatcanvas -side top -fill both -expand true
SetScrollbarBindings $combatcanvas $combatframe.enemy.scrolly
ttk::label $combatcanvas.info -wraplength 350
SetScrollbarBindings $combatcanvas.info $combatframe.enemy.scrolly
$combatcanvas create window 0 0 -anchor nw -window $combatcanvas.info
::autoscroll::autoscroll $combatframe.enemy.scrolly
::autoscroll::autoscroll $combatframe.enemy.scrollx
# Enemy ship info damage
grid [ttk::labelframe $combatframe.status -text {Enemy ship status:}] \
   -sticky nwes -padx 5 -pady 5 -column 1 -row 1
set combatcanvas [canvas $combatframe.status.canvas \
   -yscrollcommand [list $combatframe.status.scrolly set] \
   -xscrollcommand [list $combatframe.status.scrollx set]]
pack [ttk::scrollbar $combatframe.status.scrolly -orient vertical \
   -command [list $combatcanvas yview]] -side right -fill y
pack [ttk::scrollbar $combatframe.status.scrollx -orient horizontal \
   -command [list $combatcanvas xview]] -fill x -side bottom
pack $combatcanvas -side top -fill both -expand true
SetScrollbarBindings $combatcanvas $combatframe.status.scrolly
ttk::frame $combatcanvas.frame
SetScrollbarBindings $combatcanvas.frame $combatframe.status.scrolly
$combatcanvas create window 0 0 -anchor nw -window $combatcanvas.frame
::autoscroll::autoscroll $combatframe.status.scrolly
::autoscroll::autoscroll $combatframe.status.scrollx
grid [ttk::button $combatframe.next -text {Next turn [Enter]} \
   -command NextTurn] -columnspan 2 -sticky we -row 2 -column 0
bind $combatframe.next <Return> {InvokeButton $combatframe.next}
focus $combatframe.next

# Boarding combat
# Player boarding team
grid [ttk::labelframe $combatframe.left -text {Your crew:}] -sticky nwes \
   -row 0 -column 0 -rowspan 2 -padx 5 -pady 5
set combatcanvas [canvas $combatframe.left.canvas \
   -yscrollcommand [list $combatframe.left.scrolly set] \
   -xscrollcommand [list $combatframe.left.scrollx set]]
pack [ttk::scrollbar $combatframe.left.scrolly -orient vertical \
   -command [list $combatcanvas yview]] -side right -fill y
pack [ttk::scrollbar $combatframe.left.scrollx -orient horizontal \
   -command [list $combatcanvas xview]] -fill x -side bottom
pack $combatcanvas -side top -fill both -expand true
SetScrollbarBindings $combatcanvas $combatframe.left.scrolly
ttk::frame $combatcanvas.frame
SetScrollbarBindings $combatcanvas.frame $combatframe.left.scrolly
grid [ttk::label $combatcanvas.frame.name -text {Name}]
SetScrollbarBindings $combatcanvas.frame.name $combatframe.left.scrolly
grid [ttk::label $combatcanvas.frame.health -text {Health}] -row 0 -column 1
SetScrollbarBindings $combatcanvas.frame.health $combatframe.left.scrolly
grid [ttk::label $combatcanvas.frame.order -text {Order}] -row 0 -column 2
SetScrollbarBindings $combatcanvas.frame.order $combatframe.left.scrolly
$combatcanvas create window 0 0 -anchor nw -window $combatcanvas.frame
::autoscroll::autoscroll $combatframe.left.scrolly
::autoscroll::autoscroll $combatframe.left.scrollx
# Enemy defending party
grid [ttk::labelframe $combatframe.right -text {Enemy's crew:}] -row 0 \
   -column 1 -sticky nwes -rowspan 2 -padx 5 -pady 5
set combatcanvas [canvas $combatframe.right.canvas \
   -yscrollcommand [list $combatframe.right.scrolly set] \
   -xscrollcommand [list $combatframe.right.scrollx set]]
pack [ttk::scrollbar $combatframe.right.scrolly -orient vertical \
   -command [list $combatcanvas yview]] -side right -fill y
pack [ttk::scrollbar $combatframe.right.scrollx -orient horizontal \
   -command [list $combatcanvas xview]] -fill x -side bottom
pack $combatcanvas -side top -fill both -expand true
SetScrollbarBindings $combatcanvas $combatframe.right.scrolly
ttk::frame $combatcanvas.frame
SetScrollbarBindings $combatcanvas.frame $combatframe.right.scrolly
grid [ttk::label $combatcanvas.frame.name -text {Name}]
SetScrollbarBindings $combatcanvas.frame.name $combatframe.right.scrolly
grid [ttk::label $combatcanvas.frame.health -text {Health}] -row 0 -column 1
SetScrollbarBindings $combatcanvas.frame.health $combatframe.right.scrolly
grid [ttk::label $combatcanvas.frame.order -text {Order}] -row 0 -column 2
SetScrollbarBindings $combatcanvas.frame.order $combatframe.right.scrolly
$combatcanvas create window 0 0 -anchor nw -window $combatcanvas.frame
::autoscroll::autoscroll $combatframe.right.scrolly
::autoscroll::autoscroll $combatframe.right.scrollx
grid remove $combatframe.left
grid remove $combatframe.right

# Configure main combat grid
grid columnconfigure $combatframe 0 -weight 1
grid columnconfigure $combatframe 1 -weight 1
grid rowconfigure $combatframe 0 -weight 1
grid rowconfigure $combatframe 1 -weight 1
