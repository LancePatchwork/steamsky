--    Copyright 2016-2021 Bartek thindil Jasicki
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
with Ada.Strings.Maps; use Ada.Strings.Maps;
with DOM.Core; use DOM.Core;
with DOM.Core.Documents;
with DOM.Core.Nodes; use DOM.Core.Nodes;
with DOM.Core.Elements; use DOM.Core.Elements;
with Log; use Log;
with Items; use Items;

package body ShipModules is

   procedure Load_Ship_Modules(Reader: Tree_Reader) is
      NodesList: Node_List;
      ModulesData: Document;
      TempRecord: Base_Module_Data;
      Action: Data_Action;
      ModuleNode: Node;
      SkillIndex: Natural;
      MaterialExists: Boolean;
      ModuleIndex: Unbounded_String;
   begin
      ModulesData := Get_Tree(Reader);
      NodesList :=
        DOM.Core.Documents.Get_Elements_By_Tag_Name(ModulesData, "module");
      Load_Modules_Loop :
      for I in 0 .. Length(NodesList) - 1 loop
         TempRecord :=
           (Name => Null_Unbounded_String, MType => ENGINE, Weight => 0,
            Value => 0, Max_Value => 0, Durability => 0,
            Repair_Material => Null_Unbounded_String, Repair_Skill => 2,
            Price => 0, Install_Time => 60, Unique => False, Size => 1,
            Description => Null_Unbounded_String, Max_Owners => 1, Speed => 4,
            Reputation => -100);
         ModuleNode := Item(NodesList, I);
         ModuleIndex :=
           To_Unbounded_String(Get_Attribute(ModuleNode, "index"));
         Action :=
           (if Get_Attribute(ModuleNode, "action")'Length > 0 then
              Data_Action'Value(Get_Attribute(ModuleNode, "action"))
            else ADD);
         if Action in UPDATE | REMOVE then
            if not BaseModules_Container.Contains
                (Modules_List, ModuleIndex) then
               raise Data_Loading_Error
                 with "Can't " & To_Lower(Data_Action'Image(Action)) &
                 " ship module '" & To_String(ModuleIndex) &
                 "', there is no ship module with that index.";
            end if;
         elsif BaseModules_Container.Contains(Modules_List, ModuleIndex) then
            raise Data_Loading_Error
              with "Can't add ship module '" & To_String(ModuleIndex) &
              "', there is already a ship with that index.";
         end if;
         if Action /= REMOVE then
            if Action = UPDATE then
               TempRecord := Modules_List(ModuleIndex);
            end if;
            if Get_Attribute(ModuleNode, "name")'Length > 0 then
               TempRecord.Name :=
                 To_Unbounded_String(Get_Attribute(ModuleNode, "name"));
            end if;
            if Get_Attribute(ModuleNode, "type")'Length > 0 then
               TempRecord.MType :=
                 Module_Type'Value(Get_Attribute(ModuleNode, "type"));
            end if;
            if Get_Attribute(ModuleNode, "weight")'Length > 0 then
               TempRecord.Weight :=
                 Natural'Value(Get_Attribute(ModuleNode, "weight"));
            end if;
            if Get_Attribute(ModuleNode, "value")'Length > 0 then
               TempRecord.Value :=
                 Integer'Value(Get_Attribute(ModuleNode, "value"));
            end if;
            if Get_Attribute(ModuleNode, "maxvalue")'Length > 0 then
               TempRecord.Max_Value :=
                 Integer'Value(Get_Attribute(ModuleNode, "maxvalue"));
            end if;
            if Get_Attribute(ModuleNode, "durability")'Length > 0 then
               TempRecord.Durability :=
                 Integer'Value(Get_Attribute(ModuleNode, "durability"));
            end if;
            if Get_Attribute(ModuleNode, "material")'Length > 0 then
               TempRecord.Repair_Material :=
                 To_Unbounded_String(Get_Attribute(ModuleNode, "material"));
               MaterialExists := False;
               Check_Materials_Loop :
               for Material of Items_Types loop
                  if Material = TempRecord.Repair_Material then
                     MaterialExists := True;
                     exit Check_Materials_Loop;
                  end if;
               end loop Check_Materials_Loop;
               if not MaterialExists then
                  raise Data_Loading_Error
                    with "Can't " & To_Lower(Data_Action'Image(Action)) &
                    " ship module '" & To_String(ModuleIndex) &
                    "', there is no item type '" &
                    Get_Attribute(ModuleNode, "material") & "'.";
               end if;
            end if;
            if Get_Attribute(ModuleNode, "skill")'Length > 0 then
               SkillIndex :=
                 Find_Skill_Index(Get_Attribute(ModuleNode, "skill"));
               if SkillIndex = 0 then
                  raise Data_Loading_Error
                    with "Can't " & To_Lower(Data_Action'Image(Action)) &
                    " ship module '" & To_String(ModuleIndex) &
                    "', there is no skill named '" &
                    Get_Attribute(ModuleNode, "skill") & "'.";
               end if;
               TempRecord.Repair_Skill := SkillIndex;
            end if;
            if Get_Attribute(ModuleNode, "price")'Length > 0 then
               TempRecord.Price :=
                 Integer'Value(Get_Attribute(ModuleNode, "price"));
            end if;
            if Get_Attribute(ModuleNode, "installtime")'Length > 0 then
               TempRecord.Install_Time :=
                 Positive'Value(Get_Attribute(ModuleNode, "installtime"));
            end if;
            if Get_Attribute(ModuleNode, "unique") /= "" then
               TempRecord.Unique := True;
            end if;
            if Get_Attribute(ModuleNode, "size") /= "" then
               TempRecord.Size :=
                 Integer'Value(Get_Attribute(ModuleNode, "size"));
            end if;
            if Get_Attribute(ModuleNode, "maxowners")'Length > 0 then
               TempRecord.Max_Owners :=
                 Integer'Value(Get_Attribute(ModuleNode, "maxowners"));
            end if;
            if Get_Attribute(ModuleNode, "speed")'Length > 0 then
               TempRecord.Speed :=
                 Integer'Value(Get_Attribute(ModuleNode, "speed"));
            end if;
            if Get_Attribute(ModuleNode, "reputation")'Length > 0 then
               TempRecord.Reputation :=
                 Integer'Value(Get_Attribute(ModuleNode, "reputation"));
            end if;
            if Has_Child_Nodes(ModuleNode) then
               TempRecord.Description :=
                 To_Unbounded_String(Node_Value(First_Child(ModuleNode)));
            end if;
            if Action /= UPDATE then
               BaseModules_Container.Include
                 (Modules_List, ModuleIndex, TempRecord);
               Log_Message
                 ("Module added: " & To_String(TempRecord.Name), EVERYTHING);
            else
               Modules_List(ModuleIndex) := TempRecord;
               Log_Message
                 ("Module updated: " & To_String(TempRecord.Name), EVERYTHING);
            end if;
         else
            BaseModules_Container.Exclude(Modules_List, ModuleIndex);
            Log_Message
              ("Module removed: " & To_String(ModuleIndex), EVERYTHING);
         end if;
      end loop Load_Modules_Loop;
   end Load_Ship_Modules;

   function Get_Module_Type(Module_Index: Unbounded_String) return String is
      ModuleTypeName: Unbounded_String :=
        To_Unbounded_String
          (To_Lower(Module_Type'Image(Modules_List(Module_Index).MType)));
   begin
      Replace_Element
        (ModuleTypeName, 1,
         To_Upper(Ada.Strings.Unbounded.Element(ModuleTypeName, 1)));
      Translate(ModuleTypeName, To_Mapping("_", " "));
      return To_String(ModuleTypeName);
   end Get_Module_Type;

end ShipModules;
