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

with Ada.Characters.Latin_1; use Ada.Characters.Latin_1;
with Ada.Exceptions; use Ada.Exceptions;
with Ada.Strings; use Ada.Strings;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Interfaces.C; use Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with CArgv;
with Tcl; use Tcl;
with Tcl.Ada; use Tcl.Ada;
with Tcl.Tk.Ada; use Tcl.Tk.Ada;
with Tcl.Tk.Ada.Font; use Tcl.Tk.Ada.Font;
with Tcl.Tk.Ada.Grid;
with Tcl.Tk.Ada.Pack;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.Canvas; use Tcl.Tk.Ada.Widgets.Canvas;
with Tcl.Tk.Ada.Widgets.Menu; use Tcl.Tk.Ada.Widgets.Menu;
with Tcl.Tk.Ada.Widgets.Text; use Tcl.Tk.Ada.Widgets.Text;
with Tcl.Tk.Ada.Widgets.Toplevel; use Tcl.Tk.Ada.Widgets.Toplevel;
with Tcl.Tk.Ada.Widgets.Toplevel.MainWindow;
use Tcl.Tk.Ada.Widgets.Toplevel.MainWindow;
with Tcl.Tk.Ada.Widgets.TtkButton; use Tcl.Tk.Ada.Widgets.TtkButton;
with Tcl.Tk.Ada.Widgets.TtkButton.TtkCheckButton;
use Tcl.Tk.Ada.Widgets.TtkButton.TtkCheckButton;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Tcl.Tk.Ada.Widgets.TtkLabel; use Tcl.Tk.Ada.Widgets.TtkLabel;
with Tcl.Tk.Ada.Widgets.TtkProgressBar; use Tcl.Tk.Ada.Widgets.TtkProgressBar;
with Tcl.Tk.Ada.Widgets.TtkScrollbar; use Tcl.Tk.Ada.Widgets.TtkScrollbar;
with Tcl.Tk.Ada.Widgets.TtkWidget; use Tcl.Tk.Ada.Widgets.TtkWidget;
with Tcl.Tk.Ada.Winfo; use Tcl.Tk.Ada.Winfo;
with Tcl.Tklib.Ada.Autoscroll; use Tcl.Tklib.Ada.Autoscroll;
with Tcl.Tklib.Ada.Tooltip; use Tcl.Tklib.Ada.Tooltip;
with Config; use Config;
with CoreUI; use CoreUI;
with Crafts; use Crafts;
with Dialogs; use Dialogs;
with Factions; use Factions;
with Maps; use Maps;
with Maps.UI; use Maps.UI;
with Messages; use Messages;
with Missions; use Missions;
with ShipModules; use ShipModules;
with Ships.Cargo; use Ships.Cargo;
with Ships.Crew; use Ships.Crew;
with Ships.UI.Crew; use Ships.UI.Crew;
with Ships.Upgrade; use Ships.Upgrade;
with Table; use Table;
with Utils.UI; use Utils.UI;

