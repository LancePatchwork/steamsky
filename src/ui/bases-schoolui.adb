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

with Interfaces.C; use Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with CArgv;
with Tcl; use Tcl;
with Tcl.Ada; use Tcl.Ada;
with Tcl.Tk.Ada; use Tcl.Tk.Ada;
with Tcl.Tk.Ada.Grid;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.Canvas; use Tcl.Tk.Ada.Widgets.Canvas;
with Tcl.Tk.Ada.Widgets.Menu; use Tcl.Tk.Ada.Widgets.Menu;
with Tcl.Tk.Ada.Widgets.TtkButton; use Tcl.Tk.Ada.Widgets.TtkButton;
with Tcl.Tk.Ada.Widgets.TtkEntry.TtkComboBox;
use Tcl.Tk.Ada.Widgets.TtkEntry.TtkComboBox;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Tcl.Tk.Ada.Widgets.TtkLabel; use Tcl.Tk.Ada.Widgets.TtkLabel;
with Tcl.Tk.Ada.Widgets.TtkPanedWindow; use Tcl.Tk.Ada.Widgets.TtkPanedWindow;
with Tcl.Tk.Ada.Widgets.TtkTreeView; use Tcl.Tk.Ada.Widgets.TtkTreeView;
with Tcl.Tk.Ada.Winfo; use Tcl.Tk.Ada.Winfo;
with Bases.Trade; use Bases.Trade;
with CoreUI; use CoreUI;
with Dialogs; use Dialogs;
with Maps.UI; use Maps.UI;
with Trades; use Trades;
with Utils.UI; use Utils.UI;

