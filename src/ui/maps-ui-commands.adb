-- Copyright (c) 2020-2022 Bartek thindil Jasicki <thindil@laeran.pl>
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

   ButtonNames: constant array(1 .. 13) of Unbounded_String :=
     (To_Unbounded_String("show"), To_Unbounded_String("nw"),
      To_Unbounded_String("n"), To_Unbounded_String("ne"),
      To_Unbounded_String("w"), To_Unbounded_String("wait"),
      To_Unbounded_String("e"), To_Unbounded_String("sw"),
      To_Unbounded_String("s"), To_Unbounded_String("se"),
      To_Unbounded_String("hide"), To_Unbounded_String("left"),
      To_Unbounded_String("right"));

   -- ****o* MapCommands/MapCommands.Hide_Map_Buttons_Command
   -- FUNCTION
   -- Hide map movement buttons
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- HideMapButtons
   -- SOURCE
   function Hide_Map_Buttons_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Hide_Map_Buttons_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
      Button: Ttk_Button;
   begin
      Button.Interp := Interp;
      Hide_Buttons_Loop :
      for I in 2 .. 13 loop
         Button.Name :=
           New_String
             (Main_Paned & ".mapframe.buttons." & To_String(ButtonNames(I)));
         Tcl.Tk.Ada.Grid.Grid_Remove(Button);
      end loop Hide_Buttons_Loop;
      Button.Name := New_String(Main_Paned & ".mapframe.buttons.show");
      Tcl.Tk.Ada.Grid.Grid(Button);
      return TCL_OK;
   end Hide_Map_Buttons_Command;

   -- ****o* MapCommands/MapCommands.Show_Map_Buttons_Command
   -- FUNCTION
   -- Show map movement buttons
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowMapButtons
   -- SOURCE
   function Show_Map_Buttons_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Map_Buttons_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
      Button: Ttk_Button;
      ButtonsBox: constant Ttk_Frame :=
        Get_Widget(Main_Paned & ".mapframe.buttons", Interp);
   begin
      Button.Interp := Interp;
      Show_Buttons_Loop :
      for I in 2 .. 11 loop
         Button.Name :=
           New_String
             (Widget_Image(ButtonsBox) & "." & To_String(ButtonNames(I)));
         Tcl.Tk.Ada.Grid.Grid(Button);
      end loop Show_Buttons_Loop;
      Button.Name := New_String(Widget_Image(ButtonsBox) & ".show");
      Tcl.Tk.Ada.Grid.Grid_Remove(Button);
      Button.Name :=
        (if Index(Tcl.Tk.Ada.Grid.Grid_Info(ButtonsBox), "-sticky es") = 0 then
           New_String(Widget_Image(ButtonsBox) & ".right")
         else New_String(Widget_Image(ButtonsBox) & ".left"));
      Tcl.Tk.Ada.Grid.Grid(Button);
      return TCL_OK;
   end Show_Map_Buttons_Command;

   -- ****o* MapCommands/MapCommands.Move_Map_Buttons_Command
   -- FUNCTION
   -- Move map movement buttons left of right
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- MoveMapButtons buttonname
   -- Buttonname is the name of the button which was clicked
   -- SOURCE
   function Move_Map_Buttons_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Move_Map_Buttons_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      ButtonsBox: constant Ttk_Frame :=
        Get_Widget(Main_Paned & ".mapframe.buttons", Interp);
      Button: Ttk_Button :=
        Get_Widget(ButtonsBox & "." & CArgv.Arg(Argv, 1), Interp);
   begin
      Tcl.Tk.Ada.Grid.Grid_Remove(Button);
      if CArgv.Arg(Argv, 1) = "left" then
         Button.Name := New_String(Widget_Image(ButtonsBox) & ".right");
         Tcl.Tk.Ada.Grid.Grid_Configure(ButtonsBox, "-sticky sw");
      else
         Button.Name := New_String(Widget_Image(ButtonsBox) & ".left");
         Tcl.Tk.Ada.Grid.Grid_Configure(ButtonsBox, "-sticky se");
      end if;
      Tcl.Tk.Ada.Grid.Grid(Button);
      return TCL_OK;
   end Move_Map_Buttons_Command;

   -- ****o* MapCommands/MapCommands.Draw_Map_Command
   -- FUNCTION
   -- Draw the sky map
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- DrawMap
   -- SOURCE
   function Draw_Map_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Draw_Map_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
      MapView: constant Tk_Text :=
        Get_Widget(Main_Paned & ".mapframe.map", Interp);
   begin
      configure
        (MapView,
         "-width [expr [winfo width $mapview] / [font measure MapFont {" &
         Encode
           ("" &
            Themes_List(To_String(Game_Settings.Interface_Theme))
              .Empty_Map_Icon) &
         "}]]");
      configure
        (MapView,
         "-height [expr [winfo height $mapview] / [font metrics MapFont -linespace]]");
      Draw_Map;
      return TCL_OK;
   end Draw_Map_Command;

   -- ****iv* MapCommands/MapCommands.MapX
   -- FUNCTION
   -- Current map cell X coordinate (where mouse is hovering)
   -- SOURCE
   MapX: Natural := 0;
   -- ****

   -- ****iv* MapCommands/MapCommands.MapY
   -- FUNCTION
   -- Current map cell Y coordinate (where mouse is hovering)
   -- SOURCE
   MapY: Natural := 0;
   -- ****

   -- ****o* MapCommands/MapCommands.Update_Map_Info_Command
   -- FUNCTION
   -- Update map cell info
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- UpdateMapInfo x y
   -- X and Y are coordinates of the map cell which info will be show
   -- SOURCE
   function Update_Map_Info_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Update_Map_Info_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      MapView: constant Tk_Text :=
        Get_Widget(Main_Paned & ".mapframe.map", Interp);
      MapIndex: Unbounded_String;
   begin
      MapIndex :=
        To_Unbounded_String
          (Index
             (MapView, "@" & CArgv.Arg(Argv, 1) & "," & CArgv.Arg(Argv, 2)));
      if Start_Y +
        Integer'Value(Slice(MapIndex, 1, Index(MapIndex, ".") - 1)) - 1 <
        1 then
         return TCL_OK;
      end if;
      MapY :=
        Start_Y + Integer'Value(Slice(MapIndex, 1, Index(MapIndex, ".") - 1)) -
        1;
      if MapY > 1_024 then
         return TCL_OK;
      end if;
      if Start_X +
        Integer'Value
          (Slice(MapIndex, Index(MapIndex, ".") + 1, Length(MapIndex))) <
        1 then
         return TCL_OK;
      end if;
      MapX :=
        Start_X +
        Integer'Value
          (Slice(MapIndex, Index(MapIndex, ".") + 1, Length(MapIndex)));
      if MapX > 1_024 then
         return TCL_OK;
      end if;
      Update_Map_Info(MapX, MapY);
      return TCL_OK;
   end Update_Map_Info_Command;

   -- ****o* MapCommands/MapCommands.Move_Map_Info_Command
   -- FUNCTION
   -- Move map info frame when mouse enter it
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- MoveMapInfo
   -- SOURCE
   function Move_Map_Info_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Move_Map_Info_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
      MapInfoFrame: constant Ttk_Frame :=
        Get_Widget(Main_Paned & ".mapframe.info", Interp);
   begin
      Tcl.Tk.Ada.Grid.Grid_Configure
        (MapInfoFrame,
         "-sticky " &
         (if Index(Tcl.Tk.Ada.Grid.Grid_Info(MapInfoFrame), "-sticky ne") = 0
          then "ne"
          else "wn"));
      return TCL_OK;
   end Move_Map_Info_Command;

   -- ****o* MapCommands/MapCommands.Show_Destination_Menu_Command
   -- FUNCTION
   -- Create and show destination menu
   -- PARAMETERS
   -- ClientData - Custom data send to the command.
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command.
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowDestinationMenu x y
   -- X and Y are mouse coordinates on which the destination menu will be show
   -- SOURCE
   function Show_Destination_Menu_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Destination_Menu_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      DestinationDialog: constant Ttk_Frame :=
        Create_Dialog
          (Name => ".gameframe.destinationmenu", Title => "Set destination",
           Parent_Name => ".gameframe");
      Button: Ttk_Button :=
        Create
          (DestinationDialog & ".set",
           "-text {Set destination} -command {SetDestination;CloseDialog " &
           DestinationDialog & "}");
      CloseButton: constant Ttk_Button :=
        Create
          (DestinationDialog & ".button",
           "-text Close -command {CloseDialog " & DestinationDialog & "}");
   begin
      if (MapX = 0 or MapY = 0)
        and then Update_Map_Info_Command(ClientData, Interp, Argc, Argv) /=
          TCL_OK then
         Tcl_Eval(Interp, "CloseDialog " & DestinationDialog);
         return TCL_ERROR;
      end if;
      if Player_Ship.Sky_X = MapX and Player_Ship.Sky_Y = MapY then
         Tcl_Eval(Interp, "CloseDialog " & DestinationDialog);
         return Show_Orders_Command(ClientData, Interp, Argc, Argv);
      end if;
      Tcl.Tk.Ada.Grid.Grid(Button, "-sticky we -padx 5");
      Bind(Button, "<Escape>", "{" & CloseButton & " invoke;break}");
      if Player_Ship.Speed /= DOCKED then
         Bind
           (Button, "<Tab>",
            "{focus " & DestinationDialog & ".setandmove;break}");
         Button :=
           Create
             (DestinationDialog & ".setandmove",
              "-text {Set destination and move} -command {SetDestination;MoveShip moveto;CloseDialog " &
              DestinationDialog & "}");
         Tcl.Tk.Ada.Grid.Grid(Button, "-sticky we -padx 5");
         Bind(Button, "<Escape>", "{" & CloseButton & " invoke;break}");
         if Player_Ship.Destination_X > 0 and
           Player_Ship.Destination_Y > 0 then
            Bind
              (Button, "<Tab>",
               "{focus " & DestinationDialog & ".move;break}");
            Button :=
              Create
                (DestinationDialog & ".move",
                 "-text {Move to} -command {MoveShip moveto;CloseDialog " &
                 DestinationDialog & "}");
            Tcl.Tk.Ada.Grid.Grid(Button, "-sticky we -padx 5");
            Bind(Button, "<Escape>", "{" & CloseButton & " invoke;break}");
            Bind
              (Button, "<Tab>",
               "{focus " & DestinationDialog & ".button;break}");
         end if;
      end if;
      Tcl.Tk.Ada.Grid.Grid(CloseButton, "-sticky we -padx 5 -pady {0 5}");
      Bind
        (CloseButton, "<Tab>", "{focus " & DestinationDialog & ".set;break}");
      Bind(CloseButton, "<Escape>", "{" & CloseButton & " invoke;break}");
      Show_Dialog
        (Dialog => DestinationDialog, Parent_Frame => ".gameframe",
         Relative_X => 0.4);
      return TCL_OK;
   end Show_Destination_Menu_Command;

   -- ****o* MapCommands/MapCommands.Set_Ship_Destination_Command
   -- FUNCTION
   -- Set current map cell as destination for the player's ship
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed. Unused
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- SetDestination
   -- SOURCE
   function Set_Ship_Destination_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Set_Ship_Destination_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Interp, Argc, Argv);
   begin
      Player_Ship.Destination_X := MapX;
      Player_Ship.Destination_Y := MapY;
      Add_Message
        ("You set the travel destination for your ship.", ORDERMESSAGE);
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
   -- ClientData - Custom data send to the command.
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- MoveMap direction
   -- Direction in which the map will be moved
   -- SOURCE
   function Move_Map_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Move_Map_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Argc);
      MapView: constant Tk_Text :=
        Get_Widget(Main_Paned & ".mapframe.map", Interp);
      MapHeight, MapWidth: Positive;
      DialogName: constant String := ".gameframe.movemapdialog";
      SpinBox: Ttk_SpinBox := Get_Widget(DialogName & ".x", Interp);
   begin
      if Winfo_Get(MapView, "ismapped") = "0" then
         return TCL_OK;
      end if;
      MapHeight := Positive'Value(cget(MapView, "-height"));
      MapWidth := Positive'Value(cget(MapView, "-width"));
      if CArgv.Arg(Argv, 1) = "centeronship" then
         Center_X := Player_Ship.Sky_X;
         Center_Y := Player_Ship.Sky_Y;
      elsif CArgv.Arg(Argv, 1) = "movemapto" then
         Center_X := Positive'Value(Get(SpinBox));
         SpinBox.Name := New_String(DialogName & ".y");
         Center_Y := Positive'Value(Get(SpinBox));
      elsif CArgv.Arg(Argv, 1) = "n" then
         Center_Y :=
           (if Center_Y - (MapHeight / 3) < 1 then MapHeight / 3
            else Center_Y - (MapHeight / 3));
      elsif CArgv.Arg(Argv, 1) = "s" then
         Center_Y :=
           (if Center_Y + (MapHeight / 3) > 1_024 then 1_024 - (MapHeight / 3)
            else Center_Y + (MapHeight / 3));
      elsif CArgv.Arg(Argv, 1) = "w" then
         Center_X :=
           (if Center_X - (MapWidth / 3) < 1 then MapWidth / 3
            else Center_X - (MapWidth / 3));
      elsif CArgv.Arg(Argv, 1) = "e" then
         Center_X :=
           (if Center_X + (MapWidth / 3) > 1_024 then 1_024 - (MapWidth / 3)
            else Center_X + (MapWidth / 3));
      elsif CArgv.Arg(Argv, 1) = "nw" then
         Center_Y :=
           (if Center_Y - (MapHeight / 3) < 1 then MapHeight / 3
            else Center_Y - (MapHeight / 3));
         Center_X :=
           (if Center_X - (MapWidth / 3) < 1 then MapWidth / 3
            else Center_X - (MapWidth / 3));
      elsif CArgv.Arg(Argv, 1) = "ne" then
         Center_Y :=
           (if Center_Y - (MapHeight / 3) < 1 then MapHeight / 3
            else Center_Y - (MapHeight / 3));
         Center_X :=
           (if Center_X + (MapWidth / 3) > 1_024 then 1_024 - (MapWidth / 3)
            else Center_X + (MapWidth / 3));
      elsif CArgv.Arg(Argv, 1) = "sw" then
         Center_Y :=
           (if Center_Y + (MapHeight / 3) > 1_024 then 1_024 - (MapHeight / 3)
            else Center_Y + (MapHeight / 3));
         Center_X :=
           (if Center_X - (MapWidth / 3) < 1 then MapWidth / 3
            else Center_X - (MapWidth / 3));
      elsif CArgv.Arg(Argv, 1) = "se" then
         Center_Y :=
           (if Center_Y + (MapHeight / 3) > 1_024 then 1_024 - (MapHeight / 3)
            else Center_Y + (MapHeight / 3));
         Center_X :=
           (if Center_X + (MapWidth / 3) > 1_024 then 1_024 - (MapWidth / 3)
            else Center_X + (MapWidth / 3));
      elsif CArgv.Arg(Argv, 1) = "centeronhome" then
         Center_X := Sky_Bases(Player_Ship.Home_Base).Sky_X;
         Center_Y := Sky_Bases(Player_Ship.Home_Base).Sky_Y;
      end if;
      Draw_Map;
      return
        Close_Dialog_Command
          (ClientData, Interp, 2, Empty & "CloseDialog" & DialogName);
   end Move_Map_Command;

   -- ****o* MapCommands/MapCommands.Zoom_Map_Command
   -- FUNCTION
   -- Zoom the sky map
   -- PARAMETERS
   -- ClientData - Custom data send to the command.
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command.
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ZoomMap
   -- SOURCE
   function Zoom_Map_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Zoom_Map_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
   begin
      Game_Settings.Map_Font_Size :=
        (if CArgv.Arg(Argv, 1) = "raise" then Game_Settings.Map_Font_Size + 1
         else Game_Settings.Map_Font_Size - 1);
      if Game_Settings.Map_Font_Size < 3 then
         Game_Settings.Map_Font_Size := 3;
      elsif Game_Settings.Map_Font_Size > 50 then
         Game_Settings.Map_Font_Size := 50;
      end if;
      Tcl_Eval
        (Interp,
         "font configure MapFont -size" &
         Positive'Image(Game_Settings.Map_Font_Size));
      return Draw_Map_Command(ClientData, Interp, Argc, Argv);
   end Zoom_Map_Command;

   -- ****o* MapCommands/MapCommands.Move_Command
   -- FUNCTION
   -- Move the player ship in the selected location and check what happens
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- MoveShip direction
   -- Direction in which the player's ship will be moved
   -- SOURCE
   function Move_Ship_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Move_Ship_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      Message: Unbounded_String;
      Result: Natural;
      StartsCombat: Boolean := False;
      NewX, NewY: Integer := 0;
      procedure Update_Coordinates is
      begin
         if Player_Ship.Destination_X > Player_Ship.Sky_X then
            NewX := 1;
         elsif Player_Ship.Destination_X < Player_Ship.Sky_X then
            NewX := -1;
         end if;
         if Player_Ship.Destination_Y > Player_Ship.Sky_Y then
            NewY := 1;
         elsif Player_Ship.Destination_Y < Player_Ship.Sky_Y then
            NewY := -1;
         end if;
      end Update_Coordinates;
   begin
      if CArgv.Arg(Argv, 1) = "n" then -- Move up
         Result := MoveShip(0, -1, Message);
      elsif CArgv.Arg(Argv, 1) = "s" then -- Move down
         Result := MoveShip(0, 1, Message);
      elsif CArgv.Arg(Argv, 1) = "e" then -- Move right
         Result := MoveShip(1, 0, Message);
      elsif CArgv.Arg(Argv, 1) = "w" then -- Move left
         Result := MoveShip(-1, 0, Message);
      elsif CArgv.Arg(Argv, 1) = "sw" then -- Move down/left
         Result := MoveShip(-1, 1, Message);
      elsif CArgv.Arg(Argv, 1) = "se" then -- Move down/right
         Result := MoveShip(1, 1, Message);
      elsif CArgv.Arg(Argv, 1) = "nw" then -- Move up/left
         Result := MoveShip(-1, -1, Message);
      elsif CArgv.Arg(Argv, 1) = "ne" then -- Move up/right
         Result := MoveShip(1, -1, Message);
      elsif CArgv.Arg(Argv, 1) =
        "waitormove" then -- Move to destination or wait 1 game minute
         if Player_Ship.Destination_X = 0 and
           Player_Ship.Destination_Y = 0 then
            Result := 1;
            Update_Game(1);
            WaitInPlace(1);
         else
            Update_Coordinates;
            Result := MoveShip(NewX, NewY, Message);
            if Player_Ship.Destination_X = Player_Ship.Sky_X and
              Player_Ship.Destination_Y = Player_Ship.Sky_Y then
               Add_Message
                 ("You reached your travel destination.", ORDERMESSAGE);
               Player_Ship.Destination_X := 0;
               Player_Ship.Destination_Y := 0;
               if Game_Settings.Auto_Finish then
                  Message := To_Unbounded_String(Auto_Finish_Missions);
               end if;
               Result := 4;
            end if;
         end if;
      elsif CArgv.Arg(Argv, 1) = "moveto" then -- Move to destination
         Move_Loop :
         loop
            NewX := 0;
            NewY := 0;
            Update_Coordinates;
            Result := MoveShip(NewX, NewY, Message);
            exit Move_Loop when Result = 0;
            StartsCombat := Check_For_Event;
            if StartsCombat then
               Result := 4;
               exit Move_Loop;
            end if;
            if Result = 8 then
               Wait_For_Rest;
               if not Factions_List(Player_Ship.Crew(1).Faction).Flags.Contains
                   (To_Unbounded_String("sentientships"))
                 and then
                 (Find_Member(PILOT) = 0 or Find_Member(ENGINEER) = 0) then
                  Wait_For_Rest;
               end if;
               Result := 1;
               StartsCombat := Check_For_Event;
               if StartsCombat then
                  Result := 4;
                  exit Move_Loop;
               end if;
            end if;
            if Game_Settings.Auto_Move_Stop /= NEVER and
              Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Event_Index >
                0 then
               declare
                  EventIndex: constant Positive :=
                    Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Event_Index;
               begin
                  case Game_Settings.Auto_Move_Stop is
                     when ANY =>
                        if Events_List(EventIndex).E_Type in ENEMYSHIP |
                              TRADER | FRIENDLYSHIP | ENEMYPATROL then
                           Result := 0;
                           exit Move_Loop;
                        end if;
                     when FRIENDLY =>
                        if Events_List(EventIndex).E_Type in TRADER |
                              FRIENDLYSHIP then
                           Result := 0;
                           exit Move_Loop;
                        end if;
                     when Config.ENEMY =>
                        if Events_List(EventIndex).E_Type in ENEMYSHIP |
                              ENEMYPATROL then
                           Result := 0;
                           exit Move_Loop;
                        end if;
                     when NEVER =>
                        null;
                  end case;
               end;
            end if;
            declare
               MessageDialog: constant Ttk_Frame :=
                 Get_Widget(".message", Interp);
            begin
               if Winfo_Get(MessageDialog, "exists") = "0" then
                  if GetItemAmount(Fuel_Type) <= Game_Settings.Low_Fuel then
                     Show_Message
                       (Text => "Your fuel level is dangerously low.",
                        Title => "Low fuel level");
                     Result := 4;
                     exit Move_Loop;
                  elsif GetItemsAmount("Food") <= Game_Settings.Low_Food then
                     Show_Message
                       (Text => "Your food level is dangerously low.",
                        Title => "Low amount of food");
                     Result := 4;
                     exit Move_Loop;
                  elsif GetItemsAmount("Drinks") <=
                    Game_Settings.Low_Drinks then
                     Show_Message
                       (Text => "Your drinks level is dangerously low.",
                        Title => "Low level of drinks");
                     Result := 4;
                     exit Move_Loop;
                  end if;
               end if;
            end;
            if Player_Ship.Destination_X = Player_Ship.Sky_X and
              Player_Ship.Destination_Y = Player_Ship.Sky_Y then
               Add_Message
                 ("You reached your travel destination.", ORDERMESSAGE);
               Player_Ship.Destination_X := 0;
               Player_Ship.Destination_Y := 0;
               if Game_Settings.Auto_Finish then
                  Message := To_Unbounded_String(Auto_Finish_Missions);
               end if;
               Result := 4;
               exit Move_Loop;
            end if;
            exit Move_Loop when Result = 6 or Result = 7;
         end loop Move_Loop;
      end if;
      case Result is
         when 1 => -- Ship moved, check for events
            StartsCombat := Check_For_Event;
            if not StartsCombat and Game_Settings.Auto_Finish then
               Message := To_Unbounded_String(Auto_Finish_Missions);
            end if;
         when 6 => -- Ship moved, but pilot needs rest, confirm
            Show_Question
              ("You don't have pilot on duty. Do you want to wait until your pilot rest?",
               "nopilot");
            return TCL_OK;
         when 7 => -- Ship moved, but engineer needs rest, confirm
            Show_Question
              ("You don't have engineer on duty. Do you want to wait until your engineer rest?",
               "nopilot");
            return TCL_OK;
         when 8 => -- Ship moved, but crew needs rest, autorest
            StartsCombat := Check_For_Event;
            if not StartsCombat then
               Wait_For_Rest;
               if not Factions_List(Player_Ship.Crew(1).Faction).Flags.Contains
                   (To_Unbounded_String("sentientships"))
                 and then
                 (Find_Member(PILOT) = 0 or Find_Member(ENGINEER) = 0) then
                  Wait_For_Rest;
               end if;
               StartsCombat := Check_For_Event;
            end if;
            if not StartsCombat and Game_Settings.Auto_Finish then
               Message := To_Unbounded_String(Auto_Finish_Missions);
            end if;
         when others =>
            null;
      end case;
      if Message /= Null_Unbounded_String then
         Show_Message(Text => To_String(Message), Title => "Message");
      end if;
      Center_X := Player_Ship.Sky_X;
      Center_Y := Player_Ship.Sky_Y;
      if StartsCombat then
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
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed. Unused
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- QuitGame
   -- SOURCE
   function Quit_Game_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Quit_Game_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Interp, Argc, Argv);
   begin
      Show_Question("Are you sure want to quit?", "quit");
      return TCL_OK;
   end Quit_Game_Command;

   -- ****o* MapCommands/MapCommands.Resign_Game_Command
   -- FUNCTION
   -- Resing from the game - if player resigned, kill he/she character and
   -- follow as for death of the player's character
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed. Unused
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ResignGame
   -- SOURCE
   function Resign_Game_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Resign_Game_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Interp, Argc, Argv);
   begin
      Show_Question("Are you sure want to resign from game?", "resign");
      return TCL_OK;
   end Resign_Game_Command;

   -- ****o* MapCommands/MapCommands.Show_Stats_Command
   -- FUNCTION
   -- Show the player's game statistics
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed. Unused
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowStats
   -- SOURCE
   function Show_Stats_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Stats_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Interp, Argc, Argv);
   begin
      Tcl.Tk.Ada.Grid.Grid(Close_Button, "-row 0 -column 1");
      ShowStatistics;
      return TCL_OK;
   end Show_Stats_Command;

   -- ****o* MapCommands/MapCommands.Show_Sky_Map_Command
   -- FUNCTION
   -- Show sky map
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed. Unused
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowSkyMap ?previouscommand?
   -- Previouscommand is command to show previous screen. Some screens require
   -- to do special actions when closing them
   -- SOURCE
   function Show_Sky_Map_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Sky_Map_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData);
   begin
      if Argc = 1 then
         Tcl.Tk.Ada.Grid.Grid_Remove(Close_Button);
         Show_Sky_Map(True);
      else
         Tcl_Eval(Interp, CArgv.Arg(Argv, 1));
      end if;
      Focus(Get_Main_Window(Interp));
      return TCL_OK;
   end Show_Sky_Map_Command;

   -- ****o* MapCommands/MapCommands.Move_Mouse_Command
   -- FUNCTION
   -- Move mouse cursor with keyboard
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- MoveCursor direction
   -- Direction is the direction in which the mouse cursor should be moves or
   -- click if emulate clicking with the left or right button
   -- SOURCE
   function Move_Mouse_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Move_Mouse_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      MapView: constant Tk_Text :=
        Get_Widget(Main_Paned & ".mapframe.map", Interp);
   begin
      if Focus /= Widget_Image(MapView) then
         Focus(MapView, "-force");
         return TCL_OK;
      end if;
      if CArgv.Arg(Argv, 1) = "click" then
         Generate
           (MapView,
            "<Button-" & (if Game_Settings.Right_Button then "3" else "1") &
            ">",
            "-x " & CArgv.Arg(Argv, 2) & " -y " & CArgv.Arg(Argv, 3));
      elsif CArgv.Arg(Argv, 1) = "nw" then
         Generate
           (MapView, "<Motion>",
            "-warp 1 -x [expr " & CArgv.Arg(Argv, 2) & "-5] -y [expr " &
            CArgv.Arg(Argv, 3) & "-5]");
      elsif CArgv.Arg(Argv, 1) = "n" then
         Generate
           (MapView, "<Motion>",
            "-warp 1 -x " & CArgv.Arg(Argv, 2) & " -y [expr " &
            CArgv.Arg(Argv, 3) & "-5]");
      elsif CArgv.Arg(Argv, 1) = "ne" then
         Generate
           (MapView, "<Motion>",
            "-warp 1 -x [expr " & CArgv.Arg(Argv, 2) & "+5] -y [expr " &
            CArgv.Arg(Argv, 3) & "-5]");
      elsif CArgv.Arg(Argv, 1) = "w" then
         Generate
           (MapView, "<Motion>",
            "-warp 1 -x [expr " & CArgv.Arg(Argv, 2) & "-5] -y " &
            CArgv.Arg(Argv, 3));
      elsif CArgv.Arg(Argv, 1) = "e" then
         Generate
           (MapView, "<Motion>",
            "-warp 1 -x [expr " & CArgv.Arg(Argv, 2) & "+5] -y " &
            CArgv.Arg(Argv, 3));
      elsif CArgv.Arg(Argv, 1) = "sw" then
         Generate
           (MapView, "<Motion>",
            "-warp 1 -x [expr " & CArgv.Arg(Argv, 2) & "-5] -y [expr " &
            CArgv.Arg(Argv, 3) & "+5]");
      elsif CArgv.Arg(Argv, 1) = "s" then
         Generate
           (MapView, "<Motion>",
            "-warp 1 -x " & CArgv.Arg(Argv, 2) & " -y [expr " &
            CArgv.Arg(Argv, 3) & "+5]");
      elsif CArgv.Arg(Argv, 1) = "se" then
         Generate
           (MapView, "<Motion>",
            "-warp 1 -x [expr " & CArgv.Arg(Argv, 2) & "+5] -y [expr " &
            CArgv.Arg(Argv, 3) & "+5]");
      end if;
      return TCL_OK;
   end Move_Mouse_Command;

   -- ****o* MapCommands/MapCommands.Toggle_Full_Screen_Command
   -- FUNCTION
   -- Toggle the game full screen mode
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ToggleFullScreen
   -- SOURCE
   function Toggle_Full_Screen_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Toggle_Full_Screen_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
   begin
      Tcl_Eval(Interp, "wm attributes . -fullscreen");
      if Tcl_GetResult(Interp) = "0" then
         Wm_Set(Get_Main_Window(Interp), "attributes", "-fullscreen 1");
         Game_Settings.Full_Screen := True;
      else
         Wm_Set(Get_Main_Window(Interp), "attributes", "-fullscreen 0");
         Game_Settings.Full_Screen := False;
      end if;
      return TCL_OK;
   end Toggle_Full_Screen_Command;

   -- ****o* MapCommands/MapCommands.Resize_Last_Messages_Command
   -- FUNCTION
   -- Resize the last messages window
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ResizeLastMessages
   -- SOURCE
   function Resize_Last_Messages_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Resize_Last_Messages_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
      PanedPosition: Positive;
      SashPosition: constant Natural :=
        Natural'Value(SashPos(Main_Paned, "0"));
   begin
      Game_Settings.Window_Width :=
        Positive'Value(Winfo_Get(Get_Main_Window(Interp), "width"));
      Game_Settings.Window_Height :=
        Positive'Value(Winfo_Get(Get_Main_Window(Interp), "height"));
      PanedPosition :=
        (if Game_Settings.Window_Height - Game_Settings.Messages_Position < 0
         then Game_Settings.Window_Height
         else Game_Settings.Window_Height - Game_Settings.Messages_Position);
      if SashPosition > 0 and then SashPosition /= PanedPosition then
         if Game_Settings.Window_Height - SashPosition > -1 then
            Game_Settings.Messages_Position :=
              Game_Settings.Window_Height - SashPosition;
         end if;
         PanedPosition := SashPosition;
      end if;
      return TCL_OK;
   end Resize_Last_Messages_Command;

   -- ****o* MapCommands/MapCommands.Show_Game_Menu_Command
   -- FUNCTION
   -- Show the main menu of the game
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowGameMenu
   -- SOURCE
   function Show_Game_Menu_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Game_Menu_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
      Row: Positive := 1;
      State: constant String := Tcl_GetVar(Interp, "gamestate");
      type Menu_Shortcut is record
         ButtonName: Unbounded_String;
         Shortcut: Unbounded_String;
      end record;
      package Shortcuts_Container is new Vectors
        (Index_Type => Positive, Element_Type => Menu_Shortcut);
      Shortcuts: Shortcuts_Container.Vector;
      GameMenu: Ttk_Frame := Get_Widget(pathName => ".gameframe.gamemenu");
      procedure Add_Button
        (Name, Label, Command: String; Shortcut: Unbounded_String;
         Last: Boolean := False) is
         Button: constant Ttk_Button :=
           Create
             (GameMenu & Name,
              "-text {" & Label & " [" & To_String(Shortcut) &
              "]} -command {CloseDialog " & GameMenu & ";" & Command & "}");
      begin
         if not Last then
            Tcl.Tk.Ada.Grid.Grid(Button, "-sticky we -padx 5");
         else
            Bind
              (Button, "<Tab>",
               "{focus " & To_String(Shortcuts.First_Element.ButtonName) &
               ";break}");
            Tcl.Tk.Ada.Grid.Grid(Button, "-sticky we -padx 5 -pady {0 3}");
            Focus(Button);
         end if;
         Shortcuts.Append((To_Unbounded_String(GameMenu & Name), Shortcut));
         Row := Row + 1;
      end Add_Button;
   begin
      if Winfo_Get(GameMenu, "exists") = "1" then
         Tcl_Eval(Interp, "CloseDialog " & GameMenu);
         return TCL_OK;
      end if;
      GameMenu :=
        Create_Dialog(Name => ".gameframe.gamemenu", Title => "Game menu");
      Add_Button
        (".shipinfo", "Ship information", "ShowShipInfo",
         Menu_Accelerators(1));
      if State not in "combat" | "dead" then
         Add_Button
           (".shiporders", "Ship orders", "ShowOrders", Menu_Accelerators(2));
      end if;
      if State /= "dead" then
         Add_Button
           (".crafting", "Crafting", "ShowCrafting", Menu_Accelerators(3));
      end if;
      Add_Button
        (".messages", "Last messages", "ShowLastMessages",
         Menu_Accelerators(4));
      Add_Button
        (".knowledge", "Knowledge lists", "ShowKnowledge",
         Menu_Accelerators(5));
      if State not in "combat" | "dead" then
         Add_Button(".wait", "Wait orders", "ShowWait", Menu_Accelerators(6));
      end if;
      Add_Button
        (".stats", "Game statistics", "ShowStats", Menu_Accelerators(7));
      if State /= "dead" then
         Add_Button
           (".help", "Help", "ShowHelp " & State, Menu_Accelerators(8));
         Add_Button
           (".options", "Game options", "ShowOptions", Menu_Accelerators(9));
         Add_Button
           (".quit", "Quit from game", "QuitGame", Menu_Accelerators(10));
         Add_Button
           (".resign", "Resign from game", "ResignGame",
            Menu_Accelerators(11));
      end if;
      Add_Button
        (".close", "Close", "CloseDialog " & GameMenu,
         To_Unbounded_String("Escape"), True);
      declare
         MenuButton: Ttk_Button;
      begin
         for Button of Shortcuts loop
            MenuButton := Get_Widget(To_String(Button.ButtonName));
            for Shortcut of Shortcuts loop
               Bind
                 (MenuButton,
                  "<KeyPress-" & To_String(Shortcut.Shortcut) & ">",
                  "{" & To_String(Shortcut.ButtonName) & " invoke;break}");
            end loop;
            Bind
              (MenuButton, "<KeyPress-" & To_String(Map_Accelerators(1)) & ">",
               "{ShowGameMenu;break}");
         end loop;
      end;
      Show_Dialog(Dialog => GameMenu, Relative_X => 0.4, Relative_Y => 0.1);
      return TCL_OK;
   end Show_Game_Menu_Command;

   -- ****o* MapCommands/MapCommands.Invoke_Menu_Command
   -- FUNCTION
   -- Invoke the selected game menu option with the selected keyboard shortcut
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- InvokeMenu shortcut
   -- Shortcut, the keyboard shortcut which was pressed
   -- SOURCE
   function Invoke_Menu_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Invoke_Menu_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      Focused_Widget: constant Ttk_Frame := Get_Widget(Focus(Interp), Interp);
      Commands: constant array(Menu_Accelerators'Range) of Unbounded_String :=
        (To_Unbounded_String("ShowShipInfo"),
         To_Unbounded_String("ShowOrders"),
         To_Unbounded_String("ShowCrafting"),
         To_Unbounded_String("ShowLastMessages"),
         To_Unbounded_String("ShowKnowledge"), To_Unbounded_String("ShowWait"),
         To_Unbounded_String("ShowStats"), To_Unbounded_String("ShowHelp"),
         To_Unbounded_String("ShowOptions"), To_Unbounded_String("QuitGame"),
         To_Unbounded_String("ResignGame"));
   begin
      if Winfo_Get(Focused_Widget, "class") = "TEntry" or
        Tcl.Tk.Ada.Busy.Status(Game_Header) = "1" then
         return TCL_OK;
      end if;
      for I in Menu_Accelerators'Range loop
         if To_String(Menu_Accelerators(I)) = CArgv.Arg(Argv, 1) then
            Tcl_Eval(Interp, To_String(Commands(I)));
            return TCL_OK;
         end if;
      end loop;
      return TCL_OK;
   end Invoke_Menu_Command;

   procedure AddCommands is
   begin
      Add_Command("HideMapButtons", Hide_Map_Buttons_Command'Access);
      Add_Command("ShowMapButtons", Show_Map_Buttons_Command'Access);
      Add_Command("MoveMapButtons", Move_Map_Buttons_Command'Access);
      Add_Command("DrawMap", Draw_Map_Command'Access);
      Add_Command("UpdateMapInfo", Update_Map_Info_Command'Access);
      Add_Command("MoveMapInfo", Move_Map_Info_Command'Access);
      Add_Command("ShowDestinationMenu", Show_Destination_Menu_Command'Access);
      Add_Command("SetDestination", Set_Ship_Destination_Command'Access);
      Add_Command("MoveMap", Move_Map_Command'Access);
      Add_Command("ZoomMap", Zoom_Map_Command'Access);
      Add_Command("MoveShip", Move_Ship_Command'Access);
      Add_Command("QuitGame", Quit_Game_Command'Access);
      Add_Command("ResignGame", Resign_Game_Command'Access);
      Add_Command("ShowStats", Show_Stats_Command'Access);
      Add_Command("ShowSkyMap", Show_Sky_Map_Command'Access);
      Add_Command("MoveCursor", Move_Mouse_Command'Access);
      Add_Command("ToggleFullScreen", Toggle_Full_Screen_Command'Access);
      Add_Command("ResizeLastMessages", Resize_Last_Messages_Command'Access);
      Add_Command("ShowGameMenu", Show_Game_Menu_Command'Access);
      Add_Command("InvokeMenu", Invoke_Menu_Command'Access);
   end AddCommands;

end Maps.UI.Commands;
