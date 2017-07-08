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
with Ada.Characters.Handling; use Ada.Characters.Handling;
with Terminal_Interface.Curses.Forms; use Terminal_Interface.Curses.Forms;
with Terminal_Interface.Curses.Forms.Field_Types.IntField;
use Terminal_Interface.Curses.Forms.Field_Types.IntField;
with Ships; use Ships;
with Ships.Movement; use Ships.Movement;
with Bases; use Bases;
with UserInterface; use UserInterface;
with Messages; use Messages;
with Events; use Events;
with Missions; use Missions;
with Items; use Items;
with Crew; use Crew;
with Messages.UI; use Messages.UI;
with Config; use Config;

package body Maps.UI is

   MoveX, MoveY: Integer := 0;
   MoveForm: Form;
   FormWindow: Window;

   procedure ShowSkyMap is
      StartX: Integer;
      StartY: Integer;
      BaseIndex, EventIndex, MissionIndex: Natural;
      InfoWindow: Window;
      WindowHeight, CurrentLine: Line_Position := 3;
      WindowWidth, NewWindowWidth: Column_Position := 20;
      CurrentCell: Attributed_Character;
   begin
      CurrentCell := ACS_Map(ACS_Checker_Board);
      CurrentCell.Color := 0;
      StartX := PlayerShip.SkyX - Integer(Columns / 2);
      StartX := StartX + MoveX;
      if StartX < 0 then
         StartX := 0;
      elsif (StartX + Integer(Columns)) > 1025 then
         StartX := 1025 - Integer(Columns);
      end if;
      if PlayerShip.SkyX + MoveX <= 1 then
         MoveX := 1 - PlayerShip.SkyX;
      elsif PlayerShip.SkyX + MoveX > 1024 then
         MoveX := 1024 - PlayerShip.SkyX;
      end if;
      StartY := PlayerShip.SkyY - Integer((Lines - 7) / 2);
      StartY := StartY + MoveY;
      if StartY < 0 then
         StartY := 0;
      elsif (StartY + Integer(Lines - 7)) > 1025 then
         StartY := 1025 - Integer(Lines - 7);
      end if;
      if PlayerShip.SkyY + MoveY <= 1 then
         MoveY := 1 - PlayerShip.SkyY;
      elsif PlayerShip.SkyY + MoveY > 1024 then
         MoveY := 1024 - PlayerShip.SkyY;
      end if;
      for X in 1 .. Integer(Columns) - 1 loop
         for Y in 1 .. Integer(Lines) - 8 loop
            BaseIndex := SkyMap(StartX + X, StartY + Y).BaseIndex;
            if BaseIndex > 0 then
               if SkyBases(BaseIndex).Known then
                  Move_Cursor
                    (Line => Line_Position(Y),
                     Column => Column_Position(X - 1));
                  Add(Ch => 'o');
                  if SkyBases(BaseIndex).Visited.Year > 0 then
                     case SkyBases(BaseIndex).BaseType is
                        when Industrial =>
                           Change_Attributes
                             (Line => Line_Position(Y),
                              Column => Column_Position(X - 1),
                              Count => 1,
                              Color => 3);
                        when Agricultural =>
                           Change_Attributes
                             (Line => Line_Position(Y),
                              Column => Column_Position(X - 1),
                              Count => 1,
                              Color => 2);
                        when Refinery =>
                           Change_Attributes
                             (Line => Line_Position(Y),
                              Column => Column_Position(X - 1),
                              Count => 1,
                              Color => 4);
                        when Shipyard =>
                           Change_Attributes
                             (Line => Line_Position(Y),
                              Column => Column_Position(X - 1),
                              Count => 1,
                              Color => 5);
                        when others =>
                           null;
                     end case;
                  else
                     Change_Attributes
                       (Line => Line_Position(Y),
                        Column => Column_Position(X - 1),
                        Count => 1,
                        Color => 7);
                  end if;
               else
                  Move_Cursor
                    (Line => Line_Position(Y),
                     Column => Column_Position(X - 1));
                  Change_Attributes
                    (Line => Line_Position(Y),
                     Column => Column_Position(X - 1),
                     Count => 1,
                     Color => 6);
               end if;
            elsif not SkyMap(StartX + X, StartY + Y).Visited then
               Change_Attributes
                 (Line => Line_Position(Y),
                  Column => Column_Position(X - 1),
                  Count => 1,
                  Color => 6);
            end if;
            if SkyMap(StartX + X, StartY + Y).EventIndex > 0 then
               Move_Cursor
                 (Line => Line_Position(Y),
                  Column => Column_Position(X - 1));
               Add(Ch => '?');
            end if;
            if SkyMap(StartX + X, StartY + Y).MissionIndex > 0 then
               Move_Cursor
                 (Line => Line_Position(Y),
                  Column => Column_Position(X - 1));
               Add(Ch => '!');
            end if;
            if StartX + X = PlayerShip.SkyX and
              StartY + Y = PlayerShip.SkyY then
               Move_Cursor
                 (Line => Line_Position(Y),
                  Column => Column_Position(X - 1));
               Add(Ch => '+');
            end if;
            if (MoveX /= 0 or MoveY /= 0) and
              (StartX + X = PlayerShip.SkyX + MoveX and
               StartY + Y = PlayerShip.SkyY + MoveY) then
               if Peek
                   (Line => Line_Position(Y),
                    Column => Column_Position(X - 1))
                   .Ch =
                 ' ' then
                  Move_Cursor
                    (Line => Line_Position(Y),
                     Column => Column_Position(X - 1));
                  Add(Ch => CurrentCell);
               end if;
            end if;
         end loop;
      end loop;
      Refresh_Without_Update;
      BaseIndex :=
        SkyMap(PlayerShip.SkyX + MoveX, PlayerShip.SkyY + MoveY).BaseIndex;
      if BaseIndex > 0 then
         if SkyBases(BaseIndex).Visited.Year > 0 then
            WindowHeight := WindowHeight + 6;
            if SkyBases(BaseIndex).Population = 0 then
               WindowHeight := WindowHeight - 1;
            end if;
         elsif SkyBases(BaseIndex).Known then
            WindowHeight := WindowHeight + 2;
         end if;
         WindowWidth := 4 + Column_Position(Length(SkyBases(BaseIndex).Name));
         if WindowWidth < 20 then
            WindowWidth := 20;
         end if;
      end if;
      EventIndex :=
        SkyMap(PlayerShip.SkyX + MoveX, PlayerShip.SkyY + MoveY).EventIndex;
      MissionIndex :=
        SkyMap(PlayerShip.SkyX + MoveX, PlayerShip.SkyY + MoveY).MissionIndex;
      if EventIndex > 0 or MissionIndex > 0 then
         WindowHeight := WindowHeight + 1;
      end if;
      if EventIndex > 0 then
         WindowHeight := WindowHeight + 1;
         if Events_List(EventIndex).EType = EnemyShip then
            NewWindowWidth :=
              4 +
              Column_Position
                (Length(ProtoShips_List(Events_List(EventIndex).Data).Name));
         elsif Events_List(EventIndex).EType = AttackOnBase then
            NewWindowWidth := 21;
         elsif Events_List(EventIndex).EType = DoublePrice then
            NewWindowWidth :=
              21 +
              Column_Position
                (Length(Items_List(Events_List(EventIndex).Data).Name));
         end if;
         if NewWindowWidth > WindowWidth then
            WindowWidth := NewWindowWidth;
         end if;
      end if;
      if MissionIndex > 0 then
         WindowHeight := WindowHeight + 1;
         if PlayerShip.Missions(MissionIndex).MType = Destroy then
            NewWindowWidth :=
              12 +
              Column_Position
                (Length
                   (ProtoShips_List(PlayerShip.Missions(MissionIndex).Target)
                      .Name));
         elsif PlayerShip.Missions(MissionIndex).MType = Deliver then
            NewWindowWidth :=
              12 +
              Column_Position
                (Length
                   (Items_List(PlayerShip.Missions(MissionIndex).Target)
                      .Name));
         elsif PlayerShip.Missions(MissionIndex).MType = Passenger then
            NewWindowWidth := 23;
         end if;
         if NewWindowWidth > WindowWidth then
            WindowWidth := NewWindowWidth;
         end if;
      end if;
      if MoveX /= 0 or MoveY /= 0 then
         WindowHeight := WindowHeight + 2;
      end if;
      InfoWindow :=
        Create(WindowHeight, WindowWidth, 1, (Columns - WindowWidth - 1));
      Box(InfoWindow);
      Move_Cursor(Win => InfoWindow, Line => 1, Column => 3);
      Add
        (Win => InfoWindow,
         Str =>
           "X:" &
           Positive'Image(PlayerShip.SkyX + MoveX) &
           " Y:" &
           Positive'Image(PlayerShip.SkyY + MoveY));
      if BaseIndex > 0 then
         if SkyBases(BaseIndex).Known then
            Move_Cursor(Win => InfoWindow, Line => 3, Column => 2);
            Add(Win => InfoWindow, Str => To_String(SkyBases(BaseIndex).Name));
            CurrentLine := 5;
         end if;
         if SkyBases(BaseIndex).Visited.Year > 0 then
            Move_Cursor(Win => InfoWindow, Line => 4, Column => 2);
            Add
              (Win => InfoWindow,
               Str =>
                 To_Lower(Bases_Types'Image(SkyBases(BaseIndex).BaseType)));
            Move_Cursor(Win => InfoWindow, Line => 5, Column => 2);
            if SkyBases(BaseIndex).Population > 0 and
              SkyBases(BaseIndex).Population < 150 then
               Add(Win => InfoWindow, Str => "small");
            elsif SkyBases(BaseIndex).Population > 149 and
              SkyBases(BaseIndex).Population < 300 then
               Add(Win => InfoWindow, Str => "medium");
            elsif SkyBases(BaseIndex).Population > 299 then
               Add(Win => InfoWindow, Str => "large");
            end if;
            Move_Cursor(Win => InfoWindow, Line => 6, Column => 2);
            Add
              (Win => InfoWindow,
               Str => To_Lower(Bases_Owners'Image(SkyBases(BaseIndex).Owner)));
            if SkyBases(BaseIndex).Population > 0 then
               Move_Cursor(Win => InfoWindow, Line => 7, Column => 2);
               case SkyBases(BaseIndex).Reputation(1) is
                  when -100 .. -75 =>
                     Add(Win => InfoWindow, Str => "hated");
                  when -74 .. -50 =>
                     Add(Win => InfoWindow, Str => "outlaw");
                  when -49 .. -25 =>
                     Add(Win => InfoWindow, Str => "hostile");
                  when -24 .. -1 =>
                     Add(Win => InfoWindow, Str => "unfriendly");
                  when 0 =>
                     Add(Win => InfoWindow, Str => "unknown");
                  when 1 .. 25 =>
                     Add(Win => InfoWindow, Str => "visitor");
                  when 26 .. 50 =>
                     Add(Win => InfoWindow, Str => "trader");
                  when 51 .. 75 =>
                     Add(Win => InfoWindow, Str => "friend");
                  when 76 .. 100 =>
                     Add(Win => InfoWindow, Str => "well known");
                  when others =>
                     null;
               end case;
               CurrentLine := 9;
            else
               CurrentLine := 8;
            end if;
         end if;
      end if;
      if EventIndex > 0 then
         Move_Cursor(Win => InfoWindow, Line => CurrentLine, Column => 2);
         case Events_List(EventIndex).EType is
            when EnemyShip =>
               Add
                 (Win => InfoWindow,
                  Str =>
                    To_String
                      (ProtoShips_List(Events_List(EventIndex).Data).Name));
            when FullDocks =>
               Add(Win => InfoWindow, Str => "Full docks");
            when AttackOnBase =>
               Add(Win => InfoWindow, Str => "Base under attack");
            when Disease =>
               Add(Win => InfoWindow, Str => "Disease");
            when EnemyPatrol =>
               Add(Win => InfoWindow, Str => "Enemy patrol");
            when DoublePrice =>
               Add
                 (Win => InfoWindow,
                  Str =>
                    "Double price for " &
                    To_String(Items_List(Events_List(EventIndex).Data).Name));
            when None =>
               null;
         end case;
         CurrentLine := CurrentLine + 1;
      end if;
      if MissionIndex > 0 then
         Move_Cursor(Win => InfoWindow, Line => CurrentLine, Column => 2);
         case PlayerShip.Missions(MissionIndex).MType is
            when Deliver =>
               Add
                 (Win => InfoWindow,
                  Str =>
                    "Deliver " &
                    To_String
                      (Items_List(PlayerShip.Missions(MissionIndex).Target)
                         .Name));
            when Destroy =>
               Add
                 (Win => InfoWindow,
                  Str =>
                    "Destroy " &
                    To_String
                      (ProtoShips_List
                         (PlayerShip.Missions(MissionIndex).Target)
                         .Name));
            when Patrol =>
               Add(Win => InfoWindow, Str => "Patrol area");
            when Explore =>
               Add(Win => InfoWindow, Str => "Explore area");
            when Passenger =>
               Add(Win => InfoWindow, Str => "Transport passenger");
         end case;
      end if;
      if MoveX /= 0 or MoveY /= 0 then
         Move_Cursor(Win => InfoWindow, Line => WindowHeight - 2, Column => 2);
         Add
           (Win => InfoWindow,
            Str =>
              "Distance:" &
              Positive'Image
                (CountDistance
                   (PlayerShip.SkyX + MoveX,
                    PlayerShip.SkyY + MoveY)));
      end if;
      Refresh(InfoWindow);
      Delete(InfoWindow);
      ShowLastMessages;
      LastMessage := To_Unbounded_String("");
   end ShowSkyMap;

   procedure ShowMoveMapForm is
      Move_Fields: constant Field_Array_Access := new Field_Array(1 .. 7);
      FieldOptions: Field_Option_Set;
      FormHeight: Line_Position;
      FormLength: Column_Position;
      Visibility: Cursor_Visibility := Normal;
      Result: Forms.Driver_Result;
   begin
      Set_Cursor_Visibility(Visibility);
      Move_Fields.all(1) := New_Field(1, 2, 0, 0, 0, 0);
      FieldOptions := Get_Options(Move_Fields.all(1));
      Set_Buffer(Move_Fields.all(1), 0, "X:");
      FieldOptions.Active := False;
      Set_Options(Move_Fields.all(1), FieldOptions);
      Move_Fields.all(2) := New_Field(1, 5, 0, 2, 0, 0);
      FieldOptions := Get_Options(Move_Fields.all(2));
      Set_Buffer
        (Move_Fields.all(2),
         0,
         Natural'Image(PlayerShip.SkyX + MoveX));
      FieldOptions.Auto_Skip := False;
      FieldOptions.Null_Ok := False;
      Set_Options(Move_Fields.all(2), FieldOptions);
      Set_Background
        (Move_Fields.all(2),
         (Reverse_Video => True, others => False));
      Set_Field_Type(Move_Fields.all(2), (0, 1, 1024));
      Move_Fields.all(3) := New_Field(1, 2, 0, 8, 0, 0);
      FieldOptions := Get_Options(Move_Fields.all(3));
      Set_Buffer(Move_Fields.all(3), 0, "Y:");
      FieldOptions.Active := False;
      Set_Options(Move_Fields.all(3), FieldOptions);
      Move_Fields.all(4) := New_Field(1, 5, 0, 10, 0, 0);
      FieldOptions := Get_Options(Move_Fields.all(4));
      Set_Buffer
        (Move_Fields.all(4),
         0,
         Natural'Image(PlayerShip.SkyY + MoveY));
      FieldOptions.Auto_Skip := False;
      FieldOptions.Null_Ok := False;
      Set_Options(Move_Fields.all(4), FieldOptions);
      Set_Field_Type(Move_Fields.all(4), (0, 1, 1024));
      Move_Fields.all(5) := New_Field(1, 8, 2, 1, 0, 0);
      Set_Buffer(Move_Fields.all(5), 0, "[Cancel]");
      FieldOptions := Get_Options(Move_Fields.all(5));
      FieldOptions.Edit := False;
      Set_Options(Move_Fields.all(5), FieldOptions);
      Move_Fields.all(6) := New_Field(1, 4, 2, 11, 0, 0);
      FieldOptions := Get_Options(Move_Fields.all(6));
      FieldOptions.Edit := False;
      Set_Options(Move_Fields.all(6), FieldOptions);
      Set_Buffer(Move_Fields.all(6), 0, "[Ok]");
      Move_Fields.all(7) := Null_Field;
      MoveForm := New_Form(Move_Fields);
      Set_Options(MoveForm, (others => False));
      Scale(MoveForm, FormHeight, FormLength);
      FormWindow :=
        Create
          (FormHeight + 2,
           FormLength + 2,
           ((Lines / 3) - (FormHeight / 2)),
           ((Columns / 2) - (FormLength / 2)));
      Box(FormWindow);
      Set_Window(MoveForm, FormWindow);
      Set_Sub_Window
        (MoveForm,
         Derived_Window(FormWindow, FormHeight, FormLength, 1, 1));
      Post(MoveForm);
      Result := Driver(MoveForm, F_End_Line);
      if Result = Form_Ok then
         Refresh;
         Refresh(FormWindow);
      end if;
   end ShowMoveMapForm;

   procedure MoveMap(NewX, NewY: Positive) is
   begin
      MoveX := NewX - PlayerShip.SkyX;
      MoveY := NewY - PlayerShip.SkyY;
   end MoveMap;

   procedure CenterMap is
   begin
      MoveX := 0;
      MoveY := 0;
   end CenterMap;

   function SkyMapKeys(Key: Key_Code) return Integer is
      Result: Integer := 1;
      NewX, NewY: Integer := 0;
   begin
      if Key = Key_Code(GameSettings.Keys(1)) then -- Move up
         Result := MoveShip(0, 0, -1);
      elsif Key = Key_Code(GameSettings.Keys(2)) then -- Move down
         Result := MoveShip(0, 0, 1);
      elsif Key = Key_Code(GameSettings.Keys(3)) then -- Move right
         Result := MoveShip(0, 1, 0);
      elsif Key = Key_Code(GameSettings.Keys(4)) then -- Move left
         Result := MoveShip(0, -1, 0);
      elsif Key = Key_Code(GameSettings.Keys(5)) then -- Move down/left
         Result := MoveShip(0, -1, 1);
      elsif Key = Key_Code(GameSettings.Keys(6)) then -- Move down/right
         Result := MoveShip(0, 1, 1);
      elsif Key = Key_Code(GameSettings.Keys(7)) then -- Move up/left
         Result := MoveShip(0, -1, -1);
      elsif Key = Key_Code(GameSettings.Keys(8)) then -- Move up/right
         Result := MoveShip(0, 1, -1);
      elsif Key =
        Key_Code
          (GameSettings.Keys
             (9)) then -- Wait 1 minute or travel to destination if set
         if PlayerShip.DestinationX = 0 and PlayerShip.DestinationY = 0 then
            UpdateGame(1);
         else
            if PlayerShip.DestinationX > PlayerShip.SkyX then
               NewX := 1;
            elsif PlayerShip.DestinationX < PlayerShip.SkyX then
               NewX := -1;
            end if;
            if PlayerShip.DestinationY > PlayerShip.SkyY then
               NewY := 1;
            elsif PlayerShip.DestinationY < PlayerShip.SkyY then
               NewY := -1;
            end if;
            Result := MoveShip(0, NewX, NewY);
            if PlayerShip.DestinationX = PlayerShip.SkyX and
              PlayerShip.DestinationY = PlayerShip.SkyY then
               AddMessage
                 ("You reached your travel destination.",
                  OrderMessage);
               PlayerShip.DestinationX := 0;
               PlayerShip.DestinationY := 0;
               if GameSettings.AutoFinish then
                  AutoFinishMissions;
               end if;
               return 4;
            end if;
         end if;
      elsif Key =
        Key_Code
          (GameSettings.Keys
             (10)) then -- Move to destination until combat happen or reach destination or can't move
         if PlayerShip.DestinationX = 0 and PlayerShip.DestinationY = 0 then
            return 0;
         end if;
         loop
            NewX := 0;
            NewY := 0;
            if PlayerShip.DestinationX > PlayerShip.SkyX then
               NewX := 1;
            elsif PlayerShip.DestinationX < PlayerShip.SkyX then
               NewX := -1;
            end if;
            if PlayerShip.DestinationY > PlayerShip.SkyY then
               NewY := 1;
            elsif PlayerShip.DestinationY < PlayerShip.SkyY then
               NewY := -1;
            end if;
            Result := MoveShip(0, NewX, NewY);
            exit when Result = 0;
            if CheckForEvent(Sky_Map_View) /= Sky_Map_View then
               return 5;
            end if;
            if Result = 8 then
               WaitForRest;
               Result := 1;
               if CheckForEvent(Sky_Map_View) /= Sky_Map_View then
                  return 5;
               end if;
            end if;
            if PlayerShip.DestinationX = PlayerShip.SkyX and
              PlayerShip.DestinationY = PlayerShip.SkyY then
               AddMessage
                 ("You reached your travel destination.",
                  OrderMessage);
               PlayerShip.DestinationX := 0;
               PlayerShip.DestinationY := 0;
               if GameSettings.AutoFinish then
                  AutoFinishMissions;
               end if;
               return 4;
            end if;
            exit when Result = 6 or Result = 7;
         end loop;
         if Result = 0 then
            Result := 4;
         end if;
      elsif Key = Key_Code(GameSettings.Keys(11)) then -- Move map up
         MoveY := MoveY - 1;
         Result := 4;
      elsif Key = Key_Code(GameSettings.Keys(12)) then -- Move map down
         MoveY := MoveY + 1;
         Result := 4;
      elsif Key = Key_Code(GameSettings.Keys(13)) then -- Move map right
         MoveX := MoveX + 1;
         Result := 4;
      elsif Key = Key_Code(GameSettings.Keys(14)) then -- Move map left
         MoveX := MoveX - 1;
         Result := 4;
      elsif Key = Key_Code(GameSettings.Keys(15)) then -- Move map up/left
         MoveX := MoveX - 1;
         MoveY := MoveY - 1;
         Result := 4;
      elsif Key = Key_Code(GameSettings.Keys(16)) then -- Move map up/right
         MoveX := MoveX + 1;
         MoveY := MoveY - 1;
         Result := 4;
      elsif Key = Key_Code(GameSettings.Keys(17)) then -- Move map down/left
         MoveX := MoveX - 1;
         MoveY := MoveY + 1;
         Result := 4;
      elsif Key = Key_Code(GameSettings.Keys(18)) then -- Move map down/right
         MoveX := MoveX + 1;
         MoveY := MoveY + 1;
         Result := 4;
      elsif Key = Key_Code(GameSettings.Keys(19)) then -- Center map on ship
         CenterMap;
         Result := 4;
      elsif Key =
        Key_Code
          (GameSettings.Keys
             (20)) then -- Set current map cell as destination point for ship
         if MoveX = 0 and MoveY = 0 then
            return 0;
         end if;
         PlayerShip.DestinationX := PlayerShip.SkyX + MoveX;
         PlayerShip.DestinationY := PlayerShip.SkyY + MoveY;
         AddMessage("You set travel destination for your ship.", OrderMessage);
         if GameSettings.AutoCenter then
            CenterMap;
         end if;
         return 4;
      else
         case Key is
            when Character'Pos('o') | Character'Pos('O') => -- Ship orders menu
               Result := 2;
            when Character'Pos('w') | Character'Pos('W') => -- Wait order menu
               Result := 3;
            when others =>
               Result := 0;
         end case;
      end if;
      return Result;
   end SkyMapKeys;

   function MoveFormKeys(Key: Key_Code) return GameStates is
      Result: Forms.Driver_Result;
      FieldIndex: Positive := Get_Index(Current(MoveForm));
      Visibility: Cursor_Visibility := Invisible;
   begin
      case Key is
         when KEY_UP => -- Select previous field
            Result := Driver(MoveForm, F_Previous_Field);
            FieldIndex := Get_Index(Current(MoveForm));
            if FieldIndex = 2 or FieldIndex = 4 then
               Result := Driver(MoveForm, F_End_Line);
            end if;
         when KEY_DOWN => -- Select next field
            Result := Driver(MoveForm, F_Next_Field);
            FieldIndex := Get_Index(Current(MoveForm));
            if FieldIndex = 2 or FieldIndex = 4 then
               Result := Driver(MoveForm, F_End_Line);
            end if;
         when 10 => -- quit/move map
            if FieldIndex = 6 then
               MoveMap
                 (Integer'Value(Get_Buffer(Fields(MoveForm, 2))),
                  Integer'Value(Get_Buffer(Fields(MoveForm, 4))));
            end if;
            Set_Cursor_Visibility(Visibility);
            Post(MoveForm, False);
            Delete(MoveForm);
            DrawGame(Sky_Map_View);
            return Sky_Map_View;
         when Key_Backspace => -- delete last character
            if FieldIndex = 2 or FieldIndex = 4 then
               Result := Driver(MoveForm, F_Delete_Previous);
            end if;
         when KEY_DC => -- delete character at cursor
            if FieldIndex = 2 or FieldIndex = 4 then
               Result := Driver(MoveForm, F_Delete_Char);
            end if;
         when KEY_RIGHT => -- Move cursor right
            if FieldIndex = 2 or FieldIndex = 4 then
               Result := Driver(MoveForm, F_Right_Char);
            end if;
         when KEY_LEFT => -- Move cursor left
            if FieldIndex = 2 or FieldIndex = 4 then
               Result := Driver(MoveForm, F_Left_Char);
            end if;
         when others =>
            Result := Driver(MoveForm, Key);
      end case;
      if Result = Form_Ok then
         Set_Background(Fields(MoveForm, 2), (others => False));
         Set_Background(Fields(MoveForm, 4), (others => False));
         if FieldIndex = 2 or FieldIndex = 4 then
            Set_Background
              (Current(MoveForm),
               (Reverse_Video => True, others => False));
         end if;
         Refresh(FormWindow);
      end if;
      return Move_Map;
   end MoveFormKeys;

end Maps.UI;
