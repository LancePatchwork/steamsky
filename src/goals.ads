--    Copyright 2017 Bartek thindil Jasicki
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

package Goals is

   type GoalTypes is
     (RANDOM, REPUTATION, KILL, DISCOVER, VISIT, CRAFT); -- Types of goals
   type Goal_Data is -- Data structure for each goal
   record
      Index: Unbounded_String; -- Index of goal
      GType: GoalTypes; -- Type of goal
      Amount: Natural; -- Amount of targets needed for finish goal
      TargetIndex: Unbounded_String; -- Index of target needed for finish goal. If empty, mean all targets selected type (bases, ships, etc)
   end record;
   package Goals_Container is new Vectors(Positive, Goal_Data);
   Goals_List: Goals_Container
     .Vector; -- List of player goals available in game
   CurrentGoal: Goal_Data; -- Player current goal
   Goals_Directory_Not_Found : exception; -- Raised when no directory with modules files
   Goals_Files_Not_Found : exception; -- Raised when no files with modules

   procedure LoadGoals; -- Load player goals from files
   function GoalText
     (Index: Natural)
     return String; -- return info about selected goal or current goal if Index = 0
   procedure UpdateGoal
     (GType: GoalTypes;
      Index: Unbounded_String); -- Update current goal

end Goals;
