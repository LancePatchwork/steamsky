-- Copyright (c) 2020-2024 Bartek thindil Jasicki
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

-- ****h* MainMenu/MainMenu
-- FUNCTION
-- Provide code for manipulate the game main menu
-- SOURCE
package MainMenu is
-- ****

   -- ****f* MainMenu/MainMenu.Create_Main_Menu
   -- FUNCTION
   -- Create main menu UI
   -- SOURCE
   procedure Create_Main_Menu;
   -- ****

   -- ****f* MainMenu/MainMenu.Show_Main_Menu
   -- FUNCTION
   -- Show main menu to a player
   -- SOURCE
   procedure Show_Main_Menu with
      Convention => C,
      Import => True,
      External_Name => "showAdaMainMenu";
   -- ****

end MainMenu;
