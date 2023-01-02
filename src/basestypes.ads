--    Copyright 2019-2023 Bartek thindil Jasicki
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
with Ada.Containers.Hashed_Maps; use Ada.Containers;
with Game; use Game;

-- ****h* BasesTypes/BasesTypes
-- FUNCTION
-- Provide code for bases types
-- SOURCE
package BasesTypes is
-- ****

   --## rule off TYPE_INITIAL_VALUES
   -- ****t* BasesTypes/BasesTypes.Prices_Array
   -- FUNCTION
   -- Buy and sell prices for the item in selected base type
   -- SOURCE
   type Prices_Array is array(1 .. 2) of Natural with
      Default_Component_Value => 0;
   -- ****

   -- ****t* BasesTypes/BasesTypes.BasesTrade_Container
   -- FUNCTION
   -- Used to store base buy and sell prices for items in selected base type
   -- SOURCE
   package BasesTrade_Container is new Hashed_Maps
     (Key_Type => Tiny_String.Bounded_String, Element_Type => Prices_Array,
      Hash => Tiny_String_Hash, Equivalent_Keys => Tiny_String."=");
   -- ****

   -- ****s* BasesTypes/Bases_Types.BaseType_Data
   -- FUNCTION
   -- Data structure for bases types
   -- PARAMETERS
   -- Name        - Name of base type, will be presented to the player
   -- Color       - Hexadecimal number of color used to show that base type on
   --               the map
   -- Trades      - List of base items prices for buy and sale in that base
   --               type
   -- Recipes     - List of available crafting recipes in that base type
   -- Flags       - Special flags for selected base type (like shipyard, etc)
   -- Description - Description of the base type. Will be presented to the
   --               player, for example in new game menu
   -- SOURCE
   type Base_Type_Data is record
      Name: Unbounded_String;
      Color: String(1 .. 6);
      Trades: BasesTrade_Container.Map;
      Recipes: UnboundedString_Container.Vector;
      Flags: UnboundedString_Container.Vector;
      Description: Unbounded_String;
   end record;
   -- ****
   --## rule on TYPE_INITIAL_VALUES

   -- ****t* BasesTypes/BasesTypes.BasesTypes_Container
   -- FUNCTION
   -- Used to store information about all available bases types
   -- SOURCE
   package BasesTypes_Container is new Hashed_Maps
     (Key_Type => Tiny_String.Bounded_String, Element_Type => Base_Type_Data,
      Hash => Tiny_String_Hash, Equivalent_Keys => Tiny_String."=");
   -- ****

   -- ****v* BasesTypes/BasesTypes.Bases_Types_List
   -- FUNCTION
   -- List of all available bases types
   -- SOURCE
   Bases_Types_List: BasesTypes_Container.Map;
   -- ****

   -- ****f* BasesTypes/BasesTypes.Load_Bases_Types
   -- FUNCTION
   -- Load bases types from file
   -- PARAMETERS
   -- File_Name - The full path to the factions file which will be read
   -- SOURCE
   procedure Load_Bases_Types(File_Name: String);
   -- ****

   -- ****f* BasesTypes/BasesTypes.Is_Buyable
   -- FUNCTION
   -- Check if selected item is buyable in selected base type
   -- PARAMETERS
   -- Base_Type  - Base type to check
   -- Item_Index - Index of item prototype to check
   -- Check_Flag - Check if selected base type has blackmarket flag
   -- Base_Index - Index of the selected base to check. Default value
   --              is 0
   -- RESULT
   -- True if item is buyable in that type of bases otherwise false
   -- SOURCE
   function Is_Buyable
     (Base_Type: Tiny_String.Bounded_String; Item_Index: Positive;
      Check_Flag: Boolean := True; Base_Index: Extended_Base_Range := 0)
      return Boolean;
      -- ****

      -- ****f* BasesTypes/BasesTypes.Get_Price
      -- FUNCTION
      -- Get price of selected item in selected base type
      -- PARAMETERS
      -- Base_Type  - Base type to check
      -- Item_Index - Index of item prototype to check
      -- RESULT
      -- Price of selected item in selected base type
      -- SOURCE
   function Get_Price
     (Base_Type: Tiny_String.Bounded_String; Item_Index: Positive)
      return Natural;
      -- ****

-- Temporary code to interact with Nim

   Bases_Types: array(0 .. 15) of Tiny_String.Bounded_String;

   function Has_Flag
     (Base_Type: Tiny_String.Bounded_String; Flag: String) return Boolean;

end BasesTypes;
