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

with Ada.Characters.Latin_1; use Ada.Characters.Latin_1;
with Ada.Strings; use Ada.Strings;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Tcl.Ada; use Tcl.Ada;
with Tcl.Tk.Ada; use Tcl.Tk.Ada;
with Tcl.Tk.Ada.Grid;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.TtkButton; use Tcl.Tk.Ada.Widgets.TtkButton;
with Tcl.Tk.Ada.Widgets.TtkEntry.TtkSpinBox;
use Tcl.Tk.Ada.Widgets.TtkEntry.TtkSpinBox;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Tcl.Tk.Ada.Widgets.TtkLabel; use Tcl.Tk.Ada.Widgets.TtkLabel;
with Tcl.Tk.Ada.Winfo; use Tcl.Tk.Ada.Winfo;
with Tcl.Tklib.Ada.Tooltip; use Tcl.Tklib.Ada.Tooltip;
with CoreUI; use CoreUI;
with Crew; use Crew;
with Dialogs; use Dialogs;
with Game; use Game;
with Maps.UI; use Maps.UI;
with Ships; use Ships;
with Ships.Movement; use Ships.Movement;
with Utils.UI; use Utils.UI;

package body WaitMenu is

   function Show_Wait_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
      WaitDialog: Ttk_Frame := Get_Widget(".gameframe.wait", Interp);
      Button: Ttk_Button;
      AmountBox: Ttk_SpinBox;
      AmountLabel: Ttk_Label;
      NeedHealing, NeedRest: Boolean := False;
      procedure AddButton(Time: Positive) is
      begin
         Button :=
           Create
             (WaitDialog & ".wait" & Trim(Positive'Image(Time), Left),
              "-text {Wait" & Positive'Image(Time) & " minute" &
              (if Time > 1 then "s" else "") & "} -command {Wait" &
              Positive'Image(Time) & "}");
         Tcl.Tk.Ada.Grid.Grid
           (Button,
            "-sticky we -columnspan 3 -padx 5" &
            (if Time = 1 then " -pady {5 0}" else ""));
         Bind(Button, "<Escape>", "{CloseDialog " & WaitDialog & ";break}");
         Add
           (Button,
            "Wait in place for" & Positive'Image(Time) & " minute" &
            (if Time > 1 then "s" else ""));
      end AddButton;
   begin
      if Winfo_Get(WaitDialog, "exists") = "1" then
         Button := Get_Widget(WaitDialog & ".frame.close");
         if Invoke(Button) /= "" then
            return TCL_ERROR;
         end if;
         return TCL_OK;
      end if;
      WaitDialog :=
        Create_Dialog
          (Name => ".gameframe.wait", Title => "Wait in place", Columns => 3);
      AddButton(1);
      AddButton(5);
      AddButton(10);
      AddButton(15);
      AddButton(30);
      Button :=
        Create
          (WaitDialog & ".wait1h", "-text {Wait 1 hour} -command {Wait 60}");
      Tcl.Tk.Ada.Grid.Grid(Button, "-sticky we -columnspan 3 -padx 5");
      Add(Button, "Wait in place for 1 hour");
      Bind(Button, "<Escape>", "{CloseDialog " & WaitDialog & ";break}");
      Button :=
        Create(WaitDialog & ".wait", "-text Wait  -command {Wait amount}");
      Tcl.Tk.Ada.Grid.Grid(Button, "-padx {5 0}");
      Bind(Button, "<Escape>", "{CloseDialog " & WaitDialog & ";break}");
      Add
        (Button,
         "Wait in place for the selected amount of minutes:" & LF &
         "from 1 to 1440 (the whole day)");
      AmountBox :=
        Create
          (WaitDialog & ".amount",
           "-from 1.0 -to 1440 -width 6 -validate key -validatecommand {ValidateSpinbox %W %P}");
      Tcl.Tk.Ada.Grid.Grid(AmountBox, "-row 7 -column 1");
      Bind(AmountBox, "<Escape>", "{CloseDialog " & WaitDialog & ";break}");
      Set(AmountBox, "1");
      Add
        (AmountBox,
         "Wait in place for the selected amount of minutes:" & LF &
         "from 1 to 1440 (the whole day)");
      AmountLabel :=
        Create(WaitDialog & ".mins", "-text minutes. -takefocus 0");
      Tcl.Tk.Ada.Grid.Grid(AmountLabel, "-row 7 -column 2 -padx {0 5}");
      Check_Crew_Rest_Loop :
      for I in Player_Ship.Crew.First_Index .. Player_Ship.Crew.Last_Index loop
         if Player_Ship.Crew(I).Tired > 0 and
           Player_Ship.Crew(I).Order = REST then
            NeedRest := True;
         end if;
         if Player_Ship.Crew(I).Health in 1 .. 99 and
           Player_Ship.Crew(I).Order = REST then
            Modules_Loop :
            for Module of Player_Ship.Modules loop
               if Module.M_Type = CABIN then
                  for Owner of Module.Owner loop
                     if Owner = I then
                        NeedHealing := True;
                        exit Modules_Loop;
                     end if;
                  end loop;
               end if;
            end loop Modules_Loop;
         end if;
      end loop Check_Crew_Rest_Loop;
      if NeedRest then
         Button :=
           Create
             (WaitDialog & ".rest",
              "-text {Wait until crew is rested} -command {Wait rest}");
         Tcl.Tk.Ada.Grid.Grid(Button, "-sticky we -columnspan 3 -padx 5");
         Bind(Button, "<Escape>", "{CloseDialog " & WaitDialog & ";break}");
         Add(Button, "Wait in place until the whole ship's crew is rested.");
      end if;
      if NeedHealing then
         Button :=
           Create
             (WaitDialog & ".heal",
              "-text {Wait until crew is healed} -command {Wait heal}");
         Tcl.Tk.Ada.Grid.Grid(Button, "-sticky we -columnspan 3 -padx 5");
         Bind(Button, "<Escape>", "{CloseDialog " & WaitDialog & ";break}");
         Add
           (Button,
            "Wait in place until the whole ship's crew is healed." & LF &
            "Can take a large amount of time.");
      end if;
      Button :=
        Create
          (WaitDialog & ".close",
           "-text {Close} -command {CloseDialog " & WaitDialog & "}");
      Tcl.Tk.Ada.Grid.Grid
        (Button, "-sticky we -columnspan 3 -padx 5 -pady {0 5}");
      Bind(Button, "<Escape>", "{CloseDialog " & WaitDialog & ";break}");
      Add(Button, "Close dialog \[Escape\]");
      Focus(Button);
      Bind(Button, "<Tab>", "{focus " & WaitDialog & ".wait1;break}");
      Show_Dialog(Dialog => WaitDialog, Relative_Y => 0.15);
      return TCL_OK;
   end Show_Wait_Command;

   -- ****o* WaitMenu/WaitMenu.Wait_Command
   -- FUNCTION
   -- Wait the selected amount of time
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- Wait
   -- SOURCE
   function Wait_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Wait_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      TimeNeeded: Natural := 0;
      CloseButton: constant Ttk_Button :=
        Get_Widget(".gameframe.wait.close", Interp);
      AmountBox: constant Ttk_SpinBox :=
        Get_Widget(".gameframe.wait.amount", Interp);
      CurrentFrame: Ttk_Frame :=
        Get_Widget(Main_Paned & ".shipinfoframe", Interp);
   begin
      if CArgv.Arg(Argv, 1) = "1" then
         Update_Game(1);
         Wait_In_Place(1);
      elsif CArgv.Arg(Argv, 1) = "5" then
         Update_Game(5);
         Wait_In_Place(5);
      elsif CArgv.Arg(Argv, 1) = "10" then
         Update_Game(10);
         Wait_In_Place(10);
      elsif CArgv.Arg(Argv, 1) = "15" then
         Update_Game(15);
         Wait_In_Place(15);
      elsif CArgv.Arg(Argv, 1) = "30" then
         Update_Game(30);
         Wait_In_Place(30);
      elsif CArgv.Arg(Argv, 1) = "60" then
         Update_Game(60);
         Wait_In_Place(60);
      elsif CArgv.Arg(Argv, 1) = "rest" then
         Wait_For_Rest;
      elsif CArgv.Arg(Argv, 1) = "heal" then
         Check_Crew_Heal_Loop :
         for I in Player_Ship.Crew.Iterate loop
            if Player_Ship.Crew(I).Health in 1 .. 99 and
              Player_Ship.Crew(I).Order = REST then
               Modules_Loop :
               for Module of Player_Ship.Modules loop
                  if Module.M_Type = CABIN then
                     for Owner of Module.Owner loop
                        if Owner = Crew_Container.To_Index(I) then
                           if TimeNeeded <
                             (100 - Player_Ship.Crew(I).Health) * 15 then
                              TimeNeeded :=
                                (100 - Player_Ship.Crew(I).Health) * 15;
                           end if;
                           exit Modules_Loop;
                        end if;
                     end loop;
                  end if;
               end loop Modules_Loop;
            end if;
         end loop Check_Crew_Heal_Loop;
         if TimeNeeded > 0 then
            Update_Game(TimeNeeded);
            Wait_In_Place(TimeNeeded);
         else
            return TCL_OK;
         end if;
      elsif CArgv.Arg(Argv, 1) = "amount" then
         Update_Game(Positive'Value(Get(AmountBox)));
         Wait_In_Place(Positive'Value(Get(AmountBox)));
      end if;
      Update_Header;
      Update_Messages;
      if Winfo_Get(CurrentFrame, "exists") = "1"
        and then Winfo_Get(CurrentFrame, "ismapped") = "1" then
         Tcl_Eval(Interp, "ShowShipInfo 1");
      else
         CurrentFrame := Get_Widget(Main_Paned & ".knowledgeframe", Interp);
         if Winfo_Get(CurrentFrame, "exists") = "1"
           and then Winfo_Get(CurrentFrame, "ismapped") = "1" then
            Tcl_Eval(Interp, "ShowKnowledge 1");
         else
            Draw_Map;
         end if;
      end if;
      if Invoke(CloseButton) /= "" then
         return TCL_ERROR;
      end if;
      return TCL_OK;
   end Wait_Command;

   procedure AddCommands is
   begin
      Add_Command("ShowWait", Show_Wait_Command'Access);
      Add_Command("Wait", Wait_Command'Access);
   end AddCommands;

end WaitMenu;
