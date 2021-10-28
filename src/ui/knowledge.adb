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

with Ada.Containers; use Ada.Containers;
with Ada.Strings; use Ada.Strings;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with GNAT.String_Split; use GNAT.String_Split;
with Tcl.Ada; use Tcl.Ada;
with Tcl.Tk.Ada; use Tcl.Tk.Ada;
with Tcl.Tk.Ada.Event; use Tcl.Tk.Ada.Event;
with Tcl.Tk.Ada.Grid;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.Canvas; use Tcl.Tk.Ada.Widgets.Canvas;
with Tcl.Tk.Ada.Widgets.Text; use Tcl.Tk.Ada.Widgets.Text;
with Tcl.Tk.Ada.Widgets.TtkButton; use Tcl.Tk.Ada.Widgets.TtkButton;
with Tcl.Tk.Ada.Widgets.TtkEntry.TtkComboBox;
use Tcl.Tk.Ada.Widgets.TtkEntry.TtkComboBox;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Tcl.Tk.Ada.Widgets.TtkLabel; use Tcl.Tk.Ada.Widgets.TtkLabel;
with Tcl.Tk.Ada.Winfo; use Tcl.Tk.Ada.Winfo;
with BasesTypes; use BasesTypes;
with CoreUI; use CoreUI;
with Factions; use Factions;
with Game; use Game;
with Knowledge.Bases;
with Knowledge.Events;
with Knowledge.Missions;
with Stories; use Stories;
with Knowledge.Stories;
with Utils.UI; use Utils.UI;

