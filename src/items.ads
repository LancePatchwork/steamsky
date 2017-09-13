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

package Items is

   Items_Types: UnboundedString_Container.Vector; -- Types of items
   type Object_Prices is array(1 .. 4) of Natural; -- Prices of item in bases
   type Object_Buyable is
     array(1 .. 4) of Boolean; -- Did item is buyable in bases
   type Object_Data is -- Data structure for objects prototypes
   record
      Name: Unbounded_String; -- Name of item
      Weight: Positive; -- Weight of item
      IType: Unbounded_String; -- Type of item
      Prices: Object_Prices; -- Prices of item in bases
      Buyable: Object_Buyable; -- Did item is buyable in selected bases
      Value: Natural; -- Additional item data (damage for ammo, etc)
      ShowType: Unbounded_String; -- Displayed type of item (can be group of items, renamed type, etc)
      Description: Unbounded_String; -- Description of item
      Index: Unbounded_String; -- Index of item
   end record;
   package Objects_Container is new Vectors(Positive, Object_Data);
   type InventoryData is -- Data structure for item in inventory
   record
      ProtoIndex: Positive; -- Index of prototype
      Amount: Positive; -- Amount of item
      Name: Unbounded_String; -- Name of item if different than default
      Durability: Natural; -- Current durability of item
   end record;
   package Inventory_Container is new Vectors(Positive, InventoryData);
   Items_List: Objects_Container.Vector; -- List of item available in game
   Items_Directory_Not_Found: exception; -- Raised when no directory with items files
   Items_Files_Not_Found: exception; -- Raised when no files with items

   procedure LoadItems; -- Load items from files
   function FindProtoItem
     (Index,
      ItemType: Unbounded_String :=
        Null_Unbounded_String)
      return Natural; -- Return vector index of item or zero if item not found
   function GetItemName
     (Item: InventoryData)
     return String; -- Get name of item in ship cargo or character inventory
   procedure DamageItem
     (CargoIndex: Positive;
      CrewIndex,
      SkillIndex: Natural :=
        0); -- Check if item in ship cargo or character inventory was damaged

end Items;
