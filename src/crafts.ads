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

with Ada.Containers.Vectors; use Ada.Containers;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with ShipModules; use ShipModules;
with Game; use Game;

package Crafts is

   type Craft_Data is -- Data structure for recipes
   record
      MaterialTypes: UnboundedString_Container
        .Vector; -- Types of material needed for recipe
      MaterialAmounts: Positive_Container
        .Vector; -- Amounts of material needed for recipe
      ResultIndex: Positive; -- Prototype index of crafted item
      ResultAmount: Natural; -- Amount of products
      Workplace: ModuleType; -- Ship module needed for crafting
      Skill: Positive; -- Skill used in crafting item
      Time: Positive; -- Minutes needed for finish recipe
      Difficulty: Positive; -- How difficult is recipe to discover
      BaseType: Natural; -- Sky base type in which recipe can be bought
      Tool: Unbounded_String; -- Type of tool used to craft item
      Index: Unbounded_String; -- Index of recipe
   end record;
   package Recipes_Container is new Vectors(Positive, Craft_Data);
   Recipes_List: Recipes_Container.Vector; -- List of recipes available in game
   Known_Recipes: Positive_Container
     .Vector; -- List of all know by player recipes
   Recipes_Directory_Not_Found: exception;
   Recipes_Files_Not_Found: exception;
   Recipes_Invalid_Data: exception;

   procedure LoadRecipes; -- Load recipes from files
   procedure Manufacturing(Minutes: Positive); -- Craft selected items
   function SetRecipe
     (RecipeIndex: Integer;
      ModuleIndex: Positive)
     return String; -- Set recipe to craft, returns empty string if all ok otherwise error message
   function FindRecipe
     (Index: Unbounded_String)
     return Natural; -- Return vector index of recipe or zero if recipe not found

end Crafts;
