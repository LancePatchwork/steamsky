--    Copyright 2016-2022 Bartek thindil Jasicki
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
with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Hash;
with Ada.Containers.Hashed_Maps;
with DOM.Readers; use DOM.Readers;
with Crew; use Crew;
with Game; use Game;
with Items; use Items;
with Mobs; use Mobs;

-- ****h* Ships/Ships
-- FUNCTION
-- Provides code for manipulate ships
-- SOURCE
package Ships is
-- ****

   -- ****t* Ships/Ships.Ship_Speed
   -- FUNCTION
   -- Ship speed states
   -- SOURCE
   type Ship_Speed is
     (DOCKED, FULL_STOP, QUARTER_SPEED, HALF_SPEED, FULL_SPEED) with
      Default_Value => FULL_SPEED;
   -- ****

   -- ****d* Ships/Ships.Default_Ship_Speed
   -- FUNCTION
   -- Default speed setting for ships
   -- SOURCE
   Default_Ship_Speed: constant Ship_Speed := FULL_SPEED;
   -- ****

   -- ****t* Ships/Ships.Ship_Combat_Ai
   -- FUNCTION
   -- NPC ships combat AI types
   -- SOURCE
   type Ship_Combat_Ai is (NONE, BERSERKER, ATTACKER, COWARD, DISARMER) with
      Default_Value => NONE;
   -- ****

   -- ****d* Ships/Ships.Default_Combat_Ai
   -- FUNCTION
   -- Default value for NPC's ships combat behavior
   -- SOURCE
   Default_Combat_Ai: constant Ship_Combat_Ai := NONE;
   -- ****

   -- ****t* Ships/Ships.Ship_Upgrade
   -- FUNCTION
   -- Player ship types of module upgrades
   -- SOURCE
   type Ship_Upgrade is (NONE, DURABILITY, MAX_VALUE, VALUE) with
      Default_Value => NONE;
   -- ****

   -- ****d* Ships/Ships.Default_Ship_Upgrade
   -- FUNCTION
   -- Default ship upgrade (no upgrade)
   -- SOURCE
   Default_Ship_Upgrade: constant Ship_Upgrade := NONE;
   -- ****

   -- ****t* Ships/Ships.Data_Array
   -- FUNCTION
   -- Used to store ship modules data
   -- SOURCE
   type Data_Array is array(1 .. 3) of Integer with
      Default_Component_Value => 0;
   -- ****

   -- ****d* Ships/Ships.Empty_Data_Array
   -- FUNCTION
   -- Empty modules data
   -- SOURCE
   Empty_Data_Array: constant Data_Array := (others => 0);
   -- ****

   -- ****t* Ships/Ships.Module_Type_2
   -- FUNCTION
   -- Types of ships modules
   -- SOURCE
   type Module_Type_2 is
     (WORKSHOP, ANY, MEDICAL_ROOM, TRAINING_ROOM, ENGINE, CABIN, COCKPIT,
      TURRET, GUN, CARGO_ROOM, HULL, ARMOR, BATTERING_RAM, HARPOON_GUN) with
      Default_Value => ANY;
   -- ****

   -- ****d* Ships/Ships.Default_Module_Type
   -- FUNCTION
   -- Default type of ships modules
   -- SOURCE
   Default_Module_Type: constant Module_Type_2 := ANY;
   -- ****

   -- ****s* Ships/Ships.Module_Data
   -- FUNCTION
   -- Data structure for ship modules, medical room, cockpit, armor and cargo
   -- bays don't have any special fields
   -- PARAMETERS
   -- Name              - Name of module
   -- Proto_Index       - Index of module prototype
   -- Weight            - Weight of module
   -- Durability        - 0 = destroyed
   -- Max_Durability    - Base durability
   -- Owner             - Crew member indexes for owners of module
   -- Upgrade_Progress  - Progress of module upgrade
   -- Upgrade_Action    - Type of module upgrade
   -- Fuel_Usage        - Amount of fuel used for each move on map
   -- Power             - Power of engine used for counting ship speed
   -- Disabled          - Did engine is disabled or not
   -- Cleanliness       - Cleanliness of selected cabin
   -- Quality           - Quality of selected cabin
   -- Gun_Index         - Index of installed gun
   -- Damage            - Damage bonus for selected gun
   -- Ammo_Index        - Cargo index of ammunition used by selected gun
   -- Installed_Modules - Amount of installed modules on ship
   -- Max_Modules       - Amount of maximum installed modules for this hull
   -- Crafting_Index    - Index of crafting recipe or item which is
   --                     deconstructed or studies
   -- Crafting_Time     - Time needed to finish crating order
   -- Crafting_Amount   - How many times repeat crafting order
   -- Trained_Skill     - Index of skill set to training
   -- Damage2           - Damage done by battering ram
   -- Cooling_Down      - If true, battering ram can't attack
   -- Duration          - Duration bonus for selected harpoon gun
   -- Harpoon_Index     - Cargo index of ammunition used by selected harpoon
   --                     gun
   -- Data              - Various data for module (depends on module)
   -- SOURCE
   type Module_Data(M_Type: Module_Type_2 := Default_Module_Type) is record
      Name: Tiny_String.Bounded_String;
      Proto_Index: Tiny_String.Bounded_String;
      Weight: Natural := 0;
      Durability: Integer := 0;
      Max_Durability: Natural := 0;
      Owner: Natural_Container.Vector;
      Upgrade_Progress: Integer := 0;
      Upgrade_Action: Ship_Upgrade;
      case M_Type is
         when ENGINE =>
            Fuel_Usage: Positive := 1;
            Power: Positive := 1;
            Disabled: Boolean;
         when CABIN =>
            Cleanliness: Natural := 0;
            Quality: Natural := 0;
         when TURRET =>
            Gun_Index: Natural := 0;
         when GUN =>
            Damage: Positive := 1;
            Ammo_Index: Inventory_Container.Extended_Index;
         when HULL =>
            Installed_Modules: Natural := 0;
            Max_Modules: Positive := 1;
         when WORKSHOP =>
            Crafting_Index: Tiny_String.Bounded_String;
            Crafting_Time: Natural := 0;
            Crafting_Amount: Natural := 0;
         when MEDICAL_ROOM | COCKPIT | ARMOR | CARGO_ROOM =>
            null;
         when TRAINING_ROOM =>
            Trained_Skill: SkillsData_Container.Extended_Index;
         when BATTERING_RAM =>
            Damage2: Positive := 1;
            Cooling_Down: Boolean;
         when HARPOON_GUN =>
            Duration: Positive := 1;
            Harpoon_Index: Inventory_Container.Extended_Index;
         when ANY =>
            Data: Data_Array;
      end case;
   end record;
   -- ****

   -- ****d* Ships/Ships.Default_Module
   -- FUNCTION
   -- Default empty module without type
   -- SOURCE
   Default_Module: constant Module_Data := (others => <>);
   -- ****

   -- ****t* Ships/Ships.Modules_Container
   -- FUNCTION
   -- Used to store modules data in ships
   -- SOURCE
   package Modules_Container is new Vectors
     (Index_Type => Positive, Element_Type => Module_Data);
   -- ****

   -- ****t* Ships/Ships.Crew_Container
   -- FUNCTION
   -- Used to store crew data in ships
   -- SOURCE
   package Crew_Container is new Indefinite_Vectors
     (Index_Type => Positive, Element_Type => Member_Data);
   -- ****

   -- ****s* Ships/Ships.Ship_Record
   -- FUNCTION
   -- Data structure for ships
   -- PARAMETERS
   -- Name           - Ship name
   -- Sky_X          - X coordinate on sky map
   -- SKy_Y          - Y coordinate on sky map
   -- Speed          - Speed of ship
   -- Modules        - List of ship modules
   -- Cargo          - List of ship cargo
   -- Crew           - List of ship crew
   -- Upgrade_Module - Number of module to upgrade
   -- Destination_X  - Destination X coordinate
   -- Destination_Y  - Destination Y coordinate
   -- Repair_Module  - Number of module to repair as first
   -- Description    - Description of ship
   -- Home_Base      - Index of home base of ship
   -- SOURCE
   type Ship_Record is record
      Name: Tiny_String.Bounded_String;
      Sky_X: Map_X_Range;
      Sky_Y: Map_Y_Range;
      Speed: Ship_Speed;
      Modules: Modules_Container.Vector;
      Cargo: Inventory_Container.Vector (Capacity => 128);
      Crew: Crew_Container.Vector;
      Upgrade_Module: Modules_Container.Extended_Index;
      Destination_X: Natural range 0 .. Map_X_Range'Last;
      Destination_Y: Natural range 0 .. Map_Y_Range'Last;
      Repair_Module: Modules_Container.Extended_Index;
      Description: Short_String.Bounded_String;
      Home_Base: Extended_Base_Range;
   end record;
   -- ****

   -- ****d* Ships/Ships.Empty_Ship
   -- FUNCTION
   -- Empty record for ship data
   -- SOURCE
   Empty_Ship: constant Ship_Record := (others => <>);
   -- ****

   -- ****s* Ships/Ships.Proto_Member_Data
   -- FUNCTION
   -- Data structure for proto crew info
   -- PARAMETERS
   -- Proto_Index - Index of proto mob which will be used as crew member
   -- Min_Amount  - Mininum amount of that mob in crew
   -- Max_Amount  - Maximum amount of that mob in crew. If 0 then MinAmount
   --               will be amount
   -- SOURCE
   type Proto_Member_Data is record
      Proto_Index: Unbounded_String;
      Min_Amount: Positive := 1;
      Max_Amount: Natural := 0;
   end record;
   -- ****

   -- ****d* Ships/Ships.Empty_Proto_Member
   -- FUNCTION
   -- Empty record for proto crew info
   -- SOURCE
   Empty_Proto_Member: constant Proto_Member_Data := (others => <>);
   -- ****

   -- ****t* Ships/Ships.Proto_Crew_Container
   -- FUNCTION
   -- Used to store crew info in ships prototypes
   -- SOURCE
   package Proto_Crew_Container is new Vectors
     (Index_Type => Positive, Element_Type => Proto_Member_Data);
   -- ****

   -- ****s* Ships/Ships.Proto_Ship_Data
   -- FUNCTION
   -- Data structure for ship prototypes
   -- PARAMETERS
   -- Name          - Prototype name
   -- Modules       - List of ship modules
   -- Accuracy      - Bonus to hit for ship
   -- Combat_Ai     - Behaviour of ship in combat
   -- Evasion       - Bonus to evade attacks
   -- Loot          - Amount of loot(moneys) gained for destroying ship
   -- Perception    - Bonus to spot player ship first
   -- Cargo         - List of ship cargo
   -- Combat_Value  - Combat value of ship (used to generate enemies)
   -- Crew          - List of mobs used as ship crew
   -- Description   - Description of ship
   -- Owner         - Index of faction to which ship belong
   -- Known_Recipes - List of known recipes
   -- SOURCE
   type Proto_Ship_Data is record
      Name: Tiny_String.Bounded_String;
      Modules: TinyString_Container.Vector;
      Accuracy: Natural_Array(1 .. 2);
      Combat_Ai: Ship_Combat_Ai;
      Evasion: Natural_Array(1 .. 2);
      Loot: Natural_Array(1 .. 2);
      Perception: Natural_Array(1 .. 2);
      Cargo: MobInventory_Container.Vector (Capacity => 32);
      Combat_Value: Positive := 1;
      Crew: Proto_Crew_Container.Vector;
      Description: Short_String.Bounded_String;
      Owner: Tiny_String.Bounded_String;
      Known_Recipes: TinyString_Container.Vector;
   end record;
   -- ****

   -- ****d* Ships/Ships.Empty_Proto_Ship
   -- FUNCTION
   -- Empty record for ships prototypes
   -- SOURCE
   Empty_Proto_Ship: constant Proto_Ship_Data := (others => <>);
   -- ****

   -- ****t* Ships/Ships.Proto_Ships_Container
   -- FUNCTION
   -- Used to store prototype ships data
   -- SOURCE
   package Proto_Ships_Container is new Hashed_Maps
     (Key_Type => Unbounded_String, Element_Type => Proto_Ship_Data,
      Hash => Ada.Strings.Unbounded.Hash, Equivalent_Keys => "=");
   -- ****

   -- ****v* Ships/Ships.Proto_Ships_List
   -- FUNCTION
   -- List of all prototypes of ships
   -- SOURCE
   Proto_Ships_List: Proto_Ships_Container.Map;
   -- ****

   -- ****v* Ships/Ships.Player_Ship
   -- FUNCTION
   -- The player ship
   -- SOURCE
   Player_Ship: Ship_Record;
   -- ****

   -- ****v* Ships/Ships.Ship_Syllables_Start
   -- FUNCTION
   -- List of first syllables for generating ships names
   -- SOURCE
   Ship_Syllables_Start: SyllableString_Container.Vector (Capacity => 128);
   -- ****

   -- ****v* Ships/Ships.Ship_Syllables_Middle
   -- FUNCTION
   -- List of middle syllables for generating ships names
   -- SOURCE
   Ship_Syllables_Middle: SyllableString_Container.Vector (Capacity => 128);
   -- ****

   -- ****v* Ships/Ships.Ship_Syllables_End
   -- FUNCTION
   -- List of last syllables for generating ships names
   -- SOURCE
   Ship_Syllables_End: SyllableString_Container.Vector (Capacity => 128);
   -- ****

   -- ****e* Ships/Ships.Ships_Invalid_Data
   -- FUNCTION
   -- Raised when invalid data in ships file
   -- SOURCE
   Ships_Invalid_Data: exception;
   -- ****

   -- ****f* Ships/Ships.CreateShip
   -- FUNCTION
   -- Create new ship
   -- PARAMETERS
   -- Proto_Index     - Index of prototype ship which will be used to create
   --                   the new ship
   -- Name            - Name of the new ship. If empty, then the default name
   --                   of the prototype ship will be used
   -- X               - X coordinate of newly created ship on map
   -- Y               - Y coordinate of newly created ship on map
   -- Speed           - Starting speed of newly created ship
   -- Random_Upgrades - If true, newly created ship will be have
   --                   random upgrades to own modules. Default is true.
   -- RESULT
   -- Newly created ship
   -- SOURCE
   function Create_Ship
     (Proto_Index: Unbounded_String; Name: Tiny_String.Bounded_String;
      X: Map_X_Range; Y: Map_Y_Range; Speed: Ship_Speed;
      Random_Upgrades: Boolean := True) return Ship_Record with
      Pre => Proto_Ships_List.Contains(Key => Proto_Index),
      Test_Case => (Name => "Test_CreateShip", Mode => Nominal);
      -- ****

      -- ****f* Ships/Ships.Load_Ships
      -- FUNCTION
      -- Load ships from files
      -- PARAMETERS
      -- Reader - XML Reader from which ships data will be read
      -- SOURCE
   procedure Load_Ships(Reader: Tree_Reader);
   -- ****

   -- ****f* Ships/Ships.Count_Ship_Weight
   -- FUNCTION
   -- Count weight of ship (with modules and cargo)
   -- PARAMETERS
   -- Ship - Ship which weight will be counted
   -- RESULT
   -- Ship weight in kilograms
   -- SOURCE
   function Count_Ship_Weight(Ship: Ship_Record) return Positive with
      Test_Case => (Name => "Test_CountShipWeight", Mode => Robustness);
      -- ****

      -- ****f* Ships/Ships.Generate_Ship_Name
      -- FUNCTION
      -- Generate random name for ship
      -- PARAMETERS
      -- Owner - Index of faction to which ship belongs
      -- RESULT
      -- Random name for a ship
      -- SOURCE
   function Generate_Ship_Name
     (Owner: Tiny_String.Bounded_String) return Tiny_String.Bounded_String with
      Pre => Tiny_String.Length(Source => Owner) > 0,
      Test_Case => (Name => "Test_GenerateShipName", Mode => Nominal);
      -- ****

      -- ****f* Ships/Ships.Count_Combat_Value
      -- FUNCTION
      -- Count combat value of player ship
      -- RESULT
      -- Numeric level of combat value of player ship
      -- SOURCE
   function Count_Combat_Value return Natural with
      Test_Case => (Name => "Test_CountCombatValue", Mode => Robustness);
      -- ****

      -- ****f* Ships/Ships.Get_Cabin_Quality
      -- FUNCTION
      -- Get description of quality of selected cabin in player ship
      -- PARAMETERS
      -- Quality - Numeric value of cabin quality
      -- RESULT
      -- Description of cabin quality
      -- SOURCE
   function Get_Cabin_Quality(Quality: Natural) return String with
      Post => Get_Cabin_Quality'Result'Length > 0,
      Test_Case => (Name => "Test_GetCabinQuality", Mode => Nominal);
      -- ****

      -- ****f* Ships/Ships.Damage_Module
      -- FUNCTION
      -- Damage the selected module
      -- PARAMETERS
      -- Ship         - Ship in which the module will be damaged
      -- Module_Index - Index of the module to damage
      -- Damage       - Amount of damage which the module will take
      -- Death_Reason - If module has owner, reason of owner's death
      --                if module will be destroyed
      -- SOURCE
   procedure Damage_Module
     (Ship: in out Ship_Record; Module_Index: Modules_Container.Extended_Index;
      Damage: Positive; Death_Reason: String) with
      Pre => Module_Index in
        Ship.Modules.First_Index .. Ship.Modules.Last_Index and
      Death_Reason'Length > 0,
      Test_Case => (Name => "Test_DamageModule", Mode => Nominal);
      -- ****

end Ships;
