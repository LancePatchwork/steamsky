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

with Goals; use Goals;
with Ships; use Ships;

package body Statistics is

   procedure UpdateDestroyedShips(ShipName: Unbounded_String) is
      Updated: Boolean := False;
      ShipIndex: Unbounded_String;
   begin
      for ProtoShip of ProtoShips_List loop
         if ProtoShip.Name = ShipName then
            ShipIndex := ProtoShip.Index;
            GameStats.Points :=
              GameStats.Points + (ProtoShip.CombatValue / 10);
            exit;
         end if;
      end loop;
      for DestroyedShip of GameStats.DestroyedShips loop
         if DestroyedShip.Index = ShipIndex then
            DestroyedShip.Amount := DestroyedShip.Amount + 1;
            Updated := True;
            exit;
         end if;
      end loop;
      if not Updated then
         GameStats.DestroyedShips.Append
         (New_Item => (Index => ShipIndex, Amount => 1));
      end if;
   end UpdateDestroyedShips;

   procedure ClearGameStats is
   begin
      GameStats.DestroyedShips.Clear;
      GameStats.BasesVisited := 1;
      GameStats.MapVisited := 1;
      GameStats.DistanceTraveled := 0;
      GameStats.CraftingOrders.Clear;
      GameStats.AcceptedMissions := 0;
      GameStats.FinishedMissions.Clear;
      GameStats.FinishedGoals.Clear;
      GameStats.Points := 0;
   end ClearGameStats;

   procedure UpdateFinishedGoals(Index: Unbounded_String) is
      Updated: Boolean := False;
   begin
      for Goal of Goals_List loop
         if Goal.Index = Index then
            GameStats.Points :=
              GameStats.Points + (Goal.Amount * Goal.Multiplier);
            exit;
         end if;
      end loop;
      for FinishedGoal of GameStats.FinishedGoals loop
         if FinishedGoal.Index = Index then
            FinishedGoal.Amount := FinishedGoal.Amount + 1;
            Updated := True;
            exit;
         end if;
      end loop;
      if not Updated then
         for Goal of Goals_List loop
            if Goal.Index = Index then
               GameStats.FinishedGoals.Append
               (New_Item => (Index => Goal.Index, Amount => 1));
               exit;
            end if;
         end loop;
      end if;
   end UpdateFinishedGoals;

   procedure UpdateFinishedMissions(MType: Unbounded_String) is
      Updated: Boolean := False;
   begin
      for FinishedMission of GameStats.FinishedMissions loop
         if FinishedMission.Index = MType then
            FinishedMission.Amount := FinishedMission.Amount + 1;
            Updated := True;
            exit;
         end if;
      end loop;
      if not Updated then
         GameStats.FinishedMissions.Append
         (New_Item => (Index => MType, Amount => 1));
      end if;
      GameStats.Points := GameStats.Points + 50;
   end UpdateFinishedMissions;

   procedure UpdateCraftingOrders(Index: Unbounded_String) is
      Updated: Boolean := False;
   begin
      for CraftingOrder of GameStats.CraftingOrders loop
         if CraftingOrder.Index = Index then
            CraftingOrder.Amount := CraftingOrder.Amount + 1;
            Updated := True;
            exit;
         end if;
      end loop;
      if not Updated then
         GameStats.CraftingOrders.Append
         (New_Item => (Index => Index, Amount => 1));
      end if;
      GameStats.Points := GameStats.Points + 5;
   end UpdateCraftingOrders;

end Statistics;
