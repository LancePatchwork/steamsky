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

with Ada.Containers.Hashed_Maps; use Ada.Containers;
with Ada.Strings.Unbounded.Hash;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with DOM.Readers; use DOM.Readers;
with ShipModules; use ShipModules;
with Game; use Game;
with Ships; use Ships;

-- ****h* Crafts/Crafts
-- FUNCTION
-- Provide code for crafting
-- SOURCE
package Crafts is
-- ****

   -- ****s* Crafts/Crafts.Craft_Data
   -- FUNCTION
   -- Data structure for recipes
   -- PARAMETERS
   -- MaterialTypes   - Types of material needed for recipe
   -- MaterialAmounts - Amounts of material needed for recipe
   -- ResultIndex     - Prototype index of crafted item
   -- ResultAmount    - Amount of products
   -- Workplace       - Ship module needed for crafting
   -- Skill           - Skill used in crafting item
   -- Time            - Minutes needed for finish recipe
   -- Difficulty      - How difficult is recipe to discover
   -- Tool            - Type of tool used to craft item
   -- Reputation      - Minimal reputation in base needed to buy that recipe
   -- ToolQuality     - Minimal quality of tool needed to craft that recipe
   -- SOURCE
   type Craft_Data is record
      MaterialTypes: UnboundedString_Container.Vector;
      MaterialAmounts: Positive_Container.Vector;
      ResultIndex: Unbounded_String;
      ResultAmount: Natural := 0;
      Workplace: ModuleType;
      Skill: SkillsData_Container.Extended_Index;
      Time: Positive := 1;
      Difficulty: Positive := 1;
      Tool: Unbounded_String;
      Reputation: Reputation_Range;
      ToolQuality: Positive := 1;
   end record;
   -- ****

   -- ****t* Crafts/Crafts.Recipes_Container
   -- SOURCE
   package Recipes_Container is new Hashed_Maps
     (Unbounded_String, Craft_Data, Ada.Strings.Unbounded.Hash, "=");
   -- ****

   -- ****v* Crafts/Crafts.Recipes_List
   -- FUNCTION
   -- List of recipes available in game
   -- SOURCE
   Recipes_List: Recipes_Container.Map;
   -- ****

   -- ****v* Crafts/Crafts.Known_Recipes
   -- FUNCTION
   -- List of all know by player recipes
   -- SOURCE
   Known_Recipes: UnboundedString_Container.Vector;
   -- ****

   -- ****e* Crafts/Crafts.Crafting_No_Materials
   -- FUNCTION
   -- Raised when no materials needed for selected recipe
   -- SOURCE
   Crafting_No_Materials: exception;
   -- ****

   -- ****e* Crafts/Crafts.Crafting_No_Tools
   -- FUNCTION
   -- Raised when no tool needed for selected recipe
   -- SOURCE
   Crafting_No_Tools: exception;
   -- ****

   -- ****e* Crafts/Crafts.Crafting_No_Workshop
   -- FUNCTION
   -- Raised when no workshop needed for selected recipe
   -- SOURCE
   Crafting_No_Workshop: exception;
   -- ****

   -- ****f* Crafts/Crafts.LoadRecipes
   -- FUNCTION
   -- Load recipes from files
   -- PARAMETERS
   -- Reader - XML reader from which recipes will be read
   -- SOURCE
   procedure LoadRecipes(Reader: Tree_Reader);
   -- ****

   -- ****f* Crafts/Crafts.Manufacturing
   -- FUNCTION
   -- Craft selected items
   -- PARAMETERS
   -- Minutes - How many in game minutes passed
   -- SOURCE
   procedure Manufacturing(Minutes: Positive) with
      Test_Case => (Name => "Test_Manufacturing", Mode => Robustness);
      -- ****

   -- ****f* Crafts/Crafts.SetRecipeData
   -- FUNCTION
   -- Set crafting data for selected recipe
   -- PARAMETERS
   -- RecipeIndex - Index of recipe from Recipes_List or full name of recipe
   --               for deconstructing
   -- RESULT
   -- Crafting data for selected recipe
   -- SOURCE
   function SetRecipeData(RecipeIndex: Unbounded_String) return Craft_Data;
   -- ****

      -- ****f* Crafts/Crafts.CheckRecipe
      -- FUNCTION
      -- Check if player have all requirements for selected recipe
      -- PARAMETERS
      -- RecipeIndex - Index of the prototype recipe to check or if deconstruct
      --               existing item, "Study " + item name.
      -- RESULT
      -- Max amount of items which can be craft
      -- SOURCE
   function CheckRecipe(RecipeIndex: Unbounded_String) return Positive with
      Pre => RecipeIndex /= Null_Unbounded_String,
      Test_Case => (Name => "Test_CheckRecipe", Mode => Nominal);
      -- ****

      -- ****f* Crafts/Crafts.SetRecipe
      -- FUNCTION
      -- Set crafting recipe for selected workshop
      -- PARAMETERS
      -- Workshop    - Index of player ship module (workplace) to which
      --               selected recipe will be set
      -- Amount      - How many times the recipe will be crafted
      -- RecipeIndex - Index of the prototype recipe to check or if deconstruct
      --               existing item, "Study " + item name.
      -- SOURCE
   procedure SetRecipe
     (Workshop, Amount: Positive; RecipeIndex: Unbounded_String) with
      Pre =>
      (Workshop <= Player_Ship.Modules.Last_Index and
       RecipeIndex /= Null_Unbounded_String),
      Test_Case => (Name => "Test_SetRecipe", Mode => Nominal);
      -- ****

end Crafts;
