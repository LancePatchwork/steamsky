--    Copyright 2017 Bartek thindil Jasicki
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

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Maps; use Maps;
with Maps.UI; use Maps.UI;
with Ships; use Ships;
with Ships.Cargo; use Ships.Cargo;
with Ships.Movement; use Ships.Movement;
with Ships.Crew; use Ships.Crew;
with Crew; use Crew;
with Crew.UI; use Crew.UI;
with Bases; use Bases;
with Messages; use Messages;
with Combat; use Combat;
with MainMenu; use MainMenu;
with Events; use Events;
with ShipModules; use ShipModules;
with Missions; use Missions;
with Utils; use Utils;
with Items; use Items;

package body UserInterface.Keys is

   function GameMenuKeys
     (CurrentState: GameStates;
      Key: Key_Code) return GameStates is
      Result: Menus.Driver_Result;
      MenuOptions: constant array(Positive range <>) of Character :=
        ('s',
         'a',
         'c',
         'o',
         'r',
         'm',
         'b',
         'n',
         'i',
         'w',
         'v',
         'g',
         'h',
         'p',
         'q',
         'x',
         'l');
      NewKey: Key_Code;
   begin
      case Key is
         when KEY_UP => -- Select previous order
            if CurrentState = GameMenu then
               Result := Driver(OrdersMenu, M_Up_Item);
               if Result = Request_Denied then
                  Result := Driver(OrdersMenu, M_Last_Item);
               end if;
               if Result = Menu_Ok then
                  Refresh(MenuWindow);
               end if;
               return GameMenu;
            else
               NewKey := Key;
            end if;
         when KEY_DOWN => -- Select next order
            if CurrentState = GameMenu then
               Result := Driver(OrdersMenu, M_Down_Item);
               if Result = Request_Denied then
                  Result := Driver(OrdersMenu, M_First_Item);
               end if;
               if Result = Menu_Ok then
                  Refresh(MenuWindow);
               end if;
               return GameMenu;
            else
               NewKey := Key;
            end if;
         when 10 => -- Select option from menu
            if CurrentState = GameMenu then
               NewKey :=
                 Character'Pos(MenuOptions(Get_Index(Current(OrdersMenu))));
            else
               NewKey := Key;
            end if;
         when others =>
            NewKey := Key;
      end case;
      case NewKey is
         when Character'Pos('q') | Character'Pos('Q') => -- Back to main menu
            DrawGame(Quit_Confirm);
            return Quit_Confirm;
         when Character'Pos('s') | Character'Pos('S') => -- Ship info screen
            DrawGame(Ship_Info);
            return Ship_Info;
         when Character'Pos('c') | Character'Pos('C') => -- Crew info screen
            DrawGame(Crew_Info);
            return Crew_Info;
         when Character'Pos('o') | Character'Pos('O') => -- Ship orders menu
            DrawGame(Control_Speed);
            return Control_Speed;
         when Character'Pos('r') | Character'Pos('R') => -- Crafting screen
            DrawGame(Craft_View);
            return Craft_View;
         when Character'Pos('m') |
           Character'Pos('M') => -- Messages list screen
            DrawGame(Messages_View);
            return Messages_View;
         when Character'Pos('h') | Character'Pos('H') => -- Help screen
            DrawGame(Help_View);
            return Help_View;
         when Character'Pos('e') | Character'Pos('E') => -- Show game menu
            ShowGameMenu;
            return GameMenu;
         when Character'Pos('a') | Character'Pos('A') => -- Cargo info screen
            DrawGame(Cargo_Info);
            return Cargo_Info;
         when Character'Pos('v') | Character'Pos('V') => -- Move map form
            DrawGame(Sky_Map_View);
            ShowMoveMapForm;
            return Move_Map;
         when Character'Pos('b') |
           Character'Pos('B') => -- List of bases screen
            DrawGame(Bases_List);
            return Bases_List;
         when Character'Pos('n') |
           Character'Pos('N') => -- List of events screen
            DrawGame(Events_View);
            return Events_View;
         when Character'Pos('l') | Character'Pos('L') => -- Close menu
            if CurrentState = GameMenu then
               DrawGame(Sky_Map_View);
               return Sky_Map_View;
            else
               return CurrentState;
            end if;
         when Character'Pos('g') | Character'Pos('G') => -- Game statistics
            DrawGame(GameStats_View);
            return GameStats_View;
         when Character'Pos('i') |
           Character'Pos('I') => -- List of accepted missions
            DrawGame(Missions_View);
            return Missions_View;
         when Character'Pos('p') | Character'Pos('P') => -- Game options
            DrawGame(GameOptions_View);
            return GameOptions_View;
         when Character'Pos('x') | Character'Pos('X') => -- Resign from game
            DrawGame(Resign_Confirm);
            return Resign_Confirm;
         when others =>
            if CurrentState /= GameMenu then
               DrawGame(CurrentState);
            end if;
            return CurrentState;
      end case;
   end GameMenuKeys;

   function OrdersMenuKeys
     (OldState: GameStates;
      Key: Key_Code) return GameStates is
      EventIndex, ItemIndex: Natural := 0;
      NewState: GameStates;
      Order: constant String := Name(Current(OrdersMenu));
      Result: Menus.Driver_Result;
      NewTime: Integer;
   begin
      if SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).EventIndex > 0 then
         EventIndex := SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).EventIndex;
      end if;
      case Key is
         when KEY_UP => -- Select previous order
            Result := Driver(OrdersMenu, M_Up_Item);
            if Result = Request_Denied then
               Result := Driver(OrdersMenu, M_Last_Item);
            end if;
            if Result = Menu_Ok then
               Refresh(MenuWindow);
            end if;
         when KEY_DOWN => -- Select next order
            Result := Driver(OrdersMenu, M_Down_Item);
            if Result = Request_Denied then
               Result := Driver(OrdersMenu, M_First_Item);
            end if;
            if Result = Menu_Ok then
               Refresh(MenuWindow);
            end if;
         when 10 => -- Select current order
            Post(OrdersMenu, False);
            Delete(OrdersMenu);
            if Order = "Trade" then
               DrawGame(Trade_View);
               return Trade_View;
            elsif Order = "Recruit" then
               DrawGame(Recruits_View);
               return Recruits_View;
            elsif Order = "Ask for events" then
               AskForEvents;
            elsif Order = "Ask for bases" then
               AskForBases;
            elsif Order = "Heal wounded" then
               DrawGame(Heal_View);
               return Heal_View;
            elsif Order = "Repair" then
               DrawGame(Repairs_View);
               return Repairs_View;
            elsif Order = "Shipyard" then
               DrawGame(Shipyard_View);
               return Shipyard_View;
            elsif Order = "Buy recipes" then
               DrawGame(TradeRecipes_View);
               return TradeRecipes_View;
            elsif Order = "Missions" then
               DrawGame(BaseMissions_View);
               return BaseMissions_View;
            elsif Order = "Undock" then
               DockShip(False);
            elsif Order = "Quarter speed" then
               ChangeShipSpeed(QUARTER_SPEED);
            elsif Order = "Dock" then
               DockShip(True);
            elsif Order = "Defend" then
               OldSpeed := PlayerShip.Speed;
               NewState := Combat_State;
               if EnemyName /=
                 ProtoShips_List(Events_List(EventIndex).Data).Name then
                  NewState := StartCombat(Events_List(EventIndex).Data, False);
               end if;
               DrawGame(NewState);
               return NewState;
            elsif Order = "All stop" then
               ChangeShipSpeed(FULL_STOP);
            elsif Order = "Attack" then
               OldSpeed := PlayerShip.Speed;
               NewState := Combat_State;
               if EnemyName /=
                 ProtoShips_List(Events_List(EventIndex).Data).Name then
                  NewState := StartCombat(Events_List(EventIndex).Data, False);
               end if;
               DrawGame(NewState);
               return NewState;
            elsif Order = "Half speed" then
               ChangeShipSpeed(HALF_SPEED);
            elsif Order = "Full speed" then
               ChangeShipSpeed(FULL_SPEED);
            elsif Order = "Wait" then
               DrawGame(Wait_Order);
               return Wait_Order;
            elsif Order = "Deliver medicines for free" then
               ItemIndex := FindCargo(ItemType => HealingTools);
               NewTime :=
                 Events_List(EventIndex).Time -
                 PlayerShip.Cargo(ItemIndex).Amount;
               if NewTime < 1 then
                  DeleteEvent(EventIndex);
               else
                  Events_List(EventIndex).Time := NewTime;
               end if;
               GainRep
                 (SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex,
                  (PlayerShip.Cargo(ItemIndex).Amount / 10));
               AddMessage
                 ("You gave " &
                  To_String
                    (Items_List(PlayerShip.Cargo(ItemIndex).ProtoIndex).Name) &
                  " for free to base.",
                  TradeMessage);
               UpdateCargo
                 (PlayerShip,
                  PlayerShip.Cargo.Element(ItemIndex).ProtoIndex,
                  (0 - PlayerShip.Cargo.Element(ItemIndex).Amount));
            elsif Order = "Deliver medicines for price" then
               ItemIndex := FindCargo(ItemType => HealingTools);
               NewTime :=
                 Events_List(EventIndex).Time -
                 PlayerShip.Cargo(ItemIndex).Amount;
               if NewTime < 1 then
                  DeleteEvent(EventIndex);
               else
                  Events_List(EventIndex).Time := NewTime;
               end if;
               SellItems
                 (ItemIndex,
                  Integer'Image(PlayerShip.Cargo.Element(ItemIndex).Amount));
               GainRep
                 (SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex,
                  ((PlayerShip.Cargo(ItemIndex).Amount / 20) * (-1)));
            elsif Order(1 .. 3) = "Com" then
               FinishMission
                 (SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).MissionIndex);
            elsif Order(1 .. 3) = "Sea" then
               OldSpeed := PlayerShip.Speed;
               UpdateGame(GetRandom(15, 45));
               NewState :=
                 StartCombat
                   (PlayerShip.Missions
                      (SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).MissionIndex)
                      .Target,
                    False);
               DrawGame(NewState);
               return NewState;
            elsif Order = "Patrol area" then
               UpdateGame(GetRandom(45, 75));
               UpdateMission
                 (SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).MissionIndex);
            elsif Order = "Explore area" then
               UpdateGame(GetRandom(30, 60));
               UpdateMission
                 (SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).MissionIndex);
            end if;
            DrawGame(Sky_Map_View);
            return OldState;
         when others =>
            Result := Driver(OrdersMenu, Key);
            if Result = Menu_Ok then
               Refresh(MenuWindow);
            else
               Result := Driver(OrdersMenu, M_Clear_Pattern);
               Result := Driver(OrdersMenu, Key);
               if Result = Menu_Ok then
                  Refresh(MenuWindow);
               end if;
            end if;
      end case;
      return Control_Speed;
   end OrdersMenuKeys;

   function ConfirmKeys
     (OldState: GameStates;
      Key: Key_Code) return GameStates is
   begin
      case Key is
         when Character'Pos('n') | Character'Pos('N') => -- Back to old screen
            if OldState = Clear_Confirm then
               DrawGame(Messages_View);
               return Messages_View;
            elsif OldState = Dismiss_Confirm then
               DrawGame(Crew_Info);
               return Crew_Info;
            elsif OldState = Quit_Confirm or
              OldState = PilotRest_Confirm or
              OldState = EngineerRest_Confirm or
              OldState = Resign_Confirm then
               DrawGame(Sky_Map_View);
               return Sky_Map_View;
            elsif OldState = Death_Confirm then
               EndGame(False);
               Erase;
               Refresh;
               ShowMainMenu;
               return Main_Menu;
            else
               return OldState;
            end if;
         when Character'Pos('y') | Character'Pos('Y') => -- Confirm action
            if OldState = Quit_Confirm then
               EndGame(True);
               Erase;
               Refresh;
               ShowMainMenu;
               return Main_Menu;
            elsif OldState = Clear_Confirm then
               ClearMessages;
               DrawGame(Messages_View);
               return Messages_View;
            elsif OldState = Dismiss_Confirm then
               DismissMember;
               DrawGame(Crew_Info);
               return Crew_Info;
            elsif OldState = Death_Confirm then
               DrawGame(GameStats_View);
               return GameStats_View;
            elsif OldState = PilotRest_Confirm or
              OldState = EngineerRest_Confirm then
               WaitForRest;
               DrawGame(Sky_Map_View);
               return Sky_Map_View;
            elsif OldState = Resign_Confirm then
               Death(1, To_Unbounded_String("resignation"), PlayerShip);
               DrawGame(Death_Confirm);
               return Death_Confirm;
            else
               return OldState;
            end if;
         when others =>
            DrawGame(OldState);
            return OldState;
      end case;
   end ConfirmKeys;

   function WaitMenuKeys
     (OldState: GameStates;
      Key: Key_Code) return GameStates is
      TimeNeeded: Natural := 0;
      ReturnState: GameStates;
      Order: constant String :=
        Name(Current(OrdersMenu))(4 .. Name(Current(OrdersMenu))'Last);
      Result: Menus.Driver_Result;
   begin
      case Key is
         when KEY_UP => -- Select previous wait order
            Result := Driver(OrdersMenu, M_Up_Item);
            if Result = Request_Denied then
               Result := Driver(OrdersMenu, M_Last_Item);
            end if;
            if Result = Menu_Ok then
               Refresh(MenuWindow);
            end if;
            return Wait_Order;
         when KEY_DOWN => -- Select next wait order
            Result := Driver(OrdersMenu, M_Down_Item);
            if Result = Request_Denied then
               Result := Driver(OrdersMenu, M_First_Item);
            end if;
            if Result = Menu_Ok then
               Refresh(MenuWindow);
            end if;
            return Wait_Order;
         when 10 => -- Select option from menu
            if Order = "Quit" then
               DrawGame(Sky_Map_View);
               return Sky_Map_View;
            elsif Order = "Wait 1 minute" then
               UpdateGame(1);
            elsif Order = "Wait 5 minutes" then
               UpdateGame(5);
            elsif Order = "Wait 10 minutes" then
               UpdateGame(10);
            elsif Order = "Wait 15 minutes" then
               UpdateGame(15);
            elsif Order = "Wait 30 minutes" then
               UpdateGame(30);
            elsif Order = "Wait 1 hour" then
               UpdateGame(60);
            elsif Order = "Wait X minutes" then
               DrawGame(Sky_Map_View);
               ShowWaitForm;
               return WaitX_Order;
            elsif Order = "Wait until crew is rested" then
               WaitForRest;
            elsif Order = "Wait until crew is healed" then
               for I in PlayerShip.Crew.Iterate loop
                  if PlayerShip.Crew(I).Health < 100 and
                    PlayerShip.Crew(I).Health > 0 and
                    PlayerShip.Crew(I).Order = Rest then
                     for Module of PlayerShip.Modules loop
                        if Modules_List(Module.ProtoIndex).MType = CABIN and
                          Module.Owner = Crew_Container.To_Index(I) then
                           if TimeNeeded <
                             (100 - PlayerShip.Crew(I).Health) * 15 then
                              TimeNeeded :=
                                (100 - PlayerShip.Crew(I).Health) * 15;
                           end if;
                           exit;
                        end if;
                     end loop;
                  end if;
               end loop;
               if TimeNeeded > 0 then
                  UpdateGame(TimeNeeded);
               else
                  return Wait_Order;
               end if;
            end if;
         when others =>
            Result := Driver(OrdersMenu, Key);
            if Result = Menu_Ok then
               Refresh(MenuWindow);
            else
               Result := Driver(OrdersMenu, M_Clear_Pattern);
               Result := Driver(OrdersMenu, Key);
               if Result = Menu_Ok then
                  Refresh(MenuWindow);
               end if;
            end if;
            return Wait_Order;
      end case;
      ReturnState := CheckForEvent(OldState);
      DrawGame(ReturnState);
      return ReturnState;
   end WaitMenuKeys;

   function WaitFormKeys(Key: Key_Code) return GameStates is
      Result: Forms.Driver_Result;
      FieldIndex: Positive := Get_Index(Current(WaitForm));
      Visibility: Cursor_Visibility := Invisible;
   begin
      case Key is
         when KEY_UP => -- Select previous field
            Result := Driver(WaitForm, F_Previous_Field);
            FieldIndex := Get_Index(Current(WaitForm));
            if FieldIndex = 2 then
               Result := Driver(WaitForm, F_End_Line);
            end if;
         when KEY_DOWN => -- Select next field
            Result := Driver(WaitForm, F_Next_Field);
            FieldIndex := Get_Index(Current(WaitForm));
            if FieldIndex = 2 then
               Result := Driver(WaitForm, F_End_Line);
            end if;
         when 10 => -- quit/move map
            if FieldIndex = 4 then
               UpdateGame(Integer'Value(Get_Buffer(Fields(WaitForm, 2))));
            end if;
            Set_Cursor_Visibility(Visibility);
            Post(WaitForm, False);
            Delete(WaitForm);
            DrawGame(Sky_Map_View);
            return Sky_Map_View;
         when Key_Backspace => -- delete last character
            if FieldIndex = 2 then
               Result := Driver(WaitForm, F_Delete_Previous);
            end if;
         when KEY_DC => -- delete character at cursor
            if FieldIndex = 2 then
               Result := Driver(WaitForm, F_Delete_Char);
            end if;
         when KEY_RIGHT => -- Move cursor right
            if FieldIndex = 2 then
               Result := Driver(WaitForm, F_Right_Char);
            end if;
         when KEY_LEFT => -- Move cursor left
            if FieldIndex = 2 then
               Result := Driver(WaitForm, F_Left_Char);
            end if;
         when others =>
            Result := Driver(WaitForm, Key);
      end case;
      if Result = Form_Ok then
         Set_Background(Fields(WaitForm, 2), (others => False));
         if FieldIndex = 2 then
            Set_Background
              (Current(WaitForm),
               (Reverse_Video => True, others => False));
         end if;
         Refresh(MenuWindow);
      end if;
      return WaitX_Order;
   end WaitFormKeys;

end UserInterface.Keys;
