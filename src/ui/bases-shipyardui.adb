-- Copyright (c) 2020-2023 Bartek thindil Jasicki <thindil@laeran.pl>
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Characters.Latin_1; use Ada.Characters.Latin_1;
with Ada.Containers.Generic_Array_Sort;
with Ada.Exceptions; use Ada.Exceptions;
with Ada.Strings; use Ada.Strings;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Interfaces.C; use Interfaces.C;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with CArgv; use CArgv;
with Tcl; use Tcl;
with Tcl.Ada; use Tcl.Ada;
with Tcl.Tk.Ada; use Tcl.Tk.Ada;
with Tcl.Tk.Ada.Busy;
with Tcl.Tk.Ada.Font; use Tcl.Tk.Ada.Font;
with Tcl.Tk.Ada.Grid;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.Canvas; use Tcl.Tk.Ada.Widgets.Canvas;
with Tcl.Tk.Ada.Widgets.Text; use Tcl.Tk.Ada.Widgets.Text;
with Tcl.Tk.Ada.Widgets.TtkButton; use Tcl.Tk.Ada.Widgets.TtkButton;
with Tcl.Tk.Ada.Widgets.TtkEntry.TtkComboBox;
use Tcl.Tk.Ada.Widgets.TtkEntry.TtkComboBox;
with Tcl.Tk.Ada.Widgets.TtkEntry; use Tcl.Tk.Ada.Widgets.TtkEntry;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Tcl.Tk.Ada.Widgets.TtkLabel; use Tcl.Tk.Ada.Widgets.TtkLabel;
with Tcl.Tk.Ada.Widgets.TtkPanedWindow; use Tcl.Tk.Ada.Widgets.TtkPanedWindow;
with Tcl.Tk.Ada.Widgets.TtkProgressBar; use Tcl.Tk.Ada.Widgets.TtkProgressBar;
with Tcl.Tk.Ada.Widgets.TtkScrollbar; use Tcl.Tk.Ada.Widgets.TtkScrollbar;
with Tcl.Tk.Ada.Winfo; use Tcl.Tk.Ada.Winfo;
with Tcl.Tklib.Ada.Tooltip; use Tcl.Tklib.Ada.Tooltip;
with Bases.Ship; use Bases.Ship;
with Config; use Config;
with CoreUI; use CoreUI;
with Dialogs; use Dialogs;
with Maps; use Maps;
with Maps.UI; use Maps.UI;
with ShipModules; use ShipModules;
with Ships.Crew; use Ships.Crew;
with Table; use Table;
with Trades; use Trades;
with Utils.UI; use Utils.UI;

