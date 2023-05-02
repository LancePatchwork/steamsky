--  This package has been generated automatically by GNATtest.
--  You are allowed to add your code to the bodies of test routines.
--  Such changes will be kept during further regeneration of this file.
--  All code placed outside of test routine bodies will be lost. The
--  code intended to set up and tear down the test environment should be
--  placed into Events.Test_Data.

with AUnit.Assertions; use AUnit.Assertions;
with System.Assertions;

--  begin read only
--  id:2.2/00/
--
--  This section can be used to add with clauses if necessary.
--
--  end read only

with Bases; use Bases;

--  begin read only
--  end read only
package body Events.Test_Data.Tests is

--  begin read only
--  id:2.2/01/
--
--  This section can be used to add global variables and other elements.
--
--  end read only

--  begin read only
--  end read only
--  begin read only
   function Wrap_Test_Check_For_Event_73edc5_e01b25 return Boolean is
   begin
      declare
         Test_Check_For_Event_73edc5_e01b25_Result: constant Boolean :=
           GNATtest_Generated.GNATtest_Standard.Events.Check_For_Event;
      begin
         return Test_Check_For_Event_73edc5_e01b25_Result;
      end;
   end Wrap_Test_Check_For_Event_73edc5_e01b25;
--  end read only

--  begin read only
   procedure Test_Check_For_Event_test_checkforevent(Gnattest_T: in out Test);
   procedure Test_Check_For_Event_73edc5_e01b25
     (Gnattest_T: in out Test) renames
     Test_Check_For_Event_test_checkforevent;
--  id:2.2/73edc53664733282/Check_For_Event/1/0/test_checkforevent/
   procedure Test_Check_For_Event_test_checkforevent
     (Gnattest_T: in out Test) is
      function Check_For_Event return Boolean renames
        Wrap_Test_Check_For_Event_73edc5_e01b25;
--  end read only

      pragma Unreferenced(Gnattest_T);

   begin

      if Check_For_Event then
         null;
      end if;
      Assert(True, "This test can only crash");

--  begin read only
   end Test_Check_For_Event_test_checkforevent;
--  end read only

--  begin read only
   procedure Wrap_Test_Delete_Event_626bfb_8845a2(Event_Index: Positive) is
   begin
      begin
         pragma Assert(Event_Index <= Events_List.Last_Index);
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "req_sloc(events.ads:0):Test_DeleteEvent test requirement violated");
      end;
      GNATtest_Generated.GNATtest_Standard.Events.Delete_Event(Event_Index);
      begin
         pragma Assert(True);
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "ens_sloc(events.ads:0:):Test_DeleteEvent test commitment violated");
      end;
   end Wrap_Test_Delete_Event_626bfb_8845a2;
--  end read only

--  begin read only
   procedure Test_Delete_Event_test_deleteevent(Gnattest_T: in out Test);
   procedure Test_Delete_Event_626bfb_8845a2(Gnattest_T: in out Test) renames
     Test_Delete_Event_test_deleteevent;
--  id:2.2/626bfb6f85c2bcf4/Delete_Event/1/0/test_deleteevent/
   procedure Test_Delete_Event_test_deleteevent(Gnattest_T: in out Test) is
      procedure Delete_Event(Event_Index: Positive) renames
        Wrap_Test_Delete_Event_626bfb_8845a2;
--  end read only

      pragma Unreferenced(Gnattest_T);
      Amount: constant Natural := Natural(Events_List.Length);

   begin

      Delete_Event(1);
      Assert(Natural(Events_List.Length) < Amount, "Failed to delete event.");

--  begin read only
   end Test_Delete_Event_test_deleteevent;
--  end read only

--  begin read only
   procedure Wrap_Test_Generate_Traders_4cda02_5d00a3 is
   begin
      GNATtest_Generated.GNATtest_Standard.Events.Generate_Traders;
   end Wrap_Test_Generate_Traders_4cda02_5d00a3;
--  end read only

--  begin read only
   procedure Test_Generate_Traders_test_generatetraders
     (Gnattest_T: in out Test);
   procedure Test_Generate_Traders_4cda02_5d00a3
     (Gnattest_T: in out Test) renames
     Test_Generate_Traders_test_generatetraders;
--  id:2.2/4cda0206f4f34b65/Generate_Traders/1/0/test_generatetraders/
   procedure Test_Generate_Traders_test_generatetraders
     (Gnattest_T: in out Test) is
      procedure Generate_Traders renames
        Wrap_Test_Generate_Traders_4cda02_5d00a3;
--  end read only

      pragma Unreferenced(Gnattest_T);

   begin

      Generate_Traders;
      Assert(True, "This test can only crash.");

--  begin read only
   end Test_Generate_Traders_test_generatetraders;
--  end read only

--  begin read only
   procedure Wrap_Test_Recover_Base_d738af_a032fd(Base_Index: Bases_Range) is
   begin
      GNATtest_Generated.GNATtest_Standard.Events.Recover_Base(Base_Index);
   end Wrap_Test_Recover_Base_d738af_a032fd;
--  end read only

--  begin read only
   procedure Test_Recover_Base_test_recoverbase(Gnattest_T: in out Test);
   procedure Test_Recover_Base_d738af_a032fd(Gnattest_T: in out Test) renames
     Test_Recover_Base_test_recoverbase;
--  id:2.2/d738af38c924128a/Recover_Base/1/0/test_recoverbase/
   procedure Test_Recover_Base_test_recoverbase(Gnattest_T: in out Test) is
      procedure Recover_Base(Base_Index: Bases_Range) renames
        Wrap_Test_Recover_Base_d738af_a032fd;
--  end read only

      pragma Unreferenced(Gnattest_T);

   begin

      for I in Sky_Bases'Range loop
         if Sky_Bases(I).Population = 0 then
            Recover_Base(I);
            exit;
         end if;
      end loop;
      Assert(True, "This test can only crash.");

--  begin read only
   end Test_Recover_Base_test_recoverbase;
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
end Events.Test_Data.Tests;
