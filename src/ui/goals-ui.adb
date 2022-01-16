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

with Ada.Strings; use Ada.Strings;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Interfaces.C;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with CArgv;
with Tcl; use Tcl;
with Tcl.Ada; use Tcl.Ada;
with Tcl.Tk.Ada; use Tcl.Tk.Ada;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.TtkButton; use Tcl.Tk.Ada.Widgets.TtkButton;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Tcl.Tk.Ada.Widgets.TtkLabel; use Tcl.Tk.Ada.Widgets.TtkLabel;
with Tcl.Tk.Ada.Widgets.TtkTreeView; use Tcl.Tk.Ada.Widgets.TtkTreeView;
with Tcl.Tklib.Ada.Tooltip; use Tcl.Tklib.Ada.Tooltip;
with Config; use Config;
with Game; use Game;
with Utils; use Utils;
with Utils.UI; use Utils.UI;

package body Goals.UI is

   -- ****o* GUI/GUI.Show_Goals_Command
   -- FUNCTION
   -- Show goals UI to the player
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowGoals buttonpath
   -- Buttonpath is path to the button which is used to set the goal
   -- SOURCE
   function Show_Goals_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Goals_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc);
      Goals_Dialog: constant Ttk_Frame :=
        Get_Widget(pathName => ".goalsdialog", Interp => Interp);
      Goals_View: constant Ttk_Tree_View :=
        Get_Widget(pathName => Goals_Dialog & ".view", Interp => Interp);
      Select_Button: constant Ttk_Button :=
        Get_Widget
          (pathName => Goals_Dialog & ".selectbutton", Interp => Interp);
      Dialog_Header: constant Ttk_Label :=
        Get_Widget(pathName => Goals_Dialog & ".header", Interp => Interp);
   begin
      Tcl_EvalFile
        (interp => Interp,
         fileName =>
           To_String(Source => Data_Directory) & "ui" & Dir_Separator &
           "goals.tcl");
      Load_Goals_Loop :
      for I in Goals_List.Iterate loop
         Insert
           (TreeViewWidget => Goals_View,
            Options =>
              Goal_Types'Image(Goals_List(I).G_Type) & " end -id {" &
              Trim
                (Source =>
                   Positive'Image(Goals_Container.To_Index(Position => I)),
                 Side => Left) &
              "} -text {" &
              Goal_Text(Index => Goals_Container.To_Index(Position => I)) &
              "}");
      end loop Load_Goals_Loop;
      configure
        (Widgt => Select_Button,
         options =>
           "-command {SetGoal " & CArgv.Arg(Argv => Argv, N => 1) & "}");
      Bind
        (Widgt => Dialog_Header,
         Sequence =>
           "<ButtonPress-" &
           (if Game_Settings.Right_Button then "3" else "1") & ">",
         Script => "{SetMousePosition " & Dialog_Header & " %X %Y}");
      Bind
        (Widgt => Dialog_Header, Sequence => "<Motion>",
         Script => "{MoveDialog " & Goals_Dialog & " %X %Y}");
      Bind
        (Widgt => Dialog_Header,
         Sequence =>
           "<ButtonRelease-" &
           (if Game_Settings.Right_Button then "3" else "1") & ">",
         Script => "{SetMousePosition " & Dialog_Header & " 0 0}");
      return TCL_OK;
   end Show_Goals_Command;

   -- ****o* GUI/GUI.Set_Goal_Command
   -- FUNCTION
   -- Set selected goal as a current goal
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- SetGoal buttonpath
   -- Buttonpath is path to the button which is used to set the goal
   -- SOURCE
   function Set_Goal_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Set_Goal_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc);
      Goals_View: constant Ttk_Tree_View :=
        Get_Widget(pathName => ".goalsdialog.view", Interp => Interp);
      Selected_Goal: Natural;
      Button_Name: constant String := CArgv.Arg(Argv => Argv, N => 1);
      Goal_Button: constant Ttk_Button :=
        Get_Widget(pathName => Button_Name, Interp => Interp);
      Button_Text: Unbounded_String;
   begin
      Selected_Goal := Natural'Value(Selection(TreeViewWidget => Goals_View));
      Clear_Current_Goal;
      if Selected_Goal > 0 then
         Current_Goal := Goals_List(Selected_Goal);
      elsif Index(Source => Button_Name, Pattern => "newgamemenu") = 0 then
         Current_Goal :=
           Goals_List
             (Get_Random
                (Min => Goals_List.First_Index, Max => Goals_List.Last_Index));
      end if;
      if Selected_Goal > 0 then
         Button_Text :=
           To_Unbounded_String(Source => Goal_Text(Index => Selected_Goal));
         Add
           (Widget => Goal_Button,
            Message => To_String(Source => Button_Text));
         if Length(Source => Button_Text) > 16 then
            Button_Text :=
              Unbounded_Slice(Source => Button_Text, Low => 1, High => 17) &
              "...";
         end if;
         configure
           (Widgt => Goal_Button,
            options => "-text {" & To_String(Source => Button_Text) & "}");
      else
         configure(Widgt => Goal_Button, options => "-text {Random}");
      end if;
      Tcl_Eval(interp => Interp, strng => ".goalsdialog.closebutton invoke");
      return TCL_OK;
   end Set_Goal_Command;

   procedure Add_Commands is
   begin
      Add_Command
        (Name => "ShowGoals", Ada_Command => Show_Goals_Command'Access);
      Add_Command(Name => "SetGoal", Ada_Command => Set_Goal_Command'Access);
   end Add_Commands;

end Goals.UI;
