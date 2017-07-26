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

package Missions is

   type Missions_Types is (Deliver, Destroy, Patrol, Explore, Passenger);
   type Mission_Data is -- Data structure for missions
   record
      MType: Missions_Types; -- Type of mission
      Target: Natural; -- Target for mission (ship, item or passenger index)
      Time: Positive; -- Amount of minutes to finish mission
      TargetX: Natural; -- Skymap X-axis for mission target
      TargetY: Natural; -- Skymap Y-axis for mission target
      Reward: Positive; -- Amount of moneys for mission
      StartBase: Positive; -- Index of sky base where mission starts
      Finished: Boolean; -- Did mission is finished
   end record;
   package Mission_Container is new Vectors(Positive, Mission_Data);

   procedure GenerateMissions
     (BaseIndex: Positive); -- Generate if needed new missions in selected base
   function AcceptMission
     (MissionIndex: Positive)
     return String; -- Accept selected mission from base, returns empty string if all ok otherwise error message
   procedure UpdateMissions(Minutes: Positive); -- Update accepted missions
   function FinishMission
     (MissionIndex: Positive)
     return String; -- Finish selected mission, returns empty string if all ok otherwise error message
   procedure DeleteMission
     (MissionIndex: Positive;
      Failed: Boolean := True); -- Delete selected mission
   procedure UpdateMission(MissionIndex: Positive); -- Update status of mission
   function AutoFinishMissions
     return String; -- Finish all possible missions, returns empty string if all ok otherwise error message

end Missions;
