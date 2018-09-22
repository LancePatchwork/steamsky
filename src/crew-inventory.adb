--    Copyright 2017-2018 Bartek thindil Jasicki
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

with Ships; use Ships;
with Messages; use Messages;
with Ships.Cargo; use Ships.Cargo;
with Ships.Crew; use Ships.Crew;

package body Crew.Inventory is

   procedure UpdateInventory(MemberIndex: Positive; Amount: Integer;
      ProtoIndex, Durability, InventoryIndex: Natural := 0) is
      ItemIndex: Natural := 0;
      NewAmount: Natural;
      Weight: Integer;
   begin
      if InventoryIndex = 0 then
         for I in PlayerShip.Crew(MemberIndex).Inventory.Iterate loop
            if PlayerShip.Crew(MemberIndex).Inventory(I).ProtoIndex =
              ProtoIndex and
              PlayerShip.Crew(MemberIndex).Inventory(I).Durability =
                Durability then
               ItemIndex := Inventory_Container.To_Index(I);
               exit;
            end if;
         end loop;
      else
         ItemIndex := InventoryIndex;
      end if;
      if Amount > 0 then
         if ItemIndex > 0 then
            Weight :=
              0 -
              Items_List
                  (PlayerShip.Crew(MemberIndex).Inventory(ItemIndex)
                     .ProtoIndex)
                  .Weight *
                Amount;
         else
            Weight := 0 - Items_List(ProtoIndex).Weight * Amount;
         end if;
         if FreeInventory(MemberIndex, Weight) < 0 then
            raise Crew_No_Space_Error
              with To_String(PlayerShip.Crew(MemberIndex).Name) &
              " don't have free space in own inventory.";
         end if;
      else
         if ItemIsUsed(MemberIndex, ItemIndex) then
            TakeOffItem(MemberIndex, ItemIndex);
         end if;
      end if;
      if ItemIndex = 0 then
         PlayerShip.Crew(MemberIndex).Inventory.Append
           (New_Item =>
              (ProtoIndex => ProtoIndex, Amount => Amount,
               Name => Items_List(ProtoIndex).Name, Durability => Durability));
      else
         NewAmount :=
           PlayerShip.Crew(MemberIndex).Inventory(ItemIndex).Amount + Amount;
         if NewAmount = 0 then
            PlayerShip.Crew(MemberIndex).Inventory.Delete(Index => ItemIndex);
            for Item of PlayerShip.Crew(MemberIndex).Equipment loop
               if Item = ItemIndex then
                  Item := 0;
               elsif Item > ItemIndex then
                  Item := Item - 1;
               end if;
            end loop;
         else
            PlayerShip.Crew(MemberIndex).Inventory(ItemIndex).Amount :=
              NewAmount;
         end if;
      end if;
   end UpdateInventory;

   function FreeInventory(MemberIndex: Positive;
      Amount: Integer) return Integer is
      FreeSpace: Integer :=
        50 + PlayerShip.Crew(MemberIndex).Attributes(StrengthIndex)(1);
   begin
      for Item of PlayerShip.Crew(MemberIndex).Inventory loop
         FreeSpace :=
           FreeSpace - (Items_List(Item.ProtoIndex).Weight * Item.Amount);
      end loop;
      return FreeSpace + Amount;
   end FreeInventory;

   procedure TakeOffItem(MemberIndex, ItemIndex: Positive) is
   begin
      for I in PlayerShip.Crew(MemberIndex).Equipment'Range loop
         if PlayerShip.Crew(MemberIndex).Equipment(I) = ItemIndex then
            PlayerShip.Crew(MemberIndex).Equipment(I) := 0;
            exit;
         end if;
      end loop;
   end TakeOffItem;

   function ItemIsUsed(MemberIndex, ItemIndex: Positive) return Boolean is
   begin
      for I in PlayerShip.Crew(MemberIndex).Equipment'Range loop
         if PlayerShip.Crew(MemberIndex).Equipment(I) = ItemIndex then
            return True;
         end if;
      end loop;
      return False;
   end ItemIsUsed;

   function FindTools(MemberIndex: Positive; ItemType: Unbounded_String;
      Order: Crew_Orders) return Natural is
      ToolsIndex: Natural;
   begin
      ToolsIndex := PlayerShip.Crew(MemberIndex).Equipment(7);
      if ToolsIndex > 0 then
         if Items_List
             (PlayerShip.Crew(MemberIndex).Inventory(ToolsIndex).ProtoIndex)
             .IType /=
           ItemType then
            return 0;
         end if;
      end if;
      ToolsIndex :=
        FindItem
          (Inventory => PlayerShip.Crew(MemberIndex).Inventory,
           ItemType => ItemType);
      if ToolsIndex = 0 then
         ToolsIndex :=
           FindItem(Inventory => PlayerShip.Cargo, ItemType => ItemType);
         if ToolsIndex > 0 then
            begin
               UpdateInventory
                 (MemberIndex, 1, PlayerShip.Cargo(ToolsIndex).ProtoIndex,
                  PlayerShip.Cargo(ToolsIndex).Durability);
               UpdateCargo
                 (Ship => PlayerShip, Amount => -1, CargoIndex => ToolsIndex);
               ToolsIndex :=
                 FindItem
                   (Inventory => PlayerShip.Crew(MemberIndex).Inventory,
                    ItemType => ItemType);
               PlayerShip.Crew(MemberIndex).Equipment(7) := ToolsIndex;
            exception
               when Crew_No_Space_Error =>
                  case Order is
                     when Repair =>
                        AddMessage
                          (To_String(PlayerShip.Crew(MemberIndex).Name) &
                           " can't continue repairs because don't have space in inventory for repair tools.",
                           OrderMessage, 3);
                     when Upgrading =>
                        AddMessage
                          (To_String(PlayerShip.Crew(MemberIndex).Name) &
                           " can't continue upgrading module because don't have space in inventory for repair tools.",
                           OrderMessage, 3);
                     when Clean =>
                        AddMessage
                          (To_String(PlayerShip.Crew(MemberIndex).Name) &
                           " can't continue cleaning ship because don't have space in inventory for cleaning tools.",
                           OrderMessage, 3);
                     when Craft =>
                        AddMessage
                          (To_String(PlayerShip.Crew(MemberIndex).Name) &
                           " can't continue manufacturing because don't have space in inventory for proper tools.",
                           OrderMessage, 3);
                     when Train =>
                        AddMessage
                          (To_String(PlayerShip.Crew(MemberIndex).Name) &
                           " can't continue training because don't have space in inventory for proper tools.",
                           OrderMessage, 3);
                     when others =>
                        null;
                  end case;
                  GiveOrders(PlayerShip, MemberIndex, Rest);
                  return 0;
            end;
         end if;
      else
         PlayerShip.Crew(MemberIndex).Equipment(7) := ToolsIndex;
      end if;
      return ToolsIndex;
   end FindTools;

end Crew.Inventory;
