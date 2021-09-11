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

with Ada.Containers; use Ada.Containers;
with Maps; use Maps;
with Messages; use Messages;
with Ships.Cargo; use Ships.Cargo;
with Ships.Crew; use Ships.Crew;
with Events; use Events;
with Crew; use Crew;
with Game; use Game;
with Utils; use Utils;
with Bases.Cargo; use Bases.Cargo;
with BasesTypes; use BasesTypes;

package body Trades is

   procedure BuyItems
     (BaseItemIndex: BaseCargo_Container.Extended_Index; Amount: String) is
      BuyAmount, Price: Positive;
      BaseIndex: constant Extended_Base_Range :=
        SkyMap(Player_Ship.Sky_X, Player_Ship.Sky_Y).BaseIndex;
      Cost: Natural;
      MoneyIndex2: Inventory_Container.Extended_Index;
      EventIndex: constant Events_Container.Extended_Index :=
        SkyMap(Player_Ship.Sky_X, Player_Ship.Sky_Y).EventIndex;
      ItemName, ItemIndex: Unbounded_String;
      TraderIndex: constant Crew_Container.Extended_Index := FindMember(Talk);
   begin
      BuyAmount := Positive'Value(Amount);
      if TraderIndex = 0 then
         raise Trade_No_Trader;
      end if;
      if BaseIndex > 0 then
         ItemIndex := SkyBases(BaseIndex).Cargo(BaseItemIndex).ProtoIndex;
         ItemName := Items_List(ItemIndex).Name;
         Price := SkyBases(BaseIndex).Cargo(BaseItemIndex).Price;
         if EventIndex > 0
           and then
           (Events_List(EventIndex).EType = DoublePrice and
            Events_List(EventIndex).ItemIndex = ItemIndex) then
            Price := Price * 2;
         end if;
      else
         ItemIndex := TraderCargo(BaseItemIndex).ProtoIndex;
         ItemName := Items_List(ItemIndex).Name;
         if TraderCargo(BaseItemIndex).Amount < BuyAmount then
            raise Trade_Buying_Too_Much with To_String(ItemName);
         end if;
         Price := TraderCargo(BaseItemIndex).Price;
      end if;
      Cost := BuyAmount * Price;
      CountPrice(Cost, TraderIndex);
      MoneyIndex2 := FindItem(Player_Ship.Cargo, Money_Index);
      if FreeCargo(Cost - (Items_List(ItemIndex).Weight * BuyAmount)) < 0 then
         raise Trade_No_Free_Cargo;
      end if;
      if MoneyIndex2 = 0 then
         raise Trade_No_Money with To_String(ItemName);
      end if;
      if Cost > Player_Ship.Cargo(MoneyIndex2).Amount then
         raise Trade_Not_Enough_Money with To_String(ItemName);
      end if;
      UpdateCargo
        (Ship => Player_Ship, CargoIndex => MoneyIndex2, Amount => (0 - Cost));
      if BaseIndex > 0 then
         UpdateBaseCargo(Money_Index, Cost);
      else
         TraderCargo(1).Amount := TraderCargo(1).Amount + Cost;
      end if;
      if BaseIndex > 0 then
         UpdateCargo
           (Ship => Player_Ship, ProtoIndex => ItemIndex, Amount => BuyAmount,
            Durability => SkyBases(BaseIndex).Cargo(BaseItemIndex).Durability,
            Price => Price);
         UpdateBaseCargo
           (CargoIndex => BaseItemIndex, Amount => (0 - BuyAmount),
            Durability =>
              SkyBases(BaseIndex).Cargo.Element(BaseItemIndex).Durability);
         GainRep(BaseIndex, 1);
      else
         UpdateCargo
           (Ship => Player_Ship, ProtoIndex => ItemIndex, Amount => BuyAmount,
            Durability => TraderCargo(BaseItemIndex).Durability,
            Price => Price);
         TraderCargo(BaseItemIndex).Amount :=
           TraderCargo(BaseItemIndex).Amount - BuyAmount;
         if TraderCargo(BaseItemIndex).Amount = 0 then
            TraderCargo.Delete(Index => BaseItemIndex);
         end if;
      end if;
      GainExp(1, Talking_Skill, TraderIndex);
      AddMessage
        ("You bought" & Positive'Image(BuyAmount) & " " & To_String(ItemName) &
         " for" & Positive'Image(Cost) & " " & To_String(Money_Name) & ".",
         TradeMessage);
      if BaseIndex = 0 and EventIndex > 0 then
         Events_List(EventIndex).Time := Events_List(EventIndex).Time + 5;
      end if;
      Update_Game(5);
   exception
      when Constraint_Error =>
         raise Trade_Invalid_Amount;
   end BuyItems;

   procedure SellItems
     (ItemIndex: Inventory_Container.Extended_Index; Amount: String) is
      SellAmount: Positive;
      BaseIndex: constant Extended_Base_Range :=
        SkyMap(Player_Ship.Sky_X, Player_Ship.Sky_Y).BaseIndex;
      ProtoIndex: constant Unbounded_String :=
        Player_Ship.Cargo(ItemIndex).ProtoIndex;
      ItemName: constant String := To_String(Items_List(ProtoIndex).Name);
      Price: Positive;
      EventIndex: constant Events_Container.Extended_Index :=
        SkyMap(Player_Ship.Sky_X, Player_Ship.Sky_Y).EventIndex;
      BaseItemIndex: Natural := 0;
      CargoAdded: Boolean := False;
      TraderIndex: constant Crew_Container.Extended_Index := FindMember(Talk);
      Profit: Integer;
   begin
      SellAmount := Positive'Value(Amount);
      if TraderIndex = 0 then
         raise Trade_No_Trader;
      end if;
      if BaseIndex > 0 then
         BaseItemIndex := FindBaseCargo(ProtoIndex);
      else
         Find_Base_Index_Loop :
         for I in TraderCargo.Iterate loop
            if TraderCargo(I).ProtoIndex = ProtoIndex then
               BaseItemIndex := BaseCargo_Container.To_Index(I);
               exit Find_Base_Index_Loop;
            end if;
         end loop Find_Base_Index_Loop;
      end if;
      if BaseItemIndex = 0 then
         Price := Get_Price(SkyBases(BaseIndex).BaseType, ProtoIndex);
      else
         Price :=
           (if BaseIndex > 0 then
              SkyBases(BaseIndex).Cargo(BaseItemIndex).Price
            else TraderCargo(BaseItemIndex).Price);
      end if;
      if EventIndex > 0 and then Events_List(EventIndex).EType = DoublePrice
        and then Events_List(EventIndex).ItemIndex = ProtoIndex then
         Price := Price * 2;
      end if;
      Profit := Price * SellAmount;
      if Player_Ship.Cargo(ItemIndex).Durability < 100 then
         Profit :=
           Positive
             (Float'Floor
                (Float(Profit) *
                 (Float(Player_Ship.Cargo(ItemIndex).Durability) / 100.0)));
      end if;
      CountPrice(Profit, TraderIndex, False);
      Pay_Trade_Profit_Loop :
      for I in Player_Ship.Crew.Iterate loop
         if Player_Ship.Crew(I).Payment(2) = 0 then
            goto End_Of_Loop;
         end if;
         if Profit < 1 then
            UpdateMorale
              (Player_Ship, Crew_Container.To_Index(I), Get_Random(-25, -5));
            AddMessage
              (To_String(Player_Ship.Crew(I).Name) &
               " is sad because doesn't get own part of profit.",
               TradeMessage, RED);
            Profit := 0;
            goto End_Of_Loop;
         end if;
         Profit :=
           Profit -
           Positive
             (Float'Ceiling
                (Float(Profit) *
                 (Float(Player_Ship.Crew(I).Payment(2)) / 100.0)));
         if Profit < 1 then
            if Profit < 0 then
               UpdateMorale
                 (Player_Ship, Crew_Container.To_Index(I), Get_Random(-12, -2));
               AddMessage
                 (To_String(Player_Ship.Crew(I).Name) &
                  " is sad because doesn't get own part of profit.",
                  TradeMessage, RED);
            end if;
            Profit := 0;
         end if;
         <<End_Of_Loop>>
      end loop Pay_Trade_Profit_Loop;
      if FreeCargo((Items_List(ProtoIndex).Weight * SellAmount) - Profit) <
        0 then
         raise Trade_No_Free_Cargo;
      end if;
      if BaseIndex > 0 then
         if Profit > SkyBases(BaseIndex).Cargo(1).Amount then
            raise Trade_No_Money_In_Base with ItemName;
         end if;
         UpdateBaseCargo
           (ProtoIndex, SellAmount,
            Player_Ship.Cargo.Element(ItemIndex).Durability);
      else
         if Profit > TraderCargo(1).Amount then
            raise Trade_No_Money_In_Base with ItemName;
         end if;
         Update_Trader_Cargo_Loop :
         for I in TraderCargo.Iterate loop
            if TraderCargo(I).ProtoIndex = ProtoIndex and
              TraderCargo(I).Durability =
                Player_Ship.Cargo(ItemIndex).Durability then
               TraderCargo(I).Amount := TraderCargo(I).Amount + SellAmount;
               CargoAdded := True;
               exit Update_Trader_Cargo_Loop;
            end if;
         end loop Update_Trader_Cargo_Loop;
         if not CargoAdded then
            TraderCargo.Append
              (New_Item =>
                 (ProtoIndex => ProtoIndex, Amount => SellAmount,
                  Durability => Player_Ship.Cargo(ItemIndex).Durability,
                  Price => Items_List(ProtoIndex).Price));
         end if;
      end if;
      UpdateCargo
        (Ship => Player_Ship, CargoIndex => ItemIndex,
         Amount => (0 - SellAmount),
         Price => Player_Ship.Cargo.Element(ItemIndex).Price);
      UpdateCargo(Player_Ship, Money_Index, Profit);
      if BaseIndex > 0 then
         UpdateBaseCargo(Money_Index, (0 - Profit));
         GainRep(BaseIndex, 1);
         if Items_List(ProtoIndex).Reputation >
           SkyBases(BaseIndex).Reputation(1) then
            GainRep(BaseIndex, 1);
         end if;
      else
         TraderCargo(1).Amount := TraderCargo(1).Amount - Profit;
      end if;
      GainExp(1, Talking_Skill, TraderIndex);
      AddMessage
        ("You sold" & Positive'Image(SellAmount) & " " & ItemName & " for" &
         Positive'Image(Profit) & " " & To_String(Money_Name) & ".",
         TradeMessage);
      if BaseIndex = 0 and EventIndex > 0 then
         Events_List(EventIndex).Time := Events_List(EventIndex).Time + 5;
      end if;
      Update_Game(5);
   exception
      when Constraint_Error =>
         raise Trade_Invalid_Amount;
   end SellItems;

   procedure GenerateTraderCargo(ProtoIndex: Unbounded_String) is
      TraderShip: Ship_Record :=
        Create_Ship
          (ProtoIndex, Null_Unbounded_String, Player_Ship.Sky_X,
           Player_Ship.Sky_Y, FULL_STOP);
      CargoAmount: Natural range 0 .. 10 :=
        (if TraderShip.Crew.Length < 5 then Get_Random(1, 3)
         elsif TraderShip.Crew.Length < 10 then Get_Random(1, 5)
         else Get_Random(1, 10));
      CargoItemIndex, ItemIndex: Inventory_Container.Extended_Index;
      ItemAmount: Positive range 1 .. 1_000;
      NewItemIndex: Unbounded_String;
   begin
      TraderCargo.Clear;
      Add_Items_To_Cargo_Loop :
      for Item of TraderShip.Cargo loop
         TraderCargo.Append
           (New_Item =>
              (ProtoIndex => Item.ProtoIndex, Amount => Item.Amount,
               Durability => 100, Price => Items_List(Item.ProtoIndex).Price));
      end loop Add_Items_To_Cargo_Loop;
      Generate_Cargo_Loop :
      while CargoAmount > 0 loop
         ItemAmount :=
           (if TraderShip.Crew.Length < 5 then Get_Random(1, 100)
            elsif TraderShip.Crew.Length < 10 then Get_Random(1, 500)
            else Get_Random(1, 1_000));
         ItemIndex := Get_Random(1, Positive(Items_List.Length));
         Find_Item_Index_Loop :
         for I in Items_List.Iterate loop
            ItemIndex := ItemIndex - 1;
            if ItemIndex = 0 then
               NewItemIndex := Objects_Container.Key(I);
               exit Find_Item_Index_Loop;
            end if;
         end loop Find_Item_Index_Loop;
         CargoItemIndex := FindItem(TraderShip.Cargo, NewItemIndex);
         if CargoItemIndex > 0 then
            TraderCargo(CargoItemIndex).Amount :=
              TraderCargo(CargoItemIndex).Amount + ItemAmount;
            TraderShip.Cargo(CargoItemIndex).Amount :=
              TraderShip.Cargo(CargoItemIndex).Amount + ItemAmount;
         else
            if FreeCargo(0 - (Items_List(NewItemIndex).Weight * ItemAmount)) >
              -1 then
               TraderCargo.Append
                 (New_Item =>
                    (ProtoIndex => NewItemIndex, Amount => ItemAmount,
                     Durability => 100,
                     Price => Items_List(NewItemIndex).Price));
               TraderShip.Cargo.Append
                 (New_Item =>
                    (ProtoIndex => NewItemIndex, Amount => ItemAmount,
                     Durability => 100, Name => Null_Unbounded_String,
                     Price => 0));
            else
               CargoAmount := 1;
            end if;
         end if;
         CargoAmount := CargoAmount - 1;
      end loop Generate_Cargo_Loop;
   end GenerateTraderCargo;

end Trades;
