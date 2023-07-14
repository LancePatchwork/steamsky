-- Copyright (c) 2020-2022 Bartek thindil Jasicki <thindil@laeran.pl>
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

-- ****h* SUI2/SUCrew
-- FUNCTION
-- Provide code to show information about the player ship crew members
-- SOURCE
package Ships.UI.Crew is
-- ****

   -- ****f* SUCrew/SUCrew.Update_Crew_Info
   -- FUNCTION
   -- Update information about the player ship crew members
   -- PARAMETERS
   -- Page  - The number of current page of crew list to show
   -- Skill - The index of skill with which the crew members will be show
   -- SOURCE
   procedure Update_Crew_Info(Page: Positive := 1; Skill: Natural := 0);
   -- ****

   -- ****f* SUCrew/SUCrew.Add_Commands
   -- FUNCTION
   -- Add Tcl commands related to the player's ship crew members information
   -- SOURCE
   procedure Add_Crew_Commands;
   -- ****

end Ships.UI.Crew;
