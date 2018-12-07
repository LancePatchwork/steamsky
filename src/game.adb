--    Copyright 2016-2018 Bartek thindil Jasicki
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

with Ada.Directories; use Ada.Directories;
with Ada.Exceptions; use Ada.Exceptions;
with DOM.Core; use DOM.Core;
with DOM.Core.Nodes; use DOM.Core.Nodes;
with DOM.Core.Elements; use DOM.Core.Elements;
with DOM.Core.Documents; use DOM.Core.Documents;
with DOM.Readers; use DOM.Readers;
with Input_Sources.File; use Input_Sources.File;
with Bases; use Bases;
with Bases.Ship; use Bases.Ship;
with Bases.Cargo; use Bases.Cargo;
with Maps; use Maps;
with Ships; use Ships;
with Ships.Upgrade; use Ships.Upgrade;
with Ships.Repairs;
with Ships.Crew; use Ships.Crew;
with Crew; use Crew;
with Messages; use Messages;
with Crafts; use Crafts;
with Items; use Items;
with Events; use Events;
with ShipModules; use ShipModules;
with Config; use Config;
with Statistics; use Statistics;
with Missions; use Missions;
with Utils; use Utils;
with Goals; use Goals;
with Game.SaveLoad; use Game.SaveLoad;
with Mobs; use Mobs;
with Factions; use Factions;
with Log; use Log;
with Help; use Help;
with Stories; use Stories;
with Careers; use Careers;