package body Bases.SchoolUI is

   -- ****o* SchoolUI/Set_School_Skills_Command
   -- FUNCTION
   -- Set list of available to train skills for the selected crew member
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- SetSchoolSkills
   -- SOURCE
   function Set_School_Skills_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Set_School_Skills_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
      FrameName: constant String :=
        Main_Paned & ".schoolframe.canvas.school.setting";
      ComboBox: Ttk_ComboBox := Get_Widget(FrameName & ".crew", Interp);
      MemberIndex: constant Positive := Natural'Value(Current(ComboBox)) + 1;
      ComboList: Unbounded_String;
   begin
      ComboBox := Get_Widget(FrameName & ".skill");
      Add_Skills_Loop :
      for I in Skills_List.Iterate loop
         for Skill of Player_Ship.Crew(MemberIndex).Skills loop
            if Skill(1) = SkillsData_Container.To_Index(I)
              and then Skill(2) = 100 then
               goto End_Of_Add_Skills_Loop;
            end if;
         end loop;
         Append(ComboList, " " & Skills_List(I).Name);
         <<End_Of_Add_Skills_Loop>>
      end loop Add_Skills_Loop;
      configure(ComboBox, "-values [list" & To_String(ComboList) & "]");
      Current(ComboBox, "0");
      return TCL_OK;
   end Set_School_Skills_Command;

   -- ****o* SchoolUI/SchoolUI.Show_School_Command
   -- FUNCTION
   -- Show the selected base school
   -- PARAMETERS
   -- ClientData - Custom data send to the command.
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command.
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowSchool
   -- SOURCE
   function Show_School_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_School_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      SchoolFrame: Ttk_Frame :=
        Get_Widget(Main_Paned & ".schoolframe", Interp);
      SchoolCanvas: constant Tk_Canvas :=
        Get_Widget(SchoolFrame & ".canvas", Interp);
      CrewView: Ttk_Tree_View;
      ComboBox: constant Ttk_ComboBox :=
        Get_Widget(SchoolCanvas & ".school.setting.crew", Interp);
      ComboList: Unbounded_String := Null_Unbounded_String;
   begin
      if Winfo_Get(SchoolCanvas, "exists") = "0" then
         Tcl_EvalFile
           (Get_Context,
            To_String(Data_Directory) & "ui" & Dir_Separator & "school.tcl");
         Bind(SchoolFrame, "<Configure>", "{ResizeCanvas %W.canvas %w %h}");
      elsif Winfo_Get(SchoolCanvas, "ismapped") = "1" and Argc = 1 then
         Tcl.Tk.Ada.Grid.Grid_Remove(Close_Button);
         Entry_Configure(GameMenu, "Help", "-command {ShowHelp general}");
         ShowSkyMap(True);
         return TCL_OK;
      end if;
      Entry_Configure(GameMenu, "Help", "-command {ShowHelp crew}");
      SchoolFrame.Name := New_String(SchoolCanvas & ".school");
      Add_Crew_Loop :
      for Member of Player_Ship.Crew loop
         Append(ComboList, " " & Member.Name);
      end loop Add_Crew_Loop;
      configure(ComboBox, "-values [list" & To_String(ComboList) & "]");
      Current(ComboBox, "0");
      if Set_School_Skills_Command(ClientData, Interp, Argc, Argv) /=
        TCL_OK then
         return TCL_ERROR;
      end if;
      CrewView := Get_Widget(SchoolFrame & ".crew.view", Interp);
      Delete(CrewView, "[list " & Children(CrewView, "{}") & "]");
      Load_Crew_Loop :
      for I in Player_Ship.Crew.Iterate loop
         Insert
           (CrewView,
            "{} end -id" & Positive'Image(Crew_Container.To_Index(I)) &
            " -text {" & To_String(Player_Ship.Crew(I).Name) & "}");
      end loop Load_Crew_Loop;
      Selection_Set(CrewView, "[list 1]");
      Tcl.Tk.Ada.Grid.Grid(Close_Button, "-row 0 -column 1");
      configure
        (SchoolCanvas,
         "-height [expr " & SashPos(Main_Paned, "0") & " - 20] -width " &
         cget(Main_Paned, "-width"));
      Tcl_Eval(Get_Context, "update");
      Canvas_Create
        (SchoolCanvas, "window", "0 0 -anchor nw -window " & SchoolFrame);
      Tcl_Eval(Get_Context, "update");
      configure
        (SchoolCanvas,
         "-scrollregion [list " & BBox(SchoolCanvas, "all") & "]");
      ShowScreen("schoolframe");
      return TCL_OK;
   end Show_School_Command;

      -- ****iv* SchoolUI/SchoolUI.MemberIndex
      -- FUNCTION
      -- The currently selected crew member index
      -- SOURCE
   MemberIndex: Positive;
   -- ****

   -- ****o* SchoolUI/SchoolUI.Show_Training_Info_Command
   -- FUNCTION
   -- Show training costs for the selected crew member
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowTrainingInfo
   -- SOURCE
   function Show_Training_Info_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Training_Info_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
      FrameName: constant String := Main_Paned & ".schoolframe.canvas.school";
      CrewView: constant Ttk_Tree_View :=
        Get_Widget(FrameName & ".crew.view", Interp);
      SkillsView: constant Ttk_Tree_View :=
        Get_Widget(FrameName & ".skills.view", Interp);
      Cost, MoneyIndex2, FirstIndex: Natural := 0;
      MoneyLabel: constant Ttk_Label :=
        Get_Widget(FrameName & ".skills.money", Interp);
      TrainButton: constant Ttk_Button :=
        Get_Widget(FrameName & ".skills.train", Interp);
   begin
      MemberIndex := Positive'Value(Selection(CrewView));
      Delete(SkillsView, "[list " & Children(SkillsView, "{}") & "]");
      Load_Skills_List_Loop :
      for I in Skills_List.Iterate loop
         Cost := TrainCost(MemberIndex, SkillsData_Container.To_Index(I));
         if Cost > 0 then
            if FirstIndex = 0 then
               FirstIndex := SkillsData_Container.To_Index(I);
            end if;
            Insert
              (SkillsView,
               "{} end -id" &
               Positive'Image(SkillsData_Container.To_Index(I)) &
               " -values [list {" & To_String(Skills_List(I).Name) & "}" &
               Natural'Image(Cost) & "]");
         end if;
      end loop Load_Skills_List_Loop;
      MoneyIndex2 := FindItem(Player_Ship.Cargo, Money_Index);
      if MoneyIndex2 > 0 then
         configure
           (MoneyLabel,
            "-text {You have" &
            Natural'Image(Player_Ship.Cargo(MoneyIndex2).Amount) & " " &
            To_String(Money_Name) & ".}");
      else
         configure
           (MoneyLabel,
            "-text {You don't have any " & To_String(Money_Name) &
            " to pay for learning.}");
      end if;
      if Children(SkillsView, "{}") /= "{}" then
         Selection_Set(SkillsView, "[list" & Positive'Image(FirstIndex) & "]");
         configure(TrainButton, "-state normal");
      else
         configure(TrainButton, "-state disabled");
      end if;
      return TCL_OK;
   end Show_Training_Info_Command;

   -- ****o* SchoolUI/SchoolUI.Train_Skill_Command
   -- FUNCTION
   -- Train the selected skill
   -- PARAMETERS
   -- ClientData - Custom data send to the command.
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command.
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- TrainSkill
   -- SOURCE
   function Train_Skill_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Train_Skill_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      SkillsView: constant Ttk_Tree_View :=
        Get_Widget
          (Main_Paned & ".schoolframe.canvas.school.skills.view", Interp);
      SkillIndex: Positive;
   begin
      SkillIndex := Positive'Value(Selection(SkillsView));
      TrainSkill(MemberIndex, SkillIndex);
      UpdateMessages;
      return Show_Training_Info_Command(ClientData, Interp, Argc, Argv);
   exception
      when Trade_No_Money =>
         ShowMessage
           (Text =>
              "You don't have any " & To_String(Money_Name) &
              " to pay for learning.",
            Title => "Can't train");
         return TCL_OK;
      when Trade_Not_Enough_Money =>
         ShowMessage
           (Text =>
              "You don't have enough " & To_String(Money_Name) &
              " to pay for learning this skill.",
            Title => "Can't train");
         return TCL_OK;
      when Trade_Cant_Train =>
         ShowMessage
           (Text => "You can't train this skill any more.",
            Title => "Can't train");
         return TCL_OK;
   end Train_Skill_Command;

   procedure AddCommands is
   begin
      AddCommand("ShowSchool", Show_School_Command'Access);
      AddCommand("ShowTrainingInfo", Show_Training_Info_Command'Access);
      AddCommand("TrainSkill", Train_Skill_Command'Access);
      AddCommand("SetSchoolSkills", Set_School_Skills_Command'Access);
   end AddCommands;

end Bases.SchoolUI;
