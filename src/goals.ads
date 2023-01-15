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
with Ada.Containers.Vectors; use Ada.Containers;
with DOM.Readers; use DOM.Readers;

-- ****h* Goals/Goals
-- FUNCTION
-- Provide code for manipulate goals
-- SOURCE
package Goals is
-- ****

   -- ****t* Goals/Goals.GoalTypes
   -- FUNCTION
   -- Types of goals
   -- SOURCE
   type Goal_Types is
     (RANDOM, REPUTATION, DESTROY, DISCOVER, VISIT, CRAFT, MISSION, KILL) with
      Default_Value => RANDOM;
      -- ****

      -- ****d* Goals/Goals.Default_Goal_Type
      -- FUNCTION
      -- Default goal type, random type
      -- SOURCE
   Default_Goal_Type: constant Goal_Types := RANDOM;
   -- ****

   -- ****s* Goals/Goals.Goal_Data
   -- FUNCTION
   -- Data structure for each goal
   -- PARAMETERS
   -- Index        - Index of goal
   -- G_Type       - Type of goal
   -- Amount       - Amount of targets needed for finish goal
   -- Target_Index - Index of target needed for finish goal. If empty, mean all
   --                targets selected type (bases, ships, etc)
   -- Multiplie r  - Multiplier for points awarded for finish this goal
   -- SOURCE
   type Goal_Data is record
      Index: Unbounded_String;
      G_Type: Goal_Types;
      Amount: Natural;
      Target_Index: Unbounded_String;
      Multiplier: Positive;
   end record;
   -- ****

   -- ****d* Goals/Goals.Empty_Goal
   -- FUNCTION
   -- Default value for Goal_Data, an empty goal data
   -- SOURCE
   Empty_Goal: constant Goal_Data := (others => <>);
   -- ****

   -- ****t* Goals/Goals.Goals_Container
   -- FUNCTION
   -- Used to store goals data
   -- SOURCE
   package Goals_Container is new Vectors
     (Index_Type => Positive, Element_Type => Goal_Data);
   -- ****

   -- ****v* Goals/Goals.Goals_List
   -- FUNCTION
   -- List of player goals available in game
   -- SOURCE
   Goals_List: Goals_Container.Vector;
   -- ****

   -- ****v* Goals/Goals.Current_Goal
   -- FUNCTION
   -- Player current goal
   -- SOURCE
   Current_Goal: Goal_Data;
   -- ****

   -- ****f* Goals/Goals.Load_Goals
   -- FUNCTION
   -- Load player goals from files
   -- FUNCTION
   -- Reader - XML Reader from which goals data will be read
   -- SOURCE
   procedure Load_Goals(Reader: Tree_Reader);
   -- ****

   -- ****f* Goals/Goals.Goal_Text
   -- FUNCTION
   -- Get info about selected goal
   -- PARAMETERS
   -- Index - Index of goal from which we take info. If 0 then get info for
   --         current goal
   -- RESULT
   -- Info about selected goal
   -- SOURCE
   function Goal_Text(Index: Goals_Container.Extended_Index) return String with
      Pre => Index <= Goals_List.Last_Index,
      Post => Goal_Text'Result'Length > 0,
      Test_Case => (Name => "Test_GoalText", Mode => Nominal);
      -- ****

      -- ****f* Goals/Goals.Clear_Current_Goal
      -- FUNCTION
      -- Reset current goal
      -- SOURCE
   procedure Clear_Current_Goal with
      Post => Current_Goal.Index = Null_Unbounded_String,
      Test_Case => (Name => "Test_ClearCurrentGoal", Mode => Nominal);
      -- ****

      -- ****f* Goals/Goals.Update_Goal
      -- FUNCTION
      -- Update current goal
      -- PARAMETERS
      -- G_Type       - Type of goal to check
      -- Target_Index - Index of target to check
      -- Amount       - Amount for goal to modify if both checks are valid
      -- SOURCE
   procedure Update_Goal
     (G_Type: Goal_Types; Target_Index: Unbounded_String;
      Amount: Positive := 1) with
      Test_Case => (Name => "Test_UpdateGoal", Mode => Nominal);
      -- ****

end Goals;
