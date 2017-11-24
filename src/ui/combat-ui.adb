--    Copyright 2016-2017 Bartek thindil Jasicki
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

with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Exceptions; use Ada.Exceptions;
with Terminal_Interface.Curses.Menus; use Terminal_Interface.Curses.Menus;
with Crew; use Crew;
with Messages; use Messages;
with UserInterface; use UserInterface;
with ShipModules; use ShipModules;
with Items; use Items;
with Help.UI; use Help.UI;
with Ships.Crew; use Ships.Crew;
with Messages.UI; use Messages.UI;
with Header; use Header;
with Utils.UI; use Utils.UI;
with Bases; use Bases;
with Config; use Config;

package body Combat.UI is

   PilotOrders: constant array(1 .. 4) of Unbounded_String :=
     (To_Unbounded_String("Go closer"),
      To_Unbounded_String("Keep distance"),
      To_Unbounded_String("Evade"),
      To_Unbounded_String("Escape"));
   EngineerOrders: constant array(1 .. 4) of Unbounded_String :=
     (To_Unbounded_String("All stop"),
      To_Unbounded_String("Quarter speed"),
      To_Unbounded_String("Half speed"),
      To_Unbounded_String("Full speed"));
   GunnerOrders: constant array(1 .. 6) of Unbounded_String :=
     (To_Unbounded_String("Don't shoot"),
      To_Unbounded_String("Precise fire"),
      To_Unbounded_String("Fire at will"),
      To_Unbounded_String("Aim for engine"),
      To_Unbounded_String("Aim in weapon"),
      To_Unbounded_String("Aim in hull"));
   Order: Crew_Orders;
   CrewMenu: Menu;
   OrdersMenu: Menu;
   MenuWindow, MenuWindow2, EnemyPad: Window;
   CurrentMenuIndex: Positive := 1;
   StartIndex: Integer := 0;
   EndIndex: Integer;

   procedure CombatOrders is
      MemberIndex: Natural := 0;
      CrewIndex: constant Integer :=
        Positive'Value(Description(Current(OrdersMenu)));
      OrderIndex: constant Positive := Get_Index(Current(OrdersMenu));
      ModuleIndex: Natural := 0;
   begin
      if Order = Pilot or Order = Engineer then
         MemberIndex := FindMember(Order);
      else
         ModuleIndex :=
           Guns(Positive'Value(Description(Current(CrewMenu))))(1);
         MemberIndex := PlayerShip.Modules(ModuleIndex).Owner;
      end if;
      if CrewIndex > 0 then
         GiveOrders(CrewIndex, Order, ModuleIndex);
      elsif CrewIndex = 0 then
         if Name(Current(OrdersMenu)) = "Close" then
            return;
         end if;
         case Order is
            when Pilot =>
               PilotOrder := OrderIndex;
               AddMessage
                 ("Order for " &
                  To_String(PlayerShip.Crew(MemberIndex).Name) &
                  " was set on: " &
                  To_String(PilotOrders(PilotOrder)),
                  CombatMessage);
            when Engineer =>
               EngineerOrder := OrderIndex;
               AddMessage
                 ("Order for " &
                  To_String(PlayerShip.Crew(MemberIndex).Name) &
                  " was set on: " &
                  To_String(EngineerOrders(EngineerOrder)),
                  CombatMessage);
            when Gunner =>
               Guns(Positive'Value(Description(Current(CrewMenu))))(2) :=
                 OrderIndex;
               AddMessage
                 ("Order for " &
                  To_String(PlayerShip.Crew(MemberIndex).Name) &
                  " was set on: " &
                  To_String(GunnerOrders(OrderIndex)),
                  CombatMessage);
            when others =>
               null;
         end case;
      else
         PlayerShip.Modules(ModuleIndex).Data(1) := abs (CrewIndex);
         AddMessage
           ("You assigned " &
            To_String
              (Items_List(PlayerShip.Cargo(abs (CrewIndex)).ProtoIndex).Name) &
            " to " &
            To_String(PlayerShip.Modules(ModuleIndex).Name) &
            ".",
            OrderMessage);
      end if;
   exception
      when An_Exception : Crew_Order_Error =>
         ShowDialog(Exception_Message(An_Exception));
   end CombatOrders;

   procedure ShowCombat is
      PilotName,
      EngineerName,
      GunnerName: Unbounded_String :=
        To_Unbounded_String("Vacant");
      DamagePercent: Natural;
      Crew_Items: Item_Array_Access;
      CurrentLine, MenuHeight: Line_Position;
      MenuLength: Column_Position;
      MenuOptions: Menu_Option_Set;
      EnemyStatus: Unbounded_String;
      EnemyInfo, DamageInfo: Window;
      ShipDamaged: Boolean := False;
      WindowHeight: Line_Position := 2;
      WindowWidth: Column_Position := 17;
   begin
      Crew_Items := new Item_Array(1 .. Natural(Guns.Length) + 3);
      for I in PlayerShip.Crew.Iterate loop
         case PlayerShip.Crew(I).Order is
            when Pilot =>
               PilotName := PlayerShip.Crew(I).Name;
            when Engineer =>
               EngineerName := PlayerShip.Crew(I).Name;
            when others =>
               null;
         end case;
      end loop;
      if PilotName /= To_Unbounded_String("Vacant") then
         PilotName :=
           To_Unbounded_String("Pilot: ") &
           PilotName &
           To_Unbounded_String(" -> ") &
           PilotOrders(PilotOrder);
      else
         PilotName := To_Unbounded_String("Pilot: ") & PilotName;
      end if;
      Crew_Items.all(1) := New_Item(To_String(PilotName));
      if EngineerName /= To_Unbounded_String("Vacant") then
         EngineerName :=
           To_Unbounded_String("Engineer: ") &
           EngineerName &
           To_Unbounded_String(" -> ") &
           EngineerOrders(EngineerOrder);
      else
         EngineerName := To_Unbounded_String("Engineer: ") & EngineerName;
      end if;
      Crew_Items.all(2) := New_Item(To_String(EngineerName), "0");
      for I in Guns.First_Index .. Guns.Last_Index loop
         GunnerName := PlayerShip.Modules(Guns(I)(1)).Name & ": ";
         if PlayerShip.Modules(Guns(I)(1)).Owner = 0 then
            GunnerName := GunnerName & To_Unbounded_String("Vacant");
         else
            GunnerName :=
              GunnerName &
              PlayerShip.Crew(PlayerShip.Modules(Guns(I)(1)).Owner).Name &
              " -> " &
              GunnerOrders(Guns(I)(2));
         end if;
         Crew_Items.all(I + 2) :=
           New_Item(To_String(GunnerName), Positive'Image(I));
      end loop;
      Crew_Items.all(Crew_Items'Last) := Null_Item;
      CrewMenu := New_Menu(Crew_Items);
      Set_Format(CrewMenu, 4, 1);
      MenuOptions := Get_Options(CrewMenu);
      MenuOptions.Show_Descriptions := False;
      Set_Options(CrewMenu, MenuOptions);
      Scale(CrewMenu, MenuHeight, MenuLength);
      MenuWindow := Create(MenuHeight + 2, MenuLength + 2, 1, 2);
      WindowFrame(MenuWindow, 2, "Crew orders");
      Set_Window(CrewMenu, MenuWindow);
      Set_Sub_Window
        (CrewMenu,
         Derived_Window(MenuWindow, MenuHeight, MenuLength, 1, 1));
      Post(CrewMenu);
      if CurrentMenuIndex >= Crew_Items'Last then
         CurrentMenuIndex := 1;
      end if;
      Set_Current(CrewMenu, Crew_Items.all(CurrentMenuIndex));
      CurrentLine := Line_Position(MenuHeight + 3);
      Move_Cursor(Line => CurrentLine, Column => 2);
      if not EndCombat then
         Add(Str => "Crew Info");
         Change_Attributes
           (Line => CurrentLine,
            Column => 2,
            Count => 1,
            Color => 1,
            Attr => BoldCharacters);
         CurrentLine := CurrentLine + 1;
         Move_Cursor(Line => CurrentLine, Column => 2);
         Add(Str => "Ship cargo");
         Change_Attributes
           (Line => CurrentLine,
            Column => 8,
            Count => 1,
            Color => 1,
            Attr => BoldCharacters);
         CurrentLine := CurrentLine + 1;
         Move_Cursor(Line => CurrentLine, Column => 2);
         Add(Str => "Ship modules");
         Change_Attributes
           (Line => CurrentLine,
            Column => 2,
            Count => 1,
            Color => 1,
            Attr => BoldCharacters);
         CurrentLine := CurrentLine + 1;
         Move_Cursor(Line => CurrentLine, Column => 2);
         Add(Str => "Messages");
         Change_Attributes
           (Line => CurrentLine,
            Column => 2,
            Count => 1,
            Color => 1,
            Attr => BoldCharacters);
         CurrentLine := CurrentLine + 1;
      end if;
      WindowHeight := 2;
      for Module of PlayerShip.Modules loop
         if Module.Durability < Module.MaxDurability then
            WindowHeight := WindowHeight + 1;
            if WindowWidth < Column_Position(Length(Module.Name) + 4) then
               WindowWidth := Column_Position(Length(Module.Name) + 4);
            end if;
            ShipDamaged := True;
         end if;
      end loop;
      if ShipDamaged then
         if (WindowHeight + CurrentLine) >= (Lines - 12) then
            WindowHeight := Lines - CurrentLine - 12;
            if WindowHeight < 3 then
               WindowHeight := 3;
            end if;
         end if;
         DamageInfo := Create(WindowHeight, WindowWidth, CurrentLine, 2);
         WindowFrame(DamageInfo, 3, "Ship damage");
         CurrentLine := 1;
         for Module of PlayerShip.Modules loop
            DamagePercent :=
              100 -
              Natural
                ((Float(Module.Durability) / Float(Module.MaxDurability)) *
                 100.0);
            if DamagePercent > 0 then
               Move_Cursor
                 (Win => DamageInfo,
                  Line => CurrentLine,
                  Column => 2);
               Add(Win => DamageInfo, Str => To_String(Module.Name));
               if DamagePercent > 19 and DamagePercent < 50 then
                  Change_Attributes
                    (Win => DamageInfo,
                     Line => CurrentLine,
                     Column => 2,
                     Count => Length(Module.Name),
                     Color => 2);
               elsif DamagePercent > 49 and DamagePercent < 80 then
                  Change_Attributes
                    (Win => DamageInfo,
                     Line => CurrentLine,
                     Column => 2,
                     Count => Length(Module.Name),
                     Color => 1);
               elsif DamagePercent > 79 and DamagePercent < 100 then
                  Change_Attributes
                    (Win => DamageInfo,
                     Line => CurrentLine,
                     Column => 2,
                     Count => Length(Module.Name),
                     Color => 3);
               elsif DamagePercent = 100 then
                  Change_Attributes
                    (Win => DamageInfo,
                     Line => CurrentLine,
                     Column => 2,
                     Count => Length(Module.Name),
                     Color => 4);
               end if;
               CurrentLine := CurrentLine + 1;
               exit when CurrentLine = WindowHeight;
            end if;
         end loop;
      end if;
      EnemyInfo := Create(8, (Columns / 2), 1, (Columns / 2));
      WindowFrame(EnemyInfo, 1, "Enemy status");
      Move_Cursor(Win => EnemyInfo, Line => 1, Column => 2);
      Add(Win => EnemyInfo, Str => "Name: " & To_String(EnemyName));
      Move_Cursor(Win => EnemyInfo, Line => 2, Column => 2);
      Add(Win => EnemyInfo, Str => "Type: " & To_String(Enemy.Ship.Name));
      Move_Cursor(Win => EnemyInfo, Line => 3, Column => 2);
      Add
        (Win => EnemyInfo,
         Str => "Home: " & To_String(SkyBases(Enemy.Ship.HomeBase).Name));
      Move_Cursor(Win => EnemyInfo, Line => 4, Column => 2);
      Add(Win => EnemyInfo, Str => "Distance: ");
      if Enemy.Distance >= 15000 then
         Add(Win => EnemyInfo, Str => "Escaped");
      elsif Enemy.Distance < 15000 and Enemy.Distance >= 10000 then
         Add(Win => EnemyInfo, Str => "Long");
      elsif Enemy.Distance < 10000 and Enemy.Distance >= 5000 then
         Add(Win => EnemyInfo, Str => "Medium");
      elsif Enemy.Distance < 5000 and Enemy.Distance >= 1000 then
         Add(Win => EnemyInfo, Str => "Short");
      else
         Add(Win => EnemyInfo, Str => "Close");
      end if;
      Move_Cursor(Win => EnemyInfo, Line => 5, Column => 2);
      Add(Win => EnemyInfo, Str => "Status: ");
      if Enemy.Distance < 15000 then
         if Enemy.Ship.Modules(1).Durability = 0 then
            Add(Win => EnemyInfo, Str => "Destroyed");
         else
            EnemyStatus := To_Unbounded_String("Ok");
            for Module of Enemy.Ship.Modules loop
               if Module.Durability < Module.MaxDurability then
                  EnemyStatus := To_Unbounded_String("Damaged");
                  exit;
               end if;
            end loop;
            Add(Win => EnemyInfo, Str => To_String(EnemyStatus));
            for Module of Enemy.Ship.Modules loop
               if Module.Durability > 0 then
                  case Modules_List(Module.ProtoIndex).MType is
                     when ARMOR =>
                        Add(Win => EnemyInfo, Str => " (armored)");
                     when GUN =>
                        Add(Win => EnemyInfo, Str => " (gun)");
                     when BATTERING_RAM =>
                        Add(Win => EnemyInfo, Str => " (battering ram)");
                     when HARPOON_GUN =>
                        Add(Win => EnemyInfo, Str => " (harpoon gun)");
                     when others =>
                        null;
                  end case;
               end if;
            end loop;
         end if;
      else
         Add(Win => EnemyInfo, Str => "Unknown");
      end if;
      Move_Cursor(Win => EnemyInfo, Line => 6, Column => 2);
      Add(Win => EnemyInfo, Str => "Speed: ");
      if Enemy.Distance < 15000 then
         case Enemy.Ship.Speed is
            when FULL_STOP =>
               Add(Win => EnemyInfo, Str => "Stopped");
            when QUARTER_SPEED =>
               Add(Win => EnemyInfo, Str => "Slow");
            when HALF_SPEED =>
               Add(Win => EnemyInfo, Str => "Medium");
            when FULL_SPEED =>
               Add(Win => EnemyInfo, Str => "Fast");
            when others =>
               null;
         end case;
      else
         Add(Win => EnemyInfo, Str => "Unknown");
      end if;
      if not EndCombat then
         Move_Cursor(Line => 9, Column => (Columns / 2));
         Add(Str => "Detailed enemy info");
         Change_Attributes
           (Line => 9,
            Column => (Columns / 2),
            Count => 1,
            Color => 1,
            Attr => BoldCharacters);
         Move_Cursor(Line => 10, Column => (Columns / 2));
         Add(Str => "ENTER to give orders");
         Change_Attributes
           (Line => 10,
            Column => (Columns / 2),
            Count => 5,
            Color => 1,
            Attr => BoldCharacters);
         Move_Cursor(Line => 11, Column => (Columns / 2));
         Add(Str => "SPACE for next turn");
         Change_Attributes
           (Line => 11,
            Column => (Columns / 2),
            Count => 5,
            Color => 1,
            Attr => BoldCharacters);
         Move_Cursor(Line => 12, Column => (Columns / 2));
         Add(Str => GetKeyName(Key_Code(GameSettings.Keys(33))) & " for help");
         Change_Attributes
           (Line => 12,
            Column => (Columns / 2),
            Count => GetKeyName(Key_Code(GameSettings.Keys(33)))'Length,
            Color => 1,
            Attr => BoldCharacters);
         if HarpoonDuration > 0 or Enemy.HarpoonDuration > 0 then
            Move_Cursor(Line => 13, Column => (Columns / 2));
            Add(Str => "Board enemy ship");
            Change_Attributes
              (Line => 13,
               Column => (Columns / 2),
               Count => 1,
               Color => 1,
               Attr => BoldCharacters);
         end if;
      else
         Move_Cursor(Line => 11, Column => (Columns / 3));
         Add(Str => "Press any key for back to sky map");
         Change_Attributes
           (Line => 11,
            Column => (Columns / 3) + 6,
            Count => 3,
            Color => 1,
            Attr => BoldCharacters);
      end if;
      LastMessage := To_Unbounded_String("");
      Refresh_Without_Update;
      ShowLastMessages(MessagesStarts);
      Refresh_Without_Update(MenuWindow);
      Refresh_Without_Update(EnemyInfo);
      Delete(EnemyInfo);
      if ShipDamaged then
         Refresh(DamageInfo);
         Delete(DamageInfo);
      end if;
      Update_Screen;
   end ShowCombat;

   procedure ShowOrdersMenu is
      Orders_Items: Item_Array_Access;
      MenuHeight: Line_Position;
      MenuLength: Column_Position;
      MenuOptions: Menu_Option_Set;
      MemberIndex: Natural := 0;
      SkillIndex, SkillValue: Natural := 0;
      MenuIndex, LastIndex: Positive := 1;
      SkillString: Unbounded_String;
   begin
      if Order = Pilot or Order = Engineer then
         MemberIndex := FindMember(Order);
      else
         MemberIndex :=
           PlayerShip.Modules
             (Guns(Positive'Value(Description(Current(CrewMenu))))(1))
             .Owner;
      end if;
      if MemberIndex > 0 then
         case Order is
            when Pilot =>
               LastIndex :=
                 PilotOrders'Length + 1 + PlayerShip.Crew.Last_Index;
               LastIndex := LastIndex + PlayerShip.Cargo.Last_Index;
               Orders_Items := new Item_Array(1 .. LastIndex);
               for I in PilotOrders'Range loop
                  Orders_Items.all(I) :=
                    New_Item(To_String(PilotOrders(I)), "0");
                  MenuIndex := MenuIndex + 1;
               end loop;
            when Engineer =>
               LastIndex :=
                 EngineerOrders'Length + 1 + PlayerShip.Crew.Last_Index;
               LastIndex := LastIndex + PlayerShip.Cargo.Last_Index;
               Orders_Items := new Item_Array(1 .. LastIndex);
               for I in EngineerOrders'Range loop
                  Orders_Items.all(I) :=
                    New_Item(To_String(EngineerOrders(I)), "0");
                  MenuIndex := MenuIndex + 1;
               end loop;
            when Gunner =>
               LastIndex :=
                 GunnerOrders'Length + 1 + PlayerShip.Crew.Last_Index;
               LastIndex := LastIndex + PlayerShip.Cargo.Last_Index;
               Orders_Items := new Item_Array(1 .. LastIndex);
               for I in GunnerOrders'Range loop
                  Orders_Items.all(I) :=
                    New_Item(To_String(GunnerOrders(I)), "0");
                  MenuIndex := MenuIndex + 1;
               end loop;
            when others =>
               null;
         end case;
      else
         LastIndex := PlayerShip.Crew.Last_Index + 2;
         LastIndex := LastIndex + PlayerShip.Cargo.Last_Index;
         Orders_Items := new Item_Array(1 .. LastIndex);
      end if;
      for I in PlayerShip.Crew.First_Index .. PlayerShip.Crew.Last_Index loop
         case Order is
            when Pilot =>
               if GetSkillLevel(PlayerShip.Crew(I), PilotingSkill) >
                 SkillValue then
                  SkillIndex := I;
                  SkillValue :=
                    GetSkillLevel(PlayerShip.Crew(I), PilotingSkill);
               end if;
            when Engineer =>
               if GetSkillLevel(PlayerShip.Crew(I), EngineeringSkill) >
                 SkillValue then
                  SkillIndex := I;
                  SkillValue :=
                    GetSkillLevel(PlayerShip.Crew(I), EngineeringSkill);
               end if;
            when Gunner =>
               if GetSkillLevel(PlayerShip.Crew(I), GunnerySkill) >
                 SkillValue then
                  SkillIndex := I;
                  SkillValue :=
                    GetSkillLevel(PlayerShip.Crew(I), GunnerySkill);
               end if;
            when others =>
               null;
         end case;
      end loop;
      for I in PlayerShip.Crew.First_Index .. PlayerShip.Crew.Last_Index loop
         if I /= MemberIndex and PlayerShip.Crew(I).Skills.Length > 0 then
            SkillString := Null_Unbounded_String;
            case Order is
               when Pilot =>
                  if GetSkillLevel(PlayerShip.Crew(I), PilotingSkill) > 0 then
                     SkillString := To_Unbounded_String(" +");
                  end if;
               when Engineer =>
                  if GetSkillLevel(PlayerShip.Crew(I), EngineeringSkill) >
                    0 then
                     SkillString := To_Unbounded_String(" +");
                  end if;
               when Gunner =>
                  if GetSkillLevel(PlayerShip.Crew(I), GunnerySkill) > 0 then
                     SkillString := To_Unbounded_String(" +");
                  end if;
               when others =>
                  null;
            end case;
            if I = SkillIndex then
               SkillString := SkillString & To_Unbounded_String("+");
            end if;
            if PlayerShip.Crew(I).Order /= Rest then
               SkillString := SkillString & To_Unbounded_String(" -");
            end if;
            Orders_Items.all(MenuIndex) :=
              New_Item
                ("Assign " &
                 To_String(PlayerShip.Crew(I).Name) &
                 To_String(SkillString),
                 Positive'Image(I));
            MenuIndex := MenuIndex + 1;
         end if;
      end loop;
      if Order = Gunner and MemberIndex > 0 then
         for Gun of Guns loop
            if PlayerShip.Modules(Gun(1)).Owner = MemberIndex then
               for I in
                 PlayerShip.Cargo.First_Index ..
                     PlayerShip.Cargo.Last_Index loop
                  if Items_List(PlayerShip.Cargo(I).ProtoIndex).IType =
                    Items_Types
                      (Modules_List(PlayerShip.Modules(Gun(1)).ProtoIndex)
                         .Value) and
                    I /= PlayerShip.Modules(Gun(1)).Data(1) then
                     Orders_Items.all(MenuIndex) :=
                       New_Item
                         ("Use " &
                          To_String
                            (Items_List(PlayerShip.Cargo(I).ProtoIndex).Name),
                          Positive'Image((0 - I)));
                     MenuIndex := MenuIndex + 1;
                  end if;
               end loop;
               exit;
            end if;
         end loop;
      end if;
      Orders_Items.all(MenuIndex) := New_Item("Close", "0");
      MenuIndex := MenuIndex + 1;
      for I in MenuIndex .. LastIndex loop
         Orders_Items.all(I) := Null_Item;
      end loop;
      OrdersMenu := New_Menu(Orders_Items);
      MenuOptions := Get_Options(OrdersMenu);
      MenuOptions.Show_Descriptions := False;
      Set_Options(OrdersMenu, MenuOptions);
      Scale(OrdersMenu, MenuHeight, MenuLength);
      MenuWindow2 :=
        Create
          (MenuHeight + 2,
           MenuLength + 2,
           ((Lines / 3) - (MenuHeight / 2)),
           ((Columns / 2) - (MenuLength / 2)));
      WindowFrame(MenuWindow2, 5, "Give order");
      Set_Window(OrdersMenu, MenuWindow2);
      Set_Sub_Window
        (OrdersMenu,
         Derived_Window(MenuWindow2, MenuHeight, MenuLength, 1, 1));
      Post(OrdersMenu);
      Refresh_Without_Update;
      Refresh_Without_Update(MenuWindow2);
      Update_Screen;
   end ShowOrdersMenu;

   procedure ShowEnemyInfo is
      DamagePercent, SpaceIndex: Natural;
      InfoText, ModuleName: Unbounded_String := Null_Unbounded_String;
      LinesAmount, TmpLinesAmount: Line_Position;
      TextPosition, EndTextPosition: Positive := 1;
      BoxLines: Line_Position := Lines / 2;
   begin
      if EnemyPad = Null_Window then
         TmpLinesAmount := 1;
         if Enemy.Ship.Description /= Null_Unbounded_String then
            while TextPosition < Length(Enemy.Ship.Description) loop
               EndTextPosition := TextPosition + (Positive(Columns / 2) - 3);
               if EndTextPosition > Length(Enemy.Ship.Description) then
                  EndTextPosition := Length(Enemy.Ship.Description);
               end if;
               Append
                 (InfoText,
                  Unbounded_Slice
                    (Enemy.Ship.Description,
                     TextPosition,
                     EndTextPosition));
               Append(InfoText, ASCII.LF);
               TmpLinesAmount := TmpLinesAmount + 1;
               TextPosition := EndTextPosition + 1;
            end loop;
            Append(InfoText, ASCII.LF);
            TmpLinesAmount := TmpLinesAmount + 1;
         end if;
         for I in Enemy.Ship.Modules.Iterate loop
            if Enemy.Distance > 1000 then
               ModuleName :=
                 To_Unbounded_String
                   (ModuleType'Image
                      (Modules_List(Enemy.Ship.Modules(I).ProtoIndex).MType));
               Replace_Slice
                 (ModuleName,
                  2,
                  Length(ModuleName),
                  To_Lower(Slice(ModuleName, 2, Length(ModuleName))));
               SpaceIndex := Index(ModuleName, "_");
               while SpaceIndex > 0 loop
                  Replace_Element(ModuleName, SpaceIndex, ' ');
                  SpaceIndex := Index(ModuleName, "_");
               end loop;
            else
               ModuleName :=
                 Modules_List(Enemy.Ship.Modules(I).ProtoIndex).Name;
            end if;
            Append(InfoText, To_String(ModuleName));
            Append(InfoText, ": ");
            DamagePercent :=
              100 -
              Natural
                ((Float(Enemy.Ship.Modules(I).Durability) /
                  Float(Enemy.Ship.Modules(I).MaxDurability)) *
                 100.0);
            if DamagePercent = 0 then
               Append(InfoText, "Ok");
            elsif DamagePercent > 0 and DamagePercent < 100 then
               Append(InfoText, "Damaged");
            else
               Append(InfoText, "Destroyed");
            end if;
            if Modules_Container.To_Index(I) <
              Enemy.Ship.Modules.Last_Index then
               Append(InfoText, ASCII.LF);
               TmpLinesAmount := TmpLinesAmount + 1;
            end if;
         end loop;
         LinesAmount :=
           Line_Position(Length(InfoText)) / Line_Position((Columns / 2));
         if LinesAmount < TmpLinesAmount then
            LinesAmount := TmpLinesAmount;
         end if;
         if BoxLines > LinesAmount + 2 then
            BoxLines := LinesAmount + 2;
         end if;
         EndIndex := Integer(LinesAmount) - Integer(Lines / 2) + 2;
         MenuWindow2 :=
           Create
             (BoxLines,
              ((Columns / 2) + 2),
              ((Lines / 5) - 1),
              ((Columns / 5) - 1));
         WindowFrame(MenuWindow2, 1, "Detailed enemy info");
         Refresh(MenuWindow2);
         EnemyPad := New_Pad(LinesAmount, (Columns / 2));
         Add(Win => EnemyPad, Str => To_String(InfoText));
      end if;
      Refresh
        (EnemyPad,
         Line_Position(StartIndex),
         0,
         (Lines / 5),
         (Columns / 5),
         ((Lines / 2) + 1),
         Columns);
   end ShowEnemyInfo;

   procedure ShowBoardingMenu is
      Orders_Items: constant Item_Array_Access :=
        new Item_Array
        (PlayerShip.Crew.First_Index .. PlayerShip.Crew.Last_Index + 2);
      MenuHeight: Line_Position;
      MenuLength: Column_Position;
   begin
      for I in PlayerShip.Crew.Iterate loop
         Orders_Items.all(Crew_Container.To_Index(I)) :=
           New_Item(To_String(PlayerShip.Crew(I).Name));
      end loop;
      Orders_Items.all(Orders_Items'Last - 1) := New_Item("Close");
      Orders_Items.all(Orders_Items'Last) := Null_Item;
      OrdersMenu := New_Menu(Orders_Items);
      Set_Options(OrdersMenu, (One_Valued => False, others => True));
      Set_Mark(OrdersMenu, "+");
      Scale(OrdersMenu, MenuHeight, MenuLength);
      if MenuLength < 22 then
         MenuLength := 22;
      end if;
      MenuWindow2 :=
        Create
          (MenuHeight + 2,
           MenuLength + 2,
           ((Lines / 3) - (MenuHeight / 2)),
           ((Columns / 2) - (MenuLength / 2)));
      WindowFrame(MenuWindow2, 5, "Set boarding party");
      Set_Window(OrdersMenu, MenuWindow2);
      Set_Sub_Window
        (OrdersMenu,
         Derived_Window(MenuWindow2, MenuHeight, MenuLength, 1, 1));
      Post(OrdersMenu);
      Refresh_Without_Update;
      Refresh_Without_Update(MenuWindow2);
      Update_Screen;
   end ShowBoardingMenu;

   function CombatKeys(Key: Key_Code) return GameStates is
      Result: Driver_Result;
      procedure SearchMenu is
      begin
         Result := Driver(CrewMenu, Key);
         if Result /= Menu_Ok then
            Result := Driver(CrewMenu, M_Clear_Pattern);
            Result := Driver(CrewMenu, Key);
         end if;
      end SearchMenu;
   begin
      if not EndCombat then
         case Key is
            when 56 | KEY_UP => -- Select previous crew position
               Result := Driver(CrewMenu, M_Up_Item);
               if Result = Request_Denied then
                  Result := Driver(CrewMenu, M_Last_Item);
               end if;
            when 50 | KEY_DOWN => -- Select next crew position
               Result := Driver(CrewMenu, M_Down_Item);
               if Result = Request_Denied then
                  Result := Driver(CrewMenu, M_First_Item);
               end if;
            when 10 => -- Give orders to selected position
               case Get_Index(Current(CrewMenu)) is
                  when 1 =>
                     Order := Pilot;
                  when 2 =>
                     Order := Engineer;
                  when others =>
                     Order := Gunner;
               end case;
               ShowOrdersMenu;
               return Combat_Orders;
            when Character'Pos
                (' ') => -- Next combat turn or back to sky map if end combat
               CombatTurn;
               DrawGame(Combat_State);
               return Combat_State;
            when Character'Pos('a') | Character'Pos('A') => -- Show ship cargo
               DrawGame(Cargo_Info);
               return Cargo_Info;
            when Character'Pos('s') | Character'Pos('S') => -- Show ship info
               DrawGame(Ship_Info);
               return Ship_Info;
            when Character'Pos('c') | Character'Pos('C') => -- Show crew info
               DrawGame(Crew_Info);
               return Crew_Info;
            when Character'Pos('m') |
              Character'Pos('M') => -- Show messages list
               DrawGame(Messages_View);
               return Messages_View;
            when Character'Pos('d') | Character'Pos('D') => -- Show enemy info
               EnemyPad := Null_Window;
               ShowEnemyInfo;
               return Enemy_Info;
            when Key_F1 => -- Show help
               Erase;
               ShowGameHeader(Help_Topic);
               ShowHelp(Combat_State, 4);
               return Help_Topic;
            when Character'Pos('b') |
              Character'Pos
                ('B') => -- Select boarding party and start boarding enemy ship
               if HarpoonDuration > 0 or Enemy.HarpoonDuration > 0 then
                  ShowBoardingMenu;
                  return Boarding_Menu;
               else
                  SearchMenu;
               end if;
            when others =>
               SearchMenu;
         end case;
         if Result = Menu_Ok then
            Refresh(MenuWindow);
         end if;
         CurrentMenuIndex := Get_Index(Current(CrewMenu));
         return Combat_State;
      else
         CurrentMenuIndex := 1;
         PlayerShip.Speed := OldSpeed;
         EnemyName := Null_Unbounded_String;
         UpdateOrders;
         DrawGame(Sky_Map_View);
         return Sky_Map_View;
      end if;
   end CombatKeys;

   function CombatOrdersKeys(Key: Key_Code) return GameStates is
      Result: Driver_Result;
   begin
      case Key is
         when 56 | KEY_UP => -- Select previous order
            Result := Driver(OrdersMenu, M_Up_Item);
            if Result = Request_Denied then
               Result := Driver(OrdersMenu, M_Last_Item);
            end if;
         when 50 | KEY_DOWN => -- Select next order
            Result := Driver(OrdersMenu, M_Down_Item);
            if Result = Request_Denied then
               Result := Driver(OrdersMenu, M_First_Item);
            end if;
         when 10 => -- Give order
            CombatOrders;
            DrawGame(Combat_State);
            return Combat_State;
         when 27 => -- Esc select close option, used second time, close menu
            if Name(Current(OrdersMenu)) = "Close" then
               DrawGame(Combat_State);
               return Combat_State;
            else
               Result := Driver(OrdersMenu, M_Last_Item);
            end if;
         when others =>
            Result := Driver(OrdersMenu, Key);
            if Result /= Menu_Ok then
               Result := Driver(OrdersMenu, M_Clear_Pattern);
               Result := Driver(OrdersMenu, Key);
            end if;
      end case;
      if Result = Menu_Ok then
         Refresh(MenuWindow2);
      end if;
      return Combat_Orders;
   end CombatOrdersKeys;

   function EnemyInfoKeys(Key: Key_Code) return GameStates is
   begin
      case Key is
         when 56 | KEY_UP => -- Scroll enemy info up one line
            StartIndex := StartIndex - 1;
         when 50 | KEY_DOWN => -- Scroll enemy info down one line
            StartIndex := StartIndex + 1;
         when 51 | KEY_NPAGE => -- Scroll enemy info down one page
            StartIndex := StartIndex + Integer(Lines / 2);
         when 57 | KEY_PPAGE => -- Scroll enemy info up one page
            StartIndex := StartIndex - Integer(Lines / 2);
         when 55 | Key_Home => -- Scroll enemy info to start
            StartIndex := 0;
         when 49 | Key_End => -- Scroll enemy info to end
            StartIndex := EndIndex;
         when others => -- Back to combat screen
            DrawGame(Combat_State);
            return Combat_State;
      end case;
      if StartIndex < 0 then
         StartIndex := 0;
      end if;
      if StartIndex > EndIndex then
         StartIndex := EndIndex;
      end if;
      ShowEnemyInfo;
      return Enemy_Info;
   end EnemyInfoKeys;

   function BoardingMenuKeys(Key: Key_Code) return GameStates is
      Result: Driver_Result;
   begin
      case Key is
         when 56 | KEY_UP => -- Select previous crew member
            Result := Driver(OrdersMenu, M_Up_Item);
            if Result = Request_Denied then
               Result := Driver(OrdersMenu, M_Last_Item);
            end if;
         when 50 | KEY_DOWN => -- Select next crew member
            Result := Driver(OrdersMenu, M_Down_Item);
            if Result = Request_Denied then
               Result := Driver(OrdersMenu, M_First_Item);
            end if;
         when 10 => -- Set selected crew member as boarding party member
            if Name(Current(OrdersMenu)) = "Close" then
               for I in
                 PlayerShip.Crew.First_Index .. PlayerShip.Crew.Last_Index loop
                  if Value(Menus.Items(OrdersMenu, I)) then
                     GiveOrders(I, Boarding);
                  end if;
               end loop;
               DrawGame(Combat_State);
               return Combat_State;
            else
               Result := Driver(OrdersMenu, M_Toggle_Item);
            end if;
         when 27 => -- Esc select close option, used second time, close menu
            if Name(Current(OrdersMenu)) = "Close" then
               DrawGame(Combat_State);
               return Combat_State;
            else
               Result := Driver(OrdersMenu, M_Last_Item);
            end if;
         when others =>
            Result := Driver(OrdersMenu, Key);
            if Result /= Menu_Ok then
               Result := Driver(OrdersMenu, M_Clear_Pattern);
               Result := Driver(OrdersMenu, Key);
            end if;
      end case;
      if Result = Menu_Ok then
         Refresh(MenuWindow2);
      end if;
      return Boarding_Menu;
   end BoardingMenuKeys;

end Combat.UI;
