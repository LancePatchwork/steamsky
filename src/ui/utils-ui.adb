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
with Ada.Directories; use Ada.Directories;
with Ada.Strings; use Ada.Strings;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with GNAT.String_Split; use GNAT.String_Split;
with Tcl; use Tcl;
with Tcl.Ada; use Tcl.Ada;
with Tcl.Tk.Ada; use Tcl.Tk.Ada;
with Tcl.Tk.Ada.Grid;
with Tcl.Tk.Ada.Widgets.Text; use Tcl.Tk.Ada.Widgets.Text;
with Tcl.Tk.Ada.Widgets.Menu; use Tcl.Tk.Ada.Widgets.Menu;
with Tcl.Tk.Ada.Widgets.TtkButton; use Tcl.Tk.Ada.Widgets.TtkButton;
with Tcl.Tk.Ada.Widgets.TtkEntry; use Tcl.Tk.Ada.Widgets.TtkEntry;
with Tcl.Tk.Ada.Widgets.TtkEntry.TtkComboBox;
use Tcl.Tk.Ada.Widgets.TtkEntry.TtkComboBox;
with Tcl.Tk.Ada.Widgets.TtkEntry.TtkSpinBox;
use Tcl.Tk.Ada.Widgets.TtkEntry.TtkSpinBox;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Tcl.Tk.Ada.Widgets.TtkLabel; use Tcl.Tk.Ada.Widgets.TtkLabel;
with Tcl.Tk.Ada.Widgets.TtkPanedWindow; use Tcl.Tk.Ada.Widgets.TtkPanedWindow;
with Tcl.Tk.Ada.Widgets.TtkScrollbar; use Tcl.Tk.Ada.Widgets.TtkScrollbar;
with Tcl.Tk.Ada.Winfo; use Tcl.Tk.Ada.Winfo;
with Bases; use Bases;
with Combat.UI; use Combat.UI;
with Config; use Config;
with CoreUI; use CoreUI;
with Crew; use Crew;
with Dialogs; use Dialogs;
with Events; use Events;
with Factions; use Factions;
with Maps; use Maps;
with Maps.UI; use Maps.UI;
with MainMenu; use MainMenu;
with Messages; use Messages;
with Missions; use Missions;
with Ships.Cargo; use Ships.Cargo;
with Ships.Crew; use Ships.Crew;
with Ships.Movement; use Ships.Movement;
with Ships.UI.Crew; use Ships.UI.Crew;
with Ships.UI.Modules; use Ships.UI.Modules;
with Statistics.UI; use Statistics.UI;