package body Ships.UI.Modules is

   -- ****iv* SUI2/SUI2.ModulesTable
   -- FUNCTION
   -- Table with info about the installed modules on the player ship
   -- SOURCE
   ModulesTable: Table_Widget (2);
   -- ****

   -- ****iv* SUI/SUI.Modules_Indexes
   -- FUNCTION
   -- Indexes of the player ship modules
   -- SOURCE
   Modules_Indexes: Positive_Container.Vector;
   -- ****

   -- ****if* SUModules/SUModules.Show_Module_Menu_Command
   -- FUNCTION
   -- Show the menu with available the selected module options
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowModuleMenu moduleindex
   -- ModuleIndex is the index of the module's menu to show
   -- SOURCE
   function Show_Module_Menu_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Module_Menu_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      MaxValue: Positive;
      IsPassenger: Boolean := False;
      ModuleIndex: constant Positive := Positive'Value(CArgv.Arg(Argv, 1));
      ModuleMenu: Tk_Menu := Get_Widget(".modulemenu", Interp);
   begin
      if Winfo_Get(ModuleMenu, "exists") = "0" then
         ModuleMenu := Create(".modulemenu", "-tearoff false");
      end if;
      Delete(ModuleMenu, "0", "end");
      Menu.Add
        (ModuleMenu, "command",
         "-label {Rename module} -command {GetString {Enter a new name for the " &
         To_String(Player_Ship.Modules(ModuleIndex).Name) & ":} modulename" &
         CArgv.Arg(Argv, 1) & " {Renaming the module}}");
      if Player_Ship.Repair_Module /= ModuleIndex then
         Menu.Add
           (ModuleMenu, "command",
            "-label {Repair selected module as first when damaged} -command {SetRepair assign " &
            CArgv.Arg(Argv, 1) & "}");
      end if;
      MaxValue :=
        Natural
          (Float
             (Modules_List(Player_Ship.Modules(ModuleIndex).Proto_Index)
                .Durability) *
           1.5);
      if Player_Ship.Modules(ModuleIndex).Upgrade_Action = DURABILITY and
        Player_Ship.Upgrade_Module = ModuleIndex then
         MaxValue := 1;
      end if;
      if Player_Ship.Modules(ModuleIndex).Max_Durability < MaxValue then
         Menu.Add
           (ModuleMenu, "command",
            "-label {Start upgrading module durability} -command {SetUpgrade 1 " &
            CArgv.Arg(Argv, 1) & "}");
      end if;
      case Player_Ship.Modules(ModuleIndex).M_Type is
         when ENGINE =>
            MaxValue :=
              Natural
                (Float
                   (Modules_List(Player_Ship.Modules(ModuleIndex).Proto_Index)
                      .MaxValue) *
                 1.5);
            if Player_Ship.Modules(ModuleIndex).Upgrade_Action = MAX_VALUE and
              Player_Ship.Upgrade_Module = ModuleIndex then
               MaxValue := 1;
            end if;
            if Player_Ship.Modules(ModuleIndex).Power < MaxValue then
               Menu.Add
                 (ModuleMenu, "command",
                  "-label {Start upgrading engine power} -command {SetUpgrade 2 " &
                  CArgv.Arg(Argv, 1) & "}");
            end if;
            MaxValue :=
              Natural
                (Float
                   (Modules_List(Player_Ship.Modules(ModuleIndex).Proto_Index)
                      .Value) /
                 2.0);
            if Player_Ship.Modules(ModuleIndex).Upgrade_Action = VALUE and
              Player_Ship.Upgrade_Module = ModuleIndex then
               MaxValue := Player_Ship.Modules(ModuleIndex).Fuel_Usage + 1;
            end if;
            if Player_Ship.Modules(ModuleIndex).Fuel_Usage > MaxValue then
               Menu.Add
                 (ModuleMenu, "command",
                  "-label {Start working on reduce fuel usage of this engine} -command {SetUpgrade 3 " &
                  CArgv.Arg(Argv, 1) & "}");
            end if;
            if not Player_Ship.Modules(ModuleIndex).Disabled then
               Menu.Add
                 (ModuleMenu, "command",
                  "-label {Turn off engine so it stop using fuel} -command {DisableEngine " &
                  CArgv.Arg(Argv, 1) & "}");
            else
               Menu.Add
                 (ModuleMenu, "command",
                  "-label {Turn on engine so ship will be fly faster} -command {DisableEngine " &
                  CArgv.Arg(Argv, 1) & "}");
            end if;
         when CABIN =>
            MaxValue :=
              Natural
                (Float
                   (Modules_List(Player_Ship.Modules(ModuleIndex).Proto_Index)
                      .MaxValue) *
                 1.5);
            if Player_Ship.Modules(ModuleIndex).Upgrade_Action = MAX_VALUE and
              Player_Ship.Upgrade_Module = ModuleIndex then
               MaxValue := 1;
            end if;
            if Player_Ship.Modules(ModuleIndex).Quality < MaxValue then
               Menu.Add
                 (ModuleMenu, "command",
                  "-label {Start upgrading cabin quality} -command {SetUpgrade 2 " &
                  CArgv.Arg(Argv, 1) & "}");
            end if;
            Missions_Loop :
            for Mission of AcceptedMissions loop
               if Mission.MType = Passenger then
                  for Owner of Player_Ship.Modules(ModuleIndex).Owner loop
                     if Mission.Data = Owner then
                        IsPassenger := True;
                        exit Missions_Loop;
                     end if;
                  end loop;
               end if;
            end loop Missions_Loop;
            if not IsPassenger then
               Menu.Add
                 (ModuleMenu, "command",
                  "-label {Assign a crew member as owner of cabin...} -command {ShowAssignCrew " &
                  CArgv.Arg(Argv, 1) & "}");
            end if;
         when GUN | HARPOON_GUN =>
            declare
               CurrentValue: constant Positive :=
                 (if Player_Ship.Modules(ModuleIndex).M_Type = GUN then
                    Player_Ship.Modules(ModuleIndex).Damage
                  else Player_Ship.Modules(ModuleIndex).Duration);
            begin
               MaxValue :=
                 Natural
                   (Float
                      (Modules_List
                         (Player_Ship.Modules(ModuleIndex).Proto_Index)
                         .MaxValue) *
                    1.5);
               if Player_Ship.Modules(ModuleIndex).Upgrade_Action =
                 MAX_VALUE and
                 Player_Ship.Upgrade_Module = ModuleIndex then
                  MaxValue := 1;
               end if;
               if CurrentValue < MaxValue then
                  if Player_Ship.Modules(ModuleIndex).M_Type = GUN then
                     Menu.Add
                       (ModuleMenu, "command",
                        "-label {Start upgrading damage of gun} -command {SetUpgrade 2 " &
                        CArgv.Arg(Argv, 1) & "}");
                  else
                     Menu.Add
                       (ModuleMenu, "command",
                        "-label {Start upgrading strength of gun} -command {SetUpgrade 2 " &
                        CArgv.Arg(Argv, 1) & "}");
                  end if;
               end if;
            end;
            Menu.Add
              (ModuleMenu, "command",
               "-label {Assign a crew member as gunner...} -command {ShowAssignCrew " &
               CArgv.Arg(Argv, 1) & "}");
            declare
               AmmoIndex: constant Natural :=
                 (if Player_Ship.Modules(ModuleIndex).M_Type = GUN then
                    Player_Ship.Modules(ModuleIndex).Ammo_Index
                  else Player_Ship.Modules(ModuleIndex).Harpoon_Index);
               AmmoMenu: Tk_Menu :=
                 Get_Widget(Widget_Image(ModuleMenu) & ".ammomenu");
               NotEmpty: Boolean := False;
            begin
               if Winfo_Get(AmmoMenu, "exists") = "0" then
                  AmmoMenu :=
                    Create
                      (Widget_Image(ModuleMenu) & ".ammomenu",
                       "-tearoff false");
               end if;
               Delete(AmmoMenu, "0", "end");
               Find_Ammo_Loop :
               for I in
                 Player_Ship.Cargo.First_Index ..
                   Player_Ship.Cargo.Last_Index loop
                  if Items_List(Player_Ship.Cargo(I).ProtoIndex).IType =
                    Items_Types
                      (Modules_List
                         (Player_Ship.Modules(ModuleIndex).Proto_Index)
                         .Value) and
                    I /= AmmoIndex then
                     Menu.Add
                       (AmmoMenu, "command",
                        "-label {" &
                        To_String
                          (Items_List(Player_Ship.Cargo(I).ProtoIndex).Name) &
                        "} -command {AssignModule ammo " & CArgv.Arg(Argv, 1) &
                        Positive'Image(I) & "}");
                     NotEmpty := True;
                  end if;
               end loop Find_Ammo_Loop;
               if NotEmpty then
                  Menu.Add
                    (ModuleMenu, "cascade",
                     "-label {Assign an ammo to gun} -menu " &
                     Widget_Image(AmmoMenu));
               end if;
            end;
         when BATTERING_RAM =>
            MaxValue :=
              Natural
                (Float
                   (Modules_List(Player_Ship.Modules(ModuleIndex).Proto_Index)
                      .MaxValue) *
                 1.5);
            if Player_Ship.Modules(ModuleIndex).Upgrade_Action = MAX_VALUE and
              Player_Ship.Upgrade_Module = ModuleIndex then
               MaxValue := 1;
            end if;
            if Player_Ship.Modules(ModuleIndex).Damage2 < MaxValue then
               Menu.Add
                 (ModuleMenu, "command",
                  "-label {Start upgrading damage of battering ram} -command {SetUpgrade 2 " &
                  CArgv.Arg(Argv, 1) & "}");
            end if;
         when HULL =>
            MaxValue :=
              Natural
                (Float
                   (Modules_List(Player_Ship.Modules(ModuleIndex).Proto_Index)
                      .MaxValue) *
                 1.5);
            if Player_Ship.Modules(ModuleIndex).Upgrade_Action = MAX_VALUE and
              Player_Ship.Upgrade_Module = ModuleIndex then
               MaxValue := 1;
            end if;
            if Player_Ship.Modules(ModuleIndex).Max_Modules < MaxValue then
               Menu.Add
                 (ModuleMenu, "command",
                  "-label {Start enlarging hull so it can have more modules installed} -command {SetUpgrade 2 " &
                  CArgv.Arg(Argv, 1) & "}");
            end if;
         when WORKSHOP =>
            if Player_Ship.Modules(ModuleIndex).Crafting_Index /=
              Null_Unbounded_String then
               Menu.Add
                 (ModuleMenu, "command",
                  "-label {Assign selected crew member as worker...} -command {ShowAssignCrew " &
                  CArgv.Arg(Argv, 1) & "}");
               Menu.Add
                 (ModuleMenu, "command",
                  "-label {Cancel current crafting order} -command {CancelOrder " &
                  CArgv.Arg(Argv, 1) & "}");
            end if;
         when MEDICAL_ROOM =>
            Find_Healing_Tool_Loop :
            for Member of Player_Ship.Crew loop
               if Member.Health < 100 and
                 FindItem
                     (Inventory => Player_Ship.Cargo,
                      ItemType =>
                        Factions_List(Player_Ship.Crew(1).Faction)
                          .HealingTools) >
                   0 then
                  Menu.Add
                    (ModuleMenu, "command",
                     "-label {Assign selected crew member as medic...} -command {ShowAssignCrew " &
                     CArgv.Arg(Argv, 1) & "}");
                  exit Find_Healing_Tool_Loop;
               end if;
            end loop Find_Healing_Tool_Loop;
         when TRAINING_ROOM =>
            if Player_Ship.Modules(ModuleIndex).Trained_Skill > 0 then
               Menu.Add
                 (ModuleMenu, "command",
                  "-label {Assign selected crew member as worker...} -command {ShowAssignCrew " &
                  CArgv.Arg(Argv, 1) & "}");
            end if;
            Menu.Add
              (ModuleMenu, "command",
               "-label {Assign a skill which will be trained in the training room...} -command {ShowAssignSkill " &
               CArgv.Arg(Argv, 1) & "}");
         when others =>
            null;
      end case;
      Menu.Add
        (ModuleMenu, "command",
         "-label {Show more info about the module} -command {ShowModuleInfo " &
         CArgv.Arg(Argv, 1) & "}");
      Tk_Popup
        (ModuleMenu, Winfo_Get(Get_Main_Window(Interp), "pointerx"),
         Winfo_Get(Get_Main_Window(Interp), "pointery"));
      return TCL_OK;
   end Show_Module_Menu_Command;

   -- ****o* SUModules/SUModules.Show_Module_Info_Command
   -- FUNCTION
   -- Show information about the selected module and set option for it
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed. Unused
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowModuleInfo moduleindex
   -- ModuleIndex is the index of the module to show
   -- SOURCE
   function Show_Module_Info_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Module_Info_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Interp, Argc);
      ModuleIndex: constant Positive := Positive'Value(CArgv.Arg(Argv, 1));
      Module: constant Module_Data := Player_Ship.Modules(ModuleIndex);
      MaxValue: Positive;
      HaveAmmo: Boolean;
      Mamount, MaxUpgrade: Natural := 0;
      DamagePercent, UpgradePercent: Float;
      ProgressBar: Ttk_ProgressBar;
      Label: Ttk_Label;
      ModuleInfo, ProgressBarStyle: Unbounded_String;
      ModuleDialog: constant Ttk_Frame :=
        Create_Dialog
          (Name => ".moduledialog",
           Title => To_String(Player_Ship.Modules(ModuleIndex).Name),
           Columns => 2);
      YScroll: constant Ttk_Scrollbar :=
        Create
          (ModuleDialog & ".yscroll",
           "-orient vertical -command [list .moduledialog.canvas yview]");
      ModuleCanvas: constant Tk_Canvas :=
        Create
          (ModuleDialog & ".canvas",
           "-yscrollcommand [list " & YScroll & " set]");
      ModuleFrame: constant Ttk_Frame := Create(ModuleCanvas & ".frame");
      ModuleText: constant Tk_Text :=
        Create(ModuleFrame & ".info", "-wrap char -height 15 -width 40");
      Height: Positive := 10;
      procedure AddOwnersInfo(OwnersName: String) is
         HaveOwner: Boolean := False;
      begin
         Insert(ModuleText, "end", "{" & LF & OwnersName & "}");
         if Module.Owner.Length > 1 then
            Insert(ModuleText, "end", "s");
         end if;
         Insert
           (ModuleText, "end",
            "{ (max" & Count_Type'Image(Module.Owner.Length) & "): }");
         Add_Owners_Info_Loop :
         for I in Module.Owner.First_Index .. Module.Owner.Last_Index loop
            if Module.Owner(I) > 0 then
               if HaveOwner then
                  Insert(ModuleText, "end", "{, }");
               end if;
               HaveOwner := True;
               Insert
                 (ModuleText, "end",
                  To_String(Player_Ship.Crew(Module.Owner(I)).Name));
            end if;
         end loop Add_Owners_Info_Loop;
         if not HaveOwner then
            Insert(ModuleText, "end", "{none}");
         end if;
      end AddOwnersInfo;
   begin
      Tcl.Tk.Ada.Grid.Grid(ModuleCanvas, "-sticky nwes -padx 5 -pady 5");
      Tcl.Tk.Ada.Grid.Grid
        (YScroll, "-sticky ns -column 1 -row 1 -padx {0 5} -pady 5");
      Tcl.Tk.Ada.Grid.Grid_Propagate(ModuleDialog, "off");
      Tcl.Tk.Ada.Grid.Column_Configure
        (ModuleDialog, ModuleCanvas, "-weight 1");
      Tcl.Tk.Ada.Grid.Row_Configure(ModuleDialog, ModuleCanvas, "-weight 1");
      Autoscroll(YScroll);
      if Module.Durability < Module.Max_Durability then
         Label := Create(ModuleFrame & ".damagelbl");
         DamagePercent :=
           (Float(Module.Durability) / Float(Module.Max_Durability));
         if DamagePercent < 1.0 and DamagePercent > 0.79 then
            configure(Label, "-text {Status: Slightly damaged}");
         elsif DamagePercent < 0.8 and DamagePercent > 0.49 then
            configure(Label, "-text {Status: Damaged}");
         elsif DamagePercent < 0.5 and DamagePercent > 0.19 then
            configure(Label, "-text {Status: Heavily damaged}");
         elsif DamagePercent < 0.2 and DamagePercent > 0.0 then
            configure(Label, "-text {Status: Almost destroyed}");
         elsif DamagePercent = 0.0 then
            configure(Label, "-text {Status: Destroyed}");
         end if;
         Tcl.Tk.Ada.Grid.Grid(Label, "-sticky w");
         Height := Height + Positive'Value(Winfo_Get(Label, "reqheight"));
         MaxValue :=
           Positive(Float(Modules_List(Module.Proto_Index).Durability) * 1.5);
         if Module.Max_Durability = MaxValue then
            configure
              (Label, "-text {" & cget(Label, "-text") & " (max upgrade)}");
         end if;
      end if;
      Tag_Configure(ModuleText, "red", "-foreground red");
      Insert
        (ModuleText, "end",
         "{Weight: " & Integer'Image(Module.Weight) & " kg" & LF &
         "Repair/Upgrade material: }");
      Find_Repair_Material_Loop :
      for Item of Items_List loop
         if Item.IType = Modules_List(Module.Proto_Index).RepairMaterial then
            if Mamount > 0 then
               Insert(ModuleText, "end", "{ or }");
            end if;
            Insert
              (ModuleText, "end",
               "{" & To_String(Item.Name) & "}" &
               (if
                  FindItem
                    (Inventory => Player_Ship.Cargo, ItemType => Item.IType) =
                  0
                then " [list red]"
                else ""));
            Mamount := Mamount + 1;
         end if;
      end loop Find_Repair_Material_Loop;
      Insert
        (ModuleText, "end",
         "{" & LF & "Repair/Upgrade skill: " &
         To_String
           (Skills_List(Modules_List(Module.Proto_Index).RepairSkill).Name) &
         "/" &
         To_String
           (Attributes_List
              (Skills_List(Modules_List(Module.Proto_Index).RepairSkill)
                 .Attribute)
              .Name) &
         "}");
      case Module.M_Type is
         when ENGINE =>
            Insert
              (ModuleText, "end",
               "{" & LF & "Max power:" & Integer'Image(Module.Power) & "}");
            MaxValue :=
              Positive(Float(Modules_List(Module.Proto_Index).MaxValue) * 1.5);
            if Module.Power = MaxValue then
               Insert(ModuleText, "end", "{ (max upgrade)}");
            end if;
            if Module.Disabled then
               Insert(ModuleText, "end", "{ (disabled)}");
            end if;
            Insert
              (ModuleText, "end",
               "{" & LF & "Fuel usage:" & Integer'Image(Module.Fuel_Usage) &
               "}");
            MaxValue :=
              Positive(Float(Modules_List(Module.Proto_Index).Value) / 2.0);
            if Module.Fuel_Usage = MaxValue then
               Insert(ModuleText, "end", "{ (max upgrade)}");
            end if;
         when CARGO_ROOM =>
            Insert
              (ModuleText, "end",
               "{" & LF & "Max cargo:" &
               Integer'Image(Modules_List(Module.Proto_Index).MaxValue) &
               " kg}");
         when HULL =>
            Label :=
              Create
                (ModuleFrame & ".modules",
                 "-text {Modules installed:" &
                 Integer'Image(Module.Installed_Modules) & " /" &
                 Integer'Image(Module.Max_Modules) & "}");
            MaxValue :=
              Positive(Float(Modules_List(Module.Proto_Index).MaxValue) * 1.5);
            if Module.Max_Modules = MaxValue then
               configure
                 (Label, "-text {" & cget(Label, "-text") & " (max upgrade)}");
            end if;
            Tcl.Tk.Ada.Grid.Grid(Label, "-sticky w");
            Height := Height + Positive'Value(Winfo_Get(Label, "reqheight"));
         when CABIN =>
            AddOwnersInfo("Owner");
            if Module.Cleanliness /= Module.Quality then
               Label := Create(ModuleFrame & ".cleanlbl");
               DamagePercent :=
                 1.0 - (Float(Module.Cleanliness) / Float(Module.Quality));
               if DamagePercent > 0.0 and DamagePercent < 0.2 then
                  configure(Label, "-text {Bit dusty}");
                  ProgressBarStyle :=
                    To_Unbounded_String
                      (" -style green.Horizontal.TProgressbar");
               elsif DamagePercent > 0.19 and DamagePercent < 0.5 then
                  configure(Label, "-text {Dusty}");
                  ProgressBarStyle :=
                    To_Unbounded_String
                      (" -style yellow.Horizontal.TProgressbar");
               elsif DamagePercent > 0.49 and DamagePercent < 0.8 then
                  configure(Label, "-text {Dirty}");
                  ProgressBarStyle :=
                    To_Unbounded_String
                      (" -style yellow.Horizontal.TProgressbar");
               elsif DamagePercent > 0.79 and DamagePercent < 1.0 then
                  configure(Label, "-text {Very dirty}");
                  ProgressBarStyle := Null_Unbounded_String;
               else
                  configure(Label, "-text {Ruined}");
                  ProgressBarStyle := Null_Unbounded_String;
               end if;
               ProgressBar :=
                 Create
                   (ModuleFrame & ".clean",
                    "-orient horizontal -maximum 1.0 -value {" &
                    Float'Image(DamagePercent) & "}" &
                    To_String(ProgressBarStyle));
               Add(ProgressBar, "Cleanliness of the selected cabin");
               Tcl.Tk.Ada.Grid.Grid(Label, "-row 1 -sticky w");
               Tcl.Tk.Ada.Grid.Grid
                 (ProgressBar, "-row 1 -column 1 -sticky we");
               Height :=
                 Height + Positive'Value(Winfo_Get(Label, "reqheight"));
            end if;
            ProgressBar :=
              Create
                (ModuleFrame & ".quality",
                 "-orient horizontal -style blue.Horizontal.TProgressbar -maximum 1.0 -value {" &
                 Float'Image(Float(Module.Quality) / 100.0) & "}");
            Add(ProgressBar, "Quality of the selected cabin");
            Label :=
              Create
                (ModuleFrame & ".qualitylbl",
                 "-text {" & Get_Cabin_Quality(Module.Quality) & "}");
            MaxValue :=
              Positive(Float(Modules_List(Module.Proto_Index).MaxValue) * 1.5);
            if Module.Quality = MaxValue then
               configure
                 (Label, "-text {" & cget(Label, "-text") & " (max upgrade)}");
            end if;
            Tcl.Tk.Ada.Grid.Grid(Label, "-row 2 -sticky w");
            Tcl.Tk.Ada.Grid.Grid(ProgressBar, "-row 2 -column 1 -sticky we");
            Height := Height + Positive'Value(Winfo_Get(Label, "reqheight"));
         when GUN | HARPOON_GUN =>
            Insert
              (ModuleText, "end",
               "{" & LF & "Strength:" &
               (if Modules_List(Module.Proto_Index).MType = GUN then
                  Positive'Image(Module.Damage)
                else Positive'Image(Module.Duration)) &
               LF & "Ammunition: }");
            HaveAmmo := False;
            declare
               AmmoIndex: constant Natural :=
                 (if Module.M_Type = GUN then Module.Ammo_Index
                  else Module.Harpoon_Index);
            begin
               if AmmoIndex in
                   Player_Ship.Cargo.First_Index ..
                         Player_Ship.Cargo.Last_Index
                 and then
                   Items_List(Player_Ship.Cargo(AmmoIndex).ProtoIndex).IType =
                   Items_Types(Modules_List(Module.Proto_Index).Value) then
                  Insert
                    (ModuleText, "end",
                     "{" &
                     To_String
                       (Items_List(Player_Ship.Cargo(AmmoIndex).ProtoIndex)
                          .Name) &
                     " (assigned)}");
                  HaveAmmo := True;
               end if;
            end;
            if not HaveAmmo then
               Mamount := 0;
               Find_Ammo_Info_Loop :
               for I in Items_List.Iterate loop
                  if Items_List(I).IType =
                    Items_Types(Modules_List(Module.Proto_Index).Value) then
                     if Mamount > 0 then
                        Insert(ModuleText, "end", "{ or }");
                     end if;
                     Insert
                       (ModuleText, "end",
                        "{" & To_String(Items_List(I).Name) & "}" &
                        (if
                           FindItem
                             (Player_Ship.Cargo, Objects_Container.Key(I)) >
                           0
                         then ""
                         else " [list red]"));
                     Mamount := Mamount + 1;
                  end if;
               end loop Find_Ammo_Info_Loop;
            end if;
            Insert
              (ModuleText, "end",
               "{" & LF & "Gunner: " &
               (if Module.Owner(1) > 0 then
                  To_String(Player_Ship.Crew(Module.Owner(1)).Name)
                else "none") &
               "}");
            if Module.M_Type = GUN then
               Insert
                 (ModuleText, "end",
                  "{" & LF & "Max fire rate:" &
                  (if Modules_List(Module.Proto_Index).Speed > 0 then
                     Positive'Image(Modules_List(Module.Proto_Index).Speed) &
                     "/round}"
                   else "1/" &
                     Trim
                       (Integer'Image
                          (abs (Modules_List(Module.Proto_Index).Speed)),
                        Left) &
                     " rounds}"));
            end if;
         when TURRET =>
            Insert
              (ModuleText, "end",
               "{" & LF & "Weapon: " &
               (if Module.Gun_Index > 0 then
                  To_String(Player_Ship.Modules(Module.Gun_Index).Name)
                else "none") &
               "}");
         when WORKSHOP =>
            AddOwnersInfo("Worker");
            Insert(ModuleText, "end", "{" & LF & "}");
            if Module.Crafting_Index /= Null_Unbounded_String then
               if Length(Module.Crafting_Index) > 6
                 and then Slice(Module.Crafting_Index, 1, 5) = "Study" then
                  Insert
                    (ModuleText, "end",
                     "{Studying " &
                     To_String
                       (Items_List
                          (Unbounded_Slice
                             (Module.Crafting_Index, 7,
                              Length(Module.Crafting_Index)))
                          .Name) &
                     "}");
               elsif Length(Module.Crafting_Index) > 12
                 and then Slice(Module.Crafting_Index, 1, 11) =
                   "Deconstruct" then
                  Insert
                    (ModuleText, "end",
                     "{Deconstructing " &
                     To_String
                       (Items_List
                          (Unbounded_Slice
                             (Module.Crafting_Index, 13,
                              Length(Module.Crafting_Index)))
                          .Name) &
                     "}");
               else
                  Insert
                    (ModuleText, "end",
                     "{Manufacturing:" &
                     Positive'Image(Module.Crafting_Amount) & "x " &
                     To_String
                       (Items_List
                          (Recipes_List(Module.Crafting_Index).ResultIndex)
                          .Name) &
                     "}");
               end if;
               Insert
                 (ModuleText, "end",
                  "{" & LF & "Time to complete current:" &
                  Positive'Image(Module.Crafting_Time) & " mins}");
            else
               Insert(ModuleText, "end", "{Manufacturing: nothing}");
            end if;
         when MEDICAL_ROOM =>
            AddOwnersInfo("Medic");
         when TRAINING_ROOM =>
            Insert
              (ModuleText, "end",
               "{" & LF &
               (if Module.Trained_Skill > 0 then
                  "Set for training " &
                  To_String(Skills_List(Module.Trained_Skill).Name)
                else "Must be set for training") &
               ".}");
            AddOwnersInfo("Trainee");
         when BATTERING_RAM =>
            Insert
              (ModuleText, "end",
               "Strength:" & Positive'Image(Module.Damage2) & "}");
         when others =>
            null;
      end case;
      if Modules_List(Module.Proto_Index).Size > 0 then
         Insert
           (ModuleText, "end",
            "{" & LF & "Size:" &
            Natural'Image(Modules_List(Module.Proto_Index).Size) & "}");
      end if;
      if Modules_List(Module.Proto_Index).Description /=
        Null_Unbounded_String then
         Insert
           (ModuleText, "end",
            "{" & LF & LF &
            To_String(Modules_List(Module.Proto_Index).Description) & "}");
      end if;
      if Module.Upgrade_Action /= NONE then
         ModuleInfo := To_Unbounded_String("Upgrading: ");
         case Module.Upgrade_Action is
            when DURABILITY =>
               Append(ModuleInfo, "durability");
               MaxUpgrade := Modules_List(Module.Proto_Index).Durability;
            when MAX_VALUE =>
               case Modules_List(Module.Proto_Index).MType is
                  when ENGINE =>
                     Append(ModuleInfo, "power");
                     MaxUpgrade :=
                       Modules_List(Module.Proto_Index).MaxValue / 20;
                  when CABIN =>
                     Append(ModuleInfo, "quality");
                     MaxUpgrade := Modules_List(Module.Proto_Index).MaxValue;
                  when GUN | BATTERING_RAM =>
                     Append(ModuleInfo, "damage");
                     MaxUpgrade :=
                       Modules_List(Module.Proto_Index).MaxValue * 2;
                  when HULL =>
                     Append(ModuleInfo, "enlarge");
                     MaxUpgrade :=
                       Modules_List(Module.Proto_Index).MaxValue * 40;
                  when HARPOON_GUN =>
                     Append(ModuleInfo, "strength");
                     MaxUpgrade :=
                       Modules_List(Module.Proto_Index).MaxValue * 10;
                  when others =>
                     null;
               end case;
            when VALUE =>
               case Modules_List(Module.Proto_Index).MType is
                  when ENGINE =>
                     Append(ModuleInfo, "fuel usage");
                     MaxUpgrade := Modules_List(Module.Proto_Index).Value * 20;
                  when others =>
                     null;
               end case;
            when others =>
               null;
         end case;
         MaxUpgrade :=
           Integer
             (Float(MaxUpgrade) * Float(New_Game_Settings.Upgrade_Cost_Bonus));
         if MaxUpgrade = 0 then
            MaxUpgrade := 1;
         end if;
         UpgradePercent :=
           1.0 - (Float(Module.Upgrade_Progress) / Float(MaxUpgrade));
         ProgressBarStyle :=
           (if UpgradePercent > 0.74 then
              To_Unbounded_String(" -style green.Horizontal.TProgressbar")
            elsif UpgradePercent > 0.24 then
              To_Unbounded_String(" -style yellow.Horizontal.TProgressbar")
            else To_Unbounded_String(" -style Horizontal.TProgressbar"));
         ProgressBar :=
           Create
             (ModuleFrame & ".upgrade",
              "-orient horizontal -maximum 1.0 -value {" &
              Float'Image(UpgradePercent) & "}" & To_String(ProgressBarStyle));
         Add(ProgressBar, "The progress of the current upgrade of the module");
         Label :=
           Create
             (ModuleFrame & ".upgradelbl",
              "-text {" & To_String(ModuleInfo) & "}");
         Tcl.Tk.Ada.Grid.Grid(Label, "-row 3 -sticky w");
         Tcl.Tk.Ada.Grid.Grid(ProgressBar, "-row 3 -column 1 -sticky we");
         Height := Height + Positive'Value(Winfo_Get(Label, "reqheight"));
      end if;
      configure
        (ModuleText,
         "-state disabled -height" &
         Positive'Image
           (Positive'Value(Count(ModuleText, "-displaylines", "0.0", "end")) /
            Positive'Value(Metrics("InterfaceFont", "-linespace")) +
            1));
      Tcl.Tk.Ada.Grid.Grid(ModuleText, "-columnspan 2");
      Height := Height + Positive'Value(Winfo_Get(ModuleText, "reqheight"));
      Add_Close_Button
        (ModuleFrame & ".button", "Close", "CloseDialog " & ModuleDialog, 2);
      Height :=
        Height +
        Positive'Value
          (Winfo_Get
             (Ttk_Frame'(Get_Widget(ModuleFrame & ".button")), "reqheight"));
      if Height > 500 then
         Height := 500;
      end if;
      configure
        (ModuleFrame,
         "-height" & Positive'Image(Height) & " -width " &
         Winfo_Get(ModuleText, "reqwidth"));
      Canvas_Create
        (ModuleCanvas, "window",
         "0 0 -anchor nw -window " & Widget_Image(ModuleFrame));
      configure
        (ModuleCanvas,
         "-scrollregion [list " & BBox(ModuleCanvas, "all") & "]");
      Height :=
        Height + 15 +
        Positive'Value
          (Winfo_Get
             (Ttk_Frame'(Get_Widget(ModuleDialog & ".header")), "reqheight"));
      declare
         Width: Positive;
      begin
         Width :=
           Positive'Value(Winfo_Get(ModuleText, "reqwidth")) +
           Positive'Value(Winfo_Get(YScroll, "reqwidth")) + 5;
         configure
           (ModuleDialog,
            "-height" & Positive'Image(Height) & " -width" &
            Positive'Image(Width));
      end;
      Show_Dialog
        (Dialog => ModuleDialog, Relative_X => 0.2, Relative_Y => 0.1);
      return TCL_OK;
   end Show_Module_Info_Command;

   -- ****o* SUModules/SUModules.Set_Upgrade_Command
   -- FUNCTION
   -- Set the selected upgrade for the selected module
   -- PARAMETERS
   -- ClientData - Custom data send to the command.
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command.
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- SetUpgrade upgradetype moduleindex
   -- upgradetype is type of upgrade to start: 1, 2 or 3. moduleindex is the
   -- index of the player ship module which will be upgraded
   -- SOURCE
   function Set_Upgrade_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Set_Upgrade_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
   begin
      StartUpgrading
        (Positive'Value(CArgv.Arg(Argv, 2)),
         Positive'Value(CArgv.Arg(Argv, 1)));
      UpdateOrders(Player_Ship);
      UpdateMessages;
      return Show_Ship_Info_Command(ClientData, Interp, Argc, Argv);
   end Set_Upgrade_Command;

   -- ****o* SUModules/SUModules.Assign_Module_Command
   -- FUNCTION
   -- Assign member, ammo or skill to module
   -- PARAMETERS
   -- ClientData - Custom data send to the command.
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command.
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- AssignModule assigntype moduleindex assignindex
   -- assigntype is type of item to assing to module: crew, ammo, skills.
   -- moduleindex is the index of the Player_Ship module to which item will be
   -- assigned. assignindex is the index of the item which will be assigned
   -- to the module
   -- SOURCE
   function Assign_Module_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Assign_Module_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      ModuleIndex: constant Positive := Positive'Value(CArgv.Arg(Argv, 2));
      AssignIndex: constant Positive := Positive'Value(CArgv.Arg(Argv, 3));
      Assigned: Boolean;
      procedure UpdateOrder(Order: Crew_Orders) is
      begin
         GiveOrders(Player_Ship, AssignIndex, Order, ModuleIndex);
         if Player_Ship.Crew(AssignIndex).Order /= Order then
            Tcl_SetVar
              (Interp,
               ".moduledialog.canvas.frame.crewbutton" & CArgv.Arg(Argv, 3),
               "0");
         end if;
      end UpdateOrder;
   begin
      if CArgv.Arg(Argv, 1) = "crew" then
         case Modules_List(Player_Ship.Modules(ModuleIndex).Proto_Index)
           .MType is
            when CABIN =>
               Modules_Loop :
               for Module of Player_Ship.Modules loop
                  if Module.M_Type = CABIN then
                     for Owner of Module.Owner loop
                        if Owner = AssignIndex then
                           Owner := 0;
                           exit Modules_Loop;
                        end if;
                     end loop;
                  end if;
               end loop Modules_Loop;
               Assigned := False;
               Check_Assigned_Loop :
               for Owner of Player_Ship.Modules(ModuleIndex).Owner loop
                  if Owner = 0 then
                     Owner := AssignIndex;
                     Assigned := True;
                     exit Check_Assigned_Loop;
                  end if;
               end loop Check_Assigned_Loop;
               if not Assigned then
                  Player_Ship.Modules(ModuleIndex).Owner(1) := AssignIndex;
               end if;
               AddMessage
                 ("You assigned " &
                  To_String(Player_Ship.Modules(ModuleIndex).Name) & " to " &
                  To_String(Player_Ship.Crew(AssignIndex).Name) & ".",
                  OrderMessage);
            when GUN | HARPOON_GUN =>
               UpdateOrder(Gunner);
            when ALCHEMY_LAB .. GREENHOUSE =>
               UpdateOrder(Craft);
            when MEDICAL_ROOM =>
               UpdateOrder(Heal);
            when TRAINING_ROOM =>
               UpdateOrder(Train);
            when others =>
               null;
         end case;
         UpdateHeader;
      elsif CArgv.Arg(Argv, 1) = "ammo" then
         if Player_Ship.Modules(ModuleIndex).M_Type = GUN then
            Player_Ship.Modules(ModuleIndex).Ammo_Index := AssignIndex;
         else
            Player_Ship.Modules(ModuleIndex).Harpoon_Index := AssignIndex;
         end if;
         AddMessage
           ("You assigned " &
            To_String
              (Items_List(Player_Ship.Cargo(AssignIndex).ProtoIndex).Name) &
            " to " & To_String(Player_Ship.Modules(ModuleIndex).Name) & ".",
            OrderMessage);
      elsif CArgv.Arg(Argv, 1) = "skill" then
         if Player_Ship.Modules(ModuleIndex).Trained_Skill = AssignIndex then
            return TCL_OK;
         end if;
         Player_Ship.Modules(ModuleIndex).Trained_Skill := AssignIndex;
         AddMessage
           ("You prepared " &
            To_String(Player_Ship.Modules(ModuleIndex).Name) &
            " for training " & To_String(Skills_List(AssignIndex).Name) & ".",
            OrderMessage);
      end if;
      UpdateMessages;
      return Show_Ship_Info_Command(ClientData, Interp, Argc, Argv);
   exception
      when An_Exception : Crew_Order_Error =>
         ShowMessage
           (Text => Exception_Message(An_Exception),
            Title => "Can't assign crew");
         return TCL_OK;
   end Assign_Module_Command;

   -- ****o* SUModules/SUModules.Disable_Engine_Command
   -- FUNCTION
   -- Enable or disable selected engine
   -- PARAMETERS
   -- ClientData - Custom data send to the command.
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- DisableEngine engineindex
   -- engineindex is the index of the engine module in the player ship
   -- SOURCE
   function Disable_Engine_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Disable_Engine_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Argc);
      CanDisable: Boolean := False;
      ModuleIndex: constant Positive := Positive'Value(CArgv.Arg(Argv, 1));
   begin
      if not Player_Ship.Modules(ModuleIndex).Disabled then
         Check_Can_Disable_Loop :
         for I in Player_Ship.Modules.Iterate loop
            if Player_Ship.Modules(I).M_Type = ENGINE
              and then
              (not Player_Ship.Modules(I).Disabled and
               Modules_Container.To_Index(I) /= ModuleIndex) then
               CanDisable := True;
               exit Check_Can_Disable_Loop;
            end if;
         end loop Check_Can_Disable_Loop;
         if not CanDisable then
            ShowMessage
              (Text =>
                 "You can't disable this engine because it is your last working engine.",
               Title => "Can't disable engine");
            return TCL_OK;
         end if;
         Player_Ship.Modules(ModuleIndex).Disabled := True;
         AddMessage
           ("You disabled " &
            To_String(Player_Ship.Modules(ModuleIndex).Name) & ".",
            OrderMessage);
      else
         Player_Ship.Modules(ModuleIndex).Disabled := False;
         AddMessage
           ("You enabled " & To_String(Player_Ship.Modules(ModuleIndex).Name) &
            ".",
            OrderMessage);
      end if;
      UpdateMessages;
      return Show_Ship_Info_Command(ClientData, Interp, 2, Argv);
   end Disable_Engine_Command;

   -- ****o* SUModules/SUModules.Stop_Upgrading_Command
   -- FUNCTION
   -- Stop the current ship upgrade
   -- PARAMETERS
   -- ClientData - Custom data send to the command.
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- StopUpgrading
   -- SOURCE
   function Stop_Upgrading_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Stop_Upgrading_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Argc);
   begin
      Player_Ship.Upgrade_Module := 0;
      Give_Orders_Loop :
      for I in Player_Ship.Crew.First_Index .. Player_Ship.Crew.Last_Index loop
         if Player_Ship.Crew(I).Order = Upgrading then
            GiveOrders(Player_Ship, I, Rest);
            exit Give_Orders_Loop;
         end if;
      end loop Give_Orders_Loop;
      AddMessage("You stopped current upgrade.", OrderMessage);
      UpdateMessages;
      return Show_Ship_Info_Command(ClientData, Interp, 2, Argv);
   end Stop_Upgrading_Command;

   -- ****o* SUModules/SUModules.Set_Repair_Command
   -- FUNCTION
   -- Set or remove the repair priority from the selected module
   -- PARAMETERS
   -- ClientData - Custom data send to the command.
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- SetRepair action
   -- Action can be assing or remove. If assing, then assing the currently
   -- selected module as the repair first, otherwise clear current priority
   -- setting
   -- SOURCE
   function Set_Repair_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Set_Repair_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
   begin
      if CArgv.Arg(Argv, 1) = "assign" then
         Player_Ship.Repair_Module := Positive'Value(CArgv.Arg(Argv, 2));
         AddMessage
           ("You assigned " &
            To_String
              (Player_Ship.Modules(Positive'Value(CArgv.Arg(Argv, 2))).Name) &
            " as repair priority.",
            OrderMessage);
      else
         Player_Ship.Repair_Module := 0;
         AddMessage("You removed repair priority.", OrderMessage);
      end if;
      UpdateMessages;
      return Show_Ship_Info_Command(ClientData, Interp, Argc, Argv);
   end Set_Repair_Command;

   -- ****o* SUModules/SUModules.Reset_Destination_Command
   -- FUNCTION
   -- Reset the current destination point for the player's ship
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ResetDestination
   -- SOURCE
   function Reset_Destination_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Reset_Destination_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(Argc);
   begin
      Player_Ship.Destination_X := 0;
      Player_Ship.Destination_Y := 0;
      return Show_Ship_Info_Command(ClientData, Interp, 2, Argv);
   end Reset_Destination_Command;

   -- ****o* SUModules/SUModules.Update_Assign_Crew_Command
   -- FUNCTION
   -- Update assign the crew member UI
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- UpdateAssignCrew moduleindex ?crewindex?
   -- Moduleindex is the index of the module to which a new crew members will
   -- be assigned. Crewindex is the index of the crew member which will be
   -- assigned or removed
   -- SOURCE
   function Update_Assign_Crew_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Update_Assign_Crew_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      ModuleIndex: constant Positive := Positive'Value(CArgv.Arg(Argv, 1));
      Assigned: Natural := 0;
      FrameName: constant String := ".moduledialog.canvas.frame";
      CrewButton: Ttk_CheckButton;
      ButtonName: Unbounded_String;
      CrewIndex: constant Natural :=
        (if Argc = 3 then Positive'Value(CArgv.Arg(Argv, 2)) else 0);
      InfoLabel: constant Ttk_Label :=
        Get_Widget(FrameName & ".infolabel", Interp);
   begin
      if Argc = 3 then
         if Tcl_GetVar
             (Interp, FrameName & ".crewbutton" & CArgv.Arg(Argv, 2)) =
           "0" then
            Remove_Owner_Loop :
            for Owner of Player_Ship.Modules(ModuleIndex).Owner loop
               if Owner = CrewIndex then
                  Owner := 0;
                  exit Remove_Owner_Loop;
               end if;
            end loop Remove_Owner_Loop;
            if Modules_List(Player_Ship.Modules(ModuleIndex).Proto_Index)
                .MType /=
              CABIN then
               GiveOrders(Player_Ship, CrewIndex, Rest, 0, False);
            end if;
         elsif Assign_Module_Command
             (ClientData, Interp, 4,
              CArgv.Empty & "AssignModule" & "crew" & CArgv.Arg(Argv, 1) &
              CArgv.Arg(Argv, 2)) /=
           TCL_OK then
            return TCL_ERROR;
         end if;
      end if;
      CrewButton.Interp := Interp;
      Enable_Buttons_Loop :
      for I in Player_Ship.Crew.Iterate loop
         CrewButton.Name :=
           New_String
             (FrameName & ".crewbutton" &
              Trim(Positive'Image(Crew_Container.To_Index(I)), Left));
         State(CrewButton, "!disabled");
         configure(CrewButton, "-takefocus 1");
      end loop Enable_Buttons_Loop;
      for Owner of Player_Ship.Modules(ModuleIndex).Owner loop
         if Owner /= 0 then
            Assigned := Assigned + 1;
         end if;
      end loop;
      if Assigned =
        Positive(Player_Ship.Modules(ModuleIndex).Owner.Length) then
         Disable_Buttons_Loop :
         for I in Player_Ship.Crew.Iterate loop
            ButtonName :=
              To_Unbounded_String
                (FrameName & ".crewbutton" &
                 Trim(Positive'Image(Crew_Container.To_Index(I)), Left));
            if Tcl_GetVar(Interp, To_String(ButtonName)) = "0" then
               CrewButton.Name := New_String(To_String(ButtonName));
               State(CrewButton, "disabled");
               configure(CrewButton, "-takefocus 0");
            end if;
         end loop Disable_Buttons_Loop;
      end if;
      if Winfo_Get(InfoLabel, "exists") = "1" then
         configure
           (InfoLabel,
            "-text {Available:" &
            Natural'Image
              (Positive(Player_Ship.Modules(ModuleIndex).Owner.Length) -
               Assigned) &
            "}");
         UpdateHeader;
         UpdateCrewInfo;
      end if;
      return TCL_OK;
   end Update_Assign_Crew_Command;

   -- ****o* SUModules/SUModules.Show_Assign_Crew_Command
   -- FUNCTION
   -- Show assign the crew member UI
   -- PARAMETERS
   -- ClientData - Custom data send to the command.
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command.
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowAssignCrew moduleindex
   -- Moduleindex is the index of the module to which a new crew members will
   -- be assigned.
   -- SOURCE
   function Show_Assign_Crew_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Assign_Crew_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      ModuleIndex: constant Positive := Positive'Value(CArgv.Arg(Argv, 1));
      ModuleDialog: constant Ttk_Frame :=
        Create_Dialog
          (".moduledialog",
           "Assign a crew member to " &
           To_String(Player_Ship.Modules(ModuleIndex).Name),
           250);
      YScroll: constant Ttk_Scrollbar :=
        Create
          (ModuleDialog & ".yscroll",
           "-orient vertical -command [list .moduledialog.canvas yview]");
      CrewCanvas: constant Tk_Canvas :=
        Create
          (ModuleDialog & ".canvas",
           "-yscrollcommand [list " & YScroll & " set]");
      CrewFrame: constant Ttk_Frame := Create(CrewCanvas & ".frame");
      CloseButton: constant Ttk_Button :=
        Create
          (ModuleDialog & ".button",
           "-text Close -command {CloseDialog " & Widget_Image(ModuleDialog) &
           "}");
      Height: Positive := 10;
      Width: Positive := 250;
      CrewButton: Ttk_CheckButton;
      InfoLabel: Ttk_Label;
      Assigned: Natural := 0;
   begin
      Tcl.Tk.Ada.Grid.Grid(CrewCanvas, "-sticky nwes -padx 5 -pady 5");
      Tcl.Tk.Ada.Grid.Grid
        (YScroll, "-sticky ns -padx {0 5} -pady {5 0} -row 0 -column 1");
      Tcl.Tk.Ada.Grid.Grid(CloseButton, "-pady {0 5} -columnspan 2");
      Focus(CloseButton);
      Autoscroll(YScroll);
      Load_Crew_List_Loop :
      for I in Player_Ship.Crew.Iterate loop
         CrewButton :=
           Create
             (CrewFrame & ".crewbutton" &
              Trim(Positive'Image(Crew_Container.To_Index(I)), Left),
              "-text {" & To_String(Player_Ship.Crew(I).Name) &
              "} -command {UpdateAssignCrew" & Positive'Image(ModuleIndex) &
              Positive'Image(Crew_Container.To_Index(I)) & "}");
         Tcl_SetVar(Interp, Widget_Image(CrewButton), "0");
         Count_Assigned_Loop :
         for Owner of Player_Ship.Modules(ModuleIndex).Owner loop
            if Owner = Crew_Container.To_Index(I) then
               Tcl_SetVar(Interp, Widget_Image(CrewButton), "1");
               Assigned := Assigned + 1;
               exit Count_Assigned_Loop;
            end if;
         end loop Count_Assigned_Loop;
         Tcl.Tk.Ada.Pack.Pack(CrewButton, "-anchor w");
         Height := Height + Positive'Value(Winfo_Get(CrewButton, "reqheight"));
         if Positive'Value(Winfo_Get(CrewButton, "reqwidth")) + 10 > Width then
            Width := Positive'Value(Winfo_Get(CrewButton, "reqwidth")) + 10;
         end if;
         Bind(CrewButton, "<Escape>", "{" & CloseButton & " invoke;break}");
         Bind
           (CrewButton, "<Tab>",
            "{focus [GetActiveButton" &
            Positive'Image(Crew_Container.To_Index(I)) & "];break}");
      end loop Load_Crew_List_Loop;
      if Update_Assign_Crew_Command(ClientData, Interp, Argc, Argv) /=
        TCL_OK then
         return TCL_ERROR;
      end if;
      InfoLabel :=
        Create
          (CrewFrame & ".infolabel",
           "-text {Available:" &
           Natural'Image
             (Positive(Player_Ship.Modules(ModuleIndex).Owner.Length) -
              Assigned) &
           "}");
      Tcl.Tk.Ada.Pack.Pack(InfoLabel);
      Height := Height + Positive'Value(Winfo_Get(InfoLabel, "reqheight"));
      if Positive'Value(Winfo_Get(InfoLabel, "reqwidth")) > Width then
         Width := Positive'Value(Winfo_Get(InfoLabel, "reqwidth"));
      end if;
      if Height > 500 then
         Height := 500;
      end if;
      Canvas_Create
        (CrewCanvas, "window",
         "0 0 -anchor nw -window " & Widget_Image(CrewFrame));
      Tcl_Eval(Interp, "update");
      configure
        (CrewCanvas,
         "-scrollregion [list " & BBox(CrewCanvas, "all") & "] -height" &
         Positive'Image(Height) & " -width" & Positive'Image(Width));
      Bind(CloseButton, "<Escape>", "{" & CloseButton & " invoke;break}");
      Bind(CloseButton, "<Tab>", "{focus [GetActiveButton 0];break}");
      Show_Dialog(Dialog => ModuleDialog, Relative_Y => 0.2);
      return TCL_OK;
   end Show_Assign_Crew_Command;

   -- ****o* SUModules/SUModules.Show_Assign_Skill_Command
   -- FUNCTION
   -- Show assign the skill UI
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed. Unused
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowAssignSkill moduleindex
   -- Moduleindex is the index of the module to which a new skill will
   -- be assigned.
   -- SOURCE
   function Show_Assign_Skill_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Assign_Skill_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Interp, Argc);
      ModuleIndex: constant Positive := Positive'Value(CArgv.Arg(Argv, 1));
      ModuleDialog: constant Ttk_Frame :=
        Create_Dialog
          (Name => ".moduledialog",
           Title =>
             "Assign skill to " &
             To_String(Player_Ship.Modules(ModuleIndex).Name),
           Title_Width => 400);
      SkillsFrame: constant Ttk_Frame := Create(ModuleDialog & ".frame");
      ToolName, ProtoIndex, SkillName, ToolColor: Unbounded_String;
      SkillsTable: Table_Widget (2) :=
        CreateTable
          (Widget_Image(SkillsFrame),
           (To_Unbounded_String("Skill"),
            To_Unbounded_String("Training tool")));
   begin
      Load_Skills_List_Loop :
      for I in Skills_List.First_Index .. Skills_List.Last_Index loop
         if Skills_List(I).Tool /= Null_Unbounded_String then
            ProtoIndex := FindProtoItem(ItemType => Skills_List(I).Tool);
            ToolName :=
              (if Items_List(ProtoIndex).ShowType /= Null_Unbounded_String then
                 Items_List(ProtoIndex).ShowType
               else Items_List(ProtoIndex).IType);
         end if;
         SkillName := Skills_List(I).Name;
         ToolColor := To_Unbounded_String("green");
         if GetItemAmount(Items_List(ProtoIndex).IType) = 0 then
            Append(SkillName, " (no tool)");
            ToolColor := To_Unbounded_String("red");
         end if;
         AddButton
           (SkillsTable, To_String(SkillName),
            "Press mouse " &
            (if Game_Settings.Right_Button then "right" else "left") &
            " button to set as trained skill",
            "AssignModule skill" & Positive'Image(ModuleIndex) &
            Positive'Image(I),
            1);
         AddButton
           (SkillsTable, To_String(ToolName),
            "Press mouse " &
            (if Game_Settings.Right_Button then "right" else "left") &
            " button to set as trained skill",
            "AssignModule skill" & Positive'Image(ModuleIndex) &
            Positive'Image(I),
            2, True, To_String(ToolColor));
      end loop Load_Skills_List_Loop;
      UpdateTable(SkillsTable);
      Tcl.Tk.Ada.Grid.Grid(SkillsFrame, "-padx 2");
      Tcl_Eval(Get_Context, "update");
      configure
        (SkillsTable.Canvas,
         "-scrollregion [list " & BBox(SkillsTable.Canvas, "all") & "]");
      Xview_Move_To(SkillsTable.Canvas, "0.0");
      Yview_Move_To(SkillsTable.Canvas, "0.0");
      Add_Close_Button
        (ModuleDialog & ".button", "Close", "CloseDialog " & ModuleDialog);
      Show_Dialog(Dialog => ModuleDialog, Relative_Y => 0.2);
      return TCL_OK;
   end Show_Assign_Skill_Command;

   -- ****o* SUModules/SUModules.Cancel_Order_Command
   -- FUNCTION
   -- Cancel the current crafting order
   -- PARAMETERS
   -- ClientData - Custom data send to the command.
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command.
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- Cancel moduleindex
   -- Moduleindex is the index of the module which the crafting order will
   -- be canceled
   -- SOURCE
   function Cancel_Order_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Cancel_Order_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Interp, Argc);
      ModuleIndex: constant Positive := Positive'Value(CArgv.Arg(Argv, 1));
   begin
      Player_Ship.Modules(ModuleIndex).Crafting_Index := Null_Unbounded_String;
      Player_Ship.Modules(ModuleIndex).Crafting_Amount := 0;
      Player_Ship.Modules(ModuleIndex).Crafting_Time := 0;
      Give_Orders_Loop :
      for Owner of Player_Ship.Modules(ModuleIndex).Owner loop
         if Owner > 0 then
            GiveOrders(Player_Ship, Owner, Rest);
         end if;
      end loop Give_Orders_Loop;
      AddMessage
        ("You cancelled crafting order in " &
         To_String(Player_Ship.Modules(ModuleIndex).Name) & ".",
         CraftMessage, RED);
      UpdateMessages;
      UpdateHeader;
      UpdateCrewInfo;
      return TCL_OK;
   end Cancel_Order_Command;

   -- ****o* SUModules/SUModules.Get_Active_Button_Command
   -- FUNCTION
   -- Get the next active button in assing crew dialog
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- GetActiveButton crewindex
   -- Crewindex is the index of the crew member which is currently selected
   -- or 0 for close button
   -- SOURCE
   function Get_Active_Button_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Get_Active_Button_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      CrewIndex: constant Natural := Natural'Value(CArgv.Arg(Argv, 1));
      ButtonName: Unbounded_String;
      Button: Ttk_CheckButton;
   begin
      Find_Active_Button_Loop :
      for I in Player_Ship.Crew.Iterate loop
         ButtonName :=
           To_Unbounded_String
             (".moduledialog.canvas.frame.crewbutton" &
              Trim(Positive'Image(Crew_Container.To_Index(I)), Left));
         Button := Get_Widget(To_String(ButtonName), Interp);
         exit Find_Active_Button_Loop when InState(Button, "disabled") =
           "0" and
           Crew_Container.To_Index(I) > CrewIndex;
         ButtonName := Null_Unbounded_String;
      end loop Find_Active_Button_Loop;
      if ButtonName = Null_Unbounded_String then
         ButtonName := To_Unbounded_String(".moduledialog.button");
      end if;
      Button := Get_Widget(To_String(ButtonName), Interp);
      Focus(Button);
      return TCL_OK;
   end Get_Active_Button_Command;

   procedure UpdateModulesInfo(Page: Positive := 1) is
      ShipCanvas: constant Tk_Canvas :=
        Get_Widget(Main_Paned & ".shipinfoframe.modules.canvas");
      ShipInfoFrame: constant Ttk_Frame := Get_Widget(ShipCanvas & ".frame");
      Row: Positive := 2;
      Start_Row: constant Positive := ((Page - 1) * 25) + 1;
      Current_Row: Positive := 1;
   begin
      if ModulesTable.Row_Height = 1 then
         ModulesTable :=
           CreateTable
             (Widget_Image(ShipInfoFrame),
              (To_Unbounded_String("Name"), To_Unbounded_String("Durability")),
              Get_Widget(Main_Paned & ".shipinfoframe.modules.scrolly"),
              "SortShipModules", "Press mouse button to sort the modules.");
         for I in Player_Ship.Modules.Iterate loop
            Modules_Indexes.Append(Modules_Container.To_Index(I));
         end loop;
      end if;
      ClearTable(ModulesTable);
      Show_Modules_Menu_Loop :
      for Module_Index of Modules_Indexes loop
         if Current_Row < Start_Row then
            Current_Row := Current_Row + 1;
            goto End_Of_Loop;
         end if;
         AddButton
           (ModulesTable, To_String(Player_Ship.Modules(Module_Index).Name),
            "Show available module's options",
            "ShowModuleMenu" & Positive'Image(Module_Index), 1);
         AddProgressBar
           (ModulesTable, Player_Ship.Modules(Module_Index).Durability,
            Player_Ship.Modules(Module_Index).Max_Durability,
            "Show available module's options",
            "ShowModuleMenu" & Positive'Image(Module_Index), 2, True);
         Row := Row + 1;
         exit Show_Modules_Menu_Loop when ModulesTable.Row = 26;
         <<End_Of_Loop>>
      end loop Show_Modules_Menu_Loop;
      if Page > 1 then
         if ModulesTable.Row < 26 then
            AddPagination
              (ModulesTable, "ShowModules" & Positive'Image(Page - 1), "");
         else
            AddPagination
              (ModulesTable, "ShowModules" & Positive'Image(Page - 1),
               "ShowModules" & Positive'Image(Page + 1));
         end if;
      elsif ModulesTable.Row = 26 then
         AddPagination
           (ModulesTable, "", "ShowModules" & Positive'Image(Page + 1));
      end if;
      UpdateTable(ModulesTable);
      Tcl_Eval(Get_Context, "update");
      configure
        (ShipCanvas, "-scrollregion [list " & BBox(ShipCanvas, "all") & "]");
      Xview_Move_To(ShipCanvas, "0.0");
      Yview_Move_To(ShipCanvas, "0.0");
   end UpdateModulesInfo;

   -- ****o* SUModules/SUModules.Show_Modules_Command
   -- FUNCTION
   -- Show the list of the player's ship modules to a player
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed. Unused
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowModules ?page?
   -- Page parameter is a index of page from which starts showing
   -- modules.
   -- SOURCE
   function Show_Modules_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Modules_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Interp, Argc);
   begin
      UpdateModulesInfo(Positive'Value(CArgv.Arg(Argv, 1)));
      return TCL_OK;
   end Show_Modules_Command;

   -- ****o* SUModules/SUModules.Sort_Modules_Command
   -- FUNCTION
   -- Sort the player's ship's modules list
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed. Unused
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- SortShipModules x
   -- X is X axis coordinate where the player clicked the mouse button
   -- SOURCE
   function Sort_Modules_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Sort_Modules_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Interp, Argc);
      Column: constant Positive :=
        Get_Column_Number(ModulesTable, Natural'Value(CArgv.Arg(Argv, 1)));
      Local_Modules: Modules_Container.Vector := Player_Ship.Modules;
   begin
      case Column is
         when 1 =>
            if Modules_Sort_Order = NAMEASC then
               Modules_Sort_Order := NAMEDESC;
            else
               Modules_Sort_Order := NAMEASC;
            end if;
         when 2 =>
            if Modules_Sort_Order = DAMAGEASC then
               Modules_Sort_Order := DAMAGEDESC;
            else
               Modules_Sort_Order := DAMAGEASC;
            end if;
         when others =>
            null;
      end case;
      Player_Ship_Modules_Sorting.Sort(Local_Modules);
      Modules_Indexes.Clear;
      for Module of Local_Modules loop
         for I in Player_Ship.Modules.Iterate loop
            if Player_Ship.Modules(I).Name = Module.Name then
               Modules_Indexes.Append(Modules_Container.To_Index(I));
               exit;
            end if;
         end loop;
      end loop;
      UpdateModulesInfo;
      return TCL_OK;
   end Sort_Modules_Command;

   procedure AddCommands is
   begin
      AddCommand("ShowModuleMenu", Show_Module_Menu_Command'Access);
      AddCommand("ShowModuleInfo", Show_Module_Info_Command'Access);
      AddCommand("SetUpgrade", Set_Upgrade_Command'Access);
      AddCommand("AssignModule", Assign_Module_Command'Access);
      AddCommand("DisableEngine", Disable_Engine_Command'Access);
      AddCommand("StopUpgrading", Stop_Upgrading_Command'Access);
      AddCommand("SetRepair", Set_Repair_Command'Access);
      AddCommand("ResetDestination", Reset_Destination_Command'Access);
      AddCommand("ShowAssignCrew", Show_Assign_Crew_Command'Access);
      AddCommand("UpdateAssignCrew", Update_Assign_Crew_Command'Access);
      AddCommand("ShowAssignSkill", Show_Assign_Skill_Command'Access);
      AddCommand("CancelOrder", Cancel_Order_Command'Access);
      AddCommand("GetActiveButton", Get_Active_Button_Command'Access);
      AddCommand("ShowModules", Show_Modules_Command'Access);
      AddCommand("SortShipModules", Sort_Modules_Command'Access);
   end AddCommands;

end Ships.UI.Modules;
