-- Copyright (c) 2020-2024 Bartek thindil Jasicki
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

with Ada.Strings; use Ada.Strings;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Containers.Generic_Array_Sort;
with Interfaces.C; use Interfaces.C;
with CArgv; use CArgv;
with Tcl; use Tcl;
with Tcl.Ada; use Tcl.Ada;
with Tcl.Tk.Ada; use Tcl.Tk.Ada;
with Tcl.Tk.Ada.Event;
with Tcl.Tk.Ada.Grid;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.Canvas;
with Tcl.Tk.Ada.Widgets.Toplevel;
with Tcl.Tk.Ada.Widgets.TtkButton; use Tcl.Tk.Ada.Widgets.TtkButton;
with Tcl.Tk.Ada.Widgets.TtkEntry.TtkComboBox;
with Tcl.Tk.Ada.Widgets.TtkEntry.TtkSpinBox;
use Tcl.Tk.Ada.Widgets.TtkEntry.TtkSpinBox;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Tcl.Tk.Ada.Widgets.TtkLabel;
with Tcl.Tk.Ada.Widgets.TtkScrollbar;
with Tcl.Tk.Ada.Winfo;
with Tcl.Tklib.Ada.Autoscroll;
with Tcl.Tklib.Ada.Tooltip; use Tcl.Tklib.Ada.Tooltip;
with Config;
with CoreUI;
with Crew.Inventory; use Crew.Inventory;
with Dialogs; use Dialogs;
with Ships.Cargo;
with Ships.Crew;
with Table; use Table;
with Utils.UI; use Utils.UI;

