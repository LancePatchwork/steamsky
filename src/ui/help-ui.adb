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
with Interfaces.C; use Interfaces.C;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with CArgv;
with Tcl; use Tcl;
with Tcl.Ada; use Tcl.Ada;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.Text; use Tcl.Tk.Ada.Widgets.Text;
with Tcl.Tk.Ada.Widgets.Toplevel; use Tcl.Tk.Ada.Widgets.Toplevel;
with Tcl.Tk.Ada.Widgets.TtkPanedWindow; use Tcl.Tk.Ada.Widgets.TtkPanedWindow;
with Tcl.Tk.Ada.Widgets.TtkTreeView; use Tcl.Tk.Ada.Widgets.TtkTreeView;
with Tcl.Tk.Ada.Winfo; use Tcl.Tk.Ada.Winfo;
with Tcl.Tk.Ada.Wm; use Tcl.Tk.Ada.Wm;
with BasesTypes; use BasesTypes;
with Config; use Config;
with Dialogs; use Dialogs;
with Factions; use Factions;
with Game; use Game;
with Items; use Items;
with Maps.UI; use Maps.UI;
with Themes; use Themes;
with Utils.UI; use Utils.UI;

package body Help.UI is

   -- ****o* HUI/HUI.Show_Topic_Command
   -- FUNCTION
   -- Show the content of the selected topic help
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowTopic
   -- SOURCE
   function Show_Topic_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Topic_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
      use Tiny_String;

      NewText, TagText: Unbounded_String;
      StartIndex, EndIndex, OldIndex: Natural;
      type Variables_Data is record
         Name: Unbounded_String;
         Value: Unbounded_String;
      end record;
      Variables: constant array(1 .. 11) of Variables_Data :=
        (1 => (Name => To_Unbounded_String("MoneyName"), Value => Money_Name),
         2 =>
           (Name => To_Unbounded_String("FuelName"),
            Value =>
              To_Unbounded_String
                (Source =>
                   To_String
                     (Source =>
                        Objects_Container.Element
                          (Container => Items_List,
                           Index => Find_Proto_Item(Item_Type => Fuel_Type))
                          .Name))),
         3 =>
           (Name => To_Unbounded_String("StrengthName"),
            Value =>
              To_Unbounded_String
                (To_String
                   (AttributesData_Container.Element
                      (Attributes_List, Strength_Index)
                      .Name))),
         4 =>
           (Name => To_Unbounded_String("PilotingSkill"),
            Value =>
              To_Unbounded_String
                (To_String
                   (SkillsData_Container.Element(Skills_List, Piloting_Skill)
                      .Name))),
         5 =>
           (Name => To_Unbounded_String("EngineeringSkill"),
            Value =>
              To_Unbounded_String
                (To_String
                   (SkillsData_Container.Element
                      (Skills_List, Engineering_Skill)
                      .Name))),
         6 =>
           (Name => To_Unbounded_String("GunnerySkill"),
            Value =>
              To_Unbounded_String
                (To_String
                   (SkillsData_Container.Element(Skills_List, Gunnery_Skill)
                      .Name))),
         7 =>
           (Name => To_Unbounded_String("TalkingSkill"),
            Value =>
              To_Unbounded_String
                (To_String
                   (SkillsData_Container.Element(Skills_List, Talking_Skill)
                      .Name))),
         8 =>
           (Name => To_Unbounded_String("PerceptionSkill"),
            Value =>
              To_Unbounded_String
                (To_String
                   (SkillsData_Container.Element(Skills_List, Perception_Skill)
                      .Name))),
         9 =>
           (Name => To_Unbounded_String("ConditionName"),
            Value =>
              To_Unbounded_String
                (To_String
                   (AttributesData_Container.Element
                      (Attributes_List, Condition_Index)
                      .Name))),
         10 =>
           (Name => To_Unbounded_String("DodgeSkill"),
            Value =>
              To_Unbounded_String
                (To_String
                   (SkillsData_Container.Element(Skills_List, Dodge_Skill)
                      .Name))),
         11 =>
           (Name => To_Unbounded_String("UnarmedSkill"),
            Value =>
              To_Unbounded_String
                (To_String
                   (SkillsData_Container.Element(Skills_List, Unarmed_Skill)
                      .Name))));
      AccelNames: constant array(1 .. 25) of Unbounded_String :=
        (Map_Accelerators(5), Map_Accelerators(6), Map_Accelerators(7),
         Map_Accelerators(8), Map_Accelerators(9), Map_Accelerators(10),
         Map_Accelerators(11), Map_Accelerators(12), Map_Accelerators(13),
         Map_Accelerators(14), Menu_Accelerators(1), Menu_Accelerators(2),
         Menu_Accelerators(3), Menu_Accelerators(4), Menu_Accelerators(5),
         Menu_Accelerators(6), Map_Accelerators(2), Menu_Accelerators(7),
         Menu_Accelerators(9), Menu_Accelerators(10), Menu_Accelerators(11),
         Map_Accelerators(1), Menu_Accelerators(8), Map_Accelerators(3),
         Map_Accelerators(4));
      type FontTag is record
         Tag: String(1 .. 1);
         TextTag: Unbounded_String;
      end record;
      FontTags: constant array(1 .. 3) of FontTag :=
        (1 => (Tag => "b", TextTag => To_Unbounded_String("bold")),
         2 => (Tag => "u", TextTag => To_Unbounded_String("underline")),
         3 => (Tag => "i", TextTag => To_Unbounded_String("italic")));
      FlagsTags: constant array(1 .. 8) of Unbounded_String :=
        (To_Unbounded_String("diseaseimmune"),
         To_Unbounded_String("nofatigue"), To_Unbounded_String("nomorale"),
         To_Unbounded_String("naturalarmor"),
         To_Unbounded_String("toxicattack"),
         To_Unbounded_String("sentientships"),
         To_Unbounded_String("fanaticism"), To_Unbounded_String("loner"));
      FactionsWithFlag: Unbounded_String;
      BasesFlags: constant array(1 .. 4) of Unbounded_String :=
        (To_Unbounded_String("shipyard"), To_Unbounded_String("temple"),
         To_Unbounded_String("blackmarket"), To_Unbounded_String("barracks"));
      BasesWithFlag: Unbounded_String;
      TopicsView: constant Ttk_Tree_View :=
        Get_Widget(".help.paned.topics.view", Interp);
      HelpView: constant Tk_Text :=
        Get_Widget(".help.paned.content.view", Interp);
   begin
      configure(HelpView, "-state normal");
      Delete(HelpView, "1.0", "end");
      Find_Help_Text_Loop :
      for Help of Help_List loop
         if Help.Index = To_Unbounded_String(Selection(TopicsView)) then
            NewText := Help.Text;
            exit Find_Help_Text_Loop;
         end if;
      end loop Find_Help_Text_Loop;
      OldIndex := 1;
      Replace_Help_Text_Loop :
      loop
         StartIndex := Index(NewText, "{", OldIndex);
         if StartIndex > 0 then
            Insert
              (HelpView, "end",
               "{" & Slice(NewText, OldIndex, StartIndex - 1) & "}");
         else
            Insert
              (HelpView, "end",
               "{" & Slice(NewText, OldIndex, Length(NewText)) & "}");
            exit Replace_Help_Text_Loop;
         end if;
         EndIndex := Index(NewText, "}", StartIndex) - 1;
         TagText := Unbounded_Slice(NewText, StartIndex + 1, EndIndex);
         Insert_Variables_Loop :
         for I in Variables'Range loop
            if TagText = Variables(I).Name then
               Insert
                 (HelpView, "end",
                  "{" & To_String(Variables(I).Value) & "} [list special]");
               exit Insert_Variables_Loop;
            end if;
         end loop Insert_Variables_Loop;
         Insert_Keys_Loop :
         for I in AccelNames'Range loop
            if TagText =
              To_Unbounded_String("GameKey") &
                To_Unbounded_String(Positive'Image(I)) then
               Insert
                 (HelpView, "end",
                  "{'" & To_String(AccelNames(I)) & "'} [list special]");
               exit Insert_Keys_Loop;
            end if;
         end loop Insert_Keys_Loop;
         Insert_Tags_Loop :
         for I in FontTags'Range loop
            if TagText = To_Unbounded_String(FontTags(I).Tag) then
               StartIndex := Index(NewText, "{", EndIndex) - 1;
               Insert
                 (HelpView, "end",
                  "{" & Slice(NewText, EndIndex + 2, StartIndex) & "} [list " &
                  To_String(FontTags(I).TextTag) & "]");
               EndIndex := Index(NewText, "}", StartIndex) - 1;
               exit Insert_Tags_Loop;
            end if;
         end loop Insert_Tags_Loop;
         Insert_Factions_Flags_Loop :
         for I in FlagsTags'Range loop
            if TagText = FlagsTags(I) then
               FactionsWithFlag := Null_Unbounded_String;
               Create_Factions_List_Loop :
               for Faction of Factions_List loop
                  if Faction.Flags.Contains(TagText) then
                     if FactionsWithFlag /= Null_Unbounded_String then
                        Append(FactionsWithFlag, " and ");
                     end if;
                     Append
                       (FactionsWithFlag, To_String(Source => Faction.Name));
                  end if;
               end loop Create_Factions_List_Loop;
               Insert_Factions_Loop :
               while Ada.Strings.Unbounded.Count(FactionsWithFlag, " and ") >
                 1 loop
                  Replace_Slice
                    (FactionsWithFlag, Index(FactionsWithFlag, " and "),
                     Index(FactionsWithFlag, " and ") + 4, ", ");
               end loop Insert_Factions_Loop;
               Insert
                 (HelpView, "end", "{" & To_String(FactionsWithFlag) & "}");
               exit Insert_Factions_Flags_Loop;
            end if;
         end loop Insert_Factions_Flags_Loop;
         Insert_Bases_Flags_Loop :
         for BaseFlag of BasesFlags loop
            if TagText /= BaseFlag then
               goto Bases_Flags_Loop_End;
            end if;
            BasesWithFlag := Null_Unbounded_String;
            Create_Bases_List_Loop :
            for BaseType of Bases_Types_List loop
               if BaseType.Flags.Contains(TagText) then
                  if BasesWithFlag /= Null_Unbounded_String then
                     Append(BasesWithFlag, " and ");
                  end if;
                  Append(BasesWithFlag, BaseType.Name);
               end if;
            end loop Create_Bases_List_Loop;
            Insert_Bases_Loop :
            while Ada.Strings.Unbounded.Count(BasesWithFlag, " and ") > 1 loop
               Replace_Slice
                 (BasesWithFlag, Index(BasesWithFlag, " and "),
                  Index(BasesWithFlag, " and ") + 4, ", ");
            end loop Insert_Bases_Loop;
            Insert(HelpView, "end", "{" & To_String(BasesWithFlag) & "}");
            exit Insert_Bases_Flags_Loop;
            <<Bases_Flags_Loop_End>>
         end loop Insert_Bases_Flags_Loop;
         OldIndex := EndIndex + 2;
      end loop Replace_Help_Text_Loop;
      configure(HelpView, "-state disabled");
      return TCL_OK;
   end Show_Topic_Command;

   -- ****o* HUI/HUI.Close_Help_Command
   -- FUNCTION
   -- Destroy help window and save sash position to the game configuration
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- CloseHelp
   -- SOURCE
   function Close_Help_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Close_Help_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
      HelpWindow: Tk_Toplevel := Get_Widget(".help", Interp);
      Paned: constant Ttk_PanedWindow :=
        Get_Widget(HelpWindow & ".paned", Interp);
   begin
      Game_Settings.Topics_Position := Natural'Value(SashPos(Paned, "0"));
      Destroy(HelpWindow);
      return TCL_OK;
   end Close_Help_Command;

   -- ****o* HUI/HUI.Show_Help_Command
   -- FUNCTION
   -- Show help window to the player
   -- PARAMETERS
   -- ClientData - Custom data send to the command.
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command.
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowHelp topicindex
   -- Topicindex is the index of the help topic which content will be show
   -- SOURCE
   function Show_Help_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Help_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      HelpWindow: constant Tk_Toplevel := Get_Widget(".help", Interp);
      X, Y: Integer;
      Paned: constant Ttk_PanedWindow :=
        Get_Widget(HelpWindow & ".paned", Interp);
      TopicsView: constant Ttk_Tree_View :=
        Get_Widget(Paned & ".topics.view", Interp);
      TopicIndex: constant String :=
        (if Argc = 1 then Tcl_GetVar(Interp, "gamestate")
         else CArgv.Arg(Argv, 1));
      HelpView: constant Tk_Text :=
        Get_Widget(Paned & ".content.view", Interp);
      Current_Theme: constant Theme_Record :=
        Themes_List(To_String(Source => Game_Settings.Interface_Theme));
   begin
      if Winfo_Get(HelpWindow, "exists") = "1" then
         return Close_Help_Command(ClientData, Interp, Argc, Argv);
      end if;
      Tcl_EvalFile
        (Interp,
         To_String(Data_Directory) & "ui" & Dir_Separator & "help.tcl");
      Tag_Configure
        (HelpView, "special",
         "-foreground {" &
         To_String(Source => Current_Theme.Special_Help_Color) &
         "} -font BoldHelpFont");
      Tag_Configure
        (HelpView, "underline",
         "-foreground {" &
         To_String(Source => Current_Theme.Underline_Help_Color) &
         "} -font UnderlineHelpFont");
      Tag_Configure
        (HelpView, "bold",
         "-foreground {" & To_String(Source => Current_Theme.Bold_Help_Color) &
         "} -font BoldHelpFont");
      Tag_Configure
        (HelpView, "italic",
         "-foreground {" &
         To_String(Source => Current_Theme.Italic_Help_Color) &
         "} -font ItalicHelpFont");
      X :=
        (Positive'Value(Winfo_Get(HelpWindow, "vrootwidth")) -
         Game_Settings.Window_Width) /
        2;
      if X < 0 then
         X := 0;
      end if;
      Y :=
        (Positive'Value(Winfo_Get(HelpWindow, "vrootheight")) -
         Game_Settings.Window_Height) /
        2;
      if Y < 0 then
         Y := 0;
      end if;
      Wm_Set
        (HelpWindow, "geometry",
         Trim(Positive'Image(Game_Settings.Window_Width), Left) & "x" &
         Trim(Positive'Image(Game_Settings.Window_Height), Left) & "+" &
         Trim(Positive'Image(X), Left) & "+" & Trim(Positive'Image(Y), Left));
      Tcl_Eval(Interp, "update");
      SashPos(Paned, "0", Natural'Image(Game_Settings.Topics_Position));
      for I in Help_List.Iterate loop
         Insert
           (TopicsView,
            "{} end -id {" & To_String(Help_List(I).Index) & "} -text {" &
            To_String(Help_Container.Key(I)) & "}");
      end loop;
      Bind(TopicsView, "<<TreeviewSelect>>", "ShowTopic");
      if Exists(TopicsView, TopicIndex) = "0" then
         Show_Message
           ("The selected help topic doesn't exist. Showing the first available instead.",
            ".help", "Can't find help topic");
         Selection_Set(TopicsView, To_String(Help_List.First_Element.Index));
         return TCL_OK;
      end if;
      Selection_Set(TopicsView, TopicIndex);
      Tcl_Eval(Interp, "update");
      See(TopicsView, TopicIndex);
      return TCL_OK;
   end Show_Help_Command;

   procedure Add_Commands is
   begin
      Add_Command("ShowTopic", Show_Topic_Command'Access);
      Add_Command("ShowHelp", Show_Help_Command'Access);
      Add_Command("CloseHelp", Close_Help_Command'Access);
   end Add_Commands;

end Help.UI;
