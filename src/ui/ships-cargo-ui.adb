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

with Gtk.Widget; use Gtk.Widget;
with Gtk.Tree_View; use Gtk.Tree_View;
with Gtk.Tree_Model; use Gtk.Tree_Model;
with Gtk.Tree_View_Column; use Gtk.Tree_View_Column;
with Gtk.List_Store; use Gtk.List_Store;
with Gtk.Label; use Gtk.Label;
with Gtk.Tree_Selection; use Gtk.Tree_Selection;
with Gtk.Adjustment; use Gtk.Adjustment;
with Gtk.Combo_Box; use Gtk.Combo_Box;
with Gtk.Combo_Box_Text; use Gtk.Combo_Box_Text;
with Gtk.Window; use Gtk.Window;
with Gtk.Stack; use Gtk.Stack;
with Glib; use Glib;
with Glib.Object; use Glib.Object;
with Messages; use Messages;
with Crew.Inventory; use Crew.Inventory;
with Stories; use Stories;
with Missions; use Missions;
with Utils.UI; use Utils.UI;

package body Ships.Cargo.UI is

   Builder: Gtkada_Builder;
   ItemIndex: Positive;

   procedure RefreshCargoInfo is
      CargoIter: Gtk_Tree_Iter;
      CargoList: constant Gtk_List_Store :=
        Gtk_List_Store(Get_Object(Builder, "cargolist"));
      ProtoIndex, ItemWeight: Positive;
      Visible: Boolean := False;
   begin
      Clear(CargoList);
      for I in PlayerShip.Cargo.Iterate loop
         Append(CargoList, CargoIter);
         Set(CargoList, CargoIter, 0, GetItemName(PlayerShip.Cargo(I), False));
         Set(CargoList, CargoIter, 1, Gint(Inventory_Container.To_Index(I)));
         ProtoIndex := PlayerShip.Cargo(I).ProtoIndex;
         if Items_List(ProtoIndex).ShowType = Null_Unbounded_String then
            Set
              (CargoList, CargoIter, 2,
               To_String(Items_List(ProtoIndex).IType));
         else
            Set
              (CargoList, CargoIter, 2,
               To_String(Items_List(ProtoIndex).ShowType));
         end if;
         Set(CargoList, CargoIter, 3, Gint(PlayerShip.Cargo(I).Amount));
         ItemWeight :=
           PlayerShip.Cargo(I).Amount * Items_List(ProtoIndex).Weight;
         Set(CargoList, CargoIter, 4, Gint(ItemWeight));
         if PlayerShip.Cargo(I).Durability < 100 then
            Set
              (CargoList, CargoIter, 5,
               " " & GetItemDamage(PlayerShip.Cargo(I).Durability) & " ");
            Set(CargoList, CargoIter, 7, True);
            Visible := True;
         else
            Set(CargoList, CargoIter, 7, False);
         end if;
         Set(CargoList, CargoIter, 6, Gint(PlayerShip.Cargo(I).Durability));
      end loop;
      Set_Visible
        (Gtk_Tree_View_Column(Get_Object(Builder, "columncargodurability")),
         Visible);
      Set_Label
        (Gtk_Label(Get_Object(Builder, "lblfreespace")),
         "Free cargo space:" & Integer'Image(FreeCargo(0)) & " kg");
   end RefreshCargoInfo;

   procedure SetActiveItem is
   begin
      if PlayerShip.Cargo.Length > 0 then
         Set_Cursor
           (Gtk_Tree_View(Get_Object(Builder, "treecargo")),
            Gtk_Tree_Path_New_From_String("0"),
            Gtk_Tree_View_Column(Get_Object(Builder, "columncargo")), False);
      end if;
   end SetActiveItem;

   procedure ShowItemCargoInfo(Object: access Gtkada_Builder_Record'Class) is
      CargoIter: Gtk_Tree_Iter;
      CargoModel: Gtk_Tree_Model;
      AmountAdj: constant Gtk_Adjustment :=
        Gtk_Adjustment(Get_Object(Object, "amountadj"));
      AmountAdj2: constant Gtk_Adjustment :=
        Gtk_Adjustment(Get_Object(Object, "amountadj1"));
   begin
      Get_Selected
        (Gtk.Tree_View.Get_Selection
           (Gtk_Tree_View(Get_Object(Object, "treecargo"))),
         CargoModel, CargoIter);
      if CargoIter = Null_Iter then
         return;
      end if;
      ItemIndex := Positive(Get_Int(CargoModel, CargoIter, 1));
      if ItemIndex > Positive(PlayerShip.Cargo.Length) then
         return;
      end if;
      ShowInventoryItemInfo
        (Gtk_Label(Get_Object(Object, "lbliteminfo2")), ItemIndex, 0);
      if Items_List(PlayerShip.Cargo(ItemIndex).ProtoIndex).IType =
        MissionItemsType then
         Hide(Gtk_Widget(Get_Object(Builder, "givebox")));
      else
         Show_All(Gtk_Widget(Get_Object(Builder, "givebox")));
      end if;
      Set_Upper(AmountAdj, Gdouble(PlayerShip.Cargo(ItemIndex).Amount));
      Set_Value(AmountAdj, 1.0);
      Set_Upper(AmountAdj2, Gdouble(PlayerShip.Cargo(ItemIndex).Amount));
      Set_Value(AmountAdj2, 1.0);
   end ShowItemCargoInfo;

   procedure DropItem(Object: access Gtkada_Builder_Record'Class) is
      DropAmount: Natural :=
        Natural(Get_Value(Gtk_Adjustment(Get_Object(Object, "amountadj"))));
      DropAmount2: constant Natural := DropAmount;
   begin
      if Items_List(PlayerShip.Cargo(ItemIndex).ProtoIndex).IType =
        MissionItemsType then
         for J in 1 .. DropAmount2 loop
            for I in
              AcceptedMissions.First_Index .. AcceptedMissions.Last_Index loop
               if AcceptedMissions(I).MType = Deliver and
                 AcceptedMissions(I).Target =
                   PlayerShip.Cargo(ItemIndex).ProtoIndex then
                  DeleteMission(I);
                  DropAmount := DropAmount - 1;
                  exit;
               end if;
            end loop;
         end loop;
      elsif CurrentStory.Index /= 0 then
         if Positive'Value
             (To_String(Stories_List(CurrentStory.Index).StartData(1))) =
           PlayerShip.Cargo(ItemIndex).ProtoIndex then
            FinishedStories.Delete(FinishedStories.Last_Index);
            ClearCurrentStory;
         end if;
      end if;
      if DropAmount > 0 then
         AddMessage
           ("You dropped" & Positive'Image(DropAmount) & " " &
            GetItemName(PlayerShip.Cargo(ItemIndex)) & ".",
            OtherMessage);
         UpdateCargo
           (Ship => PlayerShip,
            ProtoIndex => PlayerShip.Cargo.Element(ItemIndex).ProtoIndex,
            Amount => (0 - DropAmount),
            Durability => PlayerShip.Cargo.Element(ItemIndex).Durability,
            Price => PlayerShip.Cargo.Element(ItemIndex).Price);
      end if;
      RefreshCargoInfo;
      ShowLastMessage(Object);
      SetActiveItem;
   end DropItem;

   procedure GiveItem(Object: access Gtkada_Builder_Record'Class) is
      MemberIndex: constant Positive :=
        Positive
          (Get_Active(Gtk_Combo_Box(Get_Object(Object, "cmbmember"))) + 1);
      Amount: constant Positive :=
        Positive(Get_Value(Gtk_Adjustment(Get_Object(Object, "amountadj1"))));
      Item: constant InventoryData := PlayerShip.Cargo(ItemIndex);
   begin
      if FreeInventory
          (MemberIndex, 0 - (Items_List(Item.ProtoIndex).Weight * Amount)) <
        0 then
         ShowDialog
           ("No free space in " &
            To_String(PlayerShip.Crew(MemberIndex).Name) &
            "'s inventory for that amount of " & GetItemName(Item),
            Gtk_Window(Get_Object(Object, "giveitemwindow")));
         return;
      end if;
      UpdateInventory
        (MemberIndex => MemberIndex, Amount => Amount,
         ProtoIndex => Item.ProtoIndex, Durability => Item.Durability,
         Price => Item.Price);
      UpdateCargo
        (Ship => PlayerShip, Amount => (0 - Amount), CargoIndex => ItemIndex,
         Price => Item.Price);
      RefreshCargoInfo;
      ShowLastMessage(Object);
      SetActiveItem;
   end GiveItem;

   procedure CreateCargoUI(NewBuilder: Gtkada_Builder) is
   begin
      Builder := NewBuilder;
      Register_Handler
        (Builder, "Show_Item_Cargo_Info", ShowItemCargoInfo'Access);
      Register_Handler(Builder, "Drop_Item", DropItem'Access);
      Register_Handler(Builder, "Give_Item", GiveItem'Access);
      Register_Handler(Builder, "Hide_Item_Info", HideItemInfo'Access);
      On_Key_Press_Event
        (Gtk_Widget(Get_Object(Builder, "spincargodrop")),
         SelectElement'Access, Get_Object(Builder, "btndropitem"));
      On_Key_Press_Event
        (Gtk_Widget(Get_Object(Builder, "spincargogive")),
         SelectElement'Access, Get_Object(Builder, "cmbmember"));
   end CreateCargoUI;

   procedure ShowCargoUI is
      ComboBoxMember: constant Gtk_Combo_Box_Text :=
        Gtk_Combo_Box_Text(Get_Object(Builder, "cmbmember"));
   begin
      Remove_All(ComboBoxMember);
      for Member of PlayerShip.Crew loop
         Append_Text(ComboBoxMember, To_String(Member.Name));
      end loop;
      RefreshCargoInfo;
      Set_Visible_Child_Name
        (Gtk_Stack(Get_Object(Builder, "gamestack")), "cargo");
      ShowLastMessage(Builder);
      SetActiveItem;
      Set_Active(ComboBoxMember, 0);
   end ShowCargoUI;

end Ships.Cargo.UI;
