# Copyright (c) 2020-2024 Bartek thindil Jasicki
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

ttk::frame .gameframe.paned.shipyardframe
set shipyardcanvas [canvas .gameframe.paned.shipyardframe.canvas \
   -yscrollcommand [list .gameframe.paned.shipyardframe.scrolly set] \
   -xscrollcommand [list .gameframe.paned.shipyardframe.scrollx set]]
pack [ttk::scrollbar .gameframe.paned.shipyardframe.scrolly -orient vertical \
   -command [list $shipyardcanvas yview]] -side right -fill y
pack $shipyardcanvas -side top -fill both
SetScrollbarBindings $shipyardcanvas .gameframe.paned.shipyardframe.scrolly
pack [ttk::scrollbar .gameframe.paned.shipyardframe.scrollx -orient horizontal \
   -command [list $shipyardcanvas xview]] -fill x
::autoscroll::autoscroll .gameframe.paned.shipyardframe.scrolly
::autoscroll::autoscroll .gameframe.paned.shipyardframe.scrollx
set shipyardframe [ttk::frame $shipyardcanvas.shipyard]
SetScrollbarBindings $shipyardframe .gameframe.paned.shipyardframe.scrolly
set newtab install
grid [ttk::frame $shipyardframe.tabs] -pady 5
grid [ttk::radiobutton $shipyardframe.tabs.install -text {Install modules} \
   -state selected -style Radio.Toolbutton -value install -variable newtab \
   -command ShowShipyardTab] -padx 5
grid [ttk::radiobutton $shipyardframe.tabs.remove -text {Remove modules} \
   -style Radio.Toolbutton -value remove -variable newtab \
   -command ShowShipyardTab] -row 0 -column 1 -padx 5
grid [ttk::frame $shipyardframe.moneyinfo] -sticky w
grid [ttk::label $shipyardframe.moneyinfo.lblmoney -wraplength 500] -sticky w
grid [ttk::label $shipyardframe.moneyinfo.lblmoney2 -wraplength 500] -sticky w \
   -column 1 -row 0
grid [ttk::label $shipyardframe.moneyinfo.lblmodules -wraplength 500] -sticky w
grid [ttk::label $shipyardframe.moneyinfo.lblmodules2 -wraplength 500] -sticky w \
   -column 1 -row 1
# Install modules
set sinstall [ttk::frame $shipyardframe.install]
SetScrollbarBindings $sinstall .gameframe.paned.shipyardframe.scrolly
grid [ttk::frame $sinstall.options] -sticky we -pady {0 5}
SetScrollbarBindings $sinstall.options .gameframe.paned.shipyardframe.scrolly
grid [ttk::label $sinstall.options.label -text "Show modules:"]
SetScrollbarBindings $sinstall.options.label \
   .gameframe.paned.shipyardframe.scrolly
grid [ttk::combobox $sinstall.options.modules -state readonly \
   -values [list {Any} {Engines} {Cabins} {Cockpits} {Turrets} {Guns} \
   {Cargo bays} {Hulls} {Armors} {Battering rams} {Alchemy labs} {Furnaces} \
   {Water collectors} {Workshops} {Greenhouses} {Medical rooms} {Harpoon guns} \
   {Training rooms}]] -row 0 -column 1 -padx {0 5}
$sinstall.options.modules current 0
bind $sinstall.options.modules <<ComboboxSelected>> {
   ShowShipyard [$sinstall.options.modules current] \
      [$sinstall.options.search get]
}
grid [ttk::entry $sinstall.options.search -validate key \
   -validatecommand {ShowShipyard [$sinstall.options.modules current] %P}] \
   -row 0 -column 2
# Remove modules
set sremove [ttk::frame $shipyardframe.remove]
SetScrollbarBindings $sremove .gameframe.paned.shipyardframe.scrolly
