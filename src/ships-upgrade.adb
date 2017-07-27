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

with Messages; use Messages;
with Items; use Items;
with ShipModules; use ShipModules;
with Ships.Cargo; use Ships.Cargo;
with Ships.Crew; use Ships.Crew;

package body Ships.Upgrade is

   function StartUpgrading(ModuleIndex, UpgradeType: Positive) return String is
      MaxValue: Natural;
      HaveMaterials, HaveTools: Boolean := False;
      UpgradeProgress: Positive;
      UpgradeAction: ShipUpgrade;
   begin
      if PlayerShip.Modules(ModuleIndex).Durability = 0 and
        UpgradeType /= 3 then
         return "You can't upgrade " &
           To_String(PlayerShip.Modules(ModuleIndex).Name) &
           " because is destroyed.";
      end if;
      case UpgradeType is
         when 1 => -- Upgrade durability
            MaxValue :=
              Natural
                (Float
                   (Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex)
                      .Durability) *
                 1.5);
            if PlayerShip.Modules(ModuleIndex).MaxDurability = MaxValue then
               return "You can't improve more durability of " &
                 To_String(PlayerShip.Modules(ModuleIndex).Name) &
                 ".";
            end if;
            UpgradeAction := DURABILITY;
            UpgradeProgress := 10;
         when 2 => -- Upgrade various max value of selected module
            MaxValue :=
              Natural
                (Float
                   (Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex)
                      .MaxValue) *
                 1.5);
            case Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex)
              .MType is
               when ENGINE =>
                  if PlayerShip.Modules(ModuleIndex).Max_Value = MaxValue then
                     return "You can't improve more power of " &
                       To_String(PlayerShip.Modules(ModuleIndex).Name) &
                       ".";
                  end if;
                  UpgradeProgress := 10;
               when CABIN =>
                  if PlayerShip.Modules(ModuleIndex).Max_Value = MaxValue then
                     return "You can't improve more quality of " &
                       To_String(PlayerShip.Modules(ModuleIndex).Name) &
                       ".";
                  end if;
                  UpgradeProgress := 100;
               when GUN | BATTERING_RAM =>
                  if PlayerShip.Modules(ModuleIndex).Max_Value = MaxValue then
                     return "You can't improve more damage of " &
                       To_String(PlayerShip.Modules(ModuleIndex).Name) &
                       ".";
                  end if;
                  UpgradeProgress := 100;
               when HULL =>
                  if PlayerShip.Modules(ModuleIndex).Max_Value = MaxValue then
                     return "You can't enlarge more " &
                       To_String(PlayerShip.Modules(ModuleIndex).Name) &
                       ".";
                  end if;
                  UpgradeProgress := 500;
               when others =>
                  return To_String(PlayerShip.Modules(ModuleIndex).Name) &
                    " can't be upgraded in that way.";
            end case;
            UpgradeAction := MAX_VALUE;
         when 3 => -- Upgrade various value of selected module
            MaxValue :=
              Natural
                (Float
                   (Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex)
                      .Value) *
                 1.5);
            case Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex)
              .MType is
               when ENGINE =>
                  if PlayerShip.Modules(ModuleIndex).Current_Value =
                    MaxValue then
                     return "You can't reduce more fuel usage of " &
                       To_String(PlayerShip.Modules(ModuleIndex).Name) &
                       ".";
                  end if;
                  UpgradeProgress := 100;
               when others =>
                  return To_String(PlayerShip.Modules(ModuleIndex).Name) &
                    " can't be upgraded in that way.";
            end case;
            UpgradeAction := VALUE;
         when 4 => -- Continue previous upgrade
            if PlayerShip.Modules(ModuleIndex).UpgradeAction = NONE then
               return To_String(PlayerShip.Modules(ModuleIndex).Name) &
                 " don't have set any upgrade yet.";
            end if;
            UpgradeAction := PlayerShip.Modules(ModuleIndex).UpgradeAction;
         when others =>
            return "";
      end case;
      for Item of PlayerShip.Cargo loop
         if Items_List(Item.ProtoIndex).IType =
           Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex)
             .RepairMaterial then
            HaveMaterials := True;
         elsif Items_List(Item.ProtoIndex).IType = RepairTools then
            HaveTools := True;
         end if;
         exit when HaveMaterials and HaveTools;
      end loop;
      if not HaveMaterials then
         for Item of Items_List loop
            if Item.IType =
              Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex)
                .RepairMaterial then
               return "You don't have " &
                 To_String(Item.Name) &
                 " for upgrading " &
                 To_String(PlayerShip.Modules(ModuleIndex).Name) &
                 ".";
            end if;
         end loop;
      end if;
      if not HaveTools then
         return "You don't have repair tools for upgrading " &
           To_String(PlayerShip.Modules(ModuleIndex).Name) &
           ".";
      end if;
      PlayerShip.UpgradeModule := ModuleIndex;
      if PlayerShip.Modules(ModuleIndex).UpgradeAction /= UpgradeAction then
         PlayerShip.Modules(ModuleIndex).UpgradeProgress := UpgradeProgress;
         PlayerShip.Modules(ModuleIndex).UpgradeAction := UpgradeAction;
      end if;
      AddMessage
        ("You set " &
         To_String(PlayerShip.Modules(ModuleIndex).Name) &
         " to upgrade.",
         OrderMessage);
      return "";
   end StartUpgrading;

   procedure UpgradeShip(Minutes: Positive) is
      ResultAmount,
      UpgradePoints,
      WorkerIndex,
      UpgradeMaterial,
      UpgradeProgress,
      UpgradeTools: Natural :=
        0;
      MaxValue: Positive;
      WeightGain: Natural;
      Times: Natural := 0;
      OrderTime, CurrentMinutes: Integer;
      Message: Unbounded_String;
      procedure FindMatsAndTools is
      begin
         UpgradeMaterial := 0;
         UpgradeTools := 0;
         for I in PlayerShip.Cargo.Iterate loop
            if Items_List(PlayerShip.Cargo(I).ProtoIndex).IType =
              Modules_List
                (PlayerShip.Modules(PlayerShip.UpgradeModule).ProtoIndex)
                .RepairMaterial then
               UpgradeMaterial := Cargo_Container.To_Index(I);
            elsif Items_List(PlayerShip.Cargo(I).ProtoIndex).IType =
              RepairTools then
               UpgradeTools := Cargo_Container.To_Index(I);
            end if;
            exit when UpgradeMaterial > 0 and UpgradeTools > 0;
         end loop;
      end FindMatsAndTools;
      procedure MaxUpgradeReached(MessageText: String) is
      begin
         AddMessage
           (MessageText &
            To_String(PlayerShip.Modules(PlayerShip.UpgradeModule).Name) &
            ".",
            OrderMessage,
            1);
         PlayerShip.Modules(PlayerShip.UpgradeModule).UpgradeProgress := 0;
         PlayerShip.Modules(PlayerShip.UpgradeModule).UpgradeAction := NONE;
         PlayerShip.UpgradeModule := 0;
         Message := To_Unbounded_String(GiveOrders(WorkerIndex, Rest));
         if Length(Message) > 0 then
            AddMessage(To_String(Message), OrderMessage, 3);
         end if;
      end MaxUpgradeReached;
   begin
      WorkerIndex := FindMember(Upgrading);
      if WorkerIndex = 0 then
         return;
      end if;
      CurrentMinutes := Minutes;
      OrderTime := PlayerShip.Crew(WorkerIndex).OrderTime;
      if PlayerShip.Modules(PlayerShip.UpgradeModule).Durability = 0 then
         AddMessage
           (To_String(PlayerShip.Crew(WorkerIndex).Name) &
            " stops upgrading " &
            To_String(PlayerShip.Modules(PlayerShip.UpgradeModule).Name) &
            " because it is destroyed.",
            OrderMessage,
            3);
         Message := To_Unbounded_String(GiveOrders(WorkerIndex, Rest));
         if Length(Message) > 0 then
            AddMessage(To_String(Message), OrderMessage, 3);
         end if;
         return;
      end if;
      while CurrentMinutes > 0 loop
         if CurrentMinutes >= OrderTime then
            CurrentMinutes := CurrentMinutes - OrderTime;
            Times := Times + 1;
            OrderTime := 15;
         else
            OrderTime := OrderTime - CurrentMinutes;
            CurrentMinutes := 0;
         end if;
      end loop;
      PlayerShip.Crew(WorkerIndex).OrderTime := OrderTime;
      if Times = 0 then
         return;
      end if;
      UpgradePoints :=
        ((GetSkillLevel
            (WorkerIndex,
             Modules_List
               (PlayerShip.Modules(PlayerShip.UpgradeModule).ProtoIndex)
               .RepairSkill) /
          10) *
         Times) +
        Times;
      while UpgradePoints > 0 and
        PlayerShip.Modules(PlayerShip.UpgradeModule).UpgradeProgress > 0 loop
         ResultAmount := UpgradePoints;
         if ResultAmount >
           PlayerShip.Modules(PlayerShip.UpgradeModule).UpgradeProgress then
            ResultAmount :=
              PlayerShip.Modules(PlayerShip.UpgradeModule).UpgradeProgress;
         end if;
         FindMatsAndTools;
         if UpgradeMaterial = 0 then
            AddMessage
              ("You don't have enough materials to upgrade " &
               To_String(PlayerShip.Modules(PlayerShip.UpgradeModule).Name),
               OrderMessage,
               3);
            Message := To_Unbounded_String(GiveOrders(WorkerIndex, Rest));
            exit;
         end if;
         if UpgradeTools = 0 then
            AddMessage
              ("You don't have repair tools to upgrade " &
               To_String(PlayerShip.Modules(PlayerShip.UpgradeModule).Name),
               OrderMessage,
               3);
            Message := To_Unbounded_String(GiveOrders(WorkerIndex, Rest));
            exit;
         end if;
         if ResultAmount > PlayerShip.Cargo(UpgradeMaterial).Amount then
            ResultAmount := PlayerShip.Cargo(UpgradeMaterial).Amount;
         end if;
         GainExp
           (ResultAmount,
            Modules_List
              (PlayerShip.Modules(PlayerShip.UpgradeModule).ProtoIndex)
              .RepairSkill,
            WorkerIndex);
         DamageCargo
           (UpgradeTools,
            WorkerIndex,
            Modules_List
              (PlayerShip.Modules(PlayerShip.UpgradeModule).ProtoIndex)
              .RepairSkill);
         FindMatsAndTools;
         UpgradeProgress :=
           PlayerShip.Modules(PlayerShip.UpgradeModule).UpgradeProgress -
           ResultAmount;
         UpgradePoints := UpgradePoints - ResultAmount;
         UpdateCargo
           (PlayerShip,
            PlayerShip.Cargo.Element(UpgradeMaterial).ProtoIndex,
            (0 - ResultAmount));
         if UpgradeProgress = 0 then
            WeightGain :=
              Modules_List
                (PlayerShip.Modules(PlayerShip.UpgradeModule).ProtoIndex)
                .Weight /
              Modules_List
                (PlayerShip.Modules(PlayerShip.UpgradeModule).ProtoIndex)
                .Durability;
            if WeightGain < 1 then
               WeightGain := 1;
            end if;
            case PlayerShip.Modules(PlayerShip.UpgradeModule).UpgradeAction is
               when DURABILITY =>
                  PlayerShip.Modules(PlayerShip.UpgradeModule).MaxDurability :=
                    PlayerShip.Modules(PlayerShip.UpgradeModule)
                      .MaxDurability +
                    1;
                  PlayerShip.Modules(PlayerShip.UpgradeModule).Weight :=
                    PlayerShip.Modules(PlayerShip.UpgradeModule).Weight +
                    WeightGain;
                  AddMessage
                    (To_String(PlayerShip.Crew(WorkerIndex).Name) &
                     " was upgraded durability of " &
                     To_String
                       (PlayerShip.Modules(PlayerShip.UpgradeModule).Name) &
                     ".",
                     OrderMessage,
                     2);
                  MaxValue :=
                    Positive
                      (Float
                         (Modules_List
                            (PlayerShip.Modules(PlayerShip.UpgradeModule)
                               .ProtoIndex)
                            .Durability) *
                       1.5);
                  if PlayerShip.Modules(PlayerShip.UpgradeModule)
                      .MaxDurability =
                    MaxValue then
                     MaxUpgradeReached("You reached maximum durability for ");
                     return;
                  else
                     PlayerShip.Modules(PlayerShip.UpgradeModule)
                       .UpgradeProgress :=
                       10;
                  end if;
               when MAX_VALUE =>
                  PlayerShip.Modules(PlayerShip.UpgradeModule).Max_Value :=
                    PlayerShip.Modules(PlayerShip.UpgradeModule).Max_Value + 1;
                  case Modules_List
                    (PlayerShip.Modules(PlayerShip.UpgradeModule).ProtoIndex)
                    .MType is
                     when HULL =>
                        WeightGain := WeightGain * 10;
                     when ENGINE =>
                        WeightGain := 1;
                     when others =>
                        null;
                  end case;
                  PlayerShip.Modules(PlayerShip.UpgradeModule).Weight :=
                    PlayerShip.Modules(PlayerShip.UpgradeModule).Weight +
                    WeightGain;
                  AddMessage
                    (To_String(PlayerShip.Crew(WorkerIndex).Name) &
                     " was upgraded " &
                     To_String
                       (PlayerShip.Modules(PlayerShip.UpgradeModule).Name) &
                     ".",
                     OrderMessage,
                     2);
                  MaxValue :=
                    Positive
                      (Float
                         (Modules_List
                            (PlayerShip.Modules(PlayerShip.UpgradeModule)
                               .ProtoIndex)
                            .MaxValue) *
                       1.5);
                  if PlayerShip.Modules(PlayerShip.UpgradeModule).Max_Value =
                    MaxValue then
                     MaxUpgradeReached("You reached maximum upgrade for ");
                     return;
                  else
                     case Modules_List
                       (PlayerShip.Modules(PlayerShip.UpgradeModule)
                          .ProtoIndex)
                       .MType is
                        when ENGINE =>
                           PlayerShip.Modules(PlayerShip.UpgradeModule)
                             .UpgradeProgress :=
                             10;
                        when CABIN | GUN | BATTERING_RAM =>
                           PlayerShip.Modules(PlayerShip.UpgradeModule)
                             .UpgradeProgress :=
                             100;
                        when HULL =>
                           PlayerShip.Modules(PlayerShip.UpgradeModule)
                             .UpgradeProgress :=
                             500;
                        when others =>
                           null;
                     end case;
                  end if;
               when VALUE =>
                  PlayerShip.Modules(PlayerShip.UpgradeModule).Current_Value :=
                    PlayerShip.Modules(PlayerShip.UpgradeModule)
                      .Current_Value -
                    1;
                  case Modules_List
                    (PlayerShip.Modules(PlayerShip.UpgradeModule).ProtoIndex)
                    .MType is
                     when ENGINE =>
                        WeightGain := WeightGain * 10;
                     when others =>
                        null;
                  end case;
                  PlayerShip.Modules(PlayerShip.UpgradeModule).Weight :=
                    PlayerShip.Modules(PlayerShip.UpgradeModule).Weight +
                    WeightGain;
                  AddMessage
                    (To_String(PlayerShip.Crew(WorkerIndex).Name) &
                     " was upgraded " &
                     To_String
                       (PlayerShip.Modules(PlayerShip.UpgradeModule).Name) &
                     ".",
                     OrderMessage,
                     2);
                  MaxValue :=
                    Positive
                      (Float
                         (Modules_List
                            (PlayerShip.Modules(PlayerShip.UpgradeModule)
                               .ProtoIndex)
                            .Value) /
                       2.0);
                  if PlayerShip.Modules(PlayerShip.UpgradeModule)
                      .Current_Value =
                    MaxValue then
                     MaxUpgradeReached("You reached maximum upgrade for ");
                     return;
                  else
                     case Modules_List
                       (PlayerShip.Modules(PlayerShip.UpgradeModule)
                          .ProtoIndex)
                       .MType is
                        when ENGINE =>
                           PlayerShip.Modules(PlayerShip.UpgradeModule)
                             .UpgradeProgress :=
                             100;
                        when others =>
                           null;
                     end case;
                  end if;
               when others =>
                  null;
            end case;
         else
            PlayerShip.Modules(PlayerShip.UpgradeModule).UpgradeProgress :=
              UpgradeProgress;
         end if;
      end loop;
      if Length(Message) > 0 then
         AddMessage(To_String(Message), OrderMessage, 3);
      end if;
   end UpgradeShip;

end Ships.Upgrade;
