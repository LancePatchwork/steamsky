--  This package has been generated automatically by GNATtest.
--  You are allowed to add your code to the bodies of test routines.
--  Such changes will be kept during further regeneration of this file.
--  All code placed outside of test routine bodies will be lost. The
--  code intended to set up and tear down the test environment should be
--  placed into Crew.Inventory.Test_Data.

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
package body Crew.Inventory.Test_Data.Tests is

--  begin read only
--  id:2.2/01/
--
--  This section can be used to add global variables and other elements.
--
--  end read only

--  begin read only
--  end read only
--  begin read only
   procedure Wrap_Test_UpdateInventory_95e772_c16560
     (MemberIndex: Positive; Amount: Integer;
      ProtoIndex: Tiny_String.Bounded_String :=
        Tiny_String.Null_Bounded_String;
      Durability: Items_Durability := 0; InventoryIndex, Price: Natural := 0;
      Ship: in out Ship_Record) is
   begin
      begin
         pragma Assert
           ((MemberIndex <= Ship.Crew.Last_Index and
             InventoryIndex <=
               Inventory_Container.Last_Index
                 (Container => Ship.Crew(MemberIndex).Inventory)));
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "req_sloc(crew-inventory.ads:0):Test_UpdateInventory test requirement violated");
      end;
      GNATtest_Generated.GNATtest_Standard.Crew.Inventory.UpdateInventory
        (MemberIndex, Amount, ProtoIndex, Durability, InventoryIndex, Price,
         Ship);
      begin
         pragma Assert(True);
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "ens_sloc(crew-inventory.ads:0:):Test_UpdateInventory test commitment violated");
      end;
   end Wrap_Test_UpdateInventory_95e772_c16560;
--  end read only

--  begin read only
   procedure Test_UpdateInventory_test_updateinventory
     (Gnattest_T: in out Test);
   procedure Test_UpdateInventory_95e772_c16560
     (Gnattest_T: in out Test) renames
     Test_UpdateInventory_test_updateinventory;
--  id:2.2/95e772dd71711094/UpdateInventory/1/0/test_updateinventory/
   procedure Test_UpdateInventory_test_updateinventory
     (Gnattest_T: in out Test) is
      procedure UpdateInventory
        (MemberIndex: Positive; Amount: Integer;
         ProtoIndex: Tiny_String.Bounded_String :=
           Tiny_String.Null_Bounded_String;
         Durability: Items_Durability := 0;
         InventoryIndex, Price: Natural := 0; Ship: in out Ship_Record) renames
        Wrap_Test_UpdateInventory_95e772_c16560;
--  end read only

      pragma Unreferenced(Gnattest_T);
      Amount: constant Positive :=
        Positive
          (Inventory_Container.Length
             (Container => Player_Ship.Crew(1).Inventory));

   begin

      UpdateInventory
        (1, 1, Tiny_String.To_Bounded_String("1"), Ship => Player_Ship);
      Assert
        (Positive
           (Inventory_Container.Length
              (Container => Player_Ship.Crew(1).Inventory)) =
         Amount + 1,
         "Failed to add item to crew member inventory.");
      UpdateInventory
        (1, -1, Tiny_String.To_Bounded_String("1"), Ship => Player_Ship);
      Assert
        (Positive
           (Inventory_Container.Length
              (Container => Player_Ship.Crew(1).Inventory)) =
         Amount,
         "Failed to remove item from crew member inventory.");
      begin
         UpdateInventory
           (1, 10_000, Tiny_String.To_Bounded_String("1"),
            Ship => Player_Ship);
         Assert
           (False,
            "Failed to not add too much items to the crew member inventory.");
      exception
         when Crew_No_Space_Error =>
            null;
         when others =>
            Assert
              (False,
               "Exception when trying to add more items than crew member can take.");
      end;

--  begin read only
   end Test_UpdateInventory_test_updateinventory;
--  end read only

