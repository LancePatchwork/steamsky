--  This package has been generated automatically by GNATtest.
--  You are allowed to add your code to the bodies of test routines.
--  Such changes will be kept during further regeneration of this file.
--  All code placed outside of test routine bodies will be lost. The
--  code intended to set up and tear down the test environment should be
--  placed into Ships.Movement.Test_Data.

with AUnit.Assertions; use AUnit.Assertions;
with System.Assertions;

--  begin read only
--  id:2.2/00/
--
--  This section can be used to add with clauses if necessary.
--
--  end read only

with Ada.Text_IO; use Ada.Text_IO;

--  begin read only
--  end read only
package body Ships.Movement.Test_Data.Tests is

--  begin read only
--  id:2.2/01/
--
--  This section can be used to add global variables and other elements.
--
--  end read only

--  begin read only
--  end read only
--  begin read only
   function Wrap_Test_Move_Ship_c92b3f_3bb6cb
     (X, Y: Integer; Message: in out Unbounded_String) return Natural is
   begin
      declare
         Test_Move_Ship_c92b3f_3bb6cb_Result: constant Natural :=
           GNATtest_Generated.GNATtest_Standard.Ships.Movement.Move_Ship
             (X, Y, Message);
      begin
         return Test_Move_Ship_c92b3f_3bb6cb_Result;
      end;
   end Wrap_Test_Move_Ship_c92b3f_3bb6cb;
--  end read only

--  begin read only
   procedure Test_Move_Ship_test_moveship(Gnattest_T: in out Test);
   procedure Test_Move_Ship_c92b3f_3bb6cb(Gnattest_T: in out Test) renames
     Test_Move_Ship_test_moveship;
--  id:2.2/c92b3f5b791e7e2d/Move_Ship/1/0/test_moveship/
   procedure Test_Move_Ship_test_moveship(Gnattest_T: in out Test) is
      function Move_Ship
        (X, Y: Integer; Message: in out Unbounded_String)
         return Natural renames
        Wrap_Test_Move_Ship_c92b3f_3bb6cb;
--  end read only

      pragma Unreferenced(Gnattest_T);
      OldX: constant Natural := Player_Ship.Sky_X;
      OldY: constant Natural := Player_Ship.Sky_Y;
      Message: Unbounded_String;
      NewX, NewY: Natural := 0;

   begin

      Player_Ship.Speed := FULL_SPEED;
      if Player_Ship.Sky_X + 1 <= 1_024 then
         NewX := 1;
      end if;
      if Player_Ship.Sky_Y + 1 <= 1_024 then
         NewY := 1;
      end if;
      if Move_Ship(NewX, NewY, Message) = 0 then
         Ada.Text_IO.Put_Line(To_String(Message));
      end if;
      Assert
        (Player_Ship.Sky_X - NewX = OldX,
         "Failed to move player ship in X axis");
      Assert
        (Player_Ship.Sky_Y - NewY = OldY,
         "Failed to move player ship in Y axis");
      Player_Ship.Sky_X := OldX;
      Player_Ship.Sky_Y := OldY;
      Player_Ship.Speed := DOCKED;

--  begin read only
   end Test_Move_Ship_test_moveship;
--  end read only

--  begin read only
   function Wrap_Test_Change_Ship_Speed_e4d52a_17b968
     (Speed_Value: Ship_Speed) return String is
   begin
      declare
         Test_Change_Ship_Speed_e4d52a_17b968_Result: constant String :=
           GNATtest_Generated.GNATtest_Standard.Ships.Movement
             .Change_Ship_Speed
             (Speed_Value);
      begin
         return Test_Change_Ship_Speed_e4d52a_17b968_Result;
      end;
   end Wrap_Test_Change_Ship_Speed_e4d52a_17b968;
--  end read only

--  begin read only
   procedure Test_Change_Ship_Speed_test_changeshipspeed
     (Gnattest_T: in out Test);
   procedure Test_Change_Ship_Speed_e4d52a_17b968
     (Gnattest_T: in out Test) renames
     Test_Change_Ship_Speed_test_changeshipspeed;
--  id:2.2/e4d52a3661ce3cc9/Change_Ship_Speed/1/0/test_changeshipspeed/
   procedure Test_Change_Ship_Speed_test_changeshipspeed
     (Gnattest_T: in out Test) is
      function Change_Ship_Speed(Speed_Value: Ship_Speed) return String renames
        Wrap_Test_Change_Ship_Speed_e4d52a_17b968;
--  end read only

      pragma Unreferenced(Gnattest_T);
      Message: Unbounded_String;

   begin

      Player_Ship.Crew(2).Order := PILOT;
      Player_Ship.Crew(3).Order := ENGINEER;
      Message := To_Unbounded_String(Change_Ship_Speed(FULL_SPEED));
      if Message /= Null_Unbounded_String then
         Ada.Text_IO.Put_Line(To_String(Message));
         Assert(False, "Failed to change speed of docked ship.");
      end if;
      Player_Ship.Crew(2).Order := PILOT;
      Player_Ship.Crew(3).Order := ENGINEER;
      Message := To_Unbounded_String(Dock_Ship(False));
      if Message /= Null_Unbounded_String then
         Ada.Text_IO.Put_Line(To_String(Message));
         Assert(False, "Failed to dock ship again.");
      end if;
      Player_Ship.Crew(2).Order := PILOT;
      Player_Ship.Crew(3).Order := ENGINEER;
      Message := To_Unbounded_String(Change_Ship_Speed(FULL_STOP));
      if Message /= Null_Unbounded_String then
         Ada.Text_IO.Put_Line(To_String(Message));
         Assert(False, "Failed to change speed of ship.");
      end if;
      Player_Ship.Crew(2).Order := PILOT;
      Player_Ship.Crew(3).Order := ENGINEER;
      Message := To_Unbounded_String(Dock_Ship(True));
      if Message /= Null_Unbounded_String then
         Ada.Text_IO.Put_Line(To_String(Message));
         Assert(False, "Failed to dock ship again second time.");
      end if;

--  begin read only
   end Test_Change_Ship_Speed_test_changeshipspeed;
--  end read only

--  begin read only
--  id:2.2/02/
--
--  This section can be used to add elaboration code for the global state.
--
begin
--  end read only
   null;
--  begin read only
--  end read only
end Ships.Movement.Test_Data.Tests;
