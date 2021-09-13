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

with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Characters.Latin_1; use Ada.Characters.Latin_1;
with Ada.Containers.Generic_Array_Sort;
with Ada.Strings; use Ada.Strings;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Interfaces.C; use Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with CArgv; use CArgv;
with Tcl; use Tcl;
with Tcl.Ada; use Tcl.Ada;
with Tcl.Tk.Ada; use Tcl.Tk.Ada;
with Tcl.Tk.Ada.Grid;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.Canvas; use Tcl.Tk.Ada.Widgets.Canvas;
with Tcl.Tk.Ada.Widgets.Menu; use Tcl.Tk.Ada.Widgets.Menu;
with Tcl.Tk.Ada.Widgets.Toplevel.MainWindow;
use Tcl.Tk.Ada.Widgets.Toplevel.MainWindow;
with Tcl.Tk.Ada.Widgets.TtkButton; use Tcl.Tk.Ada.Widgets.TtkButton;
with Tcl.Tk.Ada.Widgets.TtkButton.TtkRadioButton;
use Tcl.Tk.Ada.Widgets.TtkButton.TtkRadioButton;
with Tcl.Tk.Ada.Widgets.TtkEntry.TtkComboBox;
use Tcl.Tk.Ada.Widgets.TtkEntry.TtkComboBox;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Tcl.Tk.Ada.Widgets.TtkLabel; use Tcl.Tk.Ada.Widgets.TtkLabel;
with Tcl.Tk.Ada.Widgets.TtkProgressBar; use Tcl.Tk.Ada.Widgets.TtkProgressBar;
with Tcl.Tk.Ada.Widgets.TtkScale; use Tcl.Tk.Ada.Widgets.TtkScale;
with Tcl.Tk.Ada.Widgets.TtkScrollbar; use Tcl.Tk.Ada.Widgets.TtkScrollbar;
with Tcl.Tk.Ada.Winfo; use Tcl.Tk.Ada.Winfo;
with Tcl.Tklib.Ada.Autoscroll; use Tcl.Tklib.Ada.Autoscroll;
with Tcl.Tklib.Ada.Tooltip; use Tcl.Tklib.Ada.Tooltip;
with Bases.Trade; use Bases.Trade;
with CoreUI; use CoreUI;
with Dialogs; use Dialogs;
with Maps; use Maps;
with Maps.UI; use Maps.UI;
with Ships.Crew; use Ships.Crew;
with Table; use Table;
with Utils.UI; use Utils.UI;

