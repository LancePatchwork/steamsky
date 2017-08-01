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
with Ada.Containers.Vectors; use Ada.Containers;
with Game; use Game;
with Crew; use Crew;
with Missions; use Missions;

package Bases is

   type Bases_Types is (Industrial, Agricultural, Refinery, Shipyard, Any);
   type Recruit_Data is -- Data structure for recruits
   record
      Name: Unbounded_String; -- Name of recruit
      Gender: Character; -- Gender of recruit
      Skills: Skills_Container
        .Vector; -- Names indexes, levels and experience in skills of recruit
      Price: Positive; -- Cost of enlist of recruit
   end record;
   package Recruit_Container is new Vectors(Positive, Recruit_Data);
   type Reputation_Array is
     array
     (1 ..
          2) of Integer; -- Data structure for reputation, 1 = level, 2 = points to next level
   type Bases_Owners is
     (Poleis,
      Independent,
      Abandoned,
      Pirates,
      Undead,
      Drones,
      Inquisition,
      Any);
   type Base_Cargo is -- Data structure for bases cargo
   record
      ProtoIndex: Positive; -- Index of item prototype
      Amount: Natural; -- Amount of items
      Durability: Positive; -- Durability of items
   end record;
   package BaseCargo_Container is new Vectors(Positive, Base_Cargo);
   type BaseRecord is -- Data structure for bases
   record
      Name: Unbounded_String; -- Base name
      Visited: Date_Record; -- Time when player last visited base
      SkyX: Integer; -- X coordinate on sky map
      SkyY: Integer; -- Y coordinate on sky map
      BaseType: Bases_Types; -- Type of base
      Population: Natural; -- Amount of people in base
      RecruitDate: Date_Record; -- Time when recruits was generated
      Recruits: Recruit_Container.Vector; -- List of available recruits
      Known: Boolean; -- Did base is know to player
      AskedForBases: Boolean; -- Did player asked for bases in this base
      AskedForEvents: Date_Record; -- Time when players asked for events in this base
      Reputation: Reputation_Array; -- Reputation level and progress of player
      MissionsDate: Date_Record; -- Time when missions was generated
      Missions: Mission_Container.Vector; -- List of available missions
      Owner: Bases_Owners; -- Owner of base
      Cargo: BaseCargo_Container.Vector; -- List of all cargo in base
   end record;
   SkyBases: array(1 .. 1024) of BaseRecord; -- List of sky bases

   procedure GainRep
     (BaseIndex: Positive;
      Points: Integer); -- Gain reputation in selected base
   procedure CountPrice
     (Price: in out Positive;
      TraderIndex: Natural;
      Reduce: Boolean :=
        True); -- Count price for actions with bases (buying/selling/docking/ect)
   function GenerateBaseName
     return Unbounded_String; -- Generate random name for base
   procedure GenerateRecruits
     (BaseIndex: Positive); -- Generate if needed new recruits in base
   procedure AskForBases; -- Ask in base for direction for other bases
   procedure AskForEvents; -- Ask in base for direction for random events
   procedure UpdatePopulation
     (BaseIndex: Positive); -- Update base population if needed
   procedure GenerateCargo; -- Generate base cargo
   procedure UpdateBaseCargo
     (ProtoIndex: Natural := 0;
      Amount: Integer;
      Durability: Natural := 100;
      CargoIndex: Natural := 0); -- Update cargo in base
   function FindBaseCargo
     (ProtoIndex: Positive;
      Durability: Natural :=
        101)
     return Natural; -- Find index of item in base cargo, return 0 if no item found

end Bases;
