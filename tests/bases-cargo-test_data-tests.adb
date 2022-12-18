--  This package has been generated automatically by GNATtest.
--  You are allowed to add your code to the bodies of test routines.
--  Such changes will be kept during further regeneration of this file.
--  All code placed outside of test routine bodies will be lost. The
--  code intended to set up and tear down the test environment should be
--  placed into Bases.Cargo.Test_Data.

with AUnit.Assertions; use AUnit.Assertions;
with System.Assertions;

--  begin read only
--  id:2.2/00/
--
--  This section can be used to add with clauses if necessary.
--
--  end read only

with Maps; use Maps;

--  begin read only
--  end read only
package body Bases.Cargo.Test_Data.Tests is

--  begin read only
--  id:2.2/01/
--
--  This section can be used to add global variables and other elements.
--
--  end read only

--  begin read only
--  end read only
--  begin read only
   procedure Wrap_Test_Generate_Cargo_bedd31_021eea is
   begin
      GNATtest_Generated.GNATtest_Standard.Bases.Cargo.Generate_Cargo;
   end Wrap_Test_Generate_Cargo_bedd31_021eea;
--  end read only

--  begin read only
   procedure Test_Generate_Cargo_test_generatecargo(Gnattest_T: in out Test);
   procedure Test_Generate_Cargo_bedd31_021eea(Gnattest_T: in out Test) renames
     Test_Generate_Cargo_test_generatecargo;
--  id:2.2/bedd31198f3fb6a9/Generate_Cargo/1/0/test_generatecargo/
   procedure Test_Generate_Cargo_test_generatecargo(Gnattest_T: in out Test) is
      procedure Generate_Cargo renames Wrap_Test_Generate_Cargo_bedd31_021eea;
--  end read only

      pragma Unreferenced(Gnattest_T);
      BaseIndex: constant Positive :=
        Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Base_Index;

   begin

      BaseCargo_Container.Clear(Container => Sky_Bases(BaseIndex).Cargo);
      Generate_Cargo;
      Assert
        (BaseCargo_Container.Length(Sky_Bases(BaseIndex).Cargo) > 0,
         "Failed to generate base cargo.");

--  begin read only
   end Test_Generate_Cargo_test_generatecargo;
--  end read only

--  begin read only
   procedure Wrap_Test_Update_Base_Cargo_a5e235_1e1787
     (Proto_Index: Natural := 0; Amount: Integer;
      Durability: Items_Durability := Default_Item_Durability;
      Cargo_Index: Inventory_Container.Extended_Index := 0) is
   begin
      GNATtest_Generated.GNATtest_Standard.Bases.Cargo.Update_Base_Cargo
        (Proto_Index, Amount, Durability, Cargo_Index);
   end Wrap_Test_Update_Base_Cargo_a5e235_1e1787;
--  end read only

--  begin read only
   procedure Test_Update_Base_Cargo_test_updatebasecargo
     (Gnattest_T: in out Test);
   procedure Test_Update_Base_Cargo_a5e235_1e1787
     (Gnattest_T: in out Test) renames
     Test_Update_Base_Cargo_test_updatebasecargo;
--  id:2.2/a5e23599823e81c0/Update_Base_Cargo/1/0/test_updatebasecargo/
   procedure Test_Update_Base_Cargo_test_updatebasecargo
     (Gnattest_T: in out Test) is
      procedure Update_Base_Cargo
        (Proto_Index: Natural := 0; Amount: Integer;
         Durability: Items_Durability := Default_Item_Durability;
         Cargo_Index: Inventory_Container.Extended_Index := 0) renames
        Wrap_Test_Update_Base_Cargo_a5e235_1e1787;
--  end read only

      pragma Unreferenced(Gnattest_T);
      BaseIndex: constant Positive :=
        Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Base_Index;
      Amount: Positive;
      ProtoIndex: Natural;

   begin

      BaseCargo_Container.Clear(Container => Sky_Bases(BaseIndex).Cargo);
      Generate_Cargo;
      Amount :=
        BaseCargo_Container.Element(Sky_Bases(BaseIndex).Cargo, 1).Amount - 1;
      ProtoIndex :=
        BaseCargo_Container.Element(Sky_Bases(BaseIndex).Cargo, 1).Proto_Index;
      Update_Base_Cargo(ProtoIndex, -1);
      Assert
        (BaseCargo_Container.Element(Sky_Bases(BaseIndex).Cargo, 1).Amount =
         Amount,
         "Failed to update base cargo with proto index.");
      Update_Base_Cargo(Cargo_Index => 1, Amount => -1);
      Assert
        (BaseCargo_Container.Element(Sky_Bases(BaseIndex).Cargo, 1).Amount =
         Amount - 1,
         "Failed to update base cargo with cargo index.");

--  begin read only
   end Test_Update_Base_Cargo_test_updatebasecargo;
--  end read only

--  begin read only
   function Wrap_Test_Find_Base_Cargo_6c7fc4_b84903
     (Proto_Index: Natural;
      Durability: Items_Durability := Items_Durability'Last) return Natural is
   begin
      begin
         pragma Assert(Proto_Index > 0);
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "req_sloc(bases-cargo.ads:0):Test_FindBaseCargo test requirement violated");
      end;
      declare
         Test_Find_Base_Cargo_6c7fc4_b84903_Result: constant Natural :=
           GNATtest_Generated.GNATtest_Standard.Bases.Cargo.Find_Base_Cargo
             (Proto_Index, Durability);
      begin
         begin
            pragma Assert(True);
            null;
         exception
            when System.Assertions.Assert_Failure =>
               AUnit.Assertions.Assert
                 (False,
                  "ens_sloc(bases-cargo.ads:0:):Test_FindBaseCargo test commitment violated");
         end;
         return Test_Find_Base_Cargo_6c7fc4_b84903_Result;
      end;
   end Wrap_Test_Find_Base_Cargo_6c7fc4_b84903;
--  end read only

--  begin read only
   procedure Test_Find_Base_Cargo_test_findbasecargo(Gnattest_T: in out Test);
   procedure Test_Find_Base_Cargo_6c7fc4_b84903
     (Gnattest_T: in out Test) renames
     Test_Find_Base_Cargo_test_findbasecargo;
--  id:2.2/6c7fc4d411a995d6/Find_Base_Cargo/1/0/test_findbasecargo/
   procedure Test_Find_Base_Cargo_test_findbasecargo
     (Gnattest_T: in out Test) is
      function Find_Base_Cargo
        (Proto_Index: Natural;
         Durability: Items_Durability := Items_Durability'Last)
         return Natural renames
        Wrap_Test_Find_Base_Cargo_6c7fc4_b84903;
--  end read only

      pragma Unreferenced(Gnattest_T);
      BaseIndex: constant Positive :=
        Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Base_Index;

   begin

      BaseCargo_Container.Clear(Sky_Bases(BaseIndex).Cargo);
      Generate_Cargo;
      Assert(Find_Base_Cargo(1) = 1, "Failed to find charcoal.");
      Assert(Find_Base_Cargo(40) = 0, "Found item which is not in cargo.");
      Assert(Find_Base_Cargo(490) = 0, "Found item which not exists.");

--  begin read only
   end Test_Find_Base_Cargo_test_findbasecargo;
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
end Bases.Cargo.Test_Data.Tests;
