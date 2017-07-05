--    Copyright 2016-2017 Bartek thindil Jasicki
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
with Terminal_Interface.Curses.Menus; use Terminal_Interface.Curses.Menus;
with Ships; use Ships;
with Maps; use Maps;
with Maps.UI; use Maps.UI;
with Items; use Items;
with Bases; use Bases;
with UserInterface; use UserInterface;
with Messages; use Messages;
with Config; use Config;

package body Missions.UI is

   MissionsMenu: Menu;
   MenuWindow: Window;

   procedure ShowMissionInfo is
      Mission: constant Mission_Data :=
        PlayerShip.Missions(Get_Index(Current(MissionsMenu)));
      InfoWindow, ClearWindow: Window;
      CurrentLine: Line_Position := 2;
      MinutesDiff, Distance: Natural;
      MissionTime: Date_Record :=
        (Year => 0, Month => 0, Day => 0, Hour => 0, Minutes => 0);
      WindowHeight: Line_Position := 6;
   begin
      ClearWindow := Create(15, (Columns / 2), 3, (Columns / 2));
      Refresh_Without_Update(ClearWindow);
      Delete(ClearWindow);
      if Mission.Finished then
         WindowHeight := WindowHeight + 1;
      end if;
      if Mission.MType = Deliver or Mission.MType = Passenger then
         WindowHeight := WindowHeight + 1;
      end if;
      InfoWindow := Create(WindowHeight, (Columns / 2), 3, (Columns / 2));
      Box(InfoWindow);
      Move_Cursor(Win => InfoWindow, Line => 0, Column => 2);
      Add(Win => InfoWindow, Str => "[Mission info]");
      Move_Cursor(Win => InfoWindow, Line => 1, Column => 2);
      Add
        (Win => InfoWindow,
         Str => "From base: " & To_String(SkyBases(Mission.StartBase).Name));
      Move_Cursor(Win => InfoWindow, Line => 2, Column => 2);
      case Mission.MType is
         when Deliver =>
            Add
              (Win => InfoWindow,
               Str => "Item: " & To_String(Items_List(Mission.Target).Name));
            Move_Cursor(Win => InfoWindow, Line => 3, Column => 2);
            Add
              (Win => InfoWindow,
               Str =>
                 "To base: " &
                 To_String
                   (SkyBases
                      (SkyMap(Mission.TargetX, Mission.TargetY).BaseIndex)
                      .Name));
            CurrentLine := 3;
         when Patrol =>
            Add(Win => InfoWindow, Str => "Patrol selected area");
         when Destroy =>
            Add
              (Win => InfoWindow,
               Str =>
                 "Target: " & To_String(ProtoShips_List(Mission.Target).Name));
         when Explore =>
            Add(Win => InfoWindow, Str => "Explore selected area");
         when Passenger =>
            Add
              (Win => InfoWindow,
               Str =>
                 "Passenger: " &
                 To_String(PlayerShip.Crew(Mission.Target).Name));
            Move_Cursor(Win => InfoWindow, Line => 3, Column => 2);
            Add
              (Win => InfoWindow,
               Str =>
                 "To base: " &
                 To_String
                   (SkyBases
                      (SkyMap(Mission.TargetX, Mission.TargetY).BaseIndex)
                      .Name));
            CurrentLine := 3;
      end case;
      if not Mission.Finished then
         Distance := CountDistance(Mission.TargetX, Mission.TargetY);
      else
         Distance :=
           CountDistance
             (SkyBases(Mission.StartBase).SkyX,
              SkyBases(Mission.StartBase).SkyY);
      end if;
      Move_Cursor(Win => InfoWindow, Line => CurrentLine, Column => 2);
      Add(Win => InfoWindow, Str => "Distance:" & Integer'Image(Distance));
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
      CurrentLine := CurrentLine + 1;
      Move_Cursor(Win => InfoWindow, Line => CurrentLine, Column => 2);
      Add(Win => InfoWindow, Str => "Time limit:");
      if MissionTime.Year > 0 then
         Add(Win => InfoWindow, Str => Positive'Image(MissionTime.Year) & "y");
      end if;
      if MissionTime.Month > 0 then
         Add
           (Win => InfoWindow,
            Str => Positive'Image(MissionTime.Month) & "m");
      end if;
      if MissionTime.Day > 0 then
         Add(Win => InfoWindow, Str => Positive'Image(MissionTime.Day) & "d");
      end if;
      if MissionTime.Hour > 0 then
         Add(Win => InfoWindow, Str => Positive'Image(MissionTime.Hour) & "h");
      end if;
      if MissionTime.Minutes > 0 then
         Add
           (Win => InfoWindow,
            Str => Positive'Image(MissionTime.Minutes) & "mins");
      end if;
      CurrentLine := CurrentLine + 1;
      Move_Cursor(Win => InfoWindow, Line => CurrentLine, Column => 2);
      Add
        (Win => InfoWindow,
         Str =>
           "Reward:" &
           Positive'Image(Mission.Reward) &
           " " &
           To_String(MoneyName));
      if Mission.Finished then
         CurrentLine := CurrentLine + 1;
         Move_Cursor(Win => InfoWindow, Line => CurrentLine, Column => 2);
         Add(Win => InfoWindow, Str => "Mission is ready to return.");
         Move_Cursor(Line => WindowHeight + 3, Column => (Columns / 2));
         Add(Str => "Press SPACE to show start base on map");
         Change_Attributes
           (Line => WindowHeight + 3,
            Column => (Columns / 2) + 6,
            Count => 5,
            Color => 1);
         Move_Cursor(Line => WindowHeight + 4, Column => (Columns / 2));
         Add(Str => "Press ENTER to set start base as a destination for ship");
         Change_Attributes
           (Line => WindowHeight + 4,
            Column => (Columns / 2) + 6,
            Count => 5,
            Color => 1);
      else
         Move_Cursor(Line => WindowHeight + 3, Column => (Columns / 2));
         Add(Str => "Press SPACE to show mission on map");
         Change_Attributes
           (Line => WindowHeight + 3,
            Column => (Columns / 2) + 6,
            Count => 5,
            Color => 1);
         Move_Cursor(Line => WindowHeight + 4, Column => (Columns / 2));
         Add(Str => "Press ENTER to set mission as a destination for ship");
         Change_Attributes
           (Line => WindowHeight + 4,
            Column => (Columns / 2) + 6,
            Count => 5,
            Color => 1);
      end if;
      Refresh_Without_Update;
      Refresh_Without_Update(InfoWindow);
      Delete(InfoWindow);
      Refresh_Without_Update(MenuWindow);
      Update_Screen;
   end ShowMissionInfo;

   procedure ShowMissions is
      Missions_Items: constant Item_Array_Access :=
        new Item_Array
        (PlayerShip.Missions.First_Index ..
             (PlayerShip.Missions.Last_Index + 1));
      MenuHeight: Line_Position;
      MenuLength: Column_Position;
   begin
      if PlayerShip.Missions.Length = 0 then
         Move_Cursor(Line => (Lines / 3), Column => (Columns / 3));
         Add(Str => "You didn't accepted any mission yet.");
         if MissionsMenu /= Null_Menu then
            Post(MissionsMenu, False);
            Delete(MissionsMenu);
         end if;
         Refresh;
         return;
      end if;
      for I in
        PlayerShip.Missions.First_Index .. PlayerShip.Missions.Last_Index loop
         case PlayerShip.Missions(I).MType is
            when Deliver =>
               Missions_Items.all(I) := New_Item("Deliver item to base");
            when Patrol =>
               Missions_Items.all(I) := New_Item("Patrol area");
            when Destroy =>
               Missions_Items.all(I) := New_Item("Destroy ship");
            when Explore =>
               Missions_Items.all(I) := New_Item("Explore area");
            when Passenger =>
               Missions_Items.all(I) :=
                 New_Item("Transport passenger to base");
         end case;
      end loop;
      Missions_Items.all(Missions_Items'Last) := Null_Item;
      MissionsMenu := New_Menu(Missions_Items);
      Set_Format(MissionsMenu, Lines - 10, 1);
      Set_Mark(MissionsMenu, "");
      Scale(MissionsMenu, MenuHeight, MenuLength);
      MenuWindow := Create(MenuHeight, MenuLength, 3, 2);
      Set_Window(MissionsMenu, MenuWindow);
      Set_Sub_Window
        (MissionsMenu,
         Derived_Window(MenuWindow, MenuHeight, MenuLength, 0, 0));
      Post(MissionsMenu);
      ShowMissionInfo;
   end ShowMissions;

   function ShowMissionsKeys(Key: Key_Code) return GameStates is
      Result: Driver_Result;
      MissionIndex: Positive;
      X, Y: Integer;
   begin
      if MissionsMenu /= Null_Menu then
         MissionIndex := Get_Index(Current(MissionsMenu));
         case Key is
            when Character'Pos('q') | Character'Pos('Q') => -- Back to sky map
               Post(MissionsMenu, False);
               Delete(MissionsMenu);
               DrawGame(Sky_Map_View);
               return Sky_Map_View;
            when KEY_UP => -- Select previous event
               Result := Driver(MissionsMenu, M_Up_Item);
               if Result = Request_Denied then
                  Result := Driver(MissionsMenu, M_Last_Item);
               end if;
            when KEY_DOWN => -- Select next event
               Result := Driver(MissionsMenu, M_Down_Item);
               if Result = Request_Denied then
                  Result := Driver(MissionsMenu, M_First_Item);
               end if;
            when 32 => -- Show selected event on map
               MoveMap
                 (PlayerShip.Missions(MissionIndex).TargetX,
                  PlayerShip.Missions(MissionIndex).TargetY);
               DrawGame(Sky_Map_View);
               return Sky_Map_View;
            when 10 => -- Set event as destination point for ship
               if not PlayerShip.Missions(MissionIndex).Finished then
                  X := PlayerShip.Missions(MissionIndex).TargetX;
                  Y := PlayerShip.Missions(MissionIndex).TargetY;
               else
                  X :=
                    SkyBases(PlayerShip.Missions(MissionIndex).StartBase).SkyX;
                  Y :=
                    SkyBases(PlayerShip.Missions(MissionIndex).StartBase).SkyY;
               end if;
               if X = PlayerShip.SkyX and Y = PlayerShip.SkyY then
                  ShowDialog("You are at this target now.");
                  DrawGame(Missions_View);
                  return Missions_View;
               end if;
               PlayerShip.DestinationX := X;
               PlayerShip.DestinationY := Y;
               AddMessage
                 ("You set travel destination for your ship.",
                  OrderMessage);
               if GameSettings.AutoCenter then
                  CenterMap;
               end if;
               DrawGame(Sky_Map_View);
               return Sky_Map_View;
            when others =>
               Result := Driver(MissionsMenu, Key);
               if Result /= Menu_Ok then
                  Result := Driver(MissionsMenu, M_Clear_Pattern);
                  Result := Driver(MissionsMenu, Key);
               end if;
         end case;
         if Result = Menu_Ok then
            ShowMissionInfo;
         end if;
      else
         case Key is
            when Character'Pos('q') | Character'Pos('Q') => -- Back to sky map
               DrawGame(Sky_Map_View);
               return Sky_Map_View;
            when others =>
               null;
         end case;
      end if;
      return Missions_View;
   end ShowMissionsKeys;

end Missions.UI;
