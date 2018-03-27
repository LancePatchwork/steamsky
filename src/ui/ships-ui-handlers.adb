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

with Ada.Exceptions; use Ada.Exceptions;
with Gtk.Widget; use Gtk.Widget;
with Gtk.Tree_Model; use Gtk.Tree_Model;
with Gtk.List_Store; use Gtk.List_Store;
with Gtk.Label; use Gtk.Label;
with Gtk.Tree_View; use Gtk.Tree_View;
with Gtk.Tree_View_Column; use Gtk.Tree_View_Column;
with Gtk.Tree_Selection; use Gtk.Tree_Selection;
with Gtk.GEntry; use Gtk.GEntry;
with Gtk.Window; use Gtk.Window;
with Gtk.Combo_Box; use Gtk.Combo_Box;
with Gtk.Progress_Bar; use Gtk.Progress_Bar;
with Messages; use Messages;
with ShipModules; use ShipModules;
with Crafts; use Crafts;
with Help.UI; use Help.UI;
with Ships.Upgrade; use Ships.Upgrade;
with Ships.Crew; use Ships.Crew;

package body Ships.UI.Handlers is

   procedure ShowModuleInfo(Object: access Gtkada_Builder_Record'Class) is
      ModulesIter: Gtk_Tree_Iter;
      ModulesModel: Gtk_Tree_Model;
      ModuleInfo: Unbounded_String;
      Module: ModuleData;
      MaxValue, MaxUpgrade: Positive;
      HaveAmmo: Boolean;
      Mamount: Natural := 0;
      DamagePercent, UpgradePercent: Gdouble;
      DamageBar: constant Gtk_Progress_Bar :=
        Gtk_Progress_Bar(Get_Object(Object, "damagebar"));
      CleanBar: constant GObject := Get_Object(Object, "cleanbar");
      QualityBar: constant GObject := Get_Object(Object, "qualitybar");
      UpgradeBar: constant GObject := Get_Object(Object, "upgradebar2");
   begin
      Get_Selected
        (Gtk.Tree_View.Get_Selection
           (Gtk_Tree_View(Get_Object(Object, "treemodules"))),
         ModulesModel,
         ModulesIter);
      if ModulesIter = Null_Iter then
         return;
      end if;
      ModuleIndex :=
        Natural'Value(To_String(Get_Path(ModulesModel, ModulesIter))) + 1;
      Module := PlayerShip.Modules(ModuleIndex);
      if Module.Durability < Module.MaxDurability then
         DamagePercent :=
           1.0 - (Gdouble(Module.Durability) / Gdouble(Module.MaxDurability));
         if DamagePercent < 1.0 and DamagePercent > 0.79 then
            Set_Text(DamageBar, "Slightly damaged");
         elsif DamagePercent < 0.8 and DamagePercent > 0.49 then
            Set_Text(DamageBar, "Damaged");
         elsif DamagePercent < 0.5 and DamagePercent > 0.19 then
            Set_Text(DamageBar, "Heavily damaged");
         elsif DamagePercent < 0.2 and DamagePercent > 0.0 then
            Set_Text(DamageBar, "Almost destroyed");
         elsif DamagePercent = 0.0 then
            Set_Text(DamageBar, "Destroyed");
         end if;
      else
         Set_Text(DamageBar, "Not damaged");
         DamagePercent := 1.0;
      end if;
      Set_Fraction(DamageBar, DamagePercent);
      MaxValue :=
        Positive(Float(Modules_List(Module.ProtoIndex).Durability) * 1.5);
      if Module.MaxDurability = MaxValue then
         Set_Text(DamageBar, Get_Text(DamageBar) & " (max upgrade)");
      end if;
      ModuleInfo :=
        To_Unbounded_String("Weight:" & Integer'Image(Module.Weight) & " kg");
      Append(ModuleInfo, ASCII.LF & "Repair/Upgrade material: ");
      for Item of Items_List loop
         if Item.IType = Modules_List(Module.ProtoIndex).RepairMaterial then
            if Mamount > 0 then
               Append(ModuleInfo, " or ");
            end if;
            if FindItem
                (Inventory => PlayerShip.Cargo,
                 ItemType => Item.IType) =
              0 then
               Append
                 (ModuleInfo,
                  "<span foreground=""red"">" &
                  To_String(Item.Name) &
                  "</span>");
            else
               Append(ModuleInfo, To_String(Item.Name));
            end if;
            Mamount := Mamount + 1;
         end if;
      end loop;
      Append
        (ModuleInfo,
         ASCII.LF &
         "Repair/Upgrade skill: " &
         To_String
           (Skills_List(Modules_List(Module.ProtoIndex).RepairSkill).Name) &
         "/" &
         To_String
           (Attributes_Names
              (Skills_List(Modules_List(Module.ProtoIndex).RepairSkill)
                 .Attribute)));

      Set_Markup
        (Gtk_Label(Get_Object(Object, "lblmoduleinfo")),
         To_String(ModuleInfo));
      ModuleInfo := Null_Unbounded_String;
      Hide(Gtk_Widget(CleanBar));
      Hide(Gtk_Widget(QualityBar));
      case Modules_List(Module.ProtoIndex).MType is
         when ENGINE =>
            Append(ModuleInfo, "Max power:" & Integer'Image(Module.Data(2)));
            MaxValue :=
              Positive(Float(Modules_List(Module.ProtoIndex).MaxValue) * 1.5);
            if Module.Data(2) = MaxValue then
               Append(ModuleInfo, " (max upgrade)");
            end if;
            Append
              (ModuleInfo,
               ASCII.LF & "Fuel usage:" & Integer'Image(Module.Data(1)));
            MaxValue :=
              Positive(Float(Modules_List(Module.ProtoIndex).Value) / 2.0);
            if Module.Data(1) = MaxValue then
               Append(ModuleInfo, " (max upgrade)");
            end if;
         when ShipModules.CARGO =>
            Append
              (ModuleInfo,
               "Max cargo:" & Integer'Image(Module.Data(2)) & " kg");
         when HULL =>
            Show_All(Gtk_Widget(CleanBar));
            DamagePercent := Gdouble(Module.Data(1)) / Gdouble(Module.Data(2));
            Set_Fraction(Gtk_Progress_Bar(CleanBar), DamagePercent);
            Set_Text
              (Gtk_Progress_Bar(CleanBar),
               "Modules installed:" &
               Integer'Image(Module.Data(1)) &
               " /" &
               Integer'Image(Module.Data(2)));
            MaxValue :=
              Positive(Float(Modules_List(Module.ProtoIndex).MaxValue) * 1.5);
            if Module.Data(2) = MaxValue then
               Set_Text
                 (Gtk_Progress_Bar(CleanBar),
                  Get_Text(Gtk_Progress_Bar(CleanBar)) & " (max upgrade)");
            end if;
         when CABIN =>
            if Module.Owner > 0 then
               Append
                 (ModuleInfo,
                  "Owner: " & To_String(PlayerShip.Crew(Module.Owner).Name));
            else
               Append(ModuleInfo, "Owner: none");
            end if;
            Show_All(Gtk_Widget(QualityBar));
            Set_Fraction
              (Gtk_Progress_Bar(QualityBar),
               Gdouble(Module.Data(2)) / 100.0);
            if Module.Data(2) < 30 then
               Set_Text(Gtk_Progress_Bar(QualityBar), "Minimal quality");
            elsif Module.Data(2) > 29 and Module.Data(2) < 60 then
               Set_Text(Gtk_Progress_Bar(QualityBar), "Basic quality");
            elsif Module.Data(2) > 59 and Module.Data(2) < 80 then
               Set_Text(Gtk_Progress_Bar(QualityBar), "Extended quality");
            else
               Set_Text(Gtk_Progress_Bar(QualityBar), "Luxury");
            end if;
            MaxValue :=
              Positive(Float(Modules_List(Module.ProtoIndex).MaxValue) * 1.5);
            if Module.Data(2) = MaxValue then
               Set_Text
                 (Gtk_Progress_Bar(QualityBar),
                  Get_Text(Gtk_Progress_Bar(QualityBar)) & " (max upgrade)");
            end if;
            Show_All(Gtk_Widget(CleanBar));
            if Module.Data(1) = Module.Data(2) then
               DamagePercent := 0.0;
               Set_Text(Gtk_Progress_Bar(CleanBar), "Clean");
            else
               DamagePercent :=
                 1.0 - (Gdouble(Module.Data(1)) / Gdouble(Module.Data(2)));
               if DamagePercent > 0.0 and DamagePercent < 0.2 then
                  Set_Text(Gtk_Progress_Bar(CleanBar), "Bit dusty");
               elsif DamagePercent > 0.19 and DamagePercent < 0.5 then
                  Set_Text(Gtk_Progress_Bar(CleanBar), "Dusty");
               elsif DamagePercent > 0.49 and DamagePercent < 0.8 then
                  Set_Text(Gtk_Progress_Bar(CleanBar), "Dirty");
               elsif DamagePercent > 0.79 and DamagePercent < 1.0 then
                  Set_Text(Gtk_Progress_Bar(CleanBar), "Very dirty");
               else
                  Set_Text(Gtk_Progress_Bar(CleanBar), "Ruined");
               end if;
            end if;
            Set_Fraction(Gtk_Progress_Bar(CleanBar), DamagePercent);
         when GUN | HARPOON_GUN =>
            Append(ModuleInfo, "Ammunition: ");
            if Module.Data(1) >= PlayerShip.Cargo.First_Index and
              Module.Data(1) <= PlayerShip.Cargo.Last_Index then
               if Items_List(PlayerShip.Cargo(Module.Data(1)).ProtoIndex)
                   .IType =
                 Items_Types(Modules_List(Module.ProtoIndex).Value) then
                  Append
                    (ModuleInfo,
                     To_String
                       (Items_List(PlayerShip.Cargo(Module.Data(1)).ProtoIndex)
                          .Name) &
                     " (assigned)");
                  HaveAmmo := True;
               end if;
            end if;
            if not HaveAmmo then
               Mamount := 0;
               for I in Items_List.Iterate loop
                  if Items_List(I).IType =
                    Items_Types(Modules_List(Module.ProtoIndex).Value) then
                     if Mamount > 0 then
                        Append(ModuleInfo, " or ");
                     end if;
                     if FindItem
                         (PlayerShip.Cargo,
                          Objects_Container.To_Index(I)) >
                       0 then
                        Append(ModuleInfo, To_String(Items_List(I).Name));
                     else
                        Append
                          (ModuleInfo,
                           "<span foreground=""red"">" &
                           To_String(Items_List(I).Name) &
                           "</span>");
                     end if;
                     Mamount := Mamount + 1;
                  end if;
               end loop;
            end if;
            Append(ModuleInfo, ASCII.LF);
            if Module.Owner > 0 then
               Append
                 (ModuleInfo,
                  "Gunner: " & To_String(PlayerShip.Crew(Module.Owner).Name));
            else
               Append(ModuleInfo, "Gunner: none");
            end if;
         when TURRET =>
            if Module.Data(1) > 0 then
               Append
                 (ModuleInfo,
                  "Weapon: " &
                  To_String(PlayerShip.Modules(Module.Data(1)).Name));
            else
               Append(ModuleInfo, "Weapon: none");
            end if;
         when ALCHEMY_LAB .. GREENHOUSE =>
            if Module.Owner > 0 then
               Append
                 (ModuleInfo,
                  "Worker: " & To_String(PlayerShip.Crew(Module.Owner).Name));
            else
               Append(ModuleInfo, "Worker: none");
            end if;
            Append(ModuleInfo, ASCII.LF);
            if Module.Data(1) /= 0 then
               if Module.Data(1) > 0 then
                  Append
                    (ModuleInfo,
                     "Manufacturing:" &
                     Positive'Image(Module.Data(3)) &
                     "x " &
                     To_String
                       (Items_List(Recipes_List(Module.Data(1)).ResultIndex)
                          .Name));
               else
                  Append
                    (ModuleInfo,
                     "Deconstructing " &
                     To_String(Items_List(abs (Module.Data(1))).Name));
               end if;
               Append
                 (ModuleInfo,
                  ASCII.LF &
                  "Time to complete current:" &
                  Positive'Image(Module.Data(2)) &
                  " mins");
            else
               Append(ModuleInfo, "Manufacturing: nothing");
            end if;
         when MEDICAL_ROOM =>
            if Module.Owner > 0 then
               Append
                 (ModuleInfo,
                  "Medic: " & To_String(PlayerShip.Crew(Module.Owner).Name));
            else
               Append(ModuleInfo, "Medic: none");
            end if;
         when others =>
            null;
      end case;
      if Modules_List(Module.ProtoIndex).Size > 0 then
         if ModuleInfo /= Null_Unbounded_String then
            Append(ModuleInfo, ASCII.LF);
         end if;
         Append
           (ModuleInfo,
            "Size:" & Natural'Image(Modules_List(Module.ProtoIndex).Size));
      end if;
      if Modules_List(Module.ProtoIndex).Description /=
        Null_Unbounded_String then
         if ModuleInfo /= Null_Unbounded_String then
            Append(ModuleInfo, ASCII.LF);
         end if;
         Append
           (ModuleInfo,
            ASCII.LF & To_String(Modules_List(Module.ProtoIndex).Description));
      end if;
      Set_Markup
        (Gtk_Label(Get_Object(Object, "lblmoduleinfo2")),
         To_String(ModuleInfo));
      if Module.UpgradeAction /= NONE then
         ModuleInfo := To_Unbounded_String("Upgrading: ");
         case Module.UpgradeAction is
            when DURABILITY =>
               Append(ModuleInfo, "durability");
               MaxUpgrade := 10;
            when MAX_VALUE =>
               case Modules_List(Module.ProtoIndex).MType is
                  when ENGINE =>
                     Append(ModuleInfo, "power");
                     MaxUpgrade := 10;
                  when CABIN =>
                     Append(ModuleInfo, "quality");
                     MaxUpgrade := 100;
                  when GUN | BATTERING_RAM =>
                     Append(ModuleInfo, "damage");
                     MaxUpgrade := 100;
                  when HULL =>
                     Append(ModuleInfo, "enlarge");
                     MaxUpgrade := 500;
                  when others =>
                     null;
               end case;
            when VALUE =>
               case Modules_List(Module.ProtoIndex).MType is
                  when ENGINE =>
                     Append(ModuleInfo, "fuel usage");
                     MaxUpgrade := 100;
                  when others =>
                     null;
               end case;
            when others =>
               null;
         end case;
         UpgradePercent :=
           1.0 - (Gdouble(Module.UpgradeProgress) / Gdouble(MaxUpgrade));
         Set_Fraction(Gtk_Progress_Bar(UpgradeBar), UpgradePercent);
         if UpgradePercent < 0.11 then
            Append(ModuleInfo, " (started)");
         elsif UpgradePercent < 0.31 then
            Append(ModuleInfo, " (designing)");
         elsif UpgradePercent < 0.51 then
            Append(ModuleInfo, " (base upgrades)");
         elsif UpgradePercent < 0.80 then
            Append(ModuleInfo, " (advanced upgrades)");
         else
            Append(ModuleInfo, " (final upgrades)");
         end if;
         Set_Text(Gtk_Progress_Bar(UpgradeBar), To_String(ModuleInfo));
         Show_All(Gtk_Widget(UpgradeBar));
      else
         Hide(Gtk_Widget(UpgradeBar));
      end if;
      ShowModuleOptions;
   end ShowModuleInfo;

   procedure ShowHelp(Object: access Gtkada_Builder_Record'Class) is
      pragma Unreferenced(Object);
   begin
      ShowHelpUI(6);
   end ShowHelp;

   procedure ChangeShipName(Object: access Gtkada_Builder_Record'Class) is
      NewName: Unbounded_String :=
        To_Unbounded_String
          (Get_Text(Gtk_Entry(Get_Object(Object, "edtname"))));
      SemicolonIndex: Natural;
   begin
      if Length(NewName) = 0 then
         ShowDialog
           ("You must enter new ship name",
            Gtk_Window(Get_Object(Builder, "shipwindow")));
         return;
      end if;
      SemicolonIndex := Index(NewName, ";");
      while SemicolonIndex > 0 loop
         Delete(NewName, SemicolonIndex, SemicolonIndex);
         SemicolonIndex := Index(NewName, ";");
      end loop;
      PlayerShip.Name := NewName;
   end ChangeShipName;

   procedure ChangeModuleName
     (Self: access Gtk_Cell_Renderer_Text_Record'Class;
      Path: UTF8_String;
      New_Text: UTF8_String) is
      pragma Unreferenced(Self);
      ModulesList: constant Gtk_List_Store :=
        Gtk_List_Store(Get_Object(Builder, "moduleslist"));
      NewName: Unbounded_String := To_Unbounded_String(New_Text);
      SemicolonIndex: Natural;
   begin
      if Length(NewName) = 0 then
         ShowDialog
           ("You must enter new module name",
            Gtk_Window(Get_Object(Builder, "shipwindow")));
         return;
      end if;
      SemicolonIndex := Index(NewName, ";");
      while SemicolonIndex > 0 loop
         Delete(NewName, SemicolonIndex, SemicolonIndex);
         SemicolonIndex := Index(NewName, ";");
      end loop;
      PlayerShip.Modules(ModuleIndex).Name := NewName;
      Set
        (ModulesList,
         Get_Iter_From_String(ModulesList, Path),
         0,
         To_String(NewName));
   end ChangeModuleName;

   procedure SetUpgrade(User_Data: access GObject_Record'Class) is
      UpgradeType: Positive;
   begin
      if User_Data = Get_Object(Builder, "btnupgradedur") then
         UpgradeType := 1;
      elsif User_Data = Get_Object(Builder, "btnupgrade1") then
         UpgradeType := 2;
      elsif User_Data = Get_Object(Builder, "btnupgrade2") then
         UpgradeType := 3;
      else
         UpgradeType := 4;
      end if;
      StartUpgrading(ModuleIndex, UpgradeType);
      UpdateOrders(PlayerShip);
      ShowLastMessage(Builder);
      ShowShipInfo;
      ShowModuleInfo(Builder);
   exception
      when An_Exception : Ship_Upgrade_Error =>
         ShowDialog
           (Exception_Message(An_Exception),
            Gtk_Window(Get_Object(Builder, "shipwindow")));
         return;
   end SetUpgrade;

   procedure StopUpgrading(Object: access Gtkada_Builder_Record'Class) is
   begin
      PlayerShip.UpgradeModule := 0;
      for I in PlayerShip.Crew.First_Index .. PlayerShip.Crew.Last_Index loop
         if PlayerShip.Crew(I).Order = Upgrading then
            GiveOrders(PlayerShip, I, Rest);
            exit;
         end if;
      end loop;
      AddMessage("You stopped current upgrade.", OrderMessage);
      ShowLastMessage(Object);
      ShowShipInfo;
      ShowModuleInfo(Object);
   end StopUpgrading;

   procedure SetRepair(User_Data: access GObject_Record'Class) is
   begin
      if User_Data = Get_Object(Builder, "btnrepairfirst") then
         PlayerShip.RepairModule := ModuleIndex;
         AddMessage
           ("You assigned " &
            To_String(PlayerShip.Modules(ModuleIndex).Name) &
            " as repair priority.",
            OrderMessage);
      else
         PlayerShip.RepairModule := 0;
         AddMessage("You removed repair priority.", OrderMessage);
      end if;
      ShowLastMessage(Builder);
      ShowShipInfo;
      ShowModuleInfo(Builder);
   end SetRepair;

   procedure Assign(User_Data: access GObject_Record'Class) is
      ActiveIndex: Natural;
      AssignList: Gtk_List_Store;
      AssignIndex: Positive;
   begin
      if User_Data = Get_Object(Builder, "btnassigncrew") then
         ActiveIndex :=
           Natural
             (Get_Active(Gtk_Combo_Box(Get_Object(Builder, "cmbassigncrew"))));
         AssignList := Gtk_List_Store(Get_Object(Builder, "assigncrewlist"));
      else
         ActiveIndex :=
           Natural
             (Get_Active(Gtk_Combo_Box(Get_Object(Builder, "cmbassignammo"))));
         AssignList := Gtk_List_Store(Get_Object(Builder, "assignammolist"));
      end if;
      AssignIndex :=
        Positive
          (Get_Int
             (AssignList,
              Get_Iter_From_String(AssignList, Natural'Image(ActiveIndex)),
              1));
      if User_Data = Get_Object(Builder, "btnassigncrew") then
         case Modules_List(PlayerShip.Modules(ModuleIndex).ProtoIndex).MType is
            when CABIN =>
               for I in PlayerShip.Modules.Iterate loop
                  if PlayerShip.Modules(I).Owner = AssignIndex and
                    Modules_List(PlayerShip.Modules(I).ProtoIndex).MType =
                      CABIN then
                     PlayerShip.Modules(I).Owner := 0;
                  end if;
               end loop;
               PlayerShip.Modules(ModuleIndex).Owner := AssignIndex;
               AddMessage
                 ("You assigned " &
                  To_String(PlayerShip.Modules(ModuleIndex).Name) &
                  " to " &
                  To_String(PlayerShip.Crew(AssignIndex).Name) &
                  ".",
                  OrderMessage);
            when GUN =>
               GiveOrders(PlayerShip, AssignIndex, Gunner, ModuleIndex);
            when ALCHEMY_LAB .. GREENHOUSE =>
               GiveOrders(PlayerShip, AssignIndex, Craft, ModuleIndex);
            when MEDICAL_ROOM =>
               GiveOrders(PlayerShip, AssignIndex, Heal, ModuleIndex);
            when others =>
               null;
         end case;
      else
         PlayerShip.Modules(ModuleIndex).Data(1) := AssignIndex;
         AddMessage
           ("You assigned " &
            To_String
              (Items_List(PlayerShip.Cargo(AssignIndex).ProtoIndex).Name) &
            " to " &
            To_String(PlayerShip.Modules(ModuleIndex).Name) &
            ".",
            OrderMessage);
      end if;
      ShowLastMessage(Builder);
      ShowShipInfo;
      ShowModuleInfo(Builder);
   end Assign;

end Ships.UI.Handlers;
