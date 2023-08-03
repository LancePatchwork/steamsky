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

with Ada.Containers.Vectors; use Ada.Containers;
with Ada.Strings; use Ada.Strings;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Ada.Strings.UTF_Encoding.Wide_Strings;
use Ada.Strings.UTF_Encoding.Wide_Strings;
with Interfaces.C; use Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with CArgv; use CArgv;
with Tcl; use Tcl;
with Tcl.Ada; use Tcl.Ada;
with Tcl.Tk.Ada.Busy;
with Tcl.Tk.Ada.Event; use Tcl.Tk.Ada.Event;
with Tcl.Tk.Ada.Grid;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.Text; use Tcl.Tk.Ada.Widgets.Text;
with Tcl.Tk.Ada.Widgets.Toplevel.MainWindow;
use Tcl.Tk.Ada.Widgets.Toplevel.MainWindow;
with Tcl.Tk.Ada.Widgets.TtkButton; use Tcl.Tk.Ada.Widgets.TtkButton;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Tcl.Tk.Ada.Widgets.TtkEntry.TtkSpinBox;
use Tcl.Tk.Ada.Widgets.TtkEntry.TtkSpinBox;
with Tcl.Tk.Ada.Widgets.TtkPanedWindow; use Tcl.Tk.Ada.Widgets.TtkPanedWindow;
with Tcl.Tk.Ada.Winfo; use Tcl.Tk.Ada.Winfo;
with Tcl.Tk.Ada.Wm; use Tcl.Tk.Ada.Wm;
with Bases; use Bases;
with Combat.UI; use Combat.UI;
with Config; use Config;
with CoreUI; use CoreUI;
with Crew; use Crew;
with Dialogs; use Dialogs;
with Events; use Events;
with Factions; use Factions;
with Messages; use Messages;
with OrdersMenu; use OrdersMenu;
with Ships.Cargo; use Ships.Cargo;
with Ships.Crew; use Ships.Crew;
with Ships.Movement; use Ships.Movement;
with Statistics.UI; use Statistics.UI;
with Themes; use Themes;
with Utils.UI; use Utils.UI;

