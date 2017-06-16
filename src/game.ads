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
with GNAT.Directory_Operations; use GNAT.Directory_Operations;

package Game is

   type GameStates is
     (Quit,
      Main_Menu,
      Sky_Map_View,
      Control_Speed,
      Ship_Info,
      Crew_Info,
      Giving_Orders,
      Messages_View,
      Trade_View,
      Help_View,
      Quit_Confirm,
      New_Game,
      Combat_State,
      Combat_Orders,
      Craft_View,
      License_Info,
      License_Full,
      Wait_Order,
      News_View,
      Cargo_Info,
      Help_Topic,
      Repairs_View,
      Clear_Confirm,
      Module_Options,
      Shipyard_View,
      Recruits_View,
      Dismiss_Confirm,
      Rename_Module,
      Drop_Cargo,
      Trade_Form,
      Rename_Ship,
      Assign_Owner,
      Recipe_Setting,
      Move_Map,
      Bases_List,
      Events_View,
      Assign_Ammo,
      ShipyardTypesMenu,
      GameMenu,
      GameStats_View,
      Death_Confirm,
      TradeRecipes_View,
      BaseMissions_View,
      Missions_View,
      Orders_For_All,
      Enemy_Info,
      Orders_Priorities,
      BasesList_Types,
      BasesList_Statuses,
      BasesList_Owners,
      WaitX_Order,
      PilotRest_Confirm,
      EngineerRest_Confirm,
      GameOptions_View,
      Heal_View,
      Goals_Menu); -- Game states
   type Date_Record is -- Data for game date/time
   record
      Year: Natural;
      Month: Natural;
      Day: Natural;
      Hour: Natural;
      Minutes: Natural;
   end record;
   GameDate: Date_Record;
   GameVersion: constant String := "Version: 1.3";
   package UnboundedString_Container is new Vectors
     (Positive,
      Unbounded_String);
   package Positive_Container is new Vectors(Positive, Positive);
   BaseSyllablesPre: UnboundedString_Container.Vector;
   BaseSyllablesStart: UnboundedString_Container.Vector;
   BaseSyllablesEnd: UnboundedString_Container.Vector;
   BaseSyllablesPost: UnboundedString_Container.Vector;
   MaleSyllablesStart: UnboundedString_Container.Vector;
   MaleSyllablesMiddle: UnboundedString_Container.Vector;
   MaleSyllablesEnd: UnboundedString_Container.Vector;
   MaleVocals: UnboundedString_Container.Vector;
   MaleConsonants: UnboundedString_Container.Vector;
   FemaleSyllablesStart: UnboundedString_Container.Vector;
   FemaleSyllablesMiddle: UnboundedString_Container.Vector;
   FemaleSyllablesEnd: UnboundedString_Container.Vector;
   FemaleVocals: UnboundedString_Container.Vector;
   ShipSyllablesStart: UnboundedString_Container.Vector;
   ShipSyllablesMiddle: UnboundedString_Container.Vector;
   ShipSyllablesEnd: UnboundedString_Container.Vector;
   Skills_Names: UnboundedString_Container.Vector;
   RepairTools: Unbounded_String;
   CleaningTools: Unbounded_String;
   HealingTools: Unbounded_String;
   PlayerShipIndex: Unbounded_String;
   AlchemyTools: Unbounded_String;
   DrinksType: Unbounded_String;
   CorpseIndex: Unbounded_String;
   MissionItemsType: Unbounded_String;
   FoodTypes: array(1 .. 2) of Unbounded_String;
   FuelType: Unbounded_String;
   MoneyIndex: Unbounded_String;
   MoneyName: Unbounded_String;
   SaveDirectory: Unbounded_String :=
     To_Unbounded_String
       ("data" &
        Dir_Separator); -- Path to directory where are savegame and logs
   DataDirectory: Unbounded_String :=
     To_Unbounded_String
       ("data" & Dir_Separator); -- Path to directory where are game data files

   procedure NewGame
     (CharName, ShipName: Unbounded_String;
      Gender: Character); -- Start new game: create map, place ship, crew, etc
   procedure UpdateGame
     (Minutes: Positive); -- Game ticks (update time, crew, ship, etc)
   function LoadData
     return Boolean; -- Load game data from file, return false if file not found
   function DaysDifference
     (DateToCompare: Date_Record)
     return Natural; -- Return days difference between selected date and current game date

end Game;
