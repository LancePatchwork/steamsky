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

with Ada.Containers; use Ada.Containers;
with Maps; use Maps;
with Messages; use Messages;
with Ships.Cargo; use Ships.Cargo;
with Ships.Crew; use Ships.Crew;
with Events; use Events;
with Game; use Game;
with Crew; use Crew;
with Utils; use Utils;
with Bases.Cargo; use Bases.Cargo;
with BasesTypes; use BasesTypes;

package body Trades is

   procedure Buy_Items
     (Base_Item_Index: BaseCargo_Container.Extended_Index; Amount: String) is
      use Tiny_String;

      Buy_Amount, Price: Positive;
      Base_Index: constant Extended_Base_Range :=
        Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Base_Index;
      Cost: Natural;
      Money_Index_2: Inventory_Container.Extended_Index;
      Event_Index: constant Events_Container.Extended_Index :=
        Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Event_Index;
      Item_Name: Bounded_String;
      Trader_Index: constant Crew_Container.Extended_Index :=
        Find_Member(Order => TALK);
      Item_Index: Natural;
      Item: Base_Cargo;
   begin
      Buy_Amount := Positive'Value(Amount);
      if Trader_Index = 0 then
         raise Trade_No_Trader;
      end if;
      if Base_Index > 0 then
         Item_Index :=
           BaseCargo_Container.Element
             (Container => Sky_Bases(Base_Index).Cargo,
              Index => Base_Item_Index)
             .Proto_Index;
         Item_Name := Get_Proto_Item(Index => Item_Index).Name;
         Price :=
           BaseCargo_Container.Element
             (Container => Sky_Bases(Base_Index).Cargo,
              Index => Base_Item_Index)
             .Price;
         if Event_Index > 0
           and then
           (Events_List(Event_Index).E_Type = DOUBLEPRICE and
            Events_List(Event_Index).Item_Index = Item_Index) then
            Price := Price * 2;
         end if;
      else
         Item_Index :=
           BaseCargo_Container.Element
             (Container => Trader_Cargo, Index => Base_Item_Index)
             .Proto_Index;
         Item_Name := Get_Proto_Item(Index => Item_Index).Name;
         if BaseCargo_Container.Element
             (Container => Trader_Cargo, Index => Base_Item_Index)
             .Amount <
           Buy_Amount then
            raise Trade_Buying_Too_Much with To_String(Source => Item_Name);
         end if;
         Price :=
           BaseCargo_Container.Element
             (Container => Trader_Cargo, Index => Base_Item_Index)
             .Price;
      end if;
      Cost := Buy_Amount * Price;
      Count_Price(Price => Cost, Trader_Index => Trader_Index);
      Money_Index_2 :=
        Find_Item(Inventory => Player_Ship.Cargo, Proto_Index => Money_Index);
      if Free_Cargo
          (Amount =>
             Cost -
             (Get_Proto_Item(Index => Item_Index).Weight * Buy_Amount)) <
        0 then
         raise Trade_No_Free_Cargo;
      end if;
      if Money_Index_2 = 0 then
         raise Trade_No_Money with To_String(Source => Item_Name);
      end if;
      if Cost >
        Inventory_Container.Element
          (Container => Player_Ship.Cargo, Index => Money_Index_2)
          .Amount then
         raise Trade_Not_Enough_Money with To_String(Source => Item_Name);
      end if;
      Update_Cargo
        (Ship => Player_Ship, Cargo_Index => Money_Index_2, Amount => -(Cost));
      if Base_Index > 0 then
         Update_Base_Cargo(Proto_Index => Money_Index, Amount => Cost);
      else
         Item :=
           BaseCargo_Container.Element(Container => Trader_Cargo, Index => 1);
         Item.Amount := Item.Amount + Cost;
         BaseCargo_Container.Replace_Element
           (Container => Trader_Cargo, Index => 1, New_Item => Item);
      end if;
      if Base_Index > 0 then
         Update_Cargo
           (Ship => Player_Ship, Proto_Index => Item_Index,
            Amount => Buy_Amount,
            Durability =>
              BaseCargo_Container.Element
                (Container => Sky_Bases(Base_Index).Cargo,
                 Index => Base_Item_Index)
                .Durability,
            Price => Price);
         Update_Base_Cargo
           (Cargo_Index => Base_Item_Index, Amount => -(Buy_Amount),
            Durability =>
              BaseCargo_Container.Element
                (Container => Sky_Bases(Base_Index).Cargo,
                 Index => Base_Item_Index)
                .Durability);
         Gain_Rep(Base_Index => Base_Index, Points => 1);
      else
         Update_Cargo
           (Ship => Player_Ship, Proto_Index => Item_Index,
            Amount => Buy_Amount,
            Durability =>
              BaseCargo_Container.Element
                (Container => Trader_Cargo, Index => Base_Item_Index)
                .Durability,
            Price => Price);
         Item :=
           BaseCargo_Container.Element
             (Container => Trader_Cargo, Index => Base_Item_Index);
         Item.Amount := Item.Amount - Buy_Amount;
         if Item.Amount = 0 then
            BaseCargo_Container.Delete
              (Container => Trader_Cargo, Index => Base_Item_Index);
         else
            BaseCargo_Container.Replace_Element
              (Container => Trader_Cargo, Index => Base_Item_Index,
               New_Item => Item);
         end if;
      end if;
      Gain_Exp
        (Amount => 1, Skill_Number => Talking_Skill,
         Crew_Index => Trader_Index);
      Show_Log_Block :
      declare
         Gain: constant Integer := (Buy_Amount * Price) - Cost;
      begin
         Add_Message
           (Message =>
              "You bought" & Positive'Image(Buy_Amount) & " " &
              To_String(Source => Item_Name) & " for" & Positive'Image(Cost) &
              " " & To_String(Source => Money_Name) & "." &
              (if Gain = 0 then ""
               else " You " & (if Gain > 0 then "gain" else "lost") &
                 Integer'Image(abs (Gain)) & " " &
                 To_String(Source => Money_Name) &
                 " compared to the base price."),
            M_Type => TRADEMESSAGE);
      end Show_Log_Block;
      if Base_Index = 0 and Event_Index > 0 then
         Events_List(Event_Index).Time := Events_List(Event_Index).Time + 5;
      end if;
      Update_Game(Minutes => 5);
   exception
      when Constraint_Error =>
         raise Trade_Invalid_Amount;
   end Buy_Items;

   procedure Sell_Items
     (Item_Index: Inventory_Container.Extended_Index; Amount: String) is
      use Tiny_String;

      Sell_Amount: Positive;
      Base_Index: constant Extended_Base_Range :=
        Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Base_Index;
      Proto_Index: constant Natural :=
        Inventory_Container.Element
          (Container => Player_Ship.Cargo, Index => Item_Index)
          .Proto_Index;
      Item_Name: constant String :=
        To_String(Source => Get_Proto_Item(Index => Proto_Index).Name);
      Price: Positive;
      Event_Index: constant Events_Container.Extended_Index :=
        Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Event_Index;
      Base_Item_Index: Natural := 0;
      Cargo_Added: Boolean := False;
      Trader_Index: constant Crew_Container.Extended_Index :=
        Find_Member(Order => TALK);
      Profit: Integer;
      Item: Base_Cargo;
   begin
      Sell_Amount := Positive'Value(Amount);
      if Trader_Index = 0 then
         raise Trade_No_Trader;
      end if;
      if Base_Index > 0 then
         Base_Item_Index := Find_Base_Cargo(Proto_Index => Proto_Index);
      else
         Find_Base_Index_Loop :
         for I in
           BaseCargo_Container.First_Index(Container => Trader_Cargo) ..
             BaseCargo_Container.Last_Index(Container => Trader_Cargo) loop
            if BaseCargo_Container.Element
                (Container => Trader_Cargo, Index => I)
                .Proto_Index =
              Proto_Index then
               Base_Item_Index := I;
               exit Find_Base_Index_Loop;
            end if;
         end loop Find_Base_Index_Loop;
      end if;
      if Base_Item_Index = 0 then
         Price :=
           Get_Price
             (Base_Type => Sky_Bases(Base_Index).Base_Type,
              Item_Index => Proto_Index);
      else
         Price :=
           (if Base_Index > 0 then
              BaseCargo_Container.Element
                (Container => Sky_Bases(Base_Index).Cargo,
                 Index => Base_Item_Index)
                .Price
            else BaseCargo_Container.Element
                (Container => Trader_Cargo, Index => Base_Item_Index)
                .Price);
      end if;
      if Event_Index > 0 and then Events_List(Event_Index).E_Type = DOUBLEPRICE
        and then Events_List(Event_Index).Item_Index = Proto_Index then
         Price := Price * 2;
      end if;
      Profit := Price * Sell_Amount;
      if Inventory_Container.Element
          (Container => Player_Ship.Cargo, Index => Item_Index)
          .Durability <
        100 then
         Profit :=
           Positive
             (Float'Floor
                (Float(Profit) *
                 (Float
                    (Inventory_Container.Element
                       (Container => Player_Ship.Cargo, Index => Item_Index)
                       .Durability) /
                  100.0)));
      end if;
      Count_Price
        (Price => Profit, Trader_Index => Trader_Index, Reduce => False);
      Pay_Trade_Profit_Loop :
      for I in Player_Ship.Crew.Iterate loop
         if Player_Ship.Crew(I).Payment(2) = 0 then
            goto End_Of_Loop;
         end if;
         if Profit < 1 then
            Update_Morale
              (Ship => Player_Ship,
               Member_Index => Crew_Container.To_Index(Position => I),
               Amount => Get_Random(Min => -25, Max => -5));
            Add_Message
              (Message =>
                 To_String(Source => Player_Ship.Crew(I).Name) &
                 " is sad because doesn't get own part of profit.",
               M_Type => TRADEMESSAGE, Color => RED);
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
               Update_Morale
                 (Ship => Player_Ship,
                  Member_Index => Crew_Container.To_Index(Position => I),
                  Amount => Get_Random(Min => -12, Max => -2));
               Add_Message
                 (Message =>
                    To_String(Source => Player_Ship.Crew(I).Name) &
                    " is sad because doesn't get own part of profit.",
                  M_Type => TRADEMESSAGE, Color => RED);
            end if;
            Profit := 0;
         end if;
         <<End_Of_Loop>>
      end loop Pay_Trade_Profit_Loop;
      if Free_Cargo
          (Amount =>
             (Get_Proto_Item(Index => Proto_Index).Weight * Sell_Amount) -
             Profit) <
        0 then
         raise Trade_No_Free_Cargo;
      end if;
      if Base_Index > 0 then
         if Profit >
           BaseCargo_Container.Element
             (Container => Sky_Bases(Base_Index).Cargo, Index => 1)
             .Amount then
            raise Trade_No_Money_In_Base with Item_Name;
         end if;
         Update_Base_Cargo
           (Proto_Index => Proto_Index, Amount => Sell_Amount,
            Durability =>
              Inventory_Container.Element
                (Container => Player_Ship.Cargo, Index => Item_Index)
                .Durability);
      else
         if Profit >
           BaseCargo_Container.Element(Container => Trader_Cargo, Index => 1)
             .Amount then
            raise Trade_No_Money_In_Base with Item_Name;
         end if;
         Update_Trader_Cargo_Loop :
         for I in
           BaseCargo_Container.First_Index(Container => Trader_Cargo) ..
             BaseCargo_Container.Last_Index(Container => Trader_Cargo) loop
            Item :=
              BaseCargo_Container.Element
                (Container => Trader_Cargo, Index => I);
            if Item.Proto_Index = Proto_Index and
              Item.Durability =
                Inventory_Container.Element
                  (Container => Player_Ship.Cargo, Index => Item_Index)
                  .Durability then
               Item.Amount := Item.Amount + Sell_Amount;
               BaseCargo_Container.Replace_Element
                 (Container => Trader_Cargo, Index => I, New_Item => Item);
               Cargo_Added := True;
               exit Update_Trader_Cargo_Loop;
            end if;
         end loop Update_Trader_Cargo_Loop;
         if not Cargo_Added then
            BaseCargo_Container.Append
              (Container => Trader_Cargo,
               New_Item =>
                 (Proto_Index => Proto_Index, Amount => Sell_Amount,
                  Durability =>
                    Inventory_Container.Element
                      (Container => Player_Ship.Cargo, Index => Item_Index)
                      .Durability,
                  Price => Get_Proto_Item(Index => Proto_Index).Price));
         end if;
      end if;
      Update_Cargo
        (Ship => Player_Ship, Cargo_Index => Item_Index,
         Amount => (0 - Sell_Amount),
         Price =>
           Inventory_Container.Element
             (Container => Player_Ship.Cargo, Index => Item_Index)
             .Price);
      Update_Cargo
        (Ship => Player_Ship, Proto_Index => Money_Index, Amount => Profit);
      if Base_Index > 0 then
         Update_Base_Cargo(Proto_Index => Money_Index, Amount => -(Profit));
         Gain_Rep(Base_Index => Base_Index, Points => 1);
         if Get_Proto_Item(Index => Proto_Index).Reputation >
           Sky_Bases(Base_Index).Reputation.Level then
            Gain_Rep(Base_Index => Base_Index, Points => 1);
         end if;
      else
         Item :=
           BaseCargo_Container.Element(Container => Trader_Cargo, Index => 1);
         Item.Amount := Item.Amount - Profit;
         BaseCargo_Container.Replace_Element
           (Container => Trader_Cargo, Index => 1, New_Item => Item);
      end if;
      Gain_Exp
        (Amount => 1, Skill_Number => Talking_Skill,
         Crew_Index => Trader_Index);
      Show_Log_Block :
      declare
         Gain: constant Integer := Profit - (Sell_Amount * Price);
      begin
         Add_Message
           (Message =>
              "You sold" & Positive'Image(Sell_Amount) & " " & Item_Name &
              " for" & Positive'Image(Profit) & " " &
              To_String(Source => Money_Name) & "." &
              (if Gain = 0 then ""
               else " You " & (if Gain > 0 then "gain" else "lost") &
                 Integer'Image(abs (Gain)) & " " &
                 To_String(Source => Money_Name) &
                 " compared to the base price."),
            M_Type => TRADEMESSAGE);
      end Show_Log_Block;
      if Base_Index = 0 and Event_Index > 0 then
         Events_List(Event_Index).Time := Events_List(Event_Index).Time + 5;
      end if;
      Update_Game(Minutes => 5);
   exception
      when Constraint_Error =>
         raise Trade_Invalid_Amount;
   end Sell_Items;

   procedure Generate_Trader_Cargo(Proto_Index: Positive) is
      use Tiny_String;

      Trader_Ship: Ship_Record :=
        Create_Ship
          (Proto_Index => Proto_Index, Name => Null_Bounded_String,
           X => Player_Ship.Sky_X, Y => Player_Ship.Sky_Y, Speed => FULL_STOP);
      Cargo_Amount: Natural range 0 .. 10 :=
        (if Trader_Ship.Crew.Length < 5 then Get_Random(Min => 1, Max => 3)
         elsif Trader_Ship.Crew.Length < 10 then Get_Random(Min => 1, Max => 5)
         else Get_Random(Min => 1, Max => 10));
      Cargo_Item_Index, Item_Index: Inventory_Container.Extended_Index;
      Item_Amount: Positive range 1 .. 1_000;
      New_Item_Index: Natural;
      Item: Inventory_Data;
      Trader_Item: Base_Cargo;
   begin
      BaseCargo_Container.Clear(Container => Trader_Cargo);
      Add_Items_To_Cargo_Loop :
      for Item of Trader_Ship.Cargo loop
         BaseCargo_Container.Append
           (Container => Trader_Cargo,
            New_Item =>
              (Proto_Index => Item.Proto_Index, Amount => Item.Amount,
               Durability => 100,
               Price => Get_Proto_Item(Index => Item.Proto_Index).Price));
      end loop Add_Items_To_Cargo_Loop;
      Generate_Cargo_Loop :
      while Cargo_Amount > 0 loop
         Item_Amount :=
           (if Trader_Ship.Crew.Length < 5 then
              Get_Random(Min => 1, Max => 100)
            elsif Trader_Ship.Crew.Length < 10 then
              Get_Random(Min => 1, Max => 500)
            else Get_Random(Min => 1, Max => 1_000));
         Item_Index := Get_Random(Min => 1, Max => Get_Proto_Amount);
         Find_Item_Index_Loop :
         for I in 1 .. Get_Proto_Amount loop
            Item_Index := Item_Index - 1;
            if Item_Index = 0 then
               New_Item_Index := I;
               exit Find_Item_Index_Loop;
            end if;
         end loop Find_Item_Index_Loop;
         Cargo_Item_Index :=
           Find_Item
             (Inventory => Trader_Ship.Cargo, Proto_Index => New_Item_Index);
         if Cargo_Item_Index > 0 then
            Trader_Item :=
              BaseCargo_Container.Element
                (Container => Trader_Cargo, Index => Cargo_Item_Index);
            Trader_Item.Amount := Trader_Item.Amount + Item_Amount;
            BaseCargo_Container.Replace_Element
              (Container => Trader_Cargo, Index => Cargo_Item_Index,
               New_Item => Trader_Item);
            Item :=
              Inventory_Container.Element
                (Container => Trader_Ship.Cargo, Index => Cargo_Item_Index);
            Item.Amount := Item.Amount + Item_Amount;
            Inventory_Container.Replace_Element
              (Container => Trader_Ship.Cargo, Index => Cargo_Item_Index,
               New_Item => Item);
         else
            if Free_Cargo
                (Amount =>
                   0 -
                   (Get_Proto_Item(Index => New_Item_Index).Weight *
                    Item_Amount)) >
              -1 then
               BaseCargo_Container.Append
                 (Container => Trader_Cargo,
                  New_Item =>
                    (Proto_Index => New_Item_Index, Amount => Item_Amount,
                     Durability => 100,
                     Price => Get_Proto_Item(Index => New_Item_Index).Price));
               Inventory_Container.Append
                 (Container => Trader_Ship.Cargo,
                  New_Item =>
                    (Proto_Index => New_Item_Index, Amount => Item_Amount,
                     Durability => 100, Name => Null_Bounded_String,
                     Price => 0));
            else
               Cargo_Amount := 1;
            end if;
         end if;
         Cargo_Amount := Cargo_Amount - 1;
      end loop Generate_Cargo_Loop;
   end Generate_Trader_Cargo;

end Trades;