package body Maps.UI.Commands is

   Button_Names: constant array(1 .. 13) of Unbounded_String :=
     (1 => To_Unbounded_String(Source => "show"),
      2 => To_Unbounded_String(Source => "nw"),
      3 => To_Unbounded_String(Source => "n"),
      4 => To_Unbounded_String(Source => "ne"),
      5 => To_Unbounded_String(Source => "w"),
      6 => To_Unbounded_String(Source => "wait"),
      7 => To_Unbounded_String(Source => "e"),
      8 => To_Unbounded_String(Source => "sw"),
      9 => To_Unbounded_String(Source => "s"),
      10 => To_Unbounded_String(Source => "se"),
      11 => To_Unbounded_String(Source => "hide"),
      12 => To_Unbounded_String(Source => "left"),
      13 => To_Unbounded_String(Source => "right"));

   -- ****o* MapCommands/MapCommands.Hide_Map_Buttons_Command
   -- FUNCTION
   -- Hide map movement buttons
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- HideMapButtons
   -- SOURCE
   function Hide_Map_Buttons_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Hide_Map_Buttons_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc, Argv);
      Button: Ttk_Button;
   begin
      Button.Interp := Interp;
      Hide_Buttons_Loop :
      for I in 2 .. 13 loop
         Button.Name :=
           New_String
             (Str =>
                Main_Paned & ".mapframe.buttons." &
                To_String(Source => Button_Names(I)));
         Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Button);
      end loop Hide_Buttons_Loop;
      Button.Name := New_String(Str => Main_Paned & ".mapframe.buttons.show");
      Tcl.Tk.Ada.Grid.Grid(Slave => Button);
      return TCL_OK;
   end Hide_Map_Buttons_Command;

   -- ****o* MapCommands/MapCommands.Show_Map_Buttons_Command
   -- FUNCTION
   -- Show map movement buttons
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowMapButtons
   -- SOURCE
   function Show_Map_Buttons_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Map_Buttons_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc, Argv);
      Button: Ttk_Button;
      Buttons_Box: constant Ttk_Frame :=
        Get_Widget
          (pathName => Main_Paned & ".mapframe.buttons", Interp => Interp);
   begin
      Button.Interp := Interp;
      Show_Buttons_Loop :
      for I in 2 .. 11 loop
         Button.Name :=
           New_String
             (Str =>
                Widget_Image(Win => Buttons_Box) & "." &
                To_String(Source => Button_Names(I)));
         Tcl.Tk.Ada.Grid.Grid(Slave => Button);
      end loop Show_Buttons_Loop;
      Button.Name :=
        New_String(Str => Widget_Image(Win => Buttons_Box) & ".show");
      Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Button);
      Button.Name :=
        (if
           Index
             (Source => Tcl.Tk.Ada.Grid.Grid_Info(Slave => Buttons_Box),
              Pattern => "-sticky es") =
           0
         then New_String(Str => Widget_Image(Win => Buttons_Box) & ".right")
         else New_String(Str => Widget_Image(Win => Buttons_Box) & ".left"));
      Tcl.Tk.Ada.Grid.Grid(Slave => Button);
      return TCL_OK;
   end Show_Map_Buttons_Command;

   -- ****o* MapCommands/MapCommands.Move_Map_Buttons_Command
   -- FUNCTION
   -- Move map movement buttons left of right
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- MoveMapButtons buttonname
   -- Buttonname is the name of the button which was clicked
   -- SOURCE
   function Move_Map_Buttons_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Move_Map_Buttons_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc);
      Buttons_Box: constant Ttk_Frame :=
        Get_Widget
          (pathName => Main_Paned & ".mapframe.buttons", Interp => Interp);
      Button: Ttk_Button :=
        Get_Widget
          (pathName => Buttons_Box & "." & CArgv.Arg(Argv => Argv, N => 1),
           Interp => Interp);
   begin
      Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Button);
      if CArgv.Arg(Argv => Argv, N => 1) = "left" then
         Button.Name :=
           New_String(Str => Widget_Image(Win => Buttons_Box) & ".right");
         Tcl.Tk.Ada.Grid.Grid_Configure
           (Slave => Buttons_Box, Options => "-sticky sw");
      else
         Button.Name :=
           New_String(Str => Widget_Image(Win => Buttons_Box) & ".left");
         Tcl.Tk.Ada.Grid.Grid_Configure
           (Slave => Buttons_Box, Options => "-sticky se");
      end if;
      Tcl.Tk.Ada.Grid.Grid(Slave => Button);
      return TCL_OK;
   end Move_Map_Buttons_Command;

   -- ****o* MapCommands/MapCommands.Draw_Map_Command
   -- FUNCTION
   -- Draw the sky map
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- DrawMap
   -- SOURCE
   function Draw_Map_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Draw_Map_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc, Argv);
      Map_View: constant Tk_Text :=
        Get_Widget(pathName => Main_Paned & ".mapframe.map", Interp => Interp);
   begin
      configure
        (Widgt => Map_View,
         options =>
           "-width [expr [winfo width $mapview] / [font measure MapFont {" &
           Encode
             (Item =>
                "" &
                Themes_List(To_String(Source => Game_Settings.Interface_Theme))
                  .Empty_Map_Icon) &
           "}]]");
      configure
        (Widgt => Map_View,
         options =>
           "-height [expr [winfo height $mapview] / [font metrics MapFont -linespace]]");
      if Tcl_GetVar(interp => Interp, varName => "refreshmap") = "1" then
         Draw_Map;
         Tcl_UnsetVar(interp => Interp, varName => "refreshmap");
      end if;
      return TCL_OK;
   end Draw_Map_Command;

   -- ****iv* MapCommands/MapCommands.Map_X
   -- FUNCTION
   -- Current map cell X coordinate (where mouse is hovering)
   -- SOURCE
   Map_X: Natural := 0;
   -- ****

   -- ****iv* MapCommands/MapCommands.Map_Y
   -- FUNCTION
   -- Current map cell Y coordinate (where mouse is hovering)
   -- SOURCE
   Map_Y: Natural := 0;
   -- ****

   -- ****o* MapCommands/MapCommands.Update_Map_Info_Command
   -- FUNCTION
   -- Update map cell info
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- UpdateMapInfo x y
   -- X and Y are coordinates of the map cell which info will be show
   -- SOURCE
   function Update_Map_Info_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Update_Map_Info_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc);
      Map_View: constant Tk_Text :=
        Get_Widget(pathName => Main_Paned & ".mapframe.map", Interp => Interp);
      Map_Index: Unbounded_String;
   begin
      Map_Index :=
        To_Unbounded_String
          (Source =>
             Index
               (TextWidget => Map_View,
                TextIndex =>
                  "@" & CArgv.Arg(Argv => Argv, N => 1) & "," &
                  CArgv.Arg(Argv => Argv, N => 2)));
      if Start_Y +
        Integer'Value
          (Slice
             (Source => Map_Index, Low => 1,
              High => Index(Source => Map_Index, Pattern => ".") - 1)) -
        1 <
        1 then
         return TCL_OK;
      end if;
      Map_Y :=
        Start_Y +
        Integer'Value
          (Slice
             (Source => Map_Index, Low => 1,
              High => Index(Source => Map_Index, Pattern => ".") - 1)) -
        1;
      if Map_Y > 1_024 then
         return TCL_OK;
      end if;
      if Start_X +
        Integer'Value
          (Slice
             (Source => Map_Index,
              Low => Index(Source => Map_Index, Pattern => ".") + 1,
              High => Length(Source => Map_Index))) <
        1 then
         return TCL_OK;
      end if;
      Map_X :=
        Start_X +
        Integer'Value
          (Slice
             (Source => Map_Index,
              Low => Index(Source => Map_Index, Pattern => ".") + 1,
              High => Length(Source => Map_Index)));
      if Map_X > 1_024 then
         return TCL_OK;
      end if;
      Update_Map_Info(X => Map_X, Y => Map_Y);
      return TCL_OK;
   end Update_Map_Info_Command;

   -- ****o* MapCommands/MapCommands.Move_Map_Info_Command
   -- FUNCTION
   -- Move map info frame when mouse enter it
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- MoveMapInfo
   -- SOURCE
   function Move_Map_Info_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Move_Map_Info_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc, Argv);
      Map_Info_Frame: constant Ttk_Frame :=
        Get_Widget
          (pathName => Main_Paned & ".mapframe.info", Interp => Interp);
   begin
      Tcl.Tk.Ada.Grid.Grid_Configure
        (Slave => Map_Info_Frame,
         Options =>
           "-sticky " &
           (if
              Index
                (Source => Tcl.Tk.Ada.Grid.Grid_Info(Slave => Map_Info_Frame),
                 Pattern => "-sticky ne") =
              0
            then "ne"
            else "wn"));
      return TCL_OK;
   end Move_Map_Info_Command;

   -- ****o* MapCommands/MapCommands.Show_Destination_Menu_Command
   -- FUNCTION
   -- Create and show destination menu
   -- PARAMETERS
   -- Client_Data - Custom data send to the command.
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command.
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowDestinationMenu x y
   -- X and Y are mouse coordinates on which the destination menu will be show
   -- SOURCE
   function Show_Destination_Menu_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Destination_Menu_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      Destination_Dialog: constant Ttk_Frame :=
        Create_Dialog
          (Name => ".gameframe.destinationmenu", Title => "Set destination",
           Parent_Name => ".gameframe");
      Button: Ttk_Button :=
        Create
          (pathName => Destination_Dialog & ".set",
           options =>
             "-text {Set destination} -command {SetDestination;CloseDialog " &
             Destination_Dialog & "}");
      Dialog_Close_Button: constant Ttk_Button :=
        Create
          (pathName => Destination_Dialog & ".button",
           options =>
             "-text Close -command {CloseDialog " & Destination_Dialog & "}");
   begin
      if (Map_X = 0 or Map_Y = 0)
        and then
          Update_Map_Info_Command
            (Client_Data => Client_Data, Interp => Interp, Argc => Argc,
             Argv => Argv) /=
          TCL_OK then
         Tcl_Eval
           (interp => Interp, strng => "CloseDialog " & Destination_Dialog);
         return TCL_ERROR;
      end if;
      if Player_Ship.Sky_X = Map_X and Player_Ship.Sky_Y = Map_Y then
         Tcl_Eval
           (interp => Interp, strng => "CloseDialog " & Destination_Dialog);
         return
           Show_Orders_Command
             (Client_Data => Client_Data, Interp => Interp, Argc => Argc,
              Argv => Argv);
      end if;
      Tcl.Tk.Ada.Grid.Grid(Slave => Button, Options => "-sticky we -padx 5");
      Bind
        (Widgt => Button, Sequence => "<Escape>",
         Script => "{" & Dialog_Close_Button & " invoke;break}");
      if Player_Ship.Speed /= DOCKED then
         Bind
           (Widgt => Button, Sequence => "<Tab>",
            Script => "{focus " & Destination_Dialog & ".setandmove;break}");
         Button :=
           Create
             (pathName => Destination_Dialog & ".setandmove",
              options =>
                "-text {Set destination and move} -command {SetDestination;MoveShip moveto;CloseDialog " &
                Destination_Dialog & "}");
         Tcl.Tk.Ada.Grid.Grid
           (Slave => Button, Options => "-sticky we -padx 5");
         Bind
           (Widgt => Button, Sequence => "<Escape>",
            Script => "{" & Dialog_Close_Button & " invoke;break}");
         if Player_Ship.Destination_X > 0 and
           Player_Ship.Destination_Y > 0 then
            Bind
              (Widgt => Button, Sequence => "<Tab>",
               Script => "{focus " & Destination_Dialog & ".move;break}");
            Button :=
              Create
                (pathName => Destination_Dialog & ".move",
                 options =>
                   "-text {Move to} -command {MoveShip moveto;CloseDialog " &
                   Destination_Dialog & "}");
            Tcl.Tk.Ada.Grid.Grid
              (Slave => Button, Options => "-sticky we -padx 5");
            Bind
              (Widgt => Button, Sequence => "<Escape>",
               Script => "{" & Dialog_Close_Button & " invoke;break}");
            Bind
              (Widgt => Button, Sequence => "<Tab>",
               Script => "{focus " & Destination_Dialog & ".button;break}");
         end if;
      end if;
      Tcl.Tk.Ada.Grid.Grid
        (Slave => Dialog_Close_Button,
         Options => "-sticky we -padx 5 -pady {0 5}");
      Bind
        (Widgt => Dialog_Close_Button, Sequence => "<Tab>",
         Script => "{focus " & Destination_Dialog & ".set;break}");
      Bind
        (Widgt => Dialog_Close_Button, Sequence => "<Escape>",
         Script => "{" & Dialog_Close_Button & " invoke;break}");
      Show_Dialog
        (Dialog => Destination_Dialog, Parent_Frame => ".gameframe",
         Relative_X => 0.4);
      return TCL_OK;
   end Show_Destination_Menu_Command;

   -- ****o* MapCommands/MapCommands.Set_Ship_Destination_Command
   -- FUNCTION
   -- Set current map cell as destination for the player's ship
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed. Unused
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- SetDestination
   -- SOURCE
   function Set_Ship_Destination_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Set_Ship_Destination_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Interp, Argc, Argv);
   begin
      Player_Ship.Destination_X := Map_X;
      Player_Ship.Destination_Y := Map_Y;
      Add_Message
        (Message => "You set the travel destination for your ship.",
         M_Type => ORDERMESSAGE);
      if Game_Settings.Auto_Center then
         Center_X := Player_Ship.Sky_X;
         Center_Y := Player_Ship.Sky_Y;
      end if;
      Draw_Map;
      Update_Move_Buttons;
      return TCL_OK;
   end Set_Ship_Destination_Command;

   -- ****o* MapCommands/MapCommands.Move_Map_Command
   -- FUNCTION
   -- Move map in the selected direction
   -- PARAMETERS
   -- Client_Data - Custom data send to the command.
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- MoveMap direction
   -- Direction in which the map will be moved
   -- SOURCE
   function Move_Map_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Move_Map_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Argc);
      Map_View: constant Tk_Text :=
        Get_Widget(pathName => Main_Paned & ".mapframe.map", Interp => Interp);
      Map_Height, Map_Width: Positive;
      Dialog_Name: constant String := ".gameframe.movemapdialog";
      Spin_Box: Ttk_SpinBox :=
        Get_Widget(pathName => Dialog_Name & ".x", Interp => Interp);
   begin
      if Winfo_Get(Widgt => Map_View, Info => "ismapped") = "0" then
         return TCL_OK;
      end if;
      Map_Height :=
        Positive'Value(cget(Widgt => Map_View, option => "-height"));
      Map_Width := Positive'Value(cget(Widgt => Map_View, option => "-width"));
      if CArgv.Arg(Argv => Argv, N => 1) = "centeronship" then
         Center_X := Player_Ship.Sky_X;
         Center_Y := Player_Ship.Sky_Y;
      elsif CArgv.Arg(Argv => Argv, N => 1) = "movemapto" then
         Center_X := Positive'Value(Get(Widgt => Spin_Box));
         Spin_Box.Name := New_String(Str => Dialog_Name & ".y");
         Center_Y := Positive'Value(Get(Widgt => Spin_Box));
      elsif CArgv.Arg(Argv => Argv, N => 1) = "n" then
         Center_Y :=
           (if Center_Y - (Map_Height / 3) < 1 then Map_Height / 3
            else Center_Y - (Map_Height / 3));
      elsif CArgv.Arg(Argv => Argv, N => 1) = "s" then
         Center_Y :=
           (if Center_Y + (Map_Height / 3) > 1_024 then
              1_024 - (Map_Height / 3)
            else Center_Y + (Map_Height / 3));
      elsif CArgv.Arg(Argv => Argv, N => 1) = "w" then
         Center_X :=
           (if Center_X - (Map_Width / 3) < 1 then Map_Width / 3
            else Center_X - (Map_Width / 3));
      elsif CArgv.Arg(Argv => Argv, N => 1) = "e" then
         Center_X :=
           (if Center_X + (Map_Width / 3) > 1_024 then 1_024 - (Map_Width / 3)
            else Center_X + (Map_Width / 3));
      elsif CArgv.Arg(Argv => Argv, N => 1) = "nw" then
         Center_Y :=
           (if Center_Y - (Map_Height / 3) < 1 then Map_Height / 3
            else Center_Y - (Map_Height / 3));
         Center_X :=
           (if Center_X - (Map_Width / 3) < 1 then Map_Width / 3
            else Center_X - (Map_Width / 3));
      elsif CArgv.Arg(Argv => Argv, N => 1) = "ne" then
         Center_Y :=
           (if Center_Y - (Map_Height / 3) < 1 then Map_Height / 3
            else Center_Y - (Map_Height / 3));
         Center_X :=
           (if Center_X + (Map_Width / 3) > 1_024 then 1_024 - (Map_Width / 3)
            else Center_X + (Map_Width / 3));
      elsif CArgv.Arg(Argv => Argv, N => 1) = "sw" then
         Center_Y :=
           (if Center_Y + (Map_Height / 3) > 1_024 then
              1_024 - (Map_Height / 3)
            else Center_Y + (Map_Height / 3));
         Center_X :=
           (if Center_X - (Map_Width / 3) < 1 then Map_Width / 3
            else Center_X - (Map_Width / 3));
      elsif CArgv.Arg(Argv => Argv, N => 1) = "se" then
         Center_Y :=
           (if Center_Y + (Map_Height / 3) > 1_024 then
              1_024 - (Map_Height / 3)
            else Center_Y + (Map_Height / 3));
         Center_X :=
           (if Center_X + (Map_Width / 3) > 1_024 then 1_024 - (Map_Width / 3)
            else Center_X + (Map_Width / 3));
      elsif CArgv.Arg(Argv => Argv, N => 1) = "centeronhome" then
         Center_X := Sky_Bases(Player_Ship.Home_Base).Sky_X;
         Center_Y := Sky_Bases(Player_Ship.Home_Base).Sky_Y;
      end if;
      Draw_Map;
      return
        Close_Dialog_Command
          (Client_Data => Client_Data, Interp => Interp, Argc => 2,
           Argv => Empty & "CloseDialog" & Dialog_Name);
   end Move_Map_Command;

   -- ****o* MapCommands/MapCommands.Zoom_Map_Command
   -- FUNCTION
   -- Zoom the sky map
   -- PARAMETERS
   -- Client_Data - Custom data send to the command.
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command.
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ZoomMap
   -- SOURCE
   function Zoom_Map_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Zoom_Map_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
   begin
      Game_Settings.Map_Font_Size :=
        (if CArgv.Arg(Argv => Argv, N => 1) = "raise" then
           Game_Settings.Map_Font_Size + 1
         else Game_Settings.Map_Font_Size - 1);
      if Game_Settings.Map_Font_Size < 3 then
         Game_Settings.Map_Font_Size := 3;
      elsif Game_Settings.Map_Font_Size > 50 then
         Game_Settings.Map_Font_Size := 50;
      end if;
      Tcl_Eval
        (interp => Interp,
         strng =>
           "font configure MapFont -size" &
           Positive'Image(Game_Settings.Map_Font_Size));
      Tcl_SetVar(interp => Interp, varName => "refreshmap", newValue => "1");
      return
        Draw_Map_Command
          (Client_Data => Client_Data, Interp => Interp, Argc => Argc,
           Argv => Argv);
   end Zoom_Map_Command;

   -- ****o* MapCommands/MapCommands.Move_Command
   -- FUNCTION
   -- Move the player ship in the selected location and check what happens
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- MoveShip direction
   -- Direction in which the player's ship will be moved
   -- SOURCE
   function Move_Ship_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Move_Ship_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc);
      Message: Unbounded_String;
      Result: Natural;
      Starts_Combat: Boolean := False;
      New_X, New_Y: Integer := 0;
      procedure Update_Coordinates is
      begin
         if Player_Ship.Destination_X > Player_Ship.Sky_X then
            New_X := 1;
         elsif Player_Ship.Destination_X < Player_Ship.Sky_X then
            New_X := -1;
         end if;
         if Player_Ship.Destination_Y > Player_Ship.Sky_Y then
            New_Y := 1;
         elsif Player_Ship.Destination_Y < Player_Ship.Sky_Y then
            New_Y := -1;
         end if;
      end Update_Coordinates;
   begin
      if CArgv.Arg(Argv => Argv, N => 1) = "n" then -- Move up
         Result := Move_Ship(X => 0, Y => -1, Message => Message);
      elsif CArgv.Arg(Argv => Argv, N => 1) = "s" then -- Move down
         Result := Move_Ship(X => 0, Y => 1, Message => Message);
      elsif CArgv.Arg(Argv => Argv, N => 1) = "e" then -- Move right
         Result := Move_Ship(X => 1, Y => 0, Message => Message);
      elsif CArgv.Arg(Argv => Argv, N => 1) = "w" then -- Move left
         Result := Move_Ship(X => -1, Y => 0, Message => Message);
      elsif CArgv.Arg(Argv => Argv, N => 1) = "sw" then -- Move down/left
         Result := Move_Ship(X => -1, Y => 1, Message => Message);
      elsif CArgv.Arg(Argv => Argv, N => 1) = "se" then -- Move down/right
         Result := Move_Ship(X => 1, Y => 1, Message => Message);
      elsif CArgv.Arg(Argv => Argv, N => 1) = "nw" then -- Move up/left
         Result := Move_Ship(X => -1, Y => -1, Message => Message);
      elsif CArgv.Arg(Argv => Argv, N => 1) = "ne" then -- Move up/right
         Result := Move_Ship(X => 1, Y => -1, Message => Message);
      elsif CArgv.Arg(Argv => Argv, N => 1) =
        "waitormove" then -- Move to destination or wait 1 game minute
         if Player_Ship.Destination_X = 0 and
           Player_Ship.Destination_Y = 0 then
            Result := 1;
            Update_Game(Minutes => 1);
            Wait_In_Place(Minutes => 1);
         else
            Update_Coordinates;
            Result := Move_Ship(X => New_X, Y => New_Y, Message => Message);
            if Player_Ship.Destination_X = Player_Ship.Sky_X and
              Player_Ship.Destination_Y = Player_Ship.Sky_Y then
               Add_Message
                 (Message => "You reached your travel destination.",
                  M_Type => ORDERMESSAGE);
               Player_Ship.Destination_X := 0;
               Player_Ship.Destination_Y := 0;
               if Game_Settings.Auto_Finish then
                  Message :=
                    To_Unbounded_String(Source => Auto_Finish_Missions);
               end if;
               Result := 4;
            end if;
         end if;
      elsif CArgv.Arg(Argv => Argv, N => 1) =
        "moveto" then -- Move to destination
         Move_Loop :
         loop
            New_X := 0;
            New_Y := 0;
            Update_Coordinates;
            Result := Move_Ship(X => New_X, Y => New_Y, Message => Message);
            exit Move_Loop when Result = 0;
            Starts_Combat := Check_For_Event;
            if Starts_Combat then
               Result := 4;
               exit Move_Loop;
            end if;
            if Result = 8 then
               Wait_For_Rest;
               if not Get_Faction(Index => Player_Ship.Crew(1).Faction).Flags
                   .Contains
                   (Item => To_Unbounded_String(Source => "sentientships"))
                 and then
                 (Find_Member(Order => PILOT) = 0 or
                  Find_Member(Order => ENGINEER) = 0) then
                  Wait_For_Rest;
               end if;
               Result := 1;
               Starts_Combat := Check_For_Event;
               if Starts_Combat then
                  Result := 4;
                  exit Move_Loop;
               end if;
            end if;
            if Game_Settings.Auto_Move_Stop /= NEVER and
              Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Event_Index >
                0 then
               Get_Event_Block :
               declare
                  Event_Index: constant Positive :=
                    Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Event_Index;
               begin
                  case Game_Settings.Auto_Move_Stop is
                     when ANY =>
                        if Get_Event(Index => Event_Index).E_Type in ENEMYSHIP |
                              TRADER | FRIENDLYSHIP | ENEMYPATROL then
                           Result := 0;
                           exit Move_Loop;
                        end if;
                     when FRIENDLY =>
                        if Get_Event(Index => Event_Index).E_Type in TRADER |
                              FRIENDLYSHIP then
                           Result := 0;
                           exit Move_Loop;
                        end if;
                     when Config.ENEMY =>
                        if Get_Event(Index => Event_Index).E_Type in ENEMYSHIP |
                              ENEMYPATROL then
                           Result := 0;
                           exit Move_Loop;
                        end if;
                     when NEVER =>
                        null;
                  end case;
               end Get_Event_Block;
            end if;
            Set_Low_Amount_Info_Block :
            declare
               Message_Dialog: constant Ttk_Frame :=
                 Get_Widget(pathName => ".message", Interp => Interp);
            begin
               if Winfo_Get(Widgt => Message_Dialog, Info => "exists") =
                 "0" then
                  if Get_Item_Amount(Item_Type => Fuel_Type) <=
                    Game_Settings.Low_Fuel then
                     Show_Message
                       (Text => "Your fuel level is dangerously low.",
                        Title => "Low fuel level");
                     Result := 4;
                     exit Move_Loop;
                  elsif Get_Items_Amount(I_Type => "Food") <=
                    Game_Settings.Low_Food then
                     Show_Message
                       (Text => "Your food level is dangerously low.",
                        Title => "Low amount of food");
                     Result := 4;
                     exit Move_Loop;
                  elsif Get_Items_Amount(I_Type => "Drinks") <=
                    Game_Settings.Low_Drinks then
                     Show_Message
                       (Text => "Your drinks level is dangerously low.",
                        Title => "Low level of drinks");
                     Result := 4;
                     exit Move_Loop;
                  end if;
               end if;
            end Set_Low_Amount_Info_Block;
            if Player_Ship.Destination_X = Player_Ship.Sky_X and
              Player_Ship.Destination_Y = Player_Ship.Sky_Y then
               Add_Message
                 (Message => "You reached your travel destination.",
                  M_Type => ORDERMESSAGE);
               Player_Ship.Destination_X := 0;
               Player_Ship.Destination_Y := 0;
               if Game_Settings.Auto_Finish then
                  Message :=
                    To_Unbounded_String(Source => Auto_Finish_Missions);
               end if;
               Result := 4;
               exit Move_Loop;
            end if;
            exit Move_Loop when Result = 6 or Result = 7;
         end loop Move_Loop;
      end if;
      case Result is
         when 1 => -- Ship moved, check for events
            Starts_Combat := Check_For_Event;
            if not Starts_Combat and Game_Settings.Auto_Finish then
               Message := To_Unbounded_String(Source => Auto_Finish_Missions);
            end if;
         when 6 => -- Ship moved, but pilot needs rest, confirm
            Show_Question
              (Question =>
                 "You don't have pilot on duty. Do you want to wait until your pilot rest?",
               Result => "nopilot");
            return TCL_OK;
         when 7 => -- Ship moved, but engineer needs rest, confirm
            Show_Question
              (Question =>
                 "You don't have engineer on duty. Do you want to wait until your engineer rest?",
               Result => "nopilot");
            return TCL_OK;
         when 8 => -- Ship moved, but crew needs rest, autorest
            Starts_Combat := Check_For_Event;
            if not Starts_Combat then
               Wait_For_Rest;
               if not Get_Faction(Index => Player_Ship.Crew(1).Faction).Flags
                   .Contains
                   (Item => To_Unbounded_String(Source => "sentientships"))
                 and then
                 (Find_Member(Order => PILOT) = 0 or
                  Find_Member(Order => ENGINEER) = 0) then
                  Wait_For_Rest;
               end if;
               Starts_Combat := Check_For_Event;
            end if;
            if not Starts_Combat and Game_Settings.Auto_Finish then
               Message := To_Unbounded_String(Source => Auto_Finish_Missions);
            end if;
         when others =>
            null;
      end case;
      if Message /= Null_Unbounded_String then
         Show_Message
           (Text => To_String(Source => Message), Title => "Message");
      end if;
      Center_X := Player_Ship.Sky_X;
      Center_Y := Player_Ship.Sky_Y;
      if Starts_Combat then
         Show_Combat_Ui;
      else
         Show_Sky_Map;
      end if;
      return TCL_OK;
   end Move_Ship_Command;

   -- ****o* MapCommands/MapCommands.Quit_Game_Command
   -- FUNCTION
   -- Ask player if he/she wants to quit from the game and if yes, save it and
   -- show main menu
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed. Unused
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- QuitGame
   -- SOURCE
   function Quit_Game_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Quit_Game_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Interp, Argc, Argv);
   begin
      Show_Question
        (Question => "Are you sure want to quit?", Result => "quit");
      return TCL_OK;
   end Quit_Game_Command;

   -- ****o* MapCommands/MapCommands.Resign_Game_Command
   -- FUNCTION
   -- Resing from the game - if player resigned, kill he/she character and
   -- follow as for death of the player's character
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed. Unused
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ResignGame
   -- SOURCE
   function Resign_Game_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Resign_Game_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Interp, Argc, Argv);
   begin
      Show_Question
        (Question => "Are you sure want to resign from game?",
         Result => "resign");
      return TCL_OK;
   end Resign_Game_Command;

   -- ****o* MapCommands/MapCommands.Show_Stats_Command
   -- FUNCTION
   -- Show the player's game statistics
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed. Unused
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowStats
   -- SOURCE
   function Show_Stats_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Stats_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Interp, Argc, Argv);
   begin
      Tcl.Tk.Ada.Grid.Grid
        (Slave => Close_Button, Options => "-row 0 -column 1");
      Show_Statistics;
      return TCL_OK;
   end Show_Stats_Command;

   -- ****o* MapCommands/MapCommands.Show_Sky_Map_Command
   -- FUNCTION
   -- Show sky map
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed. Unused
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowSkyMap ?previouscommand?
   -- Previouscommand is command to show previous screen. Some screens require
   -- to do special actions when closing them
   -- SOURCE
   function Show_Sky_Map_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Sky_Map_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data);
   begin
      if Argc = 1 then
         Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Close_Button);
         Show_Sky_Map(Clear => True);
      else
         Tcl_Eval(interp => Interp, strng => CArgv.Arg(Argv => Argv, N => 1));
      end if;
      Focus(Widgt => Get_Main_Window(Interp => Interp));
      return TCL_OK;
   end Show_Sky_Map_Command;

   -- ****o* MapCommands/MapCommands.Move_Mouse_Command
   -- FUNCTION
   -- Move mouse cursor with keyboard
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- MoveCursor direction
   -- Direction is the direction in which the mouse cursor should be moves or
   -- click if emulate clicking with the left or right button
   -- SOURCE
   function Move_Mouse_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Move_Mouse_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc);
      Map_View: constant Tk_Text :=
        Get_Widget(pathName => Main_Paned & ".mapframe.map", Interp => Interp);
   begin
      if Focus /= Widget_Image(Win => Map_View) then
         Focus(Widgt => Map_View, Option => "-force");
         return TCL_OK;
      end if;
      if CArgv.Arg(Argv => Argv, N => 1) = "click" then
         Generate
           (Window => Map_View,
            EventName =>
              "<Button-" & (if Game_Settings.Right_Button then "3" else "1") &
              ">",
            Options =>
              "-x " & CArgv.Arg(Argv => Argv, N => 2) & " -y " &
              CArgv.Arg(Argv => Argv, N => 3));
      elsif CArgv.Arg(Argv => Argv, N => 1) = "nw" then
         Generate
           (Window => Map_View, EventName => "<Motion>",
            Options =>
              "-warp 1 -x [expr " & CArgv.Arg(Argv => Argv, N => 2) &
              "-5] -y [expr " & CArgv.Arg(Argv => Argv, N => 3) & "-5]");
      elsif CArgv.Arg(Argv => Argv, N => 1) = "n" then
         Generate
           (Window => Map_View, EventName => "<Motion>",
            Options =>
              "-warp 1 -x " & CArgv.Arg(Argv => Argv, N => 2) & " -y [expr " &
              CArgv.Arg(Argv => Argv, N => 3) & "-5]");
      elsif CArgv.Arg(Argv => Argv, N => 1) = "ne" then
         Generate
           (Window => Map_View, EventName => "<Motion>",
            Options =>
              "-warp 1 -x [expr " & CArgv.Arg(Argv => Argv, N => 2) &
              "+5] -y [expr " & CArgv.Arg(Argv => Argv, N => 3) & "-5]");
      elsif CArgv.Arg(Argv => Argv, N => 1) = "w" then
         Generate
           (Window => Map_View, EventName => "<Motion>",
            Options =>
              "-warp 1 -x [expr " & CArgv.Arg(Argv => Argv, N => 2) &
              "-5] -y " & CArgv.Arg(Argv => Argv, N => 3));
      elsif CArgv.Arg(Argv => Argv, N => 1) = "e" then
         Generate
           (Window => Map_View, EventName => "<Motion>",
            Options =>
              "-warp 1 -x [expr " & CArgv.Arg(Argv => Argv, N => 2) &
              "+5] -y " & CArgv.Arg(Argv => Argv, N => 3));
      elsif CArgv.Arg(Argv => Argv, N => 1) = "sw" then
         Generate
           (Window => Map_View, EventName => "<Motion>",
            Options =>
              "-warp 1 -x [expr " & CArgv.Arg(Argv => Argv, N => 2) &
              "-5] -y [expr " & CArgv.Arg(Argv => Argv, N => 3) & "+5]");
      elsif CArgv.Arg(Argv => Argv, N => 1) = "s" then
         Generate
           (Window => Map_View, EventName => "<Motion>",
            Options =>
              "-warp 1 -x " & CArgv.Arg(Argv => Argv, N => 2) & " -y [expr " &
              CArgv.Arg(Argv => Argv, N => 3) & "+5]");
      elsif CArgv.Arg(Argv => Argv, N => 1) = "se" then
         Generate
           (Window => Map_View, EventName => "<Motion>",
            Options =>
              "-warp 1 -x [expr " & CArgv.Arg(Argv => Argv, N => 2) &
              "+5] -y [expr " & CArgv.Arg(Argv => Argv, N => 3) & "+5]");
      end if;
      return TCL_OK;
   end Move_Mouse_Command;

   -- ****o* MapCommands/MapCommands.Toggle_Full_Screen_Command
   -- FUNCTION
   -- Toggle the game full screen mode
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ToggleFullScreen
   -- SOURCE
   function Toggle_Full_Screen_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Toggle_Full_Screen_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc, Argv);
   begin
      Tcl_Eval(interp => Interp, strng => "wm attributes . -fullscreen");
      if Tcl_GetResult(interp => Interp) = "0" then
         Wm_Set
           (Widgt => Get_Main_Window(Interp => Interp), Action => "attributes",
            Options => "-fullscreen 1");
         Game_Settings.Full_Screen := True;
      else
         Wm_Set
           (Widgt => Get_Main_Window(Interp => Interp), Action => "attributes",
            Options => "-fullscreen 0");
         Game_Settings.Full_Screen := False;
      end if;
      return TCL_OK;
   end Toggle_Full_Screen_Command;

   -- ****o* MapCommands/MapCommands.Resize_Last_Messages_Command
   -- FUNCTION
   -- Resize the last messages window
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ResizeLastMessages
   -- SOURCE
   function Resize_Last_Messages_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Resize_Last_Messages_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc, Argv);
      Paned_Position: Positive;
      Sash_Position: constant Natural :=
        Natural'Value(SashPos(Paned => Main_Paned, Index => "0"));
      procedure Set_Ada_Messages_Position(New_Value: Integer) with
         Import => True,
         Convention => C,
         External_Name => "setAdaMessagesPosition";
   begin
      Game_Settings.Window_Width :=
        Positive'Value
          (Winfo_Get
             (Widgt => Get_Main_Window(Interp => Interp), Info => "width"));
      Game_Settings.Window_Height :=
        Positive'Value
          (Winfo_Get
             (Widgt => Get_Main_Window(Interp => Interp), Info => "height"));
      Paned_Position :=
        (if Game_Settings.Window_Height - Game_Settings.Messages_Position < 0
         then Game_Settings.Window_Height
         else Game_Settings.Window_Height - Game_Settings.Messages_Position);
      if Sash_Position > 0 and then Sash_Position /= Paned_Position then
         if Game_Settings.Window_Height - Sash_Position > -1 then
            Game_Settings.Messages_Position :=
              Game_Settings.Window_Height - Sash_Position;
            Set_Ada_Messages_Position
              (New_Value => Game_Settings.Messages_Position);
         end if;
         Paned_Position := Sash_Position;
      end if;
      return TCL_OK;
   end Resize_Last_Messages_Command;

   -- ****o* MapCommands/MapCommands.Show_Game_Menu_Command
   -- FUNCTION
   -- Show the main menu of the game
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowGameMenu
   -- SOURCE
   function Show_Game_Menu_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Game_Menu_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc, Argv);
      Row: Positive := 1;
      State: constant String :=
        Tcl_GetVar(interp => Interp, varName => "gamestate");
      type Menu_Shortcut is record
         Button_Name: Unbounded_String;
         Shortcut: Unbounded_String;
      end record;
      package Shortcuts_Container is new Vectors
        (Index_Type => Positive, Element_Type => Menu_Shortcut);
      Shortcuts: Shortcuts_Container.Vector;
      Game_Menu: Ttk_Frame := Get_Widget(pathName => ".gameframe.gamemenu");
      procedure Add_Button
        (Name, Label, Command: String; Shortcut: Unbounded_String;
         Last: Boolean := False) is
         Button: constant Ttk_Button :=
           Create
             (pathName => Game_Menu & Name,
              options =>
                "-text {" & Label & " [" & To_String(Source => Shortcut) &
                "]} -command {CloseDialog " & Game_Menu & ";" & Command & "}");
      begin
         if not Last then
            Tcl.Tk.Ada.Grid.Grid
              (Slave => Button, Options => "-sticky we -padx 5");
         else
            Bind
              (Widgt => Button, Sequence => "<Tab>",
               Script =>
                 "{focus " &
                 To_String(Source => Shortcuts.First_Element.Button_Name) &
                 ";break}");
            Tcl.Tk.Ada.Grid.Grid
              (Slave => Button, Options => "-sticky we -padx 5 -pady {0 3}");
            Focus(Widgt => Button);
         end if;
         Shortcuts.Append
           (New_Item =>
              (Button_Name => To_Unbounded_String(Source => Game_Menu & Name),
               Shortcut => Shortcut));
         Row := Row + 1;
      end Add_Button;
   begin
      if Winfo_Get(Widgt => Game_Menu, Info => "exists") = "1" then
         Tcl_Eval(interp => Interp, strng => "CloseDialog " & Game_Menu);
         return TCL_OK;
      end if;
      Game_Menu :=
        Create_Dialog(Name => ".gameframe.gamemenu", Title => "Game menu");
      Add_Button
        (Name => ".shipinfo", Label => "Ship information",
         Command => "ShowShipInfo", Shortcut => Menu_Accelerators(1));
      if State not in "combat" | "dead" then
         Add_Button
           (Name => ".shiporders", Label => "Ship orders",
            Command => "ShowOrders", Shortcut => Menu_Accelerators(2));
      end if;
      if State /= "dead" then
         Add_Button
           (Name => ".crafting", Label => "Crafting",
            Command => "ShowCrafting", Shortcut => Menu_Accelerators(3));
      end if;
      Add_Button
        (Name => ".messages", Label => "Last messages",
         Command => "ShowLastMessages", Shortcut => Menu_Accelerators(4));
      Add_Button
        (Name => ".knowledge", Label => "Knowledge lists",
         Command => "ShowKnowledge", Shortcut => Menu_Accelerators(5));
      if State not in "combat" | "dead" then
         Add_Button
           (Name => ".wait", Label => "Wait orders", Command => "ShowWait",
            Shortcut => Menu_Accelerators(6));
      end if;
      Add_Button
        (Name => ".stats", Label => "Game statistics", Command => "ShowStats",
         Shortcut => Menu_Accelerators(7));
      if State /= "dead" then
         Add_Button
           (Name => ".help", Label => "Help", Command => "ShowHelp " & State,
            Shortcut => Menu_Accelerators(8));
         Add_Button
           (Name => ".options", Label => "Game options",
            Command => "ShowOptions", Shortcut => Menu_Accelerators(9));
         Add_Button
           (Name => ".quit", Label => "Quit from game", Command => "QuitGame",
            Shortcut => Menu_Accelerators(10));
         Add_Button
           (Name => ".resign", Label => "Resign from game",
            Command => "ResignGame", Shortcut => Menu_Accelerators(11));
      end if;
      Add_Button
        (Name => ".close", Label => "Close",
         Command => "CloseDialog " & Game_Menu,
         Shortcut => To_Unbounded_String(Source => "Escape"), Last => True);
      Add_Bindings_Block :
      declare
         Menu_Button: Ttk_Button;
      begin
         Buttons_Loop :
         for Button of Shortcuts loop
            Menu_Button :=
              Get_Widget(pathName => To_String(Source => Button.Button_Name));
            Add_Bindings_Loop :
            for Shortcut of Shortcuts loop
               Bind
                 (Widgt => Menu_Button,
                  Sequence =>
                    "<KeyPress-" & To_String(Source => Shortcut.Shortcut) &
                    ">",
                  Script =>
                    "{" & To_String(Source => Shortcut.Button_Name) &
                    " invoke;break}");
            end loop Add_Bindings_Loop;
            Bind
              (Widgt => Menu_Button,
               Sequence =>
                 "<KeyPress-" & To_String(Source => Map_Accelerators(1)) & ">",
               Script => "{ShowGameMenu;break}");
         end loop Buttons_Loop;
      end Add_Bindings_Block;
      Show_Dialog(Dialog => Game_Menu, Relative_X => 0.4, Relative_Y => 0.1);
      return TCL_OK;
   end Show_Game_Menu_Command;

   -- ****o* MapCommands/MapCommands.Invoke_Menu_Command
   -- FUNCTION
   -- Invoke the selected game menu option with the selected keyboard shortcut
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- InvokeMenu shortcut
   -- Shortcut, the keyboard shortcut which was pressed
   -- SOURCE
   function Invoke_Menu_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Invoke_Menu_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc);
      Focused_Widget: constant Ttk_Frame :=
        Get_Widget(pathName => Focus(Interp => Interp), Interp => Interp);
      Commands: constant array(Menu_Accelerators'Range) of Unbounded_String :=
        (1 => To_Unbounded_String(Source => "ShowShipInfo"),
         2 => To_Unbounded_String(Source => "ShowOrders"),
         3 => To_Unbounded_String(Source => "ShowCrafting"),
         4 => To_Unbounded_String(Source => "ShowLastMessages"),
         5 => To_Unbounded_String(Source => "ShowKnowledge"),
         6 => To_Unbounded_String(Source => "ShowWait"),
         7 => To_Unbounded_String(Source => "ShowStats"),
         8 => To_Unbounded_String(Source => "ShowHelp"),
         9 => To_Unbounded_String(Source => "ShowOptions"),
         10 => To_Unbounded_String(Source => "QuitGame"),
         11 => To_Unbounded_String(Source => "ResignGame"));
   begin
      if Winfo_Get(Widgt => Focused_Widget, Info => "class") = "TEntry" or
        Tcl.Tk.Ada.Busy.Status(Window => Game_Header) = "1" then
         return TCL_OK;
      end if;
      Invoke_Button_Loop :
      for I in Menu_Accelerators'Range loop
         if To_String(Source => Menu_Accelerators(I)) =
           CArgv.Arg(Argv => Argv, N => 1) then
            Tcl_Eval
              (interp => Interp, strng => To_String(Source => Commands(I)));
            return TCL_OK;
         end if;
      end loop Invoke_Button_Loop;
      return TCL_OK;
   end Invoke_Menu_Command;

   procedure Add_Commands is
   begin
      Add_Command
        (Name => "HideMapButtons",
         Ada_Command => Hide_Map_Buttons_Command'Access);
      Add_Command
        (Name => "ShowMapButtons",
         Ada_Command => Show_Map_Buttons_Command'Access);
      Add_Command
        (Name => "MoveMapButtons",
         Ada_Command => Move_Map_Buttons_Command'Access);
      Add_Command(Name => "DrawMap", Ada_Command => Draw_Map_Command'Access);
      Add_Command
        (Name => "UpdateMapInfo",
         Ada_Command => Update_Map_Info_Command'Access);
      Add_Command
        (Name => "MoveMapInfo", Ada_Command => Move_Map_Info_Command'Access);
      Add_Command
        (Name => "ShowDestinationMenu",
         Ada_Command => Show_Destination_Menu_Command'Access);
      Add_Command
        (Name => "SetDestination",
         Ada_Command => Set_Ship_Destination_Command'Access);
      Add_Command(Name => "MoveMap", Ada_Command => Move_Map_Command'Access);
      Add_Command(Name => "ZoomMap", Ada_Command => Zoom_Map_Command'Access);
      Add_Command(Name => "MoveShip", Ada_Command => Move_Ship_Command'Access);
      Add_Command(Name => "QuitGame", Ada_Command => Quit_Game_Command'Access);
      Add_Command
        (Name => "ResignGame", Ada_Command => Resign_Game_Command'Access);
      Add_Command
        (Name => "ShowStats", Ada_Command => Show_Stats_Command'Access);
      Add_Command
        (Name => "ShowSkyMap", Ada_Command => Show_Sky_Map_Command'Access);
      Add_Command
        (Name => "MoveCursor", Ada_Command => Move_Mouse_Command'Access);
      Add_Command
        (Name => "ToggleFullScreen",
         Ada_Command => Toggle_Full_Screen_Command'Access);
      Add_Command
        (Name => "ResizeLastMessages",
         Ada_Command => Resize_Last_Messages_Command'Access);
      Add_Command
        (Name => "ShowGameMenu", Ada_Command => Show_Game_Menu_Command'Access);
      Add_Command
        (Name => "InvokeMenu", Ada_Command => Invoke_Menu_Command'Access);
   end Add_Commands;

end Maps.UI.Commands;
