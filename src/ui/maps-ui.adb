--    Copyright 2018 Bartek thindil Jasicki
--
--    This file is part of Steam Sky.
--
--    Steam Sky is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    Steam Sky is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    You should have received a copy of the GNU General Public License
--    along with Steam Sky.  If not, see <http://www.gnu.org/licenses/>.

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Directories; use Ada.Directories;
with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Containers; use Ada.Containers;
with Ada.Characters.Latin_1; use Ada.Characters.Latin_1;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with Gtk.Window; use Gtk.Window;
with Gtk.Label; use Gtk.Label;
with Gtk.Combo_Box; use Gtk.Combo_Box;
with Gtk.Text_Buffer; use Gtk.Text_Buffer;
with Gtk.Text_Iter; use Gtk.Text_Iter;
with Gtk.Text_Tag_Table; use Gtk.Text_Tag_Table;
with Gtk.Text_Tag; use Gtk.Text_Tag;
with Gtk.Text_View; use Gtk.Text_View;
with Gtk.Enums; use Gtk.Enums;
with Gtk.Container; use Gtk.Container;
with Gtk.Accel_Map; use Gtk.Accel_Map;
with Gtk.Accel_Group; use Gtk.Accel_Group;
with Gtk.Stack; use Gtk.Stack;
with Gtk.Overlay; use Gtk.Overlay;
with Gtk.Text_Mark; use Gtk.Text_Mark;
with Glib; use Glib;
with Glib.Error; use Glib.Error;
with Glib.Object; use Glib.Object;
with Gdk; use Gdk;
with Gdk.Device; use Gdk.Device;
with Gdk.Window; use Gdk.Window;
with Gdk.Cursor; use Gdk.Cursor;
with Gdk.Types.Keysyms; use Gdk.Types.Keysyms;
with Gdk.Device_Manager; use Gdk.Device_Manager;
with Gdk.Types; use Gdk.Types;
with Game; use Game;
with Utils; use Utils;
with Utils.UI; use Utils.UI;
with Messages; use Messages;
with Messages.UI; use Messages.UI;
with Crew; use Crew;
with Crew.UI; use Crew.UI;
with ShipModules; use ShipModules;
with Events; use Events;
with Events.UI; use Events.UI;
with Items; use Items;
with Config; use Config;
with Bases; use Bases;
with Bases.UI; use Bases.UI;
with Bases.LootUI; use Bases.LootUI;
with Bases.SchoolUI; use Bases.SchoolUI;
with Bases.ShipyardUI; use Bases.ShipyardUI;
with Bases.RecruitUI; use Bases.RecruitUI;
with Statistics; use Statistics;
with Statistics.UI; use Statistics.UI;
with MainMenu; use MainMenu;
with Maps.UI.Handlers; use Maps.UI.Handlers;
with Missions; use Missions;
with Missions.UI; use Missions.UI;
with BasesList; use BasesList;
with Combat.UI; use Combat.UI;
with Crafts.UI; use Crafts.UI;
with GameOptions; use GameOptions;
with Ships.Crew; use Ships.Crew;
with Ships.UI; use Ships.UI;
with Ships.Cargo.UI; use Ships.Cargo.UI;
with Trades.UI; use Trades.UI;
with Factions; use Factions;
with Stories; use Stories;
with Stories.UI; use Stories.UI;

