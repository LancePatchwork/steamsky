-- Copyright (c) 2020-2021 Bartek thindil Jasicki <thindil@laeran.pl>
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

with Ada.Characters.Latin_1;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Interfaces.C;
with GNAT.Directory_Operations;
with GNAT.OS_Lib;
with GNAT.Time_Stamp;
with GNAT.Traceback.Symbolic;
with Tcl;
with Tcl.Ada;
with Tcl.Tk.Ada;
with Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.Toplevel;
with Tcl.Tk.Ada.Widgets.Toplevel.MainWindow;
with Tcl.Tk.Ada.Widgets.Text;
with Game;
with Game.SaveLoad;
with Log;
with MainMenu.Commands;
with Ships;
with Utils.UI;

package body ErrorDialog is

   procedure Save_Exception(An_Exception: Exception_Occurrence) is
      use Ada.Characters.Latin_1;
      use Ada.Strings.Unbounded;
      use Ada.Text_IO;
      use GNAT.OS_Lib;
      use GNAT.Time_Stamp;
      use GNAT.Traceback.Symbolic;
      use Game;
      use Game.SaveLoad;
      use Log;
      use Ships;

      Error_File: File_Type;
      Error_Text: Unbounded_String := Null_Unbounded_String;
   begin
      if Natural(Player_Ship.Crew.Length) > 0 then
         Save_Game;
      end if;
      Append
        (Source => Error_Text,
         New_Item =>
           Current_Time & LF & Game_Version & LF & "Exception: " &
           Exception_Name(X => An_Exception) & LF & "Message: " &
           Exception_Message(X => An_Exception) & LF &
           "-------------------------------------------------" & LF);
      if Directory_Separator = '/' then
         Append
           (Source => Error_Text,
            New_Item => Symbolic_Traceback(E => An_Exception) & LF);
      else
         Append
           (Source => Error_Text,
            New_Item => Exception_Information(X => An_Exception) & LF);
      end if;
      Append
        (Source => Error_Text,
         New_Item => "-------------------------------------------------");
      Open_Error_File_Block :
      begin
         Open
           (File => Error_File, Mode => Append_File,
            Name => To_String(Source => Save_Directory) & "error.log");
      exception
         when Name_Error =>
            Create
              (File => Error_File, Mode => Append_File,
               Name => To_String(Source => Save_Directory) & "error.log");
      end Open_Error_File_Block;
      Put_Line(File => Error_File, Item => To_String(Source => Error_Text));
      Close(File => Error_File);
      End_Logging;
      Show_Error_Dialog_Block :
      declare
         use type Interfaces.C.int;
         use GNAT.Directory_Operations;
         use Tcl;
         use Tcl.Ada;
         use Tcl.Tk.Ada;
         use Tcl.Tk.Ada.Widgets;
         use MainMenu.Commands;
         use Utils.UI;

         Interp: Tcl.Tcl_Interp := Get_Context;
      begin
         Destroy_Main_Window_Block :
         declare
            use Tcl.Tk.Ada.Widgets.Toplevel;
            use Tcl.Tk.Ada.Widgets.Toplevel.MainWindow;

            Main_Window: Tk_Toplevel := Get_Main_Window(Interp => Interp);
         begin
            Destroy(Widgt => Main_Window);
         exception
            when Storage_Error =>
               null;
         end Destroy_Main_Window_Block;
         Interp := Tcl.Tcl_CreateInterp;
         if Tcl.Tcl_Init(interp => Interp) = Tcl.TCL_ERROR then
            Ada.Text_IO.Put_Line
              (Item =>
                 "Steam Sky: Tcl.Tcl_Init failed: " &
                 Tcl.Ada.Tcl_GetStringResult(interp => Interp));
            return;
         end if;
         if Tcl.Tk.Tk_Init(interp => Interp) = Tcl.TCL_ERROR then
            Ada.Text_IO.Put_Line
              (Item =>
                 "Steam Sky: Tcl.Tk.Tk_Init failed: " &
                 Tcl.Ada.Tcl_GetStringResult(interp => Interp));
            return;
         end if;
         Set_Context(Interp => Interp);
         Tcl_EvalFile
           (interp => Get_Context,
            fileName =>
              To_String(Source => Data_Directory) & "ui" & Dir_Separator &
              "errordialog.tcl");
         Add_Command
           (Name => "OpenLink", Ada_Command => Open_Link_Command'Access);
         Show_Error_Message_Block :
         declare
            use Tcl.Tk.Ada.Widgets.Text;

            Text_View: constant Tk_Text :=
              Get_Widget(pathName => ".technical.text", Interp => Interp);
         begin
            Insert
              (TextWidget => Text_View, Index => "end",
               Text => "{" & To_String(Source => Error_Text) & "}");
            configure(Widgt => Text_View, options => "-state disabled");
         end Show_Error_Message_Block;
         Tcl.Tk.Tk_MainLoop;
      end Show_Error_Dialog_Block;
   end Save_Exception;

end ErrorDialog;
