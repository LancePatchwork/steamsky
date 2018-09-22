--    Copyright 2017-2018 Bartek thindil Jasicki
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

with Ada.Containers.Vectors; use Ada.Containers;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Crew; use Crew;

package Statistics is

   type Statistics_Data is -- Data for finished goals, destroyed ships and killed mobs
   record
      Index: Unbounded_String; -- Index of goal or ship name or name of fraction of killed mobs
      Amount: Positive; -- Amount of finished goals or ships or mobs of that type
   end record;
   package Statistics_Container is new Vectors(Positive, Statistics_Data);
   type GameStats_Data is -- Data for game statistics
   record
      DestroyedShips: Statistics_Container
        .Vector; -- Data for all destroyed ships by player
      BasesVisited: Positive; -- Amount of visited bases
      MapVisited: Positive; -- Amount of visited map fields
      DistanceTraveled: Natural; -- Amount of map fields travelled
      CraftingOrders: Statistics_Container
        .Vector; -- Data for finished crafting orders
      AcceptedMissions: Natural; -- Amount of accepted missions
      FinishedMissions: Statistics_Container
        .Vector; -- Data for all finished missions
      FinishedGoals: Statistics_Container
        .Vector; -- Data for all finished goals
      KilledMobs: Statistics_Container
        .Vector; -- Data for all mobs killed by player
      Points: Natural; -- Amount of gained points
   end record;
   GameStats: GameStats_Data; -- Game statistics

   procedure UpdateDestroyedShips
     (ShipName: Unbounded_String); -- Add new destroyed ship to list
   procedure ClearGameStats; -- Clear game statistics
   procedure UpdateFinishedGoals
     (Index: Unbounded_String); -- Add new finished goal to list
   procedure UpdateFinishedMissions
     (MType: Unbounded_String); -- Add new finished mission to list
   procedure UpdateCraftingOrders
     (Index: Unbounded_String); -- Add new finished crafting order to list
   procedure UpdateKilledMobs(Mob: Member_Data;
      FractionName: Unbounded_String); -- Add new killed mob to list

end Statistics;
