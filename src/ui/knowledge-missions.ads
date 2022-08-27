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

-- ****h* Knowledge/KMissions
-- FUNCTION
-- Provide code to show the list of known events to the player
-- SOURCE
package Knowledge.Missions is
-- ****

   -- ****f* KMissions/KMissions.Add_Commands
   -- FUNCTION
   -- Add Tcl commands related to the list of known bases
   -- SOURCE
   procedure Add_Commands;
   -- ****

   -- ****f* KMissions/KMissions.Update_Missions_List
   -- FUNCTION
   -- Update and show list of accepted missions
   -- PARAMETERS
   -- Page     - The current page of missions list to show
   -- SOURCE
   procedure Update_Missions_List(Page: Positive := 1);
   -- ****

end Knowledge.Missions;
