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

with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Characters.Latin_1; use Ada.Characters.Latin_1;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Interfaces.C; use Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with CArgv; use CArgv;
with Tcl; use Tcl;
with Tcl.Ada; use Tcl.Ada;
with Tcl.Tk.Ada; use Tcl.Tk.Ada;
with Tcl.Tk.Ada.Grid;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.Canvas; use Tcl.Tk.Ada.Widgets.Canvas;
with Tcl.Tk.Ada.Widgets.Text; use Tcl.Tk.Ada.Widgets.Text;
with Tcl.Tk.Ada.Widgets.TtkEntry; use Tcl.Tk.Ada.Widgets.TtkEntry;
with Tcl.Tk.Ada.Widgets.TtkEntry.TtkComboBox;
use Tcl.Tk.Ada.Widgets.TtkEntry.TtkComboBox;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Tcl.Tk.Ada.Widgets.TtkPanedWindow; use Tcl.Tk.Ada.Widgets.TtkPanedWindow;
with Tcl.Tk.Ada.Winfo; use Tcl.Tk.Ada.Winfo;
with Config; use Config;
with CoreUI; use CoreUI;
with Dialogs; use Dialogs;
with Utils.UI; use Utils.UI;

package body Messages.UI is

   -- ****if* MUI2/MUI2.ShowMessage
   -- FUNCTION
   -- Show the selected message to a player
   -- PARAMETERS
   -- Message      - The message to show
   -- MessagesView - The treeview in which the message will be shown
   -- MessagesType - The selected type of messages to show
   -- SOURCE
   procedure ShowMessage
     (Message: Message_Data; MessagesView: Tk_Text;
      MessagesType: Message_Type) is
      -- ****
      MessageTag: constant String :=
        (if Message.Color /= WHITE then
           " [list " & To_Lower(Message_Color'Image(Message.Color)) & "]"
         else "");
   begin
      if Message.M_Type /= MessagesType and MessagesType /= DEFAULT then
         return;
      end if;
      Insert
        (MessagesView, "end",
         "{" & To_String(Message.Message) & LF & "}" & MessageTag);
   end ShowMessage;

   -- ****o* MUI2/MUI2.Show_Last_Messages_Command
   -- FUNCTION
   -- Show the list of last messages to a player
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command.
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowLastMessages messagestype
   -- MessagesType is the type of messages to show, default all
   -- SOURCE
   function Show_Last_Messages_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Last_Messages_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData);
      MessagesFrame: Ttk_Frame :=
        Get_Widget(Main_Paned & ".messagesframe", Interp);
      MessagesCanvas: constant Tk_Canvas :=
        Get_Widget(MessagesFrame & ".canvas", Interp);
      MessagesType: constant Message_Type :=
        (if Argc = 1 then DEFAULT
         else Message_Type'Val(Natural'Value(CArgv.Arg(Argv, 1))));
      MessagesView: constant Tk_Text :=
        Get_Widget(MessagesCanvas & ".messages.list.view", Interp);
      TypeBox: constant Ttk_ComboBox :=
        Get_Widget(MessagesCanvas & ".messages.options.types", Interp);
      SearchEntry: constant Ttk_Entry :=
        Get_Widget(MessagesCanvas & ".messages.options.search", Interp);
   begin
      if Winfo_Get(MessagesCanvas, "exists") = "0" then
         Tcl_EvalFile
           (Get_Context,
            To_String(Data_Directory) & "ui" & Dir_Separator & "messages.tcl");
         Bind(MessagesFrame, "<Configure>", "{ResizeCanvas %W.canvas %w %h}");
      elsif Winfo_Get(MessagesCanvas, "ismapped") = "1" and Argc = 1 then
         Tcl_Eval(Interp, "InvokeButton " & Close_Button);
         Tcl.Tk.Ada.Grid.Grid_Remove(Close_Button);
         return TCL_OK;
      end if;
      if Argc = 1 then
         Current(TypeBox, "0");
      end if;
      Delete(SearchEntry, "0", "end");
      configure(MessagesView, "-state normal");
      Delete(MessagesView, "1.0", "end");
      if Messages_Amount(MessagesType) = 0 then
         Insert(MessagesView, "end", "{There are no messages of that type.}");
      else
         if Game_Settings.Messages_Order = OLDER_FIRST then
            Show_Older_First_Loop :
            for Message of Messages_List loop
               ShowMessage(Message, MessagesView, MessagesType);
            end loop Show_Older_First_Loop;
         else
            Show_Newer_First_Loop :
            for Message of reverse Messages_List loop
               ShowMessage(Message, MessagesView, MessagesType);
            end loop Show_Newer_First_Loop;
         end if;
      end if;
      configure(MessagesView, "-state disabled");
      Tcl.Tk.Ada.Grid.Grid(Close_Button, "-row 0 -column 1");
      MessagesFrame.Name :=
        New_String(Widget_Image(MessagesCanvas) & ".messages");
      configure
        (MessagesCanvas,
         "-height [expr " & SashPos(Main_Paned, "0") & " - 20] -width " &
         cget(Main_Paned, "-width"));
      Tcl_Eval(Get_Context, "update");
      Canvas_Create
        (MessagesCanvas, "window",
         "0 0 -anchor nw -window " & Widget_Image(MessagesFrame));
      Tcl_Eval(Get_Context, "update");
      configure
        (MessagesCanvas,
         "-scrollregion [list " & BBox(MessagesCanvas, "all") & "]");
      Show_Screen("messagesframe");
      return TCL_OK;
   end Show_Last_Messages_Command;

   -- ****o* MUI2/MUI2.Select_Messages_Command
   -- FUNCTION
   -- Show only messages of the selected type
   -- PARAMETERS
   -- ClientData - Custom data send to the command.
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- SelectMessages
   -- SOURCE
   function Select_Messages_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Select_Messages_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Argc);
      TypeBox: constant Ttk_ComboBox :=
        Get_Widget
          (Main_Paned & ".messagesframe.canvas.messages.options.types",
           Interp);
   begin
      return
        Show_Last_Messages_Command
          (ClientData, Interp, 2, Argv & Current(TypeBox));
   end Select_Messages_Command;

   -- ****o* MUI2/MUI2.Delete_Messages_Command
   -- FUNCTION
   -- Delete all messages
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed. Unused
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- DeleteMessages
   -- SOURCE
   function Delete_Messages_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Delete_Messages_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Interp, Argc, Argv);
   begin
      Show_Question
        ("Are you sure you want to clear all messages?", "messages");
      return TCL_OK;
   end Delete_Messages_Command;

   -- ****o* MUI2/MUI2.Search_Messages_Command
   -- FUNCTION
   -- Show only this messages which contains the selected sequence
   -- PARAMETERS
   -- ClientData - Custom data send to the command.
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- SearchMessages text
   -- Text is the string to search in the messages
   -- SOURCE
   function Search_Messages_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Search_Messages_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      FrameName: constant String :=
        Main_Paned & ".messagesframe.canvas.messages";
      TypeBox: constant Ttk_ComboBox :=
        Get_Widget(FrameName & ".options.types", Interp);
      MessagesType: Message_Type;
      MessagesView: constant Tk_Text :=
        Get_Widget(FrameName & ".list.view", Interp);
      SearchText: constant String := CArgv.Arg(Argv, 1);
   begin
      MessagesType := Message_Type'Val(Natural'Value(Current(TypeBox)));
      configure(MessagesView, "-state normal");
      Delete(MessagesView, "1.0", "end");
      if SearchText'Length = 0 then
         if Game_Settings.Messages_Order = OLDER_FIRST then
            Show_Older_First_Loop :
            for Message of Messages_List loop
               ShowMessage(Message, MessagesView, MessagesType);
            end loop Show_Older_First_Loop;
         else
            Show_Newer_First_Loop :
            for Message of reverse Messages_List loop
               ShowMessage(Message, MessagesView, MessagesType);
            end loop Show_Newer_First_Loop;
         end if;
         Tcl_SetResult(Interp, "1");
         return TCL_OK;
      end if;
      if Game_Settings.Messages_Order = OLDER_FIRST then
         Search_Older_First_Loop :
         for Message of Messages_List loop
            if Index
                (To_Lower(To_String(Message.Message)), To_Lower(SearchText),
                 1) >
              0 then
               ShowMessage(Message, MessagesView, MessagesType);
            end if;
         end loop Search_Older_First_Loop;
      else
         Search_Newer_First_Loop :
         for Message of reverse Messages_List loop
            if Index
                (To_Lower(To_String(Message.Message)), To_Lower(SearchText),
                 1) >
              0 then
               ShowMessage(Message, MessagesView, MessagesType);
            end if;
         end loop Search_Newer_First_Loop;
      end if;
      configure(MessagesView, "-state disable");
      Tcl_SetResult(Interp, "1");
      return TCL_OK;
   end Search_Messages_Command;

   procedure Add_Commands is
   begin
      Add_Command("ShowLastMessages", Show_Last_Messages_Command'Access);
      Add_Command("SelectMessages", Select_Messages_Command'Access);
      Add_Command("DeleteMessages", Delete_Messages_Command'Access);
      Add_Command("SearchMessages", Search_Messages_Command'Access);
   end Add_Commands;

end Messages.UI;
