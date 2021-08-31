--    Copyright 2017-2021 Bartek thindil Jasicki
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
with Ships.Cargo; use Ships.Cargo;
with Ships.Crew; use Ships.Crew;
with Crafts; use Crafts;
with Trades; use Trades;
with Utils; use Utils;
with Bases.Cargo; use Bases.Cargo;
with Config; use Config;
with BasesTypes; use BasesTypes;
with Maps; use Maps;

package body Bases.Trade is

   -- ****if* BTrade/BTrade.CheckMoney
   -- FUNCTION
   -- Check if player have enough money
   -- PARAMETERS
   -- Price   - Miniumum amount of money which player must have
   -- Message - Additional message to return when player don't have enough
   --           money
   -- RESULT
   -- Cargo index of money from the player ship
   -- SOURCE
   function CheckMoney
     (Price: Positive; Message: String := "") return Positive is
      -- ****
      MoneyIndex2: constant Natural :=
        FindItem(Player_Ship.Cargo, Money_Index);
   begin
      if MoneyIndex2 = 0 then
         if Message /= "" then
            raise Trade_No_Money with Message;
         else
            raise Trade_No_Money;
         end if;
      end if;
      if Player_Ship.Cargo(MoneyIndex2).Amount < Price then
         if Message /= "" then
            raise Trade_Not_Enough_Money with Message;
         else
            raise Trade_Not_Enough_Money;
         end if;
      end if;
      return MoneyIndex2;
   end CheckMoney;

   procedure HireRecruit
     (RecruitIndex: Recruit_Container.Extended_Index; Cost: Positive;
      DailyPayment, TradePayment: Natural; ContractLenght: Integer) is
      BaseIndex: constant Bases_Range :=
        SkyMap(Player_Ship.Sky_X, Player_Ship.Sky_Y).BaseIndex;
      MoneyIndex2: Inventory_Container.Extended_Index;
      Price: Natural;
      Recruit: constant Recruit_Data :=
        SkyBases(BaseIndex).Recruits(RecruitIndex);
      Morale: Skill_Range;
      Inventory: Inventory_Container.Vector;
      TraderIndex: constant Crew_Container.Extended_Index := FindMember(Talk);
   begin
      if TraderIndex = 0 then
         raise Trade_No_Trader;
      end if;
      Price := Cost;
      CountPrice(Price, TraderIndex);
      MoneyIndex2 := CheckMoney(Price, To_String(Recruit.Name));
      Add_Recruit_Inventory_Loop :
      for Item of Recruit.Inventory loop
         Inventory.Append
           (New_Item =>
              (ProtoIndex => Item, Amount => 1, Name => Null_Unbounded_String,
               Durability => Default_Item_Durability, Price => 0));
      end loop Add_Recruit_Inventory_Loop;
      if Factions_List(SkyBases(BaseIndex).Owner).Flags.Contains
          (To_Unbounded_String("nomorale")) then
         Morale := 50;
      else
         Morale :=
           (if 50 + SkyBases(BaseIndex).Reputation(1) > 100 then 100
            else 50 + SkyBases(BaseIndex).Reputation(1));
      end if;
      Player_Ship.Crew.Append
        (New_Item =>
           (Attributes_Amount =>
              Positive
                (AttributesData_Container.Length
                   (Container => Attributes_List)),
            Skills_Amount =>
              SkillsData_Container.Length(Container => Skills_List),
            Name => Recruit.Name, Gender => Recruit.Gender, Health => 100,
            Tired => 0, Skills => Recruit.Skills, Hunger => 0, Thirst => 0,
            Order => Rest, PreviousOrder => Rest, OrderTime => 15,
            Orders => (others => 0), Attributes => Recruit.Attributes,
            Inventory => Inventory, Equipment => Recruit.Equipment,
            Payment => (DailyPayment, TradePayment),
            ContractLength => ContractLenght, Morale => (Morale, 0),
            Loyalty => Morale, HomeBase => Recruit.HomeBase,
            Faction => Recruit.Faction));
      UpdateCargo
        (Ship => Player_Ship, CargoIndex => MoneyIndex2, Amount => -(Price));
      GainExp(1, Talking_Skill, TraderIndex);
      GainRep(BaseIndex, 1);
      AddMessage
        ("You hired " & To_String(Recruit.Name) & " for" &
         Positive'Image(Price) & " " & To_String(Money_Name) & ".",
         TradeMessage);
      SkyBases(BaseIndex).Recruits.Delete(Index => RecruitIndex);
      SkyBases(BaseIndex).Population := SkyBases(BaseIndex).Population - 1;
      Update_Game(5);
   end HireRecruit;

   procedure BuyRecipe(RecipeIndex: Unbounded_String) is
      BaseIndex: constant Bases_Range :=
        SkyMap(Player_Ship.Sky_X, Player_Ship.Sky_Y).BaseIndex;
      MoneyIndex2: Inventory_Container.Extended_Index;
      Cost: Natural;
      RecipeName: constant String :=
        To_String(Items_List(Recipes_List(RecipeIndex).ResultIndex).Name);
      BaseType: constant Unbounded_String := SkyBases(BaseIndex).BaseType;
      TraderIndex: constant Crew_Container.Extended_Index := FindMember(Talk);
   begin
      if not BasesTypes_List(BaseType).Recipes.Contains(RecipeIndex) then
         raise Trade_Cant_Buy;
      end if;
      if Known_Recipes.Find_Index(Item => RecipeIndex) /=
        Positive_Container.No_Index then
         raise Trade_Already_Known;
      end if;
      if TraderIndex = 0 then
         raise Trade_No_Trader;
      end if;
      if Get_Price
          (SkyBases(BaseIndex).BaseType,
           Recipes_List(RecipeIndex).ResultIndex) >
        0 then
         Cost :=
           Get_Price
             (SkyBases(BaseIndex).BaseType,
              Recipes_List(RecipeIndex).ResultIndex) *
           Recipes_List(RecipeIndex).Difficulty * 10;
      else
         Cost := Recipes_List(RecipeIndex).Difficulty * 10;
      end if;
      Cost := Natural(Float(Cost) * Float(New_Game_Settings.Prices_Bonus));
      if Cost = 0 then
         Cost := 1;
      end if;
      CountPrice(Cost, TraderIndex);
      MoneyIndex2 := CheckMoney(Cost, RecipeName);
      UpdateCargo
        (Ship => Player_Ship, CargoIndex => MoneyIndex2, Amount => -(Cost));
      UpdateBaseCargo(Money_Index, Cost);
      Known_Recipes.Append(New_Item => RecipeIndex);
      AddMessage
        ("You bought the recipe for " & RecipeName & " for" &
         Positive'Image(Cost) & " of " & To_String(Money_Name) & ".",
         TradeMessage);
      GainExp(1, Talking_Skill, TraderIndex);
      GainRep(BaseIndex, 1);
      Update_Game(5);
   end BuyRecipe;

   procedure HealWounded(MemberIndex: Crew_Container.Extended_Index) is
      BaseIndex: constant Bases_Range :=
        SkyMap(Player_Ship.Sky_X, Player_Ship.Sky_Y).BaseIndex;
      MoneyIndex2: Inventory_Container.Extended_Index := 0;
      Cost, Time: Natural := 0;
      TraderIndex: constant Crew_Container.Extended_Index := FindMember(Talk);
   begin
      HealCost(Cost, Time, MemberIndex);
      if Cost = 0 then
         raise Trade_Cant_Heal;
      end if;
      if TraderIndex = 0 then
         raise Trade_No_Trader;
      end if;
      MoneyIndex2 := CheckMoney(Cost);
      if MemberIndex > 0 then
         Player_Ship.Crew(MemberIndex).Health := 100;
         AddMessage
           ("You paid for healing " &
            To_String(Player_Ship.Crew(MemberIndex).Name) & " for" &
            Positive'Image(Cost) & " " & To_String(Money_Name) & ".",
            TradeMessage);
         GiveOrders(Player_Ship, MemberIndex, Rest, 0, False);
      else
         Give_Rest_Order_Loop :
         for I in Player_Ship.Crew.Iterate loop
            if Player_Ship.Crew(I).Health < 100 then
               Player_Ship.Crew(I).Health := 100;
               GiveOrders
                 (Player_Ship, Crew_Container.To_Index(I), Rest, 0, False);
            end if;
         end loop Give_Rest_Order_Loop;
         AddMessage
           ("You paid for healing for all wounded crew members for" &
            Positive'Image(Cost) & " " & To_String(Money_Name) & ".",
            TradeMessage);
      end if;
      UpdateCargo
        (Ship => Player_Ship, CargoIndex => MoneyIndex2, Amount => -(Cost));
      UpdateBaseCargo(Money_Index, Cost);
      GainExp(1, Talking_Skill, TraderIndex);
      GainRep(BaseIndex, 1);
      Update_Game(Time);
   end HealWounded;

   procedure HealCost
     (Cost, Time: in out Natural;
      MemberIndex: Crew_Container.Extended_Index) is
      BaseIndex: constant Bases_Range :=
        SkyMap(Player_Ship.Sky_X, Player_Ship.Sky_Y).BaseIndex;
   begin
      if MemberIndex > 0 then
         Time := 5 * (100 - Player_Ship.Crew(MemberIndex).Health);
         Cost :=
           (5 * (100 - Player_Ship.Crew(MemberIndex).Health)) *
           Get_Price
             (To_Unbounded_String("0"),
              FindProtoItem
                (ItemType =>
                   Factions_List(Player_Ship.Crew(MemberIndex).Faction)
                     .HealingTools));
      else
         Count_Heal_Cost_Loop :
         for Member of Player_Ship.Crew loop
            if Member.Health < 100 then
               Time := Time + (5 * (100 - Member.Health));
               Cost :=
                 Cost +
                 ((5 * (100 - Member.Health)) *
                  Items_List
                    (FindProtoItem
                       (ItemType =>
                          Factions_List(Member.Faction).HealingTools))
                    .Price);
            end if;
         end loop Count_Heal_Cost_Loop;
      end if;
      Cost := Natural(Float(Cost) * Float(New_Game_Settings.Prices_Bonus));
      if Cost = 0 then
         Cost := 1;
      end if;
      CountPrice(Cost, FindMember(Talk));
      if Time = 0 then
         Time := 1;
      end if;
      if BasesTypes_List(SkyBases(BaseIndex).BaseType).Flags.Contains
          (To_Unbounded_String("temple")) then
         Cost := Cost / 2;
         if Cost = 0 then
            Cost := 1;
         end if;
      end if;
   end HealCost;

   function TrainCost
     (MemberIndex: Crew_Container.Extended_Index;
      SkillIndex: Skills_Container.Extended_Index) return Natural is
      Cost: Natural := Natural(100.0 * New_Game_Settings.Prices_Bonus);
   begin
      Count_Train_Cost_Loop :
      for Skill of Player_Ship.Crew(MemberIndex).Skills loop
         if Skill(1) = SkillIndex then
            if Skill(2) = 100 then
               return 0;
            end if;
            Cost :=
              Natural
                (Float((Skill(2) + 1) * 100) *
                 Float(New_Game_Settings.Prices_Bonus));
            if Cost = 0 then
               Cost := 1;
            end if;
            exit Count_Train_Cost_Loop;
         end if;
      end loop Count_Train_Cost_Loop;
      CountPrice(Cost, FindMember(Talk));
      return Cost;
   end TrainCost;

   procedure TrainSkill
     (MemberIndex: Crew_Container.Extended_Index;
      SkillIndex: Skills_Container.Extended_Index; Amount: Positive;
      Is_Amount: Boolean := True) is
      Cost: Natural;
      MoneyIndex2: Inventory_Container.Extended_Index;
      GainedExp: Positive;
      BaseIndex: constant Bases_Range :=
        SkyMap(Player_Ship.Sky_X, Player_Ship.Sky_Y).BaseIndex;
      TraderIndex: Crew_Container.Extended_Index;
      Sessions, OverallCost: Natural := 0;
      MaxAmount: Integer := Amount;
   begin
      GiveOrders(Player_Ship, MemberIndex, Rest, 0, False);
      Train_Skill_Loop :
      while MaxAmount > 0 loop
         Cost := TrainCost(MemberIndex, SkillIndex);
         MoneyIndex2 := FindItem(Player_Ship.Cargo, Money_Index);
         exit Train_Skill_Loop when Cost = 0 or
           Player_Ship.Cargo(MoneyIndex2).Amount < Cost or
           (not Is_Amount and MaxAmount < Cost);
         GainedExp :=
           GetRandom(10, 60) +
           Player_Ship.Crew(MemberIndex).Attributes
             (Positive(Skills_List(SkillIndex).Attribute))
             (1);
         if GainedExp > 100 then
            GainedExp := 100;
         end if;
         GainExp(GainedExp, SkillIndex, MemberIndex);
         UpdateCargo
           (Ship => Player_Ship, CargoIndex => MoneyIndex2, Amount => -(Cost));
         UpdateBaseCargo(Money_Index, Cost);
         TraderIndex := FindMember(Talk);
         if TraderIndex > 0 then
            GainExp(5, Talking_Skill, TraderIndex);
         end if;
         GainRep(BaseIndex, 5);
         Update_Game(60);
         Sessions := Sessions + 1;
         OverallCost := OverallCost + Cost;
         MaxAmount := MaxAmount - (if Is_Amount then 1 else Cost);
      end loop Train_Skill_Loop;
      if Sessions > 0 then
         AddMessage
           ("You purchased" & Positive'Image(Sessions) &
            " training session(s) in " &
            To_String(Skills_List(SkillIndex).Name) & " for " &
            To_String(Player_Ship.Crew(MemberIndex).Name) & " for" &
            Positive'Image(OverallCost) & " " & To_String(Money_Name) & ".",
            TradeMessage);
      end if;
   end TrainSkill;

end Bases.Trade;