package body Bases.RecruitUI is

   -- ****iv* RecruitUI/RecruitUI.RecruitTable
   -- FUNCTION
   -- Table with info about the available recruits
   -- SOURCE
   RecruitTable: Table_Widget (6);
   -- ****

   -- ****iv* RecruitUI/RecruitUI.Modules_Indexes
   -- FUNCTION
   -- Indexes of the available recruits in base
   -- SOURCE
   Recruits_Indexes: Positive_Container.Vector;
   -- ****

   -- ****if* RecruitUI/RecruitUI.Get_Highest_Attribute
   -- FUNCTION
   -- Get the highest attribute's name of the selected recruit
   -- PARAMETERS
   -- BaseIndex   - The index of the base in which the recruit's attributes
   --               will be check
   -- MemberIndex - The index of the recruit which attributes will be check
   -- RESULT
   -- The name of the attribute with the highest level of the selected recruit
   -- HISTORY
   -- 6.5 - Added
   -- SOURCE
   function Get_Highest_Attribute
     (BaseIndex, MemberIndex: Positive) return Unbounded_String is
     -- ****
      use Tiny_String;

      HighestLevel, HighestIndex: Positive := 1;
   begin
      Get_Highest_Attribute_Level_Loop :
      for I in SkyBases(BaseIndex).Recruits(MemberIndex).Attributes'Range loop
         if SkyBases(BaseIndex).Recruits(MemberIndex).Attributes(I)(1) >
           HighestLevel then
            HighestLevel :=
              SkyBases(BaseIndex).Recruits(MemberIndex).Attributes(I)(1);
            HighestIndex := I;
         end if;
      end loop Get_Highest_Attribute_Level_Loop;
      return
        To_Unbounded_String
          (To_String
             (AttributesData_Container.Element(Attributes_List, Count_Type(HighestIndex))
                .Name));
   end Get_Highest_Attribute;

   -- ****if* RecruitUI/RecruitUI.Get_Highest_Skill
   -- FUNCTION
   -- Get the highest skill's name of the selected recruit
   -- PARAMETERS
   -- BaseIndex   - The index of the base in which the recruit's skills will
   --               be check
   -- MemberIndex - The index of the recruit which skills will be check
   -- RESULT
   -- The name of the skill with the highest level of the selected recruit
   -- HISTORY
   -- 6.5 - Added
   -- SOURCE
   function Get_Highest_Skill
     (BaseIndex, MemberIndex: Positive) return Unbounded_String is
     -- ****
      use Tiny_String;

      HighestLevel, HighestIndex: Positive := 1;
   begin
      Get_Highest_Skill_Level_Loop :
      for Skill of SkyBases(BaseIndex).Recruits(MemberIndex).Skills loop
         if Skill(2) > HighestLevel then
            HighestLevel := Skill(2);
            HighestIndex := Skill(1);
         end if;
      end loop Get_Highest_Skill_Level_Loop;
      return
        To_Unbounded_String
          (To_String
             (SkillsData_Container.Element(Skills_List, HighestIndex).Name));
   end Get_Highest_Skill;

   -- ****o* RecruitUI/RecruitUI.Show_Recruit_Command
   -- FUNCTION
   -- Show the selected base available recruits
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command.
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowRecruit
   -- SOURCE
   function Show_Recruit_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Recruit_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData);
      RecruitFrame: Ttk_Frame :=
        Get_Widget(Main_Paned & ".recruitframe", Interp);
      BaseIndex: constant Positive :=
        SkyMap(Player_Ship.Sky_X, Player_Ship.Sky_Y).BaseIndex;
      Page: constant Positive :=
        (if Argc = 2 then Positive'Value(CArgv.Arg(Argv, 1)) else 1);
      Start_Row: constant Positive := ((Page - 1) * 25) + 1;
      Current_Row: Positive := 1;
   begin
      if Winfo_Get(RecruitFrame, "exists") = "0" then
         RecruitFrame := Create(Widget_Image(RecruitFrame));
         RecruitTable :=
           CreateTable
             (Parent => Widget_Image(RecruitFrame),
              Headers =>
                (To_Unbounded_String("Name"), To_Unbounded_String("Gender"),
                 To_Unbounded_String("Faction"),
                 To_Unbounded_String("Base cost"),
                 To_Unbounded_String("Highest stat"),
                 To_Unbounded_String("Highest skill")),
              Command => "SortRecruits",
              Tooltip => "Press mouse button to sort the recruits.");
         Bind
           (RecruitFrame, "<Configure>",
            "{ResizeCanvas " & RecruitTable.Canvas & " %w %h}");
      elsif Winfo_Get(RecruitFrame, "ismapped") = "1" and
        (Argc = 1 or SkyBases(BaseIndex).Recruits.Length = 0) then
         Tcl.Tk.Ada.Grid.Grid_Remove(Close_Button);
         Entry_Configure(GameMenu, "Help", "-command {ShowHelp general}");
         ShowSkyMap(True);
         return TCL_OK;
      end if;
      Entry_Configure(GameMenu, "Help", "-command {ShowHelp crew}");
      Tcl.Tk.Ada.Grid.Grid(Close_Button, "-row 0 -column 1");
      if Recruits_Indexes.Length /= SkyBases(BaseIndex).Recruits.Length then
         Recruits_Indexes.Clear;
         for I in SkyBases(BaseIndex).Recruits.Iterate loop
            Recruits_Indexes.Append(Recruit_Container.To_Index(I));
         end loop;
      end if;
      ClearTable(RecruitTable);
      Load_Recruits_Loop :
      for I of Recruits_Indexes loop
         if Current_Row < Start_Row then
            Current_Row := Current_Row + 1;
            goto End_Of_Loop;
         end if;
         AddButton
           (RecruitTable, To_String(SkyBases(BaseIndex).Recruits(I).Name),
            "Show available options for recruit",
            "ShowRecruitMenu" & Positive'Image(I), 1);
         AddButton
           (RecruitTable,
            (if SkyBases(BaseIndex).Recruits(I).Gender = 'F' then "Female"
             else "Male"),
            "Show available options for recruit",
            "ShowRecruitMenu" & Positive'Image(I), 2);
         AddButton
           (RecruitTable,
            To_String
              (Factions_List(SkyBases(BaseIndex).Recruits(I).Faction).Name),
            "Show available options for recruit",
            "ShowRecruitMenu" & Positive'Image(I), 3);
         AddButton
           (RecruitTable,
            Positive'Image(SkyBases(BaseIndex).Recruits(I).Price),
            "Show available options for recruit",
            "ShowRecruitMenu" & Positive'Image(I), 4);
         AddButton
           (RecruitTable, To_String(Get_Highest_Attribute(BaseIndex, I)),
            "Show available options for recruit",
            "ShowRecruitMenu" & Positive'Image(I), 5);
         AddButton
           (RecruitTable, To_String(Get_Highest_Skill(BaseIndex, I)),
            "Show available options for recruit",
            "ShowRecruitMenu" & Positive'Image(I), 6, True);
         exit Load_Recruits_Loop when RecruitTable.Row = 26;
         <<End_Of_Loop>>
      end loop Load_Recruits_Loop;
      if Page > 1 then
         if RecruitTable.Row < 26 then
            AddPagination
              (RecruitTable, "ShowRecruit" & Positive'Image(Page - 1), "");
         else
            AddPagination
              (RecruitTable, "ShowRecruit" & Positive'Image(Page - 1),
               "ShowRecruit" & Positive'Image(Page + 1));
         end if;
      elsif RecruitTable.Row = 26 then
         AddPagination
           (RecruitTable, "", "ShowRecruit" & Positive'Image(Page + 1));
      end if;
      UpdateTable(RecruitTable);
      configure
        (RecruitTable.Canvas,
         "-scrollregion [list " & BBox(RecruitTable.Canvas, "all") & "]");
      ShowScreen("recruitframe");
      return TCL_OK;
   end Show_Recruit_Command;

   -- ****iv* RecruitUI/RecruitUI.RecruitIndex
   -- FUNCTION
   -- The index of currently selected recruit
   -- SOURCE
   RecruitIndex: Positive;
   -- ****

   -- ****o* RecruitUI/RecruitUI.Show_Recruit_Menu_Command
   -- FUNCTION
   -- Show menu with actions for the selected recruit
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowRecruitMenu recruitindex
   -- RecruitIndex is a index of the recruit which menu will be shown
   -- SOURCE
   function Show_Recruit_Menu_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Recruit_Menu_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      RecruitMenu: Tk_Menu := Get_Widget(".recruitmenu", Interp);
   begin
      RecruitIndex := Positive'Value(CArgv.Arg(Argv, 1));
      if Winfo_Get(RecruitMenu, "exists") = "0" then
         RecruitMenu := Create(".recruitmenu", "-tearoff false");
      end if;
      Delete(RecruitMenu, "0", "end");
      Menu.Add
        (RecruitMenu, "command",
         "-label {Show recruit details} -command {ShowRecruitInfo}");
      Menu.Add
        (RecruitMenu, "command",
         "-label {Start negotiations} -command {Negotiate}");
      Tk_Popup
        (RecruitMenu, Winfo_Get(Get_Main_Window(Interp), "pointerx"),
         Winfo_Get(Get_Main_Window(Interp), "pointery"));
      return TCL_OK;
   end Show_Recruit_Menu_Command;

   -- ****o* RecruitUI/RecruitUI.Show_Recruit_Info_Command
   -- FUNCTION
   -- Show information about the selected recruit
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowRecruitInfoCommand
   -- SOURCE
   function Show_Recruit_Info_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Recruit_Info_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
      use Tiny_String;

      RecruitInfo: Unbounded_String;
      BaseIndex: constant Positive :=
        SkyMap(Player_Ship.Sky_X, Player_Ship.Sky_Y).BaseIndex;
      Recruit: constant Recruit_Data :=
        SkyBases(BaseIndex).Recruits(RecruitIndex);
      RecruitDialog: constant Ttk_Frame :=
        Create_Dialog(".recruitdialog", To_String(Recruit.Name));
      YScroll: constant Ttk_Scrollbar :=
        Create
          (RecruitDialog & ".yscroll",
           "-orient vertical -command [list " & RecruitDialog &
           ".canvas yview]");
      RecruitCanvas: constant Tk_Canvas :=
        Create
          (RecruitDialog & ".canvas",
           "-yscrollcommand [list " & YScroll & " set]");
      CloseButton, InfoButton, Button: Ttk_Button;
      Height, NewHeight: Positive := 1;
      Width, NewWidth: Positive := 1;
      ProgressBar: Ttk_ProgressBar;
      TabButton: Ttk_RadioButton;
      Frame: Ttk_Frame := Create(RecruitDialog & ".buttonbox");
      RecruitLabel: Ttk_Label;
      ProgressFrame: Ttk_Frame;
      TabNames: constant array(1 .. 4) of Unbounded_String :=
        (To_Unbounded_String("General"), To_Unbounded_String("Attributes"),
         To_Unbounded_String("Skills"), To_Unbounded_String("Inventory"));
   begin
      Tcl_SetVar(Interp, "newtab", To_Lower(To_String(TabNames(1))));
      for I in TabNames'Range loop
         TabButton :=
           Create
             (Frame & "." & To_Lower(To_String(TabNames(I))),
              " -text " & To_String(TabNames(I)) &
              " -style Radio.Toolbutton -value " &
              To_Lower(To_String(TabNames(I))) &
              " -variable newtab -command ShowRecruitTab");
         Tcl.Tk.Ada.Grid.Grid
           (TabButton, "-column" & Natural'Image(I - 1) & " -row 0");
         Bind
           (TabButton, "<Escape>",
            "{" & RecruitDialog & ".buttonbox2.button invoke;break}");
      end loop;
      Height := Positive'Value(Winfo_Get(TabButton, "reqheight"));
      Bind
        (TabButton, "<Tab>",
         "{focus " & RecruitDialog & ".buttonbox2.hirebutton;break}");
      Tcl.Tk.Ada.Grid.Grid(Frame, "-pady {5 0} -columnspan 2");
      Tcl.Tk.Ada.Grid.Grid(RecruitCanvas, "-sticky nwes -pady 5 -padx 5");
      Tcl.Tk.Ada.Grid.Grid
        (YScroll, " -sticky ns -pady 5 -padx {0 5} -row 1 -column 1");
      Frame := Create(RecruitDialog & ".buttonbox2");
      Button :=
        Create
          (RecruitDialog & ".buttonbox2.hirebutton",
           "-text Negotiate -command {CloseDialog " & RecruitDialog &
           ";Negotiate}");
      Tcl.Tk.Ada.Grid.Grid(Button);
      CloseButton :=
        Create
          (RecruitDialog & ".buttonbox2.button",
           "-text Close -command {CloseDialog " & RecruitDialog & "}");
      Tcl.Tk.Ada.Grid.Grid(CloseButton, "-row 0 -column 1");
      Tcl.Tk.Ada.Grid.Grid(Frame, "-pady {0 5}");
      Focus(CloseButton);
      Autoscroll(YScroll);
      -- General info about the selected recruit
      Frame := Create(RecruitCanvas & ".general");
      if not Factions_List(Recruit.Faction).Flags.Contains
          (To_Unbounded_String("nogender")) then
         RecruitInfo :=
           (if Recruit.Gender = 'M' then To_Unbounded_String("Gender: Male")
            else To_Unbounded_String("Gender: Female"));
      end if;
      Append
        (RecruitInfo,
         LF & "Faction: " & Factions_List(Recruit.Faction).Name & LF &
         "Home base: " & SkyBases(Recruit.HomeBase).Name);
      RecruitLabel :=
        Create
          (Frame & ".label",
           "-text {" & To_String(RecruitInfo) & "} -wraplength 400");
      Tcl.Tk.Ada.Grid.Grid(RecruitLabel, "-sticky w");
      Height := Height + Positive'Value(Winfo_Get(RecruitLabel, "reqheight"));
      Width := Positive'Value(Winfo_Get(RecruitLabel, "reqwidth"));
      Tcl.Tk.Ada.Grid.Grid(Frame);
      -- Statistics of the selected recruit
      Frame := Create(RecruitCanvas & ".attributes");
      Show_Recruit_Stats_Loop :
      for I in Recruit.Attributes'Range loop
         ProgressFrame :=
           Create(Frame & ".statinfo" & Trim(Positive'Image(I), Left));
         RecruitLabel :=
           Create
             (ProgressFrame & ".label",
              "-text {" &
              To_String
                (AttributesData_Container.Element(Attributes_List, Count_Type(I)).Name) &
              ": " & GetAttributeLevelName(Recruit.Attributes(I)(1)) & "}");
         Tcl.Tk.Ada.Grid.Grid(RecruitLabel);
         InfoButton :=
           Create
             (ProgressFrame & ".button",
              "-text ""[format %c 0xf05a]"" -style Header.Toolbutton -command {ShowCrewStatsInfo" &
              Positive'Image(I) & " .recruitdialog}");
         Tcl.Tklib.Ada.Tooltip.Add
           (InfoButton,
            "Show detailed information about the selected attribute.");
         Tcl.Tk.Ada.Grid.Grid(InfoButton, "-column 1 -row 0");
         NewHeight :=
           NewHeight + Positive'Value(Winfo_Get(InfoButton, "reqheight"));
         Tcl.Tk.Ada.Grid.Grid(ProgressFrame);
         ProgressBar :=
           Create
             (Frame & ".level" & Trim(Positive'Image(I), Left),
              "-value" & Positive'Image(Recruit.Attributes(I)(1) * 2) &
              " -length 200");
         Tcl.Tklib.Ada.Tooltip.Add
           (ProgressBar, "The current level of the attribute.");
         Tcl.Tk.Ada.Grid.Grid(ProgressBar);
         NewHeight :=
           NewHeight + Positive'Value(Winfo_Get(ProgressBar, "reqheight"));
      end loop Show_Recruit_Stats_Loop;
      if NewHeight > Height then
         Height := NewHeight;
      end if;
      -- Skills of the selected recruit
      Frame := Create(RecruitCanvas & ".skills");
      NewHeight := 1;
      Show_Recruit_Skills_Loop :
      for I in Recruit.Skills.Iterate loop
         ProgressFrame :=
           Create
             (Frame & ".skillinfo" &
              Trim(Positive'Image(Skills_Container.To_Index(I)), Left));
         RecruitLabel :=
           Create
             (ProgressFrame & ".label" &
              Trim(Positive'Image(Skills_Container.To_Index(I)), Left),
              "-text {" &
              To_String
                (SkillsData_Container.Element
                   (Skills_List, Recruit.Skills(I)(1))
                   .Name) &
              ": " & GetSkillLevelName(Recruit.Skills(I)(2)) & "}");
         Tcl.Tk.Ada.Grid.Grid(RecruitLabel);
         declare
            ToolQuality: Positive := 100;
         begin
            Tool_Quality_Loop :
            for Quality of SkillsData_Container.Element
              (Skills_List, Skills_Container.To_Index(I))
              .Tools_Quality loop
               if Recruit.Skills(I)(2) <= Quality.Level then
                  ToolQuality := Quality.Quality;
                  exit Tool_Quality_Loop;
               end if;
            end loop Tool_Quality_Loop;
            InfoButton :=
              Create
                (ProgressFrame & ".button",
                 "-text ""[format %c 0xf05a]"" -style Header.Toolbutton -command {ShowCrewSkillInfo" &
                 Positive'Image(Recruit.Skills(I)(1)) &
                 Positive'Image(ToolQuality) & " .recruitdialog}");
         end;
         Tcl.Tklib.Ada.Tooltip.Add
           (InfoButton, "Show detailed information about the selected skill.");
         Tcl.Tk.Ada.Grid.Grid(InfoButton, "-column 1 -row 0");
         NewHeight :=
           NewHeight + Positive'Value(Winfo_Get(InfoButton, "reqheight"));
         Tcl.Tk.Ada.Grid.Grid(ProgressFrame);
         ProgressBar :=
           Create
             (Frame & ".level" &
              Trim(Positive'Image(Skills_Container.To_Index(I)), Left),
              "-value" & Positive'Image(Recruit.Skills(I)(2)) &
              " -length 200");
         Tcl.Tklib.Ada.Tooltip.Add
           (ProgressBar, "The current level of the skill.");
         Tcl.Tk.Ada.Grid.Grid(ProgressBar);
         NewHeight :=
           NewHeight + Positive'Value(Winfo_Get(ProgressBar, "reqheight"));
      end loop Show_Recruit_Skills_Loop;
      if NewHeight > Height then
         Height := NewHeight;
      end if;
      -- Equipment of the selected recruit
      Frame := Create(RecruitCanvas & ".inventory");
      NewHeight := 1;
      RecruitInfo := Null_Unbounded_String;
      Show_Recruit_Equipment_Loop :
      for Item of Recruit.Inventory loop
         Append(RecruitInfo, Items_List(Item).Name & LF);
      end loop Show_Recruit_Equipment_Loop;
      RecruitLabel :=
        Create
          (Frame & ".label",
           "-text {" & To_String(RecruitInfo) & "} -wraplength 400");
      Tcl.Tk.Ada.Grid.Grid(RecruitLabel, "-sticky w");
      NewHeight := Positive'Value(Winfo_Get(RecruitLabel, "reqheight"));
      if NewHeight > Height then
         Height := NewHeight;
      end if;
      NewWidth := Positive'Value(Winfo_Get(RecruitLabel, "reqwidth"));
      if NewWidth > Width then
         Width := NewWidth;
      end if;
      if Height > 500 then
         Height := 500;
      end if;
      if Width < 350 then
         Width := 350;
      end if;
      Frame := Get_Widget(RecruitCanvas & ".general");
      declare
         XPos: constant Natural :=
           (Positive'Value(Winfo_Get(RecruitCanvas, "reqwidth")) -
            Positive'Value(Winfo_Get(Frame, "reqwidth"))) /
           4;
      begin
         Canvas_Create
           (RecruitCanvas, "window",
            Trim(Natural'Image(XPos), Left) & " 0 -anchor nw -window " &
            Frame & " -tag info");
      end;
      Tcl_Eval(Interp, "update");
      configure
        (RecruitCanvas,
         "-scrollregion [list " & BBox(RecruitCanvas, "all") & "] -width" &
         Positive'Image(Width) & " -height" & Positive'Image(Height));
      Bind
        (CloseButton, "<Tab>",
         "{focus " & RecruitDialog & ".buttonbox.general;break}");
      Bind(RecruitDialog, "<Escape>", "{" & CloseButton & " invoke;break}");
      Bind(CloseButton, "<Escape>", "{" & CloseButton & " invoke;break}");
      Show_Dialog(Dialog => RecruitDialog, Relative_Y => 0.2);
      return TCL_OK;
   end Show_Recruit_Info_Command;

   -- ****o* RecruitUI/RecruitUI.Negotiate_Hire_Command
   -- FUNCTION
   -- Show information about the selected recruit
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- NegotiateHire
   -- SOURCE
   function Negotiate_Hire_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Negotiate_Hire_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
      DialogName: constant String := ".negotiatedialog";
      MoneyIndex2: constant Natural :=
        FindItem(Player_Ship.Cargo, Money_Index);
      BaseIndex: constant Positive :=
        SkyMap(Player_Ship.Sky_X, Player_Ship.Sky_Y).BaseIndex;
      Recruit: constant Recruit_Data :=
        SkyBases(BaseIndex).Recruits(RecruitIndex);
      Cost: Integer;
      Scale: Ttk_Scale := Get_Widget(DialogName & ".daily", Interp);
      DailyPayment: constant Natural :=
        Natural(Float'Value(cget(Scale, "-value")));
      ContractBox: constant Ttk_ComboBox :=
        Get_Widget(DialogName & ".contract", Interp);
      ContractLength: constant Natural := Natural'Value(Current(ContractBox));
      TradePayment: Natural;
      Label: Ttk_Label := Get_Widget(DialogName & ".cost", Interp);
      HireButton: constant Ttk_Button :=
        Get_Widget(DialogName & ".buttonbox.hirebutton", Interp);
   begin
      Scale.Name := New_String(DialogName & ".percent");
      TradePayment := Natural(Float'Value(cget(Scale, "-value")));
      Cost :=
        Recruit.Price - ((DailyPayment - Recruit.Payment) * 50) -
        (TradePayment * 5_000);
      Cost :=
        (case ContractLength is
           when 1 => Cost - Integer(Float(Recruit.Price) * 0.1),
           when 2 => Cost - Integer(Float(Recruit.Price) * 0.5),
           when 3 => Cost - Integer(Float(Recruit.Price) * 0.75),
           when 4 => Cost - Integer(Float(Recruit.Price) * 0.9),
           when others => Cost);
      if Cost < 1 then
         Cost := 1;
      end if;
      CountPrice(Cost, FindMember(Talk));
      configure
        (Label,
         "-text {Hire for" & Natural'Image(Cost) & " " &
         To_String(Money_Name) & "}");
      Label.Name := New_String(DialogName & ".dailylbl");
      configure
        (Label, "-text {Daily payment:" & Natural'Image(DailyPayment) & "}");
      Label.Name := New_String(DialogName & ".percentlbl");
      configure
        (Label,
         "-text {Percent of profit from trades: " &
         Natural'Image(TradePayment) & "}");
      if MoneyIndex2 > 0
        and then Player_Ship.Cargo(MoneyIndex2).Amount < Cost then
         configure(HireButton, "-state disabled");
      else
         configure(HireButton, "-state !disabled");
      end if;
      return TCL_OK;
   end Negotiate_Hire_Command;

   -- ****o* RecruitUI/RecruitUI.Hire_Command
   -- FUNCTION
   -- Hire the selected recruit
   -- PARAMETERS
   -- ClientData - Custom data send to the command.
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- Hire
   -- SOURCE
   function Hire_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Hire_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Argc, Argv);
      DialogName: constant String := ".negotiatedialog";
      Cost, ContractLength2: Integer;
      BaseIndex: constant Positive :=
        SkyMap(Player_Ship.Sky_X, Player_Ship.Sky_Y).BaseIndex;
      Recruit: constant Recruit_Data :=
        SkyBases(BaseIndex).Recruits(RecruitIndex);
      Scale: Ttk_Scale := Get_Widget(DialogName & ".daily", Interp);
      DailyPayment: constant Natural :=
        Natural(Float'Value(cget(Scale, "-value")));
      ContractBox: constant Ttk_ComboBox :=
        Get_Widget(DialogName & ".contract", Interp);
      ContractLength: constant Natural := Natural'Value(Current(ContractBox));
      TradePayment: Natural;
   begin
      Scale.Name := New_String(DialogName & ".percent");
      TradePayment := Natural(Float'Value(cget(Scale, "-value")));
      Cost :=
        Recruit.Price - ((DailyPayment - Recruit.Payment) * 50) -
        (TradePayment * 5_000);
      case ContractLength is
         when 1 =>
            Cost := Cost - Integer(Float(Recruit.Price) * 0.1);
            ContractLength2 := 100;
         when 2 =>
            Cost := Cost - Integer(Float(Recruit.Price) * 0.5);
            ContractLength2 := 30;
         when 3 =>
            Cost := Cost - Integer(Float(Recruit.Price) * 0.75);
            ContractLength2 := 20;
         when 4 =>
            Cost := Cost - Integer(Float(Recruit.Price) * 0.9);
            ContractLength2 := 10;
         when others =>
            ContractLength2 := -1;
      end case;
      if Cost < 1 then
         Cost := 1;
      end if;
      HireRecruit
        (RecruitIndex, Cost, DailyPayment, TradePayment, ContractLength2);
      UpdateMessages;
      Tcl_Eval(Interp, "CloseDialog " & DialogName);
      return
        Show_Recruit_Command
          (ClientData, Interp, 2, CArgv.Empty & "ShowRecruit" & "1");
   end Hire_Command;

   -- ****o* RecruitUI/RecruitUI.Show_Recruit_Tab_Command
   -- FUNCTION
   -- Show the selected information about the selected recruit
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowMemberTab
   -- SOURCE
   function Show_Recruit_Tab_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Recruit_Tab_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
      RecruitCanvas: constant Tk_Canvas :=
        Get_Widget(".recruitdialog.canvas", Interp);
      Frame: constant Ttk_Frame :=
        Get_Widget(RecruitCanvas & "." & Tcl_GetVar(Interp, "newtab"));
      XPos: constant Natural :=
        (Positive'Value(Winfo_Get(RecruitCanvas, "reqwidth")) -
         Positive'Value(Winfo_Get(Frame, "reqwidth"))) /
        2;
   begin
      Delete(RecruitCanvas, "info");
      Canvas_Create
        (RecruitCanvas, "window",
         Trim(Positive'Image(XPos), Left) & " 0 -anchor nw -window " & Frame &
         " -tag info");
      Tcl_Eval(Interp, "update");
      configure
        (RecruitCanvas,
         "-scrollregion [list " & BBox(RecruitCanvas, "all") & "]");
      return TCL_OK;
   end Show_Recruit_Tab_Command;

   -- ****o* RecruitUI/RecruitUI.Negotiate_Command
   -- FUNCTION
   -- Show negotation UI to the player
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed. Unused
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- Negotiate
   -- SOURCE
   function Negotiate_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Negotiate_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Interp, Argc, Argv);
      BaseIndex: constant Positive :=
        SkyMap(Player_Ship.Sky_X, Player_Ship.Sky_Y).BaseIndex;
      Recruit: constant Recruit_Data :=
        SkyBases(BaseIndex).Recruits(RecruitIndex);
      NegotiateDialog: constant Ttk_Frame :=
        Create_Dialog
          (".negotiatedialog", "Negotiate with " & To_String(Recruit.Name));
      CloseButton, HireButton: Ttk_Button;
      Frame: constant Ttk_Frame := Create(NegotiateDialog & ".buttonbox");
      Label: Ttk_Label;
      Scale: Ttk_Scale;
      ContractBox: constant Ttk_ComboBox :=
        Create
          (NegotiateDialog & ".contract",
           "-state readonly -values [list {Pernament} {100 days} {30 days} {20 days} {10 days}]");
      MoneyIndex2: constant Natural :=
        FindItem(Player_Ship.Cargo, Money_Index);
      Cost: Positive;
   begin
      Label :=
        Create
          (NegotiateDialog & ".dailylbl",
           "-text {Daily payment:" & Natural'Image(Recruit.Payment) & "}");
      Tcl.Tk.Ada.Grid.Grid(Label, "-pady {5 0}");
      Scale :=
        Create
          (NegotiateDialog & ".daily",
           "-from 0 -command NegotiateHire -length 250");
      Tcl.Tk.Ada.Grid.Grid(Scale);
      configure
        (Scale,
         "-to" & Natural'Image(Recruit.Payment * 2) & " -value" &
         Natural'Image(Recruit.Payment));
      Label :=
        Create
          (NegotiateDialog & ".percentlbl",
           "-text {Percent of profit from trades: 0}");
      Tcl.Tk.Ada.Grid.Grid(Label, "-padx 5");
      Scale :=
        Create
          (NegotiateDialog & ".percent",
           "-from 0 -to 10 -command NegotiateHire -length 250");
      Tcl.Tk.Ada.Grid.Grid(Scale);
      configure(Scale, "-value 0");
      Label :=
        Create(NegotiateDialog & ".contractlbl", "-text {Contract time:}");
      Tcl.Tk.Ada.Grid.Grid(Label);
      Tcl.Tk.Ada.Grid.Grid(ContractBox);
      Bind(ContractBox, "<<ComboboxSelected>>", "{NegotiateHire}");
      Current(ContractBox, "0");
      HireButton :=
        Create
          (NegotiateDialog & ".buttonbox.hirebutton",
           "-text Hire -command {Hire}");
      Label := Create(NegotiateDialog & ".money");
      Tcl.Tk.Ada.Grid.Grid(Label);
      Cost := Recruit.Price;
      CountPrice(Cost, FindMember(Talk));
      if MoneyIndex2 > 0 then
         configure
           (Label,
            "-text {You have" &
            Natural'Image(Player_Ship.Cargo(MoneyIndex2).Amount) & " " &
            To_String(Money_Name) & ".}");
         if Player_Ship.Cargo(MoneyIndex2).Amount < Cost then
            configure(HireButton, "-state disabled");
         else
            configure(HireButton, "-state !disabled");
         end if;
      else
         configure
           (Label, "-text {You don't have enough money to recruit anyone}");
         configure(HireButton, "-state disabled");
      end if;
      Label := Create(NegotiateDialog & ".cost");
      Tcl.Tk.Ada.Grid.Grid(Label);
      configure
        (Label,
         "-text {Hire for" & Positive'Image(Cost) & " " &
         To_String(Money_Name) & "}");
      Tcl.Tk.Ada.Grid.Grid(HireButton);
      CloseButton :=
        Create
          (NegotiateDialog & ".buttonbox.button",
           "-text Close -command {CloseDialog " & NegotiateDialog & "}");
      Tcl.Tk.Ada.Grid.Grid(CloseButton, "-row 0 -column 1");
      Tcl.Tk.Ada.Grid.Grid(Frame, "-pady {0 5}");
      Focus(CloseButton);
      Bind(CloseButton, "<Tab>", "{focus " & HireButton & ";break}");
      Bind(HireButton, "<Tab>", "{focus " & CloseButton & ";break}");
      Bind(NegotiateDialog, "<Escape>", "{" & CloseButton & " invoke;break}");
      Bind(CloseButton, "<Escape>", "{" & CloseButton & " invoke;break}");
      Show_Dialog(Dialog => NegotiateDialog, Relative_Y => 0.2);
      return TCL_OK;
   end Negotiate_Command;

   -- ****it* RecruitUI/RecruitUI.Recruits_Sort_Orders
   -- FUNCTION
   -- Sorting orders for the list of available recruits in base
   -- OPTIONS
   -- NAMEASC       - Sort recruits by name ascending
   -- NAMEDESC      - Sort recruits by name descending
   -- GENDERASC     - Sort recruits by gender ascending
   -- GENDERDESC    - Sort recruits by gender descending
   -- FACTIONASC    - Sort recruits by faction ascending
   -- FACTIONDESC   - Sort recruits by faction descending
   -- PRICEASC      - Sort recruits by price ascending
   -- PRICEDESC     - Sort recruits by price descending
   -- ATTRIBUTEASC  - Sort recruits by attribute ascending
   -- ATTRIBUTEDESC - Sort recruits by attribute descending
   -- SKILLASC      - Sort recruits by skill ascending
   -- SKILLDESC     - Sort recruits by skill descending
   -- NONE       - No sorting recruits (default)
   -- HISTORY
   -- 6.4 - Added
   -- SOURCE
   type Recruits_Sort_Orders is
     (NAMEASC, NAMEDESC, GENDERASC, GENDERDESC, FACTIONDESC, FACTIONASC,
      PRICEASC, PRICEDESC, ATTRIBUTEASC, ATTRIBUTEDESC, SKILLASC, SKILLDESC,
      NONE) with
      Default_Value => NONE;
      -- ****

      -- ****id* RecruitUI/RecruitUI.Default_Recruits_Sort_Order
      -- FUNCTION
      -- Default sorting order for the available recruits in base
      -- HISTORY
      -- 6.4 - Added
      -- SOURCE
   Default_Recruits_Sort_Order: constant Recruits_Sort_Orders := NONE;
   -- ****

   -- ****iv* RecruitUI/RecruitUI.Recruits_Sort_Order
   -- FUNCTION
   -- The current sorting order for the available recruits in base
   -- HISTORY
   -- 6.4 - Added
   -- SOURCE
   Recruits_Sort_Order: Recruits_Sort_Orders := Default_Recruits_Sort_Order;
   -- ****

   -- ****o* RecruitUI/RecruitUI.Sort_Recruits_Command
   -- FUNCTION
   -- Sort the list of available recruits in base
   -- PARAMETERS
   -- ClientData - Custom data send to the command.
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- SortRecruits x
   -- X is X axis coordinate where the player clicked the mouse button
   -- SOURCE
   function Sort_Recruits_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Sort_Recruits_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Argc);
      Column: constant Positive :=
        Get_Column_Number(RecruitTable, Natural'Value(CArgv.Arg(Argv, 1)));
      type Local_Module_Data is record
         Name: Unbounded_String;
         Gender: Character;
         Faction: Unbounded_String;
         Price: Positive;
         Attribute: Unbounded_String;
         Skill: Unbounded_String;
         Id: Positive;
      end record;
      type Recruits_Array is array(Positive range <>) of Local_Module_Data;
      BaseIndex: constant Positive :=
        SkyMap(Player_Ship.Sky_X, Player_Ship.Sky_Y).BaseIndex;
      Local_Recruits: Recruits_Array
        (1 .. Positive(SkyBases(BaseIndex).Recruits.Length));
      function "<"(Left, Right: Local_Module_Data) return Boolean is
      begin
         if Recruits_Sort_Order = NAMEASC and then Left.Name < Right.Name then
            return True;
         end if;
         if Recruits_Sort_Order = NAMEDESC and then Left.Name > Right.Name then
            return True;
         end if;
         if Recruits_Sort_Order = GENDERASC
           and then Left.Gender < Right.Gender then
            return True;
         end if;
         if Recruits_Sort_Order = GENDERDESC
           and then Left.Gender > Right.Gender then
            return True;
         end if;
         if Recruits_Sort_Order = FACTIONASC
           and then Left.Faction < Right.Faction then
            return True;
         end if;
         if Recruits_Sort_Order = FACTIONDESC
           and then Left.Faction > Right.Faction then
            return True;
         end if;
         if Recruits_Sort_Order = PRICEASC
           and then Left.Price < Right.Price then
            return True;
         end if;
         if Recruits_Sort_Order = PRICEDESC
           and then Left.Price > Right.Price then
            return True;
         end if;
         if Recruits_Sort_Order = ATTRIBUTEASC
           and then Left.Attribute < Right.Attribute then
            return True;
         end if;
         if Recruits_Sort_Order = ATTRIBUTEDESC
           and then Left.Attribute > Right.Attribute then
            return True;
         end if;
         if Recruits_Sort_Order = SKILLASC
           and then Left.Skill < Right.Skill then
            return True;
         end if;
         if Recruits_Sort_Order = SKILLDESC
           and then Left.Skill > Right.Skill then
            return True;
         end if;
         return False;
      end "<";
      procedure Sort_Recruits is new Ada.Containers.Generic_Array_Sort
        (Index_Type => Positive, Element_Type => Local_Module_Data,
         Array_Type => Recruits_Array);
   begin
      case Column is
         when 1 =>
            if Recruits_Sort_Order = NAMEASC then
               Recruits_Sort_Order := NAMEDESC;
            else
               Recruits_Sort_Order := NAMEASC;
            end if;
         when 2 =>
            if Recruits_Sort_Order = GENDERASC then
               Recruits_Sort_Order := GENDERDESC;
            else
               Recruits_Sort_Order := GENDERASC;
            end if;
         when 3 =>
            if Recruits_Sort_Order = FACTIONASC then
               Recruits_Sort_Order := FACTIONDESC;
            else
               Recruits_Sort_Order := FACTIONASC;
            end if;
         when 4 =>
            if Recruits_Sort_Order = PRICEASC then
               Recruits_Sort_Order := PRICEDESC;
            else
               Recruits_Sort_Order := PRICEASC;
            end if;
         when 5 =>
            if Recruits_Sort_Order = ATTRIBUTEASC then
               Recruits_Sort_Order := ATTRIBUTEDESC;
            else
               Recruits_Sort_Order := ATTRIBUTEASC;
            end if;
         when 6 =>
            if Recruits_Sort_Order = SKILLASC then
               Recruits_Sort_Order := SKILLDESC;
            else
               Recruits_Sort_Order := SKILLASC;
            end if;
         when others =>
            null;
      end case;
      if Recruits_Sort_Order = NONE then
         return TCL_OK;
      end if;
      for I in SkyBases(BaseIndex).Recruits.Iterate loop
         Local_Recruits(Recruit_Container.To_Index(I)) :=
           (Name => SkyBases(BaseIndex).Recruits(I).Name,
            Gender => SkyBases(BaseIndex).Recruits(I).Gender,
            Faction => SkyBases(BaseIndex).Recruits(I).Faction,
            Price => SkyBases(BaseIndex).Recruits(I).Price,
            Attribute =>
              Get_Highest_Attribute(BaseIndex, Recruit_Container.To_Index(I)),
            Skill =>
              Get_Highest_Skill(BaseIndex, Recruit_Container.To_Index(I)),
            Id => Recruit_Container.To_Index(I));
      end loop;
      Sort_Recruits(Local_Recruits);
      Recruits_Indexes.Clear;
      for Recruit of Local_Recruits loop
         Recruits_Indexes.Append(Recruit.Id);
      end loop;
      return
        Show_Recruit_Command
          (ClientData, Interp, 2, CArgv.Empty & "ShowRecruits" & "1");
   end Sort_Recruits_Command;

   procedure AddCommands is
   begin
      AddCommand("ShowRecruit", Show_Recruit_Command'Access);
      AddCommand("ShowRecruitMenu", Show_Recruit_Menu_Command'Access);
      AddCommand("ShowRecruitInfo", Show_Recruit_Info_Command'Access);
      AddCommand("NegotiateHire", Negotiate_Hire_Command'Access);
      AddCommand("Hire", Hire_Command'Access);
      AddCommand("ShowRecruitTab", Show_Recruit_Tab_Command'Access);
      AddCommand("Negotiate", Negotiate_Command'Access);
      AddCommand("SortRecruits", Sort_Recruits_Command'Access);
   end AddCommands;

end Bases.RecruitUI;
