-- Copyright (c) 2020-2024 Bartek thindil Jasicki
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
with Ada.Strings.Fixed;
with Interfaces.C; use Interfaces.C;
with GNAT.Directory_Operations;
with CArgv;
with Tcl; use Tcl;
with Tcl.Ada;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.Text; use Tcl.Tk.Ada.Widgets.Text;
with Tcl.Tk.Ada.Widgets.Toplevel; use Tcl.Tk.Ada.Widgets.Toplevel;
with Tcl.Tk.Ada.Widgets.TtkPanedWindow; use Tcl.Tk.Ada.Widgets.TtkPanedWindow;
with Tcl.Tk.Ada.Widgets.TtkTreeView; use Tcl.Tk.Ada.Widgets.TtkTreeView;
with Tcl.Tk.Ada.Winfo;
with Tcl.Tk.Ada.Wm;
with BasesTypes;
with Config; use Config;
with Dialogs;
with Factions;
with Game; use Game;
with Items;
with Maps.UI;
with Themes;
with Utils.UI;

package body Help.UI is

   -- ****o* HUI/HUI.Show_Topic_Command
   -- FUNCTION
   -- Show the content of the selected topic help
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowTopic
   -- SOURCE
   function Show_Topic_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Topic_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc, Argv);
      use BasesTypes;
      use Factions;
      use Items;
      use Maps.UI;
      use Tiny_String;

      New_Text, Tag_Text: Unbounded_String := Null_Unbounded_String;
      Start_Index, End_Index, Old_Index: Natural := 0;
      --## rule off TYPE_INITIAL_VALUES
      type Variables_Data is record
         Name: Unbounded_String;
         Value: Unbounded_String;
      end record;
      --## rule on TYPE_INITIAL_VALUES
      Variables: constant array(1 .. 11) of Variables_Data :=
        (1 =>
           (Name => To_Unbounded_String(Source => "MoneyName"),
            Value => Money_Name),
         2 =>
           (Name => To_Unbounded_String(Source => "FuelName"),
            Value =>
              To_Unbounded_String
                (Source =>
                   To_String
                     (Source =>
                        Get_Proto_Item
                          (Index => Find_Proto_Item(Item_Type => Fuel_Type))
                          .Name))),
         3 =>
           (Name => To_Unbounded_String(Source => "StrengthName"),
            Value =>
              To_Unbounded_String
                (Source =>
                   To_String
                     (Source =>
                        AttributesData_Container.Element
                          (Container => Attributes_List,
                           Index => Strength_Index)
                          .Name))),
         4 =>
           (Name => To_Unbounded_String(Source => "PilotingSkill"),
            Value =>
              To_Unbounded_String
                (Source =>
                   To_String
                     (Source =>
                        SkillsData_Container.Element
                          (Container => Skills_List, Index => Piloting_Skill)
                          .Name))),
         5 =>
           (Name => To_Unbounded_String(Source => "EngineeringSkill"),
            Value =>
              To_Unbounded_String
                (Source =>
                   To_String
                     (Source =>
                        SkillsData_Container.Element
                          (Container => Skills_List,
                           Index => Engineering_Skill)
                          .Name))),
         6 =>
           (Name => To_Unbounded_String(Source => "GunnerySkill"),
            Value =>
              To_Unbounded_String
                (Source =>
                   To_String
                     (Source =>
                        SkillsData_Container.Element
                          (Container => Skills_List, Index => Gunnery_Skill)
                          .Name))),
         7 =>
           (Name => To_Unbounded_String(Source => "TalkingSkill"),
            Value =>
              To_Unbounded_String
                (Source =>
                   To_String
                     (Source =>
                        SkillsData_Container.Element
                          (Container => Skills_List, Index => Talking_Skill)
                          .Name))),
         8 =>
           (Name => To_Unbounded_String(Source => "PerceptionSkill"),
            Value =>
              To_Unbounded_String
                (Source =>
                   To_String
                     (Source =>
                        SkillsData_Container.Element
                          (Container => Skills_List, Index => Perception_Skill)
                          .Name))),
         9 =>
           (Name => To_Unbounded_String(Source => "ConditionName"),
            Value =>
              To_Unbounded_String
                (Source =>
                   To_String
                     (Source =>
                        AttributesData_Container.Element
                          (Container => Attributes_List,
                           Index => Condition_Index)
                          .Name))),
         10 =>
           (Name => To_Unbounded_String(Source => "DodgeSkill"),
            Value =>
              To_Unbounded_String
                (Source =>
                   To_String
                     (Source =>
                        SkillsData_Container.Element
                          (Container => Skills_List, Index => Dodge_Skill)
                          .Name))),
         11 =>
           (Name => To_Unbounded_String(Source => "UnarmedSkill"),
            Value =>
              To_Unbounded_String
                (Source =>
                   To_String
                     (Source =>
                        SkillsData_Container.Element
                          (Container => Skills_List, Index => Unarmed_Skill)
                          .Name))));
      Accel_Names: constant array(1 .. 25) of Unbounded_String :=
        (1 => To_Unbounded_String(Source => Get_Map_Accelerator(Index => 5)),
         2 => To_Unbounded_String(Source => Get_Map_Accelerator(Index => 6)),
         3 => To_Unbounded_String(Source => Get_Map_Accelerator(Index => 7)),
         4 => To_Unbounded_String(Source => Get_Map_Accelerator(Index => 8)),
         5 => To_Unbounded_String(Source => Get_Map_Accelerator(Index => 9)),
         6 => To_Unbounded_String(Source => Get_Map_Accelerator(Index => 10)),
         7 => To_Unbounded_String(Source => Get_Map_Accelerator(Index => 11)),
         8 => To_Unbounded_String(Source => Get_Map_Accelerator(Index => 12)),
         9 => To_Unbounded_String(Source => Get_Map_Accelerator(Index => 13)),
         10 => To_Unbounded_String(Source => Get_Map_Accelerator(Index => 13)),
         11 => To_Unbounded_String(Source => Get_Menu_Accelerator(Index => 1)),
         12 => To_Unbounded_String(Source => Get_Menu_Accelerator(Index => 2)),
         13 => To_Unbounded_String(Source => Get_Menu_Accelerator(Index => 3)),
         14 => To_Unbounded_String(Source => Get_Menu_Accelerator(Index => 4)),
         15 => To_Unbounded_String(Source => Get_Menu_Accelerator(Index => 5)),
         16 => To_Unbounded_String(Source => Get_Menu_Accelerator(Index => 6)),
         17 => To_Unbounded_String(Source => Get_Map_Accelerator(Index => 2)),
         18 => To_Unbounded_String(Source => Get_Menu_Accelerator(Index => 7)),
         19 => To_Unbounded_String(Source => Get_Menu_Accelerator(Index => 9)),
         20 =>
           To_Unbounded_String(Source => Get_Menu_Accelerator(Index => 10)),
         21 =>
           To_Unbounded_String(Source => Get_Menu_Accelerator(Index => 11)),
         22 => To_Unbounded_String(Source => Get_Map_Accelerator(Index => 1)),
         23 => To_Unbounded_String(Source => Get_Menu_Accelerator(Index => 8)),
         24 => To_Unbounded_String(Source => Get_Map_Accelerator(Index => 3)),
         25 => To_Unbounded_String(Source => Get_Map_Accelerator(Index => 4)));
      --## rule off TYPE_INITIAL_VALUES
      type Font_Tag is record
         Tag: String(1 .. 1);
         Text_Tag: Unbounded_String;
      end record;
      --## rule on TYPE_INITIAL_VALUES
      Font_Tags: constant array(1 .. 3) of Font_Tag :=
        (1 => (Tag => "b", Text_Tag => To_Unbounded_String(Source => "bold")),
         2 =>
           (Tag => "u",
            Text_Tag => To_Unbounded_String(Source => "underline")),
         3 =>
           (Tag => "i", Text_Tag => To_Unbounded_String(Source => "italic")));
      Flags_Tags: constant array(1 .. 8) of Unbounded_String :=
        (1 => To_Unbounded_String(Source => "diseaseimmune"),
         2 => To_Unbounded_String(Source => "nofatigue"),
         3 => To_Unbounded_String(Source => "nomorale"),
         4 => To_Unbounded_String(Source => "naturalarmor"),
         5 => To_Unbounded_String(Source => "toxicattack"),
         6 => To_Unbounded_String(Source => "sentientships"),
         7 => To_Unbounded_String(Source => "fanaticism"),
         8 => To_Unbounded_String(Source => "loner"));
      Factions_With_Flag: Unbounded_String := Null_Unbounded_String;
      Bases_Flags: constant array(1 .. 4) of Unbounded_String :=
        (1 => To_Unbounded_String(Source => "shipyard"),
         2 => To_Unbounded_String(Source => "temple"),
         3 => To_Unbounded_String(Source => "blackmarket"),
         4 => To_Unbounded_String(Source => "barracks"));
      Bases_With_Flag, Help_Title: Unbounded_String := Null_Unbounded_String;
      Topics_View: constant Ttk_Tree_View :=
        Get_Widget(pathName => ".help.paned.topics.view", Interp => Interp);
      Help_View: constant Tk_Text :=
        Get_Widget(pathName => ".help.paned.content.view", Interp => Interp);
      --## rule off IMPROPER_INITIALIZATION
      Faction: Faction_Record;
      Local_Help: Help_Data;
      --## rule on IMPROPER_INITIALIZATION
   begin
      configure(Widgt => Help_View, options => "-state normal");
      Delete(TextWidget => Help_View, StartIndex => "1.0", Indexes => "end");
      Find_Help_Text_Loop :
      for I in 0 .. 100 loop
         Local_Help := Get_Help(Title => Help_Title, Help_Index => I);
         exit Find_Help_Text_Loop when Length(Source => Local_Help.Index) = 0;
         if Local_Help.Index =
           To_Unbounded_String
             (Source => Selection(TreeViewWidget => Topics_View)) then
            New_Text := Local_Help.Text;
            exit Find_Help_Text_Loop;
         end if;
      end loop Find_Help_Text_Loop;
      Old_Index := 1;
      Replace_Help_Text_Loop :
      loop
         Start_Index :=
           Index(Source => New_Text, Pattern => "{", From => Old_Index);
         if Start_Index = 0 then
            Insert
              (TextWidget => Help_View, Index => "end",
               Text =>
                 "{" &
                 Slice
                   (Source => New_Text, Low => Old_Index,
                    High => Length(Source => New_Text)) &
                 "}");
            exit Replace_Help_Text_Loop;
         end if;
         Insert
           (TextWidget => Help_View, Index => "end",
            Text =>
              "{" &
              Slice
                (Source => New_Text, Low => Old_Index,
                 High => Start_Index - 1) &
              "}");
         End_Index :=
           Index(Source => New_Text, Pattern => "}", From => Start_Index) - 1;
         Tag_Text :=
           Unbounded_Slice
             (Source => New_Text, Low => Start_Index + 1, High => End_Index);
         Insert_Variables_Loop :
         for Variable of Variables loop
            if Tag_Text = Variable.Name then
               Insert
                 (TextWidget => Help_View, Index => "end",
                  Text =>
                    "{" & To_String(Source => Variable.Value) &
                    "} [list special]");
               exit Insert_Variables_Loop;
            end if;
         end loop Insert_Variables_Loop;
         Insert_Keys_Loop :
         for I in Accel_Names'Range loop
            if Tag_Text =
              To_Unbounded_String(Source => "GameKey") &
                To_Unbounded_String(Source => Positive'Image(I)) then
               Insert
                 (TextWidget => Help_View, Index => "end",
                  Text =>
                    "{'" & To_String(Source => Accel_Names(I)) &
                    "'} [list special]");
               exit Insert_Keys_Loop;
            end if;
         end loop Insert_Keys_Loop;
         Insert_Tags_Loop :
         for F_Tag of Font_Tags loop
            if Tag_Text = To_Unbounded_String(Source => F_Tag.Tag) then
               Start_Index :=
                 Index(Source => New_Text, Pattern => "{", From => End_Index) -
                 1;
               Insert
                 (TextWidget => Help_View, Index => "end",
                  Text =>
                    "{" &
                    Slice
                      (Source => New_Text, Low => End_Index + 2,
                       High => Start_Index) &
                    "} [list " & To_String(Source => F_Tag.Text_Tag) & "]");
               End_Index :=
                 Index
                   (Source => New_Text, Pattern => "}", From => Start_Index) -
                 1;
               exit Insert_Tags_Loop;
            end if;
         end loop Insert_Tags_Loop;
         Insert_Factions_Flags_Loop :
         for Flag_Tag of Flags_Tags loop
            if Tag_Text = Flag_Tag then
               Factions_With_Flag := Null_Unbounded_String;
               Create_Factions_List_Loop :
               for J in 1 .. Get_Factions_Amount loop
                  Faction := Get_Faction(Number => J);
                  if Faction.Flags.Contains(Item => Tag_Text) then
                     if Factions_With_Flag /= Null_Unbounded_String then
                        Append
                          (Source => Factions_With_Flag, New_Item => " and ");
                     end if;
                     Append
                       (Source => Factions_With_Flag,
                        New_Item => To_String(Source => Faction.Name));
                  end if;
               end loop Create_Factions_List_Loop;
               Insert_Factions_Loop :
               while Ada.Strings.Unbounded.Count
                   (Source => Factions_With_Flag, Pattern => " and ") >
                 1 loop
                  Replace_Slice
                    (Source => Factions_With_Flag,
                     Low =>
                       Index(Source => Factions_With_Flag, Pattern => " and "),
                     High =>
                       Index
                         (Source => Factions_With_Flag, Pattern => " and ") +
                       4,
                     By => ", ");
               end loop Insert_Factions_Loop;
               Insert
                 (TextWidget => Help_View, Index => "end",
                  Text => "{" & To_String(Source => Factions_With_Flag) & "}");
               exit Insert_Factions_Flags_Loop;
            end if;
         end loop Insert_Factions_Flags_Loop;
         Insert_Bases_Flags_Loop :
         for BaseFlag of Bases_Flags loop
            if Tag_Text /= BaseFlag then
               goto Bases_Flags_Loop_End;
            end if;
            Bases_With_Flag := Null_Unbounded_String;
            Create_Bases_List_Loop :
            for BaseType of Bases_Types loop
               exit Create_Bases_List_Loop when Length(Source => BaseType) = 0;
               if Has_Flag
                   (Base_Type => BaseType,
                    Flag => To_String(Source => Tag_Text)) then
                  if Bases_With_Flag /= Null_Unbounded_String then
                     Append(Source => Bases_With_Flag, New_Item => " and ");
                  end if;
                  Append
                    (Source => Bases_With_Flag,
                     New_Item => Get_Base_Type_Name(Base_Type => BaseType));
               end if;
            end loop Create_Bases_List_Loop;
            Insert_Bases_Loop :
            while Ada.Strings.Unbounded.Count
                (Source => Bases_With_Flag, Pattern => " and ") >
              1 loop
               Replace_Slice
                 (Source => Bases_With_Flag,
                  Low => Index(Source => Bases_With_Flag, Pattern => " and "),
                  High =>
                    Index(Source => Bases_With_Flag, Pattern => " and ") + 4,
                  By => ", ");
            end loop Insert_Bases_Loop;
            Insert
              (TextWidget => Help_View, Index => "end",
               Text => "{" & To_String(Source => Bases_With_Flag) & "}");
            exit Insert_Bases_Flags_Loop;
            <<Bases_Flags_Loop_End>>
         end loop Insert_Bases_Flags_Loop;
         Old_Index := End_Index + 2;
      end loop Replace_Help_Text_Loop;
      configure(Widgt => Help_View, options => "-state disabled");
      return TCL_OK;
   end Show_Topic_Command;

   -- ****o* HUI/HUI.Close_Help_Command
   -- FUNCTION
   -- Destroy help window and save sash position to the game configuration
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- CloseHelp
   -- SOURCE
   function Close_Help_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Close_Help_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc, Argv);
      Help_Window: Tk_Toplevel :=
        Get_Widget(pathName => ".help", Interp => Interp);
      Paned: constant Ttk_PanedWindow :=
        Get_Widget(pathName => Help_Window & ".paned", Interp => Interp);
   begin
      Set_Integer_Setting
        (Name => "topicsPosition",
         Value => Natural'Value(SashPos(Paned => Paned, Index => "0")));
      Destroy(Widgt => Help_Window);
      return TCL_OK;
   end Close_Help_Command;

   -- ****o* HUI/HUI.Show_Help_Command
   -- FUNCTION
   -- Show help window to the player
   -- PARAMETERS
   -- Client_Data - Custom data send to the command.
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command.
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowHelp topicindex
   -- Topicindex is the index of the help topic which content will be show
   -- SOURCE
   function Show_Help_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Help_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      use Ada.Strings.Fixed;
      use GNAT.Directory_Operations;
      use Tcl.Ada;
      use Tcl.Tk.Ada.Winfo;
      use Tcl.Tk.Ada.Wm;
      use Dialogs;
      use Themes;

      Help_Window: constant Tk_Toplevel :=
        Get_Widget(pathName => ".help", Interp => Interp);
      X, Y: Integer;
      Paned: constant Ttk_PanedWindow :=
        Get_Widget(pathName => Help_Window & ".paned", Interp => Interp);
      Topics_View: constant Ttk_Tree_View :=
        Get_Widget(pathName => Paned & ".topics.view", Interp => Interp);
      Topic_Index: constant String :=
        (if Argc = 1 then Tcl_GetVar(interp => Interp, varName => "gamestate")
         else CArgv.Arg(Argv => Argv, N => 1));
      Help_View: constant Tk_Text :=
        Get_Widget(pathName => Paned & ".content.view", Interp => Interp);
      Local_Help: Help_Data; --## rule line off IMPROPER_INITIALIZATION
      Help_Title: Unbounded_String := Null_Unbounded_String;
   begin
      if Winfo_Get(Widgt => Help_Window, Info => "exists") = "1" then
         return
           Close_Help_Command
             (Client_Data => Client_Data, Interp => Interp, Argc => Argc,
              Argv => Argv);
      end if;
      Tcl_EvalFile
        (interp => Interp,
         fileName =>
           To_String(Source => Data_Directory) & "ui" & Dir_Separator &
           "help.tcl");
      Tag_Configure
        (TextWidget => Help_View, TagName => "special",
         Options =>
           "-foreground {" & Get_Icon(Name => "specialHelpColor") &
           "} -font BoldHelpFont");
      Tag_Configure
        (TextWidget => Help_View, TagName => "underline",
         Options =>
           "-foreground {" & Get_Icon(Name => "underlineHelpColor") &
           "} -font UnderlineHelpFont");
      Tag_Configure
        (TextWidget => Help_View, TagName => "bold",
         Options =>
           "-foreground {" & Get_Icon(Name => "boldHelpColor") &
           "} -font BoldHelpFont");
      Tag_Configure
        (TextWidget => Help_View, TagName => "italic",
         Options =>
           "-foreground {" & Get_Icon(Name => "italicHelpColor") &
           "} -font ItalicHelpFont");
      X :=
        (Positive'Value
           (Winfo_Get(Widgt => Help_Window, Info => "vrootwidth")) -
         Get_Integer_Setting(Name => "windowWidth")) /
        2;
      if X < 0 then
         X := 0;
      end if;
      Y :=
        (Positive'Value
           (Winfo_Get(Widgt => Help_Window, Info => "vrootheight")) -
         Get_Integer_Setting(Name => "windowHeight")) /
        2;
      if Y < 0 then
         Y := 0;
      end if;
      Wm_Set
        (Widgt => Help_Window, Action => "geometry",
         Options =>
           Trim
             (Source =>
                Positive'Image(Get_Integer_Setting(Name => "windowWidth")),
              Side => Left) &
           "x" &
           Trim
             (Source =>
                Positive'Image(Get_Integer_Setting(Name => "windowHeight")),
              Side => Left) &
           "+" & Trim(Source => Positive'Image(X), Side => Left) & "+" &
           Trim(Source => Positive'Image(Y), Side => Left));
      Tcl_Eval(interp => Interp, strng => "update");
      SashPos
        (Paned => Paned, Index => "0",
         NewPos =>
           Natural'Image(Get_Integer_Setting(Name => "topicsPosition")));
      Insert_Topics_Loop :
      for I in 0 .. 100 loop
         Local_Help := Get_Help(Title => Help_Title, Help_Index => I);
         exit Insert_Topics_Loop when Length(Source => Local_Help.Index) = 0;
         Insert
           (TreeViewWidget => Topics_View,
            Options =>
              "{} end -id {" & To_String(Source => Local_Help.Index) &
              "} -text {" & To_String(Source => Help_Title) & "}");
      end loop Insert_Topics_Loop;
      Bind
        (Widgt => Topics_View, Sequence => "<<TreeviewSelect>>",
         Script => "ShowTopic");
      if Exists(TreeViewWidget => Topics_View, Item => Topic_Index) = "0" then
         Show_Message
           (Text =>
              "The selected help topic doesn't exist. Showing the first available instead.",
            Parent_Frame => ".help", Title => "Can't find help topic");
         Selection_Set
           (TreeViewWidget => Topics_View,
            Items =>
              To_String
                (Source =>
                   Get_Help(Title => Help_Title, Help_Index => 0).Index));
         return TCL_OK;
      end if;
      Selection_Set(TreeViewWidget => Topics_View, Items => Topic_Index);
      Tcl_Eval(interp => Interp, strng => "update");
      See(TreeViewWidget => Topics_View, Item => Topic_Index);
      return TCL_OK;
   end Show_Help_Command;

   procedure Add_Commands is
      use Utils.UI;
   begin
      Add_Command
        (Name => "ShowTopic", Ada_Command => Show_Topic_Command'Access);
      Add_Command(Name => "ShowHelp", Ada_Command => Show_Help_Command'Access);
      Add_Command
        (Name => "CloseHelp", Ada_Command => Close_Help_Command'Access);
   end Add_Commands;

end Help.UI;
