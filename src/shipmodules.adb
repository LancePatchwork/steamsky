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

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Directories; use Ada.Directories;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with Game; use Game;
with Log; use Log;

package body ShipModules is

   procedure LoadShipModules is
      ModulesFile: File_Type;
      RawData, FieldName, Value: Unbounded_String;
      EqualIndex: Natural;
      TempRecord: BaseModule_Data;
      Files: Search_Type;
      FoundFile: Directory_Entry_Type;
   begin
      if Modules_List.Length > 0 then
         return;
      end if;
      if not Exists
          (To_String(DataDirectory) & "shipmodules" & Dir_Separator) then
         raise Modules_Directory_Not_Found;
      end if;
      Start_Search
        (Files,
         To_String(DataDirectory) & "shipmodules" & Dir_Separator,
         "*.dat");
      if not More_Entries(Files) then
         raise Modules_Files_Not_Found;
      end if;
      while More_Entries(Files) loop
         Get_Next_Entry(Files, FoundFile);
         TempRecord :=
           (Name => Null_Unbounded_String,
            MType => ENGINE,
            Weight => 0,
            Value => 0,
            MaxValue => 0,
            Durability => 0,
            RepairMaterial => Null_Unbounded_String,
            RepairSkill => 2,
            Price => 0,
            InstallTime => 60,
            Unique => False,
            Size => 0,
            Description => Null_Unbounded_String,
            Index => Null_Unbounded_String);
         LogMessage
           ("Loading ship modules file: " & Full_Name(FoundFile),
            Everything);
         Open(ModulesFile, In_File, Full_Name(FoundFile));
         while not End_Of_File(ModulesFile) loop
            RawData := To_Unbounded_String(Get_Line(ModulesFile));
            if Element(RawData, 1) /= '[' then
               EqualIndex := Index(RawData, "=");
               FieldName := Head(RawData, EqualIndex - 2);
               Value := Tail(RawData, (Length(RawData) - EqualIndex - 1));
               if FieldName = To_Unbounded_String("Name") then
                  TempRecord.Name := Value;
               elsif FieldName = To_Unbounded_String("Type") then
                  TempRecord.MType := ModuleType'Value(To_String(Value));
               elsif FieldName = To_Unbounded_String("Weight") then
                  TempRecord.Weight := Integer'Value(To_String(Value));
               elsif FieldName = To_Unbounded_String("Value") then
                  TempRecord.Value := Integer'Value(To_String(Value));
               elsif FieldName = To_Unbounded_String("MaxValue") then
                  TempRecord.MaxValue := Integer'Value(To_String(Value));
               elsif FieldName = To_Unbounded_String("Durability") then
                  TempRecord.Durability := Integer'Value(To_String(Value));
               elsif FieldName = To_Unbounded_String("Material") then
                  TempRecord.RepairMaterial := Value;
               elsif FieldName = To_Unbounded_String("Skill") then
                  for I in Skills_Names.Iterate loop
                     if Value = To_String(Skills_Names(I)) then
                        TempRecord.RepairSkill :=
                          UnboundedString_Container.To_Index(I);
                        exit;
                     end if;
                  end loop;
               elsif FieldName = To_Unbounded_String("Price") then
                  TempRecord.Price := Integer'Value(To_String(Value));
               elsif FieldName = To_Unbounded_String("InstallTime") then
                  TempRecord.InstallTime := Integer'Value(To_String(Value));
               elsif FieldName = To_Unbounded_String("Unique") then
                  if Value = To_Unbounded_String("Yes") then
                     TempRecord.Unique := True;
                  else
                     TempRecord.Unique := False;
                  end if;
               elsif FieldName = To_Unbounded_String("Size") then
                  TempRecord.Size := Integer'Value(To_String(Value));
               elsif FieldName = To_Unbounded_String("Description") then
                  TempRecord.Description := Value;
               end if;
            else
               if TempRecord.Name /= Null_Unbounded_String then
                  LogMessage
                    ("Module added: " & To_String(TempRecord.Name),
                     Everything);
                  Modules_List.Append(New_Item => TempRecord);
                  TempRecord :=
                    (Name => Null_Unbounded_String,
                     MType => ENGINE,
                     Weight => 0,
                     Value => 0,
                     MaxValue => 0,
                     Durability => 0,
                     RepairMaterial => Null_Unbounded_String,
                     RepairSkill => 2,
                     Price => 0,
                     InstallTime => 60,
                     Unique => False,
                     Size => 0,
                     Description => Null_Unbounded_String,
                     Index => Null_Unbounded_String);
               end if;
               if Length(RawData) > 2 then
                  TempRecord.Index :=
                    Unbounded_Slice(RawData, 2, (Length(RawData) - 1));
               end if;
            end if;
         end loop;
         Close(ModulesFile);
      end loop;
      End_Search(Files);
   end LoadShipModules;

   function FindProtoModule(Index: Unbounded_String) return Natural is
   begin
      for I in Modules_List.Iterate loop
         if Modules_List(I).Index = Index then
            return BaseModules_Container.To_Index(I);
         end if;
      end loop;
      return 0;
   end FindProtoModule;

end ShipModules;
