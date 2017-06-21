--    Copyright 2017 Bartek thindil Jasicki
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
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with Game; use Game;
with Log; use Log;
with Ships; use Ships;
with Crafts; use Crafts;
with Items; use Items;
with Utils; use Utils;
with Statistics; use Statistics;
with Messages; use Messages;
with Missions; use Missions;

package body Goals is

   procedure LoadGoals is
      GoalsFile: File_Type;
      RawData, FieldName, Value: Unbounded_String;
      EqualIndex: Natural;
      TempRecord: Goal_Data;
      Files: Search_Type;
      FoundFile: Directory_Entry_Type;
   begin
      if Goals_List.Length > 0 then
         return;
      end if;
      if not Exists(To_String(DataDirectory) & "goals" & Dir_Separator) then
         raise Goals_Directory_Not_Found;
      end if;
      Start_Search
        (Files,
         To_String(DataDirectory) & "goals" & Dir_Separator,
         "*.dat");
      if not More_Entries(Files) then
         raise Goals_Files_Not_Found;
      end if;
      while More_Entries(Files) loop
         Get_Next_Entry(Files, FoundFile);
         TempRecord :=
           (Index => Null_Unbounded_String,
            GType => RANDOM,
            Amount => 0,
            TargetIndex => Null_Unbounded_String);
         LogMessage("Loading goals file: " & Full_Name(FoundFile), Everything);
         Open(GoalsFile, In_File, Full_Name(FoundFile));
         while not End_Of_File(GoalsFile) loop
            RawData := To_Unbounded_String(Get_Line(GoalsFile));
            if Element(RawData, 1) /= '[' then
               EqualIndex := Index(RawData, "=");
               FieldName := Head(RawData, EqualIndex - 2);
               Value := Tail(RawData, (Length(RawData) - EqualIndex - 1));
               if FieldName = To_Unbounded_String("Type") then
                  TempRecord.GType := GoalTypes'Value(To_String(Value));
               elsif FieldName = To_Unbounded_String("Amount") then
                  TempRecord.Amount := Natural'Value(To_String(Value));
               elsif FieldName = To_Unbounded_String("Target") and
                 TempRecord.GType /= DISCOVER then
                  TempRecord.TargetIndex := Value;
               end if;
            else
               if TempRecord.GType /= RANDOM then
                  LogMessage
                    ("Goal added: " & To_String(TempRecord.Index),
                     Everything);
                  Goals_List.Append(New_Item => TempRecord);
                  TempRecord :=
                    (Index => Null_Unbounded_String,
                     GType => RANDOM,
                     Amount => 0,
                     TargetIndex => Null_Unbounded_String);
               end if;
               if Length(RawData) > 2 then
                  TempRecord.Index :=
                    Unbounded_Slice(RawData, 2, (Length(RawData) - 1));
               end if;
            end if;
         end loop;
         Close(GoalsFile);
      end loop;
      End_Search(Files);
   end LoadGoals;

   function GoalText(Index: Natural) return String is
      Text: Unbounded_String;
      ItemIndex: Positive;
      Goal: Goal_Data;
   begin
      if Index > 0 then
         Goal := Goals_List(Index);
      else
         Goal := CurrentGoal;
      end if;
      case Goal.GType is
         when REPUTATION =>
            Text := To_Unbounded_String("Gain max reputation in");
         when DESTROY =>
            Text := To_Unbounded_String("Destroy");
         when DISCOVER =>
            Text := To_Unbounded_String("Discover");
         when VISIT =>
            Text := To_Unbounded_String("Visit");
         when CRAFT =>
            Text := To_Unbounded_String("Craft");
         when MISSION =>
            Text := To_Unbounded_String("Finish");
         when RANDOM =>
            null;
      end case;
      Append(Text, Positive'Image(Goal.Amount));
      case Goal.GType is
         when REPUTATION | VISIT =>
            Append(Text, " base");
         when DESTROY =>
            Append(Text, " ship");
         when DISCOVER =>
            Append(Text, " field");
         when CRAFT =>
            Append(Text, " item");
         when MISSION =>
            Append(Text, " mission");
         when RANDOM =>
            null;
      end case;
      if Goal.GType /= RANDOM and Goal.Amount > 1 then
         Append(Text, "s");
      end if;
      if Goal.GType = DISCOVER then
         Append(Text, " of map");
      end if;
      if Goal.TargetIndex /= Null_Unbounded_String then
         case Goal.GType is
            when REPUTATION | VISIT =>
               Append(Text, " of " & To_String(Goal.TargetIndex));
            when DESTROY =>
               for I in ProtoShips_List.Iterate loop
                  if ProtoShips_List(I).Index = Goal.TargetIndex then
                     Append(Text, ": " & To_String(ProtoShips_List(I).Name));
                     exit;
                  end if;
               end loop;
            when CRAFT =>
               ItemIndex :=
                 Recipes_List(FindRecipe(Goal.TargetIndex)).ResultIndex;
               Append(Text, ": " & To_String(Items_List(ItemIndex).Name));
            when MISSION =>
               case Missions_Types'Value(To_String(Goal.TargetIndex)) is
                  when Deliver =>
                     Append(Text, ": Deliver item to base");
                  when Patrol =>
                     Append(Text, ": Patrol area");
                  when Destroy =>
                     Append(Text, ": Destroy ship");
                  when Explore =>
                     Append(Text, ": Explore area");
                  when Passenger =>
                     Append(Text, ": Transport passenger to base");
               end case;
            when RANDOM | DISCOVER =>
               null;
         end case;
      end if;
      return To_String(Text);
   end GoalText;

   procedure ClearCurrentGoal is
   begin
      CurrentGoal :=
        (Index => Null_Unbounded_String,
         GType => RANDOM,
         Amount => 0,
         TargetIndex => Null_Unbounded_String);
   end ClearCurrentGoal;

   procedure UpdateGoal
     (GType: GoalTypes;
      TargetIndex: Unbounded_String;
      Amount: Positive := 1) is
   begin
      if GType /= CurrentGoal.GType then
         return;
      end if;
      if To_Lower(To_String(TargetIndex)) /=
        To_Lower(To_String(CurrentGoal.TargetIndex)) and
        CurrentGoal.TargetIndex /= Null_Unbounded_String then
         return;
      end if;
      if Amount >= CurrentGoal.Amount then
         CurrentGoal.Amount := 0;
      else
         CurrentGoal.Amount := CurrentGoal.Amount - Amount;
      end if;
      if CurrentGoal.Amount = 0 then
         UpdateFinishedGoals(CurrentGoal.Index);
         AddMessage
           ("You finished your goal. New goal is set.",
            OtherMessage,
            4);
         CurrentGoal :=
           Goals_List
             (GetRandom(Goals_List.First_Index, Goals_List.Last_Index));
      end if;
   end UpdateGoal;

end Goals;