--  begin read only
   function Wrap_Test_FreeInventory_df8fe5_1b9261
     (MemberIndex: Positive; Amount: Integer) return Integer is
   begin
      begin
         pragma Assert(MemberIndex <= Player_Ship.Crew.Last_Index);
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "req_sloc(crew-inventory.ads:0):Test_FreeInventory test requirement violated");
      end;
      declare
         Test_FreeInventory_df8fe5_1b9261_Result: constant Integer :=
           GNATtest_Generated.GNATtest_Standard.Crew.Inventory.FreeInventory
             (MemberIndex, Amount);
      begin
         begin
            pragma Assert(True);
            null;
         exception
            when System.Assertions.Assert_Failure =>
               AUnit.Assertions.Assert
                 (False,
                  "ens_sloc(crew-inventory.ads:0:):Test_FreeInventory test commitment violated");
         end;
         return Test_FreeInventory_df8fe5_1b9261_Result;
      end;
   end Wrap_Test_FreeInventory_df8fe5_1b9261;
--  end read only

--  begin read only
   procedure Test_FreeInventory_test_freeinventory(Gnattest_T: in out Test);
   procedure Test_FreeInventory_df8fe5_1b9261(Gnattest_T: in out Test) renames
     Test_FreeInventory_test_freeinventory;
--  id:2.2/df8fe5d066a1fde9/FreeInventory/1/0/test_freeinventory/
   procedure Test_FreeInventory_test_freeinventory(Gnattest_T: in out Test) is
      function FreeInventory
        (MemberIndex: Positive; Amount: Integer) return Integer renames
        Wrap_Test_FreeInventory_df8fe5_1b9261;
--  end read only

      pragma Unreferenced(Gnattest_T);

   begin

      if FreeInventory(1, 0) /= 0 then
         Assert(True, "This test can only crash.");
      end if;

--  begin read only
   end Test_FreeInventory_test_freeinventory;
--  end read only

--  begin read only
   procedure Wrap_Test_TakeOffItem_a8b09e_8dba5e
     (MemberIndex, ItemIndex: Positive) is
   begin
      begin
         pragma Assert
           ((MemberIndex <= Player_Ship.Crew.Last_Index and
             ItemIndex <=
               Inventory_Container.Last_Index
                 (Container => Player_Ship.Crew(MemberIndex).Inventory)));
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "req_sloc(crew-inventory.ads:0):Test_TakeOffItem test requirement violated");
      end;
      GNATtest_Generated.GNATtest_Standard.Crew.Inventory.TakeOffItem
        (MemberIndex, ItemIndex);
      begin
         pragma Assert(True);
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "ens_sloc(crew-inventory.ads:0:):Test_TakeOffItem test commitment violated");
      end;
   end Wrap_Test_TakeOffItem_a8b09e_8dba5e;
--  end read only

--  begin read only
   procedure Test_TakeOffItem_test_takeoffitem(Gnattest_T: in out Test);
   procedure Test_TakeOffItem_a8b09e_8dba5e(Gnattest_T: in out Test) renames
     Test_TakeOffItem_test_takeoffitem;
--  id:2.2/a8b09e84477e626f/TakeOffItem/1/0/test_takeoffitem/
   procedure Test_TakeOffItem_test_takeoffitem(Gnattest_T: in out Test) is
      procedure TakeOffItem(MemberIndex, ItemIndex: Positive) renames
        Wrap_Test_TakeOffItem_a8b09e_8dba5e;
--  end read only

      pragma Unreferenced(Gnattest_T);

   begin

      TakeOffItem(1, 1);
      Assert
        (not ItemIsUsed(1, 1),
         "Failed to take off item from the player character.");

--  begin read only
   end Test_TakeOffItem_test_takeoffitem;
--  end read only

