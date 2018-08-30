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

with Ada.Exceptions; use Ada.Exceptions;
with Messages; use Messages;
with HallOfFame; use HallOfFame;
with ShipModules; use ShipModules;
with Ships.Cargo; use Ships.Cargo;
with Maps; use Maps;
with Events; use Events;
with Crew.Inventory; use Crew.Inventory;
with Utils; use Utils;
with Missions; use Missions;
with Factions; use Factions;

package body Ships.Crew is

   function GetSkillLevel
     (Member: Member_Data;
      SkillIndex: Positive) return Natural is
      SkillLevel: Integer := 0;
      type DamageFactor is digits 2 range 0.0 .. 1.0;
      Damage: DamageFactor := 0.0;
      BaseSkillLevel: Natural;
   begin
      for Skill of Member.Skills loop
         if Skill(1) = SkillIndex then
            BaseSkillLevel :=
              Skill(2) + Member.Attributes(Skills_List(Skill(1)).Attribute)(1);
            Damage := 1.0 - DamageFactor(Float(Member.Health) / 100.0);
            SkillLevel :=
              SkillLevel +
              (BaseSkillLevel -
               Integer(Float(BaseSkillLevel) * Float(Damage)));
            if Member.Thirst > 40 then
               Damage := 1.0 - DamageFactor(Float(Member.Thirst) / 100.0);
               SkillLevel :=
                 SkillLevel - (Integer(Float(BaseSkillLevel) * Float(Damage)));
            end if;
            if Member.Hunger > 80 then
               Damage := 1.0 - DamageFactor(Float(Member.Hunger) / 100.0);
               SkillLevel :=
                 SkillLevel - (Integer(Float(BaseSkillLevel) * Float(Damage)));
            end if;
            if Member.Morale(1) < 25 then
               Damage := DamageFactor(Float(Member.Morale(1)) / 100.0);
               SkillLevel :=
                 SkillLevel - (Integer(Float(BaseSkillLevel) * Float(Damage)));
            end if;
            if Member.Morale(1) > 90 then
               Damage := DamageFactor(Float(SkillLevel) / 100.0);
               SkillLevel :=
                 SkillLevel + (Integer(Float(BaseSkillLevel) * Float(Damage)));
               if SkillLevel > 100 then
                  SkillLevel := 100;
               end if;
            end if;
            if SkillLevel < 0 then
               SkillLevel := 0;
            end if;
            return SkillLevel;
         end if;
      end loop;
      return SkillLevel;
   end GetSkillLevel;

   procedure Death
     (MemberIndex: Positive;
      Reason: Unbounded_String;
      Ship: in out ShipRecord;
      CreateBody: Boolean := True) is
   begin
      if MemberIndex > 1 then
         if Ship = PlayerShip then
            AddMessage
              (To_String(Ship.Crew(MemberIndex).Name) &
               " died from " &
               To_String(Reason) &
               ".",
               CombatMessage,
               3);
         end if;
      else
         if Ship = PlayerShip then
            AddMessage
              ("You died from " & To_String(Reason) & ".",
               CombatMessage,
               3);
            PlayerShip.Crew(MemberIndex).Order := Rest;
            PlayerShip.Crew(MemberIndex).Health := 0;
            UpdateHallOfFame(PlayerShip.Crew(MemberIndex).Name, Reason);
            return;
         end if;
      end if;
      if CreateBody then
         Ship.Cargo.Append
         (New_Item =>
            (ProtoIndex => FindProtoItem(CorpseIndex),
             Amount => 1,
             Name =>
               Ship.Crew(MemberIndex).Name & To_Unbounded_String("'s corpse"),
             Durability => 100));
      end if;
      DeleteMember(MemberIndex, Ship);
      for I in Ship.Crew.Iterate loop
         UpdateMorale(Ship, Crew_Container.To_Index(I), GetRandom(-25, -10));
      end loop;
   end Death;

   procedure DeleteMember(MemberIndex: Positive; Ship: in out ShipRecord) is
   begin
      Ship.Crew.Delete(Index => MemberIndex);
      for Module of Ship.Modules loop
         if Module.Owner = MemberIndex then
            Module.Owner := 0;
         elsif Module.Owner > MemberIndex then
            Module.Owner := Module.Owner - 1;
         end if;
      end loop;
      if Ship = PlayerShip then
         for I in
           AcceptedMissions.First_Index .. AcceptedMissions.Last_Index loop
            if AcceptedMissions(I).MType = Passenger and
              AcceptedMissions(I).Target = MemberIndex then
               DeleteMission(I);
               exit;
            end if;
         end loop;
         for Mission of AcceptedMissions loop
            if Mission.MType = Passenger and Mission.Target > MemberIndex then
               Mission.Target := Mission.Target - 1;
            end if;
         end loop;
      end if;
   end DeleteMember;

   function FindMember
     (Order: Crew_Orders;
      Crew: Crew_Container.Vector := PlayerShip.Crew) return Natural is
   begin
      for I in Crew.Iterate loop
         if Crew(I).Order = Order then
            return Crew_Container.To_Index(I);
         end if;
      end loop;
      return 0;
   end FindMember;

   procedure GiveOrders
     (Ship: in out ShipRecord;
      MemberIndex: Positive;
      GivenOrder: Crew_Orders;
      ModuleIndex: Natural := 0;
      CheckPriorities: Boolean := True) is
      MemberName: constant String := To_String(Ship.Crew(MemberIndex).Name);
      ModuleIndex2, ToolsIndex: Natural := 0;
      MType: ModuleType := ENGINE;
      RequiredTool: Unbounded_String;
   begin
      if GivenOrder = Ship.Crew(MemberIndex).Order then
         if GivenOrder = Craft or GivenOrder = Gunner then
            for I in Ship.Modules.Iterate loop
               if Ship.Modules(I).Owner = MemberIndex and
                 Modules_Container.To_Index(I) = ModuleIndex then
                  return;
               end if;
            end loop;
         else
            return;
         end if;
      end if;
      if GivenOrder /= Rest and
        ((Ship.Crew(MemberIndex).Morale(1) < 11 and GetRandom(1, 100) < 50) or
         Ship.Crew(MemberIndex).Loyalty < 20) then
         raise Crew_Order_Error with MemberName & " refuses to execute order.";
      end if;
      if GivenOrder = Upgrading or
        GivenOrder = Repair or
        GivenOrder = Clean then -- Check for tools
         if GivenOrder = Clean then
            RequiredTool := CleaningTools;
         else
            RequiredTool := RepairTools;
         end if;
         ToolsIndex := Ship.Crew(MemberIndex).Equipment(7);
         if ToolsIndex > 0 then
            if Items_List
                (Ship.Crew(MemberIndex).Inventory(ToolsIndex).ProtoIndex)
                .IType /=
              RequiredTool then
               ToolsIndex := 0;
            end if;
         end if;
         if ToolsIndex = 0 then
            ToolsIndex :=
              FindItem(Inventory => Ship.Cargo, ItemType => RequiredTool);
            if ToolsIndex = 0 then
               ToolsIndex :=
                 FindItem
                   (Inventory => Ship.Crew(MemberIndex).Inventory,
                    ItemType => RequiredTool);
               if ToolsIndex > 0 then
                  Ship.Crew(MemberIndex).Equipment(7) := ToolsIndex;
               end if;
            else
               Ship.Crew(MemberIndex).Equipment(7) := 0;
            end if;
         end if;
         if ToolsIndex = 0 then
            case GivenOrder is
               when Repair =>
                  raise Crew_Order_Error
                    with MemberName &
                    " can't starts repairing ship because you don't have repair tools.";
               when Clean =>
                  raise Crew_Order_Error
                    with MemberName &
                    " can't starts cleaning ship because you don't have any cleaning tools.";
               when Upgrading =>
                  raise Crew_Order_Error
                    with MemberName &
                    " can't starts upgrading module because you don't have repair tools.";
               when others =>
                  return;
            end case;
         end if;
      end if;
      if GivenOrder = Train then
         if Ship.Modules(ModuleIndex).Data(1) = 0 then
            raise Crew_Order_Error
              with MemberName &
              " can't starts training because " &
              To_String(Ship.Modules(ModuleIndex).Name) &
              " isn't prepared.";
         end if;
      end if;
      if GivenOrder = Pilot or
        GivenOrder = Engineer or
        GivenOrder = Upgrading or
        GivenOrder = Talk then
         for I in Ship.Crew.First_Index .. Ship.Crew.Last_Index loop
            if Ship.Crew(I).Order = GivenOrder then
               GiveOrders(PlayerShip, I, Rest, 0, False);
               exit;
            end if;
         end loop;
      elsif GivenOrder = Gunner or GivenOrder = Craft then
         if Ship.Modules(ModuleIndex).Owner > 0 then
            GiveOrders
              (PlayerShip,
               Ship.Modules(ModuleIndex).Owner,
               Rest,
               0,
               False);
         end if;
      end if;
      if ModuleIndex = 0 and
        (GivenOrder = Pilot or GivenOrder = Engineer or GivenOrder = Rest) then
         case GivenOrder is
            when Pilot =>
               MType := COCKPIT;
            when Engineer =>
               MType := ENGINE;
            when Rest =>
               MType := CABIN;
            when others =>
               null;
         end case;
         for I in Ship.Modules.Iterate loop
            if MType /= CABIN then
               if Modules_List(Ship.Modules(I).ProtoIndex).MType = MType and
                 Ship.Modules(I).Durability > 0 then
                  if Ship.Modules(I).Owner /= 0 then
                     GiveOrders
                       (PlayerShip,
                        Ship.Modules(I).Owner,
                        Rest,
                        0,
                        False);
                  end if;
                  ModuleIndex2 := Modules_Container.To_Index(I);
                  exit;
               end if;
            else
               if Modules_List(Ship.Modules(I).ProtoIndex).MType = CABIN and
                 Ship.Modules(I).Durability > 0 and
                 Ship.Modules(I).Owner = MemberIndex then
                  ModuleIndex2 := Modules_Container.To_Index(I);
                  exit;
               end if;
            end if;
         end loop;
      else
         ModuleIndex2 := ModuleIndex;
      end if;
      if ModuleIndex2 = 0 and Ship = PlayerShip then
         case GivenOrder is
            when Pilot =>
               raise Crew_Order_Error
                 with MemberName &
                 " can't starts piloting because cockpit is destroyed or you don't have cockpit.";
            when Engineer =>
               raise Crew_Order_Error
                 with MemberName &
                 " can't starts engineers duty because all engines are destroyed or you don't have engine.";
            when Gunner =>
               raise Crew_Order_Error
                 with MemberName &
                 " can't starts operating gun because all guns are destroyed or you don't have installed any.";
            when Rest =>
               for Module of Ship.Modules loop
                  if Modules_List(Module.ProtoIndex).MType = CABIN and
                    Module.Durability > 0 and
                    Module.Owner = 0 then
                     Module.Owner := MemberIndex;
                     AddMessage
                       (MemberName &
                        " take " &
                        To_String(Module.Name) &
                        " as own cabin.",
                        OtherMessage);
                     exit;
                  end if;
               end loop;
            when others =>
               null;
         end case;
      end if;
      for Module of Ship.Modules loop
         if Modules_List(Module.ProtoIndex).MType /= CABIN and
           Module.Owner = MemberIndex then
            Module.Owner := 0;
            exit;
         end if;
      end loop;
      if ToolsIndex > 0 and
        Ship.Crew(MemberIndex).Equipment(7) /= ToolsIndex then
         UpdateInventory
           (MemberIndex,
            1,
            Ship.Cargo(ToolsIndex).ProtoIndex,
            Ship.Cargo(ToolsIndex).Durability);
         UpdateCargo(Ship => Ship, Amount => -1, CargoIndex => ToolsIndex);
         Ship.Crew(MemberIndex).Equipment(7) :=
           FindItem
             (Inventory => Ship.Crew(MemberIndex).Inventory,
              ItemType => RequiredTool);
      end if;
      if GivenOrder = Rest then
         Ship.Crew(MemberIndex).PreviousOrder := Rest;
         if Ship.Crew(MemberIndex).Order = Repair or
           Ship.Crew(MemberIndex).Order = Clean or
           Ship.Crew(MemberIndex).Order = Upgrading then
            ToolsIndex := Ship.Crew(MemberIndex).Equipment(7);
            if ToolsIndex > 0 then
               TakeOffItem(MemberIndex, ToolsIndex);
               UpdateCargo
                 (Ship,
                  Ship.Crew(MemberIndex).Inventory(ToolsIndex).ProtoIndex,
                  1,
                  Ship.Crew(MemberIndex).Inventory(ToolsIndex).Durability);
               UpdateInventory
                 (MemberIndex => MemberIndex,
                  Amount => -1,
                  InventoryIndex => ToolsIndex);
            end if;
         end if;
      end if;
      if Ship = PlayerShip then
         case GivenOrder is
            when Pilot =>
               AddMessage(MemberName & " starts piloting.", OrderMessage);
               Ship.Modules(ModuleIndex2).Owner := MemberIndex;
            when Engineer =>
               AddMessage
                 (MemberName & " starts engineers duty.",
                  OrderMessage);
            when Gunner =>
               AddMessage(MemberName & " starts operating gun.", OrderMessage);
               Ship.Modules(ModuleIndex2).Owner := MemberIndex;
            when Rest =>
               AddMessage(MemberName & " going on break.", OrderMessage);
            when Repair =>
               AddMessage(MemberName & " starts repair ship.", OrderMessage);
            when Craft =>
               AddMessage(MemberName & " starts manufacturing.", OrderMessage);
               Ship.Modules(ModuleIndex2).Owner := MemberIndex;
            when Upgrading =>
               AddMessage
                 (MemberName &
                  " starts upgrading " &
                  To_String(Ship.Modules(Ship.UpgradeModule).Name) &
                  ".",
                  OrderMessage);
            when Talk =>
               AddMessage
                 (MemberName & " was assigned to talking in bases.",
                  OrderMessage);
            when Heal =>
               AddMessage
                 (MemberName & " starts healing wounded crew members.",
                  OrderMessage);
            when Clean =>
               AddMessage(MemberName & " starts cleaning ship.", OrderMessage);
            when Boarding =>
               AddMessage
                 (MemberName & " starts boarding enemy ship.",
                  OrderMessage);
            when Defend =>
               AddMessage
                 (MemberName & " starts defending ship.",
                  OrderMessage);
            when Train =>
               AddMessage
                 (MemberName & " starts personal training.",
                  OrderMessage);
               Ship.Modules(ModuleIndex2).Owner := MemberIndex;
         end case;
      end if;
      Ship.Crew(MemberIndex).Order := GivenOrder;
      Ship.Crew(MemberIndex).OrderTime := 15;
      if GivenOrder /= Rest then
         UpdateMorale(Ship, MemberIndex, -1);
      end if;
      if CheckPriorities then
         UpdateOrders(Ship);
      end if;
   exception
      when An_Exception : Crew_No_Space_Error =>
         if Ship = PlayerShip then
            raise Crew_Order_Error with Exception_Message(An_Exception);
         else
            return;
         end if;
   end GiveOrders;

   procedure UpdateOrders(Ship: in out ShipRecord; Combat: Boolean := False) is
      HavePilot,
      HaveEngineer,
      HaveUpgrade,
      HaveTrader,
      NeedClean,
      NeedRepairs,
      NeedGunners,
      NeedCrafters,
      NeedHealer,
      CanHeal,
      NeedTrader: Boolean :=
        False;
      EventIndex: constant Natural := SkyMap(Ship.SkyX, Ship.SkyY).EventIndex;
      function UpdatePosition
        (Order: Crew_Orders;
         MaxPriority: Boolean := True) return Boolean is
         ModuleIndex, MemberIndex, OrderIndex: Natural := 0;
      begin
         if Crew_Orders'Pos(Order) < Crew_Orders'Pos(Defend) then
            OrderIndex := Crew_Orders'Pos(Order) + 1;
         else
            OrderIndex := Crew_Orders'Pos(Order);
         end if;
         if MaxPriority then
            for I in Ship.Crew.Iterate loop
               if Ship.Crew(I).Orders(OrderIndex) = 2 and
                 Ship.Crew(I).Order /= Order and
                 Ship.Crew(I).PreviousOrder /= Order then
                  MemberIndex := Crew_Container.To_Index(I);
                  exit;
               end if;
            end loop;
         else
            for I in Ship.Crew.Iterate loop
               if Ship.Crew(I).Orders(OrderIndex) = 1 and
                 Ship.Crew(I).Order = Rest and
                 Ship.Crew(I).PreviousOrder = Rest then
                  MemberIndex := Crew_Container.To_Index(I);
                  exit;
               end if;
            end loop;
         end if;
         if MemberIndex = 0 then
            return False;
         end if;
         if Order = Gunner or Order = Craft or Order = Heal then
            for I in Ship.Modules.Iterate loop
               case Modules_List(Ship.Modules(I).ProtoIndex).MType is
                  when GUN =>
                     if Order = Gunner and
                       Ship.Modules(I).Owner = 0 and
                       Ship.Modules(I).Durability > 0 then
                        ModuleIndex := Modules_Container.To_Index(I);
                        exit;
                     end if;
                  when ALCHEMY_LAB .. GREENHOUSE =>
                     if Order = Craft and
                       Ship.Modules(I).Owner = 0 and
                       Ship.Modules(I).Durability > 0 and
                       Ship.Modules(I).Data(1) /= 0 then
                        ModuleIndex := Modules_Container.To_Index(I);
                        exit;
                     end if;
                  when MEDICAL_ROOM =>
                     if Order = Heal and
                       Ship.Modules(I).Owner = 0 and
                       Ship.Modules(I).Durability > 0 then
                        ModuleIndex := Modules_Container.To_Index(I);
                        exit;
                     end if;
                  when others =>
                     null;
               end case;
            end loop;
            if ModuleIndex = 0 then
               return False;
            end if;
         elsif Order = Pilot or Order = Engineer then
            for I in Ship.Modules.Iterate loop
               case Modules_List(Ship.Modules(I).ProtoIndex).MType is
                  when COCKPIT =>
                     if Order = Pilot and Ship.Modules(I).Durability > 0 then
                        ModuleIndex := Modules_Container.To_Index(I);
                        exit;
                     end if;
                  when ENGINE =>
                     if Order = Engineer and
                       Ship.Modules(I).Durability > 0 then
                        ModuleIndex := Modules_Container.To_Index(I);
                        exit;
                     end if;
                  when others =>
                     null;
               end case;
            end loop;
            if ModuleIndex = 0 then
               return False;
            end if;
         end if;
         if Ship.Crew(MemberIndex).Order /= Rest then
            GiveOrders(Ship, MemberIndex, Rest, 0, False);
         end if;
         GiveOrders(Ship, MemberIndex, Order, ModuleIndex);
         return True;
      exception
         when An_Exception : Crew_Order_Error | Crew_No_Space_Error =>
            if Ship = PlayerShip then
               AddMessage(Exception_Message(An_Exception), OrderMessage, 3);
            end if;
            return False;
      end UpdatePosition;
   begin
      for Member of Ship.Crew loop
         case Member.Order is
            when Pilot =>
               HavePilot := True;
            when Engineer =>
               HaveEngineer := True;
            when Upgrading =>
               HaveUpgrade := True;
            when Talk =>
               HaveTrader := True;
            when others =>
               null;
         end case;
         if Member.Health < 100 then
            NeedHealer := True;
         end if;
      end loop;
      for Module of Ship.Modules loop
         case Modules_List(Module.ProtoIndex).MType is
            when GUN =>
               if Module.Owner = 0 and
                 Module.Durability > 0 and
                 not NeedGunners then
                  NeedGunners := True;
               end if;
            when ALCHEMY_LAB .. GREENHOUSE =>
               if Module.Data(1) /= 0 and
                 Module.Owner = 0 and
                 Module.Durability > 0 and
                 not NeedCrafters then
                  NeedCrafters := True;
               end if;
            when CABIN =>
               if Module.Data(1) < Module.Data(2) and
                 Module.Durability > 0 then
                  NeedClean := True;
               end if;
            when MEDICAL_ROOM =>
               if NeedHealer and
                 Module.Durability > 0 and
                 FindItem
                     (Inventory => Ship.Cargo,
                      ItemType => Factions_List(PlayerFaction).HealingTools) >
                   0 then
                  CanHeal := True;
               end if;
            when others =>
               null;
         end case;
         if Module.Durability < Module.MaxDurability and not NeedRepairs then
            for Item of Ship.Cargo loop
               if Items_List(Item.ProtoIndex).IType =
                 Modules_List(Module.ProtoIndex).RepairMaterial then
                  NeedRepairs := True;
                  exit;
               end if;
            end loop;
         end if;
      end loop;
      if SkyMap(Ship.SkyX, Ship.SkyY).BaseIndex > 0 then
         NeedTrader := True;
      end if;
      if not NeedTrader and EventIndex > 0 then
         if Events_List(EventIndex).EType = Trader or
           Events_List(EventIndex).EType = FriendlyShip then
            NeedTrader := True;
         end if;
      end if;
      if not HavePilot then
         if UpdatePosition(Pilot) then
            UpdateOrders(Ship);
         end if;
      end if;
      if not HaveEngineer then
         if UpdatePosition(Engineer) then
            UpdateOrders(Ship);
         end if;
      end if;
      if NeedGunners then
         if UpdatePosition(Gunner) then
            UpdateOrders(Ship);
         end if;
      end if;
      if NeedCrafters then
         if UpdatePosition(Craft) then
            UpdateOrders(Ship);
         end if;
      end if;
      if not HaveUpgrade and
        Ship.UpgradeModule > 0 and
        FindItem(Inventory => Ship.Cargo, ItemType => RepairTools) > 0 then
         if FindItem
             (Inventory => Ship.Cargo,
              ItemType =>
                Modules_List(Ship.Modules(Ship.UpgradeModule).ProtoIndex)
                  .RepairMaterial) >
           0 then
            if UpdatePosition(Upgrading) then
               UpdateOrders(Ship);
            end if;
         end if;
      end if;
      if not HaveTrader and NeedTrader then
         if UpdatePosition(Talk) then
            UpdateOrders(Ship);
         end if;
      end if;
      if NeedClean and
        FindItem(Inventory => Ship.Cargo, ItemType => CleaningTools) > 0 then
         if UpdatePosition(Clean) then
            UpdateOrders(Ship);
         end if;
      end if;
      if CanHeal then
         if UpdatePosition(Heal) then
            UpdateOrders(Ship);
         end if;
      end if;
      if NeedRepairs and
        FindItem(Inventory => Ship.Cargo, ItemType => RepairTools) > 0 then
         if UpdatePosition(Repair) then
            UpdateOrders(Ship);
         end if;
      end if;
      if Combat then
         if UpdatePosition(Defend) then
            UpdateOrders(Ship);
         end if;
         if UpdatePosition(Boarding) then
            UpdateOrders(Ship);
         end if;
      end if;
      if not HavePilot then
         if UpdatePosition(Pilot, False) then
            UpdateOrders(Ship);
         end if;
      end if;
      if not HaveEngineer then
         if UpdatePosition(Engineer, False) then
            UpdateOrders(Ship);
         end if;
      end if;
      if NeedGunners then
         if UpdatePosition(Gunner, False) then
            UpdateOrders(Ship);
         end if;
      end if;
      if NeedCrafters then
         if UpdatePosition(Craft, False) then
            UpdateOrders(Ship);
         end if;
      end if;
      if not HaveUpgrade and
        Ship.UpgradeModule > 0 and
        FindItem(Inventory => Ship.Cargo, ItemType => RepairTools) > 0 then
         if FindItem
             (Inventory => Ship.Cargo,
              ItemType =>
                Modules_List(Ship.Modules(Ship.UpgradeModule).ProtoIndex)
                  .RepairMaterial) >
           0 then
            if UpdatePosition(Upgrading, False) then
               UpdateOrders(Ship);
            end if;
         end if;
      end if;
      if not HaveTrader and SkyMap(Ship.SkyX, Ship.SkyY).BaseIndex > 0 then
         if UpdatePosition(Talk, False) then
            UpdateOrders(Ship);
         end if;
      end if;
      if NeedClean and
        FindItem(Inventory => Ship.Cargo, ItemType => CleaningTools) > 0 then
         if UpdatePosition(Clean, False) then
            UpdateOrders(Ship);
         end if;
      end if;
      if CanHeal then
         if UpdatePosition(Heal, False) then
            UpdateOrders(Ship);
         end if;
      end if;
      if NeedRepairs and
        FindItem(Inventory => Ship.Cargo, ItemType => RepairTools) > 0 then
         if UpdatePosition(Repair, False) then
            UpdateOrders(Ship);
         end if;
      end if;
      if Combat then
         if UpdatePosition(Defend, False) then
            UpdateOrders(Ship);
         end if;
         if UpdatePosition(Boarding, False) then
            UpdateOrders(Ship);
         end if;
      end if;
   end UpdateOrders;

   procedure UpdateMorale
     (Ship: in out ShipRecord;
      MemberIndex: Positive;
      Value: Integer) is
      NewMorale, NewLoyalty, NewValue: Integer;
      FactionIndex: Positive;
   begin
      if Ship = PlayerShip then
         FactionIndex := PlayerFaction;
      else
         for ProtoShip of ProtoShips_List loop
            if ProtoShip.Name = Ship.Name then
               FactionIndex := ProtoShip.Owner;
               exit;
            end if;
         end loop;
      end if;
      if Factions_List(FactionIndex).Flags.Contains
        (To_Unbounded_String("nomorale")) then
         return;
      end if;
      NewValue := Ship.Crew(MemberIndex).Morale(2) + Value;
      NewMorale := Ship.Crew(MemberIndex).Morale(1);
      while NewValue >= (NewMorale * 5) loop
         NewValue := NewValue - (NewMorale * 5);
         NewMorale := NewMorale + 1;
      end loop;
      while NewValue < 0 loop
         NewValue := NewValue + (NewMorale * 5);
         NewMorale := NewMorale - 1;
      end loop;
      if NewMorale > 100 then
         NewMorale := 100;
      elsif NewMorale < 0 then
         NewMorale := 0;
      end if;
      Ship.Crew(MemberIndex).Morale := (NewMorale, NewValue);
      if Ship = PlayerShip and MemberIndex = 1 then
         return;
      end if;
      NewLoyalty := Ship.Crew(MemberIndex).Loyalty;
      if NewMorale > 75 and NewLoyalty < 100 then
         NewLoyalty := NewLoyalty + 1;
      end if;
      if NewMorale < 25 and NewLoyalty > 0 then
         NewLoyalty := NewLoyalty - GetRandom(5, 10);
      end if;
      if NewLoyalty > 100 then
         NewLoyalty := 100;
      elsif NewLoyalty < 0 then
         NewLoyalty := 0;
      end if;
      Ship.Crew(MemberIndex).Loyalty := NewLoyalty;
   end UpdateMorale;

end Ships.Crew;
