--    Copyright 2017-2023 Bartek thindil Jasicki
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

-- ****h* HallOfFame/HallOfFame
-- FUNCTION
-- Provide code to manipulate hall of fame data
-- SOURCE
package HallOfFame is
-- ****

   -- ****s* HallOfFame/HallOfFame.Hall_Of_Fame_Data
   -- FUNCTION
   -- Data structure for hall of fame
   -- PARAMETERS
   -- Name        - Name of player
   -- Points      - Amount of points earned
   -- Death_Reason - What caused player death
   -- SOURCE
   type Hall_Of_Fame_Data is record
      Name: Unbounded_String;
      Points: Natural := 0;
      Death_Reason: Unbounded_String;
   end record;
   -- ****

   -- ****d* HallOfFame/HallOfFame.Empty_Hall_Of_Fame_Entry
   -- FUNCTION
   -- Empty entry for Hall of Fame
   -- SOURCE
   Empty_Hall_Of_Fame_Entry: constant Hall_Of_Fame_Data :=
     (Name => Null_Unbounded_String, Points => 0,
      Death_Reason => Null_Unbounded_String);
   -- ****

   -- ****t* HallOfFame/HallOfFame.Hall_Of_Fame_List
   -- FUNCTION
   -- List of all entries in the hall of fame
   -- SOURCE
   type Hall_Of_Fame_List is array(1 .. 10) of Hall_Of_Fame_Data;
   -- ****

   -- ****d* HallOfFame/HallOfFameEmpty_Hall_Of_Fame
   -- FUNCTION
   -- Empty hall of fame list
   -- SOURCE
   Empty_Hall_Of_Fame: constant Hall_Of_Fame_List :=
     (others => Empty_Hall_Of_Fame_Entry);
   -- ****

   -- ****f* HallOfFame/HallOfFame.Load_Hall_Of_Fame
   -- FUNCTION
   -- Read hall of fame data from file
   -- SOURCE
   procedure Load_Hall_Of_Fame;
   -- ****

   -- ****f* HallOfFame/HallOfFame.Update_Hall_Of_Fame
   -- FUNCTION
   -- Check did new entry should enter hall of fame
   -- PARAMETERS
   -- Player_Name  - Name of player's character to add to the hall of fame
   -- Death_Reason - Reason of death of selected character
   -- SOURCE
   procedure Update_Hall_Of_Fame
     (Player_Name, Death_Reason: Unbounded_String) with
      Pre => Player_Name /= Null_Unbounded_String and
      Death_Reason /= Null_Unbounded_String;
      -- ****

-- Temporary code to interact with Nim

   function Get_Hof_From_Nim return Hall_Of_Fame_List;

end HallOfFame;
