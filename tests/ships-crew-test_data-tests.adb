--  This package has been generated automatically by GNATtest.
--  You are allowed to add your code to the bodies of test routines.
--  Such changes will be kept during further regeneration of this file.
--  All code placed outside of test routine bodies will be lost. The
--  code intended to set up and tear down the test environment should be
--  placed into Ships.Crew.Test_Data.

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
package body Ships.Crew.Test_Data.Tests is

--  begin read only
--  id:2.2/01/
--
--  This section can be used to add global variables and other elements.
--
--  end read only

--  begin read only
--  end read only
--  begin read only
   function Wrap_Test_GetSkillLevel_f7e690_420873
     (Member: Member_Data; SkillIndex: Skills_Amount_Range)
      return Skill_Range is
   begin
      begin
         pragma Assert(SkillIndex in 1 .. Skills_Amount);
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "req_sloc(ships-crew.ads:0):Test_GetSkillLevel test requirement violated");
      end;
      declare
         Test_GetSkillLevel_f7e690_420873_Result: constant Skill_Range :=
           GNATtest_Generated.GNATtest_Standard.Ships.Crew.GetSkillLevel
             (Member, SkillIndex);
      begin
         begin
            pragma Assert(True);
            null;
         exception
            when System.Assertions.Assert_Failure =>
               AUnit.Assertions.Assert
                 (False,
                  "ens_sloc(ships-crew.ads:0:):Test_GetSkillLevel test commitment violated");
         end;
         return Test_GetSkillLevel_f7e690_420873_Result;
      end;
   end Wrap_Test_GetSkillLevel_f7e690_420873;
--  end read only

--  begin read only
   procedure Test_GetSkillLevel_test_getskilllevel(Gnattest_T: in out Test);
   procedure Test_GetSkillLevel_f7e690_420873(Gnattest_T: in out Test) renames
     Test_GetSkillLevel_test_getskilllevel;
--  id:2.2/f7e690bba6071759/GetSkillLevel/1/0/test_getskilllevel/
   procedure Test_GetSkillLevel_test_getskilllevel(Gnattest_T: in out Test) is
      function GetSkillLevel
        (Member: Member_Data; SkillIndex: Skills_Amount_Range)
         return Skill_Range renames
        Wrap_Test_GetSkillLevel_f7e690_420873;
--  end read only

      pragma Unreferenced(Gnattest_T);

   begin

      Assert
        (GetSkillLevel(Player_Ship.Crew(1), 1) = 0,
         "Failed to get real level of not owned skill.");
      Assert
        (GetSkillLevel(Player_Ship.Crew(1), 4) = 9,
         "Failed to get real level of skill.");

--  begin read only
   end Test_GetSkillLevel_test_getskilllevel;
--  end read only

--  begin read only
   procedure Wrap_Test_Death_af2fea_acf44b
     (MemberIndex: Crew_Container.Extended_Index; Reason: Unbounded_String;
      Ship: in out Ship_Record; CreateBody: Boolean := True) is
   begin
      begin
         pragma Assert
           ((MemberIndex in Ship.Crew.First_Index .. Ship.Crew.Last_Index and
             Reason /= Null_Unbounded_String));
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "req_sloc(ships-crew.ads:0):Test_Death test requirement violated");
      end;
      GNATtest_Generated.GNATtest_Standard.Ships.Crew.Death
        (MemberIndex, Reason, Ship, CreateBody);
      begin
         pragma Assert(True);
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "ens_sloc(ships-crew.ads:0:):Test_Death test commitment violated");
      end;
   end Wrap_Test_Death_af2fea_acf44b;
--  end read only

--  begin read only
   procedure Test_Death_test_death(Gnattest_T: in out Test);
   procedure Test_Death_af2fea_acf44b(Gnattest_T: in out Test) renames
     Test_Death_test_death;
--  id:2.2/af2fea911992db88/Death/1/0/test_death/
   procedure Test_Death_test_death(Gnattest_T: in out Test) is
      procedure Death
        (MemberIndex: Crew_Container.Extended_Index; Reason: Unbounded_String;
         Ship: in out Ship_Record; CreateBody: Boolean := True) renames
        Wrap_Test_Death_af2fea_acf44b;
--  end read only

      pragma Unreferenced(Gnattest_T);
      Crew: constant Crew_Container.Vector := Player_Ship.Crew;
      Amount: constant Positive := Positive(Player_Ship.Cargo.Length);

   begin

      Death(2, To_Unbounded_String("Test death"), Player_Ship);
      Assert
        (Player_Ship.Crew.Length + 1 = Crew.Length,
         "Failed to remove crew member on death.");
      Assert
        (Amount + 1 = Positive(Player_Ship.Cargo.Length),
         "Failed to add body of dead crew member.");
      Player_Ship.Crew := Crew;

--  begin read only
   end Test_Death_test_death;
--  end read only

