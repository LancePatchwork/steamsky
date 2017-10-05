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

with Ada.Containers.Vectors; use Ada.Containers;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Crew; use Crew;

package Mobs is

   type ProtoMobRecord is -- Data structure for mobs prototypes
   record
      Index: Unbounded_String; -- Index of mob
      Skills: Skills_Container
        .Vector; -- Names indexes, levels and experience in skills of mob
      Attributes: Attributes_Container
        .Vector; -- Levels and experience in attributes of mob
      Order: Crew_Orders; -- Current order for mob
      Priorities: Orders_Array; -- Priority of orders of mob
   end record;
   package ProtoMobs_Container is new Vectors(Positive, ProtoMobRecord);
   ProtoMobs_List: ProtoMobs_Container.Vector;
   Mobs_Directory_Not_Found: exception; -- Raised when no directory with mobs files
   Mobs_Files_Not_Found: exception; -- Raised when no files with mobs

   procedure LoadMobs; -- Load mobs from files
   function FindProtoMob
     (Index: Unbounded_String)
     return Natural; -- Return vector index of mobile or zero if mobile not found

end Mobs;
