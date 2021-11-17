--    Copyright 2017-2021 Bartek thindil Jasicki
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

with Ada.Characters.Handling; use Ada.Characters.Handling;
with DOM.Core; use DOM.Core;
with DOM.Core.Documents;
with DOM.Core.Nodes; use DOM.Core.Nodes;
with DOM.Core.Elements; use DOM.Core.Elements;
with Log; use Log;
with Ships; use Ships;
with Crafts; use Crafts;
with Items; use Items;
with Utils; use Utils;
with Statistics; use Statistics;
with Messages; use Messages;
with Missions; use Missions;
with Factions; use Factions;
with Game; use Game;

package body Goals is

   procedure LoadGoals(Reader: Tree_Reader) is
      TempRecord: Goal_Data;
      NodesList: Node_List;
      GoalsData: Document;
      Action: Data_Action;
      GoalIndex: Natural;
      GoalNode: Node;
   begin
      GoalsData := Get_Tree(Reader);
      NodesList :=
        DOM.Core.Documents.Get_Elements_By_Tag_Name(GoalsData, "goal");
      Load_Goals_Loop :
      for I in 0 .. Length(NodesList) - 1 loop
         TempRecord :=
           (Index => Null_Unbounded_String, GType => RANDOM, Amount => 0,
            TargetIndex => Null_Unbounded_String, Multiplier => 1);
         GoalNode := Item(NodesList, I);
         TempRecord.Index :=
           To_Unbounded_String(Get_Attribute(GoalNode, "index"));
         Action :=
           (if Get_Attribute(GoalNode, "action")'Length > 0 then
              Data_Action'Value(Get_Attribute(GoalNode, "action"))
            else ADD);
         GoalIndex := 0;
         Get_Goal_Index_Loop :
         for J in Goals_List.Iterate loop
            if Goals_List(J).Index = TempRecord.Index then
               GoalIndex := Goals_Container.To_Index(J);
               exit Get_Goal_Index_Loop;
            end if;
         end loop Get_Goal_Index_Loop;
         if Action in UPDATE | REMOVE then
            if GoalIndex = 0 then
               raise Data_Loading_Error
                 with "Can't " & To_Lower(Data_Action'Image(Action)) &
                 " goal '" & To_String(TempRecord.Index) &
                 "', there is no goal with that index.";
            end if;
         elsif GoalIndex > 0 then
            raise Data_Loading_Error
              with "Can't add goal '" & To_String(TempRecord.Index) &
              "', there is already a goal with that index.";
         end if;
         if Action /= REMOVE then
            if Action = UPDATE then
               TempRecord := Goals_List(GoalIndex);
            end if;
            if Get_Attribute(GoalNode, "type") /= "" then
               TempRecord.GType :=
                 GoalTypes'Value(Get_Attribute(GoalNode, "type"));
            end if;
            if Get_Attribute(GoalNode, "amount") /= "" then
               TempRecord.Amount :=
                 Natural'Value(Get_Attribute(GoalNode, "amount"));
            end if;
            if Get_Attribute(GoalNode, "target") /= "" then
               TempRecord.TargetIndex :=
                 To_Unbounded_String(Get_Attribute(GoalNode, "target"));
            end if;
            if Get_Attribute(GoalNode, "multiplier") /= "" then
               TempRecord.Multiplier :=
                 Natural'Value(Get_Attribute(GoalNode, "multiplier"));
            end if;
            if Action /= UPDATE then
               Goals_List.Append(New_Item => TempRecord);
               Log_Message
                 ("Goal added: " & To_String(TempRecord.Index), EVERYTHING);
            else
               Goals_List(GoalIndex) := TempRecord;
               Log_Message
                 ("Goal updated: " & To_String(TempRecord.Index), EVERYTHING);
            end if;
         else
            Goals_List.Delete(Index => GoalIndex);
            Log_Message
              ("Goal removed: " & To_String(TempRecord.Index), EVERYTHING);
         end if;
      end loop Load_Goals_Loop;
   end LoadGoals;

   function GoalText(Index: Goals_Container.Extended_Index) return String is
      Text: Unbounded_String;
      Goal: Goal_Data;
      InsertPosition: Positive;
      Added: Boolean := False;
      type FactionNameType is (NAME, MEMBERNAME, PLURALMEMBERNAME);
      function GetFactionName
        (FactionIndex: Unbounded_String; FType: FactionNameType)
         return String is
      begin
         case FType is
            when NAME =>
               return To_String(Factions_List(FactionIndex).Name);
            when MEMBERNAME =>
               return To_String(Factions_List(FactionIndex).Member_Name);
            when PLURALMEMBERNAME =>
               return
                 To_String(Factions_List(FactionIndex).Plural_Member_Name);
         end case;
      end GetFactionName;
   begin
      Goal := (if Index > 0 then Goals_List(Index) else CurrentGoal);
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
         when KILL =>
            Text := To_Unbounded_String("Kill");
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
         when KILL =>
            Append(Text, " enem");
         when RANDOM =>
            null;
      end case;
      if (Goal.GType not in RANDOM | KILL) and Goal.Amount > 1 then
         Append(Text, "s");
      end if;
      case Goal.GType is
         when DISCOVER =>
            Append(Text, " of map");
         when KILL =>
            if Goal.Amount > 1 then
               Append(Text, "ies in melee combat");
            else
               Append(Text, "y in melee combat");
            end if;
         when others =>
            null;
      end case;
      if Goal.TargetIndex /= Null_Unbounded_String then
         case Goal.GType is
            when REPUTATION | VISIT =>
               InsertPosition := Length(Text) - 3;
               if Goal.Amount > 1 then
                  InsertPosition := InsertPosition - 1;
               end if;
               Insert
                 (Text, InsertPosition,
                  GetFactionName(Goal.TargetIndex, NAME) & " ");
            when DESTROY =>
               Destroy_Ship_Loop :
               for I in Proto_Ships_List.Iterate loop
                  if Proto_Ships_Container.Key(I) = Goal.TargetIndex then
                     Append(Text, ": " & To_String(Proto_Ships_List(I).Name));
                     Added := True;
                     exit Destroy_Ship_Loop;
                  end if;
               end loop Destroy_Ship_Loop;
               if not Added then
                  InsertPosition := Length(Text) - 3;
                  if Goal.Amount > 1 then
                     InsertPosition := InsertPosition - 1;
                  end if;
                  Insert
                    (Text, InsertPosition,
                     GetFactionName(Goal.TargetIndex, NAME) & " ");
               end if;
            when CRAFT =>
               if Recipes_Container.Contains
                   (Recipes_List, Goal.TargetIndex) then
                  declare
                     ItemIndex: constant Unbounded_String :=
                       Recipes_List(Goal.TargetIndex).Result_Index;
                  begin
                     Append
                       (Text, ": " & To_String(Items_List(ItemIndex).Name));
                  end;
               else
                  Append(Text, ": " & To_String(Goal.TargetIndex));
               end if;
            when MISSION =>
               case Missions_Types'Value(To_String(Goal.TargetIndex)) is
                  when Deliver =>
                     Append(Text, ": Deliver items to bases");
                  when Patrol =>
                     Append(Text, ": Patrol areas");
                  when Destroy =>
                     Append(Text, ": Destroy ships");
                  when Explore =>
                     Append(Text, ": Explore areas");
                  when Passenger =>
                     Append(Text, ": Transport passengers to bases");
               end case;
            when KILL =>
               InsertPosition := Length(Text) - 20;
               if Goal.Amount > 1 then
                  InsertPosition := InsertPosition - 2;
               end if;
               declare
                  StopPosition: Natural := InsertPosition + 4;
               begin
                  if Goal.Amount > 1 then
                     StopPosition := StopPosition + 2;
                     Replace_Slice
                       (Text, InsertPosition, StopPosition,
                        GetFactionName(Goal.TargetIndex, PLURALMEMBERNAME));
                  else
                     Replace_Slice
                       (Text, InsertPosition, StopPosition,
                        GetFactionName(Goal.TargetIndex, MEMBERNAME));
                  end if;
               end;
            when RANDOM | DISCOVER =>
               null;
         end case;
      end if;
      return To_String(Text);
   end GoalText;

   procedure ClearCurrentGoal is
   begin
      CurrentGoal :=
        (Index => Null_Unbounded_String, GType => RANDOM, Amount => 0,
         TargetIndex => Null_Unbounded_String, Multiplier => 1);
   end ClearCurrentGoal;

   procedure UpdateGoal
     (GType: GoalTypes; TargetIndex: Unbounded_String;
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
      CurrentGoal.Amount :=
        (if Amount >= CurrentGoal.Amount then 0
         else CurrentGoal.Amount - Amount);
      if CurrentGoal.Amount = 0 then
         UpdateFinishedGoals(CurrentGoal.Index);
         AddMessage
           ("You finished your goal. New goal is set.", OtherMessage, BLUE);
         CurrentGoal :=
           Goals_List
             (Get_Random(Goals_List.First_Index, Goals_List.Last_Index));
      end if;
   end UpdateGoal;

end Goals;