--  begin read only
   procedure Wrap_Test_DeleteMember_9fa01a_2b7835
     (MemberIndex: Crew_Container.Extended_Index; Ship: in out Ship_Record) is
   begin
      begin
         pragma Assert
           (MemberIndex in Ship.Crew.First_Index .. Ship.Crew.Last_Index);
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "req_sloc(ships-crew.ads:0):Test_DeleteMember test requirement violated");
      end;
      GNATtest_Generated.GNATtest_Standard.Ships.Crew.DeleteMember
        (MemberIndex, Ship);
      begin
         pragma Assert(True);
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "ens_sloc(ships-crew.ads:0:):Test_DeleteMember test commitment violated");
      end;
   end Wrap_Test_DeleteMember_9fa01a_2b7835;
--  end read only

--  begin read only
   procedure Test_DeleteMember_test_deletemember(Gnattest_T: in out Test);
   procedure Test_DeleteMember_9fa01a_2b7835(Gnattest_T: in out Test) renames
     Test_DeleteMember_test_deletemember;
--  id:2.2/9fa01a2852ec5515/DeleteMember/1/0/test_deletemember/
   procedure Test_DeleteMember_test_deletemember(Gnattest_T: in out Test) is
      procedure DeleteMember
        (MemberIndex: Crew_Container.Extended_Index;
         Ship: in out Ship_Record) renames
        Wrap_Test_DeleteMember_9fa01a_2b7835;
--  end read only

      pragma Unreferenced(Gnattest_T);
      Crew: constant Crew_Container.Vector := Player_Ship.Crew;

   begin

      DeleteMember(2, Player_Ship);
      Assert
        (Crew.Length = Player_Ship.Crew.Length + 1,
         "Failed to delete member from the player ship crew.");
      Player_Ship.Crew := Crew;

--  begin read only
   end Test_DeleteMember_test_deletemember;
--  end read only

--  begin read only
   function Wrap_Test_FindMember_b270de_fa15b4
     (Order: Crew_Orders; Crew: Crew_Container.Vector := Player_Ship.Crew)
      return Crew_Container.Extended_Index is
   begin
      begin
         pragma Assert(True);
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "req_sloc(ships-crew.ads:0):Test_FindMember test requirement violated");
      end;
      declare
         Test_FindMember_b270de_fa15b4_Result: constant Crew_Container
           .Extended_Index :=
           GNATtest_Generated.GNATtest_Standard.Ships.Crew.FindMember
             (Order, Crew);
      begin
         begin
            pragma Assert
              (Test_FindMember_b270de_fa15b4_Result <= Crew.Last_Index);
            null;
         exception
            when System.Assertions.Assert_Failure =>
               AUnit.Assertions.Assert
                 (False,
                  "ens_sloc(ships-crew.ads:0:):Test_FindMember test commitment violated");
         end;
         return Test_FindMember_b270de_fa15b4_Result;
      end;
   end Wrap_Test_FindMember_b270de_fa15b4;
--  end read only

--  begin read only
   procedure Test_FindMember_test_findmember(Gnattest_T: in out Test);
   procedure Test_FindMember_b270de_fa15b4(Gnattest_T: in out Test) renames
     Test_FindMember_test_findmember;
--  id:2.2/b270debda44d8b87/FindMember/1/0/test_findmember/
   procedure Test_FindMember_test_findmember(Gnattest_T: in out Test) is
      function FindMember
        (Order: Crew_Orders; Crew: Crew_Container.Vector := Player_Ship.Crew)
         return Crew_Container.Extended_Index renames
        Wrap_Test_FindMember_b270de_fa15b4;
--  end read only

      pragma Unreferenced(Gnattest_T);

   begin

      Assert
        (FindMember(Talk) = 1,
         "Failed to find crew member with selected order.");
      Assert
        (FindMember(Defend) = 0,
         "Failed to not find crew member with selected order.");

--  begin read only
   end Test_FindMember_test_findmember;
--  end read only

--  begin read only
   procedure Wrap_Test_GiveOrders_fd3de0_56eedb
     (Ship: in out Ship_Record; MemberIndex: Crew_Container.Extended_Index;
      GivenOrder: Crew_Orders;
      ModuleIndex: Modules_Container.Extended_Index := 0;
      CheckPriorities: Boolean := True) is
   begin
      begin
         pragma Assert
           ((MemberIndex in Ship.Crew.First_Index .. Ship.Crew.Last_Index and
             ModuleIndex <= Ship.Modules.Last_Index));
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "req_sloc(ships-crew.ads:0):Test_GiveOrders test requirement violated");
      end;
      GNATtest_Generated.GNATtest_Standard.Ships.Crew.GiveOrders
        (Ship, MemberIndex, GivenOrder, ModuleIndex, CheckPriorities);
      begin
         pragma Assert(True);
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "ens_sloc(ships-crew.ads:0:):Test_GiveOrders test commitment violated");
      end;
   end Wrap_Test_GiveOrders_fd3de0_56eedb;
--  end read only

--  begin read only
   procedure Test_GiveOrders_test_giveorders(Gnattest_T: in out Test);
   procedure Test_GiveOrders_fd3de0_56eedb(Gnattest_T: in out Test) renames
     Test_GiveOrders_test_giveorders;