package body Utils.UI is

   procedure Add_Command
     (Name: String; Ada_Command: not null CreateCommands.Tcl_CmdProc) is
      Command: Tcl.Tcl_Command;
      Steam_Sky_Add_Command_Error: exception;
   begin
      Tcl_Eval(interp => Get_Context, strng => "info commands " & Name);
      if Tcl_GetResult(interp => Get_Context) /= "" then
         raise Steam_Sky_Add_Command_Error
           with "Command with name " & Name & " exists";
      end if;
      Command :=
        CreateCommands.Tcl_CreateCommand
          (interp => Get_Context, cmdName => Name, proc => Ada_Command,
           data => 0, deleteProc => null);
      if Command = null then
         raise Steam_Sky_Add_Command_Error with "Can't add command " & Name;
      end if;
   end Add_Command;

   -- ****o* UUI/UUI.Resize_Canvas_Command
   -- PARAMETERS
   -- Resize the selected canvas
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command. Unused
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ResizeCanvas name width height
   -- Name is the name of the canvas to resize, width it a new width, height
   -- is a new height
   -- SOURCE
   function Resize_Canvas_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Resize_Canvas_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc);
      Canvas: constant Ttk_Frame :=
        Get_Widget
          (pathName => CArgv.Arg(Argv => Argv, N => 1), Interp => Interp);
      Parent_Frame: Ttk_Frame;
   begin
      if Winfo_Get(Widgt => Canvas, Info => "exists") = "0" then
         return TCL_OK;
      end if;
      Parent_Frame :=
        Get_Widget
          (pathName => Winfo_Get(Widgt => Canvas, Info => "parent"),
           Interp => Interp);
      Unbind(Widgt => Parent_Frame, Sequence => "<Configure>");
      Widgets.configure
        (Widgt => Canvas,
         options =>
           "-width " & CArgv.Arg(Argv => Argv, N => 2) & " -height [expr " &
           CArgv.Arg(Argv => Argv, N => 3) & " - 20]");
      Bind
        (Widgt => Parent_Frame, Sequence => "<Configure>",
         Script => "{ResizeCanvas %W.canvas %w %h}");
      return TCL_OK;
   end Resize_Canvas_Command;

   -- ****o* UUI/UUI.Check_Amount_Command
   -- PARAMETERS
   -- Check amount of the item, if it is not below low level warning or if
   -- entered amount is a proper number
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- CheckAmount name cargoindex value
   -- Name is the name of spinbox which value will be checked, cargoindex is
   -- the index of the item in the cargo
   -- SOURCE
   function Check_Amount_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Check_Amount_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data);
      Cargo_Index: constant Natural :=
        Natural'Value(CArgv.Arg(Argv => Argv, N => 2));
      Warning_Text: Unbounded_String := Null_Unbounded_String;
      Amount: Integer := 0;
      Label: Ttk_Label :=
        Get_Widget(pathName => ".itemdialog.errorlbl", Interp => Interp);
      Value: Integer := 0;
      SpinBox: constant Ttk_SpinBox := Get_Widget(CArgv.Arg(Argv, 1), Interp);
      Max_Value: constant Positive :=
        Positive'Value(Widgets.cget(SpinBox, "-to"));
   begin
      if CArgv.Arg(Argv, 3)'Length > 0 then
         for Char of CArgv.Arg(Argv, 3) loop
            if not Is_Decimal_Digit(Char) then
               Tcl_SetResult(Interp, "0");
               return TCL_OK;
            end if;
         end loop;
         Value := Integer'Value(CArgv.Arg(Argv, 3));
      end if;
      if CArgv.Arg(Argv, 1) = ".itemdialog.giveamount" then
         Warning_Text :=
           To_Unbounded_String("You will give amount below low level of ");
      else
         Warning_Text :=
           To_Unbounded_String
             ("You will " & CArgv.Arg(Argv, 4) &
              " amount below low level of ");
      end if;
      if Value < 1 then
         Set(SpinBox, "1");
         Value := 1;
      elsif Value > Max_Value then
         Set(SpinBox, Positive'Image(Max_Value));
         Value := Max_Value;
      end if;
      if Argc > 4 then
         if CArgv.Arg(Argv, 4) = "take" then
            Tcl_SetResult(Interp, "1");
            return TCL_OK;
         elsif CArgv.Arg(Argv, 4) in "buy" | "sell" then
            declare
               Cost: Natural := Value * Positive'Value(CArgv.Arg(Argv, 5));
            begin
               Label := Get_Widget(".itemdialog.costlbl", Interp);
               CountPrice
                 (Cost, FindMember(Talk),
                  (if CArgv.Arg(Argv, 4) = "buy" then True else False));
               configure
                 (Label,
                  "-text {" &
                  (if CArgv.Arg(Argv, 4) = "buy" then "Cost:" else "Gain:") &
                  Natural'Image(Cost) & " " & To_String(Money_Name) & "}");
               if CArgv.Arg(Argv, 4) = "buy" then
                  Tcl_SetResult(Interp, "1");
                  return TCL_OK;
               end if;
            end;
         end if;
      end if;
      Label :=
        Get_Widget(pathName => ".itemdialog.errorlbl", Interp => Interp);
      if Items_List(Player_Ship.Cargo(Cargo_Index).ProtoIndex).IType =
        Fuel_Type then
         Amount := GetItemAmount(Fuel_Type) - Value;
         if Amount <= Game_Settings.Low_Fuel then
            Widgets.configure
              (Label, "-text {" & To_String(Warning_Text) & "fuel.}");
            Tcl.Tk.Ada.Grid.Grid(Label);
            Tcl_SetResult(Interp, "1");
            return TCL_OK;
         end if;
      end if;
      Check_Food_And_Drinks_Loop :
      for Member of Player_Ship.Crew loop
         if Factions_List(Member.Faction).DrinksTypes.Contains
             (Items_List(Player_Ship.Cargo(Cargo_Index).ProtoIndex).IType) then
            Amount := GetItemsAmount("Drinks") - Value;
            if Amount <= Game_Settings.Low_Drinks then
               Widgets.configure
                 (Label, "-text {" & To_String(Warning_Text) & "drinks.}");
               Tcl.Tk.Ada.Grid.Grid(Label);
               Tcl_SetResult(Interp, "1");
               return TCL_OK;
            end if;
            exit Check_Food_And_Drinks_Loop;
         elsif Factions_List(Member.Faction).FoodTypes.Contains
             (Items_List(Player_Ship.Cargo(Cargo_Index).ProtoIndex).IType) then
            Amount := GetItemsAmount("Food") - Value;
            if Amount <= Game_Settings.Low_Food then
               Widgets.configure
                 (Label, "-text {" & To_String(Warning_Text) & "food.}");
               Tcl.Tk.Ada.Grid.Grid(Label);
               Tcl_SetResult(Interp, "1");
               return TCL_OK;
            end if;
            exit Check_Food_And_Drinks_Loop;
         end if;
      end loop Check_Food_And_Drinks_Loop;
      Tcl.Tk.Ada.Grid.Grid_Remove(Label);
      Tcl_SetResult(Interp, "1");
      return TCL_OK;
   exception
      when Constraint_Error =>
         Tcl_SetResult(Interp, "0");
         return TCL_OK;
   end Check_Amount_Command;

   -- ****o* UUI/UUI.Validate_Amount_Command
   -- PARAMETERS
   -- Validate amount of the item when button to increase or decrease the
   -- amount was pressed
   -- ClientData - Custom data send to the command.
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command.
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ValidateAmount name
   -- Name is the name of spinbox which value will be validated
   -- SOURCE
   function Validate_Amount_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Validate_Amount_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      SpinBox: constant Ttk_SpinBox := Get_Widget(CArgv.Arg(Argv, 1), Interp);
      NewArgv: constant CArgv.Chars_Ptr_Ptr :=
        (if Argc < 4 then Argv & Get(SpinBox)
         elsif Argc = 4 then
           CArgv.Empty & CArgv.Arg(Argv, 0) & CArgv.Arg(Argv, 1) &
           CArgv.Arg(Argv, 2) & Get(SpinBox) & CArgv.Arg(Argv, 3)
         else CArgv.Empty & CArgv.Arg(Argv, 0) & CArgv.Arg(Argv, 1) &
           CArgv.Arg(Argv, 2) & Get(SpinBox) & CArgv.Arg(Argv, 3) &
           CArgv.Arg(Argv, 4));
   begin
      return
        Check_Amount_Command(ClientData, Interp, CArgv.Argc(NewArgv), NewArgv);
   end Validate_Amount_Command;

   -- ****o* UUI/UUI.Set_Text_Variable_Command
   -- FUNCTION
   -- Set the selected Tcl text variable and the proper the Ada its equivalent
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed. Unused
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- SetTextVariable variablename
   -- Variablename is the name of variable to set
   -- SOURCE
   function Set_Text_Variable_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Set_Text_Variable_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      TEntry: constant Ttk_Entry := Get_Widget(".getstring.entry", Interp);
      Value: constant String := Get(TEntry);
      VarName: constant String := CArgv.Arg(Argv, 1);
   begin
      Tcl_SetVar(Interp, VarName, Value);
      if VarName = "shipname" then
         Player_Ship.Name := To_Unbounded_String(Value);
      elsif VarName'Length > 10 and then VarName(1 .. 10) = "modulename" then
         declare
            ModuleIndex: constant Positive :=
              Positive'Value(VarName(11 .. VarName'Last));
         begin
            Player_Ship.Modules(ModuleIndex).Name :=
              To_Unbounded_String(Value);
            Tcl_UnsetVar(Interp, VarName);
            UpdateModulesInfo;
         end;
      elsif VarName'Length > 8 and then VarName(1 .. 8) = "crewname" then
         declare
            CrewIndex: constant Positive :=
              Positive'Value(VarName(9 .. VarName'Last));
         begin
            Player_Ship.Crew(CrewIndex).Name := To_Unbounded_String(Value);
            Tcl_UnsetVar(Interp, VarName);
            UpdateCrewInfo;
         end;
      end if;
      return TCL_OK;
   end Set_Text_Variable_Command;

   -- ****o* UUI/UUI.Process_Question_Command
   -- FUNCTION
   -- Process question from dialog when the player answer Yes there
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ProcessQuestion answer
   -- Answer is the answer set for the selected question
   -- SOURCE
   function Process_Question_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Process_Question_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      Result: constant String := CArgv.Arg(Argv, 1);
   begin
      if Result = "deletesave" then
         declare
         begin
            Delete_File
              (To_String(Save_Directory & Tcl_GetVar(Interp, "deletesave")));
            Tcl_UnsetVar(Interp, "deletesave");
            Tcl_Eval(Interp, "ShowLoadGame");
         end;
      elsif Result = "sethomebase" then
         declare
            TraderIndex: constant Natural := FindMember(Talk);
            Price: Positive := 1_000;
            MoneyIndex2: constant Natural :=
              FindItem(Player_Ship.Cargo, Money_Index);
         begin
            if MoneyIndex2 = 0 then
               ShowMessage
                 (Text =>
                    "You don't have any " & To_String(Money_Name) &
                    " for change ship home base.",
                  Title => "No money");
               return TCL_OK;
            end if;
            CountPrice(Price, TraderIndex);
            if Player_Ship.Cargo(MoneyIndex2).Amount < Price then
               ShowMessage
                 (Text =>
                    "You don't have enough " & To_String(Money_Name) &
                    " for change ship home base.",
                  Title => "No money");
               return TCL_OK;
            end if;
            Player_Ship.Home_Base :=
              SkyMap(Player_Ship.Sky_X, Player_Ship.Sky_Y).BaseIndex;
            UpdateCargo
              (Ship => Player_Ship, CargoIndex => MoneyIndex2,
               Amount => -(Price));
            AddMessage
              ("You changed your ship home base to: " &
               To_String(SkyBases(Player_Ship.Home_Base).Name),
               OtherMessage);
            GainExp(1, Talking_Skill, TraderIndex);
            Update_Game(10);
            ShowSkyMap;
         end;
      elsif Result = "nopilot" then
         WaitForRest;
         declare
            StartsCombat: constant Boolean := CheckForEvent;
            Message: Unbounded_String := Null_Unbounded_String;
         begin
            if not StartsCombat and Game_Settings.Auto_Finish then
               Message := To_Unbounded_String(AutoFinishMissions);
            end if;
            if Message /= Null_Unbounded_String then
               ShowMessage(Text => To_String(Message), Title => "Error");
            end if;
            CenterX := Player_Ship.Sky_X;
            CenterY := Player_Ship.Sky_Y;
            if StartsCombat then
               ShowCombatUI;
            else
               ShowSkyMap;
            end if;
         end;
      elsif Result = "quit" then
         Game_Settings.Messages_Position :=
           Game_Settings.Window_Height -
           Natural'Value(SashPos(Main_Paned, "0"));
         End_Game(True);
         Show_Main_Menu;
      elsif Result = "resign" then
         Death(1, To_Unbounded_String("resignation"), Player_Ship);
         ShowQuestion
           ("You are dead. Would you like to see your game statistics?",
            "showstats");
      elsif Result = "showstats" then
         declare
            Button: constant Ttk_Button :=
              Get_Widget(Game_Header & ".menubutton");
         begin
            Tcl.Tk.Ada.Grid.Grid(Button);
            Widgets.configure(Close_Button, "-command ShowMainMenu");
            Tcl.Tk.Ada.Grid.Grid(Close_Button, "-row 0 -column 1");
            Delete(GameMenu, "3", "4");
            Delete(GameMenu, "6", "14");
            ShowStatistics;
         end;
      elsif Result = "mainmenu" then
         Game_Settings.Messages_Position :=
           Game_Settings.Window_Height -
           Natural'Value(SashPos(Main_Paned, "0"));
         End_Game(False);
         Show_Main_Menu;
      elsif Result = "messages" then
         declare
            TypeBox: constant Ttk_ComboBox :=
              Get_Widget
                (Main_Paned & ".messagesframe.canvas.messages.options.types",
                 Get_Context);
         begin
            ClearMessages;
            Current(TypeBox, "0");
            Tcl_Eval(Get_Context, "ShowLastMessages");
         end;
      elsif Result = "retire" then
         Death
           (1, To_Unbounded_String("retired after finished the game"),
            Player_Ship);
         ShowQuestion
           ("You are dead. Would you like to see your game statistics?",
            "showstats");
      else
         declare
            BaseIndex: constant Positive :=
              SkyMap(Player_Ship.Sky_X, Player_Ship.Sky_Y).BaseIndex;
            Member_Index: constant Positive :=
              Positive'Value(CArgv.Arg(Argv, 1));
         begin
            AddMessage
              ("You dismissed " &
               To_String(Player_Ship.Crew(Member_Index).Name) & ".",
               OrderMessage);
            DeleteMember(Member_Index, Player_Ship);
            SkyBases(BaseIndex).Population :=
              SkyBases(BaseIndex).Population + 1;
            Update_Morale_Loop :
            for I in Player_Ship.Crew.Iterate loop
               UpdateMorale
                 (Player_Ship, Crew_Container.To_Index(I), Get_Random(-5, -1));
            end loop Update_Morale_Loop;
            UpdateCrewInfo;
            UpdateHeader;
            Update_Messages;
         end;
      end if;
      return TCL_OK;
   end Process_Question_Command;

   -- ****o* UUI/UUI.Set_Scrollbar_Bindings_Command
   -- FUNCTION
   -- Assign scrolling events with mouse wheel to the selected vertical
   -- scrollbar from the selected widget
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed. Unused
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- SetScrollbarBindings widget scrollbar
   -- Widget is the widget from which events will be fired, scrollbar is
   -- Ttk::scrollbar which to which bindings will be added
   -- SOURCE
   function Set_Scrollbar_Bindings_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Set_Scrollbar_Bindings_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      Widget: constant Ttk_Frame := Get_Widget(CArgv.Arg(Argv, 1), Interp);
      Scrollbar: constant Ttk_Scrollbar :=
        Get_Widget(CArgv.Arg(Argv, 2), Interp);
   begin
      Bind
        (Widget, "<Button-4>",
         "{if {[winfo ismapped " & Scrollbar & "]} {event generate " &
         Scrollbar & " <Button-4>}}");
      Bind
        (Widget, "<Button-5>",
         "{if {[winfo ismapped " & Scrollbar & "]} {event generate " &
         Scrollbar & " <Button-5>}}");
      Bind
        (Widget, "<MouseWheel>",
         "{if {[winfo ismapped " & Scrollbar & "]} {event generate " &
         Scrollbar & " <MouseWheel>}}");
      return TCL_OK;
   end Set_Scrollbar_Bindings_Command;

   function Show_On_Map_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc);
   begin
      CenterX := Positive'Value(CArgv.Arg(Argv, 1));
      CenterY := Positive'Value(CArgv.Arg(Argv, 2));
      Entry_Configure(GameMenu, "Help", "-command {ShowHelp general}");
      Tcl_Eval(Interp, "InvokeButton " & Close_Button);
      Tcl.Tk.Ada.Grid.Grid_Remove(Close_Button);
      return TCL_OK;
   end Show_On_Map_Command;

   function Set_Destination_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Client_Data, Argc);
   begin
      if Positive'Value(CArgv.Arg(Argv, 1)) = Player_Ship.Sky_X and
        Positive'Value(CArgv.Arg(Argv, 2)) = Player_Ship.Sky_Y then
         ShowMessage
           (Text => "You are at this location now.",
            Title => "Can't set destination");
         return TCL_OK;
      end if;
      Player_Ship.Destination_X := Positive'Value(CArgv.Arg(Argv, 1));
      Player_Ship.Destination_Y := Positive'Value(CArgv.Arg(Argv, 2));
      AddMessage
        ("You set the travel destination for your ship.", OrderMessage);
      Entry_Configure(GameMenu, "Help", "-command {ShowHelp general}");
      Tcl_Eval(Interp, "InvokeButton " & Close_Button);
      Tcl.Tk.Ada.Grid.Grid_Remove(Close_Button);
      return TCL_OK;
   end Set_Destination_Command;

   procedure Add_Commands is
   begin
      Add_Command("ResizeCanvas", Resize_Canvas_Command'Access);
      Add_Command("CheckAmount", Check_Amount_Command'Access);
      Add_Command("ValidateAmount", Validate_Amount_Command'Access);
      Add_Command("SetTextVariable", Set_Text_Variable_Command'Access);
      Add_Command("ProcessQuestion", Process_Question_Command'Access);
      Add_Command
        ("SetScrollbarBindings", Set_Scrollbar_Bindings_Command'Access);
      Add_Command("ShowOnMap", Show_On_Map_Command'Access);
      Add_Command("SetDestination2", Set_Destination_Command'Access);
   end Add_Commands;

   procedure Minutes_To_Date
     (Minutes: Natural; Info_Text: in out Unbounded_String) with
      SPARK_Mode
   is
      TravelTime: Date_Record := (others => 0);
      MinutesDiff: Integer := Minutes;
   begin
      Count_Time_Loop :
      while MinutesDiff > 0 loop
         pragma Loop_Invariant
           (TravelTime.Year < 4_000_000 and TravelTime.Month < 13 and
            TravelTime.Day < 32 and TravelTime.Hour < 24);
         if MinutesDiff >= 518_400 then
            TravelTime.Year := TravelTime.Year + 1;
            MinutesDiff := MinutesDiff - 518_400;
         elsif MinutesDiff >= 43_200 then
            TravelTime.Month := TravelTime.Month + 1;
            if TravelTime.Month > 12 then
               TravelTime.Month := 1;
               TravelTime.Year := TravelTime.Year + 1;
            end if;
            MinutesDiff := MinutesDiff - 43_200;
         elsif MinutesDiff >= 1_440 then
            TravelTime.Day := TravelTime.Day + 1;
            if TravelTime.Day > 31 then
               TravelTime.Day := 1;
               TravelTime.Month := TravelTime.Month + 1;
               if TravelTime.Month > 12 then
                  TravelTime.Month := 1;
                  TravelTime.Year := TravelTime.Year + 1;
               end if;
            end if;
            MinutesDiff := MinutesDiff - 1_440;
         elsif MinutesDiff >= 60 then
            TravelTime.Hour := TravelTime.Hour + 1;
            if TravelTime.Hour > 23 then
               TravelTime.Hour := 0;
               TravelTime.Day := TravelTime.Day + 1;
               if TravelTime.Day > 31 then
                  TravelTime.Day := 1;
                  TravelTime.Month := TravelTime.Month + 1;
                  if TravelTime.Month > 12 then
                     TravelTime.Month := 1;
                     TravelTime.Year := TravelTime.Year + 1;
                  end if;
               end if;
            end if;
            MinutesDiff := MinutesDiff - 60;
         else
            TravelTime.Minutes := MinutesDiff;
            MinutesDiff := 0;
         end if;
         exit Count_Time_Loop when TravelTime.Year = 4_000_000;
      end loop Count_Time_Loop;
      if TravelTime.Year > 0
        and then Length(Info_Text) <
          Natural'Last - (Positive'Image(TravelTime.Year)'Length + 1) then
         Append(Info_Text, Positive'Image(TravelTime.Year) & "y");
      end if;
      if TravelTime.Month > 0
        and then Length(Info_Text) <
          Natural'Last - (Positive'Image(TravelTime.Month)'Length + 1) then
         Append(Info_Text, Positive'Image(TravelTime.Month) & "m");
      end if;
      if TravelTime.Day > 0
        and then Length(Info_Text) <
          Natural'Last - (Positive'Image(TravelTime.Day)'Length + 1) then
         Append(Info_Text, Positive'Image(TravelTime.Day) & "d");
      end if;
      if TravelTime.Hour > 0
        and then Length(Info_Text) <
          Natural'Last - (Positive'Image(TravelTime.Hour)'Length + 1) then
         Append(Info_Text, Positive'Image(TravelTime.Hour) & "h");
      end if;
      if TravelTime.Minutes > 0
        and then Length(Info_Text) <
          Natural'Last - (Positive'Image(TravelTime.Minutes)'Length + 4) then
         Append(Info_Text, Positive'Image(TravelTime.Minutes) & "mins");
      end if;
   end Minutes_To_Date;

   procedure Travel_Info
     (Info_Text: in out Unbounded_String; Distance: Positive;
      Show_Fuel_Name: Boolean := False) is
      type SpeedType is digits 2;
      Speed: constant SpeedType :=
        (SpeedType(RealSpeed(Player_Ship, True)) / 1_000.0);
      MinutesDiff: Integer;
      Rests, CabinIndex, RestTime: Natural := 0;
      Damage: Damage_Factor := 0.0;
      Tired, CabinBonus, TempTime: Natural;
   begin
      if Speed = 0.0 then
         Append(Info_Text, LF & "ETA: Never");
         return;
      end if;
      MinutesDiff := Integer(100.0 / Speed);
      case Player_Ship.Speed is
         when QUARTER_SPEED =>
            if MinutesDiff < 60 then
               MinutesDiff := 60;
            end if;
         when HALF_SPEED =>
            if MinutesDiff < 30 then
               MinutesDiff := 30;
            end if;
         when FULL_SPEED =>
            if MinutesDiff < 15 then
               MinutesDiff := 15;
            end if;
         when others =>
            null;
      end case;
      Append(Info_Text, LF & "ETA:");
      MinutesDiff := MinutesDiff * Distance;
      Count_Rest_Time_Loop :
      for I in Player_Ship.Crew.Iterate loop
         if Player_Ship.Crew(I).Order = Pilot or
           Player_Ship.Crew(I).Order = Engineer then
            Tired := (MinutesDiff / 15) + Player_Ship.Crew(I).Tired;
            if
              (Tired /
               (80 +
                Player_Ship.Crew(I).Attributes(Integer(Condition_Index))(1))) >
              Rests then
               Rests :=
                 (Tired /
                  (80 +
                   Player_Ship.Crew(I).Attributes(Integer(Condition_Index))
                     (1)));
            end if;
            if Rests > 0 then
               CabinIndex := FindCabin(Crew_Container.To_Index(I));
               if CabinIndex > 0 then
                  Damage :=
                    1.0 -
                    Damage_Factor
                      (Float(Player_Ship.Modules(CabinIndex).Durability) /
                       Float(Player_Ship.Modules(CabinIndex).Max_Durability));
                  CabinBonus :=
                    Player_Ship.Modules(CabinIndex).Cleanliness -
                    Natural
                      (Float(Player_Ship.Modules(CabinIndex).Cleanliness) *
                       Float(Damage));
                  if CabinBonus = 0 then
                     CabinBonus := 1;
                  end if;
                  TempTime :=
                    ((80 +
                      Player_Ship.Crew(I).Attributes(Integer(Condition_Index))
                        (1)) /
                     CabinBonus) *
                    15;
                  if TempTime = 0 then
                     TempTime := 15;
                  end if;
               else
                  TempTime :=
                    (80 +
                     Player_Ship.Crew(I).Attributes(Integer(Condition_Index))
                       (1)) *
                    15;
               end if;
               TempTime := TempTime + 15;
               if TempTime > RestTime then
                  RestTime := TempTime;
               end if;
            end if;
         end if;
      end loop Count_Rest_Time_Loop;
      MinutesDiff := MinutesDiff + (Rests * RestTime);
      Minutes_To_Date(MinutesDiff, Info_Text);
      Append
        (Info_Text,
         LF & "Approx fuel usage:" &
         Natural'Image
           (abs (Distance * CountFuelNeeded) + (Rests * (RestTime / 10))) &
         " ");
      if Show_Fuel_Name then
         Append
           (Info_Text, Items_List(FindProtoItem(ItemType => Fuel_Type)).Name);
      end if;
   end Travel_Info;

   procedure Update_Messages is
      LoopStart: Integer := 0 - MessagesAmount;
      Message: Message_Data;
      TagNames: constant array(1 .. 5) of Unbounded_String :=
        (To_Unbounded_String("yellow"), To_Unbounded_String("green"),
         To_Unbounded_String("red"), To_Unbounded_String("blue"),
         To_Unbounded_String("cyan"));
      MessagesView: constant Tk_Text :=
        Get_Widget(".gameframe.paned.controls.messages.view");
      procedure ShowMessage is
      begin
         if Message.Color = WHITE then
            Insert
              (MessagesView, "end", "{" & To_String(Message.Message) & "}");
         else
            Insert
              (MessagesView, "end",
               "{" & To_String(Message.Message) & "} [list " &
               To_String(TagNames(Message_Color'Pos(Message.Color))) & "]");
         end if;
      end ShowMessage;
   begin
      Tcl.Tk.Ada.Widgets.configure(MessagesView, "-state normal");
      Delete(MessagesView, "1.0", "end");
      if LoopStart = 0 then
         return;
      end if;
      if LoopStart < -10 then
         LoopStart := -10;
      end if;
      if Game_Settings.Messages_Order = OLDER_FIRST then
         Show_Older_First_Loop :
         for I in LoopStart .. -1 loop
            Message := GetMessage(I + 1);
            ShowMessage;
            if I < -1 then
               Insert(MessagesView, "end", "{" & LF & "}");
            end if;
         end loop Show_Older_First_Loop;
         Tcl_Eval(Get_Context, "update");
         See(MessagesView, "end");
      else
         Show_Newer_First_Loop :
         for I in reverse LoopStart .. -1 loop
            Message := GetMessage(I + 1);
            ShowMessage;
            if I > LoopStart then
               Insert(MessagesView, "end", "{" & LF & "}");
            end if;
         end loop Show_Newer_First_Loop;
      end if;
      Tcl.Tk.Ada.Widgets.configure(MessagesView, "-state disable");
   end Update_Messages;

   procedure Show_Screen(New_Screen_Name: String) is
      SubWindow, OldSubWindow: Ttk_Frame;
      SubWindows: Unbounded_String;
      MessagesFrame: constant Ttk_Frame :=
        Get_Widget(Main_Paned & ".controls.messages");
      Paned: constant Ttk_PanedWindow :=
        Get_Widget(Main_Paned & ".controls.buttons");
   begin
      SubWindows := To_Unbounded_String(Panes(Main_Paned));
      OldSubWindow :=
        (if Index(SubWindows, " ") = 0 then Get_Widget(To_String(SubWindows))
         else Get_Widget(Slice(SubWindows, 1, Index(SubWindows, " "))));
      Forget(Main_Paned, OldSubWindow);
      SubWindow.Name := New_String(".gameframe.paned." & New_Screen_Name);
      Insert(Main_Paned, "0", SubWindow, "-weight 1");
      if New_Screen_Name in "optionsframe" | "messagesframe" or
        not Game_Settings.Show_Last_Messages then
         Tcl.Tk.Ada.Grid.Grid_Remove(MessagesFrame);
         if New_Screen_Name /= "mapframe" then
            SashPos(Main_Paned, "0", Winfo_Get(Main_Paned, "height"));
         end if;
      else
         if Trim(Widget_Image(OldSubWindow), Both) in
             Main_Paned & ".messagesframe" | Main_Paned & ".optionsframe" then
            SashPos
              (Main_Paned, "0",
               Natural'Image
                 (Game_Settings.Window_Height -
                  Game_Settings.Messages_Position));
         end if;
         Tcl.Tk.Ada.Grid.Grid(MessagesFrame);
      end if;
      if New_Screen_Name = "mapframe" then
         Tcl.Tk.Ada.Grid.Grid(Paned);
      else
         Tcl.Tk.Ada.Grid.Grid_Remove(Paned);
      end if;
   end Show_Screen;

   procedure Show_Inventory_Item_Info
     (Parent: String; Item_Index: Positive; Member_Index: Natural) is
      ProtoIndex, ItemInfo: Unbounded_String;
      ItemTypes: constant array(1 .. 6) of Unbounded_String :=
        (Weapon_Type, Chest_Armor, Head_Armor, Arms_Armor, Legs_Armor,
         Shield_Type);
      use Tiny_String;
   begin
      if Member_Index > 0 then
         ProtoIndex :=
           Player_Ship.Crew(Member_Index).Inventory(Item_Index).ProtoIndex;
         if Player_Ship.Crew(Member_Index).Inventory(Item_Index).Durability <
           Default_Item_Durability then
            Append
              (ItemInfo,
               GetItemDamage
                 (Player_Ship.Crew(Member_Index).Inventory(Item_Index)
                    .Durability) &
               LF);
         end if;
      else
         ProtoIndex := Player_Ship.Cargo(Item_Index).ProtoIndex;
         if Player_Ship.Cargo(Item_Index).Durability <
           Default_Item_Durability then
            Append
              (ItemInfo,
               GetItemDamage(Player_Ship.Cargo(Item_Index).Durability) & LF);
         end if;
      end if;
      Append
        (ItemInfo,
         "Weight:" & Positive'Image(Items_List(ProtoIndex).Weight) & " kg");
      if Items_List(ProtoIndex).IType = Weapon_Type then
         Append
           (ItemInfo,
            LF & "Skill: " &
            To_String
              (SkillsData_Container.Element
                 (Skills_List, Items_List(ProtoIndex).Value(3))
                 .Name) &
            "/" &
            To_String
              (AttributesData_Container.Element
                 (Attributes_List,
                  (SkillsData_Container.Element
                     (Skills_List, Items_List(ProtoIndex).Value(3))
                     .Attribute))
                 .Name));
         if Items_List(ProtoIndex).Value(4) = 1 then
            Append(ItemInfo, LF & "Can be used with shield.");
         else
            Append
              (ItemInfo,
               LF & "Can't be used with shield (two-handed weapon).");
         end if;
         Append
           (ItemInfo,
            LF & "Damage type: " &
            (case Items_List(ProtoIndex).Value(5) is when 1 => "cutting",
               when 2 => "impaling", when 3 => "blunt", when others => ""));
      end if;
      Show_More_Item_Info_Loop :
      for ItemType of ItemTypes loop
         if Items_List(ProtoIndex).IType = ItemType then
            Append
              (ItemInfo,
               LF & "Damage chance: " & LF & "Strength:" &
               Integer'Image(Items_List(ProtoIndex).Value(2)));
            exit Show_More_Item_Info_Loop;
         end if;
      end loop Show_More_Item_Info_Loop;
      if Tools_List.Contains(Items_List(ProtoIndex).IType) then
         Append
           (ItemInfo,
            LF & "Damage chance: " &
            GetItemChanceToDamage(Items_List(ProtoIndex).Value(1)));
      end if;
      if Length(Items_List(ProtoIndex).IType) > 4
        and then
        (Slice(Items_List(ProtoIndex).IType, 1, 4) = "Ammo" or
         Items_List(ProtoIndex).IType = To_Unbounded_String("Harpoon")) then
         Append
           (ItemInfo,
            LF & "Strength:" & Integer'Image(Items_List(ProtoIndex).Value(1)));
      end if;
      if Items_List(ProtoIndex).Description /= Null_Unbounded_String then
         Append
           (ItemInfo, LF & LF & To_String(Items_List(ProtoIndex).Description));
      end if;
      if Parent = "." then
         ShowInfo
           (Text => To_String(ItemInfo),
            Title =>
              (if Member_Index > 0 then
                 GetItemName
                   (Player_Ship.Crew(Member_Index).Inventory(Item_Index),
                    False, False)
               else GetItemName(Player_Ship.Cargo(Item_Index), False, False)));
      else
         ShowInfo
           (To_String(ItemInfo), Parent,
            (if Member_Index > 0 then
               GetItemName
                 (Player_Ship.Crew(Member_Index).Inventory(Item_Index), False,
                  False)
             else GetItemName(Player_Ship.Cargo(Item_Index), False, False)));
      end if;
   end Show_Inventory_Item_Info;

   procedure Delete_Widgets
     (Start_Index, End_Index: Integer; Frame: Tk_Widget'Class) is
      Tokens: Slice_Set;
      Item: Ttk_Frame;
   begin
      if End_Index < Start_Index then
         return;
      end if;
      Delete_Widgets_Loop :
      for I in Start_Index .. End_Index loop
         Create
           (Tokens,
            Tcl.Tk.Ada.Grid.Grid_Slaves(Frame, "-row" & Positive'Image(I)),
            " ");
         Delete_Row_Loop :
         for J in 1 .. Slice_Count(Tokens) loop
            Item := Get_Widget(Slice(Tokens, J));
            Destroy(Item);
         end loop Delete_Row_Loop;
      end loop Delete_Widgets_Loop;
   end Delete_Widgets;

end Utils.UI;