--  begin read only
   function Wrap_Test_ItemIsUsed_9a8ce5_97ea11
     (MemberIndex, ItemIndex: Positive) return Boolean is
   begin
      begin
         pragma Assert
           ((MemberIndex <= Player_Ship.Crew.Last_Index and
             ItemIndex <=
               Inventory_Container.Last_Index
                 (Container => Player_Ship.Crew(MemberIndex).Inventory)));
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "req_sloc(crew-inventory.ads:0):Test_ItemIsUsed test requirement violated");
      end;
      declare
         Test_ItemIsUsed_9a8ce5_97ea11_Result: constant Boolean :=
           GNATtest_Generated.GNATtest_Standard.Crew.Inventory.ItemIsUsed
             (MemberIndex, ItemIndex);
      begin
         begin
            pragma Assert(True);
            null;
         exception
            when System.Assertions.Assert_Failure =>
               AUnit.Assertions.Assert
                 (False,
                  "ens_sloc(crew-inventory.ads:0:):Test_ItemIsUsed test commitment violated");
         end;
         return Test_ItemIsUsed_9a8ce5_97ea11_Result;
      end;
   end Wrap_Test_ItemIsUsed_9a8ce5_97ea11;
--  end read only

--  begin read only
   procedure Test_ItemIsUsed_test_itemisused(Gnattest_T: in out Test);
   procedure Test_ItemIsUsed_9a8ce5_97ea11(Gnattest_T: in out Test) renames
     Test_ItemIsUsed_test_itemisused;
--  id:2.2/9a8ce5527fb6a663/ItemIsUsed/1/0/test_itemisused/
   procedure Test_ItemIsUsed_test_itemisused(Gnattest_T: in out Test) is
      function ItemIsUsed
        (MemberIndex, ItemIndex: Positive) return Boolean renames
        Wrap_Test_ItemIsUsed_9a8ce5_97ea11;
--  end read only

      pragma Unreferenced(Gnattest_T);

   begin

      Assert
        (ItemIsUsed(1, 1) = False, "Failed to detect that item is not used.");
      Assert(ItemIsUsed(1, 2) = True, "Failed to detect that item is used.");

--  begin read only
   end Test_ItemIsUsed_test_itemisused;
--  end read only

--  begin read only
   function Wrap_Test_FindTools_4d4951_18cba3
     (MemberIndex: Positive; ItemType: Tiny_String.Bounded_String;
      Order: Crew_Orders; ToolQuality: Positive := 100) return Natural is
   begin
      begin
         pragma Assert
           ((MemberIndex <= Player_Ship.Crew.Last_Index and
             Tiny_String.Length(Source => ItemType) > 0));
         null;
      exception
         when System.Assertions.Assert_Failure =>
            AUnit.Assertions.Assert
              (False,
               "req_sloc(crew-inventory.ads:0):Test_FindTools test requirement violated");
      end;
      declare
         Test_FindTools_4d4951_18cba3_Result: constant Natural :=
           GNATtest_Generated.GNATtest_Standard.Crew.Inventory.FindTools
             (MemberIndex, ItemType, Order, ToolQuality);
      begin
         begin
            pragma Assert(True);
            null;
         exception
            when System.Assertions.Assert_Failure =>
               AUnit.Assertions.Assert
                 (False,
                  "ens_sloc(crew-inventory.ads:0:):Test_FindTools test commitment violated");
         end;
         return Test_FindTools_4d4951_18cba3_Result;
      end;
   end Wrap_Test_FindTools_4d4951_18cba3;
--  end read only

--  begin read only
   procedure Test_FindTools_test_findtools(Gnattest_T: in out Test);
   procedure Test_FindTools_4d4951_18cba3(Gnattest_T: in out Test) renames
     Test_FindTools_test_findtools;
--  id:2.2/4d49518d4a3510af/FindTools/1/0/test_findtools/
   procedure Test_FindTools_test_findtools(Gnattest_T: in out Test) is
      function FindTools
        (MemberIndex: Positive; ItemType: Tiny_String.Bounded_String;
         Order: Crew_Orders; ToolQuality: Positive := 100)
         return Natural renames
        Wrap_Test_FindTools_4d4951_18cba3;
--  end read only

      pragma Unreferenced(Gnattest_T);
      use Tiny_String;

   begin

      Assert
        (FindTools(1, To_Bounded_String("Bucket"), Clean) > 0,
         "Failed to find tools for cleaning.");
      Assert
        (FindTools(1, To_Bounded_String("sdfsdfds"), Talk) = 0,
         "Failed to not find non-existing tools.");

--  begin read only
   end Test_FindTools_test_findtools;
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
end Crew.Inventory.Test_Data.Tests;
