--    Copyright 2018 Bartek thindil Jasicki
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
with Ada.Exceptions; use Ada.Exceptions;
with Ada.Characters.Latin_1; use Ada.Characters.Latin_1;
with Gtk.Widget; use Gtk.Widget;
with Gtk.Label; use Gtk.Label;
with Gtk.Tree_Model; use Gtk.Tree_Model;
with Gtk.List_Store; use Gtk.List_Store;
with Gtk.Tree_View; use Gtk.Tree_View;
with Gtk.Tree_View_Column; use Gtk.Tree_View_Column;
with Gtk.Tree_Selection; use Gtk.Tree_Selection;
with Gtk.Adjustment; use Gtk.Adjustment;
with Gtk.Window; use Gtk.Window;
with Gtk.Stack; use Gtk.Stack;
with Glib; use Glib;
with Glib.Object; use Glib.Object;
with Game; use Game;
with Maps; use Maps;
with Maps.UI; use Maps.UI;
with Ships; use Ships;
with Ships.Cargo; use Ships.Cargo;
with Events; use Events;
with Items; use Items;
with Bases.Cargo; use Bases.Cargo;
with Utils.UI; use Utils.UI;

package body Trades.UI is

   Builder: Gtkada_Builder;

   procedure CloseTrade(Object: access Gtkada_Builder_Record'Class) is
      BaseIndex: constant Natural :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex;
      EventIndex: constant Natural :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).EventIndex;
   begin
      if BaseIndex = 0 and EventIndex > 0 then
         DeleteEvent(EventIndex);
      end if;
      ShowSkyMap;
      Set_Visible_Child_Name
        (Gtk_Stack(Get_Object(Object, "gamestack")), "skymap");
   end CloseTrade;

   procedure ShowItemTradeInfo(Object: access Gtkada_Builder_Record'Class) is
      ItemsIter: Gtk_Tree_Iter;
      ItemsModel: Gtk_Tree_Model;
      ItemInfo: Unbounded_String;
      ProtoIndex, Price: Positive;
      CargoIndex, BaseCargoIndex, BaseCargoIndex2: Natural := 0;
      BaseIndex: constant Natural :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex;
      BaseType: Positive;
      EventIndex: constant Natural :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).EventIndex;
      MoneyIndex2, MaxAmount: Natural;
      FreeSpace: Integer;
      AmountAdj2: constant Gtk_Adjustment :=
        Gtk_Adjustment(Get_Object(Builder, "amountadj1"));
      AmountAdj: constant Gtk_Adjustment :=
        Gtk_Adjustment(Get_Object(Builder, "amountadj"));
   begin
      Get_Selected
        (Gtk.Tree_View.Get_Selection
           (Gtk_Tree_View(Get_Object(Object, "treeitems1"))),
         ItemsModel, ItemsIter);
      if ItemsIter = Null_Iter then
         return;
      end if;
      if BaseIndex > 0 then
         BaseType := Bases_Types'Pos(SkyBases(BaseIndex).BaseType) + 1;
      else
         BaseType := 1;
      end if;
      CargoIndex := Natural(Get_Int(ItemsModel, ItemsIter, 1));
      if CargoIndex > Natural(PlayerShip.Cargo.Length) then
         return;
      end if;
      BaseCargoIndex := Natural(Get_Int(ItemsModel, ItemsIter, 2));
      if BaseIndex = 0 and BaseCargoIndex > Natural(TraderCargo.Length) then
         return;
      elsif BaseCargoIndex > Natural(SkyBases(BaseIndex).Cargo.Length) then
         return;
      end if;
      if CargoIndex > 0 then
         ProtoIndex := PlayerShip.Cargo(CargoIndex).ProtoIndex;
         if BaseCargoIndex = 0 then
            BaseCargoIndex2 := FindBaseCargo(ProtoIndex);
         end if;
      else
         if BaseIndex = 0 then
            ProtoIndex := TraderCargo(BaseCargoIndex).ProtoIndex;
         else
            ProtoIndex := SkyBases(BaseIndex).Cargo(BaseCargoIndex).ProtoIndex;
         end if;
      end if;
      if BaseCargoIndex = 0 then
         if BaseCargoIndex2 > 0 then
            if BaseIndex > 0 then
               Price := SkyBases(BaseIndex).Cargo(BaseCargoIndex2).Price;
            else
               Price := TraderCargo(BaseCargoIndex2).Price;
            end if;
         else
            Price := Items_List(ProtoIndex).Prices(BaseType);
         end if;
      else
         if BaseIndex > 0 then
            Price := SkyBases(BaseIndex).Cargo(BaseCargoIndex).Price;
         else
            Price := TraderCargo(BaseCargoIndex).Price;
         end if;
      end if;
      if EventIndex > 0 then
         if Events_List(EventIndex).EType = DoublePrice and
           Events_List(EventIndex).Data = ProtoIndex then
            Price := Price * 2;
         end if;
      end if;
      Append
        (ItemInfo,
         "Weight:" & Integer'Image(Items_List(ProtoIndex).Weight) & " kg");
      if Items_List(ProtoIndex).IType = WeaponType then
         Append
           (ItemInfo,
            LF & "Skill: " &
            To_String(Skills_List(Items_List(ProtoIndex).Value(3)).Name) &
            "/" &
            To_String
              (Attributes_List
                 (Skills_List(Items_List(ProtoIndex).Value(3)).Attribute)
                 .Name));
         if Items_List(ProtoIndex).Value(4) = 1 then
            Append(ItemInfo, LF & "Can be used with shield.");
         else
            Append
              (ItemInfo,
               LF & "Can't be used with shield (two-handed weapon).");
         end if;
         Append(ItemInfo, LF & "Damage type: ");
         case Items_List(ProtoIndex).Value(5) is
            when 1 =>
               Append(ItemInfo, "cutting");
            when 2 =>
               Append(ItemInfo, "impaling");
            when 3 =>
               Append(ItemInfo, "blunt");
            when others =>
               null;
         end case;
      end if;
      if Items_List(ProtoIndex).Description /= Null_Unbounded_String then
         Append
           (ItemInfo, LF & LF & To_String(Items_List(ProtoIndex).Description));
      end if;
      Set_Label
        (Gtk_Label(Get_Object(Object, "lbltradeinfo")), To_String(ItemInfo));
      if CargoIndex = 0 then
         Hide(Gtk_Widget(Get_Object(Object, "sellbox")));
         Hide(Gtk_Widget(Get_Object(Object, "sellbox2")));
      else
         Show_All(Gtk_Widget(Get_Object(Object, "sellbox")));
         Show_All(Gtk_Widget(Get_Object(Object, "sellbox2")));
         Set_Value(AmountAdj, 1.0);
         MaxAmount := PlayerShip.Cargo(CargoIndex).Amount;
         if BaseIndex > 0 then
            if MaxAmount > (SkyBases(BaseIndex).Cargo(1).Amount / Price) then
               MaxAmount := SkyBases(BaseIndex).Cargo(1).Amount / Price;
            end if;
         else
            if MaxAmount > (TraderCargo(1).Amount / Price) then
               MaxAmount := TraderCargo(1).Amount / Price;
            end if;
         end if;
         Set_Upper(AmountAdj, Gdouble(MaxAmount));
         Set_Label
           (Gtk_Label(Get_Object(Builder, "lblsellamount")),
            "(max" & Natural'Image(MaxAmount) & "):");
      end if;
      MoneyIndex2 := FindItem(PlayerShip.Cargo, FindProtoItem(MoneyIndex));
      if BaseCargoIndex = 0 or MoneyIndex2 = 0 or
        not Items_List(ProtoIndex).Buyable(BaseType) then
         Hide(Gtk_Widget(Get_Object(Object, "buybox")));
      else
         if BaseIndex > 0 then
            if SkyBases(BaseIndex).Cargo(BaseCargoIndex).Amount > 0 then
               Show_All(Gtk_Widget(Get_Object(Object, "buybox")));
            else
               Hide(Gtk_Widget(Get_Object(Object, "buybox")));
            end if;
         else
            if TraderCargo(BaseCargoIndex).Amount > 0 then
               Show_All(Gtk_Widget(Get_Object(Object, "buybox")));
            else
               Hide(Gtk_Widget(Get_Object(Object, "buybox")));
            end if;
         end if;
         if Is_Visible(Gtk_Widget(Get_Object(Object, "buybox"))) then
            Set_Value(AmountAdj2, 1.0);
            MaxAmount := PlayerShip.Cargo(MoneyIndex2).Amount / Price;
            if BaseIndex > 0 then
               if MaxAmount >
                 SkyBases(BaseIndex).Cargo(BaseCargoIndex).Amount then
                  MaxAmount :=
                    SkyBases(BaseIndex).Cargo(BaseCargoIndex).Amount;
               end if;
            else
               if MaxAmount > TraderCargo(BaseCargoIndex).Amount then
                  MaxAmount := TraderCargo(BaseCargoIndex).Amount;
               end if;
            end if;
            Set_Upper(AmountAdj2, Gdouble(MaxAmount));
            Set_Label
              (Gtk_Label(Get_Object(Builder, "lblbuyamount")),
               "(max" & Natural'Image(MaxAmount) & "):");
         end if;
      end if;
      if MoneyIndex2 > 0 then
         Set_Label
           (Gtk_Label(Get_Object(Object, "lblshipmoney")),
            "You have" & Natural'Image(PlayerShip.Cargo(MoneyIndex2).Amount) &
            " " & To_String(MoneyName) & ".");
      else
         Set_Label
           (Gtk_Label(Get_Object(Object, "lblshipmoney")),
            "You don't have any " & To_String(MoneyName) &
            " to buy anything.");
      end if;
      FreeSpace := FreeCargo(0);
      if FreeSpace < 0 then
         FreeSpace := 0;
      end if;
      Set_Label
        (Gtk_Label(Get_Object(Object, "lblshipspace1")),
         "Free cargo space:" & Integer'Image(FreeSpace) & " kg");
      if BaseIndex > 0 then
         if SkyBases(BaseIndex).Cargo(1).Amount = 0 then
            Set_Label
              (Gtk_Label(Get_Object(Object, "lblbasemoney")),
               "Base don't have any " & To_String(MoneyName) &
               "to buy anything.");
         else
            Set_Label
              (Gtk_Label(Get_Object(Object, "lblbasemoney")),
               "Base have" &
               Positive'Image(SkyBases(BaseIndex).Cargo(1).Amount) & " " &
               To_String(MoneyName) & ".");
         end if;
      else
         if TraderCargo(1).Amount = 0 then
            Set_Label
              (Gtk_Label(Get_Object(Object, "lblbasemoney")),
               "Ship don't have any " & To_String(MoneyName) &
               "to buy anything.");
         else
            Set_Label
              (Gtk_Label(Get_Object(Object, "lblbasemoney")),
               "Ship have" & Positive'Image(TraderCargo(1).Amount) & " " &
               To_String(MoneyName) & ".");
         end if;
      end if;
   end ShowItemTradeInfo;

   procedure TradeItem(User_Data: access GObject_Record'Class) is
      ItemsIter: Gtk_Tree_Iter;
      ItemsModel: Gtk_Tree_Model;
      BaseIndex: constant Natural :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex;
      BaseCargoIndex, CargoIndex: Natural := 0;
      Trader: String(1 .. 4);
      Amount: Natural;
   begin
      Get_Selected
        (Gtk.Tree_View.Get_Selection
           (Gtk_Tree_View(Get_Object(Builder, "treeitems1"))),
         ItemsModel, ItemsIter);
      if ItemsIter = Null_Iter then
         return;
      end if;
      CargoIndex := Natural(Get_Int(ItemsModel, ItemsIter, 1));
      BaseCargoIndex := Natural(Get_Int(ItemsModel, ItemsIter, 2));
      if BaseIndex > 0 then
         Trader := "base";
      else
         Trader := "ship";
      end if;
      if User_Data = Get_Object(Builder, "btnbuyitem") then
         Amount :=
           Natural
             (Get_Value(Gtk_Adjustment(Get_Object(Builder, "amountadj1"))));
         BuyItems(BaseCargoIndex, Natural'Image(Amount));
      else
         Amount :=
           Natural
             (Get_Value(Gtk_Adjustment(Get_Object(Builder, "amountadj"))));
         if User_Data = Get_Object(Builder, "btnsellitem") then
            SellItems(CargoIndex, Natural'Image(Amount));
         else
            SellItems
              (CargoIndex,
               Positive'Image(PlayerShip.Cargo.Element(CargoIndex).Amount));
         end if;
      end if;
      ShowTradeUI;
   exception
      when An_Exception : Trade_Cant_Buy =>
         ShowDialog
           ("You can't buy " & Exception_Message(An_Exception) & " in this " &
            Trader & ".",
            Gtk_Window(Get_Object(Builder, "skymapwindow")));
      when An_Exception : Trade_Not_For_Sale_Now =>
         ShowDialog
           ("You can't buy " & Exception_Message(An_Exception) &
            " in this base at this moment.",
            Gtk_Window(Get_Object(Builder, "skymapwindow")));
      when An_Exception : Trade_Buying_Too_Much =>
         ShowDialog
           (Trader & " don't have that much " &
            Exception_Message(An_Exception) & " for sale.",
            Gtk_Window(Get_Object(Builder, "skymapwindow")));
      when Trade_No_Free_Cargo =>
         ShowDialog
           ("You don't have that much free space in your ship cargo.",
            Gtk_Window(Get_Object(Builder, "skymapwindow")));
      when An_Exception : Trade_No_Money =>
         ShowDialog
           ("You don't have any " & To_String(MoneyName) & " to buy " &
            Exception_Message(An_Exception) & ".",
            Gtk_Window(Get_Object(Builder, "skymapwindow")));
      when An_Exception : Trade_Not_Enough_Money =>
         ShowDialog
           ("You don't have enough " & To_String(MoneyName) &
            " to buy so much " & Exception_Message(An_Exception) & ".",
            Gtk_Window(Get_Object(Builder, "skymapwindow")));
      when Trade_Invalid_Amount =>
         if User_Data = Get_Object(Builder, "btnbuyitem") then
            ShowDialog
              ("You entered invalid amount to buy.",
               Gtk_Window(Get_Object(Builder, "skymapwindow")));
         else
            ShowDialog
              ("You entered invalid amount to sell.",
               Gtk_Window(Get_Object(Builder, "skymapwindow")));
         end if;
      when An_Exception : Trade_Too_Much_For_Sale =>
         ShowDialog
           ("You dont have that much " & Exception_Message(An_Exception) &
            " in ship cargo.",
            Gtk_Window(Get_Object(Builder, "skymapwindow")));
      when An_Exception : Trade_No_Money_In_Base =>
         ShowDialog
           ("You can't sell so much " & Exception_Message(An_Exception) &
            " because " & Trader & " don't have that much " &
            To_String(MoneyName) & " to buy it.",
            Gtk_Window(Get_Object(Builder, "skymapwindow")));
      when Trade_No_Trader =>
         ShowDialog
           ("You don't have assigned anyone in crew to talk in bases duty.",
            Gtk_Window(Get_Object(Builder, "skymapwindow")));
   end TradeItem;

   procedure CreateTradeUI(NewBuilder: Gtkada_Builder) is
   begin
      Builder := NewBuilder;
      Register_Handler
        (Builder, "Show_Item_Trade_Info", ShowItemTradeInfo'Access);
      Register_Handler(Builder, "Trade_Item", TradeItem'Access);
      Register_Handler(Builder, "Close_Trade", CloseTrade'Access);
      On_Key_Press_Event
        (Gtk_Widget(Get_Object(Builder, "spintradebuy")), SelectElement'Access,
         Get_Object(Builder, "btnbuyitem"));
      On_Key_Press_Event
        (Gtk_Widget(Get_Object(Builder, "spintradesell")),
         SelectElement'Access, Get_Object(Builder, "btnsellitem"));
   end CreateTradeUI;

   procedure ShowTradeUI is
      ItemsIter: Gtk_Tree_Iter;
      ItemsList: constant Gtk_List_Store :=
        Gtk_List_Store(Get_Object(Builder, "itemslist1"));
      BaseIndex: constant Natural :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex;
      BaseType, ProtoIndex, Price: Positive;
      IndexesList: Positive_Container.Vector;
      BaseCargoIndex: Natural;
      BaseCargo: BaseCargo_Container.Vector;
      Visible: Boolean := False;
      EventIndex: constant Natural :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).EventIndex;
   begin
      if BaseIndex > 0 then
         BaseType := Bases_Types'Pos(SkyBases(BaseIndex).BaseType) + 1;
         BaseCargo := SkyBases(BaseIndex).Cargo;
      else
         BaseType := 1;
         BaseCargo := TraderCargo;
      end if;
      Clear(ItemsList);
      for I in PlayerShip.Cargo.Iterate loop
         if Items_List(PlayerShip.Cargo(I).ProtoIndex).Prices(BaseType) >
           0 then
            Append(ItemsList, ItemsIter);
            Set
              (ItemsList, ItemsIter, 0,
               GetItemName(PlayerShip.Cargo(I), False));
            Set
              (ItemsList, ItemsIter, 1, Gint(Inventory_Container.To_Index(I)));
            ProtoIndex := PlayerShip.Cargo(I).ProtoIndex;
            BaseCargoIndex :=
              FindBaseCargo(ProtoIndex, PlayerShip.Cargo(I).Durability);
            if BaseCargoIndex > 0 then
               IndexesList.Append(New_Item => BaseCargoIndex);
            end if;
            Set(ItemsList, ItemsIter, 2, Gint(BaseCargoIndex));
            if Items_List(ProtoIndex).ShowType = Null_Unbounded_String then
               Set
                 (ItemsList, ItemsIter, 3,
                  To_String(Items_List(ProtoIndex).IType));
            else
               Set
                 (ItemsList, ItemsIter, 3,
                  To_String(Items_List(ProtoIndex).ShowType));
            end if;
            if PlayerShip.Cargo(I).Durability < 100 then
               Set
                 (ItemsList, ItemsIter, 9,
                  " " & GetItemDamage(PlayerShip.Cargo(I).Durability) & " ");
               Set(ItemsList, ItemsIter, 10, True);
               Visible := True;
            end if;
            Set(ItemsList, ItemsIter, 4, Gint(PlayerShip.Cargo(I).Durability));
            if BaseCargoIndex = 0 then
               Price := Items_List(ProtoIndex).Prices(BaseType);
            else
               if BaseIndex > 0 then
                  Price := SkyBases(BaseIndex).Cargo(BaseCargoIndex).Price;
               else
                  Price := TraderCargo(BaseCargoIndex).Price;
               end if;
            end if;
            if EventIndex > 0 then
               if Events_List(EventIndex).EType = DoublePrice and
                 Events_List(EventIndex).Data = ProtoIndex then
                  Price := Price * 2;
               end if;
            end if;
            Set(ItemsList, ItemsIter, 5, Gint(Price));
            Set
              (ItemsList, ItemsIter, 6,
               Gint(Price - PlayerShip.Cargo(I).Price));
            Set(ItemsList, ItemsIter, 7, Gint(PlayerShip.Cargo(I).Amount));
            if BaseCargoIndex > 0 and
              Items_List(ProtoIndex).Buyable(BaseType) then
               if BaseIndex = 0 then
                  Set
                    (ItemsList, ItemsIter, 8,
                     Gint(TraderCargo(BaseCargoIndex).Amount));
               else
                  Set
                    (ItemsList, ItemsIter, 8,
                     Gint(SkyBases(BaseIndex).Cargo(BaseCargoIndex).Amount));
               end if;
            end if;
         end if;
      end loop;
      Set_Visible
        (Gtk_Tree_View_Column(Get_Object(Builder, "columntradedurability")),
         Visible);
      for I in BaseCargo.First_Index .. BaseCargo.Last_Index loop
         if IndexesList.Find_Index(Item => I) = 0 and
           Items_List(BaseCargo(I).ProtoIndex).Buyable(BaseType) then
            Append(ItemsList, ItemsIter);
            ProtoIndex := BaseCargo(I).ProtoIndex;
            Set
              (ItemsList, ItemsIter, 0,
               To_String(Items_List(ProtoIndex).Name));
            Set(ItemsList, ItemsIter, 1, 0);
            Set(ItemsList, ItemsIter, 2, Gint(I));
            if Items_List(ProtoIndex).ShowType = Null_Unbounded_String then
               Set
                 (ItemsList, ItemsIter, 3,
                  To_String(Items_List(ProtoIndex).IType));
            else
               Set
                 (ItemsList, ItemsIter, 3,
                  To_String(Items_List(ProtoIndex).ShowType));
            end if;
            if BaseCargo(I).Durability < 100 then
               Set
                 (ItemsList, ItemsIter, 9,
                  " " & GetItemDamage(BaseCargo(I).Durability) & " ");
               Set(ItemsList, ItemsIter, 10, True);
               Visible := True;
            end if;
            Set(ItemsList, ItemsIter, 4, Gint(BaseCargo(I).Durability));
            if BaseIndex > 0 then
               Price := SkyBases(BaseIndex).Cargo(I).Price;
            else
               Price := TraderCargo(I).Price;
            end if;
            if EventIndex > 0 then
               if Events_List(EventIndex).EType = DoublePrice and
                 Events_List(EventIndex).Data = ProtoIndex then
                  Price := Price * 2;
               end if;
            end if;
            Set(ItemsList, ItemsIter, 5, Gint(Price));
            Set(ItemsList, ItemsIter, 6, Gint(0 - Price));
            if BaseIndex = 0 then
               Set(ItemsList, ItemsIter, 8, Gint(TraderCargo(I).Amount));
            else
               Set
                 (ItemsList, ItemsIter, 8,
                  Gint(SkyBases(BaseIndex).Cargo(I).Amount));
            end if;
         end if;
      end loop;
      Set_Visible_Child_Name
        (Gtk_Stack(Get_Object(Builder, "gamestack")), "trade");
      Set_Cursor
        (Gtk_Tree_View(Get_Object(Builder, "treeitems1")),
         Gtk_Tree_Path_New_From_String("0"),
         Gtk_Tree_View_Column(Get_Object(Builder, "columnname3")), False);
      ShowLastMessage(Builder);
   end ShowTradeUI;

end Trades.UI;