package body Maps.UI is

   procedure DeathConfirm is
   begin
      if ShowConfirmDialog
          ("You are dead. Would you like to see your game statistics?",
           Gtk_Window(Get_Object(Builder, "skymapwindow"))) then
         Show_All(Gtk_Widget(Get_Object(Builder, "btnclose")));
         Hide(Gtk_Widget(Get_Object(Builder, "btnmenu")));
         PreviousGameState := Main_Menu;
         ShowStatsUI;
      else
         Hide(Gtk_Widget(Get_Object(Builder, "skymapwindow")));
         EndGame(False);
         ShowMainMenu;
      end if;
   end DeathConfirm;

   procedure UpdateHeader is
      HaveWorker, HaveGunner: Boolean := True;
      NeedCleaning, NeedRepairs, NeedWorker, HavePilot, HaveEngineer,
      HaveTrader, HaveUpgrader, HaveCleaner, HaveRepairman: Boolean := False;
      ItemAmount: Natural := 0;
      function GetItemAmount(ItemType: Unbounded_String) return Natural is
         Amount: Natural := 0;
      begin
         for Item of PlayerShip.Cargo loop
            if Items_List(Item.ProtoIndex).IType = ItemType then
               Amount := Amount + Item.Amount;
            end if;
         end loop;
         return Amount;
      end GetItemAmount;
      procedure UpdateLabel(LabelName, TextMarkup, TooltipText: String;
         ShowLabel: Boolean := False) is
         Label: constant Gtk_Widget :=
           Gtk_Widget(Get_Object(Builder, LabelName));
      begin
         Set_Markup(Gtk_Label(Label), TextMarkup);
         Set_Tooltip_Text(Label, TooltipText);
         if ShowLabel then
            Show_All(Label);
         end if;
      end UpdateLabel;
   begin
      if PlayerShip.Crew(1).Health = 0 then
         DeathConfirm;
         return;
      end if;
      Set_Text(Gtk_Label(Get_Object(Builder, "lbltime")), FormatedTime);
      declare
         LabelsNames: constant array(Positive range <>) of Unbounded_String :=
           (To_Unbounded_String("lblnofuel"),
            To_Unbounded_String("lblnodrink"),
            To_Unbounded_String("lblnofood"));
         CheckLabel: Gtk_Widget;
      begin
         for I in LabelsNames'Range loop
            CheckLabel :=
              Gtk_Widget(Get_Object(Builder, To_String(LabelsNames(I))));
            if Is_Visible(CheckLabel) then
               Hide(CheckLabel);
            end if;
         end loop;
      end;
      ItemAmount := GetItemAmount(FuelType);
      if ItemAmount = 0 then
         UpdateLabel
           ("lblnofuel", "[<span foreground=""red"">No Fuel</span>]",
            "You can't travel anymore.", True);
      elsif ItemAmount < GameSettings.LowFuel then
         UpdateLabel
           ("lblnofuel", "[<span foreground=""yellow"">Low Fuel</span>]",
            "Low level of fuel on ship. Only" & Natural'Image(ItemAmount) &
            " left.",
            True);
      end if;
      for Member of PlayerShip.Crew loop
         if Factions_List(Member.Faction).DrinksTypes.Length = 0 then
            ItemAmount := GameSettings.LowDrinks + 1;
         else
            ItemAmount := 0;
            for DrinkType of Factions_List(Member.Faction).DrinksTypes loop
               ItemAmount := ItemAmount + GetItemAmount(DrinkType);
            end loop;
            exit when ItemAmount < GameSettings.LowDrinks;
         end if;
      end loop;
      if ItemAmount = 0 then
         UpdateLabel
           ("lblnodrink", "[<span foreground=""red"">No Drinks</span>]",
            "You don't have any drinks in ship.", True);
      elsif ItemAmount < GameSettings.LowDrinks then
         UpdateLabel
           ("lblnodrink", "[<span foreground=""yellow"">Low Drinks</span>]",
            "Low level of drinks on ship. Only" & Natural'Image(ItemAmount) &
            " left.",
            True);
      end if;
      for Member of PlayerShip.Crew loop
         if Factions_List(Member.Faction).FoodTypes.Length = 0 then
            ItemAmount := GameSettings.LowFood + 1;
         else
            ItemAmount := 0;
            for FoodType of Factions_List(Member.Faction).FoodTypes loop
               ItemAmount := ItemAmount + GetItemAmount(FoodType);
            end loop;
            exit when ItemAmount < GameSettings.LowFood;
         end if;
      end loop;
      if ItemAmount = 0 then
         UpdateLabel
           ("lblnofood", "[<span foreground=""red"">No Food</span>]",
            "You don't have any food in ship.", True);
      elsif ItemAmount < GameSettings.LowFood then
         UpdateLabel
           ("lblnofood", "[<span foreground=""yellow"">Low Food</span>]",
            "Low level of food on ship. Only" & Natural'Image(ItemAmount) &
            " left.",
            True);
      end if;
      for Module of PlayerShip.Modules loop
         case Modules_List(Module.ProtoIndex).MType is
            when GUN | HARPOON_GUN =>
               if Module.Owner = 0 then
                  HaveGunner := False;
               elsif PlayerShip.Crew(Module.Owner).Order /= Gunner then
                  HaveGunner := False;
               end if;
            when ALCHEMY_LAB .. GREENHOUSE =>
               if Module.Data(1) > 0 then
                  NeedWorker := True;
                  if Module.Owner = 0 then
                     HaveWorker := False;
                  elsif PlayerShip.Crew(Module.Owner).Order /= Craft then
                     HaveWorker := False;
                  end if;
               end if;
            when CABIN =>
               if Module.Data(1) /= Module.Data(2) then
                  NeedCleaning := True;
               end if;
            when others =>
               null;
         end case;
         if Module.Durability /= Module.MaxDurability then
            NeedRepairs := True;
         end if;
      end loop;
      for Member of PlayerShip.Crew loop
         case Member.Order is
            when Pilot =>
               HavePilot := True;
            when Engineer =>
               HaveEngineer := True;
            when Talk =>
               HaveTrader := True;
            when Upgrading =>
               HaveUpgrader := True;
            when Clean =>
               HaveCleaner := True;
            when Repair =>
               HaveRepairman := True;
            when others =>
               null;
         end case;
      end loop;
      if HavePilot then
         UpdateLabel
           ("lblpilot", "[<span foreground=""#4E9A06"">P</span>]",
            "Pilot is in position.");
      else
         UpdateLabel
           ("lblpilot", "[<span foreground=""red"">P</span>]",
            "No pilot assigned. Ship can't move.");
      end if;
      if HaveEngineer then
         UpdateLabel
           ("lblengineer", "[<span foreground=""#4E9A06"">E</span>]",
            "Engineer is in position.");
      else
         UpdateLabel
           ("lblengineer", "[<span foreground=""red"">E</span>]",
            "No engineer assigned. Ship can't move.");
      end if;
      if HaveGunner then
         UpdateLabel
           ("lblgunners", "[<span foreground=""#4E9A06"">G</span>]",
            "All guns are manned.");
      else
         UpdateLabel
           ("lblgunners", "[<span foreground=""red"">G</span>]",
            "One or more guns don't have a gunner.");
      end if;
      if NeedRepairs then
         if HaveRepairman then
            UpdateLabel
              ("lblrepairs", "[<span foreground=""#4E9A06"">R</span>]",
               "The ship is being repaired.");
         else
            UpdateLabel
              ("lblrepairs", "[<span foreground=""red"">R</span>]",
               "The ship needs repairs but no one is working them.");
         end if;
      else
         UpdateLabel("lblrepairs", "[R]", "The ship doesn't require repairs.");
      end if;
      if NeedWorker then
         if HaveWorker then
            UpdateLabel
              ("lblcrafting", "[<span foreground=""#4E9A06"">M</span>]",
               "All crafting orders are being executed.");
         else
            UpdateLabel
              ("lblcrafting", "[<span foreground=""red"">M</span>]",
               "You need to assign crew members to begin manufacturing.");
         end if;
      else
         UpdateLabel("lblcrafting", "[M]", "No crafting orders were set.");
      end if;
      if PlayerShip.UpgradeModule > 0 then
         if HaveUpgrader then
            UpdateLabel
              ("lblupgrade", "[<span foreground=""#4E9A06"">U</span>]",
               "A ship module upgrade in progress.");
         else
            UpdateLabel
              ("lblupgrade", "[<span foreground=""red"">U</span>]",
               "A ship module upgrade is in progress but no one is working on it.");
         end if;
      else
         UpdateLabel("lblupgrade", "[U]", "No ship module upgrade was set.");
      end if;
      if HaveTrader then
         UpdateLabel
           ("lbltalk", "[<span foreground=""#4E9A06"">T</span>]",
            "Trader is in position.");
      elsif SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex > 0 then
         UpdateLabel
           ("lbltalk", "[<span foreground=""red"">T</span>]",
            "No trader assigned. You need one to talk/trade.");
      elsif SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).EventIndex > 0 then
         if Events_List(SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).EventIndex)
             .EType =
           FriendlyShip then
            UpdateLabel
              ("lbltalk", "[<span foreground=""red"">T</span>]",
               "No trader assigned. You need one to talk/trade.");
         else
            UpdateLabel("lbltalk", "[T]", "No trader needed.");
         end if;
      else
         UpdateLabel("lbltalk", "[T]", "No trader needed.");
      end if;
      if NeedCleaning then
         if HaveCleaner then
            UpdateLabel
              ("lblclean", "[<span foreground=""#4E9A06"">C</span>]",
               "Ship is cleaned.");
         else
            UpdateLabel
              ("lblclean", "[<span foreground=""red"">C</span>]",
               "Ship is dirty but no one is cleaning it.");
         end if;
      else
         UpdateLabel("lblclean", "[C]", "Ship needs no cleaning.");
      end if;
   end UpdateHeader;

   procedure UpdateMoveButtons is
      MoveButtonsNames: constant array
        (Positive range <>) of Unbounded_String :=
        (To_Unbounded_String("btnupleft"), To_Unbounded_String("btnup"),
         To_Unbounded_String("btnupright"), To_Unbounded_String("btnleft"),
         To_Unbounded_String("btnright"), To_Unbounded_String("btnbottomleft"),
         To_Unbounded_String("btnbottom"),
         To_Unbounded_String("btnbottomright"));
      MoveButtonsTooltips: constant array
        (MoveButtonsNames'Range) of Unbounded_String :=
        (To_Unbounded_String("Move ship north and west"),
         To_Unbounded_String("Move ship north"),
         To_Unbounded_String("Move ship north and east"),
         To_Unbounded_String("Move ship west"),
         To_Unbounded_String("Move ship east"),
         To_Unbounded_String("Move ship south and west"),
         To_Unbounded_String("Move ship south"),
         To_Unbounded_String("Move ship south and east"));
      MoveButton: Gtk_Widget;
   begin
      if PlayerShip.Speed = DOCKED then
         Hide(Gtk_Widget(Get_Object(Builder, "cmbspeed")));
         Hide(Gtk_Widget(Get_Object(Builder, "btnmoveto")));
         Set_Label(Gtk_Label(Get_Object(Builder, "lblmovewait")), "Wait");
         Set_Tooltip_Text
           (Gtk_Widget(Get_Object(Builder, "lblmovewait")), "Wait 1 minute.");
         for I in MoveButtonsNames'Range loop
            MoveButton :=
              Gtk_Widget(Get_Object(Builder, To_String(MoveButtonsNames(I))));
            Set_Sensitive(MoveButton, False);
            Set_Tooltip_Text
              (MoveButton,
               "You must give order 'Undock' from Ship Orders first to move ship.");
         end loop;
      else
         Set_Active
           (Gtk_Combo_Box(Get_Object(Builder, "cmbspeed")),
            Gint(ShipSpeed'Pos(PlayerShip.Speed) - 1));
         Show_All(Gtk_Widget(Get_Object(Builder, "cmbspeed")));
         if PlayerShip.DestinationX > 0 and PlayerShip.DestinationY > 0 then
            Show_All(Gtk_Widget(Get_Object(Builder, "btnmoveto")));
            Set_Label(Gtk_Label(Get_Object(Builder, "lblmovewait")), "Move");
            Set_Tooltip_Text
              (Gtk_Widget(Get_Object(Builder, "lblmovewait")),
               "Move ship one map field toward destination.");
         else
            Hide(Gtk_Widget(Get_Object(Builder, "btnmoveto")));
            Set_Label(Gtk_Label(Get_Object(Builder, "lblmovewait")), "Wait");
            Set_Tooltip_Text
              (Gtk_Widget(Get_Object(Builder, "lblmovewait")),
               "Wait 1 minute.");
         end if;
         for I in MoveButtonsNames'Range loop
            MoveButton :=
              Gtk_Widget(Get_Object(Builder, To_String(MoveButtonsNames(I))));
            Set_Sensitive(MoveButton, True);
            Set_Tooltip_Text(MoveButton, To_String(MoveButtonsTooltips(I)));
         end loop;
      end if;
   end UpdateMoveButtons;

   procedure DrawMap is
      Iter: Gtk_Text_Iter;
      MapBuffer: constant Gtk_Text_Buffer :=
        Gtk_Text_Buffer(Get_Object(Builder, "txtmap"));
      EndY, EndX, StoryX, StoryY: Integer := 0;
      Tags: constant Gtk_Text_Tag_Table := Get_Tag_Table(MapBuffer);
      WhiteColor: constant Gtk_Text_Tag := Lookup(Tags, "white");
      GrayColor: constant Gtk_Text_Tag := Lookup(Tags, "gray");
      RedColor: constant Gtk_Text_Tag := Lookup(Tags, "red");
      GreenColor: constant Gtk_Text_Tag := Lookup(Tags, "green");
      YellowColor: constant Gtk_Text_Tag := Lookup(Tags, "yellow");
      CyanColor: constant Gtk_Text_Tag := Lookup(Tags, "cyan");
      LimeColor: constant Gtk_Text_Tag := Lookup(Tags, "lime");
      RedGrayColor: constant Gtk_Text_Tag := Lookup(Tags, "redgray");
      GreenGrayColor: constant Gtk_Text_Tag := Lookup(Tags, "greengray");
      YellowGrayColor: constant Gtk_Text_Tag := Lookup(Tags, "yellowgray");
      CyanGrayColor: constant Gtk_Text_Tag := Lookup(Tags, "cyangray");
      LimeGrayColor: constant Gtk_Text_Tag := Lookup(Tags, "limegray");
      Red2Color: constant Gtk_Text_Tag := Lookup(Tags, "red2");
      Red3Color: constant Gtk_Text_Tag := Lookup(Tags, "red3");
      Red2GrayColor: constant Gtk_Text_Tag := Lookup(Tags, "red2gray");
      Red3GrayColor: constant Gtk_Text_Tag := Lookup(Tags, "red3gray");
      Green2Color: constant Gtk_Text_Tag := Lookup(Tags, "green2");
      Green2GrayColor: constant Gtk_Text_Tag := Lookup(Tags, "green2gray");
      MapChar: Character;
      MapColor: Gtk_Text_Tag;
      TextWindow: constant Gdk_Window :=
        Get_Window
          (Gtk_Text_View(Get_Object(Builder, "mapview")), Text_Window_Text);
   begin
      StartY := CenterY - (MapHeight / 2);
      StartX := CenterX - (MapWidth / 2);
      EndY := CenterY + (MapHeight / 2);
      EndX := CenterX + (MapWidth / 2);
      if StartY < 1 then
         StartY := 1;
         EndY := MapHeight;
      end if;
      if StartX < 1 then
         StartX := 1;
         EndX := MapWidth;
      end if;
      if EndY > 1024 then
         EndY := 1024;
         StartY := 1024 - MapHeight;
      end if;
      if EndX > 1024 then
         EndX := 1024;
         StartX := 1024 - MapWidth;
      end if;
      if CurrentStory.Index > 0 then
         GetStoryLocation(StoryX, StoryY);
         if StoryX = PlayerShip.SkyX and StoryY = PlayerShip.SkyY then
            StoryX := 0;
            StoryY := 0;
         end if;
      end if;
      Get_Start_Iter(MapBuffer, Iter);
      for Y in StartY .. EndY loop
         for X in StartX .. EndX loop
            if X = PlayerShip.SkyX and Y = PlayerShip.SkyY then
               MapChar := '+';
               MapColor := WhiteColor;
            else
               MapChar := ' ';
               if SkyMap(X, Y).Visited then
                  MapColor := WhiteColor;
               else
                  MapColor := GrayColor;
               end if;
               if X = PlayerShip.DestinationX and
                 Y = PlayerShip.DestinationY then
                  MapChar := 'X';
               elsif X = StoryX and Y = StoryY then
                  MapChar := '+';
                  MapColor := GreenColor;
               elsif SkyMap(X, Y).MissionIndex > 0 then
                  MapChar := '!';
                  if SkyMap(X, Y).Visited then
                     case AcceptedMissions(SkyMap(X, Y).MissionIndex).MType is
                        when Deliver =>
                           MapColor := YellowColor;
                        when Destroy =>
                           MapColor := RedColor;
                        when Patrol =>
                           MapColor := LimeColor;
                        when Explore =>
                           MapColor := GreenColor;
                        when Passenger =>
                           MapColor := CyanColor;
                     end case;
                  else
                     case AcceptedMissions(SkyMap(X, Y).MissionIndex).MType is
                        when Deliver =>
                           MapColor := YellowGrayColor;
                        when Destroy =>
                           MapColor := RedGrayColor;
                        when Patrol =>
                           MapColor := LimeGrayColor;
                        when Explore =>
                           MapColor := GreenGrayColor;
                        when Passenger =>
                           MapColor := CyanGrayColor;
                     end case;
                  end if;
               elsif SkyMap(X, Y).EventIndex > 0 then
                  MapChar := '?';
                  if SkyMap(X, Y).Visited then
                     case Events_List(SkyMap(X, Y).EventIndex).EType is
                        when EnemyShip =>
                           MapColor := RedColor;
                        when AttackOnBase =>
                           MapColor := Red2Color;
                        when EnemyPatrol =>
                           MapColor := Red3Color;
                        when Disease =>
                           MapColor := YellowColor;
                        when FullDocks =>
                           MapColor := CyanColor;
                        when DoublePrice =>
                           MapColor := LimeColor;
                        when Trader =>
                           MapColor := GreenColor;
                        when FriendlyShip =>
                           MapColor := Green2Color;
                        when others =>
                           null;
                     end case;
                  else
                     case Events_List(SkyMap(X, Y).EventIndex).EType is
                        when EnemyShip =>
                           MapColor := RedGrayColor;
                        when AttackOnBase =>
                           MapColor := Red2GrayColor;
                        when EnemyPatrol =>
                           MapColor := Red3GrayColor;
                        when Disease =>
                           MapColor := YellowGrayColor;
                        when FullDocks =>
                           MapColor := CyanGrayColor;
                        when DoublePrice =>
                           MapColor := LimeGrayColor;
                        when Trader =>
                           MapColor := GreenGrayColor;
                        when FriendlyShip =>
                           MapColor := Green2GrayColor;
                        when others =>
                           null;
                     end case;
                  end if;
               elsif SkyMap(X, Y).BaseIndex > 0 then
                  if SkyBases(SkyMap(X, Y).BaseIndex).Known then
                     MapChar := 'o';
                     if SkyBases(SkyMap(X, Y).BaseIndex).Visited.Year > 0 then
                        case SkyBases(SkyMap(X, Y).BaseIndex).BaseType is
                           when Industrial =>
                              MapColor := RedColor;
                           when Agricultural =>
                              MapColor := GreenColor;
                           when Refinery =>
                              MapColor := YellowColor;
                           when Shipyard =>
                              MapColor := CyanColor;
                           when Military =>
                              MapColor := LimeColor;
                           when others =>
                              null;
                        end case;
                     end if;
                  end if;
               end if;
            end if;
            Insert_With_Tags(MapBuffer, Iter, "" & MapChar, MapColor);
         end loop;
         if Y < EndY then
            Insert(MapBuffer, Iter, "" & LF);
         end if;
      end loop;
      if TextWindow /= null then
         Set_Cursor(TextWindow, Gdk_Cursor_New(Cross));
      end if;
   end DrawMap;

   procedure UpdateMessages is
      MessagesBuffer: constant Gtk_Text_Buffer :=
        Gtk_Text_Buffer(Get_Object(Builder, "txtmessages"));
      LoopStart: Integer := 0 - MessagesAmount;
      Message: Message_Data;
      Iter: Gtk_Text_Iter;
      TagNames: constant array(1 .. 5) of Unbounded_String :=
        (To_Unbounded_String("yellow"), To_Unbounded_String("green"),
         To_Unbounded_String("red"), To_Unbounded_String("blue"),
         To_Unbounded_String("cyan"));
      procedure ShowMessage is
      begin
         if Message.Color = 0 then
            Insert(MessagesBuffer, Iter, To_String(Message.Message));
         else
            Insert_With_Tags
              (MessagesBuffer, Iter, To_String(Message.Message),
               Lookup
                 (Get_Tag_Table(MessagesBuffer),
                  To_String(TagNames(Message.Color))));
         end if;
      end ShowMessage;
   begin
      Set_Text(MessagesBuffer, "");
      Get_Start_Iter(MessagesBuffer, Iter);
      if LoopStart = 0 then
         return;
      end if;
      if LoopStart < -10 then
         LoopStart := -10;
      end if;
      if GameSettings.MessagesOrder = OLDER_FIRST then
         for I in LoopStart .. -1 loop
            Message := GetMessage(I + 1);
            ShowMessage;
            if I < -1 then
               Insert(MessagesBuffer, Iter, "" & LF);
            end if;
         end loop;
         declare
            Mark: Gtk_Text_Mark;
         begin
            Mark := Create_Mark(MessagesBuffer, "end", Iter);
            Scroll_Mark_Onscreen
              (Gtk_Text_View(Get_Object(Builder, "messagesview")), Mark);
         end;
      else
         for I in reverse LoopStart .. -1 loop
            Message := GetMessage(I + 1);
            ShowMessage;
            if I > LoopStart then
               Insert(MessagesBuffer, Iter, "" & LF);
            end if;
         end loop;
      end if;
      if LastMessage = Null_Unbounded_String then
         Hide(Gtk_Widget(Get_Object(Builder, "infolastmessage")));
      else
         Set_Text
           (Gtk_Label(Get_Object(Builder, "lbllastmessage")),
            To_String(LastMessage));
         Show_All(Gtk_Widget(Get_Object(Builder, "infolastmessage")));
         Check_Resize(Gtk_Container(Get_Object(Builder, "skymapwindow")));
         LastMessage := Null_Unbounded_String;
      end if;
   end UpdateMessages;

   procedure HideButtons(Widget: not null access Gtk_Widget_Record'Class) is
   begin
      Set_No_Show_All(Widget, True);
      Hide(Widget);
   end HideButtons;

   procedure CheckButtons(Widget: not null access Gtk_Widget_Record'Class) is
   begin
      if Widget = Gtk_Widget(Get_Object(Builder, "btncloseorders")) then
         return;
      end if;
      if not Get_No_Show_All(Widget) and not ButtonsVisible then
         ButtonsVisible := True;
      end if;
   end CheckButtons;

   procedure GetCurrentCellCoords is
      Mask: Gdk_Modifier_Type;
      MouseX, MouseY: Gint;
      DeviceManager: constant Gdk_Device_Manager :=
        Get_Device_Manager
          (Get_Display(Gtk_Widget(Get_Object(Builder, "mapview"))));
      Mouse: constant Gdk_Device := Get_Client_Pointer(DeviceManager);
      Window: Gdk_Window;
   begin
      Get_Device_Position
        (Get_Window(Gtk_Widget(Get_Object(Builder, "mapview"))), Mouse, MouseX,
         MouseY, Mask, Window);
      if MouseX < 0 then
         MapX := StartX;
      else
         MapX := (Natural(MouseX) / MapCellWidth) + StartX;
      end if;
      if MouseY < 0 then
         MapY := StartY;
      else
         MapY := (Natural(MouseY) / MapCellHeight) + StartY;
      end if;
      if MapX > SkyMap'Last then
         MapX := SkyMap'Last;
      end if;
      if MapY > SkyMap'Last then
         MapY := SkyMap'Last;
      end if;
   end GetCurrentCellCoords;

   procedure UpdateMapInfo(ShowOrdersInfo: Boolean := False) is
      MapInfoText: Unbounded_String;
   begin
      if not ShowOrdersInfo then
         GetCurrentCellCoords;
      else
         MapX := PlayerShip.SkyX;
         MapY := PlayerShip.SkyY;
      end if;
      Append
        (MapInfoText,
         "X:" & Positive'Image(MapX) & " Y:" & Positive'Image(MapY));
      if PlayerShip.SkyX /= MapX or PlayerShip.SkyY /= MapY then
         TravelInfo(MapInfoText, CountDistance(MapX, MapY));
      end if;
      if SkyMap(MapX, MapY).BaseIndex > 0 then
         declare
            BaseIndex: constant Positive := SkyMap(MapX, MapY).BaseIndex;
         begin
            if SkyBases(BaseIndex).Known then
               Append(MapInfoText, LF);
               Append(MapInfoText, "Base info:");
               Append(MapInfoText, LF);
               Append
                 (MapInfoText,
                  To_Unbounded_String("Name: ") & SkyBases(BaseIndex).Name);
            end if;
            if SkyBases(BaseIndex).Visited.Year > 0 then
               Append(MapInfoText, LF);
               Append
                 (MapInfoText,
                  "Type: " &
                  To_Lower(Bases_Types'Image(SkyBases(BaseIndex).BaseType)));
               Append(MapInfoText, LF);
               if SkyBases(BaseIndex).Population > 0 and
                 SkyBases(BaseIndex).Population < 150 then
                  Append(MapInfoText, "Population: small");
               elsif SkyBases(BaseIndex).Population > 149 and
                 SkyBases(BaseIndex).Population < 300 then
                  Append(MapInfoText, "Population: medium");
               elsif SkyBases(BaseIndex).Population > 299 then
                  Append(MapInfoText, "Population: large");
               end if;
               Append
                 (MapInfoText,
                  LF & "Size: " &
                  To_Lower(Bases_Size'Image(SkyBases(BaseIndex).Size)));
               if SkyBases(BaseIndex).Population > 0 then
                  Append(MapInfoText, LF);
                  Append
                    (MapInfoText,
                     "Owner: " &
                     To_String(Factions_List(SkyBases(BaseIndex).Owner).Name));
               else
                  Append(MapInfoText, "Base is abandoned");
               end if;
               if SkyBases(BaseIndex).Population > 0 then
                  Append(MapInfoText, LF);
                  case SkyBases(BaseIndex).Reputation(1) is
                     when -100 .. -75 =>
                        Append(MapInfoText, "You are hated here");
                     when -74 .. -50 =>
                        Append(MapInfoText, "You are outlawed here");
                     when -49 .. -25 =>
                        Append(MapInfoText, "You are disliked here");
                     when -24 .. -1 =>
                        Append(MapInfoText, "They are unfriendly to you");
                     when 0 =>
                        Append(MapInfoText, "You are unknown here");
                     when 1 .. 25 =>
                        Append(MapInfoText, "You are know here as visitor");
                     when 26 .. 50 =>
                        Append(MapInfoText, "You are know here as trader");
                     when 51 .. 75 =>
                        Append(MapInfoText, "You are know here as friend");
                     when 76 .. 100 =>
                        Append(MapInfoText, "You are well known here");
                     when others =>
                        null;
                  end case;
               end if;
               if BaseIndex = PlayerShip.HomeBase then
                  Append(MapInfoText, LF);
                  Append(MapInfoText, "It is your home base");
               end if;
            end if;
         end;
      end if;
      if SkyMap(MapX, MapY).EventIndex > 0 then
         declare
            EventIndex: constant Positive := SkyMap(MapX, MapY).EventIndex;
         begin
            Append(MapInfoText, LF);
            if Events_List(EventIndex).EType /= BaseRecovery and
              SkyMap(MapX, MapY).BaseIndex > 0 then
               Append(MapInfoText, LF);
            end if;
            case Events_List(EventIndex).EType is
               when EnemyShip | Trader | FriendlyShip =>
                  Append
                    (MapInfoText,
                     ProtoShips_List(Events_List(EventIndex).Data).Name);
               when FullDocks =>
                  Append(MapInfoText, "Full docks in base");
               when AttackOnBase =>
                  Append(MapInfoText, "Base is under attack");
               when Disease =>
                  Append(MapInfoText, "Disease in base");
               when EnemyPatrol =>
                  Append(MapInfoText, "Enemy patrol");
               when DoublePrice =>
                  Append
                    (MapInfoText,
                     "Double price for " &
                     To_String(Items_List(Events_List(EventIndex).Data).Name));
               when None | BaseRecovery =>
                  null;
            end case;
         end;
      end if;
      if SkyMap(MapX, MapY).MissionIndex > 0 then
         declare
            MissionIndex: constant Positive := SkyMap(MapX, MapY).MissionIndex;
         begin
            Append(MapInfoText, LF);
            if SkyMap(MapX, MapY).BaseIndex > 0 or
              SkyMap(MapX, MapY).EventIndex > 0 then
               Append(MapInfoText, LF);
            end if;
            case AcceptedMissions(MissionIndex).MType is
               when Deliver =>
                  Append
                    (MapInfoText,
                     "Deliver " &
                     To_String
                       (Items_List(AcceptedMissions(MissionIndex).Target)
                          .Name));
               when Destroy =>
                  Append
                    (MapInfoText,
                     "Destroy " &
                     To_String
                       (ProtoShips_List(AcceptedMissions(MissionIndex).Target)
                          .Name));
               when Patrol =>
                  Append(MapInfoText, "Patrol area");
               when Explore =>
                  Append(MapInfoText, "Explore area");
               when Passenger =>
                  Append(MapInfoText, "Transport passenger");
            end case;
         end;
      end if;
      if CurrentStory.Index > 0 then
         declare
            StoryX, StoryY: Integer := 0;
            FinishCondition: StepConditionType;
         begin
            GetStoryLocation(StoryX, StoryY);
            if StoryX = PlayerShip.SkyX and StoryY = PlayerShip.SkyY then
               StoryX := 0;
               StoryY := 0;
            end if;
            if MapX = StoryX and MapY = StoryY then
               if CurrentStory.CurrentStep = 0 then
                  FinishCondition :=
                    Stories_List(CurrentStory.Index).StartingStep
                      .FinishCondition;
               elsif CurrentStory.CurrentStep > 0 then
                  FinishCondition :=
                    Stories_List(CurrentStory.Index).Steps
                      (CurrentStory.CurrentStep)
                      .FinishCondition;
               else
                  FinishCondition :=
                    Stories_List(CurrentStory.Index).FinalStep.FinishCondition;
               end if;
               if FinishCondition = ASKINBASE or
                 FinishCondition = DESTROYSHIP or
                 FinishCondition = EXPLORE then
                  Append(MapInfoText, LF & "Story leads you here");
               end if;
            end if;
         end;
      end if;
      if MapX = PlayerShip.SkyX and MapY = PlayerShip.SkyY then
         Append(MapInfoText, LF & "You are here");
      end if;
      Set_Label
        (Gtk_Label(Get_Object(Builder, "lblmaptooltip")),
         To_String(MapInfoText));
   end UpdateMapInfo;

   procedure CreateSkyMap is
      Error: aliased GError;
      Accelerators: Gtk_Accel_Group;
   begin
      if Builder /= null then
         ShowSkyMap;
         return;
      end if;
      Gtk_New(Builder);
      if Add_From_File
          (Builder,
           To_String(DataDirectory) & "ui" & Dir_Separator & "game.glade",
           Error'Access) =
        Guint(0) then
         Put_Line("Error : " & Get_Message(Error));
         return;
      end if;
      CreateMessagesUI(Builder);
      CreateEventsUI(Builder);
      CreateMissionsUI(Builder);
      CreateBasesListUI(Builder);
      CreateStatsUI(Builder);
      CreateBasesUI(Builder);
      CreateBasesLootUI(Builder);
      CreateBasesSchoolUI(Builder);
      CreateBasesShipyardUI(Builder);
      CreateRecruitUI(Builder);
      CreateCombatUI(Builder);
      CreateCraftsUI(Builder);
      CreateGameOptions(Builder);
      CreateCrewUI(Builder);
      CreateShipUI(Builder);
      CreateCargoUI(Builder);
      CreateTradeUI(Builder);
      CreateStoriesUI(Builder);
      Add_Overlay
        (Gtk_Overlay(Get_Object(Builder, "mapoverlay")),
         Gtk_Widget(Get_Object(Builder, "lblmaptooltip")));
      Register_Handler(Builder, "Quit_Game", QuitGame'Access);
      Register_Handler(Builder, "Quit_Game_Menu", QuitGameMenu'Access);
      Register_Handler(Builder, "Hide_Last_Message", HideLastMessage'Access);
      Register_Handler(Builder, "Get_New_Size", GetMapSize'Access);
      Register_Handler(Builder, "Hide_Map_Info", HideMapInfoWindow'Access);
      Register_Handler(Builder, "Show_Window", ShowWindow'Access);
      Register_Handler(Builder, "Set_Destination", SetDestination'Access);
      Register_Handler(Builder, "Hide_Window", HideWindow'Access);
      Register_Handler(Builder, "Move_Map", MoveMap'Access);
      Register_Handler(Builder, "Dock_Ship", BtnDockClicked'Access);
      Register_Handler(Builder, "Change_Speed", ChangeSpeed'Access);
      Register_Handler(Builder, "Move_Ship", MoveShip'Access);
      Register_Handler(Builder, "Show_Orders", ShowOrders'Access);
      Register_Handler(Builder, "Wait_Order", WaitOrder'Access);
      Register_Handler(Builder, "Attack_Order", AttackOrder'Access);
      Register_Handler(Builder, "Show_Help", ShowHelp'Access);
      Register_Handler(Builder, "Show_Info", ShowInfo'Access);
      Register_Handler(Builder, "Resign_From_Game", ResignFromGame'Access);
      Register_Handler(Builder, "Show_Missions", ShowMissions'Access);
      Register_Handler(Builder, "Start_Mission", StartMission'Access);
      Register_Handler(Builder, "Complete_Mission", CompleteMission'Access);
      Register_Handler(Builder, "Execute_Order", ExecuteOrder'Access);
      Register_Handler(Builder, "Show_Wait_Orders", ShowWaitOrders'Access);
      Register_Handler(Builder, "Update_Tooltip", UpdateTooltip'Access);
      Register_Handler(Builder, "Deliver_Medicines", DeliverMedicines'Access);
      Register_Handler
        (Builder, "Disable_Menu_Shortcuts", DisableMenuShortcuts'Access);
      Register_Handler
        (Builder, "Enable_Menu_Shortcuts", EnableMenuShortcuts'Access);
      Register_Handler
        (Builder, "Disable_Menu_Shortcuts_Proc",
         DisableMenuShortcutsProc'Access);
      Register_Handler
        (Builder, "Enable_Menu_Shortcuts_Proc",
         EnableMenuShortcutsProc'Access);
      Register_Handler
        (Builder, "Toggle_Close_Button", ToggleCloseButton'Access);
      Register_Handler
        (Builder, "Toggle_Close_Button_Proc", ToggleCloseButtonProc'Access);
      Do_Connect(Builder);
      Add_Entry("<skymapwindow>/btnupleft", GDK_KP_7, 0);
      Add_Entry("<skymapwindow>/btnup", GDK_KP_8, 0);
      Add_Entry("<skymapwindow>/btnupright", GDK_KP_9, 0);
      Add_Entry("<skymapwindow>/btnleft", GDK_KP_4, 0);
      Add_Entry("<skymapwindow>/btnmovewait", GDK_KP_5, 0);
      Add_Entry("<skymapwindow>/btnright", GDK_KP_6, 0);
      Add_Entry("<skymapwindow>/btnbottomleft", GDK_KP_1, 0);
      Add_Entry("<skymapwindow>/btnbottom", GDK_KP_2, 0);
      Add_Entry("<skymapwindow>/btnbottomright", GDK_KP_3, 0);
      Add_Entry("<skymapwindow>/btnmoveto", GDK_KP_Divide, 0);
      Add_Entry("<skymapwindow>/Menu/ShipInfo", GDK_S, 0);
      Add_Entry("<skymapwindow>/Menu/ShipCargoInfo", GDK_A, 0);
      Add_Entry("<skymapwindow>/Menu/CrewInfo", GDK_C, 0);
      Add_Entry("<skymapwindow>/Menu/ShipOrders", GDK_O, 0);
      Add_Entry("<skymapwindow>/Menu/CraftInfo", GDK_R, 0);
      Add_Entry("<skymapwindow>/Menu/MessagesInfo", GDK_M, 0);
      Add_Entry("<skymapwindow>/Menu/BasesInfo", GDK_B, 0);
      Add_Entry("<skymapwindow>/Menu/EventsInfo", GDK_N, 0);
      Add_Entry("<skymapwindow>/Menu/MissionsInfo", GDK_I, 0);
      Add_Entry("<skymapwindow>/Menu/MoveMap", GDK_V, 0);
      Add_Entry("<skymapwindow>/Menu/GameStats", GDK_G, 0);
      Add_Entry("<skymapwindow>/Menu/Help", GDK_F1, 0);
      Add_Entry("<skymapwindow>/Menu/GameOptions", GDK_P, 0);
      Add_Entry("<skymapwindow>/Menu/QuitGame", GDK_Q, 0);
      Add_Entry("<skymapwindow>/Menu/ResignFromGame", GDK_X, 0);
      Add_Entry("<skymapwindow>/Menu", GDK_E, 0);
      Add_Entry("<skymapwindow>/Menu/WaitOrders", GDK_W, 0);
      Add_Entry("<movemapwindow>/btncenter", GDK_Return, 1);
      Add_Entry("<skymapwindow>/btnmapleft", GDK_Left, 1);
      Add_Entry("<skymapwindow>/btnmapright", GDK_Right, 1);
      Add_Entry("<skymapwindow>/btnmapup", GDK_Up, 1);
      Add_Entry("<skymapwindow>/btnmapdown", GDK_Down, 1);
      Add_Entry("<skymapwindow>/cursorupleft", GDK_KP_Home, 1);
      Add_Entry("<skymapwindow>/cursorup", GDK_KP_Up, 1);
      Add_Entry("<skymapwindow>/cursorupright", GDK_KP_Page_Up, 1);
      Add_Entry("<skymapwindow>/cursorleft", GDK_KP_Left, 1);
      Add_Entry("<skymapwindow>/cursorright", GDK_KP_Right, 1);
      Add_Entry("<skymapwindow>/cursordownleft", GDK_KP_End, 1);
      Add_Entry("<skymapwindow>/cursordown", GDK_KP_Down, 1);
      Add_Entry("<skymapwindow>/cursordownright", GDK_KP_Page_Down, 1);
      Add_Entry("<skymapwindow>/mouseclick", GDK_space, 1);
      Add_Entry("<skymapwindow>/Menu/Stories", GDK_T, 0);
      Add_Entry("<skymapwindow>/zoomin", GDK_KP_Subtract, 0);
      Add_Entry("<skymapwindow>/zoomout", GDK_KP_Add, 0);
      Add_Entry("<movemapwindow>/btncenterhomebase", GDK_H, 1);
      if Exists(To_String(SaveDirectory) & "keys.cfg") then
         Load(To_String(SaveDirectory) & "keys.cfg");
      end if;
      Accelerators := Gtk_Accel_Group(Get_Object(Builder, "movementaccels"));
      declare
         type Accel_Record is record
            WidgetName: Unbounded_String;
            AccelName: Unbounded_String;
         end record;
         AccelsArray: constant array(Positive range <>) of Accel_Record :=
           (1 =>
              (To_Unbounded_String("btnupleft"),
               To_Unbounded_String("<skymapwindow>/btnupleft")),
            2 =>
              (To_Unbounded_String("btnup"),
               To_Unbounded_String("<skymapwindow>/btnup")),
            3 =>
              (To_Unbounded_String("btnupright"),
               To_Unbounded_String("<skymapwindow>/btnupright")),
            4 =>
              (To_Unbounded_String("btnleft"),
               To_Unbounded_String("<skymapwindow>/btnleft")),
            5 =>
              (To_Unbounded_String("btnmovewait"),
               To_Unbounded_String("<skymapwindow>/btnmovewait")),
            6 =>
              (To_Unbounded_String("btnright"),
               To_Unbounded_String("<skymapwindow>/btnright")),
            7 =>
              (To_Unbounded_String("btnbottomleft"),
               To_Unbounded_String("<skymapwindow>/btnbottomleft")),
            8 =>
              (To_Unbounded_String("btnbottom"),
               To_Unbounded_String("<skymapwindow>/btnbottom")),
            9 =>
              (To_Unbounded_String("btnbottomright"),
               To_Unbounded_String("<skymapwindow>/btnbottomright")),
            10 =>
              (To_Unbounded_String("btnmoveto"),
               To_Unbounded_String("<skymapwindow>/btnmoveto")),
            11 =>
              (To_Unbounded_String("btnmenu"),
               To_Unbounded_String("<skymapwindow>/Menu")),
            12 =>
              (To_Unbounded_String("menuship"),
               To_Unbounded_String("<skymapwindow>/Menu/ShipInfo")),
            13 =>
              (To_Unbounded_String("menucargo"),
               To_Unbounded_String("<skymapwindow>/Menu/ShipCargoInfo")),
            14 =>
              (To_Unbounded_String("menucrew"),
               To_Unbounded_String("<skymapwindow>/Menu/CrewInfo")),
            15 =>
              (To_Unbounded_String("menuorders"),
               To_Unbounded_String("<skymapwindow>/Menu/ShipOrders")),
            16 =>
              (To_Unbounded_String("menucrafting"),
               To_Unbounded_String("<skymapwindow>/Menu/CraftInfo")),
            17 =>
              (To_Unbounded_String("menumessages"),
               To_Unbounded_String("<skymapwindow>/Menu/MessagesInfo")),
            18 =>
              (To_Unbounded_String("menubaseslist"),
               To_Unbounded_String("<skymapwindow>/Menu/BasesInfo")),
            19 =>
              (To_Unbounded_String("menuevents"),
               To_Unbounded_String("<skymapwindow>/Menu/EventsInfo")),
            20 =>
              (To_Unbounded_String("menumissions"),
               To_Unbounded_String("<skymapwindow>/Menu/MissionsInfo")),
            21 =>
              (To_Unbounded_String("menumovemap"),
               To_Unbounded_String("<skymapwindow>/Menu/MoveMap")),
            22 =>
              (To_Unbounded_String("menustats"),
               To_Unbounded_String("<skymapwindow>/Menu/GameStats")),
            23 =>
              (To_Unbounded_String("menuhelp"),
               To_Unbounded_String("<skymapwindow>/Menu/Help")),
            24 =>
              (To_Unbounded_String("menuoptions"),
               To_Unbounded_String("<skymapwindow>/Menu/GameOptions")),
            25 =>
              (To_Unbounded_String("menuquit"),
               To_Unbounded_String("<skymapwindow>/Menu/QuitGame")),
            26 =>
              (To_Unbounded_String("menuresign"),
               To_Unbounded_String("<skymapwindow>/Menu/ResignFromGame")),
            27 =>
              (To_Unbounded_String("menuwait"),
               To_Unbounded_String("<skymapwindow>/Menu/WaitOrders")),
            28 =>
              (To_Unbounded_String("menustory"),
               To_Unbounded_String("<skymapwindow>/Menu/Stories")),
            29 =>
              (To_Unbounded_String("btncenter"),
               To_Unbounded_String("<movemapwindow>/btncenter")),
            30 =>
              (To_Unbounded_String("btncenterhomebase"),
               To_Unbounded_String("<movemapwindow>/btncenterhomebase")));
      begin
         for I in AccelsArray'Range loop
            Set_Accel_Path
              (Gtk_Widget
                 (Get_Object(Builder, To_String(AccelsArray(I).WidgetName))),
               To_String(AccelsArray(I).AccelName), Accelerators);
         end loop;
      end;
      Accelerators := Gtk_Accel_Group(Get_Object(Builder, "movemapaccels"));
      Set_Accel_Path
        (Gtk_Widget(Get_Object(Builder, "btncenter")),
         "<movemapwindow>/btncenter", Accelerators);
      Set_Accel_Path
        (Gtk_Widget(Get_Object(Builder, "btncenterhomebase")),
         "<movemapwindow>/btncenterhomebase", Accelerators);
      declare
         StackNames: constant array(Positive range <>) of Unbounded_String :=
           (To_Unbounded_String("gamestack"),
            To_Unbounded_String("shipyardstack"),
            To_Unbounded_String("optionsstack"),
            To_Unbounded_String("combatstack"));
      begin
         for I in StackNames'Range loop
            Set_Transition_Type
              (Gtk_Stack(Get_Object(Builder, To_String(StackNames(I)))),
               Gtk_Stack_Transition_Type'Val(GameSettings.AnimationType));
         end loop;
      end;
      On_Key_Press_Event
        (Gtk_Widget(Get_Object(Builder, "spinx")), SelectElement'Access,
         Get_Object(Builder, "spiny"));
      On_Key_Press_Event
        (Gtk_Widget(Get_Object(Builder, "spiny")), SelectElement'Access,
         Get_Object(Builder, "btnmovemapok"));
      On_Key_Press_Event
        (Gtk_Widget(Get_Object(Builder, "spinminutes")), SelectElement'Access,
         Get_Object(Builder, "btnwaitx"));
      On_Scroll_Event
        (Gtk_Widget(Get_Object(Builder, "mapview")), ZoomMap'Access);
      declare
         MainWindow: constant Gtk_Widget :=
           Gtk_Widget(Get_Object(Builder, "skymapwindow"));
      begin
         On_Key_Release_Event(MainWindow, MapKeyReleased'Access);
         On_Key_Press_Event(MainWindow, MapKeyPressed'Access);
         Set_Default_Size
           (Gtk_Window(MainWindow), Gint(GameSettings.WindowWidth),
            Gint(GameSettings.WindowHeight));
      end;
      ShowSkyMap;
   end CreateSkyMap;

   procedure ShowSkyMap(X: Integer := PlayerShip.SkyX;
      Y: Integer := PlayerShip.SkyY) is
   begin
      CenterX := X;
      CenterY := Y;
      UpdateMessages;
      Set_Text(Gtk_Text_Buffer(Get_Object(Builder, "txtmap")), "X" & LF & "X");
      Show_All(Gtk_Widget(Get_Object(Builder, "skymapwindow")));
      UpdateHeader;
      UpdateMoveButtons;
      Hide(Gtk_Widget(Get_Object(Builder, "infolastmessage")));
      Hide(Gtk_Widget(Get_Object(Builder, "btnclose")));
      Set_Visible_Child_Name
        (Gtk_Stack(Get_Object(Builder, "gamestack")), "skymap");
      Show_All(Gtk_Widget(Get_Object(Builder, "btnmenu")));
      UpdateMapInfo;
      if CurrentStory.Index > 0 and CurrentStory.ShowText then
         if CurrentStory.CurrentStep > -2 then
            ShowDialog
              (To_String(GetCurrentStoryText),
               Gtk_Window(Get_Object(Builder, "skymapwindow")));
         else
            FinishStory;
            if PlayerShip.Crew(1).Health = 0 then
               DeathConfirm;
            end if;
         end if;
         CurrentStory.ShowText := False;
      end if;
      if not GameSettings.ShowMapButtons then
         Hide(Gtk_Widget(Get_Object(Builder, "btnmapleft")));
         Hide(Gtk_Widget(Get_Object(Builder, "btnmapright")));
         Hide(Gtk_Widget(Get_Object(Builder, "btnmapup")));
         Hide(Gtk_Widget(Get_Object(Builder, "btnmapdown")));
      end if;
   end ShowSkyMap;

   procedure FinishStory is
      Message: constant String :=
        To_String(Stories_List(CurrentStory.Index).EndText) &
        " Are you want to finish game?";
   begin
      GameStats.Points := GameStats.Points + (10000 * CurrentStory.MaxSteps);
      ClearCurrentStory;
      if ShowConfirmDialog
          (Message, Gtk_Window(Get_Object(Builder, "skymapwindow"))) then
         Death
           (1, To_Unbounded_String("retired after finished the game"),
            PlayerShip);
      end if;
   end FinishStory;

end Maps.UI;
