--  This package is intended to set up and tear down  the test environment.
--  Once created by GNATtest, this package will never be overwritten
--  automatically. Contents of this package can be modified in any way
--  except for sections surrounded by a 'read only' marker.

with Ada.Directories; use Ada.Directories;
with Ada.Text_IO; use Ada.Text_IO;
with Config; use Config;
with Log; use Log;

package body Game.Test_Data is

   procedure Set_Up(Gnattest_T: in out Test) is
      pragma Unreferenced(Gnattest_T);
   begin
      if Data_Directory = To_Unbounded_String("../../bin/data/") then
         return;
      end if;
      Data_Directory := To_Unbounded_String("../../bin/data/");
      Save_Directory := To_Unbounded_String("../../bin/data/saves/");
      Create_Path(To_String(Save_Directory));
      Doc_Directory := To_Unbounded_String("../../bin/doc/");
      Mods_Directory := To_Unbounded_String("../../bin/data/mods/");
      Themes_Directory := To_Unbounded_String("../../bin/data/themes/");
      Debug_Mode := EVERYTHING;
      Start_Logging;
      Load_Config;
      declare
         Message: constant String := Load_Game_Data;
      begin
         if Message'Length > 0 then
            Put_Line(Message);
         end if;
      end;
      New_Game_Settings.Player_Faction := To_Unbounded_String("POLEIS");
      New_Game_Settings.Player_Career := To_Unbounded_String("general");
      New_Game_Settings.Starting_Base := To_Unbounded_String("1");
      New_Game;
   end Set_Up;

   procedure Tear_Down(Gnattest_T: in out Test) is
      pragma Unreferenced(Gnattest_T);
   begin
      null;
   end Tear_Down;
end Game.Test_Data;
