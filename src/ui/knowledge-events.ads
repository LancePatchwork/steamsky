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

-- ****h* Knowledge/KEvents
-- FUNCTION
-- Provide code to show the list of known events to the player
-- SOURCE
package Knowledge.Events is
-- ****

   -- ****f* KEvents/KEvents.Add_Knowledge_Events_Commands
   -- FUNCTION
   -- Add Tcl commands related to the list of known bases
   -- SOURCE
   procedure Add_Knowledge_Events_Commands;
   -- ****

   -- ****f* KEvents/KEvents.Update_Events_List
   -- FUNCTION
   -- Update and show list of known events
   -- PARAMETERS
   -- Page     - The current page of events list to show
   -- SOURCE
   procedure Update_Events_List(Page: Positive := 1);
   -- ****

end Knowledge.Events;
