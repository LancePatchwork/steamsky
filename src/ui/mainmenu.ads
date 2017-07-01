--    Copyright 2016-2017 Bartek thindil Jasicki
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

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with Terminal_Interface.Curses; use Terminal_Interface.Curses;
with Game; use Game;

package MainMenu is

   DocDirectory: Unbounded_String :=
     To_Unbounded_String
       ("doc" & Dir_Separator); -- Path to directory where documentation is

   procedure ShowMainMenu; -- Show main game menu
   procedure ShowNewGameForm
     (CurrentField: Positive := 2); -- Show new game setting form
   function MainMenuKeys
     (Key: Key_Code) return GameStates; -- Handle keys on main menu
   function NewGameKeys
     (Key: Key_Code) return GameStates; -- Handle keys in new game window
   function LicenseKeys
     (Key: Key_Code) return GameStates; -- Handle keys on license screen
   function FullLicenseKeys
     (Key: Key_Code) return GameStates; -- Handle keys on full license screen
   function NewsKeys
     (Key: Key_Code) return GameStates; -- Handle keys on news screen
   function HallOfFameKeys
     (Key: Key_Code) return GameStates; -- Handle keys on hall of fame screen

end MainMenu;
