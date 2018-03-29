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

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Exceptions; use Ada.Exceptions;
with Gtk.Widget; use Gtk.Widget;
with Gtk.Tree_Model; use Gtk.Tree_Model;
with Gtk.List_Store; use Gtk.List_Store;
with Gtk.Label; use Gtk.Label;
with Gtk.Tree_View; use Gtk.Tree_View;
with Gtk.Tree_View_Column; use Gtk.Tree_View_Column;
with Gtk.Tree_Selection; use Gtk.Tree_Selection;
with Gtk.Window; use Gtk.Window;
with Gtk.Button; use Gtk.Button;
with Gtk.Stack; use Gtk.Stack;
with Glib; use Glib;
with Glib.Object; use Glib.Object;
with Maps; use Maps;
with Maps.UI; use Maps.UI;
with Game; use Game;
with Ships; use Ships;
with Bases; use Bases;
with Messages; use Messages;
with Items; use Items;
with ShipModules; use ShipModules;
with Utils.UI; use Utils.UI;

package body Missions.UI is

   Builder: Gtkada_Builder;
   MissionIndex: Positive;
   Cleaning: Boolean;

   procedure ShowMissionInfo(User_Data: access GObject_Record'Class) is
      MissionsIter: Gtk_Tree_Iter;
      MissionsModel: Gtk_Tree_Model;
      MissionInfo: Unbounded_String;
      Mission: Mission_Data;
      MinutesDiff: Natural;
      MissionTime: Date_Record :=
        (Year => 0, Month => 0, Day => 0, Hour => 0, Minutes => 0);
      HaveCabin, CabinTaken: Boolean := False;
      CanAccept: Boolean := True;
      MissionsLimit: Natural;
   begin
      if Cleaning then
         return;
      end if;
      Get_Selected
        (Gtk.Tree_View.Get_Selection(Gtk_Tree_View(User_Data)),
         MissionsModel,
         MissionsIter);
      if MissionsIter = Null_Iter then
         return;
      end if;
      MissionIndex := Positive(Get_Int(MissionsModel, MissionsIter, 1));
      if User_Data = Get_Object(Builder, "treemissions") then
         if MissionIndex >
           Positive
             (SkyBases(SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex)
                .Missions.Length) then
            return;
         end if;
         Mission :=
           SkyBases(SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex)
             .Missions
             (MissionIndex);
      else
         if MissionIndex > Positive(PlayerShip.Missions.Length) then
            return;
         end if;
         Mission := PlayerShip.Missions(MissionIndex);
      end if;
      case Mission.MType is
         when Deliver =>
            MissionInfo :=
              To_Unbounded_String("Item: ") & Items_List(Mission.Target).Name;
            Append
              (MissionInfo,
               ASCII.LF &
               "Weight:" &
               Positive'Image(Items_List(Mission.Target).Weight) &
               " kg");
            Append
              (MissionInfo,
               ASCII.LF &
               "To base: " &
               To_String
                 (SkyBases(SkyMap(Mission.TargetX, Mission.TargetY).BaseIndex)
                    .Name));
         when Patrol =>
            MissionInfo := To_Unbounded_String("Patrol selected area");
         when Destroy =>
            MissionInfo :=
              To_Unbounded_String
                ("Target: " & To_String(ProtoShips_List(Mission.Target).Name));
         when Explore =>
            MissionInfo := To_Unbounded_String("Explore selected area");
         when Passenger =>
            CanAccept := False;
            for Module of PlayerShip.Modules loop
               if Module.ProtoIndex = Mission.Target then
                  if Module.Owner = 0 then
                     HaveCabin := True;
                     CanAccept := True;
                     exit;
                  else
                     CabinTaken := True;
                  end if;
               end if;
            end loop;
            if User_Data = Get_Object(Builder, "treemissions1") then
               HaveCabin := True;
            end if;
            MissionInfo := To_Unbounded_String("Needed cabin: ");
            if HaveCabin then
               Append(MissionInfo, Modules_List(Mission.Target).Name);
            elsif CabinTaken then
               Append
                 (MissionInfo,
                  To_Unbounded_String("<span foreground=""yellow"">") &
                  Modules_List(Mission.Target).Name &
                  To_Unbounded_String("</span>"));
            else
               Append
                 (MissionInfo,
                  To_Unbounded_String("<span foreground=""red"">") &
                  Modules_List(Mission.Target).Name &
                  To_Unbounded_String("</span>"));
            end if;
            Append
              (MissionInfo,
               ASCII.LF &
               "To base: " &
               To_String
                 (SkyBases(SkyMap(Mission.TargetX, Mission.TargetY).BaseIndex)
                    .Name));
      end case;
      MinutesDiff := Mission.Time;
      while MinutesDiff > 0 loop
         if MinutesDiff >= 518400 then
            MissionTime.Year := MissionTime.Year + 1;
            MinutesDiff := MinutesDiff - 518400;
         elsif MinutesDiff >= 43200 then
            MissionTime.Month := MissionTime.Month + 1;
            MinutesDiff := MinutesDiff - 43200;
         elsif MinutesDiff >= 1440 then
            MissionTime.Day := MissionTime.Day + 1;
            MinutesDiff := MinutesDiff - 1440;
         elsif MinutesDiff >= 60 then
            MissionTime.Hour := MissionTime.Hour + 1;
            MinutesDiff := MinutesDiff - 60;
         else
            MissionTime.Minutes := MinutesDiff;
            MinutesDiff := 0;
         end if;
      end loop;
      Append(MissionInfo, ASCII.LF & "Time limit:");
      if MissionTime.Year > 0 then
         Append(MissionInfo, Positive'Image(MissionTime.Year) & "y");
      end if;
      if MissionTime.Month > 0 then
         Append(MissionInfo, Positive'Image(MissionTime.Month) & "m");
      end if;
      if MissionTime.Day > 0 then
         Append(MissionInfo, Positive'Image(MissionTime.Day) & "d");
      end if;
      if MissionTime.Hour > 0 then
         Append(MissionInfo, Positive'Image(MissionTime.Hour) & "h");
      end if;
      if MissionTime.Minutes > 0 then
         Append(MissionInfo, Positive'Image(MissionTime.Minutes) & "mins");
      end if;
      Append
        (MissionInfo,
         ASCII.LF &
         "Reward:" &
         Positive'Image(Mission.Reward) &
         " " &
         To_String(MoneyName));
      if User_Data = Get_Object(Builder, "treemissions") then
         Set_Markup
           (Gtk_Label(Get_Object(Builder, "lblavailablemissioninfo")),
            To_String(MissionInfo));
         case SkyBases(SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex)
           .Reputation
           (1) is
            when 0 .. 25 =>
               MissionsLimit := 1;
            when 26 .. 50 =>
               MissionsLimit := 3;
            when 51 .. 75 =>
               MissionsLimit := 5;
            when 76 .. 100 =>
               MissionsLimit := 10;
            when others =>
               MissionsLimit := 0;
         end case;
         for Mission of PlayerShip.Missions loop
            if Mission.StartBase =
              SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex then
               MissionsLimit := MissionsLimit - 1;
            end if;
         end loop;
         if MissionsLimit > 0 then
            Set_Label
              (Gtk_Label(Get_Object(Builder, "lblavailablemissions")),
               "You can take" &
               Natural'Image(MissionsLimit) &
               " more missions in this base.");
         else
            Set_Label
              (Gtk_Label(Get_Object(Builder, "lblavailablemissions")),
               "You can't take any more missions in this base.");
            CanAccept := False;
         end if;
         if not CanAccept then
            Set_Sensitive
              (Gtk_Widget(Get_Object(Builder, "btnacceptmission")),
               False);
         else
            Set_Sensitive
              (Gtk_Widget(Get_Object(Builder, "btnacceptmission")),
               True);
         end if;
      else
         Set_Markup
           (Gtk_Label(Get_Object(Builder, "lblmissioninfo")),
            To_String(MissionInfo));
         if Mission.Finished then
            Set_Label
              (Gtk_Label(Get_Object(Builder, "lblfinished")),
               "Mission is ready to return.");
            Set_Label
              (Gtk_Button(Get_Object(Builder, "btndestination")),
               "Set starting base as destination for ship");
         else
            Set_Label(Gtk_Label(Get_Object(Builder, "lblfinished")), "");
            Set_Label
              (Gtk_Button(Get_Object(Builder, "btndestination")),
               "Set mission as destination for ship");
         end if;
      end if;
   end ShowMissionInfo;

   procedure AcceptSelectedMission
     (Object: access Gtkada_Builder_Record'Class) is
      MissionsIter: Gtk_Tree_Iter;
      MissionsModel: Gtk_Tree_Model;
   begin
      AcceptMission(MissionIndex);
      Get_Selected
        (Gtk.Tree_View.Get_Selection
           (Gtk_Tree_View(Get_Object(Object, "treemissions"))),
         MissionsModel,
         MissionsIter);
      if MissionsIter = Null_Iter then
         return;
      end if;
      Remove(-(MissionsModel), MissionsIter);
      Set_Cursor
        (Gtk_Tree_View(Get_Object(Builder, "treemissions")),
         Gtk_Tree_Path_New_From_String("0"),
         Gtk_Tree_View_Column(Get_Object(Builder, "columnmission")),
         False);
      ShowLastMessage(Object);
   exception
      when An_Exception : Missions_Accepting_Error =>
         ShowDialog
           (Exception_Message(An_Exception),
            Gtk_Window(Get_Object(Object, "skymapwindow")));
   end AcceptSelectedMission;

   procedure ButtonMission(User_Data: access GObject_Record'Class) is
      X, Y: Integer;
   begin
      if User_Data = Get_Object(Builder, "btnmissioncenter") then
         CreateSkyMap
           (PlayerShip.Missions(MissionIndex).TargetX,
            PlayerShip.Missions(MissionIndex).TargetY);
      else
         if not PlayerShip.Missions(MissionIndex).Finished then
            X := PlayerShip.Missions(MissionIndex).TargetX;
            Y := PlayerShip.Missions(MissionIndex).TargetY;
         else
            X := SkyBases(PlayerShip.Missions(MissionIndex).StartBase).SkyX;
            Y := SkyBases(PlayerShip.Missions(MissionIndex).StartBase).SkyY;
         end if;
         if X = PlayerShip.SkyX and Y = PlayerShip.SkyY then
            ShowDialog
              ("You are at this target now.",
               Gtk_Window(Get_Object(Builder, "skymapwindow")));
            return;
         end if;
         PlayerShip.DestinationX := X;
         PlayerShip.DestinationY := Y;
         AddMessage("You set travel destination for your ship.", OrderMessage);
         CreateSkyMap;
      end if;
      Set_Visible_Child_Name
        (Gtk_Stack(Get_Object(Builder, "gamestack")),
         "skymap");
      Set_Deletable(Gtk_Window(Get_Object(Builder, "skymapwindow")), True);
   end ButtonMission;

   procedure CreateMissionsUI(NewBuilder: Gtkada_Builder) is
   begin
      Builder := NewBuilder;
      Register_Handler(Builder, "Show_Mission_Info", ShowMissionInfo'Access);
      Register_Handler(Builder, "Button_Mission", ButtonMission'Access);
      Register_Handler
        (Builder,
         "Accept_Mission",
         AcceptSelectedMission'Access);
   end CreateMissionsUI;

   procedure ShowMissionsUI is
      BaseIndex: constant Positive :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex;
      MissionsIter: Gtk_Tree_Iter;
      MissionsList: Gtk_List_Store;
   begin
      MissionsList := Gtk_List_Store(Get_Object(Builder, "missionslist"));
      Cleaning := True;
      Clear(MissionsList);
      Cleaning := False;
      for I in SkyBases(BaseIndex).Missions.Iterate loop
         Append(MissionsList, MissionsIter);
         case SkyBases(BaseIndex).Missions(I).MType is
            when Deliver =>
               Set(MissionsList, MissionsIter, 0, "Deliver item to base");
            when Patrol =>
               Set(MissionsList, MissionsIter, 0, "Patrol area");
            when Destroy =>
               Set(MissionsList, MissionsIter, 0, "Destroy ship");
            when Explore =>
               Set(MissionsList, MissionsIter, 0, "Explore area");
            when Passenger =>
               Set
                 (MissionsList,
                  MissionsIter,
                  0,
                  "Transport passenger to base");
         end case;
         Set
           (MissionsList,
            MissionsIter,
            1,
            Gint(Mission_Container.To_Index(I)));
         Set
           (MissionsList,
            MissionsIter,
            2,
            Gint
              (CountDistance
                 (SkyBases(BaseIndex).Missions(I).TargetX,
                  SkyBases(BaseIndex).Missions(I).TargetY)));
      end loop;
      Set_Visible_Child_Name
        (Gtk_Stack(Get_Object(Builder, "gamestack")),
         "availablemissions");
      Set_Deletable(Gtk_Window(Get_Object(Builder, "skymapwindow")), False);
      Set_Cursor
        (Gtk_Tree_View(Get_Object(Builder, "treemissions")),
         Gtk_Tree_Path_New_From_String("0"),
         Gtk_Tree_View_Column(Get_Object(Builder, "columnmission")),
         False);
      ShowLastMessage(Builder);
   end ShowMissionsUI;

   procedure ShowAcceptedMissions is
      MissionsIter: Gtk_Tree_Iter;
      MissionsList: Gtk_List_Store;
   begin
      MissionsList := Gtk_List_Store(Get_Object(Builder, "missionslist"));
      Cleaning := True;
      Clear(MissionsList);
      Cleaning := False;
      for I in PlayerShip.Missions.Iterate loop
         Append(MissionsList, MissionsIter);
         case PlayerShip.Missions(I).MType is
            when Deliver =>
               Set(MissionsList, MissionsIter, 0, "Deliver item to base");
            when Patrol =>
               Set(MissionsList, MissionsIter, 0, "Patrol area");
            when Destroy =>
               Set(MissionsList, MissionsIter, 0, "Destroy ship");
            when Explore =>
               Set(MissionsList, MissionsIter, 0, "Explore area");
            when Passenger =>
               Set
                 (MissionsList,
                  MissionsIter,
                  0,
                  "Transport passenger to base");
         end case;
         Set
           (MissionsList,
            MissionsIter,
            1,
            Gint(Mission_Container.To_Index(I)));
         Set
           (MissionsList,
            MissionsIter,
            2,
            Gint
              (CountDistance
                 (PlayerShip.Missions(I).TargetX,
                  PlayerShip.Missions(I).TargetY)));
      end loop;
      Set_Visible_Child_Name
        (Gtk_Stack(Get_Object(Builder, "gamestack")),
         "acceptedmissions");
      Set_Deletable(Gtk_Window(Get_Object(Builder, "skymapwindow")), False);
      Set_Cursor
        (Gtk_Tree_View(Get_Object(Builder, "treemissions1")),
         Gtk_Tree_Path_New_From_String("0"),
         Gtk_Tree_View_Column(Get_Object(Builder, "columnmission1")),
         False);
   end ShowAcceptedMissions;

end Missions.UI;