--  id:2.2/fd3de09254cf8892/GiveOrders/1/0/test_giveorders/
   procedure Test_GiveOrders_test_giveorders(Gnattest_T: in out Test) is
      procedure GiveOrders
        (Ship: in out Ship_Record; MemberIndex: Crew_Container.Extended_Index;
         GivenOrder: Crew_Orders;
         ModuleIndex: Modules_Container.Extended_Index := 0;
         CheckPriorities: Boolean := True) renames
        Wrap_Test_GiveOrders_fd3de0_56eedb;
--  end read only

      pragma Unreferenced(Gnattest_T);
      EnemyShip: Ship_Record :=
        Create_Ship
          (To_Unbounded_String("2"), Null_Unbounded_String, 10, 10,
           FULL_SPEED);
   begin

      GiveOrders(Player_Ship, 1, Rest);
      Assert
        (Player_Ship.Crew(1).Order = Talk, "Failed to give order to player.");
      GiveOrders(Player_Ship, 4, Rest);
      Assert
        (Player_Ship.Crew(4).Order = Rest, "Failed to give order to gunner.");
      EnemyShip.Crew(1).Morale(1) := 5;
      GiveOrders(EnemyShip, 1, Talk);
      Assert(True, "This test can only crash");

--  begin read only
   end Test_GiveOrders_test_giveorders;
--  end read only

--  begin read only
   procedure Wrap_Test_UpdateOrders_388ab3_cad1b0
     (Ship: in out Ship_Record; Combat: Boolean := False) is
   begin
      GNATtest_Generated.GNATtest_Standard.Ships.Crew.UpdateOrders
        (Ship, Combat);
   end Wrap_Test_UpdateOrders_388ab3_cad1b0;
--  end read only

--  begin read only
   procedure Test_UpdateOrders_test_updateorders(Gnattest_T: in out Test);
   procedure Test_UpdateOrders_388ab3_cad1b0(Gnattest_T: in out Test) renames
     Test_UpdateOrders_test_updateorders;
--  id:2.2/388ab351ab0e26d6/UpdateOrders/1/0/test_updateorders/
   procedure Test_UpdateOrders_test_updateorders(Gnattest_T: in out Test) is
      procedure UpdateOrders
        (Ship: in out Ship_Record; Combat: Boolean := False) renames
        Wrap_Test_UpdateOrders_388ab3_cad1b0;
--  end read only

      pragma Unreferenced(Gnattest_T);

   begin

      GiveOrders(Player_Ship, 1, Rest, 0, False);
      UpdateOrders(Player_Ship);
      Assert
        (Player_Ship.Crew(1).Order = Talk,
         "Failed to update orders for player ship crew.");

--  begin read only
   end Test_UpdateOrders_test_updateorders;
--  end read only

--  begin read only
   procedure Wrap_Test_UpdateMorale_5618e2_5147b1
     (Ship: in out Ship_Record; MemberIndex: Crew_Container.Extended_Index;
      Value: Integer) is
   begin
      begin
         pragma Assert
           (MemberIndex in Ship.Crew.First_Index .. Ship.Crew.Last_Index);
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "req_sloc(ships-crew.ads:0):Test_UpdateMorale test requirement violated");
      end;
      GNATtest_Generated.GNATtest_Standard.Ships.Crew.UpdateMorale
        (Ship, MemberIndex, Value);
      begin
         pragma Assert(True);
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "ens_sloc(ships-crew.ads:0:):Test_UpdateMorale test commitment violated");
      end;
   end Wrap_Test_UpdateMorale_5618e2_5147b1;
--  end read only

--  begin read only
   procedure Test_UpdateMorale_test_updatemorale(Gnattest_T: in out Test);
   procedure Test_UpdateMorale_5618e2_5147b1(Gnattest_T: in out Test) renames
     Test_UpdateMorale_test_updatemorale;
--  id:2.2/5618e2d744921821/UpdateMorale/1/0/test_updatemorale/
   procedure Test_UpdateMorale_test_updatemorale(Gnattest_T: in out Test) is
      procedure UpdateMorale
        (Ship: in out Ship_Record; MemberIndex: Crew_Container.Extended_Index;
         Value: Integer) renames
        Wrap_Test_UpdateMorale_5618e2_5147b1;
--  end read only

      pragma Unreferenced(Gnattest_T);
      OldMorale: constant Natural := Player_Ship.Crew(1).Morale(2);
      OldLevel: constant Natural := Player_Ship.Crew(1).Morale(1);

   begin

      UpdateMorale(Player_Ship, 1, 1);
      Assert
        (Player_Ship.Crew(1).Morale(2) - 1 = OldMorale or
         Player_Ship.Crew(1).Morale(1) - 1 = OldLevel,
         "Failed to raise player morale.");
      UpdateMorale(Player_Ship, 1, -1);
      Assert
        (Player_Ship.Crew(1).Morale(2) = OldMorale,
         "Failed to lower player morale.");

--  begin read only
   end Test_UpdateMorale_test_updatemorale;
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
end Ships.Crew.Test_Data.Tests;
