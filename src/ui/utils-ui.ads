--    Copyright 2018 Bartek thindil Jasicki
--
--    This file is part of Steam Sky.
--
--    Steam Sky is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    Steam Sky is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    You should have received a copy of the GNU General Public License
--    along with Steam Sky.  If not, see <http://www.gnu.org/licenses/>.

with Gtk.Window; use Gtk.Window;
with Glib.Object; use Glib.Object;

package Utils.UI is

   type GameStates is (SkyMap_View, Combat_View); -- Game states

   procedure ShowDialog
     (Message: String;
      Parent: Gtk_Window); -- Show dialog with info
   function HideWindow
     (User_Data: access GObject_Record'Class)
     return Boolean; -- Hide window instead of destroying it
   procedure ShowWindow
     (User_Data: access GObject_Record'Class); -- Show selected window
   function ShowConfirmDialog
     (Message: String;
      Parent: Gtk_Window)
     return Boolean; -- Show confirmation dialog to player, return True, if player choice 'Yes' option
   function QuitGame
     (User_Data: access GObject_Record'Class)
     return Boolean; -- Save and quit from game

end Utils.UI;
