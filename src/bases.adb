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

with Ada.Numerics.Generic_Elementary_Functions;
with Maps; use Maps;
with Messages; use Messages;
with Items; use Items;
with UserInterface; use UserInterface;
with Bases.UI.Repair; use Bases.UI.Repair;
with Bases.UI.Heal; use Bases.UI.Heal;
with ShipModules; use ShipModules;
with Ships; use Ships;
with Ships.Cargo; use Ships.Cargo;
with Ships.Crew; use Ships.Crew;
with Events; use Events;
with Crafts; use Crafts;
with Utils; use Utils;
with Goals; use Goals;

package body Bases is

   procedure GainRep(BaseIndex: Positive; Points: Integer) is
      NewPoints: Integer;
   begin
      if SkyBases(BaseIndex).Reputation(1) = -100 or
        SkyBases(BaseIndex).Reputation(1) = 100 then
         return;
      end if;
      NewPoints := SkyBases(BaseIndex).Reputation(2) + Points;
      while NewPoints < 0 loop
         SkyBases(BaseIndex).Reputation(1) :=
           SkyBases(BaseIndex).Reputation(1) - 1;
         NewPoints := NewPoints + abs (SkyBases(BaseIndex).Reputation(1) * 10);
         if NewPoints >= 0 then
            SkyBases(BaseIndex).Reputation(2) := NewPoints;
            return;
         end if;
      end loop;
      while NewPoints > abs (SkyBases(BaseIndex).Reputation(1) * 10) loop
         NewPoints := NewPoints - abs (SkyBases(BaseIndex).Reputation(1) * 10);
         SkyBases(BaseIndex).Reputation(1) :=
           SkyBases(BaseIndex).Reputation(1) + 1;
      end loop;
      SkyBases(BaseIndex).Reputation(2) := NewPoints;
      if SkyBases(BaseIndex).Reputation(1) = 100 then
         UpdateGoal
           (REPUTATION,
            To_Unbounded_String
              (Bases_Owners'Image(SkyBases(BaseIndex).Owner)));
      end if;
   end GainRep;

   procedure CountPrice
     (Price: in out Positive;
      TraderIndex: Natural;
      Reduce: Boolean := True) is
      Bonus: Natural := 0;
   begin
      if TraderIndex > 0 then
         Bonus :=
           Integer
             (Float'Floor
                (Float(Price) *
                 (Float(GetSkillLevel(TraderIndex, 4)) / 200.0)));
      end if;
      case SkyBases(SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex)
        .Reputation
        (1) is
         when -24 .. -1 =>
            Bonus := Bonus - Integer(Float'Floor(Float(Price) * 0.05));
         when 26 .. 50 =>
            Bonus := Bonus + Integer(Float'Floor(Float(Price) * 0.05));
         when 51 .. 75 =>
            Bonus := Bonus + Integer(Float'Floor(Float(Price) * 0.1));
         when 76 .. 100 =>
            Bonus := Bonus + Integer(Float'Floor(Float(Price) * 0.15));
         when others =>
            null;
      end case;
      if Reduce then
         if Bonus >= Price then
            Bonus := Price - 1;
         end if;
         Price := Price - Bonus;
      else
         Price := Price + Bonus;
      end if;
   end CountPrice;

   procedure BuyItems(ItemIndex: Positive; Amount: String) is
      BuyAmount, TraderIndex, Price, ProtoMoneyIndex: Positive;
      BaseType: constant Positive :=
        Bases_Types'Pos
          (SkyBases(SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex)
             .BaseType) +
        1;
      ItemName: constant String := To_String(Items_List(ItemIndex).Name);
      Cost, MoneyIndex2: Natural;
      EventIndex: constant Natural :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).EventIndex;
   begin
      BuyAmount := Positive'Value(Amount);
      if not Items_List(ItemIndex).Buyable(BaseType) then
         ShowDialog("You can't buy " & ItemName & " in this base.");
         return;
      end if;
      TraderIndex := FindMember(Talk);
      Price := Items_List(ItemIndex).Prices(BaseType);
      if EventIndex > 0 then
         if Events_List(EventIndex).EType = DoublePrice and
           Events_List(EventIndex).Data = ItemIndex then
            Price := Price * 2;
         end if;
      end if;
      Cost := BuyAmount * Price;
      CountPrice(Cost, TraderIndex);
      ProtoMoneyIndex := FindProtoItem(MoneyIndex);
      MoneyIndex2 := FindCargo(ProtoMoneyIndex);
      if FreeCargo(Cost - (Items_List(ItemIndex).Weight * BuyAmount)) < 0 then
         ShowDialog("You don't have that much free space in your ship cargo.");
         return;
      end if;
      if MoneyIndex2 = 0 then
         ShowDialog
           ("You don't have " &
            To_String(MoneyName) &
            " to buy " &
            ItemName &
            ".");
         return;
      end if;
      if Cost > PlayerShip.Cargo(MoneyIndex2).Amount then
         ShowDialog
           ("You don't have enough " &
            To_String(MoneyName) &
            " to buy so much " &
            ItemName &
            ".");
         return;
      end if;
      UpdateCargo(PlayerShip, ProtoMoneyIndex, (0 - Cost));
      UpdateCargo(PlayerShip, ItemIndex, BuyAmount);
      GainExp(1, 4, TraderIndex);
      GainRep(SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex, 1);
      AddMessage
        ("You bought" &
         Positive'Image(BuyAmount) &
         " " &
         ItemName &
         " for" &
         Positive'Image(Cost) &
         " " &
         To_String(MoneyName) &
         ".",
         TradeMessage);
      UpdateGame(5);
   exception
      when Constraint_Error =>
         return;
   end BuyItems;

   procedure SellItems(ItemIndex: Positive; Amount: String) is
      SellAmount, TraderIndex: Positive;
      BaseType: constant Positive :=
        Bases_Types'Pos
          (SkyBases(SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex)
             .BaseType) +
        1;
      ProtoIndex: constant Positive := PlayerShip.Cargo(ItemIndex).ProtoIndex;
      ItemName: constant String := To_String(Items_List(ProtoIndex).Name);
      Profit, Price: Positive;
      EventIndex: constant Natural :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).EventIndex;
   begin
      SellAmount := Positive'Value(Amount);
      if PlayerShip.Cargo(ItemIndex).Amount < SellAmount then
         ShowDialog("You dont have that much " & ItemName & " in ship cargo.");
         return;
      end if;
      TraderIndex := FindMember(Talk);
      Price := Items_List(ProtoIndex).Prices(BaseType);
      if EventIndex > 0 then
         if Events_List(EventIndex).EType = DoublePrice and
           Events_List(EventIndex).Data = ProtoIndex then
            Price := Price * 2;
         end if;
      end if;
      Profit := Price * SellAmount;
      if PlayerShip.Cargo(ItemIndex).Durability < 100 then
         Profit :=
           Positive
             (Float'Floor
                (Float(Profit) *
                 (Float(PlayerShip.Cargo(ItemIndex).Durability) / 100.0)));
      end if;
      CountPrice(Profit, TraderIndex, False);
      if FreeCargo((Items_List(ProtoIndex).Weight * SellAmount) - Profit) <
        0 then
         ShowDialog
           ("You don't have enough free cargo space in your ship for " &
            To_String(MoneyName) &
            ".");
         return;
      end if;
      UpdateCargo
        (PlayerShip,
         ProtoIndex,
         (0 - SellAmount),
         PlayerShip.Cargo.Element(ItemIndex).Durability);
      UpdateCargo(PlayerShip, FindProtoItem(MoneyIndex), Profit);
      GainExp(1, 4, TraderIndex);
      GainRep(SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex, 1);
      AddMessage
        ("You sold" &
         Positive'Image(SellAmount) &
         " " &
         ItemName &
         " for" &
         Positive'Image(Profit) &
         " " &
         To_String(MoneyName) &
         ".",
         TradeMessage);
      UpdateGame(5);
   exception
      when Constraint_Error =>
         return;
   end SellItems;

   function GenerateBaseName
     return Unbounded_String is -- based on name generator from libtcod
      NewName: Unbounded_String;
   begin
      NewName := Null_Unbounded_String;
      if GetRandom(1, 100) < 16 then
         NewName :=
           BaseSyllablesPre
             (GetRandom
                (BaseSyllablesPre.First_Index,
                 BaseSyllablesPre.Last_Index)) &
           " ";
      end if;
      NewName :=
        NewName &
        BaseSyllablesStart
          (GetRandom
             (BaseSyllablesStart.First_Index,
              BaseSyllablesStart.Last_Index)) &
        BaseSyllablesEnd
          (GetRandom
             (BaseSyllablesEnd.First_Index,
              BaseSyllablesEnd.Last_Index));
      if GetRandom(1, 100) < 16 then
         NewName :=
           NewName &
           " " &
           BaseSyllablesPost
             (GetRandom
                (BaseSyllablesPost.First_Index,
                 BaseSyllablesPost.Last_Index));
      end if;
      return NewName;
   end GenerateBaseName;

   procedure RepairShip is
      Cost, Time, ModuleIndex, MoneyIndex2: Natural := 0;
      TraderIndex, ProtoMoneyIndex: Positive;
   begin
      RepairCost(Cost, Time, ModuleIndex);
      if Cost = 0 then
         return;
      end if;
      ProtoMoneyIndex := FindProtoItem(MoneyIndex);
      MoneyIndex2 := FindCargo(ProtoMoneyIndex);
      if MoneyIndex2 = 0 then
         ShowDialog
           ("You don't have " & To_String(MoneyName) & " to pay for repairs.");
         return;
      end if;
      TraderIndex := FindMember(Talk);
      CountPrice(Cost, TraderIndex);
      if PlayerShip.Cargo(MoneyIndex2).Amount < Cost then
         ShowDialog
           ("You don't have enough " &
            To_String(MoneyName) &
            " to pay for repairs.");
         return;
      end if;
      for I in PlayerShip.Crew.Iterate loop
         if PlayerShip.Crew(I).Order = Repair then
            GiveOrders(Crew_Container.To_Index(I), Rest);
         end if;
      end loop;
      if ModuleIndex > 0 then
         PlayerShip.Modules(ModuleIndex).Durability :=
           PlayerShip.Modules(ModuleIndex).MaxDurability;
         AddMessage
           ("You bought " &
            To_String(PlayerShip.Modules(ModuleIndex).Name) &
            " repair for" &
            Positive'Image(Cost) &
            " " &
            To_String(MoneyName) &
            ".",
            TradeMessage);
      else
         for Module of PlayerShip.Modules loop
            if Module.Durability < Module.MaxDurability then
               Module.Durability := Module.MaxDurability;
            end if;
         end loop;
         AddMessage
           ("You bought whole ship repair for" &
            Positive'Image(Cost) &
            " " &
            To_String(MoneyName) &
            ".",
            TradeMessage);
      end if;
      UpdateCargo(PlayerShip, ProtoMoneyIndex, (0 - Cost));
      GainExp(1, 4, TraderIndex);
      GainRep(SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex, 1);
      UpdateGame(Time);
   end RepairShip;

   procedure UpgradeShip(Install: Boolean; ModuleIndex: Positive) is
      ProtoMoneyIndex: constant Positive := FindProtoItem(MoneyIndex);
      MoneyIndex2: constant Natural := FindCargo(ProtoMoneyIndex);
      HullIndex, ModulesAmount, TraderIndex: Positive;
      FreeTurretIndex, Price: Natural := 0;
      type DamageFactor is digits 2 range 0.0 .. 1.0;
      Damage: DamageFactor := 0.0;
   begin
      if MoneyIndex2 = 0 then
         ShowDialog
           ("You don't have " & To_String(MoneyName) & " to pay for modules.");
         return;
      end if;
      for C in PlayerShip.Modules.Iterate loop
         case Modules_List(PlayerShip.Modules(C).ProtoIndex).MType is
            when HULL =>
               HullIndex := Modules_Container.To_Index(C);
               ModulesAmount := PlayerShip.Modules(C).Current_Value;
            when TURRET =>
               if PlayerShip.Modules(C).Current_Value = 0 then
                  FreeTurretIndex := Modules_Container.To_Index(C);
               end if;
            when others =>
               null;
         end case;
      end loop;
      TraderIndex := FindMember(Talk);
      if Install then
         Price := Modules_List(ModuleIndex).Price;
         CountPrice(Price, TraderIndex);
         if PlayerShip.Cargo(MoneyIndex2).Amount < Price then
            ShowDialog
              ("You don't have enough " &
               To_String(MoneyName) &
               " to pay for " &
               To_String(Modules_List(ModuleIndex).Name) &
               ".");
            return;
         end if;
         for Module of PlayerShip.Modules loop
            if Modules_List(Module.ProtoIndex).MType =
              Modules_List(ModuleIndex).MType and
              Modules_List(ModuleIndex).Unique then
               ShowDialog
                 ("You can't install another " &
                  To_String(Modules_List(ModuleIndex).Name) &
                  " because you have installed one module that type. Remove old first.");
               return;
            end if;
         end loop;
         if Modules_List(ModuleIndex).MType /= HULL then
            ModulesAmount := ModulesAmount + Modules_List(ModuleIndex).Size;
            if ModulesAmount > PlayerShip.Modules(HullIndex).Max_Value and
              Modules_List(ModuleIndex).MType /= GUN then
               ShowDialog
                 ("You don't have free modules space for more modules.");
               return;
            end if;
            if Modules_List(ModuleIndex).MType = GUN and
              FreeTurretIndex = 0 then
               ShowDialog
                 ("You don't have free turret for next gun. Install new turret or remove old gun first.");
               return;
            end if;
         else
            if Modules_List(ModuleIndex).MaxValue < ModulesAmount then
               ShowDialog
                 ("This hull is too small for your ship. Remove some modules first.");
               return;
            end if;
            PlayerShip.Modules.Delete(HullIndex, 1);
         end if;
         UpdateGame(Modules_List(ModuleIndex).InstallTime);
         UpdateCargo(PlayerShip, ProtoMoneyIndex, (0 - Price));
         GainExp(1, 4, TraderIndex);
         GainRep(SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex, 1);
         if Modules_List(ModuleIndex).MType /= HULL then
            PlayerShip.Modules.Append
            (New_Item =>
               (Name => Modules_List(ModuleIndex).Name,
                ProtoIndex => ModuleIndex,
                Weight => Modules_List(ModuleIndex).Weight,
                Current_Value => Modules_List(ModuleIndex).Value,
                Max_Value => Modules_List(ModuleIndex).MaxValue,
                Durability => Modules_List(ModuleIndex).Durability,
                MaxDurability => Modules_List(ModuleIndex).Durability,
                Owner => 0,
                UpgradeProgress => 0,
                UpgradeAction => NONE));
         else
            PlayerShip.Modules.Insert
            (Before =>
               HullIndex, New_Item =>
               (Name => Modules_List(ModuleIndex).Name,
                ProtoIndex => ModuleIndex,
                Weight => Modules_List(ModuleIndex).Weight,
                Current_Value => Modules_List(ModuleIndex).Value,
                Max_Value => Modules_List(ModuleIndex).MaxValue,
                Durability => Modules_List(ModuleIndex).Durability,
                MaxDurability => Modules_List(ModuleIndex).Durability,
                Owner => 0,
                UpgradeProgress => 0,
                UpgradeAction => NONE));
         end if;
         case Modules_List(ModuleIndex).MType is
            when GUN =>
               PlayerShip.Modules(FreeTurretIndex).Current_Value :=
                 PlayerShip.Modules.Last_Index;
            when others =>
               PlayerShip.Modules(HullIndex).Current_Value := ModulesAmount;
         end case;
         AddMessage
           ("You installed " &
            To_String(Modules_List(ModuleIndex).Name) &
            " on your ship for" &
            Positive'Image(Price) &
            " " &
            To_String(MoneyName) &
            ".",
            TradeMessage);
      else
         Damage :=
           1.0 -
           DamageFactor
             (Float(PlayerShip.Modules(ModuleIndex).Durability) /
              Float(PlayerShip.Modules(ModuleIndex).MaxDurability));
         Price :=
           Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex).Price -
           Integer
             (Float
                (Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex)
                   .Price) *
              Float(Damage));
         CountPrice(Price, TraderIndex, False);
         if FreeCargo((0 - Price)) < 0 then
            ShowDialog
              ("You don't have enough free space for " &
               To_String(MoneyName) &
               " in ship cargo.");
            return;
         end if;
         case Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex).MType is
            when TURRET =>
               if PlayerShip.Modules(ModuleIndex).Current_Value > 0 then
                  ShowDialog
                    ("You have installed gun in this turret, remove it before you remove this turret.");
                  return;
               end if;
            when GUN =>
               for Module of PlayerShip.Modules loop
                  if Modules_List(Module.ProtoIndex).MType = TURRET and
                    Module.Current_Value = ModuleIndex then
                     Module.Current_Value := 0;
                     exit;
                  end if;
               end loop;
            when ShipModules.CARGO =>
               if FreeCargo((0 - PlayerShip.Modules(ModuleIndex).Max_Value)) <
                 0 then
                  ShowDialog
                    ("You can't sell this cargo bay, because you have items in it.");
                  return;
               end if;
            when others =>
               null;
         end case;
         ModulesAmount :=
           ModulesAmount -
           Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex).Size;
         PlayerShip.Modules(HullIndex).Current_Value := ModulesAmount;
         if PlayerShip.UpgradeModule = ModuleIndex then
            PlayerShip.UpgradeModule := 0;
            for C in PlayerShip.Crew.Iterate loop
               if PlayerShip.Crew(C).Order = Upgrading then
                  GiveOrders(Crew_Container.To_Index(C), Rest);
                  exit;
               end if;
            end loop;
         end if;
         UpdateGame
           (Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex)
              .InstallTime);
         if PlayerShip.Modules(ModuleIndex).Owner > 0 and
           Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex).MType /=
             CABIN then
            GiveOrders
              (MemberIndex => PlayerShip.Modules(ModuleIndex).Owner,
               GivenOrder => Rest,
               CheckPriorities => False);
         end if;
         UpdateCargo(PlayerShip, ProtoMoneyIndex, Price);
         GainExp(1, 4, TraderIndex);
         GainRep(SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex, 1);
         AddMessage
           ("You removed " &
            To_String(PlayerShip.Modules(ModuleIndex).Name) &
            " from your ship and earned" &
            Positive'Image(Price) &
            " " &
            To_String(MoneyName) &
            ".",
            TradeMessage);
         PlayerShip.Modules.Delete(ModuleIndex, 1);
         if PlayerShip.RepairModule > ModuleIndex then
            PlayerShip.RepairModule := PlayerShip.RepairModule - 1;
         elsif PlayerShip.RepairModule = ModuleIndex then
            PlayerShip.RepairModule := 0;
         end if;
         if PlayerShip.UpgradeModule > ModuleIndex then
            PlayerShip.UpgradeModule := PlayerShip.UpgradeModule - 1;
         end if;
         for Module of PlayerShip.Modules loop
            if Modules_List(Module.ProtoIndex).MType = TURRET then
               if Module.Current_Value > ModuleIndex then
                  Module.Current_Value := Module.Current_Value - 1;
               end if;
            end if;
         end loop;
      end if;
   end UpgradeShip;

   procedure GenerateRecruits(BaseIndex: Positive) is
      MaxRecruits,
      RecruitsAmount,
      SkillsAmount,
      SkillNumber,
      SkillLevel: Positive;
      BaseRecruits: Recruit_Container.Vector;
      Skills: Skills_Container.Vector;
      Gender: Character;
      Price: Natural;
      SkillIndex: Integer;
   begin
      if DaysDifference(SkyBases(BaseIndex).RecruitDate) < 30 or
        SkyBases(BaseIndex).Owner = Abandoned then
         return;
      end if;
      if SkyBases(BaseIndex).Population < 150 then
         MaxRecruits := 5;
      elsif SkyBases(BaseIndex).Population > 149 and
        SkyBases(BaseIndex).Population < 300 then
         MaxRecruits := 10;
      else
         MaxRecruits := 15;
      end if;
      if MaxRecruits > (SkyBases(BaseIndex).Population / 10) then
         MaxRecruits := (SkyBases(BaseIndex).Population / 10) + 1;
      end if;
      RecruitsAmount := GetRandom(1, MaxRecruits);
      for I in 1 .. RecruitsAmount loop
         Skills.Clear;
         Price := 0;
         if GetRandom(1, 2) = 1 then
            Gender := 'M';
         else
            Gender := 'F';
         end if;
         BaseRecruits.Append
         (New_Item =>
            (Name => GenerateMemberName(Gender),
             Gender => Gender,
             Price => 1,
             Skills => Skills));
         SkillsAmount :=
           GetRandom(Skills_Names.First_Index, Skills_Names.Last_Index);
         for J in 1 .. SkillsAmount loop
            SkillNumber :=
              GetRandom(Skills_Names.First_Index, Skills_Names.Last_Index);
            SkillLevel := GetRandom(1, 100);
            SkillIndex := 0;
            for C in Skills.Iterate loop
               if Skills(C)(1) = SkillNumber then
                  if Skills(C)(2) < SkillLevel then
                     SkillIndex := Skills_Container.To_Index(C);
                  else
                     SkillIndex := -1;
                  end if;
                  exit;
               end if;
            end loop;
            if SkillIndex = 0 then
               Skills.Append(New_Item => (SkillNumber, SkillLevel, 0));
            elsif SkillIndex > 0 then
               Skills.Replace_Element
               (Index => SkillIndex, New_Item => (SkillNumber, SkillLevel, 0));
            end if;
         end loop;
         for C in Skills.Iterate loop
            Price := Price + Skills(C)(2);
         end loop;
         Price := Price * 100;
         BaseRecruits(BaseRecruits.Last_Index).Skills := Skills;
         BaseRecruits(BaseRecruits.Last_Index).Price := Price;
      end loop;
      SkyBases(BaseIndex).RecruitDate := GameDate;
      SkyBases(BaseIndex).Recruits := BaseRecruits;
   end GenerateRecruits;

   procedure HireRecruit(RecruitIndex: Positive) is
      BaseIndex: constant Positive :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex;
      MoneyIndex2, Price: Natural;
      Recruit: constant Recruit_Data :=
        SkyBases(BaseIndex).Recruits(RecruitIndex);
      TraderIndex, ProtoMoneyIndex: Positive;
   begin
      ProtoMoneyIndex := FindProtoItem(MoneyIndex);
      MoneyIndex2 := FindCargo(ProtoMoneyIndex);
      if MoneyIndex2 = 0 then
         ShowDialog
           ("You don't have " & To_String(MoneyName) & " to hire anyone.");
         return;
      end if;
      TraderIndex := FindMember(Talk);
      Price := Recruit.Price;
      CountPrice(Price, TraderIndex);
      if PlayerShip.Cargo(MoneyIndex2).Amount < Price then
         ShowDialog
           ("You don't have enough " &
            To_String(MoneyName) &
            " to hire " &
            To_String(Recruit.Name) &
            ".");
         return;
      end if;
      PlayerShip.Crew.Append
      (New_Item =>
         (Name => Recruit.Name,
          Gender => Recruit.Gender,
          Health => 100,
          Tired => 0,
          Skills => Recruit.Skills,
          Hunger => 0,
          Thirst => 0,
          Order => Rest,
          PreviousOrder => Rest,
          OrderTime => 15,
          Orders => (others => 0)));
      UpdateCargo(PlayerShip, ProtoMoneyIndex, (0 - Price));
      GainExp(1, 4, TraderIndex);
      GainRep(BaseIndex, 1);
      AddMessage
        ("You hired " &
         To_String(Recruit.Name) &
         " for" &
         Positive'Image(Price) &
         " " &
         To_String(MoneyName) &
         ".",
         TradeMessage);
      SkyBases(BaseIndex).Recruits.Delete(Index => RecruitIndex, Count => 1);
      SkyBases(BaseIndex).Population := SkyBases(BaseIndex).Population - 1;
      UpdateGame(5);
   end HireRecruit;

   procedure AskForBases is
      BaseIndex: constant Positive :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex;
      Radius, TempX, TempY: Integer;
      Amount, TmpBaseIndex: Natural;
      TraderIndex: Positive;
      UnknownBases: Natural := 0;
   begin
      if SkyBases(BaseIndex).AskedForBases then
         ShowDialog
           ("You can't ask again for direction to other bases in this base.");
         return;
      end if;
      if SkyBases(BaseIndex).Population < 150 then
         Amount := 10;
         Radius := 10;
      elsif SkyBases(BaseIndex).Population > 149 and
        SkyBases(BaseIndex).Population < 300 then
         Amount := 20;
         Radius := 20;
      else
         Amount := 40;
         Radius := 40;
      end if;
      TraderIndex := FindMember(Talk);
      Bases_Loop:
      for X in -Radius .. Radius loop
         for Y in -Radius .. Radius loop
            TempX := PlayerShip.SkyX + X;
            if TempX < 1 then
               TempX := 1;
            elsif TempX > 1024 then
               TempX := 1024;
            end if;
            TempY := PlayerShip.SkyY + Y;
            if TempY < 1 then
               TempY := 1;
            elsif TempY > 1024 then
               TempY := 1024;
            end if;
            TmpBaseIndex := SkyMap(TempX, TempY).BaseIndex;
            if TmpBaseIndex > 0 then
               if not SkyBases(TmpBaseIndex).Known then
                  SkyBases(TmpBaseIndex).Known := True;
                  Amount := Amount - 1;
                  exit Bases_Loop when Amount = 0;
               end if;
            end if;
         end loop;
      end loop Bases_Loop;
      if Amount > 0 then
         if SkyBases(BaseIndex).Population < 150 then
            if Amount > 1 then
               Amount := 1;
            end if;
         elsif SkyBases(BaseIndex).Population > 149 and
           SkyBases(BaseIndex).Population < 300 then
            if Amount > 2 then
               Amount := 2;
            end if;
         else
            if Amount > 4 then
               Amount := 4;
            end if;
         end if;
         for I in SkyBases'Range loop
            if not SkyBases(I).Known then
               UnknownBases := UnknownBases + 1;
            end if;
            exit when UnknownBases >= Amount;
         end loop;
         if UnknownBases >= Amount then
            loop
               TmpBaseIndex := GetRandom(1, 1024);
               if not SkyBases(TmpBaseIndex).Known then
                  SkyBases(TmpBaseIndex).Known := True;
                  Amount := Amount - 1;
               end if;
               exit when Amount = 0;
            end loop;
         else
            for I in SkyBases'Range loop
               if not SkyBases(I).Known then
                  SkyBases(I).Known := True;
               end if;
            end loop;
         end if;
      end if;
      SkyBases(BaseIndex).AskedForBases := True;
      AddMessage
        (To_String(PlayerShip.Crew(TraderIndex).Name) &
         " asked for directions to other bases.",
         OrderMessage);
      GainExp(1, 4, TraderIndex);
      GainRep(BaseIndex, 1);
      UpdateGame(30);
   end AskForBases;

   procedure AskForEvents is
      BaseIndex: constant Positive :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex;
      MaxEvents, EventsAmount, TmpBaseIndex, TraderIndex, ItemIndex: Positive;
      Event: Events_Types;
      EventX, EventY, EventTime, DiffX, DiffY: Positive;
      MinX, MinY, MaxX, MaxY: Integer;
      type Value_Type is digits 2 range 0.0 .. 9999999.0;
      package Value_Functions is new Ada.Numerics.Generic_Elementary_Functions
        (Value_Type);
      Enemies: Positive_Container.Vector;
      PlayerValue: Natural := 0;
      Attempts: Natural;
   begin
      if DaysDifference(SkyBases(BaseIndex).AskedForEvents) < 7 then
         ShowDialog("You asked for know events in this base not so long ago.");
         return;
      end if;
      TraderIndex := FindMember(Talk);
      if SkyBases(BaseIndex).Population < 150 then
         MaxEvents := 5;
      elsif SkyBases(BaseIndex).Population > 149 and
        SkyBases(BaseIndex).Population < 300 then
         MaxEvents := 10;
      else
         MaxEvents := 15;
      end if;
      EventsAmount := GetRandom(1, MaxEvents);
      MinX := PlayerShip.SkyX - 100;
      if MinX < 1 then
         MinX := 1;
      end if;
      MaxX := PlayerShip.SkyX + 100;
      if MaxX > 1024 then
         MaxX := 1024;
      end if;
      MinY := PlayerShip.SkyY - 100;
      if MinY < 1 then
         MinY := 1;
      end if;
      MaxY := PlayerShip.SkyY + 100;
      if MaxY > 1024 then
         MaxY := 1024;
      end if;
      if GetRandom(1, 100) < 99 then
         for Module of PlayerShip.Modules loop
            case Modules_List(Module.ProtoIndex).MType is
               when HULL | GUN | BATTERING_RAM =>
                  PlayerValue :=
                    PlayerValue +
                    Module.MaxDurability +
                    (Module.Max_Value * 10);
               when ARMOR =>
                  PlayerValue := PlayerValue + Module.MaxDurability;
               when others =>
                  null;
            end case;
         end loop;
         for Item of PlayerShip.Cargo loop
            if Length(Items_List(Item.ProtoIndex).IType) >= 4 then
               if Slice(Items_List(Item.ProtoIndex).IType, 1, 4) = "Ammo" then
                  PlayerValue :=
                    PlayerValue + (Items_List(Item.ProtoIndex).Value * 10);
               end if;
            end if;
         end loop;
         for C in ProtoShips_List.Iterate loop
            if ProtoShips_List(C).CombatValue <= PlayerValue and
              (ProtoShips_List(C).Owner /= Poleis and
               ProtoShips_List(C).Owner /= Independent) then
               Enemies.Append(New_Item => ProtoShips_Container.To_Index(C));
            end if;
         end loop;
      else
         for C in ProtoShips_List.Iterate loop
            if ProtoShips_List(C).Owner /= Poleis and
              ProtoShips_List(C).Owner /= Independent then
               Enemies.Append(New_Item => ProtoShips_Container.To_Index(C));
            end if;
         end loop;
      end if;
      for I in 1 .. EventsAmount loop
         Event := Events_Types'Val(GetRandom(1, 4));
         Attempts := 10;
         loop
            if Event = EnemyShip then
               EventX := GetRandom(MinX, MaxX);
               EventY := GetRandom(MinY, MaxY);
               exit when SkyMap(EventX, EventY).BaseIndex = 0 and
                 EventX /= PlayerShip.SkyX and
                 EventY /= PlayerShip.SkyY and
                 SkyMap(EventX, EventY).EventIndex = 0;
            else
               TmpBaseIndex := GetRandom(1, 1024);
               EventX := SkyBases(TmpBaseIndex).SkyX;
               EventY := SkyBases(TmpBaseIndex).SkyY;
               Attempts := Attempts - 1;
               if Attempts = 0 then
                  Event := EnemyShip;
                  loop
                     EventX := GetRandom(MinX, MaxX);
                     EventY := GetRandom(MinY, MaxY);
                     exit when SkyMap(EventX, EventY).BaseIndex = 0 and
                       EventX /= PlayerShip.SkyX and
                       EventY /= PlayerShip.SkyY and
                       SkyMap(EventX, EventY).EventIndex = 0;
                  end loop;
                  exit;
               end if;
               if Event = AttackOnBase and
                 (EventX /= PlayerShip.SkyX and
                  EventY /= PlayerShip.SkyY and
                  SkyMap(EventX, EventY).EventIndex = 0 and
                  SkyBases(SkyMap(EventX, EventY).BaseIndex).Owner /=
                    Abandoned and
                  SkyBases(SkyMap(EventX, EventY).BaseIndex).Known) then
                  exit;
               end if;
               if (Event = Disease or Event = DoublePrice) and
                 (EventX /= PlayerShip.SkyX and
                  EventY /= PlayerShip.SkyY and
                  SkyMap(EventX, EventY).EventIndex = 0 and
                  (SkyBases(SkyMap(EventX, EventY).BaseIndex).Owner /=
                   Abandoned or
                   SkyBases(SkyMap(EventX, EventY).BaseIndex).Owner /=
                     Drones or
                   SkyBases(SkyMap(EventX, EventY).BaseIndex).Owner /=
                     Undead) and
                  SkyBases(SkyMap(EventX, EventY).BaseIndex).Known) then
                  exit;
               end if;
            end if;
         end loop;
         DiffX := abs (PlayerShip.SkyX - EventX);
         DiffY := abs (PlayerShip.SkyY - EventY);
         EventTime :=
           Positive
             (Value_Type(60) *
              Value_Functions.Sqrt(Value_Type((DiffX**2) + (DiffY**2))));
         case Event is
            when EnemyShip =>
               Events_List.Append
               (New_Item =>
                  (EnemyShip,
                   EventX,
                   EventY,
                   GetRandom(EventTime, EventTime + 60),
                   Enemies
                     (GetRandom(Enemies.First_Index, Enemies.Last_Index))));
            when AttackOnBase =>
               Events_List.Append
               (New_Item =>
                  (AttackOnBase,
                   EventX,
                   EventY,
                   GetRandom(EventTime, EventTime + 120),
                   Enemies
                     (GetRandom(Enemies.First_Index, Enemies.Last_Index))));
            when Disease =>
               Events_List.Append
               (New_Item =>
                  (Disease, EventX, EventY, GetRandom(10080, 12000), 1));
            when DoublePrice =>
               loop
                  ItemIndex :=
                    GetRandom(Items_List.First_Index, Items_List.Last_Index);
                  exit when Items_List(ItemIndex).Prices(1) > 0;
               end loop;
               Events_List.Append
               (New_Item =>
                  (DoublePrice,
                   EventX,
                   EventY,
                   GetRandom((EventTime * 3), (EventTime * 4)),
                   ItemIndex));
            when others =>
               null;
         end case;
         SkyMap(EventX, EventY).EventIndex := Events_List.Last_Index;
      end loop;
      SkyBases(BaseIndex).AskedForEvents := GameDate;
      AddMessage
        (To_String(PlayerShip.Crew(TraderIndex).Name) &
         " asked for events in base.",
         OrderMessage);
      GainExp(1, 4, TraderIndex);
      GainRep(BaseIndex, 1);
      UpdateGame(30);
   end AskForEvents;

   procedure BuyRecipe(RecipeIndex: Positive) is
      BaseIndex: constant Positive :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex;
      Cost, MoneyIndex2: Natural;
      RecipeName: constant String :=
        To_String(Items_List(Recipes_List(RecipeIndex).ResultIndex).Name);
      BaseType: constant Positive :=
        Bases_Types'Pos(SkyBases(BaseIndex).BaseType) + 1;
      TraderIndex, ProtoMoneyIndex: Positive;
   begin
      if BaseType /= Recipes_List(RecipeIndex).BaseType then
         ShowDialog("You can't buy this recipe in this base.");
         return;
      end if;
      if Known_Recipes.Find_Index(Item => RecipeIndex) /=
        Positive_Container.No_Index then
         ShowDialog("You already known this recipe.");
         return;
      end if;
      TraderIndex := FindMember(Talk);
      if Items_List(Recipes_List(RecipeIndex).ResultIndex).Prices(BaseType) >
        0 then
         Cost :=
           Items_List(Recipes_List(RecipeIndex).ResultIndex).Prices(BaseType) *
           Recipes_List(RecipeIndex).Difficulty *
           100;
      else
         Cost := Recipes_List(RecipeIndex).Difficulty * 100;
      end if;
      CountPrice(Cost, TraderIndex);
      ProtoMoneyIndex := FindProtoItem(MoneyIndex);
      MoneyIndex2 := FindCargo(ProtoMoneyIndex);
      if MoneyIndex2 = 0 then
         ShowDialog
           ("You don't have " &
            To_String(MoneyName) &
            " to buy recipe for " &
            RecipeName &
            ".");
         return;
      end if;
      if Cost > PlayerShip.Cargo(MoneyIndex2).Amount then
         ShowDialog
           ("You don't have enough" &
            To_String(MoneyName) &
            "  to buy recipe for " &
            RecipeName &
            ".");
         return;
      end if;
      UpdateCargo(PlayerShip, ProtoMoneyIndex, (0 - Cost));
      Known_Recipes.Append(New_Item => RecipeIndex);
      AddMessage
        ("You bought recipe for " &
         RecipeName &
         " for" &
         Positive'Image(Cost) &
         " of " &
         To_String(MoneyName) &
         ".",
         TradeMessage);
      GainExp(1, 4, TraderIndex);
      GainRep(BaseIndex, 1);
      UpdateGame(5);
   end BuyRecipe;

   procedure UpdatePopulation(BaseIndex: Positive) is
      PopulationDiff: Integer;
   begin
      if DaysDifference(SkyBases(BaseIndex).RecruitDate) < 30 then
         return;
      end if;
      if SkyBases(BaseIndex).Owner /= Abandoned then
         if GetRandom(1, 100) > 30 then
            return;
         end if;
         if GetRandom(1, 100) < 20 then
            PopulationDiff := 0 - GetRandom(1, 10);
         else
            PopulationDiff := GetRandom(1, 10);
         end if;
         if SkyBases(BaseIndex).Population + PopulationDiff < 0 then
            PopulationDiff := 0 - SkyBases(BaseIndex).Population;
         end if;
         SkyBases(BaseIndex).Population :=
           SkyBases(BaseIndex).Population + PopulationDiff;
         if SkyBases(BaseIndex).Population = 0 then
            SkyBases(BaseIndex).Owner := Abandoned;
            SkyBases(BaseIndex).Reputation := (0, 0);
         end if;
      else
         if GetRandom(1, 100) > 5 then
            return;
         end if;
         SkyBases(BaseIndex).Population := GetRandom(5, 10);
         loop
            SkyBases(BaseIndex).Owner :=
              Bases_Owners'Val
                (GetRandom
                   (Bases_Owners'Pos(Bases_Owners'First),
                    Bases_Owners'Pos(Bases_Owners'Last)));
            exit when SkyBases(BaseIndex).Owner /= Abandoned and
              SkyBases(BaseIndex).Owner /= Any;
         end loop;
      end if;
   end UpdatePopulation;

   procedure HealWounded is
      Cost, Time, MemberIndex, MoneyIndex2: Natural := 0;
      TraderIndex, ProtoMoneyIndex: Positive;
   begin
      HealCost(Cost, Time, MemberIndex);
      if Cost = 0 then
         return;
      end if;
      ProtoMoneyIndex := FindProtoItem(MoneyIndex);
      MoneyIndex2 := FindCargo(ProtoMoneyIndex);
      if MoneyIndex2 = 0 then
         ShowDialog
           ("You don't have " &
            To_String(MoneyName) &
            " to pay for healing wounded crew members.");
         return;
      end if;
      TraderIndex := FindMember(Talk);
      CountPrice(Cost, TraderIndex);
      if PlayerShip.Cargo(MoneyIndex2).Amount < Cost then
         ShowDialog
           ("You don't have enough " &
            To_String(MoneyName) &
            " to pay for healing wounded crew members.");
         return;
      end if;
      if MemberIndex > 0 then
         PlayerShip.Crew(MemberIndex).Health := 100;
         AddMessage
           ("You bought healing " &
            To_String(PlayerShip.Crew(MemberIndex).Name) &
            " for" &
            Positive'Image(Cost) &
            " " &
            To_String(MoneyName) &
            ".",
            TradeMessage);
         GiveOrders(MemberIndex, Rest, 0, False);
      else
         for I in PlayerShip.Crew.Iterate loop
            if PlayerShip.Crew(I).Health < 100 then
               PlayerShip.Crew(I).Health := 100;
               GiveOrders(Crew_Container.To_Index(I), Rest, 0, False);
            end if;
         end loop;
         AddMessage
           ("You bought healing all wounded crew members for" &
            Positive'Image(Cost) &
            " " &
            To_String(MoneyName) &
            ".",
            TradeMessage);
      end if;
      UpdateCargo(PlayerShip, ProtoMoneyIndex, (0 - Cost));
      GainExp(1, 4, TraderIndex);
      GainRep(SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex, 1);
      UpdateGame(Time);
   end HealWounded;

end Bases;
