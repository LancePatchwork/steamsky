--  This package has been generated automatically by GNATtest.
--  You are allowed to add your code to the bodies of test routines.
--  Such changes will be kept during further regeneration of this file.
--  All code placed outside of test routine bodies will be lost. The
--  code intended to set up and tear down the test environment should be
--  placed into Mobs.Test_Data.

with AUnit.Assertions; use AUnit.Assertions;
with System.Assertions;

--  begin read only
--  id:2.2/00/
--
--  This section can be used to add with clauses if necessary.
--
--  end read only

--  begin read only
--  end read only
package body Mobs.Test_Data.Tests is

--  begin read only
--  id:2.2/01/
--
--  This section can be used to add global variables and other elements.
--
--  end read only

--  begin read only
--  end read only
--  begin read only
   function Wrap_Test_Generate_Mob_cf8a16_7748b7
     (Mob_Index: ProtoMobs_Container.Extended_Index;
      Faction_Index: Tiny_String.Bounded_String) return Member_Data is
   begin
      begin
         pragma Assert
           ((Mob_Index > 0 and
             Mob_Index <
               ProtoMobs_Container.Last_Index(Container => Proto_Mobs_List)));
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "req_sloc(mobs.ads:0):Test_GenearateMob test requirement violated");
      end;
      declare
         Test_Generate_Mob_cf8a16_7748b7_Result: constant Member_Data :=
           GNATtest_Generated.GNATtest_Standard.Mobs.Generate_Mob
             (Mob_Index, Faction_Index);
      begin
         begin
            pragma Assert
              (Tiny_String.Length
                 (Source => Test_Generate_Mob_cf8a16_7748b7_Result.Name) >
               0);
            null;
         exception
            when System.Assertions.Assert_Failure =>
               AUnit.Assertions.Assert
                 (False,
                  "ens_sloc(mobs.ads:0:):Test_GenearateMob test commitment violated");
         end;
         return Test_Generate_Mob_cf8a16_7748b7_Result;
      end;
   end Wrap_Test_Generate_Mob_cf8a16_7748b7;
--  end read only

--  begin read only
   procedure Test_Generate_Mob_test_genearatemob(Gnattest_T: in out Test);
   procedure Test_Generate_Mob_cf8a16_7748b7(Gnattest_T: in out Test) renames
     Test_Generate_Mob_test_genearatemob;
--  id:2.2/cf8a161a4fb3a01b/Generate_Mob/1/0/test_genearatemob/
   procedure Test_Generate_Mob_test_genearatemob(Gnattest_T: in out Test) is
      function Generate_Mob
        (Mob_Index: ProtoMobs_Container.Extended_Index;
         Faction_Index: Tiny_String.Bounded_String) return Member_Data renames
        Wrap_Test_Generate_Mob_cf8a16_7748b7;
--  end read only

      pragma Unreferenced(Gnattest_T);
      NewMob: Member_Data
        (Amount_Of_Attributes => Attributes_Amount,
         Amount_Of_Skills => Skills_Amount);

   begin

      NewMob := Generate_Mob(5, Tiny_String.To_Bounded_String("POLEIS"));
      Assert(NewMob.Attributes(1).Level = 2, "Failed to generate mob.");
      Assert
        (NewMob.Order_Time = 15,
         "Failed to set order time for the generated mob.");

--  begin read only
   end Test_Generate_Mob_test_genearatemob;
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
end Mobs.Test_Data.Tests;