package body Game is

   procedure NewGame(CharName, ShipName: Unbounded_String; Gender: Character;
      FactionIndex, CareerIndex: Positive; BaseTypeIndex: Natural) is
      PosX, PosY, RandomBase, ShipIndex, Amount, FactionRoll, BaseOwner,
      PlayerIndex2, PlayerMorale: Positive;
      ValidLocation: Boolean;
      TempX, TempY, BaseReputation: Integer;
      TmpRecruits: Recruit_Container.Vector;
      TmpMissions: Mission_Container.Vector;
      CabinAssigned: Boolean := False;
      BasePopulation, MaxSpawnRoll: Natural;
      TmpCargo: BaseCargo_Container.Vector;
      TmpInventory: Inventory_Container.Vector;
      BaseSize: Bases_Size;
   begin
      -- Save new game configuration
      NewGameSettings :=
        (PlayerName => CharName, PlayerGender => Gender, ShipName => ShipName,
         PlayerFaction => Factions_List(FactionIndex).Index,
         PlayerCareer =>
           Factions_List(FactionIndex).Careers(CareerIndex).Index,
         StartingBase =>
           To_Unbounded_String
             (Bases_Types'Image(Bases_Types'Val(BaseTypeIndex))));
      SaveConfig;
      -- Set game statistics
      ClearGameStats;
      -- Set Game time
      GameDate :=
        (Year => 1600, Month => 3, Day => 1, Hour => 8, Minutes => 0);
      -- Generate world
      SkyMap :=
        (others =>
           (others =>
              (BaseIndex => 0, Visited => False, EventIndex => 0,
               MissionIndex => 0)));
      MaxSpawnRoll := 0;
      for Faction of Factions_List loop
         MaxSpawnRoll := MaxSpawnRoll + Faction.SpawnChance;
      end loop;
      for I in SkyBases'Range loop
         loop
            ValidLocation := True;
            PosX := GetRandom(1, 1024);
            PosY := GetRandom(1, 1024);
            for J in -5 .. 5 loop
               TempX := Integer(PosX) + J;
               NormalizeCoord(TempX);
               for K in -5 .. 5 loop
                  TempY := Integer(PosY) + K;
                  NormalizeCoord(TempY, False);
                  if SkyMap(TempX, TempY).BaseIndex > 0 then
                     ValidLocation := False;
                     exit;
                  end if;
               end loop;
               if not ValidLocation then
                  exit;
               end if;
            end loop;
            if SkyMap(Integer(PosX), Integer(PosY)).BaseIndex > 0 then
               ValidLocation := False;
            end if;
            exit when ValidLocation;
         end loop;
         SkyMap(Integer(PosX), Integer(PosY)) :=
           (BaseIndex => I, Visited => False, EventIndex => 0,
            MissionIndex => 0);
         FactionRoll := GetRandom(1, MaxSpawnRoll);
         for J in Factions_List.Iterate loop
            if FactionRoll > Factions_List(J).SpawnChance then
               FactionRoll := FactionRoll - Factions_List(J).SpawnChance;
            else
               BaseOwner := Factions_Container.To_Index(J);
               if Factions_List(J).Population(2) = 0 then
                  BasePopulation := Factions_List(J).Population(1);
               else
                  BasePopulation :=
                    GetRandom
                      (Factions_List(J).Population(1),
                       Factions_List(J).Population(2));
               end if;
               BaseReputation :=
                 GetReputation
                   (Factions_List(FactionIndex).Index, Factions_List(J).Index);
               exit;
            end if;
         end loop;
         if BasePopulation = 0 then
            BaseSize := Bases_Size'Val(GetRandom(0, 2));
         elsif BasePopulation < 150 then
            BaseSize := Small;
         elsif BasePopulation < 300 then
            BaseSize := Medium;
         else
            BaseSize := Big;
         end if;
         SkyBases(I) :=
           (Name => GenerateBaseName(BaseOwner), Visited => (0, 0, 0, 0, 0),
            SkyX => Integer(PosX), SkyY => Integer(PosY),
            BaseType => Bases_Types'Val(GetRandom(0, 4)),
            Population => BasePopulation, RecruitDate => (0, 0, 0, 0, 0),
            Recruits => TmpRecruits, Known => False, AskedForBases => False,
            AskedForEvents => (0, 0, 0, 0, 0),
            Reputation => (BaseReputation, 0), MissionsDate => (0, 0, 0, 0, 0),
            Missions => TmpMissions, Owner => BaseOwner, Cargo => TmpCargo,
            Size => BaseSize);
      end loop;
      -- Place player ship in random large base
      declare
         BaseType: constant Bases_Types := Bases_Types'Val(BaseTypeIndex);
      begin
         loop
            RandomBase := GetRandom(1, 1024);
            if BaseType = ANY then
               exit when SkyBases(RandomBase).Population > 299 and
                 SkyBases(RandomBase).Owner = FactionIndex;
            else
               exit when SkyBases(RandomBase).Population > 299 and
                 SkyBases(RandomBase).Owner = FactionIndex and
                 SkyBases(RandomBase).BaseType = BaseType;
            end if;
         end loop;
      end;
      -- Create player ship
      for I in ProtoShips_List.Iterate loop
         if ProtoShips_List(I).Index =
           Factions_List(FactionIndex).Careers(CareerIndex).ShipIndex then
            ShipIndex := ProtoShips_Container.To_Index(I);
            exit;
         end if;
      end loop;
      PlayerShip :=
        CreateShip
          (ShipIndex, ShipName, SkyBases(Integer(RandomBase)).SkyX,
           SkyBases(Integer(RandomBase)).SkyY, DOCKED, False);
      -- Add player to ship
      PlayerIndex2 :=
        FindProtoMob
          (Factions_List(FactionIndex).Careers(CareerIndex).PlayerIndex);
      for Item of ProtoMobs_List(PlayerIndex2).Inventory loop
         if Item(3) > 0 then
            Amount := GetRandom(Item(2), Item(3));
         else
            Amount := Item(2);
         end if;
         TmpInventory.Append
           (New_Item =>
              (ProtoIndex => Item(1), Amount => Amount,
               Name => Null_Unbounded_String, Durability => 100));
      end loop;
      if Factions_List(FactionIndex).Flags.Contains
          (To_Unbounded_String("nomorale")) then
         PlayerMorale := 50;
      else
         PlayerMorale := 100;
      end if;
      PlayerShip.Crew.Prepend
        (New_Item =>
           (Name => CharName, Gender => Gender, Health => 100, Tired => 0,
            Skills => ProtoMobs_List(PlayerIndex2).Skills, Hunger => 0,
            Thirst => 0, Order => ProtoMobs_List(PlayerIndex2).Order,
            PreviousOrder => Rest, OrderTime => 15,
            Orders => ProtoMobs_List(PlayerIndex2).Priorities,
            Attributes => ProtoMobs_List(PlayerIndex2).Attributes,
            Inventory => TmpInventory,
            Equipment => ProtoMobs_List(PlayerIndex2).Equipment,
            Payment => (others => 0), ContractLength => -1,
            Morale => (PlayerMorale, 0), Loyalty => 100,
            HomeBase => RandomBase, Faction => FactionIndex));
      for Module of PlayerShip.Modules loop
         if Module.Owner > 0 then
            Module.Owner := Module.Owner + 1;
         end if;
         if Modules_List(Module.ProtoIndex).MType = CABIN and
           Module.Owner = 0 and not CabinAssigned then
            Module.Name := CharName & To_Unbounded_String("'s Cabin");
            Module.Owner := 1;
            CabinAssigned := True;
         end if;
      end loop;
      -- Set current map field/sky base info
      SkyBases(Integer(RandomBase)).Visited := GameDate;
      SkyBases(Integer(RandomBase)).Known := True;
      SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).Visited := True;
      GenerateRecruits;
      GenerateMissions;
      GenerateCargo;
      -- Set player goal if not set yet
      if CurrentGoal.GType = RANDOM then
         CurrentGoal :=
           Goals_List
             (GetRandom(Goals_List.First_Index, Goals_List.Last_Index));
      end if;
      -- Set name of savegame
      GenerateSaveName;
      -- Set player career
      for I in Careers_List.Iterate loop
         if Careers_List(I).Index =
           Factions_List(FactionIndex).Careers(CareerIndex).Index then
            PlayerCareer := Careers.Careers_Container.To_Index(I);
            exit;
         end if;
      end loop;
      -- Add welcoming message
      AddMessage
        ("Welcome to Steam Sky. If it is your first game, please consider read help (keyboard shortcut F1 or from Menu).",
         OtherMessage);
   end NewGame;

   procedure UpdateGame(Minutes: Positive) is
      AddedHours, AddedMinutes: Natural;
      BaseIndex: constant Natural :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex;
      TiredPoints: Natural := 0;
      NeedCleaning: Boolean := False;
   begin
      for I in 1 .. Minutes loop
         if ((GameDate.Minutes + I) rem 15) = 0 then
            TiredPoints := TiredPoints + 1;
         end if;
      end loop;
      -- Update game time
      AddedMinutes := Minutes rem 60;
      AddedHours := Minutes / 60;
      GameDate.Minutes := GameDate.Minutes + AddedMinutes;
      if GameDate.Minutes > 59 then
         GameDate.Minutes := GameDate.Minutes - 60;
         GameDate.Hour := GameDate.Hour + 1;
      end if;
      GameDate.Hour := GameDate.Hour + AddedHours;
      if GameDate.Hour > 23 then
         GameDate.Hour := GameDate.Hour - 24;
         GameDate.Day := GameDate.Day + 1;
         for Module of PlayerShip.Modules loop
            if Modules_List(Module.ProtoIndex).MType = CABIN and
              Module.Data(1) > 0 then
               Module.Data(1) := Module.Data(1) - 1;
               NeedCleaning := True;
            end if;
         end loop;
         if NeedCleaning then
            UpdateOrders(PlayerShip);
         end if;
         if PlayerShip.Speed = DOCKED then
            PayForDock;
         end if;
         DailyPayment;
      end if;
      if GameDate.Day > 30 then
         GameDate.Day := 1;
         GameDate.Month := GameDate.Month + 1;
      end if;
      if GameDate.Month > 12 then
         GameDate.Month := 1;
         GameDate.Year := GameDate.Year + 1;
      end if;
      -- Update crew
      UpdateCrew(Minutes, TiredPoints);
      -- Repair ship (if needed)
      Ships.Repairs.RepairShip(Minutes);
      -- Craft items
      Manufacturing(Minutes);
      -- Upgrade ship module
      UpgradeShip(Minutes);
      -- Update base
      if BaseIndex > 0 then
         if SkyBases(BaseIndex).Visited.Year = 0 then
            GameStats.BasesVisited := GameStats.BasesVisited + 1;
            GameStats.Points := GameStats.Points + 1;
            UpdateGoal(VISIT, Factions_List(SkyBases(BaseIndex).Owner).Index);
         end if;
         SkyBases(BaseIndex).Visited := GameDate;
         if not SkyBases(BaseIndex).Known then
            SkyBases(BaseIndex).Known := True;
            AddMessage
              ("You discovered base " & To_String(SkyBases(BaseIndex).Name) &
               ".",
               OtherMessage);
         end if;
         UpdatePopulation;
         GenerateRecruits;
         GenerateMissions;
         GenerateCargo;
         UpdatePrices;
         UpdateOrders(PlayerShip);
      end if;
      -- Update map cell
      if SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).Visited = False then
         GameStats.MapVisited := GameStats.MapVisited + 1;
         GameStats.Points := GameStats.Points + 1;
         UpdateGoal(DISCOVER, Null_Unbounded_String);
         SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).Visited := True;
      end if;
      -- Update events
      UpdateEvents(Minutes);
      -- Update accepted missions
      UpdateMissions(Minutes);
   end UpdateGame;

   procedure LoadData(Reader: Tree_Reader) is
      GameData: Document;
      NodesList: Node_List;
      DeleteIndex: Natural;
      TmpSkill: Skill_Record;
      NodeName: Unbounded_String;
      DataNode: Node;
      function FindAttributeIndex
        (AttributeName: Unbounded_String) return Natural is
      begin
         for J in
           Attributes_List.First_Index .. Attributes_List.Last_Index loop
            if Attributes_List(J).Name = AttributeName then
               return J;
            end if;
         end loop;
         return 0;
      end FindAttributeIndex;
   begin
      GameData := Get_Tree(Reader);
      NodesList := Child_Nodes(First_Child(GameData));
      for I in 0 .. Length(NodesList) - 1 loop
         DataNode := Item(NodesList, I);
         NodeName := To_Unbounded_String(Node_Name(DataNode));
         if To_String(NodeName) = "basessyllablepre" then
            BaseSyllablesPre.Append
              (New_Item =>
                 To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "basessyllablestart" then
            BaseSyllablesStart.Append
              (New_Item =>
                 To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "basessyllableend" then
            BaseSyllablesEnd.Append
              (New_Item =>
                 To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "basessyllablepost" then
            BaseSyllablesPost.Append
              (New_Item =>
                 To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "malessyllablestart" then
            MaleSyllablesStart.Append
              (New_Item =>
                 To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "malessyllablemiddle" then
            MaleSyllablesMiddle.Append
              (New_Item =>
                 To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "malessyllableend" then
            MaleSyllablesEnd.Append
              (New_Item =>
                 To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "malesvocal" then
            MaleVocals.Append
              (New_Item =>
                 To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "malesconsonant" then
            MaleConsonants.Append
              (New_Item =>
                 To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "femalessyllablestart" then
            FemaleSyllablesStart.Append
              (New_Item =>
                 To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "femalessyllablemiddle" then
            FemaleSyllablesMiddle.Append
              (New_Item =>
                 To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "femalessyllableend" then
            FemaleSyllablesEnd.Append
              (New_Item =>
                 To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "femalesvocal" then
            FemaleVocals.Append
              (New_Item =>
                 To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "shipssyllablestart" then
            ShipSyllablesStart.Append
              (New_Item =>
                 To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "shipssyllablemiddle" then
            ShipSyllablesMiddle.Append
              (New_Item =>
                 To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "shipssyllableend" then
            ShipSyllablesEnd.Append
              (New_Item =>
                 To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "itemtype" then
            Items_Types.Append
              (New_Item =>
                 To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "repairtools" then
            RepairTools :=
              To_Unbounded_String(Get_Attribute(DataNode, "value"));
         elsif To_String(NodeName) = "cleaningtools" then
            CleaningTools :=
              To_Unbounded_String(Get_Attribute(DataNode, "value"));
         elsif To_String(NodeName) = "alchemytools" then
            AlchemyTools :=
              To_Unbounded_String(Get_Attribute(DataNode, "value"));
         elsif To_String(NodeName) = "corpseindex" then
            CorpseIndex :=
              To_Unbounded_String(Get_Attribute(DataNode, "value"));
         elsif To_String(NodeName) = "missionitemstype" then
            MissionItemsType :=
              To_Unbounded_String(Get_Attribute(DataNode, "value"));
         elsif To_String(NodeName) = "fueltype" then
            FuelType := To_Unbounded_String(Get_Attribute(DataNode, "value"));
         elsif To_String(NodeName) = "moneyindex" then
            MoneyIndex :=
              To_Unbounded_String(Get_Attribute(DataNode, "value"));
         elsif To_String(NodeName) = "tradersname" then
            TradersName :=
              To_Unbounded_String(Get_Attribute(DataNode, "value"));
         elsif To_String(NodeName) = "attribute" then
            Attributes_List.Append
              (New_Item =>
                 (Name => To_Unbounded_String(Get_Attribute(DataNode, "name")),
                  Description =>
                    To_Unbounded_String(Node_Value(First_Child(DataNode)))));
         elsif To_String(NodeName) = "skill" then
            TmpSkill :=
              (To_Unbounded_String(Get_Attribute(DataNode, "name")), 1,
               To_Unbounded_String(Node_Value(First_Child(DataNode))),
               Null_Unbounded_String);
            TmpSkill.Attribute :=
              FindAttributeIndex
                (To_Unbounded_String(Get_Attribute(DataNode, "attribute")));
            if Get_Attribute(DataNode, "tool") /= "" then
               TmpSkill.Tool :=
                 To_Unbounded_String(Get_Attribute(DataNode, "tool"));
            end if;
            Skills_List.Append(New_Item => TmpSkill);
         elsif To_String(NodeName) = "conditionname" then
            ConditionIndex :=
              FindAttributeIndex
                (To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "strengthname" then
            StrengthIndex :=
              FindAttributeIndex
                (To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "pilotingskill" then
            PilotingSkill :=
              FindSkillIndex
                (To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "engineeringskill" then
            EngineeringSkill :=
              FindSkillIndex
                (To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "gunneryskill" then
            GunnerySkill :=
              FindSkillIndex
                (To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "talkingskill" then
            TalkingSkill :=
              FindSkillIndex
                (To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "perceptionskill" then
            PerceptionSkill :=
              FindSkillIndex
                (To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "headarmor" then
            HeadArmor := To_Unbounded_String(Get_Attribute(DataNode, "value"));
         elsif To_String(NodeName) = "chestarmor" then
            ChestArmor :=
              To_Unbounded_String(Get_Attribute(DataNode, "value"));
         elsif To_String(NodeName) = "armsarmor" then
            ArmsArmor := To_Unbounded_String(Get_Attribute(DataNode, "value"));
         elsif To_String(NodeName) = "legsarmor" then
            LegsArmor := To_Unbounded_String(Get_Attribute(DataNode, "value"));
         elsif To_String(NodeName) = "shieldtype" then
            ShieldType :=
              To_Unbounded_String(Get_Attribute(DataNode, "value"));
         elsif To_String(NodeName) = "weapontype" then
            WeaponType :=
              To_Unbounded_String(Get_Attribute(DataNode, "value"));
         elsif To_String(NodeName) = "dodgeskill" then
            DodgeSkill :=
              FindSkillIndex
                (To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "unarmedskill" then
            UnarmedSkill :=
              FindSkillIndex
                (To_Unbounded_String(Get_Attribute(DataNode, "value")));
         elsif To_String(NodeName) = "remove" then
            if Get_Attribute(DataNode, "name") = "skill" then
               DeleteIndex :=
                 FindSkillIndex
                   (To_Unbounded_String(Get_Attribute(DataNode, "value")));
               if DeleteIndex > 0 then
                  Skills_List.Delete(Index => DeleteIndex);
               end if;
            elsif Get_Attribute(DataNode, "name") = "attribute" then
               DeleteIndex :=
                 FindAttributeIndex
                   (To_Unbounded_String(Get_Attribute(DataNode, "value")));
               if DeleteIndex > 0 then
                  Attributes_List.Delete(Index => DeleteIndex);
               end if;
            elsif Get_Attribute(DataNode, "name") = "itemtype" then
               DeleteIndex := 0;
               for J in Items_Types.First_Index .. Items_Types.Last_Index loop
                  if Items_Types(J) =
                    To_Unbounded_String(Get_Attribute(DataNode, "value")) then
                     DeleteIndex := J;
                     exit;
                  end if;
               end loop;
               if DeleteIndex > 0 then
                  Items_Types.Delete(Index => DeleteIndex);
               end if;
            end if;
         end if;
      end loop;
   end LoadData;

   procedure EndGame(Save: Boolean) is
   begin
      if Save then
         SaveGame;
      else
         if Exists(To_String(SaveName)) then
            Delete_File(To_String(SaveName));
         end if;
      end if;
      ClearMessages;
      Events_List.Clear;
      ClearGameStats;
      Known_Recipes.Clear;
      ClearCurrentGoal;
      AcceptedMissions.Clear;
      SaveConfig;
   end EndGame;

   function FindSkillIndex(SkillName: Unbounded_String) return Natural is
   begin
      for I in Skills_List.Iterate loop
         if Skills_List(I).Name = SkillName then
            return SkillsData_Container.To_Index(I);
         end if;
      end loop;
      return 0;
   end FindSkillIndex;

   function LoadGameData return String is
      type DataType_Record is record
         Name: Unbounded_String;
         FileName: Unbounded_String;
      end record;
      DataTypes: constant array(Positive range <>) of DataType_Record :=
        ((To_Unbounded_String("data"), To_Unbounded_String("game.dat")),
         (To_Unbounded_String("help"), To_Unbounded_String("help.dat")),
         (To_Unbounded_String("items"), To_Unbounded_String("items.dat")),
         (To_Unbounded_String("modules"),
          To_Unbounded_String("shipmodules.dat")),
         (To_Unbounded_String("recipes"), To_Unbounded_String("recipes.dat")),
         (To_Unbounded_String("mobiles"), To_Unbounded_String("mobs.dat")),
         (To_Unbounded_String("careers"), To_Unbounded_String("careers.dat")),
         (To_Unbounded_String("factions"),
          To_Unbounded_String("factions.dat")),
         (To_Unbounded_String("ships"), To_Unbounded_String("ships.dat")),
         (To_Unbounded_String("goals"), To_Unbounded_String("goals.dat")),
         (To_Unbounded_String("stories"), To_Unbounded_String("stories.dat")));
      Directories: Search_Type;
      FoundDirectory: Directory_Entry_Type;
      procedure LoadSelectedData(DataName, FileName: String) is
         Files: Search_Type;
         FoundFile: Directory_Entry_Type;
         DataFile: File_Input;
         Reader: Tree_Reader;
         LocalFileName: Unbounded_String;
         procedure LoadDataFile(LocalDataName: String) is
            DataType: Unbounded_String;
         begin
            Parse(Reader, DataFile);
            DataType :=
              To_Unbounded_String(Node_Name(Get_Element(Get_Tree(Reader))));
            if DataType = To_Unbounded_String(LocalDataName) or
              LocalDataName = "" then
               LogMessage
                 ("Loading " & To_String(DataType) & " file: " &
                  To_String(LocalFileName),
                  Everything);
               if To_String(DataType) = "factions" then
                  LoadFactions(Reader);
               elsif To_String(DataType) = "goals" then
                  LoadGoals(Reader);
               elsif To_String(DataType) = "help" then
                  LoadHelp(Reader);
               elsif To_String(DataType) = "items" then
                  LoadItems(Reader);
               elsif To_String(DataType) = "mobiles" then
                  LoadMobs(Reader);
               elsif To_String(DataType) = "recipes" then
                  LoadRecipes(Reader);
               elsif To_String(DataType) = "modules" then
                  LoadShipModules(Reader);
               elsif To_String(DataType) = "ships" then
                  LoadShips(Reader);
               elsif To_String(DataType) = "stories" then
                  LoadStories(Reader);
               elsif To_String(DataType) = "data" then
                  LoadData(Reader);
               elsif To_String(DataType) = "careers" then
                  LoadCareers(Reader);
               end if;
            end if;
            Free(Reader);
         end LoadDataFile;
      begin
         if FileName = "" then
            Start_Search(Files, DataName, "*.dat");
            while More_Entries(Files) loop
               Get_Next_Entry(Files, FoundFile);
               Open(Full_Name(FoundFile), DataFile);
               LocalFileName := To_Unbounded_String(Full_Name(FoundFile));
               LoadDataFile("");
               Close(DataFile);
            end loop;
            End_Search(Files);
         else
            Open(To_String(DataDirectory) & FileName, DataFile);
            LocalFileName := To_Unbounded_String(FileName);
            LoadDataFile(DataName);
            Close(DataFile);
         end if;
      end LoadSelectedData;
   begin
      if Factions_List.Length > 0 then
         return "";
      end if;
      -- Load standard game data
      for I in DataTypes'Range loop
         LoadSelectedData
           (To_String(DataTypes(I).Name), To_String(DataTypes(I).FileName));
      end loop;
      -- Load modifications
      Start_Search
        (Directories, To_String(ModsDirectory), "",
         (Directory => True, others => False));
      while More_Entries(Directories) loop
         Get_Next_Entry(Directories, FoundDirectory);
         if Simple_Name(FoundDirectory) /= "." and
           Simple_Name(FoundDirectory) /= ".." then
            LoadSelectedData(Full_Name(FoundDirectory), "");
         end if;
      end loop;
      End_Search(Directories);
      SetToolsList;
      return "";
   exception
      when An_Exception : others =>
         LogMessage(Exception_Message(An_Exception), Everything);
         return Exception_Message(An_Exception);
   end LoadGameData;

end Game;
