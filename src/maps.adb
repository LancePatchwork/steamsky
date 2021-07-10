--    Copyright 2017-2021 Bartek thindil Jasicki
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

with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Ships; use Ships;

package body Maps is

   function CountDistance
     (DestinationX: Map_X_Range; DestinationY: Map_Y_Range) return Natural is
      DiffX: Natural range 0 .. Map_X_Range'Last;
      DiffY: Natural range 0 .. Map_Y_Range'Last;
      Distance: Float range 0.0 .. Float(Map_X_Range'Last * Map_Y_Range'Last);
   begin
      DiffX := abs (Player_Ship.Sky_X - DestinationX);
      DiffY := abs (Player_Ship.Sky_Y - DestinationY);
      Distance := Sqrt(Float((DiffX**2) + (DiffY**2)));
      return Natural(Float'Floor(Distance));
   end CountDistance;

   procedure NormalizeCoord(Coord: in out Integer; IsXAxis: Boolean := True) is
   begin
      if IsXAxis then
         if Coord < Map_X_Range'First then
            Coord := Map_X_Range'First;
         elsif Coord > Map_X_Range'Last then
            Coord := Map_X_Range'Last;
         end if;
      else
         if Coord < Map_Y_Range'First then
            Coord := Map_Y_Range'First;
         elsif Coord > Map_Y_Range'Last then
            Coord := Map_Y_Range'Last;
         end if;
      end if;
   end NormalizeCoord;

end Maps;
