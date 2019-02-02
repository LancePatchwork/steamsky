--    Copyright 2016-2019 Bartek thindil Jasicki
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
with Utils; use Utils;
with Log; use Log;
with Crafts; use Crafts;
with Maps; use Maps;
with Factions; use Factions;
with Bases; use Bases;
with ShipModules; use ShipModules;

package body Ships is

   function CreateShip(ProtoIndex: Positive; Name: Unbounded_String;
      X, Y: Integer; Speed: ShipSpeed;
      RandomUpgrades: Boolean := True) return ShipRecord is
      TmpShip: ShipRecord;
      ShipModules: Modules_Container.Vector;
      ShipCrew: Crew_Container.Vector;
      NewName: Unbounded_String;
      HullIndex, Amount: Natural := 0;
      ProtoShip: constant ProtoShipData := ProtoShips_List(ProtoIndex);
      ShipCargo: Inventory_Container.Vector;
   begin
      -- Set ship modules
      declare
         UpgradesAmount, WeightGain: Natural := 0;
         MaxValue, Roll: Positive;
         TempModule: BaseModule_Data;
      begin
         if RandomUpgrades then
            UpgradesAmount := GetRandom(0, Positive(ProtoShip.Modules.Length));
         end if;
         for Module of ProtoShip.Modules loop
            TempModule := Modules_List(Module);
            if UpgradesAmount > 0 then
               WeightGain :=
                 Modules_List(Module).Weight / Modules_List(Module).Durability;
               if WeightGain < 1 then
                  WeightGain := 1;
               end if;
               if GetRandom(1, 100) > 50 then
                  Roll := GetRandom(1, 100);
                  case Roll is
                     when 1 .. 50 => -- Upgrade durability of module
                        MaxValue :=
                          Positive
                            (Float(Modules_List(Module).Durability) * 1.5);
                        TempModule.Durability :=
                          GetRandom(Modules_List(Module).Durability, MaxValue);
                        TempModule.Weight :=
                          TempModule.Weight +
                          (WeightGain *
                           (TempModule.Durability -
                            Modules_List(Module).Durability));
                     when 51 ..
                           75 => -- Upgrade value (depends on module) of module
                        if Modules_List(Module).MType = ENGINE then
                           WeightGain := WeightGain * 10;
                           MaxValue :=
                             Positive(Float(Modules_List(Module).Value) / 2.0);
                           TempModule.Value :=
                             GetRandom(MaxValue, Modules_List(Module).Value);
                           TempModule.Weight :=
                             TempModule.Weight +
                             (WeightGain *
                              (Modules_List(Module).Value - TempModule.Value));
                        end if;
                     when 76 ..
                           100 => -- Upgrade max_value (depends on module) of module
                        case Modules_List(Module).MType is
                           when HULL =>
                              WeightGain := WeightGain * 10;
                           when ENGINE =>
                              WeightGain := 1;
                           when others =>
                              null;
                        end case;
                        if TempModule.MType = ENGINE or
                          TempModule.MType = CABIN or TempModule.MType = GUN or
                          TempModule.MType = BATTERING_RAM or
                          TempModule.MType = HULL or
                          TempModule.MType = HARPOON_GUN then
                           MaxValue :=
                             Positive
                               (Float(Modules_List(Module).MaxValue) * 1.5);
                           TempModule.MaxValue :=
                             GetRandom
                               (Modules_List(Module).MaxValue, MaxValue);
                           TempModule.Weight :=
                             TempModule.Weight +
                             (WeightGain *
                              (TempModule.MaxValue -
                               Modules_List(Module).MaxValue));
                        end if;
                     when others =>
                        null;
                  end case;
                  UpgradesAmount := UpgradesAmount - 1;
               end if;
            end if;
            case TempModule.MType is
               when ENGINE =>
                  ShipModules.Append
                    (New_Item =>
                       (MType => ENGINE, Name => Modules_List(Module).Name,
                        ProtoIndex => Module, Weight => TempModule.Weight,
                        Durability => TempModule.Durability,
                        MaxDurability => TempModule.Durability, Owner => 0,
                        UpgradeProgress => 0, UpgradeAction => NONE,
                        FuelUsage => TempModule.Value,
                        Power => TempModule.MaxValue, Disabled => False));
               when CABIN =>
                  ShipModules.Append
                    (New_Item =>
                       (MType => CABIN, Name => Modules_List(Module).Name,
                        ProtoIndex => Module, Weight => TempModule.Weight,
                        Durability => TempModule.Durability,
                        MaxDurability => TempModule.Durability, Owner => 0,
                        UpgradeProgress => 0, UpgradeAction => NONE,
                        Cleanliness => TempModule.Value,
                        Quality => TempModule.MaxValue));
               when ALCHEMY_LAB .. GREENHOUSE =>
                  ShipModules.Append
                    (New_Item =>
                       (MType => WORKSHOP, Name => Modules_List(Module).Name,
                        ProtoIndex => Module, Weight => TempModule.Weight,
                        Durability => TempModule.Durability,
                        MaxDurability => TempModule.Durability, Owner => 0,
                        UpgradeProgress => 0, UpgradeAction => NONE,
                        CraftingIndex => Null_Unbounded_String,
                        CraftingTime => 0, CraftingAmount => 0));
               when MEDICAL_ROOM =>
                  ShipModules.Append
                    (New_Item =>
                       (MType => MEDICAL_ROOM,
                        Name => Modules_List(Module).Name,
                        ProtoIndex => Module, Weight => TempModule.Weight,
                        Durability => TempModule.Durability,
                        MaxDurability => TempModule.Durability, Owner => 0,
                        UpgradeProgress => 0, UpgradeAction => NONE));
               when COCKPIT =>
                  ShipModules.Append
                    (New_Item =>
                       (MType => COCKPIT, Name => Modules_List(Module).Name,
                        ProtoIndex => Module, Weight => TempModule.Weight,
                        Durability => TempModule.Durability,
                        MaxDurability => TempModule.Durability, Owner => 0,
                        UpgradeProgress => 0, UpgradeAction => NONE));
               when TRAINING_ROOM =>
                  ShipModules.Append
                    (New_Item =>
                       (MType => TRAINING_ROOM,
                        Name => Modules_List(Module).Name,
                        ProtoIndex => Module, Weight => TempModule.Weight,
                        Durability => TempModule.Durability,
                        MaxDurability => TempModule.Durability, Owner => 0,
                        UpgradeProgress => 0, UpgradeAction => NONE,
                        TrainedSkill => 0));
               when TURRET =>
                  ShipModules.Append
                    (New_Item =>
                       (MType => TURRET, Name => Modules_List(Module).Name,
                        ProtoIndex => Module, Weight => TempModule.Weight,
                        Durability => TempModule.Durability,
                        MaxDurability => TempModule.Durability, Owner => 0,
                        UpgradeProgress => 0, UpgradeAction => NONE,
                        GunIndex => 0));
               when others =>
                  ShipModules.Append
                    (New_Item =>
                       (MType => ANY, Name => Modules_List(Module).Name,
                        ProtoIndex => Module, Weight => TempModule.Weight,
                        Durability => TempModule.Durability,
                        MaxDurability => TempModule.Durability, Owner => 0,
                        UpgradeProgress => 0, UpgradeAction => NONE,
                        Data => (TempModule.Value, TempModule.MaxValue, 0)));
            end case;
         end loop;
      end;
      -- Set ship name
      if Name = Null_Unbounded_String then
         NewName := ProtoShip.Name;
      else
         NewName := Name;
      end if;
      -- Set ship crew
      declare
         Gender: Character;
         MemberName: Unbounded_String;
         TmpSkills: Skills_Container.Vector;
         MemberFaction: Unbounded_String;
         TmpAttributes: Attributes_Container.Vector;
         TmpInventory: Inventory_Container.Vector;
         Member: ProtoMobRecord;
      begin
         for ProtoMember of ProtoShip.Crew loop
            if ProtoMember(3) = 0 then
               Amount := ProtoMember(2);
            else
               Amount := GetRandom(ProtoMember(2), ProtoMember(3));
            end if;
            for I in 1 .. Amount loop
               if GetRandom(1, 100) < 99 then
                  MemberFaction := ProtoShip.Owner;
               else
                  MemberFaction := GetRandomFaction;
               end if;
               if not Factions_List(MemberFaction).Flags.Contains
                   (To_Unbounded_String("nogender")) then
                  if GetRandom(1, 100) < 50 then
                     Gender := 'M';
                  else
                     Gender := 'F';
                  end if;
               else
                  Gender := 'M';
               end if;
               MemberName := GenerateMemberName(Gender, MemberFaction);
               Member := ProtoMobs_List.Element(ProtoMember(1));
               for Skill of Member.Skills loop
                  if Skill(3) = 0 then
                     TmpSkills.Append(New_Item => Skill);
                  else
                     TmpSkills.Append
                       (New_Item =>
                          (Skill(1), GetRandom(Skill(2), Skill(3)), 0));
                  end if;
               end loop;
               for Attribute of Member.Attributes loop
                  if Attribute(2) = 0 then
                     TmpAttributes.Append(New_Item => Attribute);
                  else
                     TmpAttributes.Append
                       (New_Item =>
                          (GetRandom(Attribute(1), Attribute(2)), 0));
                  end if;
               end loop;
               for I in Member.Inventory.Iterate loop
                  if Member.Inventory(I)(2) > 0 then
                     Amount :=
                       GetRandom
                         (Member.Inventory(I)(1), Member.Inventory(I)(2));
                  else
                     Amount := Member.Inventory(I)(1);
                  end if;
                  TmpInventory.Append
                    (New_Item =>
                       (ProtoIndex => MobInventory_Container.Key(I),
                        Amount => Amount, Name => Null_Unbounded_String,
                        Durability => 100, Price => 0));
               end loop;
               ShipCrew.Append
                 (New_Item =>
                    (Name => MemberName, Gender => Gender, Health => 100,
                     Tired => 0, Skills => TmpSkills, Hunger => 0, Thirst => 0,
                     Order => Member.Order, PreviousOrder => Rest,
                     OrderTime => 15, Orders => Member.Priorities,
                     Attributes => TmpAttributes, Inventory => TmpInventory,
                     Equipment => Member.Equipment, Payment => (20, 0),
                     ContractLength => -1, Morale => (50, 0), Loyalty => 100,
                     HomeBase => 1, Faction => MemberFaction));
               TmpSkills.Clear;
               TmpAttributes.Clear;
               TmpInventory.Clear;
               for Module of ShipModules loop
                  if Module.MType = CABIN and Module.Owner = 0 then
                     Module.Name :=
                       MemberName & To_Unbounded_String("'s Cabin");
                     Module.Owner := ShipCrew.Last_Index;
                     exit;
                  end if;
               end loop;
               for Module of ShipModules loop
                  if Module.Owner = 0 and
                    ((Modules_List(Module.ProtoIndex).MType = GUN or
                      Modules_List(Module.ProtoIndex).MType = HARPOON_GUN) and
                     Member.Order = Gunner) then
                     Module.Owner := ShipCrew.Last_Index;
                     exit;
                  elsif Module.MType = COCKPIT and Member.Order = Pilot then
                     Module.Owner := ShipCrew.Last_Index;
                     exit;
                  end if;
               end loop;
            end loop;
         end loop;
      end;
      -- Set ship cargo
      for I in ProtoShip.Cargo.Iterate loop
         if ProtoShip.Cargo(I)(2) > 0 then
            Amount := GetRandom(ProtoShip.Cargo(I)(1), ProtoShip.Cargo(I)(2));
         else
            Amount := ProtoShip.Cargo(I)(1);
         end if;
         ShipCargo.Append
           (New_Item =>
              (ProtoIndex => MobInventory_Container.Key(I), Amount => Amount,
               Name => Null_Unbounded_String, Durability => 100, Price => 0));
      end loop;
      TmpShip :=
        (Name => NewName, SkyX => X, SkyY => Y, Speed => Speed,
         Modules => ShipModules, Cargo => ShipCargo, Crew => ShipCrew,
         UpgradeModule => 0, DestinationX => 0, DestinationY => 0,
         RepairModule => 0, Description => ProtoShip.Description,
         HomeBase => 0);
      declare
         GunAssigned: Boolean;
      begin
         Amount := 0;
         for I in TmpShip.Modules.Iterate loop
            if TmpShip.Modules(I).MType = TURRET then
               for J in TmpShip.Modules.Iterate loop
                  if Modules_List(TmpShip.Modules(J).ProtoIndex).MType = GUN or
                    Modules_List(TmpShip.Modules(J).ProtoIndex).MType =
                      HARPOON_GUN then
                     GunAssigned := False;
                     for K in TmpShip.Modules.Iterate loop
                        if TmpShip.Modules(K).MType = TURRET
                          and then TmpShip.Modules(K).GunIndex =
                            Modules_Container.To_Index(J) then
                           GunAssigned := True;
                           exit;
                        end if;
                     end loop;
                     if not GunAssigned then
                        TmpShip.Modules(I).GunIndex :=
                          Modules_Container.To_Index(J);
                     end if;
                  end if;
               end loop;
            elsif Modules_List(TmpShip.Modules(I).ProtoIndex).MType = HULL then
               HullIndex := Modules_Container.To_Index(I);
            end if;
            Amount :=
              Amount + Modules_List(TmpShip.Modules(I).ProtoIndex).Size;
         end loop;
         TmpShip.Modules(HullIndex).Data(1) := Amount;
      end;
      -- Set known crafting recipes
      for Recipe of ProtoShip.KnownRecipes loop
         Known_Recipes.Append(New_Item => Recipe);
      end loop;
      -- Set home base for ship
      if SkyMap(X, Y).BaseIndex > 0 then
         TmpShip.HomeBase := SkyMap(X, Y).BaseIndex;
      else
         declare
            StartX, StartY, EndX, EndY: Integer;
         begin
            StartX := X - 100;
            NormalizeCoord(StartX);
            StartY := Y - 100;
            NormalizeCoord(StartY, False);
            EndX := X + 100;
            NormalizeCoord(EndX);
            EndY := Y + 100;
            NormalizeCoord(EndY, False);
            Bases_Loop :
            for SkyX in StartX .. EndX loop
               for SkyY in StartY .. EndY loop
                  if SkyMap(SkyX, SkyY).BaseIndex > 0 then
                     if SkyBases(SkyMap(SkyX, SkyY).BaseIndex).Owner =
                       ProtoShip.Owner then
                        TmpShip.HomeBase := SkyMap(SkyX, SkyY).BaseIndex;
                        exit Bases_Loop;
                     end if;
                  end if;
               end loop;
            end loop Bases_Loop;
            if TmpShip.HomeBase = 0 then
               for I in SkyBases'Range loop
                  if SkyBases(I).Owner = ProtoShip.Owner then
                     TmpShip.HomeBase := I;
                     exit;
                  end if;
               end loop;
            end if;
         end;
      end if;
      -- Set home base for crew members
      for Member of TmpShip.Crew loop
         if GetRandom(1, 100) < 99 then
            Member.HomeBase := TmpShip.HomeBase;
         else
            Member.HomeBase := GetRandom(SkyBases'First, SkyBases'Last);
         end if;
      end loop;
      return TmpShip;
   end CreateShip;

   procedure LoadShips(Reader: Tree_Reader) is
      NodesList, ChildNodes: Node_List;
      ShipsData: Document;
      TempRecord: ProtoShipData;
      TempModules: Positive_Container.Vector;
      TempCargo: MobInventory_Container.Map;
      TempCrew: Skills_Container.Vector;
      ModuleAmount, DeleteIndex: Positive;
      Index, ShipIndex: Natural;
      Action, SubAction: DataAction;
      ShipNode, ChildNode: Node;
      ItemIndex, RecipeIndex: Unbounded_String;
      TempRecipes: UnboundedString_Container.Vector;
      procedure CountAmmoValue(ItemTypeIndex, Multiple: Positive) is
      begin
         for I in TempRecord.Cargo.Iterate loop
            if Items_List(MobInventory_Container.Key(I)).IType =
              Items_Types(ItemTypeIndex) then
               TempRecord.CombatValue :=
                 TempRecord.CombatValue +
                 (Items_List(MobInventory_Container.Key(I)).Value(1) *
                  Multiple);
            end if;
         end loop;
      end CountAmmoValue;
   begin
      TempRecord :=
        (Name => Null_Unbounded_String, Modules => TempModules,
         Accuracy => (0, 0), CombatAI => NONE, Evasion => (0, 0),
         Loot => (0, 0), Perception => (0, 0), Cargo => TempCargo,
         CombatValue => 1, Crew => TempCrew,
         Description => Null_Unbounded_String,
         Owner => Factions_Container.Key(Factions_List.First),
         Index => Null_Unbounded_String, KnownRecipes => TempRecipes);
      ShipsData := Get_Tree(Reader);
      NodesList :=
        DOM.Core.Documents.Get_Elements_By_Tag_Name(ShipsData, "ship");
      for I in 0 .. Length(NodesList) - 1 loop
         ShipNode := Item(NodesList, I);
         TempRecord.Index :=
           To_Unbounded_String(Get_Attribute(ShipNode, "index"));
         if Get_Attribute(ShipNode, "action")'Length > 0 then
            Action := DataAction'Value(Get_Attribute(ShipNode, "action"));
         else
            Action := ADD;
         end if;
         ShipIndex := 0;
         for J in ProtoShips_List.Iterate loop
            if ProtoShips_List(J).Index = TempRecord.Index then
               ShipIndex := ProtoShips_Container.To_Index(J);
               exit;
            end if;
         end loop;
         if (Action = UPDATE or Action = REMOVE) then
            if ShipIndex = 0 then
               raise Data_Loading_Error
                 with "Can't " & To_Lower(DataAction'Image(Action)) &
                 " ship '" & To_String(TempRecord.Index) &
                 "', there no ship with that index.";
            end if;
         elsif ShipIndex > 0 then
            raise Data_Loading_Error
              with "Can't add ship '" & To_String(TempRecord.Index) &
              "', there is one with that index.";
         end if;
         if Action /= REMOVE then
            if Action = UPDATE then
               TempRecord := ProtoShips_List(ShipIndex);
            end if;
            if Get_Attribute(ShipNode, "name")'Length > 0 then
               TempRecord.Name :=
                 To_Unbounded_String(Get_Attribute(ShipNode, "name"));
            end if;
            ChildNodes :=
              DOM.Core.Elements.Get_Elements_By_Tag_Name(ShipNode, "module");
            for J in 0 .. Length(ChildNodes) - 1 loop
               ChildNode := Item(ChildNodes, J);
               if Get_Attribute(ChildNode, "amount") /= "" then
                  ModuleAmount :=
                    Positive'Value(Get_Attribute(ChildNode, "amount"));
               else
                  ModuleAmount := 1;
               end if;
               Index :=
                 FindProtoModule
                   (To_Unbounded_String(Get_Attribute(ChildNode, "index")));
               if Index = 0 then
                  raise Ships_Invalid_Data
                    with "Invalid module index: |" &
                    Get_Attribute(ChildNode, "index") & "| in " &
                    To_String(TempRecord.Name) & ".";
               end if;
               if Get_Attribute(ChildNode, "action")'Length > 0 then
                  SubAction :=
                    DataAction'Value(Get_Attribute(ChildNode, "action"));
               else
                  SubAction := ADD;
               end if;
               if SubAction = ADD then
                  TempRecord.Modules.Append
                    (New_Item => Index, Count => Count_Type(ModuleAmount));
               else
                  for K in TempRecord.Modules.Iterate loop
                     if TempRecord.Modules(K) = Index then
                        DeleteIndex := Positive_Container.To_Index(K);
                        exit;
                     end if;
                  end loop;
                  TempRecord.Modules.Delete
                    (Index => DeleteIndex, Count => Count_Type(ModuleAmount));
               end if;
            end loop;
            if Get_Attribute(ShipNode, "accuracy") /= "" then
               TempRecord.Accuracy(1) :=
                 Integer'Value(Get_Attribute(ShipNode, "accuracy"));
               TempRecord.Accuracy(2) := 0;
            elsif Get_Attribute(ShipNode, "minaccuracy") /= "" then
               TempRecord.Accuracy(1) :=
                 Integer'Value(Get_Attribute(ShipNode, "minaccuracy"));
               TempRecord.Accuracy(2) :=
                 Integer'Value(Get_Attribute(ShipNode, "maxaccuracy"));
            end if;
            if Get_Attribute(ShipNode, "combatai") /= "" then
               TempRecord.CombatAI :=
                 ShipCombatAi'Value(Get_Attribute(ShipNode, "combatai"));
            end if;
            if Get_Attribute(ShipNode, "evasion") /= "" then
               TempRecord.Evasion(1) :=
                 Integer'Value(Get_Attribute(ShipNode, "evasion"));
               TempRecord.Evasion(2) := 0;
            elsif Get_Attribute(ShipNode, "minevasion") /= "" then
               TempRecord.Evasion(1) :=
                 Integer'Value(Get_Attribute(ShipNode, "minevasion"));
               TempRecord.Evasion(2) :=
                 Integer'Value(Get_Attribute(ShipNode, "maxevasion"));
            end if;
            if Get_Attribute(ShipNode, "loot") /= "" then
               TempRecord.Loot(1) :=
                 Integer'Value(Get_Attribute(ShipNode, "loot"));
               TempRecord.Loot(2) := 0;
            elsif Get_Attribute(ShipNode, "minloot") /= "" then
               TempRecord.Loot(1) :=
                 Integer'Value(Get_Attribute(ShipNode, "minloot"));
               TempRecord.Loot(2) :=
                 Integer'Value(Get_Attribute(ShipNode, "maxloot"));
            end if;
            if Get_Attribute(ShipNode, "perception") /= "" then
               TempRecord.Perception(1) :=
                 Integer'Value(Get_Attribute(ShipNode, "perception"));
               TempRecord.Perception(2) := 0;
            elsif Get_Attribute(ShipNode, "minperception") /= "" then
               TempRecord.Perception(1) :=
                 Integer'Value(Get_Attribute(ShipNode, "minperception"));
               TempRecord.Perception(2) :=
                 Integer'Value(Get_Attribute(ShipNode, "maxperception"));
            end if;
            ChildNodes :=
              DOM.Core.Elements.Get_Elements_By_Tag_Name(ShipNode, "cargo");
            for J in 0 .. Length(ChildNodes) - 1 loop
               ChildNode := Item(ChildNodes, J);
               ItemIndex :=
                 To_Unbounded_String(Get_Attribute(ChildNode, "index"));
               if not Objects_Container.Contains(Items_List, ItemIndex) then
                  raise Ships_Invalid_Data
                    with "Invalid item index: |" &
                    Get_Attribute(ChildNode, "index") & "| in " &
                    To_String(TempRecord.Name) & ".";
               end if;
               if Get_Attribute(ChildNode, "action")'Length > 0 then
                  SubAction :=
                    DataAction'Value(Get_Attribute(ChildNode, "action"));
               else
                  SubAction := ADD;
               end if;
               case SubAction is
                  when ADD =>
                     if Get_Attribute(ChildNode, "amount") /= "" then
                        MobInventory_Container.Include
                          (TempRecord.Cargo, ItemIndex,
                           (Integer'Value(Get_Attribute(ChildNode, "amount")),
                            0));
                     elsif Get_Attribute(ChildNode, "minamount") /= "" then
                        MobInventory_Container.Include
                          (TempRecord.Cargo, ItemIndex,
                           (Integer'Value
                              (Get_Attribute(ChildNode, "minamount")),
                            Integer'Value
                              (Get_Attribute(ChildNode, "maxamount"))));
                     end if;
                  when UPDATE =>
                     if Get_Attribute(ChildNode, "amount") /= "" then
                        TempRecord.Cargo(ItemIndex)(1) :=
                          Integer'Value(Get_Attribute(ChildNode, "amount"));
                        TempRecord.Cargo(ItemIndex)(2) := 0;
                     elsif Get_Attribute(ChildNode, "minamount") /= "" then
                        TempRecord.Cargo(ItemIndex)(1) :=
                          Integer'Value(Get_Attribute(ChildNode, "minamount"));
                        TempRecord.Cargo(ItemIndex)(2) :=
                          Integer'Value(Get_Attribute(ChildNode, "maxamount"));
                     end if;
                  when REMOVE =>
                     MobInventory_Container.Exclude
                       (TempRecord.Cargo, ItemIndex);
               end case;
            end loop;
            if Get_Attribute(ShipNode, "owner") /= "" then
               TempRecord.Owner :=
                 To_Unbounded_String(Get_Attribute(ShipNode, "owner"));
            end if;
            ChildNodes :=
              DOM.Core.Elements.Get_Elements_By_Tag_Name(ShipNode, "recipe");
            for J in 0 .. Length(ChildNodes) - 1 loop
               RecipeIndex :=
                 To_Unbounded_String
                   (Get_Attribute(Item(ChildNodes, J), "index"));
               if not Recipes_Container.Contains
                   (Recipes_List, RecipeIndex) then
                  raise Ships_Invalid_Data
                    with "Invalid recipe index: |" &
                    Get_Attribute(Item(ChildNodes, J), "index") & "| in " &
                    To_String(TempRecord.Name) & ".";
               end if;
               if Get_Attribute(ChildNode, "action")'Length > 0 then
                  SubAction :=
                    DataAction'Value(Get_Attribute(ChildNode, "action"));
               else
                  SubAction := ADD;
               end if;
               if SubAction = ADD then
                  TempRecord.KnownRecipes.Append(New_Item => RecipeIndex);
               else
                  for K in TempRecord.KnownRecipes.Iterate loop
                     if TempRecord.KnownRecipes(K) = RecipeIndex then
                        DeleteIndex := UnboundedString_Container.To_Index(K);
                        exit;
                     end if;
                  end loop;
                  TempRecord.KnownRecipes.Delete(Index => DeleteIndex);
               end if;
            end loop;
            ChildNodes :=
              DOM.Core.Elements.Get_Elements_By_Tag_Name(ShipNode, "member");
            for J in 0 .. Length(ChildNodes) - 1 loop
               ChildNode := Item(ChildNodes, J);
               Index :=
                 FindProtoMob
                   (To_Unbounded_String(Get_Attribute(ChildNode, "index")));
               if Index = 0 then
                  raise Ships_Invalid_Data
                    with "Invalid mob index: |" &
                    Get_Attribute(ChildNode, "index") & "| in " &
                    To_String(TempRecord.Name) & ".";
               end if;
               if Get_Attribute(ChildNode, "action")'Length > 0 then
                  SubAction :=
                    DataAction'Value(Get_Attribute(ChildNode, "action"));
               else
                  SubAction := ADD;
               end if;
               case SubAction is
                  when ADD =>
                     if Get_Attribute(ChildNode, "amount") /= "" then
                        TempRecord.Crew.Append
                          (New_Item =>
                             (Index,
                              Integer'Value
                                (Get_Attribute(ChildNode, "amount")),
                              0));
                     elsif Get_Attribute(ChildNode, "minamount") /= "" then
                        TempRecord.Crew.Append
                          (New_Item =>
                             (Index,
                              Integer'Value
                                (Get_Attribute(ChildNode, "minamount")),
                              Integer'Value
                                (Get_Attribute(ChildNode, "maxamount"))));
                     else
                        TempRecord.Crew.Append(New_Item => (Index, 1, 0));
                     end if;
                  when UPDATE =>
                     for Member of TempRecord.Crew loop
                        if Member(1) = Index then
                           if Get_Attribute(ChildNode, "amount") /= "" then
                              Member(2) :=
                                Integer'Value
                                  (Get_Attribute(ChildNode, "amount"));
                              Member(3) := 0;
                           elsif Get_Attribute(ChildNode, "minamount") /=
                             "" then
                              Member(2) :=
                                Integer'Value
                                  (Get_Attribute(ChildNode, "minamount"));
                              Member(3) :=
                                Integer'Value
                                  (Get_Attribute(ChildNode, "maxamount"));
                           else
                              Member(2) := 1;
                              Member(3) := 0;
                           end if;
                           exit;
                        end if;
                     end loop;
                  when REMOVE =>
                     for K in TempRecord.Crew.Iterate loop
                        if TempRecord.Crew(K)(1) = Index then
                           DeleteIndex := Skills_Container.To_Index(K);
                           exit;
                        end if;
                     end loop;
                     TempRecord.Crew.Delete(Index => DeleteIndex);
               end case;
            end loop;
            ChildNodes :=
              DOM.Core.Elements.Get_Elements_By_Tag_Name
                (ShipNode, "description");
            if Length(ChildNodes) > 0 then
               TempRecord.Description :=
                 To_Unbounded_String
                   (Node_Value(First_Child(Item(ChildNodes, 0))));
            end if;
            for ModuleIndex of TempRecord.Modules loop
               case Modules_List(ModuleIndex).MType is
                  when HULL | GUN | BATTERING_RAM =>
                     TempRecord.CombatValue :=
                       TempRecord.CombatValue +
                       Modules_List(ModuleIndex).Durability +
                       (Modules_List(ModuleIndex).MaxValue * 10);
                     if Modules_List(ModuleIndex).MType = GUN then
                        CountAmmoValue(Modules_List(ModuleIndex).Value, 10);
                     end if;
                  when ARMOR =>
                     TempRecord.CombatValue :=
                       TempRecord.CombatValue +
                       Modules_List(ModuleIndex).Durability;
                  when HARPOON_GUN =>
                     TempRecord.CombatValue :=
                       TempRecord.CombatValue +
                       Modules_List(ModuleIndex).Durability +
                       (Modules_List(ModuleIndex).MaxValue * 5);
                     CountAmmoValue(Modules_List(ModuleIndex).Value, 5);
                  when others =>
                     null;
               end case;
            end loop;
            TempRecord.CombatValue := TempRecord.CombatValue - 1;
            if Action /= UPDATE then
               ProtoShips_List.Append(New_Item => TempRecord);
               LogMessage
                 ("Ship added: " & To_String(TempRecord.Name), Everything);
            else
               ProtoShips_List(ShipIndex) := TempRecord;
            end if;
         else
            ProtoShips_List.Delete(Index => ShipIndex);
            LogMessage
              ("Ship removed: " & To_String(TempRecord.Index), Everything);
         end if;
         TempRecord :=
           (Name => Null_Unbounded_String, Modules => TempModules,
            Accuracy => (0, 0), CombatAI => NONE, Evasion => (0, 0),
            Loot => (0, 0), Perception => (0, 0), Cargo => TempCargo,
            CombatValue => 1, Crew => TempCrew,
            Description => Null_Unbounded_String,
            Owner => Factions_Container.Key(Factions_List.First),
            Index => Null_Unbounded_String, KnownRecipes => TempRecipes);
      end loop;
   end LoadShips;

   function CountShipWeight(Ship: ShipRecord) return Positive is
      Weight: Natural := 0;
      CargoWeight: Positive;
   begin
      for Module of Ship.Modules loop
         Weight := Weight + Module.Weight;
      end loop;
      for Item of Ship.Cargo loop
         CargoWeight := Item.Amount * Items_List(Item.ProtoIndex).Weight;
         Weight := Weight + CargoWeight;
      end loop;
      return Weight;
   end CountShipWeight;

   function GenerateShipName
     (Owner: Unbounded_String)
     return Unbounded_String is -- based on name generator from libtcod
      NewName: Unbounded_String := Null_Unbounded_String;
   begin
      for Faction of Factions_List loop
         if To_Lower(To_String(Faction.Name)) = To_Lower(To_String(Owner)) then
            if Faction.NamesType = ROBOTIC then
               NewName := GenerateRoboticName;
            else
               NewName :=
                 ShipSyllablesStart
                   (GetRandom
                      (ShipSyllablesStart.First_Index,
                       ShipSyllablesStart.Last_Index));
               if GetRandom(1, 100) < 51 then
                  Append
                    (NewName,
                     ShipSyllablesMiddle
                       (GetRandom
                          (ShipSyllablesMiddle.First_Index,
                           ShipSyllablesMiddle.Last_Index)));
               end if;
               Append
                 (NewName,
                  ShipSyllablesEnd
                    (GetRandom
                       (ShipSyllablesEnd.First_Index,
                        ShipSyllablesEnd.Last_Index)));
            end if;
            exit;
         end if;
      end loop;
      return NewName;
   end GenerateShipName;

   function CountCombatValue return Natural is
      CombatValue: Natural := 0;
      procedure CountAmmoValue(ItemTypeIndex, Multiple: Positive) is
      begin
         for Item of PlayerShip.Cargo loop
            if Items_List(Item.ProtoIndex).IType =
              Items_Types(ItemTypeIndex) then
               CombatValue :=
                 CombatValue +
                 (Items_List(Item.ProtoIndex).Value(1) * Multiple);
            end if;
         end loop;
      end CountAmmoValue;
   begin
      for Module of PlayerShip.Modules loop
         case Modules_List(Module.ProtoIndex).MType is
            when HULL | GUN | BATTERING_RAM =>
               CombatValue :=
                 CombatValue + Module.MaxDurability + (Module.Data(2) * 10);
               if Modules_List(Module.ProtoIndex).MType = GUN then
                  CountAmmoValue(Modules_List(Module.ProtoIndex).Value, 10);
               end if;
            when ARMOR =>
               CombatValue := CombatValue + Module.MaxDurability;
            when HARPOON_GUN =>
               CombatValue :=
                 CombatValue + Module.MaxDurability + (Module.Data(2) * 5);
               CountAmmoValue(Modules_List(Module.ProtoIndex).Value, 5);
            when others =>
               null;
         end case;
      end loop;
      return CombatValue;
   end CountCombatValue;

end Ships;
