--    Copyright 2017-2018 Bartek thindil Jasicki
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

with Maps; use Maps;
with Items; use Items;
with Game.SaveLoad; use Game.SaveLoad;

package body Bases.SaveLoad is

   procedure SaveBases(SaveGame: in out File_Type) is
      RawValue: Unbounded_String;
   begin
      for I in SkyBases'Range loop
         Put(SaveGame, To_String(SkyBases(I).Name) & ";");
         RawValue :=
           To_Unbounded_String(Integer'Image(SkyBases(I).Visited.Year));
         Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
         if SkyBases(I).Visited.Year > 0 then
            RawValue :=
              To_Unbounded_String(Integer'Image(SkyBases(I).Visited.Month));
            Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
            RawValue :=
              To_Unbounded_String(Integer'Image(SkyBases(I).Visited.Day));
            Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
            RawValue :=
              To_Unbounded_String(Integer'Image(SkyBases(I).Visited.Hour));
            Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
            RawValue :=
              To_Unbounded_String(Integer'Image(SkyBases(I).Visited.Minutes));
            Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
         end if;
         RawValue := To_Unbounded_String(Integer'Image(SkyBases(I).SkyX));
         Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
         RawValue := To_Unbounded_String(Integer'Image(SkyBases(I).SkyY));
         Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
         RawValue :=
           To_Unbounded_String
             (Integer'Image(Bases_Types'Pos(SkyBases(I).BaseType)));
         Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
         RawValue :=
           To_Unbounded_String(Integer'Image(SkyBases(I).Population));
         Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
         if SkyBases(I).Visited.Year > 0 then
            RawValue :=
              To_Unbounded_String(Integer'Image(SkyBases(I).RecruitDate.Year));
            Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
            RawValue :=
              To_Unbounded_String
                (Integer'Image(SkyBases(I).RecruitDate.Month));
            Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
            RawValue :=
              To_Unbounded_String(Integer'Image(SkyBases(I).RecruitDate.Day));
            Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
            RawValue := To_Unbounded_String(SkyBases(I).Recruits.Length'Img);
            Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
            if SkyBases(I).Recruits.Length > 0 then
               for Recruit of SkyBases(I).Recruits loop
                  Put(SaveGame, To_String(Recruit.Name) & ";");
                  Put(SaveGame, Recruit.Gender & ";");
                  RawValue :=
                    To_Unbounded_String(Integer'Image(Recruit.Price));
                  Put
                    (SaveGame,
                     To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
                  RawValue := To_Unbounded_String(Recruit.Skills.Length'Img);
                  Put
                    (SaveGame,
                     To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
                  for Skill of Recruit.Skills loop
                     RawValue := To_Unbounded_String(Integer'Image(Skill(1)));
                     Put
                       (SaveGame,
                        To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
                     RawValue := To_Unbounded_String(Integer'Image(Skill(2)));
                     Put
                       (SaveGame,
                        To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
                     RawValue := To_Unbounded_String(Integer'Image(Skill(3)));
                     Put
                       (SaveGame,
                        To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
                  end loop;
                  RawValue :=
                    To_Unbounded_String(Recruit.Attributes.Length'Img);
                  Put
                    (SaveGame,
                     To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
                  for Attribute of Recruit.Attributes loop
                     RawValue :=
                       To_Unbounded_String(Integer'Image(Attribute(1)));
                     Put
                       (SaveGame,
                        To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
                     RawValue :=
                       To_Unbounded_String(Integer'Image(Attribute(2)));
                     Put
                       (SaveGame,
                        To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
                  end loop;
               end loop;
            end if;
            if SkyBases(I).AskedForBases then
               Put(SaveGame, "Y;");
            else
               Put(SaveGame, "N;");
            end if;
            RawValue :=
              To_Unbounded_String
                (Integer'Image(SkyBases(I).AskedForEvents.Year));
            Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
            RawValue :=
              To_Unbounded_String
                (Integer'Image(SkyBases(I).AskedForEvents.Month));
            Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
            RawValue :=
              To_Unbounded_String
                (Integer'Image(SkyBases(I).AskedForEvents.Day));
            Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
         end if;
         RawValue :=
           To_Unbounded_String(Integer'Image(SkyBases(I).Reputation(1)));
         Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
         RawValue :=
           To_Unbounded_String(Integer'Image(SkyBases(I).Reputation(2)));
         Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
         if SkyBases(I).Visited.Year > 0 then
            RawValue :=
              To_Unbounded_String
                (Integer'Image(SkyBases(I).MissionsDate.Year));
            Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
            RawValue :=
              To_Unbounded_String
                (Integer'Image(SkyBases(I).MissionsDate.Month));
            Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
            RawValue :=
              To_Unbounded_String(Integer'Image(SkyBases(I).MissionsDate.Day));
            Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
            RawValue := To_Unbounded_String(SkyBases(I).Missions.Length'Img);
            Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
            if SkyBases(I).Missions.Length > 0 then
               for Mission of SkyBases(I).Missions loop
                  RawValue :=
                    To_Unbounded_String
                      (Integer'Image(Missions_Types'Pos(Mission.MType)));
                  Put
                    (SaveGame,
                     To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
                  RawValue :=
                    To_Unbounded_String(Integer'Image(Mission.Target));
                  Put
                    (SaveGame,
                     To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
                  RawValue := To_Unbounded_String(Integer'Image(Mission.Time));
                  Put
                    (SaveGame,
                     To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
                  RawValue :=
                    To_Unbounded_String(Integer'Image(Mission.TargetX));
                  Put
                    (SaveGame,
                     To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
                  RawValue :=
                    To_Unbounded_String(Integer'Image(Mission.TargetY));
                  Put
                    (SaveGame,
                     To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
                  RawValue :=
                    To_Unbounded_String(Integer'Image(Mission.Reward));
                  Put
                    (SaveGame,
                     To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
               end loop;
            end if;
            RawValue := To_Unbounded_String(SkyBases(I).Cargo.Length'Img);
            Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
            if SkyBases(I).Cargo.Length > 0 then
               for Item of SkyBases(I).Cargo loop
                  Put
                    (SaveGame,
                     To_String(Items_List(Item.ProtoIndex).Index) & ";");
                  RawValue := To_Unbounded_String(Integer'Image(Item.Amount));
                  Put
                    (SaveGame,
                     To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
                  RawValue :=
                    To_Unbounded_String(Integer'Image(Item.Durability));
                  Put
                    (SaveGame,
                     To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
                  RawValue := To_Unbounded_String(Integer'Image(Item.Price));
                  Put
                    (SaveGame,
                     To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
               end loop;
            end if;
         end if;
         if SkyBases(I).Known then
            Put(SaveGame, "Y;");
         else
            Put(SaveGame, "N;");
         end if;
         RawValue :=
           To_Unbounded_String
             (Integer'Image(Bases_Owners'Pos(SkyBases(I).Owner)));
         Put(SaveGame, To_String(Trim(RawValue, Ada.Strings.Left)) & ";");
      end loop;
   end SaveBases;

   procedure LoadBases(SaveGame: File_Type) is
      BaseRecruits: Recruit_Container.Vector;
      BaseMissions: Mission_Container.Vector;
      BaseCargo: BaseCargo_Container.Vector;
      VectorLength, SkillsLength: Natural;
      Skills: Skills_Container.Vector;
      Attributes: Attributes_Container.Vector;
   begin
      for I in SkyBases'Range loop
         SkyBases(I) :=
           (Name => ReadData(SaveGame),
            Visited => (0, 0, 0, 0, 0),
            SkyX => 0,
            SkyY => 0,
            BaseType => Industrial,
            Population => 0,
            RecruitDate => (0, 0, 0, 0, 0),
            Recruits => BaseRecruits,
            Known => False,
            AskedForBases => False,
            AskedForEvents => (0, 0, 0, 0, 0),
            Reputation => (0, 0),
            MissionsDate => (0, 0, 0, 0, 0),
            Missions => BaseMissions,
            Owner => Poleis,
            Cargo => BaseCargo);
         SkyBases(I).Visited.Year :=
           Natural'Value(To_String(ReadData(SaveGame)));
         if SkyBases(I).Visited.Year > 0 then
            SkyBases(I).Visited.Month :=
              Natural'Value(To_String(ReadData(SaveGame)));
            SkyBases(I).Visited.Day :=
              Natural'Value(To_String(ReadData(SaveGame)));
            SkyBases(I).Visited.Hour :=
              Natural'Value(To_String(ReadData(SaveGame)));
            SkyBases(I).Visited.Minutes :=
              Natural'Value(To_String(ReadData(SaveGame)));
         end if;
         SkyBases(I).SkyX := Integer'Value(To_String(ReadData(SaveGame)));
         SkyBases(I).SkyY := Integer'Value(To_String(ReadData(SaveGame)));
         SkyBases(I).BaseType :=
           Bases_Types'Val(Integer'Value(To_String(ReadData(SaveGame))));
         SkyBases(I).Population :=
           Natural'Value(To_String(ReadData(SaveGame)));
         if SkyBases(I).Visited.Year > 0 then
            SkyBases(I).RecruitDate.Year :=
              Natural'Value(To_String(ReadData(SaveGame)));
            SkyBases(I).RecruitDate.Month :=
              Natural'Value(To_String(ReadData(SaveGame)));
            SkyBases(I).RecruitDate.Day :=
              Natural'Value(To_String(ReadData(SaveGame)));
            VectorLength := Natural'Value(To_String(ReadData(SaveGame)));
            if VectorLength > 0 then
               for J in 1 .. VectorLength loop
                  Skills.Clear;
                  Attributes.Clear;
                  BaseRecruits.Append
                  (New_Item =>
                     (Name => ReadData(SaveGame),
                      Gender => Element(ReadData(SaveGame), 1),
                      Price => Positive'Value(To_String(ReadData(SaveGame))),
                      Skills => Skills,
                      Attributes => Attributes));
                  SkillsLength :=
                    Positive'Value(To_String(ReadData(SaveGame)));
                  for K in 1 .. SkillsLength loop
                     Skills.Append
                     (New_Item =>
                        (Natural'Value(To_String(ReadData(SaveGame))),
                         Natural'Value(To_String(ReadData(SaveGame))),
                         Natural'Value(To_String(ReadData(SaveGame)))));
                  end loop;
                  BaseRecruits(BaseRecruits.Last_Index).Skills := Skills;
                  SkillsLength :=
                    Positive'Value(To_String(ReadData(SaveGame)));
                  if SkillsLength /= Natural(Attributes_List.Length) then
                     raise SaveGame_Invalid_Data
                       with "Different amount of character statistics.";
                  end if;
                  for K in 1 .. SkillsLength loop
                     Attributes.Append
                     (New_Item =>
                        (Natural'Value(To_String(ReadData(SaveGame))),
                         Natural'Value(To_String(ReadData(SaveGame)))));
                  end loop;
                  BaseRecruits(BaseRecruits.Last_Index).Attributes :=
                    Attributes;
               end loop;
               SkyBases(I).Recruits := BaseRecruits;
               BaseRecruits.Clear;
            end if;
            if ReadData(SaveGame) = To_Unbounded_String("Y") then
               SkyBases(I).AskedForBases := True;
            end if;
            SkyBases(I).AskedForEvents.Year :=
              Natural'Value(To_String(ReadData(SaveGame)));
            SkyBases(I).AskedForEvents.Month :=
              Natural'Value(To_String(ReadData(SaveGame)));
            SkyBases(I).AskedForEvents.Day :=
              Natural'Value(To_String(ReadData(SaveGame)));
         end if;
         SkyBases(I).Reputation(1) :=
           Integer'Value(To_String(ReadData(SaveGame)));
         SkyBases(I).Reputation(2) :=
           Integer'Value(To_String(ReadData(SaveGame)));
         if SkyBases(I).Visited.Year > 0 then
            SkyBases(I).MissionsDate.Year :=
              Natural'Value(To_String(ReadData(SaveGame)));
            SkyBases(I).MissionsDate.Month :=
              Natural'Value(To_String(ReadData(SaveGame)));
            SkyBases(I).MissionsDate.Day :=
              Natural'Value(To_String(ReadData(SaveGame)));
            VectorLength := Natural'Value(To_String(ReadData(SaveGame)));
            if VectorLength > 0 then
               for J in 1 .. VectorLength loop
                  BaseMissions.Append
                  (New_Item =>
                     (MType =>
                        Missions_Types'Val
                          (Integer'Value(To_String(ReadData(SaveGame)))),
                      Target => Natural'Value(To_String(ReadData(SaveGame))),
                      Time => Integer'Value(To_String(ReadData(SaveGame))),
                      TargetX => Integer'Value(To_String(ReadData(SaveGame))),
                      TargetY => Integer'Value(To_String(ReadData(SaveGame))),
                      Reward => Integer'Value(To_String(ReadData(SaveGame))),
                      StartBase => I,
                      Finished => False));
               end loop;
               SkyBases(I).Missions := BaseMissions;
               BaseMissions.Clear;
            end if;
            VectorLength := Natural'Value(To_String(ReadData(SaveGame)));
            if VectorLength > 0 then
               for J in 1 .. VectorLength loop
                  BaseCargo.Append
                  (New_Item =>
                     (ProtoIndex => FindProtoItem(ReadData(SaveGame)),
                      Amount => Natural'Value(To_String(ReadData(SaveGame))),
                      Durability =>
                        Positive'Value(To_String(ReadData(SaveGame))),
                      Price => Positive'Value(To_String(ReadData(SaveGame)))));
               end loop;
               SkyBases(I).Cargo := BaseCargo;
               BaseCargo.Clear;
            end if;
         end if;
         if ReadData(SaveGame) = To_Unbounded_String("Y") then
            SkyBases(I).Known := True;
         end if;
         SkyBases(I).Owner :=
           Bases_Owners'Val(Integer'Value(To_String(ReadData(SaveGame))));
         SkyMap(SkyBases(I).SkyX, SkyBases(I).SkyY).BaseIndex := I;
      end loop;
   end LoadBases;

end Bases.SaveLoad;
