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
with Ada.Containers; use Ada.Containers;
with Maps; use Maps;
with Messages; use Messages;
with Items; use Items;
with Ships; use Ships;
with Ships.Cargo; use Ships.Cargo;
with Ships.Crew; use Ships.Crew;
with Events; use Events;
with Crew; use Crew;
with Game; use Game;
with Utils; use Utils;
with Bases.Cargo; use Bases.Cargo;

package body Trades is

   procedure BuyItems(BaseItemIndex: Positive; Amount: String) is
      BuyAmount, Price, ProtoMoneyIndex: Positive;
      BaseIndex: constant Natural :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex;
      BaseType, ItemIndex: Positive;
      Cost, MoneyIndex2: Natural;
      EventIndex: constant Natural :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).EventIndex;
      ItemName: Unbounded_String;
      TraderIndex: constant Natural := FindMember(Talk);
   begin
      BuyAmount := Positive'Value(Amount);
      if TraderIndex = 0 then
         raise Trade_No_Trader;
      end if;
      if BaseIndex > 0 then
         BaseType := Bases_Types'Pos(SkyBases(BaseIndex).BaseType) + 1;
         ItemIndex := SkyBases(BaseIndex).Cargo(BaseItemIndex).ProtoIndex;
         ItemName := Items_List(ItemIndex).Name;
         if not Items_List(ItemIndex).Buyable(BaseType) then
            raise Trade_Cant_Buy with To_String(ItemName);
         end if;
         if SkyBases(BaseIndex).Cargo(BaseItemIndex).Amount = 0 then
            raise Trade_Not_For_Sale_Now with To_String(ItemName);
         elsif SkyBases(BaseIndex).Cargo(BaseItemIndex).Amount < BuyAmount then
            raise Trade_Buying_Too_Much with To_String(ItemName);
         end if;
         Price := SkyBases(BaseIndex).Cargo(BaseItemIndex).Price;
         if EventIndex > 0 then
            if Events_List(EventIndex).EType = DoublePrice and
              Events_List(EventIndex).Data = ItemIndex then
               Price := Price * 2;
            end if;
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
      ProtoMoneyIndex := FindProtoItem(MoneyIndex);
      MoneyIndex2 := FindItem(PlayerShip.Cargo, ProtoMoneyIndex);
      if FreeCargo(Cost - (Items_List(ItemIndex).Weight * BuyAmount)) < 0 then
         raise Trade_No_Free_Cargo;
      end if;
      if MoneyIndex2 = 0 then
         raise Trade_No_Money with To_String(ItemName);
      end if;
      if Cost > PlayerShip.Cargo(MoneyIndex2).Amount then
         raise Trade_Not_Enough_Money with To_String(ItemName);
      end if;
      UpdateCargo
        (Ship => PlayerShip,
         CargoIndex => MoneyIndex2,
         Amount => (0 - Cost));
      if BaseIndex > 0 then
         UpdateBaseCargo(ProtoMoneyIndex, Cost);
      else
         TraderCargo(1).Amount := TraderCargo(1).Amount + Cost;
      end if;
      if BaseIndex > 0 then
         UpdateCargo
           (PlayerShip,
            ItemIndex,
            BuyAmount,
            SkyBases(BaseIndex).Cargo(BaseItemIndex).Durability);
         UpdateBaseCargo
           (CargoIndex => BaseItemIndex,
            Amount => (0 - BuyAmount),
            Durability =>
              SkyBases(BaseIndex).Cargo.Element(BaseItemIndex).Durability);
         GainRep(BaseIndex, 1);
      else
         UpdateCargo
           (PlayerShip,
            ItemIndex,
            BuyAmount,
            TraderCargo(BaseItemIndex).Durability);
         TraderCargo(BaseItemIndex).Amount :=
           TraderCargo(BaseItemIndex).Amount - BuyAmount;
         if TraderCargo(BaseItemIndex).Amount = 0 then
            TraderCargo.Delete(Index => BaseItemIndex);
         end if;
      end if;
      GainExp(1, TalkingSkill, TraderIndex);
      AddMessage
        ("You bought" &
         Positive'Image(BuyAmount) &
         " " &
         To_String(ItemName) &
         " for" &
         Positive'Image(Cost) &
         " " &
         To_String(MoneyName) &
         ".",
         TradeMessage);
      if BaseIndex = 0 and EventIndex > 0 then
         Events_List(EventIndex).Time := Events_List(EventIndex).Time + 5;
      end if;
      UpdateGame(5);
   exception
      when Constraint_Error =>
         raise Trade_Invalid_Amount;
   end BuyItems;

   procedure SellItems(ItemIndex: Positive; Amount: String) is
      SellAmount: Positive;
      BaseIndex: constant Natural :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex;
      ProtoIndex: constant Positive := PlayerShip.Cargo(ItemIndex).ProtoIndex;
      ItemName: constant String := To_String(Items_List(ProtoIndex).Name);
      Profit, Price, BaseType: Positive;
      EventIndex: constant Natural :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).EventIndex;
      MoneyIndex2: constant Positive := FindProtoItem(MoneyIndex);
      BaseItemIndex: Natural := 0;
      CargoAdded: Boolean := False;
      TraderIndex: constant Natural := FindMember(Talk);
   begin
      SellAmount := Positive'Value(Amount);
      if TraderIndex = 0 then
         raise Trade_No_Trader;
      end if;
      if PlayerShip.Cargo(ItemIndex).Amount < SellAmount then
         raise Trade_Too_Much_For_Sale with ItemName;
      end if;
      if BaseIndex > 0 then
         BaseType := Bases_Types'Pos(SkyBases(BaseIndex).BaseType) + 1;
         BaseItemIndex := FindBaseCargo(ProtoIndex);
      else
         BaseType := 1;
         for I in TraderCargo.Iterate loop
            if TraderCargo(I).ProtoIndex = ProtoIndex then
               BaseItemIndex := BaseCargo_Container.To_Index(I);
               exit;
            end if;
         end loop;
      end if;
      if BaseItemIndex = 0 then
         Price := Items_List(ProtoIndex).Prices(BaseType);
      else
         if BaseIndex > 0 then
            Price := SkyBases(BaseIndex).Cargo(BaseItemIndex).Price;
         else
            Price := TraderCargo(BaseItemIndex).Price;
         end if;
      end if;
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
         raise Trade_No_Free_Cargo;
      end if;
      if BaseIndex > 0 then
         if Profit > SkyBases(BaseIndex).Cargo(1).Amount then
            raise Trade_No_Money_In_Base with ItemName;
         end if;
         UpdateBaseCargo
           (ProtoIndex,
            SellAmount,
            PlayerShip.Cargo.Element(ItemIndex).Durability);
      else
         if Profit > TraderCargo(1).Amount then
            raise Trade_No_Money_In_Base with ItemName;
         end if;
         for I in TraderCargo.Iterate loop
            if TraderCargo(I).ProtoIndex = ProtoIndex and
              TraderCargo(I).Durability =
                PlayerShip.Cargo(ItemIndex).Durability then
               TraderCargo(I).Amount := TraderCargo(I).Amount + SellAmount;
               CargoAdded := True;
               exit;
            end if;
         end loop;
         if not CargoAdded then
            BaseType := GetRandom(1, 4);
            TraderCargo.Append
            (New_Item =>
               (ProtoIndex => ProtoIndex,
                Amount => SellAmount,
                Durability => PlayerShip.Cargo(ItemIndex).Durability,
                Price => Items_List(ItemIndex).Prices(BaseType)));
         end if;
      end if;
      UpdateCargo
        (Ship => PlayerShip,
         CargoIndex => ItemIndex,
         Amount => (0 - SellAmount),
         Durability => PlayerShip.Cargo.Element(ItemIndex).Durability);
      UpdateCargo(PlayerShip, MoneyIndex2, Profit);
      if BaseIndex > 0 then
         UpdateBaseCargo(MoneyIndex2, (0 - Profit));
         GainRep(BaseIndex, 1);
      else
         TraderCargo(1).Amount := TraderCargo(1).Amount - Profit;
      end if;
      GainExp(1, TalkingSkill, TraderIndex);
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
      if BaseIndex = 0 and EventIndex > 0 then
         Events_List(EventIndex).Time := Events_List(EventIndex).Time + 5;
      end if;
      UpdateGame(5);
   exception
      when Constraint_Error =>
         raise Trade_Invalid_Amount;
   end SellItems;

   procedure GenerateTraderCargo(ProtoIndex: Positive) is
      TraderShip: ShipRecord :=
        CreateShip
          (ProtoIndex,
           Null_Unbounded_String,
           PlayerShip.SkyX,
           PlayerShip.SkyY,
           FULL_STOP);
      BaseType, CargoAmount, CargoItemIndex: Natural;
      ItemIndex, ItemAmount: Positive;
   begin
      TraderCargo.Clear;
      for Item of TraderShip.Cargo loop
         BaseType := GetRandom(1, 4);
         TraderCargo.Append
         (New_Item =>
            (ProtoIndex => Item.ProtoIndex,
             Amount => Item.Amount,
             Durability => 100,
             Price => Items_List(Item.ProtoIndex).Prices(BaseType)));
      end loop;
      if TraderShip.Crew.Length < 5 then
         CargoAmount := GetRandom(1, 3);
      elsif TraderShip.Crew.Length < 10 then
         CargoAmount := GetRandom(1, 5);
      else
         CargoAmount := GetRandom(1, 10);
      end if;
      while CargoAmount > 0 loop
         ItemIndex := GetRandom(Items_List.First_Index, Items_List.Last_Index);
         if TraderShip.Crew.Length < 5 then
            ItemAmount := GetRandom(1, 100);
         elsif TraderShip.Crew.Length < 10 then
            ItemAmount := GetRandom(1, 500);
         else
            ItemAmount := GetRandom(1, 1000);
         end if;
         CargoItemIndex := FindItem(TraderShip.Cargo, ItemIndex);
         if CargoItemIndex > 0 then
            TraderCargo(CargoItemIndex).Amount :=
              TraderCargo(CargoItemIndex).Amount + ItemAmount;
            TraderShip.Cargo(CargoItemIndex).Amount :=
              TraderShip.Cargo(CargoItemIndex).Amount + ItemAmount;
         else
            if FreeCargo(0 - (Items_List(ItemIndex).Weight * ItemAmount)) >
              -1 then
               BaseType := GetRandom(1, 4);
               TraderCargo.Append
               (New_Item =>
                  (ProtoIndex => ItemIndex,
                   Amount => ItemAmount,
                   Durability => 100,
                   Price => Items_List(ItemIndex).Prices(BaseType)));
               TraderShip.Cargo.Append
               (New_Item =>
                  (ProtoIndex => ItemIndex,
                   Amount => ItemAmount,
                   Durability => 100,
                   Name => Null_Unbounded_String));
            else
               CargoAmount := 1;
            end if;
         end if;
         CargoAmount := CargoAmount - 1;
      end loop;
   end GenerateTraderCargo;

end Trades;
