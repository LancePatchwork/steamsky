-- Copyright (c) 2020-2023 Bartek thindil Jasicki <thindil@laeran.pl>
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

with Ada.Characters.Handling;
with Ada.Characters.Latin_1; use Ada.Characters.Latin_1;
with Ada.Strings; use Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.UTF_Encoding.Wide_Strings;
with Ada.Text_IO;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with GNAT.Directory_Operations;
with Tcl.Ada; use Tcl.Ada;
with Tcl.Tk.Ada; use Tcl.Tk.Ada;
with Tcl.Tk.Ada.Grid;
with Tcl.Tk.Ada.Pack;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.Text; use Tcl.Tk.Ada.Widgets.Text;
with Tcl.Tk.Ada.Widgets.Toplevel.MainWindow;
use Tcl.Tk.Ada.Widgets.Toplevel.MainWindow;
with Tcl.Tk.Ada.Widgets.TtkButton; use Tcl.Tk.Ada.Widgets.TtkButton;
with Tcl.Tk.Ada.Widgets.TtkEntry.TtkComboBox;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Tcl.Tk.Ada.Widgets.TtkLabel;
with Tcl.Tk.Ada.Widgets.TtkPanedWindow;
with Tcl.Tk.Ada.Widgets.TtkWidget;
with Tcl.Tk.Ada.Winfo; use Tcl.Tk.Ada.Winfo;
with Tcl.Tk.Ada.Wm;
with Tcl.Tklib.Ada.Tooltip; use Tcl.Tklib.Ada.Tooltip;
with Bases; use Bases;
with Bases.LootUI;
with Bases.RecruitUI;
with Bases.SchoolUI;
with Bases.ShipyardUI;
with Bases.UI;
with BasesTypes; use BasesTypes;
with Config; use Config;
with Crafts.UI;
with CoreUI; use CoreUI;
with Crew;
with Dialogs; use Dialogs;
with DebugUI;
with Factions; use Factions;
with GameOptions;
with Help.UI;
with Items;
with Knowledge;
with Log;
with Maps.UI.Commands;
with Messages; use Messages;
with Messages.UI;
with Missions.UI;
with OrdersMenu;
with ShipModules;
with Ships.Cargo;
with Ships.Movement;
with Ships.UI;
with Statistics; use Statistics;
with Statistics.UI;
with Stories; use Stories;
with Trades.UI;
with Themes; use Themes;
with Utils.UI; use Utils.UI;
with WaitMenu;