package body Ships.UI.Crew.Inventory is

   -- ****iv* SUCI/SUCI.Inventory_Table
   -- FUNCTION
   -- Table with info about the crew member inventory
   -- SOURCE
   Inventory_Table: Table_Widget (Amount => 6);
   -- ****

   -- ****iv* SUCI/SUCI.Member_Index
   -- FUNCTION
   -- The index of the selected crew member
   -- SOURCE
   Member_Index: Positive;
   -- ****

   -- ****iv* SUCI/SUCI.Inventory_Indexes
   -- FUNCTION
   -- Indexes of the crew member items in inventory
   -- SOURCE
   Inventory_Indexes: Positive_Container.Vector;
   -- ****

   -- ****o* SUCI/SUCI.Update_Inventory_Command
   -- FUNCTION
   -- Update inventory list of the selected crew member
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed. Unused
   -- Argc        - Number of arguments passed to the command.
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- UpdateInventory memberindex page
   -- MemberIndex is the index of the crew member to show inventory, page
   -- is a number of the page of inventory list to show
   -- SOURCE
   function Update_Inventory_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Update_Inventory_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data);
      use Config;

      Member: Member_Data
        (Amount_Of_Attributes => Attributes_Amount,
         Amount_Of_Skills => Skills_Amount);
      Page: constant Positive :=
        (if Argc = 3 then Positive'Value(CArgv.Arg(Argv => Argv, N => 2))
         else 1);
      --## rule off SIMPLIFIABLE_EXPRESSIONS
      Start_Row: constant Positive :=
        ((Page - 1) * Get_Integer_Setting(Name => "listsLimit")) + 1;
      --## rule on SIMPLIFIABLE_EXPRESSIONS
      Current_Row: Positive := 1;
   begin
      Member_Index := Positive'Value(CArgv.Arg(Argv => Argv, N => 1));
      Member := Player_Ship.Crew(Member_Index);
      if Inventory_Table.Row > 1 then
         Clear_Table(Table => Inventory_Table);
      end if;
      if Inventory_Indexes.Length /=
        Inventory_Container.Length(Container => Member.Inventory) then
         Inventory_Indexes.Clear;
         Fill_Inventory_Indexes_Loop :
         for I in
           Inventory_Container.First_Index(Container => Member.Inventory) ..
             Inventory_Container.Last_Index(Container => Member.Inventory) loop
            Inventory_Indexes.Append(New_Item => I);
         end loop Fill_Inventory_Indexes_Loop;
      end if;
      Load_Inventory_Loop :
      for I in Inventory_Indexes.Iterate loop
         if Current_Row < Start_Row then
            Current_Row := Current_Row + 1;
            goto End_Of_Loop;
         end if;
         Add_Check_Button
           (Table => Inventory_Table,
            Tooltip => "Select the item for move or equip it.",
            Command =>
              "ToggleInventoryItem" &
              Positive'Image(Positive_Container.To_Index(Position => I)) &
              Positive'Image(Inventory_Indexes(I)),
            Checked =>
              (if
                 Tcl_GetVar
                   (interp => Interp,
                    varName =>
                      "invindex" &
                      Trim
                        (Source => Positive'Image(Inventory_Indexes(I)),
                         Side => Left)) =
                 "1"
               then True
               else False),
            Column => 1, Empty_Unchecked => True);
         Add_Button
           (Table => Inventory_Table,
            Text =>
              Get_Item_Name
                (Item =>
                   Inventory_Container.Element
                     (Container => Member.Inventory,
                      Index => Inventory_Indexes(I)),
                 Damage_Info => False, To_Lower => False),
            Tooltip => "Show the selected item's info",
            Command =>
              "ShowInventoryItemInfo " & Positive'Image(Inventory_Indexes(I)),
            Column => 2);
         Add_Progress_Bar
           (Table => Inventory_Table,
            Value =>
              Inventory_Container.Element
                (Container => Member.Inventory, Index => Inventory_Indexes(I))
                .Durability,
            Max_Value => Default_Item_Durability,
            Tooltip => "The current durability level of the selected item.",
            Command =>
              "ShowInventoryItemInfo " & Positive'Image(Inventory_Indexes(I)),
            Column => 3);
         if Item_Is_Used
             (Member_Index => Member_Index,
              Item_Index => Inventory_Indexes(I)) then
            Add_Check_Button
              (Table => Inventory_Table,
               Tooltip => "The item is used by the crew member",
               Command =>
                 "ShowInventoryItemInfo " &
                 Positive'Image(Inventory_Indexes(I)),
               Checked => True, Column => 4);
         else
            Add_Check_Button
              (Table => Inventory_Table,
               Tooltip => "The item isn't used by the crew member",
               Command =>
                 "ShowInventoryItemInfo " &
                 Positive'Image(Inventory_Indexes(I)),
               Checked => False, Column => 4);
         end if;
         Add_Button
           (Table => Inventory_Table,
            Text =>
              Positive'Image
                (Inventory_Container.Element
                   (Container => Member.Inventory,
                    Index => Inventory_Indexes(I))
                   .Amount),
            Tooltip => "The amount of the item owned by the crew member",
            Command =>
              "ShowInventoryItemInfo " & Positive'Image(Inventory_Indexes(I)),
            Column => 5);
         Add_Button
           (Table => Inventory_Table,
            Text =>
              Positive'Image
                (Inventory_Container.Element
                   (Container => Member.Inventory,
                    Index => Inventory_Indexes(I))
                   .Amount *
                 Get_Proto_Item
                   (Index =>
                      Inventory_Container.Element
                        (Container => Member.Inventory,
                         Index => Inventory_Indexes(I))
                        .Proto_Index)
                   .Weight) &
              " kg",
            Tooltip => "The total weight of the items",
            Command =>
              "ShowInventoryItemInfo " & Positive'Image(Inventory_Indexes(I)),
            Column => 6, New_Row => True);
         exit Load_Inventory_Loop when Inventory_Table.Row =
           Get_Integer_Setting(Name => "listsLimit") + 1;
         <<End_Of_Loop>>
      end loop Load_Inventory_Loop;
      if Page > 1 then
         Add_Pagination
           (Table => Inventory_Table,
            Previous_Command =>
              "UpdateInventory " & CArgv.Arg(Argv => Argv, N => 1) &
              Positive'Image(Page - 1),
            Next_Command =>
              (if
                 Inventory_Table.Row <
                 Get_Integer_Setting(Name => "listsLimit") + 1
               then ""
               else "UpdateInventory " & CArgv.Arg(Argv => Argv, N => 1) &
                 Positive'Image(Page + 1)));
      elsif Inventory_Table.Row =
        Get_Integer_Setting(Name => "listsLimit") + 1 then
         Add_Pagination
           (Table => Inventory_Table, Previous_Command => "",
            Next_Command =>
              "UpdateInventory " & CArgv.Arg(Argv => Argv, N => 1) &
              Positive'Image(Page + 1));
      end if;
      Update_Table(Table => Inventory_Table);
      return TCL_OK;
   end Update_Inventory_Command;

   -- ****it* SUCI/SUCI.Inventory_Sort_Orders
   -- FUNCTION
   -- Sorting orders for items inside various inventories
   -- OPTIONS
   -- SELECTEDASC    - Sort items by selected ascending
   -- SELETEDDESC    - Sort items by selected descending
   -- NAMEASC        - Sort items by name ascending
   -- NAMEDESC       - Sort items by name descending
   -- DURABILITYASC  - Sort items by durability ascending
   -- DURABILITYDESC - Sort items by durability descending
   -- TYPEASC        - Sort items by type ascending
   -- TYPEDESC       - Sort items by type descending
   -- AMOUNTASC      - Sort items by amount ascending
   -- AMOUNTDESC     - Sort items by amount descending
   -- WEIGHTASC      - Sort items by total weight ascending
   -- WEIGHTDESC     - Sort items by total weight descending
   -- USEDASC        - Sort items by use status (mobs inventory only) ascending
   -- USEDDESC       - Sort items by use status (mobs inventory only) descending
   -- NONE           - No sorting items (default)
   -- HISTORY
   -- 6.4 - Added
   -- 7.8 - Added SELECTEDASC and SELECTEDDESC values
   -- SOURCE
   type Inventory_Sort_Orders is
     (SELECTEDASC, SELECTEDDESC, NAMEASC, NAMEDESC, DURABILITYASC,
      DURABILITYDESC, TYPEASC, TYPEDESC, AMOUNTASC, AMOUNTDESC, WEIGHTASC,
      WEIGHTDESC, USEDASC, USEDDESC, NONE) with
      Default_Value => NONE;
      -- ****

      -- ****id* SUCI/SUCI.Default_Inventory_Sort_Order
      -- FUNCTION
      -- Default sorting order for items in various inventories
      -- HISTORY
      -- 6.4 - Added
      -- SOURCE
   Default_Inventory_Sort_Order: constant Inventory_Sort_Orders := NONE;
   -- ****

   --## rule off DIRECTLY_ACCESSED_GLOBALS
   -- ****iv* SUCI/SUCI.Inventory_Sort_Order
   -- FUNCTION
   -- The current sorting order of items in various inventories
   -- SOURCE
   Inventory_Sort_Order: Inventory_Sort_Orders := Default_Inventory_Sort_Order;
   -- ****
   --## rule on DIRECTLY_ACCESSED_GLOBALS

   -- ****o* SUCI/SUCI.Sort_Crew_Inventory_Command
   -- FUNCTION
   -- Sort the selected crew member inventory
   -- PARAMETERS
   -- Client_Data - Custom data send to the command.
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- SortCrewInventory x
   -- X is X axis coordinate where the player clicked the mouse button
   -- SOURCE
   function Sort_Crew_Inventory_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Sort_Crew_Inventory_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Argc);
      use Tiny_String;

      --## rule off DIRECTLY_ACCESSED_GLOBALS
      Column: constant Positive :=
        (if CArgv.Arg(Argv => Argv, N => 1) = "-1" then Positive'Last
         else Get_Column_Number
             (Table => Inventory_Table,
              X_Position => Natural'Value(CArgv.Arg(Argv => Argv, N => 1))));
      --## rule on DIRECTLY_ACCESSED_GLOBALS
      --## rule off TYPE_INITIAL_VALUES
      type Local_Item_Data is record
         Selected: Boolean;
         Name: Unbounded_String;
         Damage: Float;
         Item_Type: Bounded_String;
         Amount: Positive;
         Weight: Positive;
         Used: Boolean;
         Id: Positive;
      end record;
      type Inventory_Array is array(Positive range <>) of Local_Item_Data;
      --## rule on TYPE_INITIAL_VALUES
      --## rule off IMPROPER_INITIALIZATION
      --## rule off DIRECTLY_ACCESSED_GLOBALS
      Local_Inventory: Inventory_Array
        (1 ..
             Natural
               (Inventory_Container.Length
                  (Container => Player_Ship.Crew(Member_Index).Inventory)));
      --## rule on IMPROPER_INITIALIZATION
      function "<"(Left, Right: Local_Item_Data) return Boolean is
      begin
         if Inventory_Sort_Order = SELECTEDASC
           and then Left.Selected < Right.Selected then
            return True;
         end if;
         if Inventory_Sort_Order = SELECTEDDESC
           and then Left.Selected > Right.Selected then
            return True;
         end if;
         if Inventory_Sort_Order = NAMEASC and then Left.Name < Right.Name then
            return True;
         end if;
         if Inventory_Sort_Order = NAMEDESC
           and then Left.Name > Right.Name then
            return True;
         end if;
         if Inventory_Sort_Order = DURABILITYASC
           and then Left.Damage < Right.Damage then
            return True;
         end if;
         if Inventory_Sort_Order = DURABILITYDESC
           and then Left.Damage > Right.Damage then
            return True;
         end if;
         if Inventory_Sort_Order = TYPEASC
           and then Left.Item_Type < Right.Item_Type then
            return True;
         end if;
         if Inventory_Sort_Order = TYPEDESC
           and then Left.Item_Type > Right.Item_Type then
            return True;
         end if;
         if Inventory_Sort_Order = AMOUNTASC
           and then Left.Amount < Right.Amount then
            return True;
         end if;
         if Inventory_Sort_Order = AMOUNTDESC
           and then Left.Amount > Right.Amount then
            return True;
         end if;
         if Inventory_Sort_Order = WEIGHTASC
           and then Left.Weight < Right.Weight then
            return True;
         end if;
         if Inventory_Sort_Order = WEIGHTDESC
           and then Left.Weight > Right.Weight then
            return True;
         end if;
         if Inventory_Sort_Order = USEDASC and then Left.Used < Right.Used then
            return True;
         end if;
         if Inventory_Sort_Order = USEDDESC
           and then Left.Used > Right.Used then
            return True;
         end if;
         return False;
      end "<";
      procedure Sort_Inventory is new Ada.Containers.Generic_Array_Sort
        (Index_Type => Positive, Element_Type => Local_Item_Data,
         Array_Type => Inventory_Array);
   begin
      case Column is
         when 1 =>
            if Inventory_Sort_Order = SELECTEDASC then
               Inventory_Sort_Order := SELECTEDDESC;
            else
               Inventory_Sort_Order := SELECTEDASC;
            end if;
         when 2 =>
            if Inventory_Sort_Order = NAMEASC then
               Inventory_Sort_Order := NAMEDESC;
            else
               Inventory_Sort_Order := NAMEASC;
            end if;
         when 3 =>
            if Inventory_Sort_Order = DURABILITYASC then
               Inventory_Sort_Order := DURABILITYDESC;
            else
               Inventory_Sort_Order := DURABILITYASC;
            end if;
         when 4 =>
            if Inventory_Sort_Order = USEDASC then
               Inventory_Sort_Order := USEDDESC;
            else
               Inventory_Sort_Order := USEDASC;
            end if;
         when 5 =>
            if Inventory_Sort_Order = AMOUNTASC then
               Inventory_Sort_Order := AMOUNTDESC;
            else
               Inventory_Sort_Order := AMOUNTASC;
            end if;
         when 6 =>
            if Inventory_Sort_Order = WEIGHTASC then
               Inventory_Sort_Order := WEIGHTDESC;
            else
               Inventory_Sort_Order := WEIGHTASC;
            end if;
         when others =>
            null;
      end case;
      if Inventory_Sort_Order = NONE then
         return
           Update_Inventory_Command
             (Client_Data => Client_Data, Interp => Interp, Argc => 2,
              Argv =>
                CArgv.Empty & "UpdateInventory" &
                Trim(Source => Positive'Image(Member_Index), Side => Left));
      end if;
      Fill_Local_Inventory_Loop :
      for I in
        Inventory_Indexes.First_Index .. Inventory_Indexes.Last_Index loop
         Local_Inventory(I) :=
           (Selected =>
              (if
                 Tcl_GetVar
                   (interp => Interp,
                    varName =>
                      "invindex" &
                      Trim
                        (Source => Positive_Container.Extended_Index'Image(I),
                         Side => Left)) =
                 "1"
               then True
               else False),
            Name =>
              To_Unbounded_String
                (Source =>
                   Get_Item_Name
                     (Item =>
                        Inventory_Container.Element
                          (Container =>
                             Player_Ship.Crew(Member_Index).Inventory,
                           Index => I),
                      Damage_Info => False, To_Lower => False)),
            Damage =>
              Float
                (Inventory_Container.Element
                   (Container => Player_Ship.Crew(Member_Index).Inventory,
                    Index => I)
                   .Durability) /
              Float(Default_Item_Durability),
            Item_Type =>
              (if
                 Get_Proto_Item
                   (Index =>
                      Inventory_Container.Element
                        (Container => Player_Ship.Crew(Member_Index).Inventory,
                         Index => I)
                        .Proto_Index)
                   .Show_Type /=
                 Null_Bounded_String
               then
                 Get_Proto_Item
                   (Index =>
                      Inventory_Container.Element
                        (Container => Player_Ship.Crew(Member_Index).Inventory,
                         Index => I)
                        .Proto_Index)
                   .Show_Type
               else Get_Proto_Item
                   (Index =>
                      Inventory_Container.Element
                        (Container => Player_Ship.Crew(Member_Index).Inventory,
                         Index => I)
                        .Proto_Index)
                   .I_Type),
            Amount =>
              Inventory_Container.Element
                (Container => Player_Ship.Crew(Member_Index).Inventory,
                 Index => I)
                .Amount,
            Weight =>
              Inventory_Container.Element
                (Container => Player_Ship.Crew(Member_Index).Inventory,
                 Index => I)
                .Amount *
              Get_Proto_Item
                (Index =>
                   Inventory_Container.Element
                     (Container => Player_Ship.Crew(Member_Index).Inventory,
                      Index => I)
                     .Proto_Index)
                .Weight,
            Used =>
              Item_Is_Used(Member_Index => Member_Index, Item_Index => I),
            Id => I);
      end loop Fill_Local_Inventory_Loop;
      Sort_Inventory(Container => Local_Inventory);
      Inventory_Indexes.Clear;
      Fill_Inventory_Indexes_Loop :
      for Item of Local_Inventory loop
         Inventory_Indexes.Append(New_Item => Item.Id);
      end loop Fill_Inventory_Indexes_Loop;
      return
        Update_Inventory_Command
          (Client_Data => Client_Data, Interp => Interp, Argc => 4,
           Argv =>
             CArgv.Empty & "UpdateInventory" &
             Trim(Source => Positive'Image(Member_Index), Side => Left));
      --## rule on DIRECTLY_ACCESSED_GLOBALS
   end Sort_Crew_Inventory_Command;

   -- ****if* SUCI/SUCI.Reset_Selection
   -- FUNCTION
   -- Reset the currently selected items in the crew member inventory
   -- PARAMETERS
   -- Interp - The Tcl interpreter in which the selection will be reseted
   -- HISTORY
   -- 7.8 - Added
   -- SOURCE
   procedure Reset_Selection(Interp: Tcl_Interp) is
      -- ****
   begin
      --## rule off DIRECTLY_ACCESSED_GLOBALS
      Reset_Item_Selection_Loop :
      for I in
        1 ..
          Inventory_Container.Capacity
            (Container => Player_Ship.Crew(Member_Index).Inventory) loop
         if Tcl_GetVar
             (interp => Interp,
              varName => "invindex" & Trim(Source => I'Img, Side => Left)) =
           "1" then
            Tcl_UnsetVar
              (interp => Interp,
               varName => "invindex" & Trim(Source => I'Img, Side => Left));
         end if;
      end loop Reset_Item_Selection_Loop;
      --## rule on DIRECTLY_ACCESSED_GLOBALS
   end Reset_Selection;

   -- ****o* SUCI/SUCI.Show_Member_Inventory_Command
   -- FUNCTION
   -- Show inventory of the selected crew member
   -- PARAMETERS
   -- Client_Data - Custom data send to the command.
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command.
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowMemberInventory memberindex
   -- MemberIndex is the index of the crew member to show inventory
   -- SOURCE
   function Show_Member_Inventory_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Member_Inventory_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      use Tcl.Tk.Ada.Widgets.Canvas;
      use Tcl.Tk.Ada.Widgets.TtkLabel;
      use Tcl.Tk.Ada.Widgets.TtkScrollbar;
      use Tcl.Tk.Ada.Winfo;
      use Tcl.Tklib.Ada.Autoscroll;
      use Tiny_String;

      Local_Member_Index: constant Positive :=
        Positive'Value(CArgv.Arg(Argv => Argv, N => 1));
      Member_Dialog: constant Ttk_Frame :=
        Create_Dialog
          (Name => ".memberdialog",
           Title =>
             "Inventory of " &
             To_String(Source => Player_Ship.Crew(Local_Member_Index).Name),
           Columns => 2);
      Y_Scroll: constant Ttk_Scrollbar :=
        Create
          (pathName => Member_Dialog & ".yscroll",
           options =>
             "-orient vertical -command [list .memberdialog.canvas yview]");
      Member_Canvas: constant Tk_Canvas :=
        Create
          (pathName => Member_Dialog & ".canvas",
           options => "-yscrollcommand [list " & Y_Scroll & " set]");
      Member_Frame: constant Ttk_Frame :=
        Create(pathName => Member_Canvas & ".frame");
      Height: Positive := 10;
      Width: Positive;
      Free_Space_Label: constant Ttk_Label :=
        Create
          (pathName => Member_Frame & ".freespace",
           options =>
             "-text {Free inventory space:" &
             Integer'Image
               (Free_Inventory
                  (Member_Index =>
                     Positive'Value(CArgv.Arg(Argv => Argv, N => 1)),
                   Amount => 0)) &
             " kg} -wraplength 400");
      Dialog_Close_Button: constant Ttk_Button :=
        Create
          (pathName => Member_Dialog & ".button",
           options =>
             "-image exiticon -command {CloseDialog " & Member_Dialog &
             "} -text {Close} -style Dialog.TButton");
      Buttons_Box: constant Ttk_Frame :=
        Create(pathName => Member_Frame & ".selectbox");
      Select_All_Button: constant Ttk_Button :=
        Create
          (pathName => Buttons_Box & ".selectallbutton",
           options =>
             "-image selectallicon -command {ToggleAllInventory select} -style Small.TButton");
      Unselect_All_Button: constant Ttk_Button :=
        Create
          (pathName => Buttons_Box & ".unselectallbutton",
           options =>
             "-image unselectallicon -command {ToggleAllInventory unselect} -style Small.TButton");
   begin
      if Inventory_Container.Length
          (Container => Player_Ship.Crew(Local_Member_Index).Inventory) =
        0 then
         Tcl_Eval(interp => Interp, strng => "CloseDialog .memberdialog");
         Show_Message
           (Text =>
              To_String(Source => Player_Ship.Crew(Local_Member_Index).Name) &
              " doesn't own any items.",
            Title =>
              "Inventory of " &
              To_String(Source => Player_Ship.Crew(Local_Member_Index).Name));
         return TCL_OK;
      end if;
      --## rule off DIRECTLY_ACCESSED_GLOBALS
      Member_Index := Local_Member_Index;
      --## rule on DIRECTLY_ACCESSED_GLOBALS
      Reset_Selection(Interp => Interp);
      Add
        (Widget => Dialog_Close_Button,
         Message => "Close inventory \[Escape key\]");
      Tcl.Tk.Ada.Grid.Grid
        (Slave => Member_Canvas, Options => "-padx 5 -pady 5");
      Tcl.Tk.Ada.Grid.Grid
        (Slave => Y_Scroll,
         Options => "-row 1 -column 1 -padx 5 -pady 5 -sticky ns");
      Autoscroll(Scroll => Y_Scroll);
      Tcl.Tk.Ada.Grid.Grid(Slave => Free_Space_Label);
      Height :=
        Height +
        Positive'Value
          (Winfo_Get(Widgt => Free_Space_Label, Info => "reqheight"));
      Add(Widget => Select_All_Button, Message => "Select all items.");
      Tcl.Tk.Ada.Grid.Grid(Slave => Select_All_Button, Options => "-sticky w");
      Add(Widget => Unselect_All_Button, Message => "Unselect all items.");
      Tcl.Tk.Ada.Grid.Grid
        (Slave => Unselect_All_Button,
         Options => "-sticky w -row 0 -column 1");
      Height :=
        Height +
        Positive'Value
          (Winfo_Get(Widgt => Select_All_Button, Info => "reqheight"));
      Tcl.Tk.Ada.Grid.Grid
        (Slave => Buttons_Box, Options => "-sticky w -padx 5");
      --## rule off DIRECTLY_ACCESSED_GLOBALS
      Inventory_Table :=
        Create_Table
          (Parent => Widget_Image(Win => Member_Frame),
           Headers =>
             (1 => To_Unbounded_String(Source => ""),
              2 => To_Unbounded_String(Source => "Name"),
              3 => To_Unbounded_String(Source => "Durability"),
              4 => To_Unbounded_String(Source => "Used"),
              5 => To_Unbounded_String(Source => "Amount"),
              6 => To_Unbounded_String(Source => "Weight")),
           Scrollbar => Y_Scroll, Command => "SortCrewInventory",
           Tooltip_Text => "Press mouse button to sort the inventory.");
      if Update_Inventory_Command
          (Client_Data => Client_Data, Interp => Interp, Argc => Argc,
           Argv => Argv) =
        TCL_ERROR then
         return TCL_ERROR;
      end if;
      Height :=
        Height +
        Positive'Value
          (Winfo_Get(Widgt => Inventory_Table.Canvas, Info => "reqheight"));
      Width :=
        Positive'Value
          (Winfo_Get(Widgt => Inventory_Table.Canvas, Info => "reqwidth"));
      Tcl.Tk.Ada.Grid.Grid(Slave => Dialog_Close_Button, Options => "-pady 5");
      Widgets.Focus(Widgt => Inventory_Table.Canvas);
      --## rule on DIRECTLY_ACCESSED_GLOBALS
      Bind
        (Widgt => Dialog_Close_Button, Sequence => "<Tab>",
         Script => "{focus " & Select_All_Button & ";break}");
      Bind
        (Widgt => Dialog_Close_Button, Sequence => "<Escape>",
         Script => "{" & Dialog_Close_Button & " invoke;break}");
      Bind
        (Widgt => Select_All_Button, Sequence => "<Escape>",
         Script => "{" & Dialog_Close_Button & " invoke;break}");
      Bind
        (Widgt => Unselect_All_Button, Sequence => "<Escape>",
         Script => "{" & Dialog_Close_Button & " invoke;break}");
      --## rule off DIRECTLY_ACCESSED_GLOBALS
      Bind
        (Widgt => Inventory_Table.Canvas, Sequence => "<Escape>",
         Script => "{" & Dialog_Close_Button & " invoke;break}");
      --## rule on DIRECTLY_ACCESSED_GLOBALS
      Focus(Widgt => Dialog_Close_Button);
      if Height > 500 then
         Height := 500;
      end if;
      configure
        (Widgt => Member_Frame,
         options =>
           "-height" & Positive'Image(Height) & " -width" &
           Positive'Image(Width));
      configure
        (Widgt => Member_Canvas,
         options =>
           "-height" & Positive'Image(Height) & " -width" &
           Positive'Image(Width + 15));
      Canvas_Create
        (Parent => Member_Canvas, Child_Type => "window",
         Options => "0 0 -anchor nw -window " & Member_Frame);
      Tcl_Eval(interp => Interp, strng => "update");
      configure
        (Widgt => Member_Canvas,
         options =>
           "-scrollregion [list " &
           BBox(CanvasWidget => Member_Canvas, TagOrId => "all") & "]");
      Show_Dialog
        (Dialog => Member_Dialog, Relative_X => 0.2, Relative_Y => 0.2);
      return TCL_OK;
   end Show_Member_Inventory_Command;

   -- ****o* SUCI/SUCI.Set_Use_Item_Command
   -- FUNCTION
   -- Set if item is used by a crew member or not
   -- PARAMETERS
   -- Client_Data - Custom data send to the command.
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- SetUseItem itemindex
   -- itemindex is the index of the item which will be set
   -- SOURCE
   function Set_Use_Item_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Set_Use_Item_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Argc);
      use Tiny_String;

      Item_Index: constant Positive :=
        Positive'Value(CArgv.Arg(Argv => Argv, N => 1));
      --## rule off DIRECTLY_ACCESSED_GLOBALS
      Item_Type: constant Bounded_String :=
        Get_Proto_Item
          (Index =>
             Inventory_Container.Element
               (Container => Player_Ship.Crew(Member_Index).Inventory,
                Index => Item_Index)
               .Proto_Index)
          .I_Type;
   begin
      if Item_Is_Used
          (Member_Index => Member_Index, Item_Index => Item_Index) then
         Take_Off_Item(Member_Index => Member_Index, Item_Index => Item_Index);
         return
           Sort_Crew_Inventory_Command
             (Client_Data => Client_Data, Interp => Interp, Argc => 2,
              Argv => CArgv.Empty & "SortCrewInventory" & "-1");
      end if;
      if Item_Type = Weapon_Type then
         if Get_Proto_Item
             (Index =>
                Inventory_Container.Element
                  (Container => Player_Ship.Crew(Member_Index).Inventory,
                   Index => Item_Index)
                  .Proto_Index)
             .Value
             (4) =
           2 and
           Player_Ship.Crew(Member_Index).Equipment(SHIELD) /= 0 then
            Show_Message
              (Text =>
                 To_String(Source => Player_Ship.Crew(Member_Index).Name) &
                 " can't use this weapon because have shield equiped. Take off shield first.",
               Title => "Shield in use");
            return TCL_OK;
         end if;
         Player_Ship.Crew(Member_Index).Equipment(WEAPON) := Item_Index;
      elsif Item_Type = Shield_Type then
         if Player_Ship.Crew(Member_Index).Equipment(WEAPON) > 0 then
            if Get_Proto_Item
                (Index =>
                   Inventory_Container.Element
                     (Container => Player_Ship.Crew(Member_Index).Inventory,
                      Index =>
                        Player_Ship.Crew(Member_Index).Equipment(WEAPON))
                     .Proto_Index)
                .Value
                (4) =
              2 then
               Show_Message
                 (Text =>
                    To_String(Source => Player_Ship.Crew(Member_Index).Name) &
                    " can't use shield because have equiped two-hand weapon. Take off weapon first.",
                  Title => "Two handed weapon in use");
               return TCL_OK;
            end if;
         end if;
         Player_Ship.Crew(Member_Index).Equipment(SHIELD) := Item_Index;
      elsif Item_Type = Head_Armor then
         Player_Ship.Crew(Member_Index).Equipment(HELMET) := Item_Index;
      elsif Item_Type = Chest_Armor then
         Player_Ship.Crew(Member_Index).Equipment(TORSO) := Item_Index;
      elsif Item_Type = Arms_Armor then
         Player_Ship.Crew(Member_Index).Equipment(ARMS) := Item_Index;
      elsif Item_Type = Legs_Armor then
         Player_Ship.Crew(Member_Index).Equipment(LEGS) := Item_Index;
      elsif Is_Tool(Item_Type => Item_Type) then
         Player_Ship.Crew(Member_Index).Equipment(TOOL) := Item_Index;
      end if;
      --## rule on DIRECTLY_ACCESSED_GLOBALS
      return
        Sort_Crew_Inventory_Command
          (Client_Data => Client_Data, Interp => Interp, Argc => 2,
           Argv => CArgv.Empty & "SortCrewInventory" & "-1");
   end Set_Use_Item_Command;

   -- ****o* SUCI/SUCI.Show_Move_Item_Command
   -- FUNCTION
   -- Show UI to move the selected item to the ship cargo
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowMoveItem itemindex
   -- itemindex is the index of the item which will be set
   -- SOURCE
   function Show_Move_Item_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Move_Item_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Interp, Argc);

      Item_Index: constant Positive :=
        Positive'Value(CArgv.Arg(Argv => Argv, N => 1));
      --## rule off DIRECTLY_ACCESSED_GLOBALS
      Item_Dialog: constant Ttk_Frame :=
        Create_Dialog
          (Name => ".itemdialog",
           Title =>
             "Move " &
             Get_Item_Name
               (Item =>
                  Inventory_Container.Element
                    (Container => Player_Ship.Crew(Member_Index).Inventory,
                     Index => Item_Index)) &
             " to ship cargo",
           Title_Width => 400, Columns => 2, Parent_Name => ".memberdialog");
      Button: Ttk_Button :=
        Create
          (pathName => Item_Dialog & ".movebutton",
           options =>
             "-text Move -command {MoveItem " &
             CArgv.Arg(Argv => Argv, N => 1) &
             "} -image moveicon -style Dialoggreen.TButton");
      Max_Amount_Button: Ttk_Button;
      Max_Amount: constant Positive :=
        Inventory_Container.Element
          (Container => Player_Ship.Crew(Member_Index).Inventory,
           Index => Item_Index)
          .Amount;
      --## rule off DIRECTLY_ACCESSED_GLOBALS
      Amount_Box: constant Ttk_SpinBox :=
        Create
          (pathName => Item_Dialog & ".amount",
           options =>
             "-width 5 -from 1 -to" & Positive'Image(Max_Amount) &
             " -validate key -validatecommand {ValidateMoveAmount" &
             Positive'Image(Max_Amount) & " %P " & Button & " %W}");
   begin
      Max_Amount_Button :=
        Create
          (pathName => Item_Dialog & ".amountlbl",
           options =>
             "-text {Amount (max:" & Positive'Image(Max_Amount) &
             "):} -command {" & Amount_Box & " set" &
             Positive'Image(Max_Amount) & ";" & Amount_Box & " validate}");
      Add
        (Widget => Max_Amount_Button,
         Message => "Max amount of the item to move.");
      Tcl.Tk.Ada.Grid.Grid(Slave => Max_Amount_Button, Options => "-padx 5");
      Set(SpinBox => Amount_Box, Value => "1");
      Add(Widget => Amount_Box, Message => "Amount of the item to move.");
      Tcl.Tk.Ada.Grid.Grid(Slave => Amount_Box, Options => "-column 1 -row 1");
      Bind
        (Widgt => Amount_Box, Sequence => "<Escape>",
         Script => "{" & Item_Dialog & ".cancelbutton invoke;break}");
      Add(Widget => Button, Message => "Move the item to the cargo.");
      Tcl.Tk.Ada.Grid.Grid
        (Slave => Button, Options => "-padx {5 0} -pady {0 5}");
      Bind
        (Widgt => Button, Sequence => "<Escape>",
         Script => "{" & Item_Dialog & ".cancelbutton invoke;break}");
      Button :=
        Create
          (pathName => Item_Dialog & ".cancelbutton",
           options =>
             "-text Cancel -command {CloseDialog " & Item_Dialog &
             " .memberdialog;focus .memberdialog.button} -image cancelicon -style Dialogred.TButton");
      Add
        (Widget => Button,
         Message => "Cancel giving and close dialog. \[Escape key\]");
      Tcl.Tk.Ada.Grid.Grid
        (Slave => Button,
         Options => "-column 1 -row 2 -padx {0 5} -pady {0 5}");
      Focus(Widgt => Button);
      Bind
        (Widgt => Button, Sequence => "<Tab>",
         Script => "{focus " & Item_Dialog & ".movebutton;break}");
      Bind
        (Widgt => Button, Sequence => "<Escape>",
         Script => "{" & Button & " invoke;break}");
      Show_Dialog(Dialog => Item_Dialog);
      return TCL_OK;
   end Show_Move_Item_Command;

   -- ****if* SUCI/SUCI.Move_Item
   -- FUNCTION
   -- Move the selected item to the player's ship's cargo
   -- PARAMETERS
   -- Item_Index - The inventory index of the item to move
   -- Amount     - The amount of the item to move
   -- HISTORY
   -- 7.8 - Added
   -- SOURCE
   procedure Move_Item(Item_Index, Amount: Positive) is
      -- ****
      use Tcl.Tk.Ada.Event;
      use Tcl.Tk.Ada.Widgets.TtkEntry.TtkComboBox;
      use CoreUI;
      use Ships.Cargo;
      use Ships.Crew;

      Type_Box: constant Ttk_ComboBox :=
        Get_Widget
          (pathName =>
             Main_Paned &
             ".shipinfoframe.cargo.canvas.frame.selecttype.combo");
   begin
      --## rule off DIRECTLY_ACCESSED_GLOBALS
      --## rule off SIMPLIFIABLE_EXPRESSIONS
      if Free_Cargo
          (Amount =>
             0 -
             (Get_Proto_Item
                (Index =>
                   Inventory_Container.Element
                     (Container => Player_Ship.Crew(Member_Index).Inventory,
                      Index => Item_Index)
                     .Proto_Index)
                .Weight *
              Amount)) <
        0 then
         Show_Message
           (Text =>
              "No free space in ship cargo for that amount of " &
              Get_Item_Name
                (Item =>
                   Inventory_Container.Element
                     (Container => Player_Ship.Crew(Member_Index).Inventory,
                      Index => Item_Index)),
            Title => "No free space in cargo");
         return;
      end if;
      --## rule on SIMPLIFIABLE_EXPRESSIONS
      Update_Cargo
        (Ship => Player_Ship,
         Proto_Index =>
           Inventory_Container.Element
             (Container => Player_Ship.Crew(Member_Index).Inventory,
              Index => Item_Index)
             .Proto_Index,
         Amount => Amount,
         Durability =>
           Inventory_Container.Element
             (Container => Player_Ship.Crew(Member_Index).Inventory,
              Index => Item_Index)
             .Durability,
         Price =>
           Inventory_Container.Element
             (Container => Player_Ship.Crew(Member_Index).Inventory,
              Index => Item_Index)
             .Price);
      Update_Inventory
        (Member_Index => Member_Index, Amount => -Amount,
         Inventory_Index => Item_Index, Ship => Player_Ship);
      if
        (Player_Ship.Crew(Member_Index).Order = CLEAN and
         Find_Item
             (Inventory => Player_Ship.Crew(Member_Index).Inventory,
              Item_Type => Cleaning_Tools) =
           0) or
        ((Player_Ship.Crew(Member_Index).Order = UPGRADING or
          Player_Ship.Crew(Member_Index).Order = REPAIR) and
         Find_Item
             (Inventory => Player_Ship.Crew(Member_Index).Inventory,
              Item_Type => Repair_Tools) =
           0) then
         Give_Orders
           (Ship => Player_Ship, Member_Index => Member_Index,
            Given_Order => REST);
      end if;
      Generate(Window => Type_Box, EventName => "<<ComboboxSelected>>");
      --## rule on DIRECTLY_ACCESSED_GLOBALS
   end Move_Item;

   -- ****o* SUCI/SUCI.Move_Item_Command
   -- FUNCTION
   -- Move the selected item to the ship cargo
   -- PARAMETERS
   -- Client_Data - Custom data send to the command.
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- MoveItem itemindex
   -- itemindex is the index of the item which will be set
   -- SOURCE
   function Move_Item_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Move_Item_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Argc);
      use Tcl.Tk.Ada.Widgets.Toplevel;

      Amount: Positive;
      Item_Index: constant Positive :=
        Positive'Value(CArgv.Arg(Argv => Argv, N => 1));
      Item_Dialog: Tk_Toplevel :=
        Get_Widget(pathName => ".itemdialog", Interp => Interp);
      Amount_Box: constant Ttk_SpinBox :=
        Get_Widget(pathName => Item_Dialog & ".amount", Interp => Interp);
   begin
      Amount := Positive'Value(Get(Widgt => Amount_Box));
      Move_Item(Item_Index => Item_Index, Amount => Amount);
      Destroy(Widgt => Item_Dialog);
      Tcl_Eval
        (interp => Interp, strng => "CloseDialog .itemdialog .memberdialog");
      --## rule off DIRECTLY_ACCESSED_GLOBALS
      if Inventory_Container.Length
          (Container => Player_Ship.Crew(Member_Index).Inventory) =
        0 then
         Tcl_Eval(interp => Interp, strng => "CloseDialog .memberdialog");
         return TCL_OK;
      end if;
      --## rule off DIRECTLY_ACCESSED_GLOBALS
      return
        Sort_Crew_Inventory_Command
          (Client_Data => Client_Data, Interp => Interp, Argc => 2,
           Argv => CArgv.Empty & "SortCrewInventory" & "-1");
   end Move_Item_Command;

   -- ****o* SUCI/SUCI.Validate_Move_Amount_Command
   -- FUNCTION
   -- Validate amount of the item to move
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ValidateMoveAmount maxvalue amount button spinbox
   -- SOURCE
   function Validate_Move_Amount_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Validate_Move_Amount_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc);

      Amount: Natural := 0;
      Button: constant Ttk_Button :=
        Get_Widget(pathName => CArgv.Arg(Argv => Argv, N => 3));
      Max_Val: constant Positive :=
        Positive'Value(CArgv.Arg(Argv => Argv, N => 1));
      Spin_Box: constant Ttk_SpinBox :=
        Get_Widget
          (pathName => CArgv.Arg(Argv => Argv, N => 4), Interp => Interp);
   begin
      if CArgv.Arg(Argv => Argv, N => 2)'Length > 0 then
         Amount := Natural'Value(CArgv.Arg(Argv => Argv, N => 2));
      end if;
      if Amount < 1 then
         Widgets.configure(Widgt => Button, options => "-state disabled");
         Tcl_SetResult(interp => Interp, str => "1");
         return TCL_OK;
      elsif Amount > Max_Val then
         Set(SpinBox => Spin_Box, Value => Positive'Image(Max_Val));
      end if;
      Widgets.configure(Widgt => Button, options => "-state normal");
      Tcl_SetResult(interp => Interp, str => "1");
      return TCL_OK;
   exception
      when Constraint_Error =>
         Tcl_SetResult(interp => Interp, str => "0");
         return TCL_OK;
   end Validate_Move_Amount_Command;

   -- ****o* SUCI/SUCI.Show_Inventory_Item_Info_Command
   -- FUNCTION
   -- Show detailed information about the selected item in crew member
   -- inventory
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command.
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowInventoryItemInfo memberindex itemindex
   -- itemindex is the index of the item which will be show
   -- SOURCE
   function Show_Inventory_Item_Info_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Inventory_Item_Info_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc);
      use Tiny_String;

      Used: constant Boolean :=
        Item_Is_Used
          (Member_Index => Member_Index,
           Item_Index => Positive'Value(CArgv.Arg(Argv => Argv, N => 1)));
      Selection, Equipable: Boolean := False;
      Item_Type: constant Tiny_String.Bounded_String :=
        Get_Proto_Item
          (Index =>
             Inventory_Container.Element
               (Container => Player_Ship.Crew(Member_Index).Inventory,
                Index => Positive'Value(CArgv.Arg(Argv => Argv, N => 1)))
               .Proto_Index)
          .I_Type;
      Types_Array: constant array(1 .. 6) of Tiny_String.Bounded_String :=
        (1 => Weapon_Type, 2 => Shield_Type, 3 => Head_Armor, 4 => Chest_Armor,
         5 => Arms_Armor, 6 => Legs_Armor);
   begin
      Check_Selection_Loop :
      for I in
        Inventory_Container.First_Index
          (Container => Player_Ship.Crew(Member_Index).Inventory) ..
          Inventory_Container.Last_Index
            (Container => Player_Ship.Crew(Member_Index).Inventory) loop
         if Tcl_GetVar
             (interp => Interp,
              varName =>
                "invindex" &
                Trim
                  (Source => Inventory_Container.Extended_Index'Image(I),
                   Side => Left)) =
           "1" then
            Selection := True;
            exit Check_Selection_Loop;
         end if;
      end loop Check_Selection_Loop;
      if Selection then
         Show_Multi_Item_Actions_Menu_Block :
         declare
            Items_Menu: constant Ttk_Frame :=
              Create_Dialog
                (Name => ".itemsmenu", Title => "Selected items actions",
                 Parent_Name => ".memberdialog");
            procedure Add_Button(Name, Label, Command: String) is
               Button: constant Ttk_Button :=
                 Create
                   (pathName => Items_Menu & Name,
                    options =>
                      "-text {" & Label & "} -command {CloseDialog " &
                      Items_Menu & " .memberdialog;" & Command & "}");
            begin
               Tcl.Tk.Ada.Grid.Grid
                 (Slave => Button,
                  Options =>
                    "-sticky we -padx 5" &
                    (if Command'Length = 0 then " -pady {0 3}" else ""));
               Bind
                 (Widgt => Button, Sequence => "<Escape>",
                  Script =>
                    "{CloseDialog " & Items_Menu & " .memberdialog;break}");
               if Command'Length = 0 then
                  Bind
                    (Widgt => Button, Sequence => "<Tab>",
                     Script => "{focus " & Items_Menu & ".equip;break}");
                  Focus(Widgt => Button);
               end if;
            end Add_Button;
         begin
            Add_Button
              (Name => ".equip", Label => "Equip items",
               Command => "ToggleInventoryItems equip");
            Add_Button
              (Name => ".unequip", Label => "Unequip items",
               Command => "ToggleInventoryItems unequip");
            Add_Button
              (Name => ".move", Label => "Move items to the ship's cargo",
               Command => "MoveItems");
            Add_Button(Name => ".close", Label => "Close", Command => "");
            Show_Dialog(Dialog => Items_Menu, Parent_Frame => ".memberdialog");
         end Show_Multi_Item_Actions_Menu_Block;
         return TCL_OK;
      end if;
      Equipable := Is_Tool(Item_Type => Item_Type);
      Is_Equipable_Loop :
      for I_Type of Types_Array loop
         if I_Type = Item_Type then
            Equipable := True;
            exit Is_Equipable_Loop;
         end if;
      end loop Is_Equipable_Loop;
      Show_Inventory_Item_Info
        (Parent => ".memberdialog", Member_Index => Member_Index,
         Item_Index => Positive'Value(CArgv.Arg(Argv => Argv, N => 1)),
         Button_1 =>
           (Text => To_Unbounded_String(Source => "Move"),
            Command =>
              To_Unbounded_String
                (Source => "ShowMoveItem " & CArgv.Arg(Argv => Argv, N => 1)),
            Icon => To_Unbounded_String(Source => "cargoicon"),
            Tooltip =>
              To_Unbounded_String
                (Source => "Move the selected item to the ship's cargo"),
            Color => Null_Unbounded_String),
         Button_2 =>
           (if Equipable then
              (Text =>
                 (if Used then To_Unbounded_String(Source => "Unequip")
                  else To_Unbounded_String(Source => "Equip")),
               Command =>
                 To_Unbounded_String
                   (Source => "SetUseItem " & CArgv.Arg(Argv => Argv, N => 1)),
               Icon =>
                 (if Used then To_Unbounded_String(Source => "unequipicon")
                  else To_Unbounded_String(Source => "equipicon")),
               Tooltip =>
                 (if Used then To_Unbounded_String(Source => "Stop")
                  else To_Unbounded_String(Source => "Start")) &
                 " using the selected item",
               Color => To_Unbounded_String(Source => "green"))
            else Empty_Button_Settings));
      return TCL_OK;
   end Show_Inventory_Item_Info_Command;

   -- ****o* SUCI/SUCI.Toggle_Inventory_Item
   -- FUNCTION
   -- Select or deselect the selected item in the inventory
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command.
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ToggleInventoryItem rowindex, itemindex
   -- Rowindex is the index of the row in which is the selected item,
   -- itemindex is the index of the selected item in crew member inventory.
   -- SOURCE
   function Toggle_Inventory_Item_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Toggle_Inventory_Item_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc);
   begin
      Toggle_Checked_Button
        (Table => Inventory_Table,
         Row => Natural'Value(CArgv.Arg(Argv => Argv, N => 1)), Column => 1);
      if Is_Checked
          (Table => Inventory_Table,
           Row => Natural'Value(CArgv.Arg(Argv => Argv, N => 1)),
           Column => 1) then
         Tcl_SetVar
           (interp => Interp,
            varName => "invindex" & CArgv.Arg(Argv => Argv, N => 2),
            newValue => "1");
      else
         Tcl_UnsetVar
           (interp => Interp,
            varName => "invindex" & CArgv.Arg(Argv => Argv, N => 2));
      end if;
      return TCL_OK;
   end Toggle_Inventory_Item_Command;

   -- ****o* SUCI/SUCI.Toggle_Inventory_Items_Command
   -- FUNCTION
   -- Equip or unequip the selected items
   -- PARAMETERS
   -- Client_Data - Custom data send to the command.
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ToggleInventoryItems action
   -- Action is the action to do with the selected items. Possible values are
   -- equip and unequip
   -- SOURCE
   function Toggle_Inventory_Items_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Toggle_Inventory_Items_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Argc);
      Is_Used: Boolean := False;
      Equip: constant Boolean :=
        (if CArgv.Arg(Argv => Argv, N => 1) = "equip" then True else False);
   begin
      Toogle_Items_Loop :
      for I in
        Inventory_Container.First_Index
          (Container => Player_Ship.Crew(Member_Index).Inventory) ..
          Inventory_Container.Last_Index
            (Container => Player_Ship.Crew(Member_Index).Inventory) loop
         if Tcl_GetVar
             (interp => Interp,
              varName =>
                "invindex" &
                Trim
                  (Source => Inventory_Container.Extended_Index'Image(I),
                   Side => Left)) =
           "1" then
            Is_Used :=
              Item_Is_Used(Member_Index => Member_Index, Item_Index => I);
            if Equip and then not Is_Used then
               if Set_Use_Item_Command
                   (Client_Data => Client_Data, Interp => Interp, Argc => 2,
                    Argv =>
                      CArgv.Empty & "SetUseItem" &
                      Trim(Source => I'Img, Side => Left)) /=
                 TCL_OK then
                  return TCL_ERROR;
               end if;
            elsif not Equip and then Is_Used then
               Take_Off_Item(Member_Index => Member_Index, Item_Index => I);
            end if;
         end if;
      end loop Toogle_Items_Loop;
      Reset_Selection(Interp => Interp);
      return
        Sort_Crew_Inventory_Command
          (Client_Data => Client_Data, Interp => Interp, Argc => 2,
           Argv => CArgv.Empty & "SortCrewInventory" & "-1");
   end Toggle_Inventory_Items_Command;

   -- ****o* SUCI/SUCI.Move_Items_Command
   -- FUNCTION
   -- Move the selected items to the ships's cargo
   -- PARAMETERS
   -- Client_Data - Custom data send to the command.
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- MoveItems
   -- SOURCE
   function Move_Items_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Move_Items_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Argc, Argv);
   begin
      Move_Items_Loop :
      for I in reverse
        Inventory_Container.First_Index
          (Container => Player_Ship.Crew(Member_Index).Inventory) ..
          Inventory_Container.Last_Index
            (Container => Player_Ship.Crew(Member_Index).Inventory) loop
         if Tcl_GetVar
             (interp => Interp,
              varName =>
                "invindex" &
                Trim
                  (Source => Inventory_Container.Extended_Index'Image(I),
                   Side => Left)) =
           "1" then
            Move_Item
              (Item_Index => I,
               Amount =>
                 Inventory_Container.Element
                   (Container => Player_Ship.Crew(Member_Index).Inventory,
                    Index => I)
                   .Amount);
         end if;
      end loop Move_Items_Loop;
      if Inventory_Container.Length
          (Container => Player_Ship.Crew(Member_Index).Inventory) =
        0 then
         Tcl_Eval(interp => Interp, strng => "CloseDialog .memberdialog");
         return TCL_OK;
      end if;
      Reset_Selection(Interp => Interp);
      return
        Sort_Crew_Inventory_Command
          (Client_Data => Client_Data, Interp => Interp, Argc => 2,
           Argv => CArgv.Empty & "SortCrewInventory" & "-1");
   end Move_Items_Command;

   -- ****o* SUCI/SUCI.Toggle_All_Inventory_Command
   -- FUNCTION
   -- Select or deselect all items in the crew member inventory
   -- PARAMETERS
   -- Client_Data - Custom data send to the command.
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ToggleAllInventory action
   -- Action is the action which will be performed. Possible values are
   -- select or deselect
   -- SOURCE
   function Toggle_All_Inventory_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Toggle_All_Inventory_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Argc);
   begin
      if CArgv.Arg(Argv => Argv, N => 1) = "unselect" then
         Reset_Selection(Interp => Interp);
      else
         Set_Item_Selection_Loop :
         for I in
           1 ..
             Inventory_Container.Capacity
               (Container => Player_Ship.Crew(Member_Index).Inventory) loop
            Tcl_SetVar
              (interp => Interp,
               varName => "invindex" & Trim(Source => I'Img, Side => Left),
               newValue => "1");
         end loop Set_Item_Selection_Loop;
      end if;
      return
        Sort_Crew_Inventory_Command
          (Client_Data => Client_Data, Interp => Interp, Argc => 2,
           Argv => CArgv.Empty & "SortCrewInventory" & "-1");
   end Toggle_All_Inventory_Command;

   procedure Add_Inventory_Commands is
      procedure Add_Ada_Commands with
         Import => True,
         Convention => C,
         External_Name => "addAdaCrewInventoryCommands";
   begin
      Add_Ada_Commands;
      Add_Command
        (Name => "UpdateInventory",
         Ada_Command => Update_Inventory_Command'Access);
      Add_Command
        (Name => "ShowMemberInventory",
         Ada_Command => Show_Member_Inventory_Command'Access);
      Add_Command
        (Name => "SetUseItem", Ada_Command => Set_Use_Item_Command'Access);
      Add_Command
        (Name => "ShowMoveItem", Ada_Command => Show_Move_Item_Command'Access);
      Add_Command(Name => "MoveItem", Ada_Command => Move_Item_Command'Access);
      Add_Command
        (Name => "ValidateMoveAmount",
         Ada_Command => Validate_Move_Amount_Command'Access);
      Add_Command
        (Name => "ShowInventoryItemInfo",
         Ada_Command => Show_Inventory_Item_Info_Command'Access);
      Add_Command
        (Name => "SortCrewInventory",
         Ada_Command => Sort_Crew_Inventory_Command'Access);
      Add_Command
        (Name => "ToggleInventoryItem",
         Ada_Command => Toggle_Inventory_Item_Command'Access);
      Add_Command
        (Name => "ToggleInventoryItems",
         Ada_Command => Toggle_Inventory_Items_Command'Access);
      Add_Command
        (Name => "MoveItems", Ada_Command => Move_Items_Command'Access);
      Add_Command
        (Name => "ToggleAllInventory",
         Ada_Command => Toggle_All_Inventory_Command'Access);
   end Add_Inventory_Commands;

end Ships.UI.Crew.Inventory;