package body Bases.ShipyardUI is

   -- ****iv* ShipyardUI/ShipyardUI.Install_Table
   -- FUNCTION
   -- Table with info about the available modules
   -- SOURCE
   Install_Table: Table_Widget (Amount => 5);
   -- ****

   -- ****iv* ShipyardUI/ShipyardUI.Remove_Table
   -- FUNCTION
   -- Table with info about the installed modules
   -- SOURCE
   Remove_Table: Table_Widget (Amount => 5);
   -- ****

   -- ****iv* ShipyardUI/ShipyardUI.Install_Indexes
   -- FUNCTION
   -- Indexes of the available modules to install
   -- SOURCE
   Install_Indexes: Positive_Container.Vector;
   -- ****

   -- ****iv* ShipyardUI/ShipyardUI.Remove_Indexes
   -- FUNCTION
   -- Indexes of the modules in the player's ship (to remove)
   -- SOURCE
   Remove_Indexes: Positive_Container.Vector;
   -- ****

   -- ****f* ShipyardUI/ShipyardUI.Show_Shipyard_Command
   -- FUNCTION
   -- Show the selected base shipyard
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command.
   -- Argv        - Values of arguments passed to the command.
   -- COMMAND
   -- ShowShipyard ?moduletype? ?modulename?
   -- Show the base shipyard and load all available and installed modules
   -- lists. Moduletype is the type of modules to show in available modules,
   -- modulename is the name of the module to search in available modules.
   -- SOURCE
   function Show_Shipyard_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Shipyard_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data);
      use Tiny_String;

      Shipyard_Frame: Ttk_Frame :=
        Get_Widget
          (pathName => Main_Paned & ".shipyardframe", Interp => Interp);
      Shipyard_Canvas: constant Tk_Canvas :=
        Get_Widget(pathName => Shipyard_Frame & ".canvas", Interp => Interp);
      Base_Index: constant Positive :=
        Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Base_Index;
      Module_Size: Integer;
      Module_Type_Box: constant Ttk_ComboBox :=
        Get_Widget
          (pathName => Shipyard_Canvas & ".shipyard.install.options.modules",
           Interp => Interp);
      Cost, Used_Space: Natural;
      Damage: Float;
      Money_Index_2: constant Natural :=
        Find_Item(Inventory => Player_Ship.Cargo, Proto_Index => Money_Index);
      Max_Size, All_Space: Positive;
      Install_Info: Unbounded_String;
      Money_Label: constant Ttk_Label :=
        Get_Widget
          (pathName => Shipyard_Canvas & ".shipyard.moneyinfo",
           Interp => Interp);
      Page: constant Positive :=
        (if Argc = 4 then Positive'Value(CArgv.Arg(Argv => Argv, N => 3))
         else 1);
      Start_Row: constant Positive :=
        ((Page - 1) * Game_Settings.Lists_Limit) + 1;
      Current_Row: Positive := 1;
      Arguments: constant String :=
        (if Argc > 2 then
           "{" & CArgv.Arg(Argv => Argv, N => 1) & "} {" &
           CArgv.Arg(Argv => Argv, N => 2) & "}"
         elsif Argc = 2 then CArgv.Arg(Argv => Argv, N => 1) & " {}"
         else "0 {}");
      Search_Entry: constant Ttk_Entry :=
        Get_Widget
          (pathName => Shipyard_Canvas & ".shipyard.install.options.search");
   begin
      if Winfo_Get(Widgt => Shipyard_Canvas, Info => "exists") = "0" then
         Tcl_EvalFile
           (interp => Get_Context,
            fileName =>
              To_String(Source => Data_Directory) & "ui" & Dir_Separator &
              "shipyard.tcl");
         Bind
           (Widgt => Shipyard_Frame, Sequence => "<Configure>",
            Script => "{ResizeCanvas %W.canvas %w %h}");
         Shipyard_Frame :=
           Get_Widget
             (pathName => Shipyard_Canvas & ".shipyard.install",
              Interp => Interp);
         Install_Table :=
           Create_Table
             (Parent => Widget_Image(Win => Shipyard_Frame),
              Headers =>
                (1 => To_Unbounded_String(Source => "Name"),
                 2 => To_Unbounded_String(Source => "Type"),
                 3 => To_Unbounded_String(Source => "Size"),
                 4 => To_Unbounded_String(Source => "Materials"),
                 5 => To_Unbounded_String(Source => "Cost")),
              Scrollbar =>
                Get_Widget
                  (pathName => ".gameframe.paned.shipyardframe.scrolly"),
              Command => "",
              Tooltip_Text => "Press mouse button to sort the modules.");
         Shipyard_Frame :=
           Get_Widget
             (pathName => Shipyard_Canvas & ".shipyard.remove",
              Interp => Interp);
         Remove_Table :=
           Create_Table
             (Parent => Widget_Image(Win => Shipyard_Frame),
              Headers =>
                (1 => To_Unbounded_String(Source => "Name"),
                 2 => To_Unbounded_String(Source => "Type"),
                 3 => To_Unbounded_String(Source => "Size"),
                 4 => To_Unbounded_String(Source => "Materials"),
                 5 => To_Unbounded_String(Source => "Price")),
              Scrollbar =>
                Get_Widget
                  (pathName => ".gameframe.paned.shipyardframe.scrolly"),
              Command => "SortShipyardModules remove 0 {}",
              Tooltip_Text => "Press mouse button to sort the modules.");
      elsif Winfo_Get(Widgt => Shipyard_Canvas, Info => "ismapped") = "1" then
         if Argc = 1 then
            Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Close_Button);
            Show_Sky_Map(Clear => True);
            return TCL_OK;
         else
            Current
              (ComboBox => Module_Type_Box,
               NewIndex => CArgv.Arg(Argv => Argv, N => 1));
         end if;
      elsif Winfo_Get(Widgt => Shipyard_Canvas, Info => "ismapped") = "0" and
        Argc = 1 then
         Current(ComboBox => Module_Type_Box, NewIndex => "0");
      end if;
      Tcl_SetVar
        (interp => Interp, varName => "gamestate", newValue => "repair");
      Find_Max_Module_Size_Loop :
      for Module of Player_Ship.Modules loop
         if Module.M_Type = HULL then
            Max_Size := Get_Module(Index => Module.Proto_Index).Value;
            Used_Space := Module.Installed_Modules;
            All_Space := Module.Max_Modules;
            exit Find_Max_Module_Size_Loop;
         end if;
      end loop Find_Max_Module_Size_Loop;
      Shipyard_Frame.Name := New_String(Str => Shipyard_Canvas & ".shipyard");
      Install_Info :=
        (if Money_Index_2 > 0 then
           To_Unbounded_String
             (Source =>
                "You have" &
                Natural'Image
                  (Inventory_Container.Element
                     (Container => Player_Ship.Cargo, Index => Money_Index_2)
                     .Amount) &
                " " & To_String(Source => Money_Name) & ".")
         else To_Unbounded_String
             (Source =>
                LF & "You don't have any " & To_String(Source => Money_Name) &
                " to install anything."));
      Append
        (Source => Install_Info,
         New_Item =>
           LF & "You have used" & Natural'Image(Used_Space) &
           " modules space from max" & Natural'Image(All_Space) & " allowed.");
      configure
        (Widgt => Money_Label,
         options => "-text {" & To_String(Source => Install_Info) & "}");
      Tcl_Eval
        (interp => Interp,
         strng =>
           "SetScrollbarBindings " & Money_Label &
           " .gameframe.paned.shipyardframe.scrolly");
      if Argc < 3 then
         configure(Widgt => Search_Entry, options => "-validatecommand {}");
         Delete
           (TextEntry => Search_Entry, FirstIndex => "0", LastIndex => "end");
         configure
           (Widgt => Search_Entry,
            options =>
              "-validatecommand {ShowShipyard [" & Shipyard_Frame &
              ".install.options.modules current] %P}");
      end if;
      if Install_Indexes.Length = 0 then
         Fill_Install_Indexes_Loop :
         for I in 1 .. Get_Modules_Amount loop
            Install_Indexes.Append(New_Item => I);
         end loop Fill_Install_Indexes_Loop;
      end if;
      Update_Headers_Command
        (Table => Install_Table,
         Command => "SortShipyardModules install " & Arguments);
      Clear_Table(Table => Install_Table);
      Load_Install_Modules_Loop :
      for I of Install_Indexes loop
         if Get_Module(Index => I).Price = 0
           or else Sky_Bases(Base_Index).Reputation.Level <
             Get_Module(Index => I).Reputation then
            goto End_Of_Loop;
         end if;
         if Argc > 1
           and then Natural'Value(CArgv.Arg(Argv => Argv, N => 1)) > 0
           and then Natural'Value(CArgv.Arg(Argv => Argv, N => 1)) /=
             Module_Type'Pos(Get_Module(Index => I).M_Type) then
            goto End_Of_Loop;
         end if;
         if Argc > 2 and then CArgv.Arg(Argv => Argv, N => 2)'Length > 0
           and then
             Index
               (Source =>
                  To_Lower
                    (Item => To_String(Source => Get_Module(Index => I).Name)),
                Pattern => To_Lower(Item => CArgv.Arg(Argv => Argv, N => 2))) =
             0 then
            goto End_Of_Loop;
         end if;
         if Current_Row < Start_Row then
            Current_Row := Current_Row + 1;
            goto End_Of_Loop;
         end if;
         Module_Size :=
           (if Get_Module(Index => I).M_Type = HULL then
              Get_Module(Index => I).Max_Value
            else Get_Module(Index => I).Size);
         Add_Button
           (Table => Install_Table,
            Text => To_String(Source => Get_Module(Index => I).Name),
            Tooltip => "Show available options for module",
            Command =>
              "ShowShipyardModuleMenu {" &
              Trim(Source => I'Img, Side => Left) & "} install",
            Column => 1);
         Add_Button
           (Table => Install_Table, Text => Get_Module_Type(Module_Index => I),
            Tooltip => "Show available options for module",
            Command =>
              "ShowShipyardModuleMenu {" &
              Trim(Source => I'Img, Side => Left) & "} install",
            Column => 2);
         Add_Button
           (Table => Install_Table, Text => Integer'Image(Module_Size),
            Tooltip => "Show available options for module",
            Command =>
              "ShowShipyardModuleMenu {" &
              Trim(Source => I'Img, Side => Left) & "} install",
            Column => 3, New_Row => False,
            Color =>
              (if Get_Module(Index => I).M_Type = HULL then
                 (if Module_Size < All_Space then "red"
                  elsif Module_Size > All_Space then "green" else "")
               else (if Module_Size > Max_Size then "red" else "")));
         Add_Button
           (Table => Install_Table,
            Text =>
              To_String(Source => Get_Module(Index => I).Repair_Material),
            Tooltip => "Show available options for module",
            Command =>
              "ShowShipyardModuleMenu {" &
              Trim(Source => I'Img, Side => Left) & "} install",
            Column => 4);
         Cost := Get_Module(Index => I).Price;
         Count_Price
           (Price => Cost, Trader_Index => Find_Member(Order => TALK));
         Add_Button
           (Table => Install_Table, Text => Natural'Image(Cost),
            Tooltip => "Show available options for module",
            Command =>
              "ShowShipyardModuleMenu {" &
              Trim(Source => I'Img, Side => Left) & "} install",
            Column => 5, New_Row => True,
            Color =>
              (if
                 Money_Index_2 > 0
                 and then Cost <=
                   Inventory_Container.Element
                     (Container => Player_Ship.Cargo, Index => Money_Index_2)
                     .Amount
               then ""
               else "red"));
         exit Load_Install_Modules_Loop when Install_Table.Row =
           Game_Settings.Lists_Limit + 1;
         <<End_Of_Loop>>
      end loop Load_Install_Modules_Loop;
      Add_Pagination
        (Table => Install_Table,
         Previous_Command =>
           (if Page > 1 then
              "ShowShipyard " & Arguments & Positive'Image(Page - 1)
            else ""),
         Next_Command =>
           (if Install_Table.Row < Game_Settings.Lists_Limit + 1 then ""
            else "ShowShipyard " & Arguments & Positive'Image(Page + 1)));
      Update_Table
        (Table => Install_Table,
         Grab_Focus =>
           (if Focus = Widget_Image(Win => Search_Entry) then False));
      if Remove_Indexes.Length /= Player_Ship.Modules.Length then
         Remove_Indexes.Clear;
         Fill_Remove_Indexes_Loop :
         for I in Player_Ship.Modules.Iterate loop
            Remove_Indexes.Append
              (New_Item => Modules_Container.To_Index(Position => I));
         end loop Fill_Remove_Indexes_Loop;
      end if;
      Clear_Table(Table => Remove_Table);
      Current_Row := 1;
      Load_Remove_Modules_Loop :
      for I of Remove_Indexes loop
         if Get_Module(Index => Player_Ship.Modules(I).Proto_Index).M_Type =
           HULL then
            goto End_Of_Remove_Loop;
         end if;
         if Current_Row < Start_Row then
            Current_Row := Current_Row + 1;
            goto End_Of_Remove_Loop;
         end if;
         Add_Button
           (Table => Remove_Table,
            Text => To_String(Source => Player_Ship.Modules(I).Name),
            Tooltip => "Show available options for module",
            Command =>
              "ShowShipyardModuleMenu {" & Positive'Image(I) & "} remove",
            Column => 1);
         Add_Button
           (Table => Remove_Table,
            Text =>
              Get_Module_Type
                (Module_Index => Player_Ship.Modules(I).Proto_Index),
            Tooltip => "Show available options for module",
            Command =>
              "ShowShipyardModuleMenu {" & Positive'Image(I) & "} remove",
            Column => 2);
         Add_Button
           (Table => Remove_Table,
            Text =>
              Integer'Image
                (Get_Module(Index => Player_Ship.Modules(I).Proto_Index).Size),
            Tooltip => "Show available options for module",
            Command =>
              "ShowShipyardModuleMenu {" & Positive'Image(I) & "} remove",
            Column => 3);
         Add_Button
           (Table => Remove_Table,
            Text =>
              To_String
                (Source =>
                   Get_Module(Index => Player_Ship.Modules(I).Proto_Index)
                     .Repair_Material),
            Tooltip => "Show available options for module",
            Command =>
              "ShowShipyardModuleMenu {" & Positive'Image(I) & "} remove",
            Column => 4);
         Damage :=
           1.0 -
           Float(Player_Ship.Modules(I).Durability) /
             Float(Player_Ship.Modules(I).Max_Durability);
         Cost :=
           Get_Module(Index => Player_Ship.Modules(I).Proto_Index).Price -
           Integer
             (Float
                (Get_Module(Index => Player_Ship.Modules(I).Proto_Index)
                   .Price) *
              Damage);
         if Cost = 0 then
            Cost := 1;
         end if;
         Count_Price
           (Price => Cost, Trader_Index => Find_Member(Order => TALK),
            Reduce => False);
         Add_Button
           (Table => Remove_Table, Text => Natural'Image(Cost),
            Tooltip => "Show available options for module",
            Command =>
              "ShowShipyardModuleMenu {" & Positive'Image(I) & "} remove",
            Column => 5, New_Row => True);
         exit Load_Remove_Modules_Loop when Remove_Table.Row =
           Game_Settings.Lists_Limit + 1;
         <<End_Of_Remove_Loop>>
      end loop Load_Remove_Modules_Loop;
      Add_Pagination
        (Table => Remove_Table,
         Previous_Command =>
           (if Page > 1 then
              "ShowShipyard " & Arguments & Positive'Image(Page - 1)
            else ""),
         Next_Command =>
           (if Remove_Table.Row < Game_Settings.Lists_Limit + 1 then ""
            else "ShowShipyard " & Arguments & Positive'Image(Page + 1)));
      Update_Table(Table => Remove_Table);
      Tcl.Tk.Ada.Grid.Grid
        (Slave => Close_Button, Options => "-row 0 -column 1");
      configure
        (Widgt => Shipyard_Canvas,
         options =>
           "-height [expr " & SashPos(Paned => Main_Paned, Index => "0") &
           " - 20] -width " & cget(Widgt => Main_Paned, option => "-width"));
      Xview_Move_To(CanvasWidget => Shipyard_Canvas, Fraction => "0.0");
      Yview_Move_To(CanvasWidget => Shipyard_Canvas, Fraction => "0.0");
      Show_Screen(New_Screen_Name => "shipyardframe");
      Tcl_SetResult(interp => Interp, str => "1");
      Tcl_Eval(interp => Get_Context, strng => "ShowShipyardTab show");
      return TCL_OK;
   end Show_Shipyard_Command;

   -- ****iv* ShipyardUI/ShipyardUI.Module_Index
   -- SOURCE
   Module_Index: Positive;
   -- ****

   -- ****if* ShipyardUI/ShipyardUI.Set_Module_Info
   -- FUNCTION
   -- Show information about selected module
   -- PARAMETERS
   -- Installing - If true, player looking at installing modules list
   -- SOURCE
   procedure Set_Module_Info(Installing: Boolean) is
      -- ****
      use Short_String;
      use Tiny_String;

      M_Type: Module_Type;
      M_Amount, Weight, Max_Value, Value, Max_Owners: Natural;
      Ship_Module_Index: Natural := 0;
      Size: Positive;
      Speed: Integer;
      Module_Text: Tk_Text;
      Added: Boolean := False;
      Cost: Positive;
      Money_Index_2: Natural;
   begin
      if Installing then
         M_Type := Get_Module(Index => Module_Index).M_Type;
         Max_Value := Get_Module(Index => Module_Index).Max_Value;
         Value := Get_Module(Index => Module_Index).Value;
         Size := Get_Module(Index => Module_Index).Size;
         Weight := Get_Module(Index => Module_Index).Weight;
         Max_Owners := Get_Module(Index => Module_Index).Max_Owners;
         Speed := Get_Module(Index => Module_Index).Speed;
         Module_Text := Get_Widget(pathName => ".moduledialog.info");
         Get_Module_Index_Block :
         declare
            Compare_Box: constant Ttk_ComboBox :=
              Get_Widget(pathName => ".moduledialog.compare.combo");
            Module_Iterator: Natural := 1;
         begin
            if Winfo_Get(Widgt => Compare_Box, Info => "ismapped") = "1" then
               Module_Iterator :=
                 Natural'Value(Current(ComboBox => Compare_Box)) + 1;
            end if;
            Set_Ship_Module_Index_Loop :
            for I in Player_Ship.Modules.Iterate loop
               if Get_Module(Index => Player_Ship.Modules(I).Proto_Index)
                   .M_Type =
                 M_Type then
                  Module_Iterator := Module_Iterator - 1;
                  if Module_Iterator = 0 then
                     Ship_Module_Index :=
                       Modules_Container.To_Index(Position => I);
                     exit Set_Ship_Module_Index_Loop;
                  end if;
               end if;
            end loop Set_Ship_Module_Index_Loop;
         end Get_Module_Index_Block;
         Cost := Get_Module(Index => Module_Index).Price;
         Count_Price
           (Price => Cost, Trader_Index => Find_Member(Order => TALK));
         Money_Index_2 :=
           Find_Item
             (Inventory => Player_Ship.Cargo, Proto_Index => Money_Index);
         configure(Widgt => Module_Text, options => "-state normal");
         Delete
           (TextWidget => Module_Text, StartIndex => "1.0", Indexes => "end");
         Insert
           (TextWidget => Module_Text, Index => "end",
            Text => "{Install cost:}");
         Insert
           (TextWidget => Module_Text, Index => "end",
            Text =>
              "{" & Positive'Image(Cost) & " " &
              To_String(Source => Money_Name) & "}" &
              (if
                 Money_Index_2 = 0
                 or else
                   Inventory_Container.Element
                     (Container => Player_Ship.Cargo, Index => Money_Index_2)
                     .Amount <
                   Cost
               then " [list red]"
               else ""));
         Insert
           (TextWidget => Module_Text, Index => "end",
            Text =>
              "{" & LF & "Installation time:" &
              Positive'Image(Get_Module(Index => Module_Index).Install_Time) &
              " minutes}");
      else
         Ship_Module_Index := Module_Index;
         M_Type :=
           Get_Module
             (Index => Player_Ship.Modules(Ship_Module_Index).Proto_Index)
             .M_Type;
         case M_Type is
            when HARPOON_GUN =>
               Max_Value := Player_Ship.Modules(Ship_Module_Index).Duration;
               Value :=
                 Get_Module
                   (Index =>
                      Player_Ship.Modules(Ship_Module_Index).Proto_Index)
                   .Value;
            when ENGINE =>
               Max_Value := Player_Ship.Modules(Ship_Module_Index).Power;
               Value := Player_Ship.Modules(Ship_Module_Index).Fuel_Usage;
            when CABIN =>
               Max_Value := Player_Ship.Modules(Ship_Module_Index).Quality;
               Value := Player_Ship.Modules(Ship_Module_Index).Cleanliness;
            when GUN =>
               Max_Value := Player_Ship.Modules(Ship_Module_Index).Damage;
               Value :=
                 Get_Module
                   (Index =>
                      Player_Ship.Modules(Ship_Module_Index).Proto_Index)
                   .Value;
            when ShipModules.CARGO =>
               Max_Value :=
                 Get_Module
                   (Index =>
                      Player_Ship.Modules(Ship_Module_Index).Proto_Index)
                   .Max_Value;
               Value :=
                 Get_Module
                   (Index =>
                      Player_Ship.Modules(Ship_Module_Index).Proto_Index)
                   .Value;
            when HULL =>
               Max_Value := Player_Ship.Modules(Ship_Module_Index).Max_Modules;
               Value :=
                 Get_Module
                   (Index =>
                      Player_Ship.Modules(Ship_Module_Index).Proto_Index)
                   .Value;
            when BATTERING_RAM =>
               Max_Value := Player_Ship.Modules(Ship_Module_Index).Damage2;
               Value := 0;
            when others =>
               Max_Value := 0;
               Value := 0;
         end case;
         Size :=
           Get_Module
             (Index => Player_Ship.Modules(Ship_Module_Index).Proto_Index)
             .Size;
         Weight :=
           Get_Module
             (Index => Player_Ship.Modules(Ship_Module_Index).Proto_Index)
             .Weight;
         Max_Owners :=
           Get_Module
             (Index => Player_Ship.Modules(Ship_Module_Index).Proto_Index)
             .Max_Owners;
         Speed :=
           Get_Module
             (Index => Player_Ship.Modules(Ship_Module_Index).Proto_Index)
             .Speed;
         Module_Text := Get_Widget(pathName => ".moduledialog.info");
      end if;
      case M_Type is
         when HULL =>
            if Installing then
               Insert
                 (TextWidget => Module_Text, Index => "end",
                  Text =>
                    "{" & LF & "Ship hull can be only replaced." & LF &
                    "Modules space:}");
               if Max_Value <
                 Player_Ship.Modules(Ship_Module_Index).Max_Modules then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text =>
                       "{" & Positive'Image(Max_Value) &
                       " (smaller)} [list red]");
               elsif Max_Value >
                 Player_Ship.Modules(Ship_Module_Index).Max_Modules then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text =>
                       "{" & Positive'Image(Max_Value) &
                       " (bigger)} [list green]");
               else
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text => "{" & Positive'Image(Max_Value) & "}");
               end if;
            end if;
            Insert
              (TextWidget => Module_Text, Index => "end",
               Text => "{" & LF & "Max module size:}");
            if Installing then
               if Value <
                 Get_Module
                   (Index =>
                      Player_Ship.Modules(Ship_Module_Index).Proto_Index)
                   .Value then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text =>
                       "{" & Positive'Image(Value) & " (smaller)} [list red]");
               elsif Value >
                 Get_Module
                   (Index =>
                      Player_Ship.Modules(Ship_Module_Index).Proto_Index)
                   .Value then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text =>
                       "{" & Positive'Image(Value) &
                       " (bigger)} [list green]");
               else
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text => "{" & Positive'Image(Value) & "}");
               end if;
            else
               Insert
                 (TextWidget => Module_Text, Index => "end",
                  Text => "{" & Positive'Image(Value) & "}");
            end if;
         when ENGINE =>
            Insert
              (TextWidget => Module_Text, Index => "end",
               Text => "{" & LF & "Max power:}");
            if Installing and then Ship_Module_Index > 0 then
               if Max_Value < Player_Ship.Modules(Ship_Module_Index).Power then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text =>
                       "{" & Positive'Image(Max_Value) &
                       " (weaker)} [list red]");
               elsif Max_Value >
                 Player_Ship.Modules(Ship_Module_Index).Power then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text =>
                       "{" & Positive'Image(Max_Value) &
                       " (stronger)} [list green]");
               else
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text => "{" & Positive'Image(Max_Value) & "}");
               end if;
               Insert
                 (TextWidget => Module_Text, Index => "end",
                  Text => "{" & LF & "Fuel usage:}");
               if Value <
                 Player_Ship.Modules(Ship_Module_Index).Fuel_Usage then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text =>
                       "{" & Positive'Image(Value) & " (less)} [list green]");
               elsif Value >
                 Player_Ship.Modules(Ship_Module_Index).Fuel_Usage then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text =>
                       "{" & Positive'Image(Value) & " (more)} [list red]");
               else
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text => "{" & Positive'Image(Value) & "}");
               end if;
            else
               Insert
                 (TextWidget => Module_Text, Index => "end",
                  Text => "{" & Positive'Image(Max_Value) & "}");
               Insert
                 (TextWidget => Module_Text, Index => "end",
                  Text =>
                    "{" & LF & "Fuel usage:" & Positive'Image(Value) & "}");
            end if;
         when ShipModules.CARGO =>
            Insert
              (TextWidget => Module_Text, Index => "end",
               Text => "{" & LF & "Max cargo:}");
            if Installing and then Ship_Module_Index > 0 then
               if Max_Value >
                 Get_Module
                   (Index =>
                      Player_Ship.Modules(Ship_Module_Index).Proto_Index)
                   .Max_Value then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text =>
                       "{" & Positive'Image(Max_Value) &
                       " kg (bigger)} [list green]");
               elsif Max_Value <
                 Get_Module
                   (Index =>
                      Player_Ship.Modules(Ship_Module_Index).Proto_Index)
                   .Max_Value then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text =>
                       "{" & Positive'Image(Max_Value) &
                       " kg (smaller)} [list red]");
               else
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text => "{" & Positive'Image(Max_Value) & " kg}");
               end if;
            else
               Insert
                 (TextWidget => Module_Text, Index => "end",
                  Text => "{" & Positive'Image(Max_Value) & " kg}");
            end if;
         when CABIN =>
            Insert
              (TextWidget => Module_Text, Index => "end",
               Text => "{" & LF & "Quality: }");
            if Installing and then Ship_Module_Index > 0 then
               if Max_Value < 30 then
                  if Player_Ship.Modules(Ship_Module_Index).Quality >
                    Max_Value then
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text => "{minimal (worse)} [list red]");
                  elsif Player_Ship.Modules(Ship_Module_Index).Quality <
                    Max_Value then
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text => "{minimal (better)} [list green]");
                  else
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text => "{minimal}");
                  end if;
               elsif Max_Value < 60 then
                  if Player_Ship.Modules(Ship_Module_Index).Quality >
                    Max_Value then
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text => "{basic (worse)} [list red]");
                  elsif Player_Ship.Modules(Ship_Module_Index).Quality <
                    Max_Value then
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text => "{basic (better)} [list green]");
                  else
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text => "{basic}");
                  end if;
               elsif Max_Value < 80 then
                  if Player_Ship.Modules(Ship_Module_Index).Quality >
                    Max_Value then
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text => "{extended (worse)} [list red]");
                  elsif Player_Ship.Modules(Ship_Module_Index).Quality <
                    Max_Value then
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text => "{extended (better)} [list green]");
                  else
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text => "{extended}");
                  end if;
               else
                  if Player_Ship.Modules(Ship_Module_Index).Quality >
                    Max_Value then
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text => "{luxury (worse) [list red]}");
                  elsif Player_Ship.Modules(Ship_Module_Index).Quality <
                    Max_Value then
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text => "{luxury (better) [list green]}");
                  else
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text => "{luxury}");
                  end if;
               end if;
            else
               if Max_Value < 30 then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text => "{minimal}");
               elsif Max_Value < 60 then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text => "{basic}");
               elsif Max_Value < 80 then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text => "{extended}");
               else
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text => "{luxury}");
               end if;
            end if;
            Insert
              (TextWidget => Module_Text, Index => "end",
               Text => "{" & LF & "Max owners:}");
            if Installing and then Ship_Module_Index > 0 then
               if Get_Module
                   (Index =>
                      Player_Ship.Modules(Ship_Module_Index).Proto_Index)
                   .Max_Owners >
                 Max_Owners then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text =>
                       "{" & Natural'Image(Max_Owners) &
                       " (less)} [list red]");
               elsif Get_Module
                   (Index =>
                      Player_Ship.Modules(Ship_Module_Index).Proto_Index)
                   .Max_Owners <
                 Max_Owners then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text =>
                       "{" & Natural'Image(Max_Owners) &
                       " (more)} [list green]");
               else
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text => "{" & Natural'Image(Max_Owners) & "}");
               end if;
            else
               Insert
                 (TextWidget => Module_Text, Index => "end",
                  Text => "{" & Natural'Image(Max_Owners) & "}");
            end if;
         when ALCHEMY_LAB .. GREENHOUSE =>
            Insert
              (TextWidget => Module_Text, Index => "end",
               Text => "{" & LF & "Max workers:}");
            if Installing and then Ship_Module_Index > 0 then
               if Get_Module
                   (Index =>
                      Player_Ship.Modules(Ship_Module_Index).Proto_Index)
                   .Max_Owners >
                 Max_Owners then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text =>
                       "{" & Natural'Image(Max_Owners) &
                       " (less)} [list red]");
               elsif Get_Module
                   (Index =>
                      Player_Ship.Modules(Ship_Module_Index).Proto_Index)
                   .Max_Owners <
                 Max_Owners then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text =>
                       "{" & Natural'Image(Max_Owners) &
                       " (more)} [list green]");
               else
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text => "{" & Natural'Image(Max_Owners) & "}");
               end if;
            else
               Insert
                 (TextWidget => Module_Text, Index => "end",
                  Text => "{" & Natural'Image(Max_Owners) & "}");
            end if;
         when GUN | HARPOON_GUN =>
            Insert
              (TextWidget => Module_Text, Index => "end",
               Text => "{" & LF & "Strength:}");
            if Installing and then Ship_Module_Index > 0 then
               if M_Type = GUN then
                  if Player_Ship.Modules(Ship_Module_Index).Damage >
                    Max_Value then
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text =>
                          "{" & Natural'Image(Max_Value) &
                          " (weaker)} [list red]");
                  elsif Player_Ship.Modules(Ship_Module_Index).Damage <
                    Max_Value then
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text =>
                          "{" & Natural'Image(Max_Value) &
                          " (stronger)} [list green]");
                  else
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text => "{" & Natural'Image(Max_Value) & "}");
                  end if;
               else
                  if Player_Ship.Modules(Ship_Module_Index).Duration >
                    Max_Value then
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text =>
                          "{" & Natural'Image(Max_Value) &
                          " (weaker)} [list red]");
                  elsif Player_Ship.Modules(Ship_Module_Index).Damage <
                    Max_Value then
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text =>
                          "{" & Natural'Image(Max_Value) &
                          " (stronger)} [list green]");
                  else
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text => "{" & Natural'Image(Max_Value) & "}");
                  end if;
               end if;
            else
               Insert
                 (TextWidget => Module_Text, Index => "end",
                  Text => "{" & Natural'Image(Max_Value) & "}");
            end if;
            Insert
              (TextWidget => Module_Text, Index => "end",
               Text => "{" & LF & "Ammunition: }");
            Ammunition_Info_Loop :
            for I in 1 .. Get_Proto_Amount loop
               if Get_Proto_Item(Index => I).I_Type =
                 Get_Ada_Item_Type(Item_Index => Value - 1) then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text =>
                       "{Any" &
                       Slice
                         (Source => Get_Proto_Item(Index => I).Name,
                          Low =>
                            Index
                              (Source => Get_Proto_Item(Index => I).Name,
                               Pattern => " "),
                          High =>
                            Length
                              (Source => Get_Proto_Item(Index => I).Name)) &
                       "}");
                  exit Ammunition_Info_Loop;
               end if;
            end loop Ammunition_Info_Loop;
            if M_Type = GUN then
               Insert
                 (TextWidget => Module_Text, Index => "end",
                  Text => "{" & LF & "Max fire rate:}");
               if Installing and then Ship_Module_Index > 0 then
                  if Get_Module
                      (Index =>
                         Player_Ship.Modules(Ship_Module_Index).Proto_Index)
                      .Speed >
                    Speed then
                     if Speed > 0 then
                        Insert
                          (TextWidget => Module_Text, Index => "end",
                           Text =>
                             "{" & Positive'Image(Speed) &
                             "/round (slower)} [list red]");
                     else
                        Insert
                          (TextWidget => Module_Text, Index => "end",
                           Text =>
                             "{1/" &
                             Trim
                               (Source => Integer'Image(abs (Speed)),
                                Side => Both) &
                             " rounds (slower)} [list red]");
                     end if;
                  elsif Get_Module
                      (Index =>
                         Player_Ship.Modules(Ship_Module_Index).Proto_Index)
                      .Speed <
                    Speed then
                     if Speed > 0 then
                        Insert
                          (TextWidget => Module_Text, Index => "end",
                           Text =>
                             "{" & Positive'Image(Speed) &
                             "/round (faster)} [list green]");
                     else
                        Insert
                          (TextWidget => Module_Text, Index => "end",
                           Text =>
                             "{1/" &
                             Trim
                               (Source => Integer'Image(abs (Speed)),
                                Side => Both) &
                             " rounds (faster)} [list green]");
                     end if;
                  else
                     if Speed > 0 then
                        Insert
                          (TextWidget => Module_Text, Index => "end",
                           Text => "{" & Positive'Image(Speed) & "/round}");
                     else
                        Insert
                          (TextWidget => Module_Text, Index => "end",
                           Text =>
                             "{1/" &
                             Trim
                               (Source => Integer'Image(abs (Speed)),
                                Side => Both) &
                             " rounds}");
                     end if;
                  end if;
               else
                  if Speed > 0 then
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text => "{" & Positive'Image(Speed) & "/round}");
                  else
                     Insert
                       (TextWidget => Module_Text, Index => "end",
                        Text =>
                          "{1/" &
                          Trim
                            (Source => Integer'Image(abs (Speed)),
                             Side => Both) &
                          " rounds}");
                  end if;
               end if;
            end if;
         when BATTERING_RAM =>
            Insert
              (TextWidget => Module_Text, Index => "end",
               Text => "{" & LF & "Strength:}");
            if Installing and then Ship_Module_Index > 0 then
               if Player_Ship.Modules(Ship_Module_Index).Damage2 >
                 Max_Value then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text =>
                       "{" & Natural'Image(Max_Value) &
                       " (weaker)} [list red]");
               elsif Player_Ship.Modules(Ship_Module_Index).Damage2 <
                 Max_Value then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text =>
                       "{" & Natural'Image(Max_Value) &
                       " (stronger)} [list green]");
               else
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text => "{" & Natural'Image(Max_Value) & "}");
               end if;
            else
               Insert
                 (TextWidget => Module_Text, Index => "end",
                  Text => "{" & Natural'Image(Max_Value) & "}");
            end if;
         when others =>
            null;
      end case;
      if M_Type not in HULL | ARMOR then
         Insert
           (TextWidget => Module_Text, Index => "end",
            Text => "{" & LF & "Size:}");
         if Installing then
            Check_Module_Size_Loop :
            for Module of Player_Ship.Modules loop
               if Module.M_Type = HULL
                 and then Size >
                   Get_Module(Index => Module.Proto_Index).Value then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text =>
                       "{" & Natural'Image(Size) &
                       " (needs a bigger hull)} [list red]");
                  Added := True;
                  exit Check_Module_Size_Loop;
               end if;
            end loop Check_Module_Size_Loop;
         end if;
         if not Added then
            Insert
              (TextWidget => Module_Text, Index => "end",
               Text => "{" & Natural'Image(Size) & "}");
         end if;
      end if;
      if Weight > 0 then
         Insert
           (TextWidget => Module_Text, Index => "end",
            Text => "{" & LF & "Weight:" & Natural'Image(Weight) & " kg}");
         if Ship_Module_Index > 0 then
            if Weight > Player_Ship.Modules(Ship_Module_Index).Weight then
               Insert
                 (TextWidget => Module_Text, Index => "end",
                  Text => "{ (heavier)}");
            elsif Weight < Player_Ship.Modules(Ship_Module_Index).Weight then
               Insert
                 (TextWidget => Module_Text, Index => "end",
                  Text => "{ (lighter)}");
            end if;
         end if;
      end if;
      if Installing then
         Insert
           (TextWidget => Module_Text, Index => "end",
            Text => "{" & LF & "Repair/Upgrade material: }");
         M_Amount := 0;
         Repair_Materials_Loop :
         for I in 1 .. Get_Proto_Amount loop
            if To_String(Source => Get_Proto_Item(Index => I).I_Type) =
              To_String
                (Source =>
                   Get_Module(Index => Module_Index).Repair_Material) then
               if M_Amount > 0 then
                  Insert
                    (TextWidget => Module_Text, Index => "end",
                     Text => "{ or }");
               end if;
               Insert
                 (TextWidget => Module_Text, Index => "end",
                  Text =>
                    "{" &
                    To_String(Source => Get_Proto_Item(Index => I).Name) &
                    "}");
               M_Amount := M_Amount + 1;
            end if;
         end loop Repair_Materials_Loop;
         Insert
           (TextWidget => Module_Text, Index => "end",
            Text =>
              "{" & LF & "Repair/Upgrade skill: " &
              To_String
                (Source =>
                   SkillsData_Container.Element
                     (Container => Skills_List,
                      Index => Get_Module(Index => Module_Index).Repair_Skill)
                     .Name) &
              "/" &
              To_String
                (Source =>
                   AttributesData_Container.Element
                     (Container => Attributes_List,
                      Index =>
                        SkillsData_Container.Element
                          (Container => Skills_List,
                           Index =>
                             Get_Module(Index => Module_Index).Repair_Skill)
                          .Attribute)
                     .Name) &
              "}");
         if Get_Module(Index => Module_Index).Unique then
            Insert
              (TextWidget => Module_Text, Index => "end",
               Text =>
                 "{" & LF &
                 "The module is unique. Only one module of that type can be installed on the ship.}");
         end if;
         if Get_Module(Index => Module_Index).Description /=
           Short_String.Null_Bounded_String then
            Insert
              (TextWidget => Module_Text, Index => "end",
               Text =>
                 "{" & LF & LF &
                 To_String
                   (Source => Get_Module(Index => Module_Index).Description) &
                 "}");
         end if;
      end if;
   end Set_Module_Info;

   -- ****if* ShipyardUI/ShipyardUI.Set_Install_Button
   -- FUNCTION
   -- Set enabled/disabled state for the install button
   -- PARAMETERS
   -- Install_Button - The button which state will be set
   -- Money_Index_2   - The index of money in the player's ship's cargo
   -- Cost          - The cost of the module to install
   -- SOURCE
   procedure Set_Install_Button
     (Install_Button: Ttk_Button; Money_Index_2, Cost: Natural) is
      -- ****
      Used_Space, All_Space, Max_Size: Natural;
      Has_Unique: Boolean := False;
      Free_Turret_Index: Natural := 0;
   begin
      Find_Hull_And_Free_Turret_Loop :
      for I in Player_Ship.Modules.Iterate loop
         case Player_Ship.Modules(I).M_Type is
            when HULL =>
               Max_Size :=
                 Get_Module(Index => Player_Ship.Modules(I).Proto_Index).Value;
               Used_Space := Player_Ship.Modules(I).Installed_Modules;
               All_Space := Player_Ship.Modules(I).Max_Modules;
            when TURRET =>
               if Player_Ship.Modules(I).Gun_Index = 0
                 and then
                   Get_Module(Index => Player_Ship.Modules(I).Proto_Index)
                     .Size >=
                   Get_Module(Index => Module_Index).Size then
                  Free_Turret_Index :=
                    Modules_Container.To_Index(Position => I);
               end if;
            when others =>
               null;
         end case;
      end loop Find_Hull_And_Free_Turret_Loop;
      Check_Unique_Module_Loop :
      for Module of Player_Ship.Modules loop
         if Get_Module(Index => Module.Proto_Index).M_Type =
           Get_Module(Index => Module_Index).M_Type and
           Get_Module(Index => Module_Index).Unique then
            Has_Unique := True;
            exit Check_Unique_Module_Loop;
         end if;
      end loop Check_Unique_Module_Loop;
      if Money_Index_2 = 0 then
         configure
           (Widgt => Install_Button,
            options => "-state disabled -text {No money}");
         Add
           (Widget => Install_Button,
            Message => "You don't have any money to buy the module.");
      else
         if Inventory_Container.Element
             (Container => Player_Ship.Cargo, Index => Money_Index_2)
             .Amount <
           Cost then
            configure
              (Widgt => Install_Button,
               options => "-state disabled -text {No money}");
            Add
              (Widget => Install_Button,
               Message => "You don't have enough money to buy the module.");
         elsif Has_Unique then
            configure
              (Widgt => Install_Button,
               options => "-state disabled -text {Unique}");
            Add
              (Widget => Install_Button,
               Message =>
                 "Only one module of that type can be installed on the ship.");
         elsif Get_Module(Index => Module_Index).M_Type not in GUN |
               HARPOON_GUN | HULL then
            if Get_Module(Index => Module_Index).Size > Max_Size then
               configure
                 (Widgt => Install_Button,
                  options => "-state disabled -text {Too big}");
               Add
                 (Widget => Install_Button,
                  Message =>
                    "The selected module is too big for your's ship's hull.");
            elsif (All_Space - Used_Space) <
              Get_Module(Index => Module_Index).Size and
              Get_Module(Index => Module_Index).M_Type /= ARMOR then
               configure
                 (Widgt => Install_Button,
                  options => "-state disabled -text {No space}");
               Add
                 (Widget => Install_Button,
                  Message =>
                    "You don't have enough space in your ship's hull to install the module.");
            end if;
         elsif Get_Module(Index => Module_Index).M_Type = HULL and
           Get_Module(Index => Module_Index).Max_Value < Used_Space then
            configure
              (Widgt => Install_Button,
               options => "-state disabled -text {Too small}");
            Add
              (Widget => Install_Button,
               Message =>
                 "The selected hull is too small to replace your current hull.");
         elsif Get_Module(Index => Module_Index).M_Type in GUN | HARPOON_GUN
           and then Free_Turret_Index = 0 then
            configure
              (Widgt => Install_Button,
               options => "-state disabled -text {No turret}");
            Add
              (Widget => Install_Button,
               Message =>
                 "You don't have a free turret to install the selected gun.");
         else
            configure
              (Widgt => Install_Button,
               options => "-state !disabled -text Install");
         end if;
      end if;
   end Set_Install_Button;

   -- ****f* ShipyardUI/ShipyardUI.Show_Install_Info_Command
   -- FUNCTION
   -- Show information about the selected module to install
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command. Unused
   -- SOURCE
   function Show_Install_Info_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Install_Info_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc, Argv);
      use Tiny_String;

      Cost: Positive;
      Money_Index_2: Natural;
      Module_Dialog: constant Ttk_Frame :=
        Create_Dialog
          (Name => ".moduledialog",
           Title =>
             To_String(Source => Get_Module(Index => Module_Index).Name));
      Module_Text: constant Tk_Text :=
        Create
          (pathName => Module_Dialog & ".info",
           options => "-height 10 -width 40");
      Frame: constant Ttk_Frame :=
        Create(pathName => Module_Dialog & ".buttonbox");
      Close_Button: constant Ttk_Button :=
        Get_Widget(pathName => Module_Dialog & ".buttonbox.button");
      Install_Button: constant Ttk_Button :=
        Create
          (pathName => Module_Dialog & ".buttonbox.install",
           options =>
             "-text Install -image buyicon -style Dialog.TButton -command {CloseDialog " &
             Module_Dialog & ";ManipulateModule install}");
      Compare_Frame: constant Ttk_Frame :=
        Create(pathName => Module_Dialog & ".compare");
      Compare_Box: constant Ttk_ComboBox :=
        Create
          (pathName => Compare_Frame & ".combo", options => "-state readonly");
      Compare_Label: constant Ttk_Label :=
        Create
          (pathName => Compare_Frame & ".label",
           options => "-text {Compare with:}");
      Module_Iterator: Natural := 0;
      Compare_Modules: Unbounded_String := Null_Unbounded_String;
   begin
      Fill_Compare_Modules_Loop :
      for I in Player_Ship.Modules.Iterate loop
         if Get_Module(Index => Player_Ship.Modules(I).Proto_Index).M_Type =
           Get_Module(Index => Module_Index).M_Type then
            Module_Iterator := Module_Iterator + 1;
            Append
              (Source => Compare_Modules,
               New_Item =>
                 "{" & To_String(Source => Player_Ship.Modules(I).Name) &
                 "} ");
         end if;
      end loop Fill_Compare_Modules_Loop;
      if Module_Iterator > 1 then
         configure
           (Widgt => Compare_Box,
            options =>
              "-values {" & To_String(Source => Compare_Modules) & "}");
         Current(ComboBox => Compare_Box, NewIndex => "0");
         Tcl.Tk.Ada.Grid.Grid
           (Slave => Compare_Label, Options => "-padx {0 5}");
         Tcl.Tk.Ada.Grid.Grid
           (Slave => Compare_Box, Options => "-row 0 -column 1 -padx {5 0}");
         Tcl.Tk.Ada.Grid.Grid
           (Slave => Compare_Frame, Options => "-pady {0 5}");
         Bind
           (Widgt => Compare_Box, Sequence => "<<ComboboxSelected>>",
            Script => "{CompareModules}");
      end if;
      Cost := Get_Module(Index => Module_Index).Price;
      Count_Price(Price => Cost, Trader_Index => Find_Member(Order => TALK));
      Money_Index_2 :=
        Find_Item(Inventory => Player_Ship.Cargo, Proto_Index => Money_Index);
      Tag_Configure
        (TextWidget => Module_Text, TagName => "red",
         Options =>
           "-foreground " &
           Tcl_GetVar
             (interp => Interp,
              varName =>
                "ttk::theme::" &
                To_String(Source => Game_Settings.Interface_Theme) &
                "::colors(-red)"));
      Tag_Configure
        (TextWidget => Module_Text, TagName => "green",
         Options =>
           "-foreground " &
           Tcl_GetVar
             (interp => Interp,
              varName =>
                "ttk::theme::" &
                To_String(Source => Game_Settings.Interface_Theme) &
                "::colors(-green)"));
      Set_Module_Info(Installing => True);
      configure
        (Widgt => Module_Text,
         options =>
           "-state disabled -height" &
           Positive'Image
             (Positive'Value
                (Count
                   (TextWidget => Module_Text, Options => "-displaylines",
                    Index1 => "0.0", Index2 => "end")) /
              Positive'Value
                (Metrics(Font => "InterfaceFont", Option => "-linespace")) +
              1));
      Tcl.Tk.Ada.Grid.Grid
        (Slave => Module_Text, Options => "-padx 5 -pady {5 0}");
      Tcl.Tk.Ada.Grid.Grid(Slave => Install_Button, Options => "-padx {0 5}");
      Set_Install_Button
        (Install_Button => Install_Button, Money_Index_2 => Money_Index_2,
         Cost => Cost);
      Add_Close_Button
        (Name => Module_Dialog & ".buttonbox.button", Text => "Close",
         Command => "CloseDialog " & Module_Dialog, Column => 1);
      Tcl.Tk.Ada.Grid.Grid(Slave => Frame, Options => "-pady {0 5}");
      Focus(Widgt => Close_Button);
      Bind
        (Widgt => Close_Button, Sequence => "<Tab>",
         Script => "{focus " & Install_Button & ";break}");
      Bind
        (Widgt => Module_Dialog, Sequence => "<Escape>",
         Script => "{" & Close_Button & " invoke;break}");
      Bind
        (Widgt => Close_Button, Sequence => "<Escape>",
         Script => "{" & Close_Button & " invoke;break}");
      Show_Dialog
        (Dialog => Module_Dialog, Relative_X => 0.25, Relative_Y => 0.15);
      return TCL_OK;
   end Show_Install_Info_Command;

   -- ****f* ShipyardUI/ShipyardUI.Manipulate_Module_Command
   -- FUNCTION
   -- Install or remove the selected module
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command. Unused
   -- SOURCE
   function Manipulate_Module_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Manipulate_Module_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Argc);
   begin
      if CArgv.Arg(Argv => Argv, N => 1) = "install" then
         Bases.Ship.Upgrade_Ship
           (Install => True, Module_Index => Module_Index);
      else
         Bases.Ship.Upgrade_Ship
           (Install => False, Module_Index => Module_Index);
         Tcl_Eval
           (interp => Interp, strng => "SortShipyardModules remove 0 {} 10");
      end if;
      Update_Messages;
      return
        Show_Shipyard_Command
          (Client_Data => Client_Data, Interp => Interp, Argc => 2,
           Argv => CArgv.Empty & "ShowShipyard" & "0");
   exception
      when Trade_No_Money =>
         Show_Message
           (Text =>
              "You don't have " & To_String(Source => Money_Name) &
              " to pay for modules.",
            Title => "Can't install module");
         return TCL_OK;
      when An_Exception : Trade_Not_Enough_Money =>
         Show_Message
           (Text =>
              "You don't have enough " & To_String(Source => Money_Name) &
              " to pay for " & Exception_Message(X => An_Exception) & ".",
            Title => "Can't install module");
         return TCL_OK;
      when An_Exception : Bases_Ship_Unique_Module =>
         Show_Message
           (Text =>
              "You can't install another " &
              Exception_Message(X => An_Exception) &
              " because you have installed one module that type. Remove old first.",
            Title => "Can't install module");
         return TCL_OK;
      when An_Exception : Bases_Ship_Installation_Error |
        Bases_Ship_Removing_Error =>
         Show_Message
           (Text => Exception_Message(X => An_Exception),
            Title =>
              "Can't" &
              (if CArgv.Arg(Argv => Argv, N => 1) = "install" then "install"
               else "remove") &
              " module");
         return TCL_OK;
      when Trade_No_Free_Cargo =>
         Show_Message
           (Text =>
              "You don't have enough free space for " &
              To_String(Source => Money_Name) & " in ship cargo.",
            Title => "Can't remove module");
         return TCL_OK;
      when Trade_No_Money_In_Base =>
         Show_Message
           (Text =>
              "Base don't have enough " & To_String(Source => Money_Name) &
              " for buy this module.",
            Title => "Can't remove module");
         return TCL_OK;
   end Manipulate_Module_Command;

   -- ****f* ShipyardUI/ShipyardUI.Show_Remove_Info_Command
   -- FUNCTION
   -- Show information about the selected module to remove
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed. Unused
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command. Unused
   -- SOURCE
   function Show_Remove_Info_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Remove_Info_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Interp, Argc, Argv);
      use Short_String;
      use Tiny_String;

      Cost: Natural;
      Damage: Float;
      Ship_Module_Index: constant Natural := Module_Index;
      Module_Dialog: constant Ttk_Frame :=
        Create_Dialog
          (Name => ".moduledialog",
           Title =>
             To_String(Source => Player_Ship.Modules(Ship_Module_Index).Name));
      Damage_Bar: constant Ttk_ProgressBar :=
        Create(pathName => Module_Dialog & ".damage");
      Module_Text: constant Tk_Text :=
        Create
          (pathName => Module_Dialog & ".info",
           options => "-height 10 -width 40");
      Label: Ttk_Label := Create(pathName => Module_Dialog & ".damagelbl");
      Remove_Button: Ttk_Button;
      Close_Button: constant Ttk_Button :=
        Get_Widget(pathName => Module_Dialog & ".buttonbox.button");
      Frame: constant Ttk_Frame :=
        Create(pathName => Module_Dialog & ".buttonbox");
   begin
      Tcl.Tk.Ada.Busy.Busy(Window => Game_Header);
      Tcl.Tk.Ada.Busy.Busy(Window => Main_Paned);
      Damage :=
        1.0 -
        Float(Player_Ship.Modules(Ship_Module_Index).Durability) /
          Float(Player_Ship.Modules(Ship_Module_Index).Max_Durability);
      Cost :=
        Get_Module(Index => Player_Ship.Modules(Ship_Module_Index).Proto_Index)
          .Price -
        Integer
          (Float
             (Get_Module
                (Index => Player_Ship.Modules(Ship_Module_Index).Proto_Index)
                .Price) *
           Damage);
      if Cost = 0 then
         Cost := 1;
      end if;
      Count_Price
        (Price => Cost, Trader_Index => Find_Member(Order => TALK),
         Reduce => False);
      Tcl.Tk.Ada.Grid.Grid
        (Slave => Module_Text, Options => "-padx 5 -pady {5 0}");
      configure(Widgt => Module_Text, options => "-state normal");
      Delete(TextWidget => Module_Text, StartIndex => "1.0", Indexes => "end");
      Insert
        (TextWidget => Module_Text, Index => "end",
         Text =>
           "{Remove gain:" & Positive'Image(Cost) & LF & "Removing time:" &
           Positive'Image
             (Get_Module
                (Index => Player_Ship.Modules(Ship_Module_Index).Proto_Index)
                .Install_Time) &
           " minutes}");
      Set_Module_Info(Installing => False);
      if Damage > 0.0 then
         configure
           (Widgt => Damage_Bar, options => "-value" & Float'Image(Damage));
         if Damage < 0.2 then
            configure
              (Widgt => Label, options => "-text {Damage: Slightly damaged}");
         elsif Damage < 0.5 then
            configure(Widgt => Label, options => "-text {Damage: Damaged}");
         elsif Damage < 0.8 then
            configure
              (Widgt => Label, options => "-text {Damage: Heavily damaged}");
         elsif Damage < 1.0 then
            configure
              (Widgt => Label, options => "-text {Damage: Almost destroyed}");
         else
            configure(Widgt => Label, options => "-text {Damage: Destroyed}");
         end if;
         Tcl.Tk.Ada.Grid.Grid(Slave => Label);
         Tcl.Tk.Ada.Grid.Grid(Slave => Damage_Bar);
      end if;
      if Get_Module
          (Index => Player_Ship.Modules(Ship_Module_Index).Proto_Index)
          .Description /=
        Short_String.Null_Bounded_String then
         Label :=
           Create
             (pathName => Module_Dialog & ".description",
              options =>
                "-text {" & LF &
                To_String
                  (Source =>
                     Get_Module
                       (Index =>
                          Player_Ship.Modules(Ship_Module_Index).Proto_Index)
                       .Description) &
                "} -wraplength 450");
         Tcl.Tk.Ada.Grid.Grid(Slave => Label, Options => "-sticky w -padx 5");
      end if;
      configure
        (Widgt => Module_Text,
         options =>
           "-state disabled -height" &
           Positive'Image
             (Positive'Value
                (Count
                   (TextWidget => Module_Text, Options => "-displaylines",
                    Index1 => "0.0", Index2 => "end")) /
              Positive'Value
                (Metrics(Font => "InterfaceFont", Option => "-linespace")) +
              1));
      Remove_Button :=
        Create
          (pathName => Module_Dialog & ".buttonbox.install",
           options =>
             "-text Remove -image sellicon -style Dialog.TButton -command {CloseDialog " &
             Module_Dialog & ";ManipulateModule remove}");
      Tcl.Tk.Ada.Grid.Grid(Slave => Remove_Button, Options => "-padx {0 5}");
      Add_Close_Button
        (Name => Module_Dialog & ".buttonbox.button", Text => "Close",
         Command => "CloseDialog " & Module_Dialog, Column => 1);
      Tcl.Tk.Ada.Grid.Grid(Slave => Frame, Options => "-pady {0 5}");
      Focus(Widgt => Close_Button);
      Bind
        (Widgt => Close_Button, Sequence => "<Tab>",
         Script => "{focus " & Remove_Button & ";break}");
      Bind
        (Widgt => Module_Dialog, Sequence => "<Escape>",
         Script => "{" & Close_Button & " invoke;break}");
      Bind
        (Widgt => Close_Button, Sequence => "<Escape>",
         Script => "{" & Close_Button & " invoke;break}");
      Show_Dialog(Dialog => Module_Dialog, Relative_Y => 0.2);
      return TCL_OK;
   end Show_Remove_Info_Command;

   -- ****o* ShipyardUI/ShipyardUI.Show_Module_Menu_Command
   -- FUNCTION
   -- Show menu with actions for the selected module
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed. Unused
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowModuleMenu moduleindex actiontype
   -- ModuleIndex is a index of the module which menu will be shown,
   -- actiontype is action related to the module. Can be install or remove.
   -- SOURCE
   function Show_Module_Menu_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Module_Menu_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Interp, Argc);
      use Tiny_String;

      Module_Menu: constant Ttk_Frame :=
        Create_Dialog
          (Name => ".modulemenu", Title => "Module actions",
           Parent_Name => ".");
      procedure Add_Button(Name, Label, Command: String) is
         Button: constant Ttk_Button :=
           Create
             (pathName => Module_Menu & Name,
              options =>
                "-text {" & Label & "} -command {CloseDialog " & Module_Menu &
                " .;" & Command & "}");
      begin
         Tcl.Tk.Ada.Grid.Grid
           (Slave => Button,
            Options =>
              "-sticky we -padx 5" &
              (if Command'Length = 0 then " -pady {0 3}" else ""));
         Bind
           (Widgt => Button, Sequence => "<Escape>",
            Script => "{CloseDialog " & Module_Menu & " .;break}");
         if Command'Length = 0 then
            Bind
              (Widgt => Button, Sequence => "<Tab>",
               Script => "{focus " & Module_Menu & ".info;break}");
            Focus(Widgt => Button);
         end if;
      end Add_Button;
   begin
      Module_Index := Natural'Value(CArgv.Arg(Argv => Argv, N => 1));
      if CArgv.Arg(Argv => Argv, N => 2) = "install" then
         Change_Title
           (Dialog => Module_Menu,
            New_Title =>
              To_String(Source => Get_Module(Index => Module_Index).Name) &
              " actions");
         Add_Button
           (Name => ".info", Label => "Show module details",
            Command => "ShowInstallInfo");
         Add_Button
           (Name => ".install", Label => "Install module",
            Command => "ManipulateModule install");
         Set_Install_Button_Block :
         declare
            Cost: Positive;
            Money_Index_2: Natural := 0;
            Button: constant Ttk_Button :=
              Get_Widget(pathName => Module_Menu & ".install");
         begin
            Cost := Get_Module(Index => Module_Index).Price;
            Count_Price
              (Price => Cost, Trader_Index => Find_Member(Order => TALK));
            Money_Index_2 :=
              Find_Item
                (Inventory => Player_Ship.Cargo, Proto_Index => Money_Index);
            Set_Install_Button
              (Install_Button => Button, Money_Index_2 => Money_Index_2,
               Cost => Cost);
         end Set_Install_Button_Block;
      else
         Change_Title
           (Dialog => Module_Menu,
            New_Title =>
              To_String(Source => Player_Ship.Modules(Module_Index).Name) &
              " actions");
         Add_Button
           (Name => ".info", Label => "Show module details",
            Command => "ShowRemoveInfo");
         Add_Button
           (Name => ".install", Label => "Remove module",
            Command => "ManipulateModule remove");
      end if;
      Add_Button(Name => ".close", Label => "Close", Command => "");
      Show_Dialog(Dialog => Module_Menu, Parent_Frame => ".");
      return TCL_OK;
   end Show_Module_Menu_Command;

   -- ****o* ShipyardUI/ShipyardUI.Show_Shipyard_Tab_Command
   -- FUNCTION
   -- Show the install or remove modules options in shipyard
   -- PARAMETERS
   -- Client_Data - Custom data send to the command.
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command.
   -- Argv        - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowShipyardTab
   -- SOURCE
   function Show_Shipyard_Tab_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Shipyard_Tab_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Argv);
      Shipyard_Canvas: constant Tk_Canvas :=
        Get_Widget
          (pathName => Main_Paned & ".shipyardframe.canvas", Interp => Interp);
      Shipyard_Frame: constant Ttk_Frame :=
        Get_Widget(pathName => Shipyard_Canvas & ".shipyard");
      Frame: Ttk_Frame;
   begin
      if Tcl_GetVar(interp => Interp, varName => "newtab") = "install" then
         Frame := Get_Widget(pathName => Shipyard_Frame & ".remove");
         Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Frame);
         Frame := Get_Widget(pathName => Shipyard_Frame & ".install");
         Tcl.Tk.Ada.Grid.Grid(Slave => Frame);
      else
         Frame := Get_Widget(pathName => Shipyard_Frame & ".install");
         Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Frame);
         Frame := Get_Widget(pathName => Shipyard_Frame & ".remove");
         Tcl.Tk.Ada.Grid.Grid(Slave => Frame);
      end if;
      Delete(CanvasWidget => Shipyard_Canvas, TagOrId => "all");
      Canvas_Create
        (Parent => Shipyard_Canvas, Child_Type => "window",
         Options =>
           "0 0 -anchor nw -window " & Widget_Image(Win => Shipyard_Frame));
      Tcl_Eval(interp => Interp, strng => "update");
      configure
        (Widgt => Shipyard_Canvas,
         options =>
           "-scrollregion [list " &
           BBox(CanvasWidget => Shipyard_Canvas, TagOrId => "all") & "]");
      Tcl_SetResult(interp => Interp, str => "1");
      if Argc = 1 then
         return
           Show_Shipyard_Command
             (Client_Data => Client_Data, Interp => Interp, Argc => 2,
              Argv => CArgv.Empty & "ShowShipyard" & "0");
      else
         return TCL_OK;
      end if;
   end Show_Shipyard_Tab_Command;

   -- ****it* ShipyardUI/ShipyardUI.Modules_Sort_Orders
   -- FUNCTION
   -- Sorting orders for the ship modules list
   -- OPTIONS
   -- NAMEASC      - Sort modules by name ascending
   -- NAMEDESC     - Sort modules by name descending
   -- TYPEASC      - Sort modules by type ascending
   -- TYPEDESC     - Sort modules by type descending
   -- SIZEASC      - Sort modules by size ascending
   -- SIZEDESC     - Sort modules by size descending
   -- MATERIALASC  - Sort modules by material ascending
   -- MATERIALDESC - Sort modules by material descending
   -- PRICEASC     - Sort modules by price ascending
   -- PRICEDESC    - Sort modules by price descending
   -- NONE       - No sorting modules (default)
   -- HISTORY
   -- 6.4 - Added
   -- SOURCE
   type Modules_Sort_Orders is
     (NAMEASC, NAMEDESC, TYPEASC, TYPEDESC, SIZEASC, SIZEDESC, MATERIALASC,
      MATERIALDESC, PRICEASC, PRICEDESC, NONE) with
      Default_Value => NONE;
      -- ****

      -- ****id* ShipyardUI/ShipyardUI.Default_Modules_Sort_Order
      -- FUNCTION
      -- Default sorting order for the player's ship's modules
      -- HISTORY
      -- 6.4 - Added
      -- SOURCE
   Default_Modules_Sort_Order: constant Modules_Sort_Orders := NONE;
   -- ****

   -- ****iv* ShipyardUI/ShipyardUI.Modules_Sort_Order
   -- FUNCTION
   -- The current sorting order for modules list
   -- HISTORY
   -- 6.4 - Added
   -- SOURCE
   Modules_Sort_Order: Modules_Sort_Orders := Default_Modules_Sort_Order;
   -- ****

   -- ****o* ShipyardUI/ShipyardUI.Sort_Modules_Command
   -- FUNCTION
   -- Sort the ship modules lists
   -- PARAMETERS
   -- Client_Data - Custom data send to the command.
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- SortShipModules action moduletype page x
   -- Action is a type of action, can be install or remove, moduletype is a
   -- type of modules to show, page is the number of currently showed page
   -- of list and x is X axis coordinate where the player clicked the mouse
   -- button
   -- SOURCE
   function Sort_Modules_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Sort_Modules_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Argc);
      use Tiny_String;

      Column: constant Positive :=
        Get_Column_Number
          (Table =>
             (if CArgv.Arg(Argv => Argv, N => 1) = "install" then Install_Table
              else Remove_Table),
           X_Position => Natural'Value(CArgv.Arg(Argv => Argv, N => 4)));
      type Local_Module_Data is record
         Name: Bounded_String;
         M_Type: Unbounded_String;
         Size: Natural;
         Material: Bounded_String;
         Price: Positive;
         Id: Positive;
      end record;
      type Modules_Array is array(Positive range <>) of Local_Module_Data;
      Local_Modules: Modules_Array
        (1 ..
             (if CArgv.Arg(Argv => Argv, N => 1) = "install" then
                Get_Modules_Amount
              else Positive(Player_Ship.Modules.Length)));
      Index: Positive := 1;
      Cost: Natural;
      Damage: Float;
      function "<"(Left, Right: Local_Module_Data) return Boolean is
      begin
         if Modules_Sort_Order = NAMEASC and then Left.Name < Right.Name then
            return True;
         end if;
         if Modules_Sort_Order = NAMEDESC and then Left.Name > Right.Name then
            return True;
         end if;
         if Modules_Sort_Order = TYPEASC
           and then Left.M_Type < Right.M_Type then
            return True;
         end if;
         if Modules_Sort_Order = TYPEDESC
           and then Left.M_Type > Right.M_Type then
            return True;
         end if;
         if Modules_Sort_Order = SIZEASC and then Left.Size < Right.Size then
            return True;
         end if;
         if Modules_Sort_Order = SIZEDESC and then Left.Size > Right.Size then
            return True;
         end if;
         if Modules_Sort_Order = MATERIALASC
           and then Left.Material < Right.Material then
            return True;
         end if;
         if Modules_Sort_Order = MATERIALDESC
           and then Left.Material > Right.Material then
            return True;
         end if;
         if Modules_Sort_Order = PRICEASC
           and then Left.Price < Right.Price then
            return True;
         end if;
         if Modules_Sort_Order = PRICEDESC
           and then Left.Price > Right.Price then
            return True;
         end if;
         return False;
      end "<";
      procedure Sort_Modules is new Ada.Containers.Generic_Array_Sort
        (Index_Type => Positive, Element_Type => Local_Module_Data,
         Array_Type => Modules_Array);
   begin
      case Column is
         when 1 =>
            if Modules_Sort_Order = NAMEASC then
               Modules_Sort_Order := NAMEDESC;
            else
               Modules_Sort_Order := NAMEASC;
            end if;
         when 2 =>
            if Modules_Sort_Order = TYPEASC then
               Modules_Sort_Order := TYPEDESC;
            else
               Modules_Sort_Order := TYPEASC;
            end if;
         when 3 =>
            if Modules_Sort_Order = SIZEASC then
               Modules_Sort_Order := SIZEDESC;
            else
               Modules_Sort_Order := SIZEASC;
            end if;
         when 4 =>
            if Modules_Sort_Order = MATERIALASC then
               Modules_Sort_Order := MATERIALDESC;
            else
               Modules_Sort_Order := MATERIALASC;
            end if;
         when 5 =>
            if Modules_Sort_Order = PRICEASC then
               Modules_Sort_Order := PRICEDESC;
            else
               Modules_Sort_Order := PRICEASC;
            end if;
         when others =>
            null;
      end case;
      if Modules_Sort_Order = NONE then
         return TCL_OK;
      end if;
      if CArgv.Arg(Argv => Argv, N => 1) = "install" then
         Fill_Local_Install_Modules_Loop :
         for I in 1 .. Get_Modules_Amount loop
            Cost := Get_Module(Index => I).Price;
            Count_Price
              (Price => Cost, Trader_Index => Find_Member(Order => TALK));
            if Cost = 0 then
               Cost := 1;
            end if;
            Local_Modules(Index) :=
              (Name => Get_Module(Index => I).Name,
               M_Type =>
                 To_Unbounded_String
                   (Source => Get_Module_Type(Module_Index => I)),
               Size =>
                 (if Get_Module(Index => I).M_Type = HULL then
                    Get_Module(Index => I).Max_Value
                  else Get_Module(Index => I).Size),
               Material => Get_Module(Index => I).Repair_Material,
               Price => Cost, Id => I);
            Index := Index + 1;
         end loop Fill_Local_Install_Modules_Loop;
      else
         Fill_Local_Remove_Modules_Loop :
         for I in Player_Ship.Modules.Iterate loop
            Damage :=
              1.0 -
              Float(Player_Ship.Modules(I).Durability) /
                Float(Player_Ship.Modules(I).Max_Durability);
            Cost :=
              Get_Module(Index => Player_Ship.Modules(I).Proto_Index).Price -
              Integer
                (Float
                   (Get_Module(Index => Player_Ship.Modules(I).Proto_Index)
                      .Price) *
                 Damage);
            if Cost = 0 then
               Cost := 1;
            end if;
            Count_Price
              (Price => Cost, Trader_Index => Find_Member(Order => TALK),
               Reduce => False);
            Local_Modules(Index) :=
              (Name =>
                 To_Bounded_String
                   (Source =>
                      To_String(Source => Player_Ship.Modules(I).Name)),
               M_Type =>
                 To_Unbounded_String
                   (Source =>
                      Get_Module_Type
                        (Module_Index => Player_Ship.Modules(I).Proto_Index)),
               Size =>
                 Get_Module(Index => Player_Ship.Modules(I).Proto_Index).Size,
               Material =>
                 Get_Module(Index => Player_Ship.Modules(I).Proto_Index)
                   .Repair_Material,
               Price => Cost, Id => Modules_Container.To_Index(Position => I));
            Index := Index + 1;
         end loop Fill_Local_Remove_Modules_Loop;
      end if;
      Sort_Modules(Container => Local_Modules);
      if CArgv.Arg(Argv => Argv, N => 1) = "install" then
         Install_Indexes.Clear;
         Fill_Install_Indexes_Loop :
         for Module of Local_Modules loop
            Install_Indexes.Append(New_Item => Module.Id);
         end loop Fill_Install_Indexes_Loop;
      else
         Remove_Indexes.Clear;
         Fill_Remove_Indexes_Loop :
         for Module of Local_Modules loop
            Remove_Indexes.Append(New_Item => Module.Id);
         end loop Fill_Remove_Indexes_Loop;
      end if;
      return
        Show_Shipyard_Command
          (Client_Data => Client_Data, Interp => Interp, Argc => 3,
           Argv =>
             CArgv.Empty & "ShowShipyard" & CArgv.Arg(Argv => Argv, N => 2) &
             CArgv.Arg(Argv => Argv, N => 3));
   end Sort_Modules_Command;

   -- ****o* ShipyardUI/ShipyardUI.Compare_Modules_Command
   -- FUNCTION
   -- Show the comparison between the selected modules in install info
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed. Unused
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- CompareModules
   -- SOURCE
   function Compare_Modules_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Compare_Modules_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Interp, Argc, Argv);
   begin
      Set_Module_Info(Installing => True);
      return TCL_OK;
   end Compare_Modules_Command;

   procedure Add_Commands is
   begin
      Add_Command
        (Name => "ShowShipyard", Ada_Command => Show_Shipyard_Command'Access);
      Add_Command
        (Name => "ShowInstallInfo",
         Ada_Command => Show_Install_Info_Command'Access);
      Add_Command
        (Name => "ManipulateModule",
         Ada_Command => Manipulate_Module_Command'Access);
      Add_Command
        (Name => "ShowRemoveInfo",
         Ada_Command => Show_Remove_Info_Command'Access);
      Add_Command
        (Name => "ShowShipyardModuleMenu",
         Ada_Command => Show_Module_Menu_Command'Access);
      Add_Command
        (Name => "ShowShipyardTab",
         Ada_Command => Show_Shipyard_Tab_Command'Access);
      Add_Command
        (Name => "SortShipyardModules",
         Ada_Command => Sort_Modules_Command'Access);
      Add_Command
        (Name => "CompareModules",
         Ada_Command => Compare_Modules_Command'Access);
   end Add_Commands;

end Bases.ShipyardUI;
