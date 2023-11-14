-- Copyright (c) 2021-2023 Bartek thindil Jasicki
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
with Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with CArgv;
with Tcl; use Tcl;
with Tcl.Ada; use Tcl.Ada;
with Tcl.Tk.Ada;
with Tcl.Tk.Ada.TtkStyle;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Config;
with Utils.UI;

package body Table is

   --## rule off TYPE_INITIAL_VALUES
   type Nim_Width is array(0 .. 10) of Integer;
   --## rule on TYPE_INITIAL_VALUES

   function Create_Table
     (Parent: String; Headers: Headers_Array;
      Scrollbar: Ttk_Scrollbar := Get_Widget(pathName => ".");
      Command, Tooltip_Text: String := "") return Table_Widget is
      use Tcl.Tk.Ada;

      --## rule off IMPROPER_INITIALIZATION
      New_Table: Table_Widget (Amount => Headers'Length);
      --## rule on IMPROPER_INITIALIZATION
      --## rule off TYPE_INITIAL_VALUES
      type Nim_Headers is array(0 .. 10) of chars_ptr;
      --## rule on TYPE_INITIAL_VALUES
      N_Headers: Nim_Headers;
      Nim_Canvas, Nim_Scrollbar: chars_ptr;
      N_Width: Nim_Width := (others => 0);
      Index, Nim_Height: Natural := 0;
      procedure Create_Ada_Table
        (P: chars_ptr; H: Nim_Headers; S, Com, T_Text: chars_ptr;
         N_Canvas, N_Scrollbar: out chars_ptr; Height: out Integer;
         N_W: out Nim_Width) with
         Import => True,
         Convention => C,
         External_Name => "createAdaTable";
   begin
      Convert_Headers_To_Nim_Loop :
      for Header of Headers loop
         N_Headers(Index) := New_String(Str => To_String(Source => Header));
         Index := Index + 1;
      end loop Convert_Headers_To_Nim_Loop;
      Create_Ada_Table
        (P => New_String(Str => Parent), H => N_Headers,
         S => New_String(Str => Widget_Image(Win => Scrollbar)),
         Com => New_String(Str => Command),
         T_Text => New_String(Str => Tooltip_Text), N_Canvas => Nim_Canvas,
         N_Scrollbar => Nim_Scrollbar, Height => Nim_Height, N_W => N_Width);
      New_Table.Canvas := Get_Widget(pathName => Value(Item => Nim_Canvas));
      Index := 1;
      Convert_Headers_Width_Loop :
      for Width of N_Width loop
         exit Convert_Headers_Width_Loop when Width = 0;
         New_Table.Columns_Width(Index) := Width;
         Index := Index + 1;
      end loop Convert_Headers_Width_Loop;
      New_Table.Row := 1;
      New_Table.Row_Height := Nim_Height;
      New_Table.Scrollbar :=
        Get_Widget(pathName => Value(Item => Nim_Scrollbar));
      Tcl_Eval
        (interp => Get_Context,
         strng =>
           "SetScrollbarBindings " & New_Table.Canvas & " " &
           New_Table.Scrollbar);
      return New_Table;
   end Create_Table;

   --## rule off LOCAL_HIDING
   procedure Clear_Table(Table: in out Table_Widget) is
      --## rule on LOCAL_HIDING
      procedure Clear_Ada_Table(Columns, Rows: Positive; Canv: chars_ptr) with
         Import => True,
         Convention => C,
         External_Name => "clearAdaTable";
   begin
      Clear_Ada_Table
        (Columns => Table.Amount, Rows => Table.Row,
         Canv => New_String(Str => Widget_Image(Win => Table.Canvas)));
      Table.Row := 1;
   end Clear_Table;

   --## rule off LOCAL_HIDING
   procedure Add_Button
     (Table: in out Table_Widget; Text, Tooltip, Command: String;
      Column: Positive; New_Row: Boolean := False; Color: String := "") is
      --## rule on LOCAL_HIDING
      N_Width: Nim_Width := (others => 0);
      Index: Natural := 0;
      Row: Positive := Table.Row;
      procedure Add_Ada_Button
        (Can, T, Tt, Com, Colr: chars_ptr; Col, N_Row, R_Height: Integer;
         Width: Nim_Width; R: in out Integer) with
         Import => True,
         Convention => C,
         External_Name => "addAdaButton";
   begin
      Convert_Width_Loop :
      for Width of Table.Columns_Width loop
         N_Width(Index) := Width;
         Index := Index + 1;
      end loop Convert_Width_Loop;
      Add_Ada_Button
        (Can => New_String(Str => Widget_Image(Win => Table.Canvas)),
         T => New_String(Str => Text), Tt => New_String(Str => Tooltip),
         Com => New_String(Str => Command), Colr => New_String(Str => Color),
         Col => Column, N_Row => (if New_Row then 1 else 0),
         R_Height => Table.Row_Height, Width => N_Width, R => Row);
      Table.Row := Row;
      Index := 1;
      Convert_Nim_Width_Loop :
      for Width of N_Width loop
         exit Convert_Nim_Width_Loop when Width = 0;
         Table.Columns_Width(Index) := Width;
         Index := Index + 1;
      end loop Convert_Nim_Width_Loop;
   end Add_Button;

   --## rule off LOCAL_HIDING
   procedure Update_Table(Table: Table_Widget; Grab_Focus: Boolean := True) is
      --## rule on LOCAL_HIDING
      N_Width: Nim_Width := (others => 0);
      Index: Natural := 0;
      procedure Update_Ada_Table
        (Can: chars_ptr; Row, Row_Height, G_Focus: Integer;
         Width: Nim_Width) with
         Import => True,
         Convention => C,
         External_Name => "updateAdaTable";
   begin
      Convert_Width_Loop :
      for Width of Table.Columns_Width loop
         N_Width(Index) := Width;
         Index := Index + 1;
      end loop Convert_Width_Loop;
      Update_Ada_Table
        (Can => New_String(Str => Widget_Image(Win => Table.Canvas)),
         Row => Table.Row, Row_Height => Table.Row_Height,
         G_Focus => (if Grab_Focus then 1 else 0), Width => N_Width);
   end Update_Table;

   --## rule off LOCAL_HIDING
   procedure Add_Progress_Bar
     (Table: in out Table_Widget; Value: Natural; Max_Value: Positive;
      Tooltip, Command: String; Column: Positive;
      New_Row, Invert_Colors: Boolean := False) is
      --## rule on LOCAL_HIDING
      N_Width: Nim_Width := (others => 0);
      Index: Natural := 0;
      Row: Positive := Table.Row;
      procedure Add_Ada_Progressbar
        (Can, Tt, Com: chars_ptr;
         Val, Max_Val, Col, N_Row, R_Height, I_Colors: Integer;
         Width: Nim_Width; R: in out Integer) with
         Import => True,
         Convention => C,
         External_Name => "addAdaProgressbar";
   begin
      Convert_Width_Loop :
      for Width of Table.Columns_Width loop
         N_Width(Index) := Width;
         Index := Index + 1;
      end loop Convert_Width_Loop;
      Add_Ada_Progressbar
        (Can => New_String(Str => Widget_Image(Win => Table.Canvas)),
         Tt => New_String(Str => Tooltip), Com => New_String(Str => Command),
         Val => Value, Max_Val => Max_Value, Col => Column,
         N_Row => (if New_Row then 1 else 0), R_Height => Table.Row_Height,
         I_Colors => (if Invert_Colors then 1 else 0), Width => N_Width,
         R => Row);
      Table.Row := Row;
      Index := 1;
      Convert_Nim_Width_Loop :
      for Width of N_Width loop
         exit Convert_Nim_Width_Loop when Width = 0;
         Table.Columns_Width(Index) := Width;
         Index := Index + 1;
      end loop Convert_Nim_Width_Loop;
   end Add_Progress_Bar;

   --## rule off LOCAL_HIDING
   procedure Add_Pagination
     (Table: Table_Widget; Previous_Command, Next_Command: String := "") is
      --## rule on LOCAL_HIDING
      procedure Add_Ada_Pagination
        (Can, P_Command, N_Command: chars_ptr; R, R_Height: Integer) with
         Import => True,
         Convention => C,
         External_Name => "addAdaPagination";
   begin
      Add_Ada_Pagination
        (Can => New_String(Str => Widget_Image(Win => Table.Canvas)),
         P_Command => New_String(Str => Previous_Command),
         N_Command => New_String(Str => Next_Command), R => Table.Row,
         R_Height => Table.Row_Height);
   end Add_Pagination;

   --## rule off LOCAL_HIDING
   procedure Add_Check_Button
     (Table: in out Table_Widget; Tooltip, Command: String; Checked: Boolean;
      Column: Positive; New_Row, Empty_Unchecked: Boolean := False) is
      --## rule on LOCAL_HIDING
      N_Width: Nim_Width := (others => 0);
      Index: Natural := 0;
      Row: Positive := Table.Row;
      procedure Add_Ada_Check_Button
        (Can, Tt, Com: chars_ptr;
         Col, N_Row, R_Height, Ch, E_Unchecked: Integer; Width: Nim_Width;
         R: in out Integer) with
         Import => True,
         Convention => C,
         External_Name => "addAdaCheckButton";
   begin
      Convert_Width_Loop :
      for Width of Table.Columns_Width loop
         N_Width(Index) := Width;
         Index := Index + 1;
      end loop Convert_Width_Loop;
      Add_Ada_Check_Button
        (Can => New_String(Str => Widget_Image(Win => Table.Canvas)),
         Tt => New_String(Str => Tooltip), Com => New_String(Str => Command),
         Col => Column, N_Row => (if New_Row then 1 else 0),
         R_Height => Table.Row_Height, Ch => (if Checked then 1 else 0),
         E_Unchecked => (if Empty_Unchecked then 1 else 0), Width => N_Width,
         R => Row);
      Table.Row := Row;
      Index := 1;
      Convert_Nim_Width_Loop :
      for Width of N_Width loop
         exit Convert_Nim_Width_Loop when Width = 0;
         Table.Columns_Width(Index) := Width;
         Index := Index + 1;
      end loop Convert_Nim_Width_Loop;
   end Add_Check_Button;

   --## rule off LOCAL_HIDING
   function Get_Column_Number
     (Table: Table_Widget; X_Position: Natural) return Positive is
      --## rule on LOCAL_HIDING
      N_Width: Nim_Width := (others => 0);
      Index: Natural := 0;
      function Get_Ada_Column_Number
        (Width: Nim_Width; X_Pos: Integer) return Positive with
         Import => True,
         Convention => C,
         External_Name => "getAdaColumnNumber";
   begin
      Convert_Width_Loop :
      for Width of Table.Columns_Width loop
         N_Width(Index) := Width;
         Index := Index + 1;
      end loop Convert_Width_Loop;
      return Get_Ada_Column_Number(Width => N_Width, X_Pos => X_Position);
   end Get_Column_Number;

   --## rule off LOCAL_HIDING
   procedure Update_Headers_Command(Table: Table_Widget; Command: String) is
      --## rule on LOCAL_HIDING
      N_Width: Nim_Width := (others => 0);
      Index: Natural := 0;
      procedure Update_Ada_Headers_Command
        (Can, Com: chars_ptr; Width: Nim_Width) with
         Import => True,
         Convention => C,
         External_Name => "updateAdaHeadersCommand";
   begin
      Convert_Width_Loop :
      for Width of Table.Columns_Width loop
         N_Width(Index) := Width;
         Index := Index + 1;
      end loop Convert_Width_Loop;
      Update_Ada_Headers_Command
        (Can => New_String(Str => Widget_Image(Win => Table.Canvas)),
         Com => New_String(Str => Command), Width => N_Width);
   end Update_Headers_Command;

   -- ****o* Table/Table.Hide_Current_Row_Command
   -- FUNCTION
   -- Set the normal background color for the current row in the selected
   -- Table_Widget
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- HideCurrentRow canvas
   -- Canvas is the name of Table Tk_Canvas in which the selected row
   -- background will be recolored
   -- SOURCE
   function Hide_Current_Row_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Hide_Current_Row_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc);
      use Tcl.Tk.Ada.TtkStyle;
      use Config;

      Can: constant Tk_Canvas :=
        Get_Widget
          (pathName => CArgv.Arg(Argv => Argv, N => 1), Interp => Interp);
      Color: constant String :=
        (if
           Natural'Value
             (Tcl_GetVar(interp => Interp, varName => "currentrow")) rem
           2 >
           0
         then Style_Lookup(Name => "Table", Option => "-rowcolor")
         else Style_Lookup
             (Name => To_String(Source => Get_Interface_Theme),
              Option => "-background"));
   begin
      Item_Configure
        (CanvasWidget => Can, TagOrId => "row$currentrow",
         Options => "-fill " & Color);
      return TCL_OK;
   end Hide_Current_Row_Command;

   --## rule off LOCAL_HIDING
   function Is_Checked
     (Table: Table_Widget; Row, Column: Natural) return Boolean is
   --## rule on LOCAL_HIDING
   begin
      if Item_Cget
          (CanvasWidget => Table.Canvas,
           TagOrId =>
             "row" & Trim(Source => Positive'Image(Row), Side => Left) &
             "col" & Trim(Source => Positive'Image(Column), Side => Left),
           Option => "-image") =
        "checkbox-checked" then
         return True;
      end if;
      return False;
   end Is_Checked;

   --## rule off LOCAL_HIDING
   procedure Toggle_Checked_Button
     (Table: Table_Widget; Row, Column: Natural) is
   --## rule on LOCAL_HIDING
   begin
      if Is_Checked(Table => Table, Row => Row, Column => Column) then
         Item_Configure
           (CanvasWidget => Table.Canvas,
            TagOrId =>
              "row" & Trim(Source => Positive'Image(Row), Side => Left) &
              "col" & Trim(Source => Positive'Image(Column), Side => Left),
            Options => "-image checkbox-unchecked-empty");
      else
         Item_Configure
           (CanvasWidget => Table.Canvas,
            TagOrId =>
              "row" & Trim(Source => Positive'Image(Row), Side => Left) &
              "col" & Trim(Source => Positive'Image(Column), Side => Left),
            Options => "-image checkbox-checked");
      end if;
   end Toggle_Checked_Button;

   procedure Add_Commands is
      use Utils.UI;
      procedure Add_Ada_Commands with
         Import => True,
         Convention => C,
         External_Name => "addAdaTableCommands";
   begin
      Add_Ada_Commands;
      Add_Command
        (Name => "HideCurrentRow",
         Ada_Command => Hide_Current_Row_Command'Access);
   end Add_Commands;

end Table;
