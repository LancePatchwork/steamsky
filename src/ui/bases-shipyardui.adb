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

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Exceptions; use Ada.Exceptions;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with Gtkada.Builder; use Gtkada.Builder;
with Gtk.Widget; use Gtk.Widget;
with Gtk.Label; use Gtk.Label;
with Gtk.Tree_Model; use Gtk.Tree_Model;
with Gtk.List_Store; use Gtk.List_Store;
with Gtk.Tree_View; use Gtk.Tree_View;
with Gtk.Tree_View_Column; use Gtk.Tree_View_Column;
with Gtk.Combo_Box; use Gtk.Combo_Box;
with Gtk.Tree_Selection; use Gtk.Tree_Selection;
with Gtk.Window; use Gtk.Window;
with Glib; use Glib;
with Glib.Error; use Glib.Error;
with Glib.Object; use Glib.Object;
with Game; use Game;
with Maps.UI; use Maps.UI;
with ShipModules; use ShipModules;
with Ships; use Ships;
with Ships.Crew; use Ships.Crew;
with Items; use Items;
with Bases.Ship; use Bases.Ship;
with Utils.UI; use Utils.UI;
with Trades; use Trades;

package body Bases.ShipyardUI is

   Builder: Gtkada_Builder;
   ModuleIndex: Positive;

   function HideShipyard
     (Object: access Gtkada_Builder_Record'Class) return Boolean is
   begin
      Hide(Gtk_Widget(Get_Object(Object, "shipyardwindow")));
      CreateSkyMap;
      return True;
   end HideShipyard;

   procedure SetInstallModulesList(ShowType: ModuleType) is
      ModulesList: Gtk_List_Store;
      procedure AddListItems(MType: ModuleType) is
         ModulesIter: Gtk_Tree_Iter;
      begin
         for I in Modules_List.Iterate loop
            if Modules_List(I).Price > 0 and Modules_List(I).MType = MType then
               Append(ModulesList, ModulesIter);
               Set
                 (ModulesList,
                  ModulesIter,
                  0,
                  To_String(Modules_List(I).Name));
               Set
                 (ModulesList,
                  ModulesIter,
                  1,
                  Gint(BaseModules_Container.To_Index(I)));
            end if;
         end loop;
      end AddListItems;
   begin
      ModulesList := Gtk_List_Store(Get_Object(Builder, "installmoduleslist"));
      Clear(ModulesList);
      if ShowType = ANY then
         for I in ModuleType'Range loop
            AddListItems(I);
         end loop;
      else
         AddListItems(ShowType);
      end if;
   end SetInstallModulesList;

   procedure SetActiveModule(TreeName, ColumnName: String) is
   begin
      Set_Cursor
        (Gtk_Tree_View(Get_Object(Builder, TreeName)),
         Gtk_Tree_Path_New_From_String("0"),
         Gtk_Tree_View_Column(Get_Object(Builder, ColumnName)),
         False);
   end SetActiveModule;

   procedure ChangeType(Object: access Gtkada_Builder_Record'Class) is
   begin
      SetInstallModulesList
        (ModuleType'Val
           (Natural
              (Get_Active(Gtk_Combo_Box(Get_Object(Object, "cmbtypes"))))));
      SetActiveModule("treeinstall", "columnname");
   end ChangeType;

   procedure ShowInstallInfo(Object: access Gtkada_Builder_Record'Class) is
      ModulesIter: Gtk_Tree_Iter;
      ModulesModel: Gtk_Tree_Model;
      ModuleInfo, InstallInfo: Unbounded_String;
      Cost: Positive;
      MAmount, MoneyIndex2, UsedSpace, AllSpace: Natural;
   begin
      Get_Selected
        (Gtk.Tree_View.Get_Selection
           (Gtk_Tree_View(Get_Object(Object, "treeinstall"))),
         ModulesModel,
         ModulesIter);
      if ModulesIter = Null_Iter then
         return;
      end if;
      ModuleIndex := Positive(Get_Int(ModulesModel, ModulesIter, 1));
      Cost := Modules_List(ModuleIndex).Price;
      CountPrice(Cost, FindMember(Talk));
      ModuleInfo :=
        To_Unbounded_String("Install cost:" & Positive'Image(Cost));
      Append
        (ModuleInfo,
         ASCII.LF &
         "Installation time:" &
         Positive'Image(Modules_List(ModuleIndex).InstallTime) &
         " minutes");
      case Modules_List(ModuleIndex).MType is
         when HULL =>
            Append(ModuleInfo, ASCII.LF & "Ship hull can be only replaced.");
            Append
              (ModuleInfo,
               ASCII.LF &
               "Modules space:" &
               Positive'Image(Modules_List(ModuleIndex).MaxValue));
         when ENGINE =>
            Append
              (ModuleInfo,
               ASCII.LF &
               "Max power:" &
               Positive'Image(Modules_List(ModuleIndex).MaxValue));
            Append
              (ModuleInfo,
               ASCII.LF &
               "Fuel usage:" &
               Positive'Image(Modules_List(ModuleIndex).Value));
         when ShipModules.CARGO =>
            Append
              (ModuleInfo,
               ASCII.LF &
               "Max cargo:" &
               Positive'Image(Modules_List(ModuleIndex).MaxValue) &
               " kg");
         when CABIN =>
            Append(ModuleInfo, ASCII.LF & "Quality: ");
            if Modules_List(ModuleIndex).MaxValue < 30 then
               Append(ModuleInfo, "minimal");
            elsif Modules_List(ModuleIndex).MaxValue > 29 and
              Modules_List(ModuleIndex).MaxValue < 60 then
               Append(ModuleInfo, "basic");
            elsif Modules_List(ModuleIndex).MaxValue > 59 and
              Modules_List(ModuleIndex).MaxValue < 80 then
               Append(ModuleInfo, "extended");
            else
               Append(ModuleInfo, "luxury");
            end if;
         when GUN | HARPOON_GUN =>
            Append(ModuleInfo, ASCII.LF & "Ammunition: ");
            MAmount := 0;
            for Item of Items_List loop
               if Item.IType =
                 Items_Types(Modules_List(ModuleIndex).Value) then
                  if MAmount > 0 then
                     Append(ModuleInfo, " or ");
                  end if;
                  Append(ModuleInfo, Item.Name);
                  MAmount := MAmount + 1;
               end if;
            end loop;
         when others =>
            null;
      end case;
      if Modules_List(ModuleIndex).Size > 0 then
         Append
           (ModuleInfo,
            ASCII.LF &
            "Size:" &
            Natural'Image(Modules_List(ModuleIndex).Size));
      end if;
      if Modules_List(ModuleIndex).Weight > 0 then
         Append
           (ModuleInfo,
            ASCII.LF &
            "Weight:" &
            Natural'Image(Modules_List(ModuleIndex).Weight) &
            " kg");
      end if;
      Append(ModuleInfo, ASCII.LF & "Repair/Upgrade material: ");
      MAmount := 0;
      for Item of Items_List loop
         if Item.IType = Modules_List(ModuleIndex).RepairMaterial then
            if MAmount > 0 then
               Append(ModuleInfo, " or ");
            end if;
            Append(ModuleInfo, Item.Name);
            MAmount := MAmount + 1;
         end if;
      end loop;
      Append
        (ModuleInfo,
         ASCII.LF &
         "Repair/Upgrade skill: " &
         To_String(Skills_List(Modules_List(ModuleIndex).RepairSkill).Name) &
         "/" &
         To_String
           (Attributes_Names
              (Skills_List(Modules_List(ModuleIndex).RepairSkill).Attribute)));
      if Modules_List(ModuleIndex).Description /= Null_Unbounded_String then
         Append
           (ModuleInfo,
            ASCII.LF & ASCII.LF & Modules_List(ModuleIndex).Description);
      end if;
      Set_Label
        (Gtk_Label(Get_Object(Object, "lblinstallinfo")),
         To_String(ModuleInfo));
      MoneyIndex2 := FindItem(PlayerShip.Cargo, FindProtoItem(MoneyIndex));
      if MoneyIndex2 > 0 then
         InstallInfo :=
           To_Unbounded_String
             (ASCII.LF &
              "You have" &
              Natural'Image(PlayerShip.Cargo(MoneyIndex2).Amount) &
              " " &
              To_String(MoneyName) &
              ".");
      else
         InstallInfo :=
           To_Unbounded_String
             (ASCII.LF &
              "You don't have any " &
              To_String(MoneyName) &
              " to install anything.");
      end if;
      for Module of PlayerShip.Modules loop
         if Modules_List(Module.ProtoIndex).MType = HULL then
            UsedSpace := Module.Data(1);
            AllSpace := Module.Data(2);
            Append
              (InstallInfo,
               ASCII.LF &
               "You have used" &
               Natural'Image(UsedSpace) &
               " modules space from max" &
               Natural'Image(AllSpace) &
               " allowed.");
            exit;
         end if;
      end loop;
      Set_Label
        (Gtk_Label(Get_Object(Object, "lblmoneyinstall")),
         To_String(InstallInfo));
      if MoneyIndex2 = 0 then
         Set_Sensitive(Gtk_Widget(Get_Object(Object, "btninstall")), False);
      else
         if PlayerShip.Cargo(MoneyIndex2).Amount < Cost or
           (AllSpace - UsedSpace) < Modules_List(ModuleIndex).Size then
            Set_Sensitive(Gtk_Widget(Get_Object(Object, "btninstall")), False);
         else
            Set_Sensitive(Gtk_Widget(Get_Object(Object, "btninstall")), True);
         end if;
      end if;
   end ShowInstallInfo;

   procedure ShowRemoveInfo(Object: access Gtkada_Builder_Record'Class) is
      ModulesIter: Gtk_Tree_Iter;
      ModulesModel: Gtk_Tree_Model;
      ModuleInfo, RemoveInfo: Unbounded_String;
      Cost: Positive;
      MAmount, MoneyIndex2, UsedSpace, AllSpace: Natural;
      type DamageFactor is digits 2 range 0.0 .. 1.0;
      Damage: DamageFactor := 0.0;
   begin
      Get_Selected
        (Gtk.Tree_View.Get_Selection
           (Gtk_Tree_View(Get_Object(Object, "treeremove"))),
         ModulesModel,
         ModulesIter);
      if ModulesIter = Null_Iter then
         return;
      end if;
      ModuleIndex := Positive(Get_Int(ModulesModel, ModulesIter, 1));
      if ModuleIndex > Positive(PlayerShip.Modules.Length) then
         return;
      end if;
      Damage :=
        1.0 -
        DamageFactor
          (Float(PlayerShip.Modules(ModuleIndex).Durability) /
           Float(PlayerShip.Modules(ModuleIndex).MaxDurability));
      Cost :=
        Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex).Price -
        Integer
          (Float
             (Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex).Price) *
           Float(Damage));
      CountPrice(Cost, FindMember(Talk), False);
      ModuleInfo := To_Unbounded_String("Remove gain:" & Positive'Image(Cost));
      Append
        (ModuleInfo,
         ASCII.LF &
         "Removing time:" &
         Positive'Image
           (Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex)
              .InstallTime) &
         " minutes");
      case Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex).MType is
         when ENGINE =>
            Append
              (ModuleInfo,
               ASCII.LF &
               "Max power:" &
               Positive'Image(PlayerShip.Modules(ModuleIndex).Data(2)));
         when ShipModules.CARGO =>
            Append
              (ModuleInfo,
               ASCII.LF &
               "Max cargo:" &
               Positive'Image(PlayerShip.Modules(ModuleIndex).Data(2)) &
               " kg");
         when CABIN =>
            Append(ModuleInfo, ASCII.LF & "Quality: ");
            if PlayerShip.Modules(ModuleIndex).Data(2) < 30 then
               Append(ModuleInfo, "minimal");
            elsif PlayerShip.Modules(ModuleIndex).Data(2) > 29 and
              PlayerShip.Modules(ModuleIndex).Data(2) < 60 then
               Append(ModuleInfo, "basic");
            elsif PlayerShip.Modules(ModuleIndex).Data(2) > 59 and
              PlayerShip.Modules(ModuleIndex).Data(2) < 80 then
               Append(ModuleInfo, "extended");
            else
               Append(ModuleInfo, "luxury");
            end if;
         when GUN | HARPOON_GUN =>
            Append(ModuleInfo, ASCII.LF & "Ammunition: ");
            MAmount := 0;
            for I in Items_List.First_Index .. Items_List.Last_Index loop
               if Items_List(I).IType =
                 Items_Types
                   (Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex)
                      .Value) then
                  if MAmount > 0 then
                     Append(ModuleInfo, " or ");
                  end if;
                  Append(ModuleInfo, Items_List(I).Name);
                  MAmount := MAmount + 1;
               end if;
            end loop;
         when others =>
            null;
      end case;
      if Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex).Size > 0 then
         Append
           (ModuleInfo,
            ASCII.LF &
            "Size:" &
            Natural'Image
              (Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex).Size));
      end if;
      if PlayerShip.Modules(ModuleIndex).Weight > 0 then
         Append
           (ModuleInfo,
            ASCII.LF &
            "Weight:" &
            Natural'Image(PlayerShip.Modules(ModuleIndex).Weight) &
            " kg");
      end if;
      if Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex)
          .Description /=
        Null_Unbounded_String then
         Append
           (ModuleInfo,
            ASCII.LF &
            ASCII.LF &
            Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex)
              .Description);
      end if;
      Set_Label
        (Gtk_Label(Get_Object(Object, "lblremoveinfo")),
         To_String(ModuleInfo));
      MoneyIndex2 := FindItem(PlayerShip.Cargo, FindProtoItem(MoneyIndex));
      if MoneyIndex2 > 0 then
         RemoveInfo :=
           To_Unbounded_String
             (ASCII.LF &
              "You have" &
              Natural'Image(PlayerShip.Cargo(MoneyIndex2).Amount) &
              " " &
              To_String(MoneyName) &
              ".");
      else
         RemoveInfo :=
           To_Unbounded_String
             (ASCII.LF &
              "You don't have any " &
              To_String(MoneyName) &
              " to install anything.");
      end if;
      for Module of PlayerShip.Modules loop
         if Modules_List(Module.ProtoIndex).MType = HULL then
            UsedSpace := Module.Data(1);
            AllSpace := Module.Data(2);
            Append
              (RemoveInfo,
               ASCII.LF &
               "You have used" &
               Natural'Image(UsedSpace) &
               " modules space from max" &
               Natural'Image(AllSpace) &
               " allowed.");
            exit;
         end if;
      end loop;
      Set_Label
        (Gtk_Label(Get_Object(Object, "lblmoneyremove")),
         To_String(RemoveInfo));
   end ShowRemoveInfo;

   procedure SetRemoveModulesList is
      ModulesList: Gtk_List_Store;
      ModulesIter: Gtk_Tree_Iter;
   begin
      ModulesList := Gtk_List_Store(Get_Object(Builder, "removemodulelist"));
      Clear(ModulesList);
      for I in PlayerShip.Modules.Iterate loop
         if Modules_List(PlayerShip.Modules(I).ProtoIndex).MType /= HULL then
            Append(ModulesList, ModulesIter);
            Set
              (ModulesList,
               ModulesIter,
               0,
               To_String(PlayerShip.Modules(I).Name));
            Set
              (ModulesList,
               ModulesIter,
               1,
               Gint(Modules_Container.To_Index(I)));
         end if;
      end loop;
   end SetRemoveModulesList;

   procedure ManipulateModule(User_Data: access GObject_Record'Class) is
      Install: Boolean;
      ParentWindow: constant Gtk_Window :=
        Gtk_Window(Get_Object(Builder, "shipyardwindow"));
      ModulesIter: Gtk_Tree_Iter;
      ModulesModel: Gtk_Tree_Model;
   begin
      if User_Data = Get_Object(Builder, "btninstall") then
         Install := True;
      else
         Get_Selected
           (Gtk.Tree_View.Get_Selection
              (Gtk_Tree_View(Get_Object(Builder, "treeremove"))),
            ModulesModel,
            ModulesIter);
         Install := False;
      end if;
      Bases.Ship.UpgradeShip(Install, ModuleIndex);
      SetRemoveModulesList;
      ShowInstallInfo(Builder);
      ShowLastMessage(Builder);
   exception
      when Trade_No_Money =>
         ShowDialog
           ("You don't have " & To_String(MoneyName) & " to pay for modules.",
            ParentWindow);
      when An_Exception : Trade_Not_Enough_Money =>
         ShowDialog
           ("You don't have enough " &
            To_String(MoneyName) &
            " to pay for " &
            Exception_Message(An_Exception) &
            ".",
            ParentWindow);
      when An_Exception : BasesShip_Unique_Module =>
         ShowDialog
           ("You can't install another " &
            Exception_Message(An_Exception) &
            " because you have installed one module that type. Remove old first.",
            ParentWindow);
      when An_Exception : BasesShip_Installation_Error |
        BasesShip_Removing_Error =>
         ShowDialog(Exception_Message(An_Exception), ParentWindow);
      when Trade_No_Free_Cargo =>
         ShowDialog
           ("You don't have enough free space for " &
            To_String(MoneyName) &
            " in ship cargo.",
            ParentWindow);
      when Trade_No_Money_In_Base =>
         ShowDialog
           ("Base don't have enough " &
            To_String(MoneyName) &
            " for buy this module.",
            ParentWindow);
   end ManipulateModule;

   procedure CreateBasesShipyardUI is
      Error: aliased GError;
   begin
      if Builder /= null then
         return;
      end if;
      Gtk_New(Builder);
      if Add_From_File
          (Builder,
           To_String(DataDirectory) &
           "ui" &
           Dir_Separator &
           "bases-shipyard.glade",
           Error'Access) =
        Guint(0) then
         Put_Line("Error : " & Get_Message(Error));
         return;
      end if;
      Register_Handler(Builder, "Hide_Shipyard", HideShipyard'Access);
      Register_Handler(Builder, "Hide_Last_Message", HideLastMessage'Access);
      Register_Handler(Builder, "Change_Type", ChangeType'Access);
      Register_Handler(Builder, "Show_Install_Info", ShowInstallInfo'Access);
      Register_Handler(Builder, "Manipulate_Module", ManipulateModule'Access);
      Register_Handler(Builder, "Show_Remove_Info", ShowRemoveInfo'Access);
      Do_Connect(Builder);
   end CreateBasesShipyardUI;

   procedure ShowShipyardUI is
   begin
      SetRemoveModulesList;
      SetInstallModulesList(ANY);
      Show_All(Gtk_Widget(Get_Object(Builder, "shipyardwindow")));
      ShowLastMessage(Builder);
      SetActiveModule("treeinstall", "columnname");
      SetActiveModule("treeremove", "columnname1");
   end ShowShipyardUI;

end Bases.ShipyardUI;