package body Maps.UI is

   procedure Update_Header is
      use Tcl.Tk.Ada.Widgets.TtkLabel;
      use Crew;
      use Ships.Cargo;
      use Ships.Movement;
      use ShipModules;
      use Tiny_String;

      Have_Worker, Have_Gunner: Boolean := True;
      Need_Cleaning, Need_Repairs, Need_Worker, Have_Pilot, Have_Engineer,
      Have_Trader, Have_Upgrader, Have_Cleaner, Have_Repairman: Boolean :=
        False;
      Item_Amount: Natural;
      Label: Ttk_Label := Get_Widget(pathName => Game_Header & ".time");
      Frame: constant Ttk_Frame :=
        Get_Widget(pathName => Main_Paned & ".combat");
      Faction: constant Faction_Record :=
        Get_Faction(Index => Player_Ship.Crew(1).Faction);
   begin
      configure(Widgt => Label, options => "-text {" & Formated_Time & "}");
      if Game_Settings.Show_Numbers then
         configure
           (Widgt => Label,
            options =>
              "-text {" & Formated_Time & " Speed:" &
              Natural'Image((Real_Speed(Ship => Player_Ship) * 60) / 1_000) &
              " km/h}");
         Add(Widget => Label, Message => "Game time and current ship speed.");
      end if;
      Label.Name := New_String(Str => Game_Header & ".nofuel");
      Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Label);
      Item_Amount := Get_Item_Amount(Item_Type => Fuel_Type);
      if Item_Amount = 0 then
         configure(Widgt => Label, options => "-image nofuelicon");
         Add
           (Widget => Label,
            Message =>
              "You can't travel anymore, because you don't have any fuel for ship.");
         Tcl.Tk.Ada.Grid.Grid(Slave => Label);
      elsif Item_Amount <= Game_Settings.Low_Fuel then
         configure(Widgt => Label, options => "-image lowfuelicon");
         Add
           (Widget => Label,
            Message =>
              "Low level of fuel on ship. Only" & Natural'Image(Item_Amount) &
              " left.");
         Tcl.Tk.Ada.Grid.Grid(Slave => Label);
      end if;
      Label.Name := New_String(Str => Game_Header & ".nodrink");
      Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Label);
      Item_Amount := Get_Items_Amount(I_Type => "Drinks");
      if Item_Amount = 0 then
         configure(Widgt => Label, options => "-image nodrinksicon");
         Add
           (Widget => Label,
            Message =>
              "You don't have any drinks in ship but your crew needs them to live.");
         Tcl.Tk.Ada.Grid.Grid(Slave => Label);
      elsif Item_Amount <= Game_Settings.Low_Drinks then
         configure(Widgt => Label, options => "-image lowdrinksicon");
         Add
           (Widget => Label,
            Message =>
              "Low level of drinks on ship. Only" &
              Natural'Image(Item_Amount) & " left.");
         Tcl.Tk.Ada.Grid.Grid(Slave => Label);
      end if;
      Label.Name := New_String(Str => Game_Header & ".nofood");
      Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Label);
      Item_Amount := Get_Items_Amount(I_Type => "Food");
      if Item_Amount = 0 then
         configure(Widgt => Label, options => "-image nofoodicon");
         Add
           (Widget => Label,
            Message =>
              "You don't have any food in ship but your crew needs it to live.");
         Tcl.Tk.Ada.Grid.Grid(Slave => Label);
      elsif Item_Amount <= Game_Settings.Low_Food then
         configure(Widgt => Label, options => "-image lowfoodicon");
         Add
           (Widget => Label,
            Message =>
              "Low level of food on ship. Only" & Natural'Image(Item_Amount) &
              " left.");
         Tcl.Tk.Ada.Grid.Grid(Slave => Label);
      end if;
      Find_Workers_Loop :
      for Member of Player_Ship.Crew loop
         case Member.Order is
            when PILOT =>
               Have_Pilot := True;
            when ENGINEER =>
               Have_Engineer := True;
            when TALK =>
               Have_Trader := True;
            when UPGRADING =>
               Have_Upgrader := True;
            when CLEAN =>
               Have_Cleaner := True;
            when REPAIR =>
               Have_Repairman := True;
            when others =>
               null;
         end case;
      end loop Find_Workers_Loop;
      Label.Name := New_String(Str => Game_Header & ".overloaded");
      Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Label);
      if Have_Pilot and
        (Have_Engineer or
         Faction.Flags.Contains
           (Item => To_Unbounded_String(Source => "sentientships"))) and
        (Winfo_Get(Widgt => Frame, Info => "exists") = "0"
         or else Winfo_Get(Widgt => Frame, Info => "ismapped") = "0") then
         Set_Overloaded_Info_Block :
         declare
            type Speed_Type is digits 2;
            --## rule off SIMPLIFIABLE_EXPRESSIONS
            Speed: constant Speed_Type :=
              (if Player_Ship.Speed /= DOCKED then
                 (Speed_Type(Real_Speed(Ship => Player_Ship)) / 1_000.0)
               else
                 (Speed_Type
                    (Real_Speed(Ship => Player_Ship, Info_Only => True)) /
                  1_000.0));
            --## rule n SIMPLIFIABLE_EXPRESSIONS
         begin
            if Speed < 0.5 then
               Add
                 (Widget => Label,
                  Message =>
                    "You can't fly with your ship, because it is overloaded.");
               Tcl.Tk.Ada.Grid.Grid(Slave => Label);
            end if;
         end Set_Overloaded_Info_Block;
      end if;
      Check_Workers_Loop :
      for Module of Player_Ship.Modules loop
         case Get_Module(Index => Module.Proto_Index).M_Type is
            when GUN | HARPOON_GUN =>
               if Module.Owner(1) = 0 then
                  Have_Gunner := False;
               elsif Player_Ship.Crew(Module.Owner(1)).Order /= GUNNER then
                  Have_Gunner := False;
               end if;
            when ALCHEMY_LAB .. GREENHOUSE =>
               if Module.Crafting_Index /= Null_Bounded_String then
                  Need_Worker := True;
                  Check_Owners_Loop :
                  for Owner of Module.Owner loop
                     if Owner = 0 then
                        Have_Worker := False;
                     elsif Player_Ship.Crew(Owner).Order /= CRAFT then
                        Have_Worker := False;
                     end if;
                     exit Check_Owners_Loop when not Have_Worker;
                  end loop Check_Owners_Loop;
               end if;
            when CABIN =>
               if Module.Cleanliness /= Module.Quality then
                  Need_Cleaning := True;
               end if;
            when others =>
               null;
         end case;
         if Module.Durability /= Module.Max_Durability then
            Need_Repairs := True;
         end if;
      end loop Check_Workers_Loop;
      Label.Name := New_String(Str => Game_Header & ".pilot");
      if Have_Pilot then
         Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Label);
      else
         if Faction.Flags.Contains
             (Item => To_Unbounded_String(Source => "sentientships")) then
            configure(Widgt => Label, options => "-image nopiloticon");
            Add
              (Widget => Label,
               Message => "No pilot assigned. Ship fly on it own.");
         else
            configure(Widgt => Label, options => "-image piloticon");
            Add
              (Widget => Label,
               Message => "No pilot assigned. Ship can't move.");
         end if;
         Tcl.Tk.Ada.Grid.Grid(Slave => Label);
      end if;
      Label.Name := New_String(Str => Game_Header & ".engineer");
      if Have_Engineer then
         Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Label);
      else
         if Faction.Flags.Contains
             (Item => To_Unbounded_String(Source => "sentientships")) then
            configure(Widgt => Label, options => "-image noengineericon");
            Add
              (Widget => Label,
               Message => "No engineer assigned. Ship fly on it own.");
         else
            configure(Widgt => Label, options => "-image engineericon");
            Add
              (Widget => Label,
               Message => "No engineer assigned. Ship can't move.");
         end if;
         Tcl.Tk.Ada.Grid.Grid(Slave => Label);
      end if;
      Label.Name := New_String(Str => Game_Header & ".gunner");
      if Have_Gunner then
         Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Label);
      else
         configure(Widgt => Label, options => "-style Headerred.TLabel");
         Add
           (Widget => Label,
            Message => "One or more guns don't have a gunner.");
         Tcl.Tk.Ada.Grid.Grid(Slave => Label);
      end if;
      Label.Name := New_String(Str => Game_Header & ".repairs");
      if Need_Repairs then
         if Have_Repairman then
            configure(Widgt => Label, options => "-image repairicon");
            Add(Widget => Label, Message => "The ship is being repaired.");
         else
            configure(Widgt => Label, options => "-image norepairicon");
            Add
              (Widget => Label,
               Message =>
                 "The ship needs repairs but no one is working them.");
         end if;
         Tcl.Tk.Ada.Grid.Grid(Slave => Label);
      else
         Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Label);
      end if;
      Label.Name := New_String(Str => Game_Header & ".crafting");
      if Need_Worker then
         if Have_Worker then
            configure(Widgt => Label, options => "-image manufactureicon");
            Add
              (Widget => Label,
               Message => "All crafting orders are being executed.");
         else
            configure(Widgt => Label, options => "-image nocrafticon");
            Add
              (Widget => Label,
               Message =>
                 "You need to assign crew members to begin manufacturing.");
         end if;
         Tcl.Tk.Ada.Grid.Grid(Slave => Label);
      else
         Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Label);
      end if;
      Label.Name := New_String(Str => Game_Header & ".upgrade");
      if Player_Ship.Upgrade_Module > 0 then
         if Have_Upgrader then
            configure(Widgt => Label, options => "-image upgradeicon");
            Add
              (Widget => Label,
               Message => "A ship module upgrade in progress.");
         else
            configure(Widgt => Label, options => "-image noupgradeicon");
            Add
              (Widget => Label,
               Message =>
                 "A ship module upgrade is in progress but no one is working on it.");
         end if;
         Tcl.Tk.Ada.Grid.Grid(Slave => Label);
      else
         Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Label);
      end if;
      Label.Name := New_String(Str => Game_Header & ".talk");
      if Have_Trader then
         Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Label);
      elsif Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Base_Index > 0 then
         Add
           (Widget => Label,
            Message => "No trader assigned. You need one to talk/trade.");
         Tcl.Tk.Ada.Grid.Grid(Slave => Label);
      elsif Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Event_Index > 0 then
         if Events_List
             (Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Event_Index)
             .E_Type =
           FRIENDLYSHIP then
            Add
              (Widget => Label,
               Message => "No trader assigned. You need one to talk/trade.");
            Tcl.Tk.Ada.Grid.Grid(Slave => Label);
         else
            Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Label);
         end if;
      else
         Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Label);
      end if;
      Label.Name := New_String(Str => Game_Header & ".clean");
      if Need_Cleaning then
         if Have_Cleaner then
            configure(Widgt => Label, options => "-image cleanicon");
            Add(Widget => Label, Message => "Ship is cleaned.");
         else
            configure(Widgt => Label, options => "-image nocleanicon");
            Add
              (Widget => Label,
               Message => "Ship is dirty but no one is cleaning it.");
         end if;
         Tcl.Tk.Ada.Grid.Grid(Slave => Label);
      else
         Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Label);
      end if;
      if Player_Ship.Crew(1).Health = 0 then
         Show_Question
           (Question =>
              "You are dead. Would you like to see your game statistics?",
            Result => "showstats");
      end if;
   end Update_Header;

   -- ****iv* MUI/MUI.MapView
   -- FUNCTION
   -- Text widget with the sky map
   -- SOURCE
   Map_View: Tk_Text;
   -- ****

   -- ****if* MUI/MUI.Get_Map_View
   -- FUNCTION
   -- Get the text widget with the sky map
   -- RESULT
   -- Returns text widget with the sky map
   -- SOURCE
   function Get_Map_View return Tk_Text is
      -- ****
   begin
      return Map_View;
   end Get_Map_View;

   procedure Draw_Map is
      use Ada.Strings.UTF_Encoding.Wide_Strings;

      Map_Char: Wide_Character := Wide_Character'Val(0);
      End_X, End_Y: Integer;
      Map_Height, Map_Width: Positive;
      Map_Tag: Unbounded_String := Null_Unbounded_String;
      Story_X, Story_Y: Natural := 1;
      Current_Theme: constant Theme_Record :=
        Themes_List(To_String(Source => Game_Settings.Interface_Theme));
      Preview: Boolean :=
        (if
           Tcl_GetVar(interp => Get_Context, varName => "mappreview")'Length >
           0
         then True
         else False);
   begin
      if Preview and Player_Ship.Speed /= DOCKED then
         Tcl_UnsetVar(interp => Get_Context, varName => "mappreview");
         Preview := False;
      end if;
      configure(Widgt => Get_Map_View, options => "-state normal");
      Delete
        (TextWidget => Get_Map_View, StartIndex => "1.0", Indexes => "end");
      Map_Height :=
        Positive'Value(cget(Widgt => Get_Map_View, option => "-height"));
      Map_Width :=
        Positive'Value(cget(Widgt => Get_Map_View, option => "-width"));
      Start_Y := Center_Y - (Map_Height / 2);
      Start_X := Center_X - (Map_Width / 2);
      End_Y := Center_Y + (Map_Height / 2);
      End_X := Center_X + (Map_Width / 2);
      if Start_Y < 1 then
         Start_Y := 1;
         End_Y := Map_Height;
      end if;
      if Start_X < 1 then
         Start_X := 1;
         End_X := Map_Width;
      end if;
      if End_Y > 1_024 then
         End_Y := 1_024;
         Start_Y := 1_025 - Map_Height;
      end if;
      if End_X > 1_024 then
         End_X := 1_024;
         Start_X := 1_025 - Map_Width;
      end if;
      if Current_Story.Index /= Null_Unbounded_String then
         Get_Story_Location(Story_X => Story_X, Story_Y => Story_Y);
         if Story_X = Player_Ship.Sky_X and Story_Y = Player_Ship.Sky_Y then
            Story_X := 0;
            Story_Y := 0;
         end if;
      end if;
      if Player_Ship.Speed = DOCKED and
        Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Base_Index = 0 then
         Player_Ship.Speed := Ships.FULL_STOP;
      end if;
      Draw_Map_Y_Loop :
      for Y in Start_Y .. End_Y loop
         Draw_Map_X_Loop :
         for X in Start_X .. End_X loop
            Map_Tag := Null_Unbounded_String;
            if X = Player_Ship.Sky_X and Y = Player_Ship.Sky_Y then
               Map_Char := Current_Theme.Player_Ship_Icon;
            else
               Map_Char := Current_Theme.Empty_Map_Icon;
               Map_Tag :=
                 (if Sky_Map(X, Y).Visited then
                    To_Unbounded_String(Source => "black")
                  else To_Unbounded_String(Source => "unvisited gray"));
               if X = Player_Ship.Destination_X and
                 Y = Player_Ship.Destination_Y then
                  Map_Char := Current_Theme.Target_Icon;
                  Map_Tag :=
                    (if Sky_Map(X, Y).Visited then Null_Unbounded_String
                     else To_Unbounded_String(Source => "unvisited"));
               elsif Current_Story.Index /= Null_Unbounded_String
                 and then (X = Story_X and Y = Story_Y) then
                  Map_Char := Current_Theme.Story_Icon;
                  Map_Tag := To_Unbounded_String(Source => "green");
               elsif Sky_Map(X, Y).Mission_Index > 0 then
                  case Get_Accepted_Mission
                    (Mission_Index => Sky_Map(X, Y).Mission_Index)
                    .M_Type is
                     when DELIVER =>
                        Map_Char := Current_Theme.Deliver_Icon;
                        Map_Tag := To_Unbounded_String(Source => "yellow");
                     when DESTROY =>
                        Map_Char := Current_Theme.Destroy_Icon;
                        Map_Tag := To_Unbounded_String(Source => "red");
                     when PATROL =>
                        Map_Char := Current_Theme.Patrol_Icon;
                        Map_Tag := To_Unbounded_String(Source => "lime");
                     when EXPLORE =>
                        Map_Char := Current_Theme.Explore_Icon;
                        Map_Tag := To_Unbounded_String(Source => "green");
                     when PASSENGER =>
                        Map_Char := Current_Theme.Passenger_Icon;
                        Map_Tag := To_Unbounded_String(Source => "cyan");
                  end case;
                  if not Sky_Map(X, Y).Visited then
                     Append(Source => Map_Tag, New_Item => " unvisited");
                  end if;
               elsif Sky_Map(X, Y).Event_Index > 0 then
                  if Sky_Map(X, Y).Event_Index > Events_List.Last_Index then
                     Sky_Map(X, Y).Event_Index := 0;
                  else
                     case Events_List(Sky_Map(X, Y).Event_Index).E_Type is
                        when ENEMYSHIP =>
                           Map_Char := Current_Theme.Enemy_Ship_Icon;
                           Map_Tag := To_Unbounded_String(Source => "red");
                        when ATTACKONBASE =>
                           Map_Char := Current_Theme.Attack_On_Base_Icon;
                           Map_Tag := To_Unbounded_String(Source => "red2");
                        when ENEMYPATROL =>
                           Map_Char := Current_Theme.Enemy_Patrol_Icon;
                           Map_Tag := To_Unbounded_String(Source => "red3");
                        when DISEASE =>
                           Map_Char := Current_Theme.Disease_Icon;
                           Map_Tag := To_Unbounded_String(Source => "yellow");
                        when FULLDOCKS =>
                           Map_Char := Current_Theme.Full_Docks_Icon;
                           Map_Tag := To_Unbounded_String(Source => "cyan");
                        when DOUBLEPRICE =>
                           Map_Char := Current_Theme.Double_Price_Icon;
                           Map_Tag := To_Unbounded_String(Source => "lime");
                        when TRADER =>
                           Map_Char := Current_Theme.Trader_Icon;
                           Map_Tag := To_Unbounded_String(Source => "green");
                        when FRIENDLYSHIP =>
                           Map_Char := Current_Theme.Friendly_Ship_Icon;
                           Map_Tag := To_Unbounded_String(Source => "green2");
                        when others =>
                           null;
                     end case;
                  end if;
                  if not Sky_Map(X, Y).Visited then
                     Append(Source => Map_Tag, New_Item => " unvisited");
                  end if;
               elsif Sky_Map(X, Y).Base_Index > 0 then
                  Map_Char := Current_Theme.Not_Visited_Base_Icon;
                  if Sky_Bases(Sky_Map(X, Y).Base_Index).Known then
                     if Sky_Bases(Sky_Map(X, Y).Base_Index).Visited.Year >
                       0 then
                        Map_Char :=
                          Get_Faction
                            (Index =>
                               Sky_Bases(Sky_Map(X, Y).Base_Index).Owner)
                            .Base_Icon;
                        Map_Tag :=
                          To_Unbounded_String
                            (Source =>
                               Tiny_String.To_String
                                 (Source =>
                                    Sky_Bases(Sky_Map(X, Y).Base_Index)
                                      .Base_Type));
                     else
                        Map_Tag := To_Unbounded_String(Source => "unvisited");
                     end if;
                  else
                     Map_Tag :=
                       To_Unbounded_String(Source => "unvisited gray");
                  end if;
               end if;
            end if;
            if Preview then
               Preview_Mission_Loop :
               for Mission of Sky_Bases
                 (Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Base_Index)
                 .Missions loop
                  if Mission.Target_X = X and Mission.Target_Y = Y then
                     case Mission.M_Type is
                        when DELIVER =>
                           Map_Char := Current_Theme.Deliver_Icon;
                           Map_Tag := To_Unbounded_String(Source => "yellow");
                        when DESTROY =>
                           Map_Char := Current_Theme.Destroy_Icon;
                           Map_Tag := To_Unbounded_String(Source => "red");
                        when PATROL =>
                           Map_Char := Current_Theme.Patrol_Icon;
                           Map_Tag := To_Unbounded_String(Source => "lime");
                        when EXPLORE =>
                           Map_Char := Current_Theme.Explore_Icon;
                           Map_Tag := To_Unbounded_String(Source => "green");
                        when PASSENGER =>
                           Map_Char := Current_Theme.Passenger_Icon;
                           Map_Tag := To_Unbounded_String(Source => "cyan");
                     end case;
                     if not Sky_Map(X, Y).Visited then
                        Append(Source => Map_Tag, New_Item => " unvisited");
                     end if;
                     exit Preview_Mission_Loop;
                  end if;
               end loop Preview_Mission_Loop;
            end if;
            Insert
              (TextWidget => Get_Map_View, Index => "end",
               Text =>
                 Encode(Item => "" & Map_Char) & " [list " &
                 To_String(Source => Map_Tag) & "]");
         end loop Draw_Map_X_Loop;
         if Y < End_Y then
            Insert
              (TextWidget => Get_Map_View, Index => "end",
               Text => "{" & LF & "}");
         end if;
      end loop Draw_Map_Y_Loop;
      configure(Widgt => Get_Map_View, options => "-state disable");
   end Draw_Map;

   procedure Update_Map_Info
     (X: Positive := Player_Ship.Sky_X; Y: Positive := Player_Ship.Sky_Y) is
      use Items;
      use Tiny_String;

      Map_Info_Text, Event_Info_Text, Color: Unbounded_String :=
        Null_Unbounded_String;
      Map_Info: constant Tk_Text :=
        Get_Widget(pathName => Main_Paned & ".mapframe.info");
      Width: Positive := 1;
      procedure Insert_Text
        (New_Text: String;
         Tag_Name: Unbounded_String := Null_Unbounded_String) is
      begin
         if New_Text'Length > Width then
            Width := New_Text'Length;
         end if;
         if Width > 21 then
            Width := 21;
         end if;
         Insert
           (TextWidget => Map_Info, Index => "end",
            Text =>
              "{" & New_Text & "}" &
              (if Length(Source => Tag_Name) = 0 then ""
               else " [list " & To_String(Source => Tag_Name) & "]"));
      end Insert_Text;
   begin
      configure(Widgt => Map_Info, options => "-state normal");
      Delete(TextWidget => Map_Info, StartIndex => "1.0", Indexes => "end");
      Insert_Text
        (New_Text => "X:" & Positive'Image(X) & " Y:" & Positive'Image(Y));
      if Player_Ship.Sky_X /= X or Player_Ship.Sky_Y /= Y then
         Add_Distance_Info_Block :
         declare
            Distance: constant Positive :=
              Count_Distance(Destination_X => X, Destination_Y => Y);
            Distance_Text: Unbounded_String;
            New_Line_Index: Positive;
         begin
            Distance_Text :=
              To_Unbounded_String
                (Source => LF & "Distance:" & Positive'Image(Distance));
            Insert_Text(New_Text => To_String(Source => Distance_Text));
            Distance_Text := Null_Unbounded_String;
            Travel_Info(Info_Text => Distance_Text, Distance => Distance);
            New_Line_Index :=
              Index(Source => Distance_Text, Pattern => "" & LF, From => 2);
            Insert_Text
              (New_Text =>
                 Slice
                   (Source => Distance_Text, Low => 1,
                    High => New_Line_Index));
            Insert_Text
              (New_Text =>
                 Slice
                   (Source => Distance_Text, Low => New_Line_Index + 1,
                    High => Length(Source => Distance_Text)));
         end Add_Distance_Info_Block;
      end if;
      if Sky_Map(X, Y).Base_Index > 0 then
         Add_Base_Info_Block :
         declare
            use Ada.Characters.Handling;

            Base_Index: constant Bases_Range := Sky_Map(X, Y).Base_Index;
            Base_Info_Text: Unbounded_String := Null_Unbounded_String;
         begin
            if Sky_Bases(Base_Index).Known then
               Insert_Text
                 (New_Text => LF & "Base info:",
                  Tag_Name => To_Unbounded_String(Source => "underline"));
               Insert_Text
                 (New_Text =>
                    LF & "Name: " &
                    Tiny_String.To_String
                      (Source => Sky_Bases(Base_Index).Name));
            end if;
            if Sky_Bases(Base_Index).Visited.Year > 0 then
               Tag_Configure
                 (TextWidget => Map_Info, TagName => "basetype",
                  Options =>
                    "-foreground #" &
                    Get_Base_Type_Color
                      (Base_Type => Sky_Bases(Base_Index).Base_Type));
               Insert_Text(New_Text => LF & "Type: ");
               Insert_Text
                 (New_Text =>
                    Get_Base_Type_Name
                      (Base_Type => Sky_Bases(Base_Index).Base_Type),
                  Tag_Name => To_Unbounded_String(Source => "basetype"));
               if Sky_Bases(Base_Index).Population > 0 then
                  Base_Info_Text := To_Unbounded_String(Source => "" & LF);
               end if;
               if Sky_Bases(Base_Index).Population > 0 and
                 Sky_Bases(Base_Index).Population < 150 then
                  Append
                    (Source => Base_Info_Text,
                     New_Item => "Population: small");
               elsif Sky_Bases(Base_Index).Population > 149 and
                 Sky_Bases(Base_Index).Population < 300 then
                  Append
                    (Source => Base_Info_Text,
                     New_Item => "Population: medium");
               elsif Sky_Bases(Base_Index).Population > 299 then
                  Append
                    (Source => Base_Info_Text,
                     New_Item => "Population: large");
               end if;
               Insert_Text(New_Text => To_String(Source => Base_Info_Text));
               Insert_Text
                 (New_Text =>
                    LF & "Size: " &
                    To_Lower
                      (Item => Bases_Size'Image(Sky_Bases(Base_Index).Size)) &
                    LF);
               if Sky_Bases(Base_Index).Population > 0 then
                  Base_Info_Text :=
                    To_Unbounded_String
                      (Source =>
                         "Owner: " &
                         Tiny_String.To_String
                           (Source =>
                              Get_Faction(Index => Sky_Bases(Base_Index).Owner)
                                .Name));
               else
                  Base_Info_Text :=
                    To_Unbounded_String(Source => "Base is abandoned");
               end if;
               Insert_Text(New_Text => To_String(Source => Base_Info_Text));
               if Sky_Bases(Base_Index).Population > 0 then
                  Base_Info_Text := To_Unbounded_String(Source => "" & LF);
                  case Sky_Bases(Base_Index).Reputation.Level is
                     when -100 .. -75 =>
                        Append
                          (Source => Base_Info_Text,
                           New_Item => "You are hated here");
                        Color := To_Unbounded_String(Source => "red");
                     when -74 .. -50 =>
                        Append
                          (Source => Base_Info_Text,
                           New_Item => "You are outlawed here");
                        Color := To_Unbounded_String(Source => "red");
                     when -49 .. -25 =>
                        Append
                          (Source => Base_Info_Text,
                           New_Item => "You are disliked here");
                        Color := To_Unbounded_String(Source => "red");
                     when -24 .. -1 =>
                        Append
                          (Source => Base_Info_Text,
                           New_Item => "They are unfriendly to you");
                        Color := To_Unbounded_String(Source => "red");
                     when 0 =>
                        Append
                          (Source => Base_Info_Text,
                           New_Item => "You are unknown here");
                        Color := Null_Unbounded_String;
                     when 1 .. 25 =>
                        Append
                          (Source => Base_Info_Text,
                           New_Item => "You are know here as visitor");
                        Color := To_Unbounded_String(Source => "green");
                     when 26 .. 50 =>
                        Append
                          (Source => Base_Info_Text,
                           New_Item => "You are know here as trader");
                        Color := To_Unbounded_String(Source => "green");
                     when 51 .. 75 =>
                        Append
                          (Source => Base_Info_Text,
                           New_Item => "You are know here as friend");
                        Color := To_Unbounded_String(Source => "green");
                     when 76 .. 100 =>
                        Append
                          (Source => Base_Info_Text,
                           New_Item => "You are well known here");
                        Color := To_Unbounded_String(Source => "green");
                  end case;
                  Insert_Text
                    (New_Text => To_String(Source => Base_Info_Text),
                     Tag_Name => Color);
               end if;
               if Base_Index = Player_Ship.Home_Base then
                  Insert_Text
                    (New_Text => LF & "It is your home base",
                     Tag_Name => To_Unbounded_String(Source => "cyan"));
               end if;
            end if;
         end Add_Base_Info_Block;
      end if;
      if Sky_Map(X, Y).Mission_Index > 0 then
         Add_Mission_Info_Block :
         declare
            Mission_Index: constant Mission_Container.Extended_Index :=
              Sky_Map(X, Y).Mission_Index;
            Mission_Info_Text: Unbounded_String;
         begin
            Mission_Info_Text := To_Unbounded_String(Source => "" & LF);
            if Sky_Map(X, Y).Base_Index > 0 or
              Sky_Map(X, Y).Event_Index > 0 then
               Append(Source => Map_Info_Text, New_Item => LF);
            end if;
            case Get_Accepted_Mission(Mission_Index => Mission_Index).M_Type is
               when DELIVER =>
                  Append
                    (Source => Mission_Info_Text,
                     New_Item =>
                       "Deliver " &
                       To_String
                         (Source =>
                            Get_Proto_Item
                              (Index =>
                                 Get_Accepted_Mission
                                   (Mission_Index => Mission_Index)
                                   .Item_Index)
                              .Name));
               when DESTROY =>
                  Append
                    (Source => Mission_Info_Text,
                     New_Item =>
                       "Destroy " &
                       To_String
                         (Source =>
                            Get_Proto_Ship
                              (Proto_Index =>
                                 Get_Accepted_Mission
                                   (Mission_Index => Mission_Index)
                                   .Ship_Index)
                              .Name));
               when PATROL =>
                  Append
                    (Source => Mission_Info_Text, New_Item => "Patrol area");
               when EXPLORE =>
                  Append
                    (Source => Mission_Info_Text, New_Item => "Explore area");
               when PASSENGER =>
                  Append
                    (Source => Mission_Info_Text,
                     New_Item => "Transport passenger");
            end case;
            Insert_Text(New_Text => To_String(Source => Mission_Info_Text));
         end Add_Mission_Info_Block;
      end if;
      if Current_Story.Index /= Null_Unbounded_String then
         Add_Story_Info_Block :
         declare
            --## rule off IMPROPER_INITIALIZATION
            Story_X, Story_Y: Natural := 1;
            --## rule on IMPROPER_INITIALIZATION
            Finish_Condition: Step_Condition_Type := ANY;
         begin
            Get_Story_Location(Story_X => Story_X, Story_Y => Story_Y);
            if Story_X = Player_Ship.Sky_X and Story_Y = Player_Ship.Sky_Y then
               Story_X := 0;
               Story_Y := 0;
            end if;
            if X = Story_X and Y = Story_Y then
               Finish_Condition :=
                 (if Current_Story.Current_Step = 0 then
                    Stories_List(Current_Story.Index).Starting_Step
                      .Finish_Condition
                  elsif Current_Story.Current_Step > 0 then
                    Stories_List(Current_Story.Index).Steps
                      (Current_Story.Current_Step)
                      .Finish_Condition
                  else Stories_List(Current_Story.Index).Final_Step
                      .Finish_Condition);
               if Finish_Condition in ASKINBASE | DESTROYSHIP | EXPLORE then
                  Insert_Text(New_Text => LF & "Story leads you here");
               end if;
            end if;
         end Add_Story_Info_Block;
      end if;
      if X = Player_Ship.Sky_X and Y = Player_Ship.Sky_Y then
         Insert_Text
           (New_Text => LF & "You are here",
            Tag_Name => To_Unbounded_String(Source => "yellow"));
      end if;
      if Sky_Map(X, Y).Event_Index > 0 then
         Add_Event_Info_Block :
         declare
            Event_Index: constant Events_Container.Extended_Index :=
              Sky_Map(X, Y).Event_Index;
         begin
            if Events_List(Event_Index).E_Type /= BASERECOVERY then
               Event_Info_Text := To_Unbounded_String(Source => LF & LF);
            end if;
            case Events_List(Event_Index).E_Type is
               when TRADER =>
                  Append
                    (Source => Event_Info_Text,
                     New_Item =>
                       To_String
                         (Source =>
                            Get_Proto_Ship
                              (Proto_Index =>
                                 Events_List(Event_Index).Ship_Index)
                              .Name));
                  Color := To_Unbounded_String(Source => "green");
               when FRIENDLYSHIP =>
                  Append
                    (Source => Event_Info_Text,
                     New_Item =>
                       To_String
                         (Source =>
                            Get_Proto_Ship
                              (Proto_Index =>
                                 Events_List(Event_Index).Ship_Index)
                              .Name));
                  Color := To_Unbounded_String(Source => "green2");
               when ENEMYSHIP =>
                  Append
                    (Source => Event_Info_Text,
                     New_Item =>
                       To_String
                         (Source =>
                            Get_Proto_Ship
                              (Proto_Index =>
                                 Events_List(Event_Index).Ship_Index)
                              .Name));
                  Color := To_Unbounded_String(Source => "red");
               when FULLDOCKS =>
                  Append
                    (Source => Event_Info_Text,
                     New_Item => "Full docks in base");
                  Color := To_Unbounded_String(Source => "cyan");
               when ATTACKONBASE =>
                  Append
                    (Source => Event_Info_Text,
                     New_Item => "Base is under attack");
                  Color := To_Unbounded_String(Source => "red");
               when DISEASE =>
                  Append
                    (Source => Event_Info_Text, New_Item => "Disease in base");
                  Color := To_Unbounded_String(Source => "yellow");
               when ENEMYPATROL =>
                  Append
                    (Source => Event_Info_Text, New_Item => "Enemy patrol");
                  Color := To_Unbounded_String(Source => "red3");
               when DOUBLEPRICE =>
                  Append
                    (Source => Event_Info_Text,
                     New_Item =>
                       "Double price for " &
                       To_String
                         (Source =>
                            Get_Proto_Item
                              (Index => Events_List(Event_Index).Item_Index)
                              .Name));
                  Color := To_Unbounded_String(Source => "lime");
               when NONE | BASERECOVERY =>
                  null;
            end case;
            Insert_Text
              (New_Text => To_String(Source => Event_Info_Text),
               Tag_Name => Color);
         end Add_Event_Info_Block;
      end if;
      configure
        (Widgt => Map_Info,
         options =>
           "-state disabled -width" & Positive'Image(Width) & " -height " &
           Text.Count
             (TextWidget => Map_Info, Options => "-displaylines",
              Index1 => "0.0", Index2 => "end"));
   end Update_Map_Info;

   procedure Update_Move_Buttons is
      use Tcl.Tk.Ada.Widgets.TtkEntry.TtkComboBox;
      use Tcl.Tk.Ada.Widgets.TtkWidget;

      Move_Buttons_Names: constant array(1 .. 8) of Unbounded_String :=
        (1 => To_Unbounded_String(Source => "nw"),
         2 => To_Unbounded_String(Source => "n"),
         3 => To_Unbounded_String(Source => "ne"),
         4 => To_Unbounded_String(Source => "w"),
         5 => To_Unbounded_String(Source => "e"),
         6 => To_Unbounded_String(Source => "sw"),
         7 => To_Unbounded_String(Source => "s"),
         8 => To_Unbounded_String(Source => "se"));
      Move_Buttons_Tooltips: constant array(1 .. 8) of Unbounded_String :=
        (1 => To_Unbounded_String(Source => "Move ship up and left"),
         2 => To_Unbounded_String(Source => "Move ship up"),
         3 => To_Unbounded_String(Source => "Move ship up and right"),
         4 => To_Unbounded_String(Source => "Move ship left"),
         5 => To_Unbounded_String(Source => "Move ship right"),
         6 => To_Unbounded_String(Source => "Move ship down and left"),
         7 => To_Unbounded_String(Source => "Move ship down"),
         8 => To_Unbounded_String(Source => "Move ship down and right"));
      Frame_Name: constant String := Main_Paned & ".controls.buttons";
      Button: Ttk_Button := Get_Widget(pathName => Frame_Name & ".wait");
      Speedbox: constant Ttk_ComboBox :=
        Get_Widget(pathName => Frame_Name & ".box.speed");
   begin
      if Player_Ship.Speed = DOCKED then
         Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Speedbox);
         Button.Name := New_String(Str => Frame_Name & ".box.moveto");
         Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Button);
         Button.Name := New_String(Str => Frame_Name & ".wait");
         configure(Widgt => Button, options => "-image waiticon");
         Add(Widget => Button, Message => "Wait 1 minute.");
         Disable_Move_Buttons_Loop :
         for ButtonName of Move_Buttons_Names loop
            Button.Name :=
              New_String
                (Str => Frame_Name & "." & To_String(Source => ButtonName));
            State(Widget => Button, StateSpec => "disabled");
            Add
              (Widget => Button,
               Message =>
                 "You have to give order 'Undock' from\nMenu->Ship orders first to move ship.");
         end loop Disable_Move_Buttons_Loop;
      else
         Current
           (ComboBox => Speedbox,
            NewIndex => Natural'Image(Ship_Speed'Pos(Player_Ship.Speed) - 1));
         Tcl.Tk.Ada.Grid.Grid(Slave => Speedbox);
         if Player_Ship.Destination_X > 0 and
           Player_Ship.Destination_Y > 0 then
            Button.Name := New_String(Str => Frame_Name & ".box.moveto");
            Tcl.Tk.Ada.Grid.Grid(Slave => Button);
            Tcl.Tk.Ada.Grid.Grid_Configure(Slave => Speedbox);
            Button.Name := New_String(Str => Frame_Name & ".wait");
            configure(Widgt => Button, options => "-image movestepicon");
            Add
              (Widget => Button,
               Message => "Move ship one map field toward destination.");
            Tcl.Tk.Ada.Grid.Grid(Slave => Button);
         else
            Button.Name := New_String(Str => Frame_Name & ".box.moveto");
            Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Button);
            Tcl.Tk.Ada.Grid.Grid_Configure(Slave => Speedbox);
            Button.Name := New_String(Str => Frame_Name & ".wait");
            configure(Widgt => Button, options => "-image waiticon");
            Add(Widget => Button, Message => "Wait 1 minute.");
         end if;
         Enable_Move_Buttons_Loop :
         for I in Move_Buttons_Names'Range loop
            Button.Name :=
              New_String
                (Str =>
                   Frame_Name & "." &
                   To_String(Source => Move_Buttons_Names(I)));
            State(Widget => Button, StateSpec => "!disabled");
            Add
              (Widget => Button,
               Message => To_String(Source => Move_Buttons_Tooltips(I)));
         end loop Enable_Move_Buttons_Loop;
      end if;
   end Update_Move_Buttons;

   procedure Create_Game_Ui is
      use Ada.Strings.Fixed;
      use GNAT.Directory_Operations;
      use Tcl.Tk.Ada.Widgets.TtkPanedWindow;
      use Tcl.Tk.Ada.Wm;
      use DebugUI;
      use Log;
      use Tiny_String;

      Game_Frame: constant Ttk_Frame := Get_Widget(pathName => ".gameframe");
      Paned: constant Ttk_PanedWindow :=
        Get_Widget(pathName => Game_Frame & ".paned");
      Button: constant Ttk_Button :=
        Get_Widget(pathName => Paned & ".mapframe.buttons.hide");
      Steam_Sky_Map_Error: exception;
      Header: constant Ttk_Frame :=
        Get_Widget(pathName => Game_Frame & ".header");
      Messages_Frame: constant Ttk_Frame :=
        Get_Widget(pathName => Paned & ".controls.messages");
      Paned_Position: Natural := 0;
      New_Start: Boolean := False;
   begin
      Map_View := Get_Widget(pathName => Paned & ".mapframe.map");
      if Winfo_Get(Widgt => Get_Map_View, Info => "exists") = "0" then
         New_Start := True;
         Load_Keys_Block :
         declare
            use Ada.Text_IO;

            Keys_File: File_Type;
            Raw_Data, Field_Name, Value: Unbounded_String :=
              Null_Unbounded_String;
            Equal_Index: Natural := 0;
         begin
            Open
              (File => Keys_File, Mode => In_File,
               Name => To_String(Source => Save_Directory) & "keys.cfg");
            Load_Accelerators_Loop :
            while not End_Of_File(File => Keys_File) loop
               Raw_Data :=
                 To_Unbounded_String(Source => Get_Line(File => Keys_File));
               if Length(Source => Raw_Data) = 0 then
                  goto End_Of_Loop;
               end if;
               Equal_Index := Index(Source => Raw_Data, Pattern => "=");
               Field_Name :=
                 Head(Source => Raw_Data, Count => Equal_Index - 2);
               Value :=
                 Tail
                   (Source => Raw_Data,
                    Count => Length(Source => Raw_Data) - Equal_Index - 1);
               if Field_Name = To_Unbounded_String(Source => "ShipInfo") then
                  Menu_Accelerators(1) := Value;
               elsif Field_Name = To_Unbounded_String(Source => "Orders") then
                  Menu_Accelerators(2) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "Crafting") then
                  Menu_Accelerators(3) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "LastMessages") then
                  Menu_Accelerators(4) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "Knowledge") then
                  Menu_Accelerators(5) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "WaitOrders") then
                  Menu_Accelerators(6) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "GameStats") then
                  Menu_Accelerators(7) := Value;
               elsif Field_Name = To_Unbounded_String(Source => "Help") then
                  Menu_Accelerators(8) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "GameOptions") then
                  Menu_Accelerators(9) := Value;
               elsif Field_Name = To_Unbounded_String(Source => "Quit") then
                  Menu_Accelerators(10) := Value;
               elsif Field_Name = To_Unbounded_String(Source => "Resign") then
                  Menu_Accelerators(11) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "GameMenu") then
                  Map_Accelerators(1) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MapOptions") then
                  Map_Accelerators(2) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "ZoomInMap") then
                  Map_Accelerators(3) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "ZoomOutMap") then
                  Map_Accelerators(4) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveUpLeft") then
                  Map_Accelerators(5) := Value;
               elsif Field_Name = To_Unbounded_String(Source => "MoveUp") then
                  Map_Accelerators(6) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveUpRight") then
                  Map_Accelerators(7) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveLeft") then
                  Map_Accelerators(8) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "WaitInPlace") then
                  Map_Accelerators(10) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveRight") then
                  Map_Accelerators(9) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveDownLeft") then
                  Map_Accelerators(11) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveDown") then
                  Map_Accelerators(12) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveDownRight") then
                  Map_Accelerators(13) := Value;
               elsif Field_Name = To_Unbounded_String(Source => "MoveTo") then
                  Map_Accelerators(14) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "CenterMap") then
                  Map_Accelerators(15) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "CenterMapOnHomeBase") then
                  Map_Accelerators(16) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveMapUpLeft") then
                  Map_Accelerators(17) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveMapUp") then
                  Map_Accelerators(18) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveMapUpRight") then
                  Map_Accelerators(19) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveMapLeft") then
                  Map_Accelerators(20) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveMapRight") then
                  Map_Accelerators(21) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveMapDownLeft") then
                  Map_Accelerators(22) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveMapDown") then
                  Map_Accelerators(23) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveMapDownRight") then
                  Map_Accelerators(24) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveCursorUpLeft") then
                  Map_Accelerators(25) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveCursorUp") then
                  Map_Accelerators(26) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveCursorUpRight") then
                  Map_Accelerators(27) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveCursorLeft") then
                  Map_Accelerators(28) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveCursorRight") then
                  Map_Accelerators(29) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveCursorDownLeft") then
                  Map_Accelerators(30) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveCursorDown") then
                  Map_Accelerators(31) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "MoveCursorDownRight") then
                  Map_Accelerators(32) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "LeftClickMouse") then
                  Map_Accelerators(33) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "FullStop") then
                  Map_Accelerators(34) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "QuarterSpeed") then
                  Map_Accelerators(35) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "HalfSpeed") then
                  Map_Accelerators(36) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "FullSpeed") then
                  Map_Accelerators(37) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "FullScreen") then
                  Full_Screen_Accel := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "ResizeFirst") then
                  General_Accelerators(1) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "ResizeSecond") then
                  General_Accelerators(2) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "ResizeThird") then
                  General_Accelerators(3) := Value;
               elsif Field_Name =
                 To_Unbounded_String(Source => "ResizeForth") then
                  General_Accelerators(4) := Value;
               end if;
               <<End_Of_Loop>>
            end loop Load_Accelerators_Loop;
            Close(File => Keys_File);
         exception
            when others =>
               if Dir_Separator = '\' then
                  Map_Accelerators(5) := To_Unbounded_String(Source => "Home");
                  Map_Accelerators(6) := To_Unbounded_String(Source => "Up");
                  Map_Accelerators(7) :=
                    To_Unbounded_String(Source => "Prior");
                  Map_Accelerators(8) := To_Unbounded_String(Source => "Left");
                  Map_Accelerators(9) :=
                    To_Unbounded_String(Source => "Clear");
                  Map_Accelerators(10) :=
                    To_Unbounded_String(Source => "Right");
                  Map_Accelerators(11) := To_Unbounded_String(Source => "End");
                  Map_Accelerators(12) :=
                    To_Unbounded_String(Source => "Down");
                  Map_Accelerators(13) :=
                    To_Unbounded_String(Source => "Next");
                  Map_Accelerators(14) :=
                    To_Unbounded_String(Source => "slash");
                  Map_Accelerators(17) :=
                    To_Unbounded_String(Source => "Shift-Home");
                  Map_Accelerators(18) :=
                    To_Unbounded_String(Source => "Shift-Up");
                  Map_Accelerators(19) :=
                    To_Unbounded_String(Source => "Shift-Prior");
                  Map_Accelerators(20) :=
                    To_Unbounded_String(Source => "Shift-Left");
                  Map_Accelerators(21) :=
                    To_Unbounded_String(Source => "Shift-Right");
                  Map_Accelerators(22) :=
                    To_Unbounded_String(Source => "Shift-End");
                  Map_Accelerators(23) :=
                    To_Unbounded_String(Source => "Shift-Down");
                  Map_Accelerators(24) :=
                    To_Unbounded_String(Source => "Shift-Next");
                  Map_Accelerators(25) :=
                    To_Unbounded_String(Source => "Control-Home");
                  Map_Accelerators(26) :=
                    To_Unbounded_String(Source => "Control-Up");
                  Map_Accelerators(27) :=
                    To_Unbounded_String(Source => "Control-Prior");
                  Map_Accelerators(28) :=
                    To_Unbounded_String(Source => "Control-Left");
                  Map_Accelerators(29) :=
                    To_Unbounded_String(Source => "Control-Right");
                  Map_Accelerators(30) :=
                    To_Unbounded_String(Source => "Control-End");
                  Map_Accelerators(31) :=
                    To_Unbounded_String(Source => "Control-Down");
                  Map_Accelerators(32) :=
                    To_Unbounded_String(Source => "Control-Next");
               end if;
         end Load_Keys_Block;
         Tcl_EvalFile
           (interp => Get_Context,
            fileName =>
              To_String(Source => Data_Directory) & "ui" & Dir_Separator &
              "game.tcl");
         Main_Paned := Paned;
         Game_Header := Header;
         Close_Button := Get_Widget(pathName => Game_Header & ".closebutton");
         Set_Theme;
         OrdersMenu.Add_Commands;
         Maps.UI.Commands.Add_Commands;
         WaitMenu.Add_Commands;
         Help.UI.Add_Commands;
         Ships.UI.Add_Commands;
         Crafts.UI.Add_Commands;
         Messages.UI.Add_Commands;
         GameOptions.Add_Commands;
         Trades.UI.Add_Commands;
         SchoolUI.Add_Commands;
         RecruitUI.Add_Commands;
         Bases.UI.Add_Commands;
         ShipyardUI.Add_Commands;
         LootUI.Add_Commands;
         Knowledge.Add_Commands;
         Missions.UI.Add_Commands;
         Statistics.UI.Add_Commands;
         Bind
           (Widgt => Messages_Frame, Sequence => "<Configure>",
            Script => "ResizeLastMessages");
         Bind
           (Widgt => Get_Map_View, Sequence => "<Configure>",
            Script => "DrawMap");
         Bind
           (Widgt => Get_Map_View, Sequence => "<Motion>",
            Script => "{UpdateMapInfo %x %y}");
         Bind
           (Widgt => Get_Map_View,
            Sequence =>
              "<Button-" & (if Game_Settings.Right_Button then "3" else "1") &
              ">",
            Script => "{ShowDestinationMenu %X %Y}");
         Bind
           (Widgt => Get_Map_View, Sequence => "<MouseWheel>",
            Script => "{if {%D > 0} {ZoomMap raise} else {ZoomMap lower}}");
         Bind
           (Widgt => Get_Map_View, Sequence => "<Button-4>",
            Script => "{ZoomMap raise}");
         Bind
           (Widgt => Get_Map_View, Sequence => "<Button-5>",
            Script => "{ZoomMap lower}");
         Set_Keys;
         if Log.Debug_Mode = Log.MENU then
            Show_Debug_Ui;
         end if;
      else
         Tcl.Tk.Ada.Pack.Pack
           (Slave => Game_Frame, Options => "-fill both -expand true");
      end if;
      Tcl_SetVar
        (interp => Get_Context, varName => "refreshmap", newValue => "1");
      Wm_Set
        (Widgt => Get_Main_Window(Interp => Get_Context), Action => "title",
         Options => "{Steam Sky}");
      if Game_Settings.Full_Screen then
         Wm_Set
           (Widgt => Get_Main_Window(Interp => Get_Context),
            Action => "attributes", Options => "-fullscreen 1");
      end if;
      Set_Accelerators_Loop :
      for Accelerator of Menu_Accelerators loop
         Bind_To_Main_Window
           (Interp => Get_Context,
            Sequence =>
              "<" &
              To_String
                (Source =>
                   Insert
                     (Source => Accelerator,
                      Before =>
                        Index
                          (Source => Accelerator, Pattern => "-",
                           Going => Backward) +
                        1,
                      New_Item => "KeyPress-")) &
              ">",
            Script => "{InvokeMenu " & To_String(Source => Accelerator) & "}");
      end loop Set_Accelerators_Loop;
      if Index
          (Source =>
             Tcl.Tk.Ada.Grid.Grid_Slaves
               (Master => Get_Main_Window(Interp => Get_Context)),
           Pattern => ".gameframe.header") =
        0 then
         Tcl.Tk.Ada.Grid.Grid(Slave => Header);
      end if;
      Update_Header;
      Center_X := Player_Ship.Sky_X;
      Center_Y := Player_Ship.Sky_Y;
      Set_Tags_Loop :
      for Base_Type of Bases_Types loop
         exit Set_Tags_Loop when Length(Source => Base_Type) = 0;
         Tag_Configure
           (TextWidget => Get_Map_View,
            TagName => To_String(Source => Base_Type),
            Options =>
              "-foreground #" & Get_Base_Type_Color(Base_Type => Base_Type));
      end loop Set_Tags_Loop;
      Paned_Position :=
        (if Game_Settings.Window_Height - Game_Settings.Messages_Position < 0
         then Game_Settings.Window_Height
         else Game_Settings.Window_Height - Game_Settings.Messages_Position);
      SashPos
        (Paned => Paned, Index => "0",
         NewPos => Natural'Image(Paned_Position));
      if Index
          (Source =>
             Tcl.Tk.Ada.Grid.Grid_Slaves
               (Master => Get_Main_Window(Interp => Get_Context)),
           Pattern => ".gameframe.paned") =
        0 then
         Tcl.Tk.Ada.Grid.Grid(Slave => Paned);
      end if;
      if Invoke(Buttn => Button) /= "" then
         raise Steam_Sky_Map_Error with "Can't hide map buttons";
      end if;
      Bind_To_Main_Window
        (Interp => Get_Context, Sequence => "<Escape>",
         Script => "{InvokeButton " & Close_Button & "}");
      Update_Messages;
      if not New_Start then
         Tcl_Eval(interp => Get_Context, strng => "DrawMap");
      end if;
      Update_Move_Buttons;
      Update_Map_Info;
      if not Game_Settings.Show_Last_Messages then
         Tcl.Tk.Ada.Grid.Grid_Remove(Slave => Messages_Frame);
      end if;
      Tcl_SetVar
        (interp => Get_Context, varName => "shipname",
         newValue => To_String(Source => Player_Ship.Name));
      Tcl_SetVar
        (interp => Get_Context, varName => "gamestate", newValue => "general");
   end Create_Game_Ui;

   procedure Show_Sky_Map(Clear: Boolean := False) is
   begin
      Tcl_SetVar
        (interp => Get_Context, varName => "refreshmap", newValue => "1");
      if Clear then
         Show_Screen(New_Screen_Name => "mapframe");
      end if;
      Tcl_SetVar
        (interp => Get_Context, varName => "gamestate", newValue => "general");
      Update_Header;
      if Tcl_GetVar(interp => Get_Context, varName => "refreshmap") = "1" then
         Tcl_Eval(interp => Get_Context, strng => "DrawMap");
      end if;
      Update_Move_Buttons;
      Tcl_Eval(interp => Get_Context, strng => "update");
      Update_Messages;
      if Current_Story.Index /= Null_Unbounded_String and
        Current_Story.Show_Text then
         if Current_Story.Current_Step > -2 then
            Show_Info
              (Text => To_String(Source => Get_Current_Story_Text),
               Title => "Story");
         else
            Finish_Story;
            if Player_Ship.Crew(1).Health = 0 then
               Show_Question
                 (Question =>
                    "You are dead. Would you like to see your game statistics?",
                  Result => "showstats");
            end if;
         end if;
         Current_Story.Show_Text := False;
      end if;
   end Show_Sky_Map;

   procedure Set_Keys is
      Tcl_Commands_Array: constant array
        (Map_Accelerators'Range) of Unbounded_String :=
        (1 =>
           To_Unbounded_String
             (Source =>
                "{if {[winfo class [focus]] != {TEntry} && [tk busy status " &
                Game_Header & "] == 0} {ShowGameMenu}}"),
         2 =>
           To_Unbounded_String
             (Source => "{" & Main_Paned & ".mapframe.buttons.wait invoke}"),
         3 => To_Unbounded_String(Source => "{ZoomMap raise}"),
         4 => To_Unbounded_String(Source => "{ZoomMap lower}"),
         5 => To_Unbounded_String(Source => "{InvokeButton $bframe.nw}"),
         6 => To_Unbounded_String(Source => "{InvokeButton $bframe.n}"),
         7 => To_Unbounded_String(Source => "{InvokeButton $bframe.ne}"),
         8 => To_Unbounded_String(Source => "{InvokeButton $bframe.w}"),
         9 => To_Unbounded_String(Source => "{InvokeButton $bframe.wait}"),
         10 => To_Unbounded_String(Source => "{InvokeButton $bframe.e}"),
         11 => To_Unbounded_String(Source => "{InvokeButton $bframe.sw}"),
         12 => To_Unbounded_String(Source => "{InvokeButton $bframe.s}"),
         13 => To_Unbounded_String(Source => "{InvokeButton $bframe.se}"),
         14 =>
           To_Unbounded_String(Source => "{InvokeButton $bframe.box.moveto}"),
         15 => To_Unbounded_String(Source => "{MoveMap centeronship}"),
         16 => To_Unbounded_String(Source => "{MoveMap centeronhome}"),
         17 => To_Unbounded_String(Source => "{MoveMap nw}"),
         18 => To_Unbounded_String(Source => "{MoveMap n}"),
         19 => To_Unbounded_String(Source => "{MoveMap ne}"),
         20 => To_Unbounded_String(Source => "{MoveMap w}"),
         21 => To_Unbounded_String(Source => "{MoveMap e}"),
         22 => To_Unbounded_String(Source => "{MoveMap sw}"),
         23 => To_Unbounded_String(Source => "{MoveMap s}"),
         24 => To_Unbounded_String(Source => "{MoveMap se}"),
         25 => To_Unbounded_String(Source => "{MoveCursor nw %x %y}"),
         26 => To_Unbounded_String(Source => "{MoveCursor n %x %y}"),
         27 => To_Unbounded_String(Source => "{MoveCursor ne %x %y}"),
         28 => To_Unbounded_String(Source => "{MoveCursor w %x %y}"),
         29 => To_Unbounded_String(Source => "{MoveCursor e %x %y}"),
         30 => To_Unbounded_String(Source => "{MoveCursor sw %x %y}"),
         31 => To_Unbounded_String(Source => "{MoveCursor s %x %y}"),
         32 => To_Unbounded_String(Source => "{MoveCursor se %x %y}"),
         33 => To_Unbounded_String(Source => "{MoveCursor click %x %y}"),
         34 =>
           To_Unbounded_String
             (Source =>
                "{" & Main_Paned & ".controls.buttons.box.speed current 0}"),
         35 =>
           To_Unbounded_String
             (Source =>
                "{" & Main_Paned & ".controls.buttons.box.speed current 1}"),
         36 =>
           To_Unbounded_String
             (Source =>
                "{" & Main_Paned & ".controls.buttons.box.speed current 2}"),
         37 =>
           To_Unbounded_String
             (Source =>
                "{" & Main_Paned & ".controls.buttons.box.speed current 3}"));
   begin
      Bind_Commands_Loop :
      for I in Tcl_Commands_Array'Range loop
         Bind_To_Main_Window
           (Interp => Get_Context,
            Sequence =>
              "<" &
              To_String
                (Source =>
                   Insert
                     (Source => Map_Accelerators(I),
                      Before =>
                        Index
                          (Source => Map_Accelerators(I), Pattern => "-",
                           Going => Backward) +
                        1,
                      New_Item => "KeyPress-")) &
              ">",
            Script => To_String(Source => Tcl_Commands_Array(I)));
      end loop Bind_Commands_Loop;
      Bind_To_Main_Window
        (Interp => Get_Context,
         Sequence =>
           "<" &
           To_String
             (Source =>
                Insert
                  (Source => Full_Screen_Accel,
                   Before =>
                     Index
                       (Source => Full_Screen_Accel, Pattern => "-",
                        Going => Backward) +
                     1,
                   New_Item => "KeyPress-")) &
           ">",
         Script => "{ToggleFullScreen}");
   end Set_Keys;

   procedure Finish_Story is
   begin
      Game_Stats.Points :=
        Game_Stats.Points + (10_000 * Current_Story.Max_Steps);
      Clear_Current_Story;
      Show_Question
        (Question =>
           To_String(Source => Stories_List(Current_Story.Index).End_Text) &
           " Are you want to finish game?",
         Result => "retire");
   end Finish_Story;

end Maps.UI;