package body Knowledge is

   function Show_Knowledge_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argv);
      KnowledgeFrame: Ttk_Frame := Get_Widget(Main_Paned & ".knowledgeframe");
      Tokens: Slice_Set;
      Rows: Natural := 0;
      KnowledgeCanvas: Tk_Canvas :=
        Get_Widget(KnowledgeFrame & ".bases.canvas", Interp);
      ComboBox: Ttk_ComboBox :=
        Get_Widget(KnowledgeCanvas & ".frame.options.types");
      ComboValues: Unbounded_String;
      Label: Ttk_Label;
      Button: Ttk_Button;
   begin
      if Winfo_Get(KnowledgeFrame, "exists") = "0" then
         Tcl_EvalFile
           (Get_Context,
            To_String(Data_Directory) & "ui" & Dir_Separator &
            "knowledge.tcl");
         Append(ComboValues, " {Any}");
         Load_Bases_Types_Loop :
         for BaseType of Bases_Types_List loop
            Append(ComboValues, " {" & BaseType.Name & "}");
         end loop Load_Bases_Types_Loop;
         configure(ComboBox, "-values [list" & To_String(ComboValues) & "]");
         Current(ComboBox, "0");
         ComboValues := To_Unbounded_String(" {Any}");
         ComboBox.Name := New_String(KnowledgeCanvas & ".frame.options.owner");
         Load_Bases_Owners_Loop :
         for I in Factions_List.Iterate loop
            Append(ComboValues, " {" & Factions_List(I).Name & "}");
         end loop Load_Bases_Owners_Loop;
         configure(ComboBox, "-values [list" & To_String(ComboValues) & "]");
         Current(ComboBox, "0");
      elsif Winfo_Get(KnowledgeFrame, "ismapped") = "1" and Argc = 1 then
         Tcl_Eval(Interp, "InvokeButton " & Close_Button);
         Tcl.Tk.Ada.Grid.Grid_Remove(Close_Button);
         return TCL_OK;
      end if;
      Tcl.Tk.Ada.Grid.Grid(Close_Button, "-row 0 -column 1");
      -- Setting bases list
      Knowledge.Bases.UpdateBasesList;
      -- Setting accepted missions info
      Knowledge.Missions.UpdateMissionsList;
      -- Setting the known events list
      Knowledge.Events.UpdateEventsList;
      -- Setting the known stories list
      KnowledgeFrame.Name :=
        New_String(Main_Paned & ".knowledgeframe.stories.canvas.frame");
      Create(Tokens, Tcl.Tk.Ada.Grid.Grid_Size(KnowledgeFrame), " ");
      Rows := Natural'Value(Slice(Tokens, 2));
      Delete_Widgets(1, Rows - 1, KnowledgeFrame);
      if FinishedStories.Length = 0 then
         Label :=
           Create
             (KnowledgeFrame & ".nostories",
              "-text {You didn't discover any story yet.} -wraplength 400");
         Tcl.Tk.Ada.Grid.Grid(Label, "-padx 10");
      else
         declare
            OptionsFrame: constant Ttk_Frame :=
              Create(KnowledgeFrame & ".options");
            StoriesBox: constant Ttk_ComboBox :=
              Create(OptionsFrame & ".titles", "-state readonly");
            StoriesList: Unbounded_String;
            StoriesView: constant Tk_Text :=
              Create(KnowledgeFrame & ".view", "-wrap word");
         begin
            Load_Finished_Stories_Loop :
            for FinishedStory of FinishedStories loop
               Append
                 (StoriesList,
                  " {" & Stories_List(FinishedStory.Index).Name & "}");
            end loop Load_Finished_Stories_Loop;
            configure
              (StoriesBox, "-values [list " & To_String(StoriesList) & "]");
            Bind(StoriesBox, "<<ComboboxSelected>>", "ShowStory");
            Current
              (StoriesBox, Natural'Image(Natural(FinishedStories.Length) - 1));
            Tcl.Tk.Ada.Grid.Grid(StoriesBox);
            Button :=
              Create
                (OptionsFrame & ".show",
                 "-text {Show on map} -command ShowStoryLocation");
            Tcl.Tk.Ada.Grid.Grid(Button, "-column 1 -row 0");
            Button :=
              Create
                (OptionsFrame & ".set",
                 "-text {Set as destintion for ship} -command SetStory");
            Tcl.Tk.Ada.Grid.Grid(Button, "-column 2 -row 0");
            Tcl.Tk.Ada.Grid.Grid(OptionsFrame, "-sticky w");
            Tcl.Tk.Ada.Grid.Grid(StoriesView, "-sticky w");
            Generate(StoriesBox, "<<ComboboxSelected>>");
         end;
      end if;
      Tcl_Eval(Get_Context, "update");
      KnowledgeCanvas.Name :=
        New_String(Main_Paned & ".knowledgeframe.stories.canvas");
      configure
        (KnowledgeCanvas,
         "-scrollregion [list " & BBox(KnowledgeCanvas, "all") & "]");
      Xview_Move_To(KnowledgeCanvas, "0.0");
      Yview_Move_To(KnowledgeCanvas, "0.0");
      -- Show knowledge
      Show_Screen("knowledgeframe");
      return TCL_OK;
   end Show_Knowledge_Command;

   -- ****o* Knowledge/Knowledge.Knowledge_Max_Min_Command
   -- FUNCTION
   -- Maximize or minimize the selected section of knowledge info
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- KnowledgeMaxMin framename
   -- Framename is name of the frame to maximize or minimize
   -- SOURCE
   function Knowledge_Max_Min_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Knowledge_Max_Min_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      type Frame_Info is record
         Name: Unbounded_String;
         Column: Natural range 0 .. 1;
         Row: Natural range 0 .. 1;
      end record;
      Frames: constant array(1 .. 4) of Frame_Info :=
        ((To_Unbounded_String("bases"), 0, 0),
         (To_Unbounded_String("missions"), 0, 1),
         (To_Unbounded_String("events"), 1, 0),
         (To_Unbounded_String("stories"), 1, 1));
      FrameName: constant String := Main_Paned & ".knowledgeframe";
      Frame: Ttk_Frame := Get_Widget(FrameName, Interp);
      Button: constant Ttk_Button :=
        Get_Widget
          (FrameName & "." & CArgv.Arg(Argv, 1) & ".canvas.frame.maxmin",
           Interp);
   begin
      if CArgv.Arg(Argv, 2) /= "show" then
         Hide_Manipulate_Frames_Loop :
         for FrameInfo of Frames loop
            Frame.Name :=
              New_String(FrameName & "." & To_String(FrameInfo.Name));
            if To_String(FrameInfo.Name) /= CArgv.Arg(Argv, 1) then
               Tcl.Tk.Ada.Grid.Grid(Frame);
            else
               Tcl.Tk.Ada.Grid.Grid_Configure
                 (Frame,
                  "-columnspan 1 -rowspan 1 -column" &
                  Natural'Image(FrameInfo.Column) & " -row" &
                  Natural'Image(FrameInfo.Row));
            end if;
         end loop Hide_Manipulate_Frames_Loop;
         configure
           (Button,
            "-text ""[format %c 0xf106]"" -command {KnowledgeMaxMin " &
            CArgv.Arg(Argv, 1) & " show}");
      else
         Show_Manipulate_Frames_Loop :
         for FrameInfo of Frames loop
            Frame.Name :=
              New_String(FrameName & "." & To_String(FrameInfo.Name));
            if To_String(FrameInfo.Name) /= CArgv.Arg(Argv, 1) then
               Tcl.Tk.Ada.Grid.Grid_Remove(Frame);
            else
               Tcl.Tk.Ada.Grid.Grid_Configure
                 (Frame, "-columnspan 2 -rowspan 2 -row 0 -column 0");
            end if;
         end loop Show_Manipulate_Frames_Loop;
         configure
           (Button,
            "-text ""[format %c 0xf107]"" -command {KnowledgeMaxMin " &
            CArgv.Arg(Argv, 1) & " hide}");
      end if;
      return TCL_OK;
   end Knowledge_Max_Min_Command;

   procedure AddCommands is
   begin
      Add_Command("ShowKnowledge", Show_Knowledge_Command'Access);
      Add_Command("KnowledgeMaxMin", Knowledge_Max_Min_Command'Access);
      Knowledge.Bases.AddCommands;
      Knowledge.Events.AddCommands;
      Knowledge.Missions.AddCommands;
      Knowledge.Stories.AddCommands;
   end AddCommands;

end Knowledge;
