-- Copyright (c) 2021 Bartek thindil Jasicki <thindil@laeran.pl>
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
with GNAT.String_Split; use GNAT.String_Split;
with Tcl; use Tcl;
with Tcl.Ada; use Tcl.Ada;
with Tcl.Tk.Ada; use Tcl.Tk.Ada;
with Tcl.Tk.Ada.Grid;
with Tcl.Tk.Ada.Pack;
with Tcl.Tk.Ada.TtkStyle; use Tcl.Tk.Ada.TtkStyle;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.TtkButton; use Tcl.Tk.Ada.Widgets.TtkButton;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Tcl.Tk.Ada.Winfo; use Tcl.Tk.Ada.Winfo;
with Tcl.Tklib.Ada.Autoscroll; use Tcl.Tklib.Ada.Autoscroll;
with Tcl.Tklib.Ada.Tooltip; use Tcl.Tklib.Ada.Tooltip;
with Config; use Config;

package body Table is

   function CreateTable
     (Parent: String; Headers: Headers_Array;
      Scrollbar: Ttk_Scrollbar := Get_Widget(".");
      Command, Tooltip: String := "") return Table_Widget is
      Canvas: Tk_Canvas;
      YScroll: Ttk_Scrollbar;
      XScroll: Ttk_Scrollbar;
      Table: Table_Widget (Headers'Length);
      X: Natural := 5;
      Tokens: Slice_Set;
      Master: constant Tk_Canvas := Get_Widget(Parent);
      Header_Id: Unbounded_String;
   begin
      if Widget_Image(Scrollbar) = "." then
         YScroll :=
           Create
             (Parent & ".scrolly",
              "-orient vertical -command [list " & Parent & ".table yview]");
         XScroll :=
           Create
             (Parent & ".scrollx",
              "-orient horizontal -command [list " & Parent & ".table xview]");
         Canvas :=
           Create
             (Parent & ".table",
              "-yscrollcommand [list " & Parent &
              ".scrolly set] -xscrollcommand [list " & Parent &
              ".scrollx set]");
         Tcl.Tk.Ada.Pack.Pack(YScroll, "-side right -fill y");
         Tcl.Tk.Ada.Pack.Pack(Canvas, "-side top -fill both -padx {5 0}");
         Tcl.Tk.Ada.Pack.Pack(XScroll, "-side bottom -fill x");
         Autoscroll(XScroll);
         Autoscroll(YScroll);
         Table.Scrollbar := YScroll;
      else
         Canvas := Create(Parent & ".table");
         Tcl.Tk.Ada.Grid.Grid(Canvas, "-sticky nwes -padx {5 0}");
         Tcl.Tk.Ada.Grid.Column_Configure(Master, Canvas, "-weight 1");
         Tcl.Tk.Ada.Grid.Row_Configure(Master, Canvas, "-weight 1");
         Table.Scrollbar := Scrollbar;
      end if;
      Create_Headers_Loop :
      for I in Headers'Range loop
         Header_Id :=
           To_Unbounded_String
             (Canvas_Create
                (Canvas, "text",
                 Trim(Natural'Image(X), Left) & " 2 -anchor nw -text {" &
                 To_String(Headers(I)) &
                 "} -font InterfaceFont -justify center -fill [ttk::style lookup " &
                 To_String(Game_Settings.Interface_Theme) &
                 " -foreground] -tags [list header" &
                 Trim(Positive'Image(I), Left) & "]"));
         if Command'Length > 0 then
            Bind
              (Canvas, To_String(Header_Id), "<Enter>",
               "{" & Canvas & " configure -cursor hand1}");
            Bind
              (Canvas, To_String(Header_Id), "<Leave>",
               "{" & Canvas & " configure -cursor left_ptr}");
            Bind
              (Canvas, To_String(Header_Id), "<Button-1>",
               "{" & Command & " %x}");
         end if;
         if Tooltip'Length > 0 then
            Add(Canvas, Tooltip, "-item " & To_String(Header_Id));
         end if;
         Create
           (Tokens, BBox(Canvas, "header" & Trim(Positive'Image(I), Left)),
            " ");
         X := Positive'Value(Slice(Tokens, 3)) + 10;
         Table.Columns_Width(I) := X - Positive'Value(Slice(Tokens, 1));
         if I = 1 then
            Table.Row_Height := Positive'Value(Slice(Tokens, 4)) + 5;
         end if;
      end loop Create_Headers_Loop;
      Header_Id :=
        To_Unbounded_String
          (Canvas_Create
             (Canvas, "rectangle",
              "0 0" & Positive'Image(X) &
              Positive'Image(Table.Row_Height - 3) & " -fill " &
              Style_Lookup("Table", "-headercolor") & " -outline " &
              Style_Lookup("Table", "-rowcolor") &
              " -width 2 -tags [list headerback]"));
      Lower(Canvas, "headerback");
      if Command'Length > 0 then
         Bind
           (Canvas, To_String(Header_Id), "<Enter>",
            "{" & Canvas & " configure -cursor hand1}");
         Bind
           (Canvas, To_String(Header_Id), "<Leave>",
            "{" & Canvas & " configure -cursor left_ptr}");
         Bind
           (Canvas, To_String(Header_Id), "<Button-1>",
            "{" & Command & " %x}");
      end if;
      if Tooltip'Length > 0 then
         Add(Canvas, Tooltip, "-item " & To_String(Header_Id));
      end if;
      Table.Canvas := Canvas;
      Tcl_Eval
        (Get_Context,
         "SetScrollbarBindings " & Table.Canvas & " " & Table.Scrollbar);
      return Table;
   end CreateTable;

   procedure ClearTable(Table: in out Table_Widget) is
      ButtonsFrame: Ttk_Frame := Get_Widget(Table.Canvas & ".buttonframe");
      Button: Ttk_Button;
   begin
      if Winfo_Get(ButtonsFrame, "exists") = "1" then
         Button := Get_Widget(ButtonsFrame & ".previous");
         Destroy(Button);
         Button := Get_Widget(ButtonsFrame & ".next");
         Destroy(Button);
         Destroy(ButtonsFrame);
      end if;
      Clear_Rows_Loop :
      for Row in 1 .. Table.Row loop
         Clear_Columns_Loop :
         for Column in 1 .. Table.Amount loop
            Delete
              (Table.Canvas,
               "row" & Trim(Positive'Image(Row), Left) & "col" &
               Trim(Positive'Image(Column), Left));
            Delete(Table.Canvas, "row" & Trim(Positive'Image(Row), Left));
            Delete
              (Table.Canvas,
               "progressbar" & Trim(Positive'Image(Row), Left) & "back" &
               Trim(Positive'Image(Column), Left));
            Delete
              (Table.Canvas,
               "progressbar" & Trim(Positive'Image(Row), Left) & "bar" &
               Trim(Positive'Image(Column), Left));
         end loop Clear_Columns_Loop;
      end loop Clear_Rows_Loop;
      Table.Row := 1;
   end ClearTable;

   -- ****if* Table/Add_Bindings
   -- FUNCTION
   -- Add events to the selected element of the Table_Widget
   -- PARAMETERS
   -- Canvas
   -- ItemId
   -- Row
   -- Command
   -- HISTORY
   -- 6.6 - Added
   -- SOURCE
   procedure Add_Bindings
     (Canvas: Tk_Canvas; ItemId, Row, Command, Color: String) is
   begin
      Bind
        (Canvas, ItemId, "<Enter>",
         "{" & Canvas & " itemconfigure row" & Row & " -fill " &
         Style_Lookup
           (To_String(Game_Settings.Interface_Theme), "-selectbackground") &
         (if Command'Length > 0 then ";" & Canvas & " configure -cursor hand1"
          else "") &
         ";set currentrow " & Row & "}");
      Bind
        (Canvas, ItemId, "<Leave>",
         "{" & Canvas & " itemconfigure row" & Row & " -fill " & Color & "}");
      if Command'Length > 0 then
         Bind
           (Canvas, ItemId,
            "<Button-" & (if Game_Settings.Right_Button then "3" else "1") &
            ">",
            "{" & Command & "}");
      end if;
   end Add_Bindings;

   -- ****if* Table/Table.AddBackground
   -- FUNCTION
   -- Add a proper background color to the item in the table and return the
   -- name of used color
   -- PARAMETERS
   -- Table   - The Table_Widget in which background will be added
   -- NewRow  - If True, add the background, otherwise just return the color
   --           which will be used
   -- Command - Tcl command which will be executed when the background was
   --           clicked
   -- RESULT
   -- The String with the name of the color used for set background for the
   -- item
   -- SOURCE
   function AddBackground
     (Table: Table_Widget; NewRow: Boolean; Command: String) return String is
     -- ****
      ItemId: Unbounded_String;
      Color: constant String :=
        (if Table.Row rem 2 > 0 then Style_Lookup("Table", "-rowcolor")
         else Style_Lookup
             (To_String(Game_Settings.Interface_Theme), "-background"));
   begin
      if not NewRow then
         return Color;
      end if;
      ItemId :=
        To_Unbounded_String
          (Canvas_Create
             (Table.Canvas, "rectangle",
              " 0" & Positive'Image((Table.Row * Table.Row_Height)) & " 10" &
              Positive'Image
                ((Table.Row * Table.Row_Height) + (Table.Row_Height)) &
              " -fill " & Color & " -width 0 -tags [list row" &
              Trim(Positive'Image(Table.Row), Left) & "]"));
      Lower(Table.Canvas, To_String(ItemId));
      Add_Bindings
        (Table.Canvas, To_String(ItemId),
         Trim(Positive'Image(Table.Row), Left), Command, Color);
      return Color;
   end AddBackground;

   procedure AddButton
     (Table: in out Table_Widget; Text, Tooltip, Command: String;
      Column: Positive; NewRow: Boolean := False; Color: String := "") is
      X: Natural := 5;
      ItemId: Unbounded_String;
      Tokens: Slice_Set;
      Text_Color: constant String :=
        (if Color'Length > 0 then Color
         else Style_Lookup
             (To_String(Game_Settings.Interface_Theme), "-foreground"));
      Background_Color: constant String :=
        AddBackground(Table, NewRow, Command);
   begin
      Count_X_Loop :
      for I in 1 .. Column - 1 loop
         X := X + Table.Columns_Width(I);
      end loop Count_X_Loop;
      ItemId :=
        To_Unbounded_String
          (Canvas_Create
             (Table.Canvas, "text",
              Trim(Natural'Image(X), Left) &
              Positive'Image((Table.Row * Table.Row_Height) + 2) &
              " -anchor nw -text {" & Text & "} -font InterfaceFont -fill " &
              Text_Color & " -tags [list row" &
              Trim(Positive'Image(Table.Row), Left) & "col" &
              Trim(Positive'Image(Column), Left) & "]"));
      if Tooltip'Length > 0 then
         Add(Table.Canvas, Tooltip, "-item " & To_String(ItemId));
      end if;
      Add_Bindings
        (Table.Canvas, To_String(ItemId),
         Trim(Positive'Image(Table.Row), Left), Command, Background_Color);
      Create(Tokens, BBox(Table.Canvas, To_String(ItemId)), " ");
      X :=
        (Positive'Value(Slice(Tokens, 3)) + 10) -
        Positive'Value(Slice(Tokens, 1));
      if X > Table.Columns_Width(Column) then
         Table.Columns_Width(Column) := X;
      end if;
      if NewRow then
         Table.Row := Table.Row + 1;
      end if;
   end AddButton;

   procedure UpdateTable(Table: in out Table_Widget) is
      Tag: Unbounded_String;
      NewX: Natural := Table.Columns_Width(1) + 20;
      NewY: Natural := 2;
   begin
      Update_Columns_Loop :
      for Column in 2 .. Table.Amount loop
         Tag :=
           To_Unbounded_String("header" & Trim(Natural'Image(Column), Left));
         Coords
           (Table.Canvas, To_String(Tag),
            Trim(Positive'Image(NewX), Left) & Positive'Image(NewY));
         Update_Rows_Loop :
         for Row in 1 .. Table.Row loop
            NewY := NewY + Table.Row_Height;
            Tag :=
              To_Unbounded_String
                ("row" & Trim(Positive'Image(Row), Left) & "col" &
                 Trim(Natural'Image(Column), Left));
            MoveTo
              (Table.Canvas, To_String(Tag), Trim(Positive'Image(NewX), Left),
               Trim(Positive'Image(NewY), Left));
            Tag :=
              To_Unbounded_String
                ("progressbar" & Trim(Positive'Image(Row), Left) & "back" &
                 Trim(Natural'Image(Column), Left));
            MoveTo
              (Table.Canvas, To_String(Tag), Trim(Positive'Image(NewX), Left),
               Trim(Positive'Image(NewY + 5), Left));
            Tag :=
              To_Unbounded_String
                ("progressbar" & Trim(Positive'Image(Row), Left) & "bar" &
                 Trim(Natural'Image(Column), Left));
            MoveTo
              (Table.Canvas, To_String(Tag),
               Trim(Positive'Image(NewX + 2), Left),
               Trim(Positive'Image(NewY + 7), Left));
         end loop Update_Rows_Loop;
         NewX := NewX + Table.Columns_Width(Column) + 20;
         NewY := 2;
      end loop Update_Columns_Loop;
      declare
         Tokens: Slice_Set;
      begin
         Create(Tokens, BBox(Table.Canvas, "all"), " ");
            -- if no scrollbars, resize the table
         if Winfo_Get(Table.Canvas, "parent") /=
           Winfo_Get(Table.Scrollbar, "parent") then
            configure
              (Table.Canvas,
               "-height [expr " & Slice(Tokens, 4) & " - " & Slice(Tokens, 2) &
               "] -width [expr " & Slice(Tokens, 3) & " - " &
               Slice(Tokens, 1) & " + 5]");
         end if;
         Coords
           (Table.Canvas, "headerback",
            "0 0" & Positive'Image(Positive'Value(Slice(Tokens, 3)) - 1) &
            Positive'Image(Table.Row_Height - 3));
         NewY := Table.Row_Height;
         Resize_Background_Loop :
         for Row in 1 .. Table.Row loop
            NewY := NewY + Table.Row_Height;
            Tag :=
              To_Unbounded_String("row" & Trim(Positive'Image(Row), Left));
            Coords
              (Table.Canvas, To_String(Tag),
               "0" & Positive'Image(NewY - Table.Row_Height) &
               Positive'Image(Positive'Value(Slice(Tokens, 3)) - 1) &
               Positive'Image(NewY));
         end loop Resize_Background_Loop;
      end;
      Tcl_SetVar(Get_Context, "currentrow", "1");
      Widgets.Focus(Table.Canvas);
   end UpdateTable;

   procedure AddProgressBar
     (Table: in out Table_Widget; Value: Natural; MaxValue: Positive;
      Tooltip, Command: String; Column: Positive;
      NewRow, InvertColors: Boolean := False) is
      X: Natural := 0;
      ItemId: Unbounded_String;
      Tokens: Slice_Set;
      Length: constant Natural :=
        Natural
          (100.0 +
           ((Float(Value) - Float(MaxValue)) / Float(MaxValue) * 100.0));
      Color: Unbounded_String;
      Background_Color: constant String :=
        AddBackground(Table, NewRow, Command);
   begin
      Count_X_Loop :
      for I in 1 .. Column - 1 loop
         X := X + Table.Columns_Width(I);
      end loop Count_X_Loop;
      ItemId :=
        To_Unbounded_String
          (Canvas_Create
             (Table.Canvas, "rectangle",
              Trim(Natural'Image(X), Left) &
              Positive'Image((Table.Row * Table.Row_Height) + 5) &
              Positive'Image(X + 102) &
              Positive'Image
                ((Table.Row * Table.Row_Height) + (Table.Row_Height - 10)) &
              " -fill " & Style_Lookup("TProgressbar", "-troughcolor") &
              " -outline " & Style_Lookup("TProgressbar", "-bordercolor") &
              " -tags [list progressbar" &
              Trim(Positive'Image(Table.Row), Left) & "back" &
              Trim(Positive'Image(Column), Left) & "]"));
      Add_Bindings
        (Table.Canvas, To_String(ItemId),
         Trim(Positive'Image(Table.Row), Left), Command, Background_Color);
      if Tooltip'Length > 0 then
         Add(Table.Canvas, Tooltip, "-item " & To_String(ItemId));
      end if;
      Create(Tokens, BBox(Table.Canvas, To_String(ItemId)), " ");
      X :=
        (Positive'Value(Slice(Tokens, 3)) + 10) -
        Positive'Value(Slice(Tokens, 1));
      if X > Table.Columns_Width(Column) then
         Table.Columns_Width(Column) := X;
      end if;
      if not InvertColors then
         Color :=
           To_Unbounded_String
             (if Length > 74 then
                Style_Lookup("green.Horizontal.TProgressbar", "-background")
              elsif Length > 24 then
                Style_Lookup("yellow.Horizontal.TProgressbar", "-background")
              else Style_Lookup("TProgressbar", "-background"));
      else
         Color :=
           To_Unbounded_String
             (if Length < 25 then
                Style_Lookup("green.Horizontal.TProgressbar", "-background")
              elsif Length > 24 and Length < 75 then
                Style_Lookup("yellow.Horizontal.TProgressbar", "-background")
              else Style_Lookup("TProgressbar", "-background"));
      end if;
      ItemId :=
        To_Unbounded_String
          (Canvas_Create
             (Table.Canvas, "rectangle",
              Trim(Natural'Image(X + 2), Left) &
              Positive'Image((Table.Row * Table.Row_Height) + 7) &
              Positive'Image(X + Length) &
              Positive'Image
                ((Table.Row * Table.Row_Height) + (Table.Row_Height - 12)) &
              " -fill " & To_String(Color) & " -tags [list progressbar" &
              Trim(Positive'Image(Table.Row), Left) & "bar" &
              Trim(Positive'Image(Column), Left) & "]"));
      Add_Bindings
        (Table.Canvas, To_String(ItemId),
         Trim(Positive'Image(Table.Row), Left), Command, Background_Color);
      if Tooltip'Length > 0 then
         Add(Table.Canvas, Tooltip, "-item " & To_String(ItemId));
      end if;
      if NewRow then
         Table.Row := Table.Row + 1;
      end if;
   end AddProgressBar;

   procedure AddPagination
     (Table: in out Table_Widget; PreviousCommand, NextCommand: String) is
      ButtonsFrame: constant Ttk_Frame :=
        Create(Table.Canvas & ".buttonframe");
      Button: Ttk_Button;
   begin
      if PreviousCommand'Length > 0 then
         Button :=
           Create
             (ButtonsFrame & ".previous",
              "-text Previous -command {" & PreviousCommand & "}");
         Tcl.Tk.Ada.Grid.Grid(Button, "-sticky w");
         Add(Button, "Previous page");
      end if;
      if NextCommand'Length > 0 then
         Button :=
           Create
             (ButtonsFrame & ".next",
              "-text Next -command {" & NextCommand & "}");
         Tcl.Tk.Ada.Grid.Grid(Button, "-sticky e -row 0 -column 1");
         Add(Button, "Next page");
      end if;
      Tcl_Eval(Get_Interp(Table.Canvas), "update");
      Canvas_Create
        (Table.Canvas, "window",
         "0" & Positive'Image(Table.Row * Table.Row_Height) &
         " -anchor nw -window " & ButtonsFrame);
   end AddPagination;

   procedure AddCheckButton
     (Table: in out Table_Widget; Tooltip, Command: String; Checked: Boolean;
      Column: Positive; NewRow: Boolean := False) is
      X: Natural := 5;
      ItemId: Unbounded_String;
      Tokens: Slice_Set;
      Background_Color: constant String :=
        AddBackground(Table, NewRow, Command);
      ImageName: constant String :=
        "${ttk::theme::" & Theme_Use & "::I(checkbox-" &
        (if Checked then "checked" else "unchecked") & ")}";
   begin
      Count_X_Loop :
      for I in 1 .. Column - 1 loop
         X := X + Table.Columns_Width(I);
      end loop Count_X_Loop;
      ItemId :=
        To_Unbounded_String
          (Canvas_Create
             (Table.Canvas, "image",
              Trim(Natural'Image(X), Left) &
              Positive'Image((Table.Row * Table.Row_Height) + 2) &
              " -anchor nw -image " & ImageName & " -tags [list row" &
              Trim(Positive'Image(Table.Row), Left) & "col" &
              Trim(Positive'Image(Column), Left) & "]"));
      if Tooltip'Length > 0 then
         Add(Table.Canvas, Tooltip, "-item " & To_String(ItemId));
      end if;
      Create(Tokens, BBox(Table.Canvas, To_String(ItemId)), " ");
      X :=
        (Positive'Value(Slice(Tokens, 3)) + 10) -
        Positive'Value(Slice(Tokens, 1));
      if X > Table.Columns_Width(Column) then
         Table.Columns_Width(Column) := X;
      end if;
      if Command'Length > 0 then
         Add_Bindings
           (Table.Canvas, To_String(ItemId),
            Trim(Positive'Image(Table.Row), Left), Command, Background_Color);
      end if;
      if NewRow then
         Table.Row := Table.Row + 1;
      end if;
   end AddCheckButton;

   function Get_Column_Number
     (Table: Table_Widget; X_Position: Natural) return Positive is
      Position: Positive := X_Position;
   begin
      for I in Table.Columns_Width'Range loop
         if Position < Table.Columns_Width(I) + 20 then
            return I;
         end if;
         Position := Position - Table.Columns_Width(I) - 20;
      end loop;
      return 1;
   end Get_Column_Number;

   procedure Update_Headers_Command(Table: Table_Widget; Command: String) is
   begin
      if Command'Length > 0 then
         for I in Table.Columns_Width'Range loop
            Bind
              (Table.Canvas, "header" & Trim(Positive'Image(I), Left),
               "<Enter>", "{" & Table.Canvas & " configure -cursor hand1}");
            Bind
              (Table.Canvas, "header" & Trim(Positive'Image(I), Left),
               "<Leave>", "{" & Table.Canvas & " configure -cursor left_ptr}");
            Bind
              (Table.Canvas, "header" & Trim(Positive'Image(I), Left),
               "<Button-1>", "{" & Command & " %x}");
         end loop;
         Bind
           (Table.Canvas, "headerback", "<Enter>",
            "{" & Table.Canvas & " configure -cursor hand1}");
         Bind
           (Table.Canvas, "headerback", "<Leave>",
            "{" & Table.Canvas & " configure -cursor left_ptr}");
         Bind
           (Table.Canvas, "headerback", "<Button-1>", "{" & Command & " %x}");
      else
         for I in Table.Columns_Width'Range loop
            Bind
              (Table.Canvas, "header" & Trim(Positive'Image(I), Left),
               "<Enter>", "{}");
            Bind
              (Table.Canvas, "header" & Trim(Positive'Image(I), Left),
               "<Leave>", "{}");
            Bind
              (Table.Canvas, "header" & Trim(Positive'Image(I), Left),
               "<Button-1>", "{}");
         end loop;
         Bind(Table.Canvas, "headerback", "<Enter>", "{}");
         Bind(Table.Canvas, "headerback", "<Leave>", "{}");
         Bind(Table.Canvas, "headerback", "<Button-1>", "{}");
      end if;
   end Update_Headers_Command;

end Table;
