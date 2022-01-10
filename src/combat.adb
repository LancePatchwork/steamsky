--    Copyright 2016-2022 Bartek thindil Jasicki
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

with GNAT.String_Split; use GNAT.String_Split;
with Crew; use Crew;
with Messages; use Messages;
with ShipModules; use ShipModules;
with Items; use Items;
with Statistics; use Statistics;
with Events; use Events;
with Maps; use Maps;
with Bases; use Bases;
with Missions; use Missions;
with Ships.Cargo; use Ships.Cargo;
with Ships.Crew; use Ships.Crew;
with Ships.Movement; use Ships.Movement;
with Utils; use Utils;
with Log; use Log;
with Goals; use Goals;
with Factions; use Factions;
with Stories; use Stories;
with Config; use Config;
with Trades; use Trades;

package body Combat is

   -- ****iv* Combat/Combat.FactionName
   -- FUNCTION
   -- Name of enemy ship (and its crew) faction
   -- SOURCE
   FactionName: Unbounded_String;
   -- ****

   -- ****iv* Combat/Combat.TurnNumber
   -- FUNCTION
   -- Number of turn of combat
   -- SOURCE
   TurnNumber: Natural;
   -- ****

   function StartCombat
     (EnemyIndex: Unbounded_String; NewCombat: Boolean := True)
      return Boolean is
      EnemyShip: Ship_Record;
      EnemyGuns: Guns_Container.Vector;
      ShootingSpeed: Integer;
      function CountPerception(Spotter, Spotted: Ship_Record) return Natural is
         Result: Natural := 0;
      begin
         Count_Spotter_Perception_Loop :
         for I in Spotter.Crew.Iterate loop
            case Spotter.Crew(I).Order is
               when PILOT =>
                  Result :=
                    Result +
                    Get_Skill_Level(Spotter.Crew(I), Perception_Skill);
                  if Spotter = Player_Ship then
                     Gain_Exp(1, Natural(Perception_Skill), Crew_Container.To_Index(I));
                  end if;
               when GUNNER =>
                  Result :=
                    Result +
                    Get_Skill_Level(Spotter.Crew(I), Perception_Skill);
                  if Spotter = Player_Ship then
                     Gain_Exp(1, Natural(Perception_Skill), Crew_Container.To_Index(I));
                  end if;
               when others =>
                  null;
            end case;
         end loop Count_Spotter_Perception_Loop;
         Count_Modules_Loop :
         for Module of Spotted.Modules loop
            if Module.M_Type = HULL then
               Result := Result + Module.Max_Modules;
               exit Count_Modules_Loop;
            end if;
         end loop Count_Modules_Loop;
         return Result;
      end CountPerception;
   begin
      EnemyShipIndex := EnemyIndex;
      FactionName := Factions_List(Proto_Ships_List(EnemyIndex).Owner).Name;
      HarpoonDuration := 0;
      BoardingOrders.Clear;
      EnemyShip :=
        Create_Ship
          (EnemyIndex, Null_Unbounded_String, Player_Ship.Sky_X,
           Player_Ship.Sky_Y, FULL_SPEED);
      -- Enemy ship is trader, generate cargo for it
      if Index(Proto_Ships_List(EnemyIndex).Name, To_String(Traders_Name)) >
        0 then
         GenerateTraderCargo(EnemyIndex);
         Update_Cargo_Loop :
         for Item of TraderCargo loop
            UpdateCargo(EnemyShip, Item.Proto_Index, Item.Amount);
         end loop Update_Cargo_Loop;
         TraderCargo.Clear;
      end if;
      declare
         MinFreeSpace, ItemIndex, CargoItemIndex: Natural := 0;
         ItemAmount: Positive;
         NewItemIndex: Tiny_String.Bounded_String;
      begin
         Count_Free_Space_Loop :
         for Module of EnemyShip.Modules loop
            if Module.M_Type = CARGO_ROOM and Module.Durability > 0 then
               MinFreeSpace :=
                 MinFreeSpace + Modules_List(Module.Proto_Index).Max_Value;
            end if;
         end loop Count_Free_Space_Loop;
         MinFreeSpace :=
           Natural
             (Float(MinFreeSpace) *
              (1.0 - (Float(Get_Random(20, 70)) / 100.0)));
         Add_Enemy_Cargo_Loop :
         loop
            exit Add_Enemy_Cargo_Loop when FreeCargo(0, EnemyShip) <=
              MinFreeSpace;
            ItemIndex := Get_Random(1, Positive(Items_List.Length));
            Find_Item_Index_Loop :
            for I in Items_List.Iterate loop
               ItemIndex := ItemIndex - 1;
               if ItemIndex = 0 then
                  NewItemIndex := Objects_Container.Key(I);
                  exit Find_Item_Index_Loop;
               end if;
            end loop Find_Item_Index_Loop;
            ItemAmount :=
              (if EnemyShip.Crew.Length < 5 then Get_Random(1, 100)
               elsif EnemyShip.Crew.Length < 10 then Get_Random(1, 500)
               else Get_Random(1, 1_000));
            CargoItemIndex := Find_Item(EnemyShip.Cargo, NewItemIndex);
            if CargoItemIndex > 0 then
               EnemyShip.Cargo(CargoItemIndex).Amount :=
                 EnemyShip.Cargo(CargoItemIndex).Amount + ItemAmount;
            else
               if FreeCargo
                   (0 - (Items_List(NewItemIndex).Weight * ItemAmount)) >
                 -1 then
                  EnemyShip.Cargo.Append
                    (New_Item =>
                       (Proto_Index => NewItemIndex, Amount => ItemAmount,
                        Durability => 100, Name => Null_Unbounded_String,
                        Price => 0));
               end if;
            end if;
         end loop Add_Enemy_Cargo_Loop;
      end;
      EnemyGuns.Clear;
      Count_Enemy_Shooting_Speed_Loop :
      for I in EnemyShip.Modules.Iterate loop
         if (EnemyShip.Modules(I).M_Type in GUN | HARPOON_GUN) and
           EnemyShip.Modules(I).Durability > 0 then
            if Modules_List(EnemyShip.Modules(I).Proto_Index).Speed > 0 then
               ShootingSpeed :=
                 (if Proto_Ships_List(EnemyIndex).Combat_Ai = DISARMER then
                    Natural
                      (Float'Ceiling
                         (Float
                            (Modules_List(EnemyShip.Modules(I).Proto_Index)
                               .Speed) /
                          2.0))
                  else Modules_List(EnemyShip.Modules(I).Proto_Index).Speed);
            else
               ShootingSpeed :=
                 (if Proto_Ships_List(EnemyIndex).Combat_Ai = DISARMER then
                    Modules_List(EnemyShip.Modules(I).Proto_Index).Speed - 1
                  else Modules_List(EnemyShip.Modules(I).Proto_Index).Speed);
            end if;
            EnemyGuns.Append
              (New_Item => (Modules_Container.To_Index(I), 1, ShootingSpeed));
         end if;
      end loop Count_Enemy_Shooting_Speed_Loop;
      Enemy :=
        (Ship => EnemyShip, Accuracy => 0, Distance => 10_000,
         CombatAI => Proto_Ships_List(EnemyIndex).Combat_Ai, Evasion => 0,
         Loot => 0, Perception => 0, HarpoonDuration => 0, Guns => EnemyGuns);
      Enemy.Accuracy :=
        (if Proto_Ships_List(EnemyIndex).Accuracy(2) = 0 then
           Proto_Ships_List(EnemyIndex).Accuracy(1)
         else Get_Random
             (Proto_Ships_List(EnemyIndex).Accuracy(1),
              Proto_Ships_List(EnemyIndex).Accuracy(2)));
      Enemy.Evasion :=
        (if Proto_Ships_List(EnemyIndex).Evasion(2) = 0 then
           Proto_Ships_List(EnemyIndex).Evasion(1)
         else Get_Random
             (Proto_Ships_List(EnemyIndex).Evasion(1),
              Proto_Ships_List(EnemyIndex).Evasion(2)));
      Enemy.Perception :=
        (if Proto_Ships_List(EnemyIndex).Perception(2) = 0 then
           Proto_Ships_List(EnemyIndex).Perception(1)
         else Get_Random
             (Proto_Ships_List(EnemyIndex).Perception(1),
              Proto_Ships_List(EnemyIndex).Perception(2)));
      Enemy.Loot :=
        (if Proto_Ships_List(EnemyIndex).Loot(2) = 0 then
           Proto_Ships_List(EnemyIndex).Loot(1)
         else Get_Random
             (Proto_Ships_List(EnemyIndex).Loot(1),
              Proto_Ships_List(EnemyIndex).Loot(2)));
      if PilotOrder = 0 then
         PilotOrder := 2;
         EngineerOrder := 3;
      end if;
      EndCombat := False;
      EnemyName := Generate_Ship_Name(Proto_Ships_List(EnemyIndex).Owner);
      MessagesStarts := Get_Last_Message_Index + 1;
      declare
         Old_Guns_List: constant Guns_Container.Vector := Guns;
         Same_Lists: Boolean := True;
      begin
         Guns.Clear;
         Set_Player_Guns_Loop :
         for I in Player_Ship.Modules.Iterate loop
            if (Player_Ship.Modules(I).M_Type in GUN | HARPOON_GUN) and
              Player_Ship.Modules(I).Durability > 0 then
               Guns.Append
                 (New_Item =>
                    (Modules_Container.To_Index(I), 1,
                     Modules_List(Player_Ship.Modules(I).Proto_Index).Speed));
            end if;
         end loop Set_Player_Guns_Loop;
         if Old_Guns_List.Length > 0 and
           Old_Guns_List.Length = Guns.Length then
            Compare_Lists_Loop :
            for I in Guns.First_Index .. Guns.Last_Index loop
               if Guns(I)(1) /= Old_Guns_List(I)(1) then
                  Same_Lists := False;
                  exit Compare_Lists_Loop;
               end if;
            end loop Compare_Lists_Loop;
            if Same_Lists then
               Guns := Old_Guns_List;
            end if;
         end if;
      end;
      if NewCombat then
         declare
            PlayerPerception: constant Natural :=
              CountPerception(Player_Ship, Enemy.Ship);
            EnemyPerception: Natural := 0;
         begin
            OldSpeed := Player_Ship.Speed;
            EnemyPerception :=
              (if Enemy.Perception > 0 then Enemy.Perception
               else CountPerception(Enemy.Ship, Player_Ship));
            if (PlayerPerception + Get_Random(1, 50)) >
              (EnemyPerception + Get_Random(1, 50)) then
               Add_Message
                 ("You spotted " & To_String(Enemy.Ship.Name) & ".",
                  OTHERMESSAGE);
            else
               if RealSpeed(Player_Ship) < RealSpeed(Enemy.Ship) then
                  Log_Message
                    ("You were attacked by " & To_String(Enemy.Ship.Name),
                     Log.COMBAT);
                  Add_Message
                    (To_String(Enemy.Ship.Name) & " intercepted you.",
                     COMBATMESSAGE);
                  return True;
               end if;
               Add_Message
                 ("You spotted " & To_String(Enemy.Ship.Name) & ".",
                  OTHERMESSAGE);
            end if;
         end;
         return False;
      end if;
      TurnNumber := 0;
      Log_Message
        ("Started combat with " & To_String(Enemy.Ship.Name), Log.COMBAT);
      return True;
   end StartCombat;

   procedure CombatTurn is
      use Tiny_String;

      AccuracyBonus, EvadeBonus: Integer := 0;
      PilotIndex, EngineerIndex, EnemyWeaponIndex, EnemyAmmoIndex,
      EnemyPilotIndex, AmmoIndex2: Natural := 0;
      DistanceTraveled, SpeedBonus: Integer;
      ShootMessage, Message: Unbounded_String;
      EnemyPilotOrder: Positive := 2;
      DamageRange: Positive := 10_000;
      FreeSpace: Integer := 0;
      procedure Attack(Ship, EnemyShip: in out Ship_Record) is
         GunnerIndex: Crew_Container.Extended_Index;
         AmmoIndex: Inventory_Container.Extended_Index;
         ArmorIndex, WeaponIndex: Modules_Container.Extended_Index;
         Shoots: Natural;
         GunnerOrder: Positive;
         HitChance, HitLocation, CurrentAccuracyBonus: Integer;
         Damage: Damage_Factor := 0.0;
         WeaponDamage: Integer;
         EnemyNameOwner: constant Unbounded_String :=
           EnemyName & To_Unbounded_String(" (") & FactionName &
           To_Unbounded_String(")");
         procedure RemoveGun(ModuleIndex: Positive) is
         begin
            if EnemyShip = Player_Ship then
               Remove_Gun_Loop :
               for J in Guns.First_Index .. Guns.Last_Index loop
                  if Guns(J)(1) = ModuleIndex then
                     Guns.Delete(Index => J);
                     exit Remove_Gun_Loop;
                  end if;
               end loop Remove_Gun_Loop;
            end if;
         end RemoveGun;
         function FindEnemyModule(MType: Module_Type) return Natural is
         begin
            Find_Enemy_Module_Loop :
            for I in EnemyShip.Modules.Iterate loop
               if Modules_List(EnemyShip.Modules(I).Proto_Index).M_Type =
                 MType and
                 EnemyShip.Modules(I).Durability > 0 then
                  return Modules_Container.To_Index(I);
               end if;
            end loop Find_Enemy_Module_Loop;
            return 0;
         end FindEnemyModule;
         procedure FindHitWeapon is
         begin
            Find_Weapon_Location_Loop :
            for J in EnemyShip.Modules.Iterate loop
               if
                 ((EnemyShip.Modules(J).M_Type = TURRET
                   and then EnemyShip.Modules(J).Gun_Index > 0) or
                  Modules_List(EnemyShip.Modules(J).Proto_Index).M_Type =
                    BATTERING_RAM) and
                 EnemyShip.Modules(J).Durability > 0 then
                  HitLocation := Modules_Container.To_Index(J);
                  return;
               end if;
            end loop Find_Weapon_Location_Loop;
         end FindHitWeapon;
      begin
         if Ship = Player_Ship then
            Log_Message("Player's round.", Log.COMBAT);
         else
            Log_Message("Enemy's round.", Log.COMBAT);
         end if;
         Attack_Loop :
         for K in Ship.Modules.Iterate loop
            if Ship.Modules(K).Durability = 0 or
              (Ship.Modules(K).M_Type not in GUN | BATTERING_RAM |
                   HARPOON_GUN) then
               goto End_Of_Attack_Loop;
            end if;
            GunnerIndex := 0;
            AmmoIndex := 0;
            if Ship.Modules(K).M_Type = HARPOON_GUN then
               AmmoIndex2 := Ship.Modules(K).Harpoon_Index;
            elsif Ship.Modules(K).M_Type = GUN then
               AmmoIndex2 := Ship.Modules(K).Ammo_Index;
            end if;
            if Ship.Modules(K).M_Type in GUN | HARPOON_GUN then
               GunnerIndex := Ship.Modules(K).Owner(1);
               Log_Message
                 ("Gunner index:" & Natural'Image(GunnerIndex) & ".",
                  Log.COMBAT);
               if Ship = Player_Ship then
                  Shoots := 0;
                  if GunnerIndex > 0 then
                     Count_Player_Shoots_Loop :
                     for Gun of Guns loop
                        if Gun(1) = Modules_Container.To_Index(K) then
                           GunnerOrder := Gun(2);
                           if Gun(3) > 0 then
                              Shoots := Gun(3);
                              if GunnerOrder /= 3 then
                                 Shoots :=
                                   Natural(Float'Ceiling(Float(Shoots) / 2.0));
                              end if;
                              Log_Message
                                ("Player Shoots (no cooldown):" &
                                 Natural'Image(Shoots),
                                 Log.COMBAT);
                           elsif Gun(3) < 0 then
                              Shoots := 0;
                              Gun(3) := Gun(3) + 1;
                              if Gun(3) = 0 then
                                 Shoots := 1;
                                 Gun(3) :=
                                   (if GunnerOrder = 3 then
                                      Modules_List
                                        (Player_Ship.Modules(Gun(1))
                                           .Proto_Index)
                                        .Speed
                                    else Modules_List
                                        (Player_Ship.Modules(Gun(1))
                                           .Proto_Index)
                                        .Speed -
                                      1);
                              end if;
                              Log_Message
                                ("Player Shoots (after cooldown):" &
                                 Natural'Image(Shoots),
                                 Log.COMBAT);
                           end if;
                           exit Count_Player_Shoots_Loop;
                        end if;
                     end loop Count_Player_Shoots_Loop;
                     Log_Message
                       ("Shoots test3:" & Natural'Image(Shoots), Log.COMBAT);
                     if Ship.Crew(GunnerIndex).Order /= GUNNER then
                        GunnerOrder := 1;
                     end if;
                     case GunnerOrder is
                        when 1 =>
                           if Shoots > 0 then
                              Shoots := 0;
                           end if;
                        when 2 =>
                           CurrentAccuracyBonus := AccuracyBonus + 20;
                        when 4 =>
                           CurrentAccuracyBonus := AccuracyBonus - 10;
                        when 5 =>
                           CurrentAccuracyBonus := AccuracyBonus - 20;
                        when others =>
                           null;
                     end case;
                  end if;
               else
                  Count_Enemy_Shoots_Loop :
                  for Gun of Enemy.Guns loop
                     if Gun(1) = Modules_Container.To_Index(K) then
                        if Gun(3) > 0 then
                           Shoots := Gun(3);
                        elsif Gun(3) < 0 then
                           Shoots := 0;
                           Gun(3) := Gun(3) + 1;
                           if Gun(3) = 0 then
                              Shoots := 1;
                              Gun(3) :=
                                (if Enemy.CombatAI = DISARMER then
                                   Modules_List
                                     (Ship.Modules(Gun(1)).Proto_Index)
                                     .Speed -
                                   1
                                 else Modules_List
                                     (Ship.Modules(Gun(1)).Proto_Index)
                                     .Speed);
                           end if;
                        end if;
                        exit Count_Enemy_Shoots_Loop;
                     end if;
                  end loop Count_Enemy_Shoots_Loop;
                  if Ship.Crew.Length > 0 and GunnerIndex = 0 then
                     Shoots := 0;
                  end if;
               end if;
               if AmmoIndex2 in Ship.Cargo.First_Index .. Ship.Cargo.Last_Index
                 and then
                   Items_List(Ship.Cargo(AmmoIndex2).Proto_Index).I_Type =
                   Items_Types
                     (Modules_List(Ship.Modules(K).Proto_Index).Value) then
                  AmmoIndex := AmmoIndex2;
               end if;
               if AmmoIndex = 0 then
                  Find_Ammo_Index_Loop :
                  for I in Items_List.Iterate loop
                     if Items_List(I).I_Type =
                       Items_Types
                         (Modules_List(Ship.Modules(K).Proto_Index).Value) then
                        Get_Ammo_Index_Loop :
                        for J in Ship.Cargo.Iterate loop
                           if Ship.Cargo(J).Proto_Index =
                             Objects_Container.Key(I) then
                              AmmoIndex := Inventory_Container.To_Index(J);
                              if Ship.Modules(K).M_Type = HARPOON_GUN then
                                 Ship.Modules(K).Harpoon_Index := AmmoIndex;
                              elsif Ship.Modules(K).M_Type = GUN then
                                 Ship.Modules(K).Ammo_Index := AmmoIndex;
                              end if;
                              exit Get_Ammo_Index_Loop;
                           end if;
                        end loop Get_Ammo_Index_Loop;
                        exit Find_Ammo_Index_Loop when AmmoIndex > 0;
                     end if;
                  end loop Find_Ammo_Index_Loop;
               end if;
               if AmmoIndex = 0 then
                  if Ship = Player_Ship then
                     Add_Message
                       ("You don't have ammo to " &
                        To_String(Ship.Modules(K).Name) & "!",
                        COMBATMESSAGE, RED);
                  end if;
                  Shoots := 0;
               elsif Ship.Cargo(AmmoIndex).Amount < Shoots then
                  Shoots := Ship.Cargo(AmmoIndex).Amount;
               end if;
               if Enemy.Distance > 5_000 then
                  Shoots := 0;
               end if;
               if Ship.Modules(K).M_Type = HARPOON_GUN and Shoots > 0 then
                  Shoots := 1;
                  if Enemy.Distance > 2_000 then
                     Shoots := 0;
                  end if;
                  if FindEnemyModule(ARMOR) > 0 then
                     Shoots := 0;
                  end if;
               end if;
               if Ship.Modules(K).M_Type = GUN and Shoots > 0 then
                  case Items_List(Ship.Cargo(AmmoIndex).Proto_Index).Value
                    (2) is
                     when 2 =>
                        if Ship = Player_Ship then
                           CurrentAccuracyBonus := CurrentAccuracyBonus - 10;
                        else
                           EvadeBonus := EvadeBonus + 10;
                        end if;
                     when 3 =>
                        if Ship = Player_Ship then
                           CurrentAccuracyBonus := CurrentAccuracyBonus + 10;
                        else
                           EvadeBonus := EvadeBonus - 10;
                        end if;
                     when others =>
                        null;
                  end case;
               end if;
            else
               if Enemy.Distance > 100 then
                  Shoots := 0;
               else
                  Shoots := (if Ship.Modules(K).Cooling_Down then 0 else 1);
               end if;
               Ship.Modules(K).Cooling_Down :=
                 not Ship.Modules(K).Cooling_Down;
            end if;
            Log_Message("Shoots:" & Integer'Image(Shoots), Log.COMBAT);
            if Shoots > 0 then
               HitChance :=
                 (if Ship = Player_Ship then
                    CurrentAccuracyBonus - Enemy.Evasion
                  else Enemy.Accuracy - EvadeBonus);
               if GunnerIndex > 0 then
                  HitChance :=
                    HitChance +
                    Get_Skill_Level(Ship.Crew(GunnerIndex), Gunnery_Skill);
               end if;
               if HitChance < -48 then
                  HitChance := -48;
               end if;
               Log_Message
                 ("Player Accuracy:" & Integer'Image(CurrentAccuracyBonus) &
                  " Player Evasion:" & Integer'Image(EvadeBonus),
                  Log.COMBAT);
               Log_Message
                 ("Enemy Evasion:" & Integer'Image(Enemy.Evasion) &
                  " Enemy Accuracy:" & Integer'Image(Enemy.Accuracy),
                  Log.COMBAT);
               Log_Message
                 ("Chance to hit:" & Integer'Image(HitChance), Log.COMBAT);
               Shooting_Loop :
               for I in 1 .. Shoots loop
                  if Ship = Player_Ship then
                     ShootMessage :=
                       (if Ship.Modules(K).M_Type in GUN | HARPOON_GUN then
                          Ship.Crew(GunnerIndex).Name &
                          To_Unbounded_String(" shoots at ") & EnemyNameOwner
                        else To_Unbounded_String("You ram ") & EnemyNameOwner);
                  else
                     ShootMessage :=
                       EnemyNameOwner & To_Unbounded_String(" attacks");
                  end if;
                  if HitChance + Get_Random(1, 50) >
                    Get_Random(1, HitChance + 50) then
                     ShootMessage :=
                       ShootMessage & To_Unbounded_String(" and hits ");
                     ArmorIndex := FindEnemyModule(ARMOR);
                     if ArmorIndex > 0 then
                        HitLocation := ArmorIndex;
                     else
                        if Ship = Player_Ship then
                           if GunnerIndex > 0
                             and then GunnerOrder in
                               4 ..
                                     6 then -- aim for part of enemy ship
                              HitLocation := 0;
                              case GunnerOrder is
                                 when 4 =>
                                    HitLocation := FindEnemyModule(ENGINE);
                                 when 5 =>
                                    HitLocation := 0;
                                    FindHitWeapon;
                                    if HitLocation = 0 then
                                       HitLocation :=
                                         FindEnemyModule(BATTERING_RAM);
                                    end if;
                                 when 6 =>
                                    HitLocation := FindEnemyModule(HULL);
                                 when others =>
                                    HitLocation := 1;
                              end case;
                              if HitLocation = 0 then
                                 HitLocation := 1;
                              end if;
                           else
                              HitLocation :=
                                Get_Random
                                  (Enemy.Ship.Modules.First_Index,
                                   Enemy.Ship.Modules.Last_Index);
                           end if;
                        else
                           if Enemy.CombatAI = DISARMER then
                              HitLocation := 1;
                              FindHitWeapon;
                           else
                              HitLocation :=
                                Get_Random
                                  (Player_Ship.Modules.First_Index,
                                   Player_Ship.Modules.Last_Index);
                           end if;
                        end if;
                        Get_Hit_Location_Loop :
                        while EnemyShip.Modules(HitLocation).Durability =
                          0 loop
                           HitLocation := HitLocation - 1;
                           exit Attack_Loop when HitLocation = 0;
                        end loop Get_Hit_Location_Loop;
                     end if;
                     ShootMessage :=
                       ShootMessage & EnemyShip.Modules(HitLocation).Name &
                       To_Unbounded_String(".");
                     Damage :=
                       1.0 -
                       Damage_Factor
                         (Float(Ship.Modules(K).Durability) /
                          Float(Ship.Modules(K).Max_Durability));
                     if Ship.Modules(K).M_Type = HARPOON_GUN then
                        WeaponDamage :=
                          Ship.Modules(K).Duration -
                          Natural
                            (Float(Ship.Modules(K).Duration) * Float(Damage));
                     elsif Ship.Modules(K).M_Type = GUN then
                        WeaponDamage :=
                          Ship.Modules(K).Damage -
                          Natural
                            (Float(Ship.Modules(K).Damage) * Float(Damage));
                     elsif Ship.Modules(K).M_Type = BATTERING_RAM then
                        WeaponDamage :=
                          Ship.Modules(K).Damage2 -
                          Natural
                            (Float(Ship.Modules(K).Damage2) * Float(Damage));
                        WeaponDamage :=
                          (if SpeedBonus < 0 then
                             WeaponDamage +
                             (abs (SpeedBonus) *
                              (Count_Ship_Weight(Ship) / 5_000))
                           else WeaponDamage +
                             (Count_Ship_Weight(Ship) / 5_000));
                     end if;
                     if WeaponDamage = 0 then
                        WeaponDamage := 1;
                     end if;
                     if AmmoIndex > 0 then
                        WeaponDamage :=
                          WeaponDamage +
                          Items_List(Ship.Cargo(AmmoIndex).Proto_Index).Value
                            (1);
                     end if;
                     WeaponDamage :=
                       (if Ship = Player_Ship then
                          Integer
                            (Float(WeaponDamage) *
                             Float(New_Game_Settings.Player_Damage_Bonus))
                        else Integer
                            (Float(WeaponDamage) *
                             Float(New_Game_Settings.Enemy_Damage_Bonus)));
                     if ArmorIndex = 0 then
                        if Ship.Modules(K).M_Type = HARPOON_GUN then
                           Count_Damage_Loop :
                           for Module of EnemyShip.Modules loop
                              if Module.M_Type = HULL then
                                 WeaponDamage :=
                                   WeaponDamage - (Module.Max_Modules / 10);
                                 if WeaponDamage < 1 then
                                    WeaponDamage := 1;
                                 end if;
                                 exit Count_Damage_Loop;
                              end if;
                           end loop Count_Damage_Loop;
                           if Ship = Player_Ship then
                              Enemy.HarpoonDuration :=
                                Enemy.HarpoonDuration + WeaponDamage;
                           else
                              HarpoonDuration :=
                                HarpoonDuration + WeaponDamage;
                           end if;
                           WeaponDamage := 1;
                        elsif Ship.Modules(K).M_Type = BATTERING_RAM then
                           if Ship = Player_Ship then
                              Enemy.HarpoonDuration :=
                                Enemy.HarpoonDuration + 2;
                           else
                              HarpoonDuration := HarpoonDuration + 2;
                           end if;
                        end if;
                     end if;
                     Damage_Module
                       (EnemyShip, HitLocation, WeaponDamage,
                        "enemy fire in ship combat");
                     if EnemyShip.Modules(HitLocation).Durability = 0 then
                        case Modules_List
                          (EnemyShip.Modules(HitLocation).Proto_Index)
                          .M_Type is
                           when HULL | ENGINE =>
                              EndCombat := True;
                           when TURRET =>
                              if EnemyShip = Player_Ship then
                                 WeaponIndex :=
                                   EnemyShip.Modules(HitLocation).Gun_Index;
                                 if WeaponIndex > 0 then
                                    EnemyShip.Modules(WeaponIndex)
                                      .Durability :=
                                      0;
                                    RemoveGun(WeaponIndex);
                                 end if;
                              end if;
                           when GUN =>
                              if EnemyShip = Player_Ship then
                                 RemoveGun(HitLocation);
                              end if;
                           when others =>
                              null;
                        end case;
                     end if;
                     if Ship = Player_Ship then
                        Add_Message
                          (To_String(ShootMessage), COMBATMESSAGE, GREEN);
                     else
                        Add_Message
                          (To_String(ShootMessage), COMBATMESSAGE, YELLOW);
                     end if;
                  else
                     ShootMessage :=
                       ShootMessage & To_Unbounded_String(" and misses.");
                     if Ship = Player_Ship then
                        Add_Message
                          (To_String(ShootMessage), COMBATMESSAGE, BLUE);
                     else
                        Add_Message
                          (To_String(ShootMessage), COMBATMESSAGE, CYAN);
                     end if;
                  end if;
                  if AmmoIndex > 0 then
                     UpdateCargo
                       (Ship => Ship, CargoIndex => AmmoIndex, Amount => -1);
                  end if;
                  if Ship = Player_Ship and GunnerIndex > 0 then
                     Gain_Exp(2, Natural(Gunnery_Skill), GunnerIndex);
                  end if;
                  if Player_Ship.Crew(1).Health = 0 then -- player is dead
                     EndCombat := True;
                  end if;
                  exit Attack_Loop when EndCombat;
               end loop Shooting_Loop;
            end if;
            <<End_Of_Attack_Loop>>
         end loop Attack_Loop;
      end Attack;
      procedure MeleeCombat
        (Attackers, Defenders: in out Crew_Container.Vector;
         PlayerAttack: Boolean) is
         AttackDone, Riposte: Boolean;
         AttackerIndex, DefenderIndex: Positive;
         OrderIndex: Natural;
         function CharacterAttack
           (AttackerIndex, DefenderIndex: Positive; PlayerAttack2: Boolean)
            return Boolean is
            HitChance, Damage: Integer;
            HitLocation: constant Equipment_Locations :=
              Equipment_Locations'Val
                (Get_Random
                   (Equipment_Locations'Pos(HELMET),
                    Equipment_Locations'Pos(LEGS)));
            LocationNames: constant array
              (HELMET .. LEGS) of Unbounded_String :=
              (To_Unbounded_String("head"), To_Unbounded_String("torso"),
               To_Unbounded_String("arm"), To_Unbounded_String("leg"));
            AttackSkill, BaseDamage: Natural;
            Wounds: Damage_Factor := 0.0;
            MessageColor: Message_Color;
            Attacker: Member_Data :=
              (if PlayerAttack2 then Player_Ship.Crew(AttackerIndex)
               else Enemy.Ship.Crew(AttackerIndex));
            Defender: Member_Data :=
              (if PlayerAttack2 then Enemy.Ship.Crew(DefenderIndex)
               else Player_Ship.Crew(DefenderIndex));
            AttackMessage: Unbounded_String :=
              (if PlayerAttack2 then
                 Attacker.Name & To_Unbounded_String(" attacks ") &
                 Defender.Name & To_Unbounded_String(" (") & FactionName &
                 To_Unbounded_String(")")
               else Attacker.Name & To_Unbounded_String(" (") & FactionName &
                 To_Unbounded_String(")") & To_Unbounded_String(" attacks ") &
                 Defender.Name);
         begin
            BaseDamage := Attacker.Attributes(Positive(Strength_Index)).Level;
            if Attacker.Equipment(WEAPON) > 0 then
               BaseDamage :=
                 BaseDamage +
                 Items_List
                   (Attacker.Inventory(Attacker.Equipment(WEAPON)).Proto_Index)
                   .Value
                   (2);
            end if;
         -- Count damage based on attacker wounds, fatigue, hunger and thirst
            Wounds := 1.0 - Damage_Factor(Float(Attacker.Health) / 100.0);
            Damage :=
              (BaseDamage - Integer(Float(BaseDamage) * Float(Wounds)));
            if Attacker.Thirst > 40 then
               Wounds := 1.0 - Damage_Factor(Float(Attacker.Thirst) / 100.0);
               Damage := Damage - (Integer(Float(BaseDamage) * Float(Wounds)));
            end if;
            if Attacker.Hunger > 80 then
               Wounds := 1.0 - Damage_Factor(Float(Attacker.Hunger) / 100.0);
               Damage := Damage - (Integer(Float(BaseDamage) * Float(Wounds)));
            end if;
            Damage :=
              (if PlayerAttack2 then
                 Integer
                   (Float(Damage) *
                    Float(New_Game_Settings.Player_Melee_Damage_Bonus))
               else Integer
                   (Float(Damage) *
                    Float(New_Game_Settings.Enemy_Melee_Damage_Bonus)));
            if Attacker.Equipment(WEAPON) > 0 then
               AttackSkill :=
                 Get_Skill_Level
                   (Attacker,
                    Skills_Amount_Range(Items_List
                      (Attacker.Inventory(Attacker.Equipment(WEAPON))
                         .Proto_Index)
                      .Value.Element
                      (3)));
               HitChance := AttackSkill + Get_Random(1, 50);
            else
               HitChance :=
                 Get_Skill_Level(Attacker, Unarmed_Skill) + Get_Random(1, 50);
            end if;
            HitChance :=
              HitChance -
              (Get_Skill_Level(Defender, Dodge_Skill) + Get_Random(1, 50));
            Count_Hit_Chance_Loop :
            for I in HELMET .. LEGS loop
               if Defender.Equipment(I) > 0
                 and then
                   Items_List
                     (Defender.Inventory(Defender.Equipment(I)).Proto_Index)
                     .Value
                     .Length >
                   2 then
                  HitChance :=
                    HitChance +
                    Items_List
                      (Defender.Inventory(Defender.Equipment(I)).Proto_Index)
                      .Value
                      (3);
               end if;
            end loop Count_Hit_Chance_Loop;
            if Defender.Equipment(HitLocation) > 0 then
               Damage :=
                 Damage -
                 Items_List
                   (Defender.Inventory(Defender.Equipment(HitLocation))
                      .Proto_Index)
                   .Value
                   (2);
            end if;
            if Defender.Equipment(SHIELD) > 0 then
               Damage :=
                 Damage -
                 Items_List
                   (Defender.Inventory(Defender.Equipment(SHIELD)).Proto_Index)
                   .Value
                   (2);
            end if;
            if Attacker.Equipment(WEAPON) = 0 then
               declare
                  DamageBonus: Natural :=
                    Get_Skill_Level(Attacker, Unarmed_Skill) / 200;
               begin
                  if DamageBonus = 0 then
                     DamageBonus := 1;
                  end if;
                  Damage := Damage + DamageBonus;
               end;
            end if;
            if Factions_List(Defender.Faction).Flags.Contains
                (To_Unbounded_String("naturalarmor")) then
               Damage := Damage / 2;
            end if;
            if
              (Factions_List(Attacker.Faction).Flags.Contains
                 (To_Unbounded_String("toxicattack")) and
               Attacker.Equipment(WEAPON) = 0) and
              not Factions_List(Defender.Faction).Flags.Contains
                (To_Unbounded_String("diseaseimmune")) then
               Damage :=
                 (if Damage * 10 < 30 then Damage * 10 else Damage + 30);
            end if;
            if Damage < 1 then
               Damage := 1;
            end if;
            -- Count damage based on damage type of weapon
            if Attacker.Equipment(WEAPON) > 0 then
               if Items_List
                   (Attacker.Inventory(Attacker.Equipment(WEAPON)).Proto_Index)
                   .Value
                   (5) =
                 1 then -- cutting weapon
                  Damage := Integer(Float(Damage) * 1.5);
               elsif Items_List
                   (Attacker.Inventory(Attacker.Equipment(WEAPON)).Proto_Index)
                   .Value
                   (5) =
                 2 then -- impale weapon
                  Damage := Damage * 2;
               end if;
            end if;
            if HitChance < 1 then
               AttackMessage :=
                 AttackMessage & To_Unbounded_String(" and misses.");
               MessageColor := (if PlayerAttack then BLUE else CYAN);
               if not PlayerAttack then
                  Gain_Exp(2, Natural(Dodge_Skill), DefenderIndex);
                  Defender.Skills := Player_Ship.Crew(DefenderIndex).Skills;
                  Defender.Attributes :=
                    Player_Ship.Crew(DefenderIndex).Attributes;
               end if;
            else
               AttackMessage :=
                 AttackMessage & To_Unbounded_String(" and hit ") &
                 LocationNames(HitLocation) & To_Unbounded_String(".");
               MessageColor := (if PlayerAttack2 then GREEN else YELLOW);
               if Attacker.Equipment(WEAPON) > 0 then
                  if PlayerAttack then
                     Damage_Item
                       (Attacker.Inventory, Attacker.Equipment(WEAPON),
                        AttackSkill, AttackerIndex, Ship => Player_Ship);
                  else
                     Damage_Item
                       (Attacker.Inventory, Attacker.Equipment(WEAPON),
                        AttackSkill, AttackerIndex, Ship => Enemy.Ship);
                  end if;
               end if;
               if Defender.Equipment(HitLocation) > 0 then
                  if PlayerAttack then
                     Damage_Item
                       (Defender.Inventory, Defender.Equipment(HitLocation), 0,
                        DefenderIndex, Ship => Enemy.Ship);
                  else
                     Damage_Item
                       (Defender.Inventory, Defender.Equipment(HitLocation), 0,
                        DefenderIndex, Ship => Player_Ship);
                  end if;
               end if;
               if PlayerAttack2 then
                  if Attacker.Equipment(WEAPON) > 0 then
                     Gain_Exp
                       (2,
                        Items_List
                          (Attacker.Inventory(Attacker.Equipment(WEAPON))
                             .Proto_Index)
                          .Value
                          (3),
                        AttackerIndex);
                  else
                     Gain_Exp(2, Natural(Unarmed_Skill), AttackerIndex);
                  end if;
                  Attacker.Skills := Player_Ship.Crew(AttackerIndex).Skills;
                  Attacker.Attributes :=
                    Player_Ship.Crew(AttackerIndex).Attributes;
               end if;
               Defender.Health :=
                 (if Damage > Defender.Health then 0
                  else Defender.Health - Damage);
            end if;
            Add_Message(To_String(AttackMessage), COMBATMESSAGE, MessageColor);
            Attacker.Tired :=
              (if Attacker.Tired + 1 > Skill_Range'Last then Skill_Range'Last
               else Attacker.Tired + 1);
            Defender.Tired :=
              (if Defender.Tired + 1 > Skill_Range'Last then Skill_Range'Last
               else Defender.Tired + 1);
            if PlayerAttack2 then
               Player_Ship.Crew(AttackerIndex) := Attacker;
               Enemy.Ship.Crew(DefenderIndex) := Defender;
            else
               Player_Ship.Crew(DefenderIndex) := Defender;
               Enemy.Ship.Crew(AttackerIndex) := Attacker;
            end if;
            if Defender.Health = 0 then
               if PlayerAttack2 then
                  Death
                    (DefenderIndex,
                     Attacker.Name &
                     To_Unbounded_String(" blow in melee combat"),
                     Enemy.Ship);
                  Change_Boarding_Order_Loop :
                  for Order of BoardingOrders loop
                     if Order >= DefenderIndex then
                        Order := Order - 1;
                     end if;
                  end loop Change_Boarding_Order_Loop;
                  Update_Killed_Mobs(Defender, FactionName);
                  Update_Goal(KILL, FactionName);
                  if Enemy.Ship.Crew.Length = 0 then
                     EndCombat := True;
                  end if;
               else
                  OrderIndex := 0;
                  Change_Order_Loop :
                  for I in Player_Ship.Crew.Iterate loop
                     if Player_Ship.Crew(I).Order = BOARDING then
                        OrderIndex := OrderIndex + 1;
                     end if;
                     if Crew_Container.To_Index(I) = DefenderIndex then
                        BoardingOrders.Delete(Index => OrderIndex);
                        OrderIndex := OrderIndex - 1;
                        exit Change_Order_Loop;
                     end if;
                  end loop Change_Order_Loop;
                  Death
                    (DefenderIndex,
                     Attacker.Name &
                     To_Unbounded_String(" blow in melee combat"),
                     Player_Ship);
                  if DefenderIndex = 1 then -- Player is dead
                     EndCombat := True;
                  end if;
               end if;
               return False;
            else
               return True;
            end if;
         end CharacterAttack;
      begin
         AttackerIndex := Attackers.First_Index;
         OrderIndex := 1;
         Attackers_Attacks_Loop :
         while AttackerIndex <=
           Attackers.Last_Index loop -- Boarding party attacks first
            Riposte := True;
            if Attackers(AttackerIndex).Order /= BOARDING then
               goto End_Of_Attacker_Loop;
            end if;
            AttackDone := False;
            if PlayerAttack then
               exit Attackers_Attacks_Loop when OrderIndex >
                 BoardingOrders.Last_Index;
               if BoardingOrders(OrderIndex) in
                   Defenders.First_Index .. Defenders.Last_Index then
                  DefenderIndex := BoardingOrders(OrderIndex);
                  Riposte :=
                    CharacterAttack
                      (AttackerIndex, DefenderIndex, PlayerAttack);
                  if not EndCombat and Riposte then
                     if Enemy.Ship.Crew(DefenderIndex).Order /= DEFEND then
                        Give_Orders
                          (Enemy.Ship, DefenderIndex, DEFEND, 0, False);
                     end if;
                     Riposte :=
                       CharacterAttack
                         (DefenderIndex, AttackerIndex, not PlayerAttack);
                  else
                     Riposte := True;
                  end if;
                  AttackDone := True;
               elsif BoardingOrders(OrderIndex) = -1 then
                  Give_Orders(Player_Ship, AttackerIndex, REST);
                  BoardingOrders.Delete(Index => OrderIndex);
                  OrderIndex := OrderIndex - 1;
                  AttackDone := True;
               end if;
               OrderIndex := OrderIndex + 1;
            end if;
            if not AttackDone then
               Defenders_Riposte_Loop :
               for Defender in
                 Defenders.First_Index .. Defenders.Last_Index loop
                  if Defenders(Defender).Order = DEFEND then
                     Riposte :=
                       CharacterAttack(AttackerIndex, Defender, PlayerAttack);
                     if not EndCombat and Riposte then
                        Riposte :=
                          CharacterAttack
                            (Defender, AttackerIndex, not PlayerAttack);
                     else
                        Riposte := True;
                     end if;
                     AttackDone := True;
                     exit Defenders_Riposte_Loop;
                  end if;
               end loop Defenders_Riposte_Loop;
            end if;
            if not AttackDone then
               DefenderIndex :=
                 Get_Random(Defenders.First_Index, Defenders.Last_Index);
               if PlayerAttack then
                  Give_Orders(Enemy.Ship, DefenderIndex, DEFEND, 0, False);
               else
                  Give_Orders(Player_Ship, DefenderIndex, DEFEND, 0, False);
               end if;
               Riposte :=
                 CharacterAttack
                   (AttackerIndex => AttackerIndex,
                    DefenderIndex => DefenderIndex,
                    PlayerAttack2 => PlayerAttack);
               if not EndCombat and Riposte then
                  Riposte :=
                    CharacterAttack
                      (AttackerIndex => DefenderIndex,
                       DefenderIndex => AttackerIndex,
                       PlayerAttack2 => not PlayerAttack);
               else
                  Riposte := True;
               end if;
            end if;
            <<End_Of_Attacker_Loop>>
            exit Attackers_Attacks_Loop when EndCombat;
            if Riposte then
               AttackerIndex := AttackerIndex + 1;
            end if;
         end loop Attackers_Attacks_Loop;
         DefenderIndex := Defenders.First_Index;
         Defenders_Attacks_Loop :
         while DefenderIndex <= Defenders.Last_Index loop -- Defenders attacks
            Riposte := True;
            if Defenders(DefenderIndex).Order = DEFEND then
               Attackers_Riposte_Loop :
               for Attacker in
                 Attackers.First_Index .. Attackers.Last_Index loop
                  if Attackers(Attacker).Order = BOARDING then
                     Riposte :=
                       CharacterAttack
                         (DefenderIndex, Attacker, not PlayerAttack);
                     if not EndCombat and Riposte then
                        Riposte :=
                          CharacterAttack
                            (Attacker, DefenderIndex, PlayerAttack);
                     end if;
                     exit Attackers_Riposte_Loop;
                  end if;
               end loop Attackers_Riposte_Loop;
            end if;
            if Riposte then
               DefenderIndex := DefenderIndex + 1;
            end if;
         end loop Defenders_Attacks_Loop;
         if Find_Member(BOARDING) = 0 then
            Update_Orders(Enemy.Ship);
         end if;
      end MeleeCombat;
   begin
      if Find_Item(Inventory => Player_Ship.Cargo, Item_Type => Fuel_Type) =
        0 then
         Add_Message
           ("Ship fall from sky due to lack of fuel.", OTHERMESSAGE, RED);
         Death(1, To_Unbounded_String("fall of the ship"), Player_Ship);
         EndCombat := True;
         return;
      end if;
      declare
         ChanceForRun: Integer;
      begin
         TurnNumber := TurnNumber + 1;
         case Enemy.CombatAI is
            when ATTACKER =>
               ChanceForRun := TurnNumber - 120;
            when BERSERKER =>
               ChanceForRun := TurnNumber - 200;
            when DISARMER =>
               ChanceForRun := TurnNumber - 60;
            when others =>
               null;
         end case;
         if ChanceForRun > 1 and then Get_Random(1, 100) < ChanceForRun then
            Enemy.CombatAI := COWARD;
         end if;
      end;
      Pilot_Engineer_Experience_Loop :
      for I in Player_Ship.Crew.Iterate loop
         case Player_Ship.Crew(I).Order is
            when PILOT =>
               PilotIndex := Crew_Container.To_Index(I);
               Gain_Exp(2, Natural(Piloting_Skill), PilotIndex);
            when ENGINEER =>
               EngineerIndex := Crew_Container.To_Index(I);
               Gain_Exp(2, Natural(Engineering_Skill), EngineerIndex);
            when others =>
               null;
         end case;
      end loop Pilot_Engineer_Experience_Loop;
      if PilotIndex > 0 then
         case PilotOrder is
            when 1 =>
               AccuracyBonus := 20;
               EvadeBonus := -10;
            when 2 =>
               AccuracyBonus := 10;
               EvadeBonus := 0;
            when 3 =>
               AccuracyBonus := 0;
               EvadeBonus := 10;
            when 4 =>
               AccuracyBonus := -10;
               EvadeBonus := 20;
            when others =>
               null;
         end case;
         EvadeBonus :=
           EvadeBonus +
           Get_Skill_Level(Player_Ship.Crew(PilotIndex), Piloting_Skill);
      else
         AccuracyBonus := 20;
         EvadeBonus := -10;
      end if;
      EnemyPilotIndex := Find_Member(PILOT, Enemy.Ship.Crew);
      if EnemyPilotIndex > 0 then
         AccuracyBonus :=
           AccuracyBonus -
           Get_Skill_Level(Enemy.Ship.Crew(EnemyPilotIndex), Piloting_Skill);
      end if;
      if EngineerIndex > 0 or
        Factions_List(Player_Ship.Crew(1).Faction).Flags.Contains
          (To_Unbounded_String("sentientships")) then
         Message :=
           To_Unbounded_String(ChangeShipSpeed(Ship_Speed'Val(EngineerOrder)));
         if Length(Message) > 0 then
            Add_Message(To_String(Message), ORDERMESSAGE, RED);
         end if;
      end if;
      SpeedBonus := 20 - (RealSpeed(Player_Ship) / 100);
      if SpeedBonus < -10 then
         SpeedBonus := -10;
      end if;
      AccuracyBonus := AccuracyBonus + SpeedBonus;
      EvadeBonus := EvadeBonus - SpeedBonus;
      Enemy_Weapon_Loop :
      for I in Enemy.Ship.Modules.Iterate loop
         if Enemy.Ship.Modules(I).Durability = 0 or
           (Enemy.Ship.Modules(I).M_Type not in GUN | BATTERING_RAM |
                HARPOON_GUN) then
            goto End_Of_Enemy_Weapon_Loop;
         end if;
         if Enemy.Ship.Modules(I).M_Type in GUN | HARPOON_GUN then
            if Enemy.Ship.Modules(I).M_Type = GUN and DamageRange > 5_000 then
               DamageRange := 5_000;
            elsif DamageRange > 2_000 then
               DamageRange := 2_000;
            end if;
            AmmoIndex2 :=
              (if Enemy.Ship.Modules(I).M_Type = GUN then
                 Enemy.Ship.Modules(I).Ammo_Index
               else Enemy.Ship.Modules(I).Harpoon_Index);
            if AmmoIndex2 in
                Enemy.Ship.Cargo.First_Index ..
                      Enemy.Ship.Cargo.Last_Index then
               if Items_List(Enemy.Ship.Cargo(AmmoIndex2).Proto_Index).I_Type =
                 Items_Types
                   (Modules_List(Enemy.Ship.Modules(I).Proto_Index).Value) then
                  EnemyAmmoIndex := AmmoIndex2;
               end if;
            end if;
            if EnemyAmmoIndex = 0 then
               Enemy_Ammo_Index_Loop :
               for K in Items_List.Iterate loop
                  if Items_List(K).I_Type =
                    Items_Types
                      (Modules_List(Enemy.Ship.Modules(I).Proto_Index)
                         .Value) then
                     Find_Enemy_Ammo_Index_Loop :
                     for J in Enemy.Ship.Cargo.Iterate loop
                        if Enemy.Ship.Cargo(J).Proto_Index =
                          Objects_Container.Key(K) then
                           EnemyAmmoIndex := Inventory_Container.To_Index(J);
                           exit Find_Enemy_Ammo_Index_Loop;
                        end if;
                     end loop Find_Enemy_Ammo_Index_Loop;
                     exit Enemy_Ammo_Index_Loop when EnemyAmmoIndex > 0;
                  end if;
               end loop Enemy_Ammo_Index_Loop;
            end if;
            if EnemyAmmoIndex = 0 and
              (Enemy.CombatAI in ATTACKER | DISARMER) then
               Enemy.CombatAI := COWARD;
               exit Enemy_Weapon_Loop;
            end if;
         elsif DamageRange > 100 then
            DamageRange := 100;
         end if;
         EnemyWeaponIndex := Modules_Container.To_Index(I);
         <<End_Of_Enemy_Weapon_Loop>>
      end loop Enemy_Weapon_Loop;
      if EnemyWeaponIndex = 0 and (Enemy.CombatAI in ATTACKER | DISARMER) then
         Enemy.CombatAI := COWARD;
      end if;
      case Enemy.CombatAI is
         when BERSERKER =>
            if Enemy.Distance > 10 and Enemy.Ship.Speed /= FULL_SPEED then
               Enemy.Ship.Speed :=
                 Ship_Speed'Val(Ship_Speed'Pos(Enemy.Ship.Speed) + 1);
               Add_Message
                 (To_String(EnemyName) & " increases speed.", COMBATMESSAGE);
               EnemyPilotOrder := 1;
            elsif Enemy.Distance <= 10 and Enemy.Ship.Speed = FULL_SPEED then
               Enemy.Ship.Speed :=
                 Ship_Speed'Val(Ship_Speed'Pos(Enemy.Ship.Speed) - 1);
               Add_Message
                 (To_String(EnemyName) & " decreases speed.", COMBATMESSAGE);
               EnemyPilotOrder := 2;
            end if;
         when ATTACKER | DISARMER =>
            if Enemy.Distance > DamageRange and
              Enemy.Ship.Speed /= FULL_SPEED then
               Enemy.Ship.Speed :=
                 Ship_Speed'Val(Ship_Speed'Pos(Enemy.Ship.Speed) + 1);
               Add_Message
                 (To_String(EnemyName) & " increases speed.", COMBATMESSAGE);
               EnemyPilotOrder := 1;
            elsif Enemy.Distance < DamageRange and
              Enemy.Ship.Speed > QUARTER_SPEED then
               Enemy.Ship.Speed :=
                 Ship_Speed'Val(Ship_Speed'Pos(Enemy.Ship.Speed) - 1);
               Add_Message
                 (To_String(EnemyName) & " decreases speed.", COMBATMESSAGE);
               EnemyPilotOrder := 2;
            end if;
         when COWARD =>
            if Enemy.Distance < 15_000 and Enemy.Ship.Speed /= FULL_SPEED then
               Enemy.Ship.Speed :=
                 Ship_Speed'Val(Ship_Speed'Pos(Enemy.Ship.Speed) + 1);
               Add_Message
                 (To_String(EnemyName) & " increases speed.", COMBATMESSAGE);
            end if;
            EnemyPilotOrder := 4;
         when others =>
            null;
      end case;
      if Enemy.HarpoonDuration > 0 then
         Enemy.Ship.Speed := FULL_STOP;
         Add_Message
           (To_String(EnemyName) & " is stopped by your ship.", COMBATMESSAGE);
      elsif Enemy.Ship.Speed = FULL_STOP then
         Enemy.Ship.Speed := QUARTER_SPEED;
      end if;
      if HarpoonDuration > 0 then
         Player_Ship.Speed := FULL_STOP;
         Add_Message("You are stopped by enemy ship.", COMBATMESSAGE);
      end if;
      case EnemyPilotOrder is
         when 1 =>
            AccuracyBonus := AccuracyBonus + 20;
            EvadeBonus := EvadeBonus - 20;
         when 2 =>
            AccuracyBonus := AccuracyBonus + 10;
            EvadeBonus := EvadeBonus - 10;
         when 3 =>
            AccuracyBonus := AccuracyBonus - 10;
            EvadeBonus := EvadeBonus + 10;
         when 4 =>
            AccuracyBonus := AccuracyBonus - 20;
            EvadeBonus := EvadeBonus + 20;
         when others =>
            null;
      end case;
      SpeedBonus := 20 - (RealSpeed(Enemy.Ship) / 100);
      if SpeedBonus < -10 then
         SpeedBonus := -10;
      end if;
      AccuracyBonus := AccuracyBonus + SpeedBonus;
      EvadeBonus := EvadeBonus - SpeedBonus;
      DistanceTraveled :=
        (if EnemyPilotOrder < 4 then -(RealSpeed(Enemy.Ship))
         else RealSpeed(Enemy.Ship));
      if PilotIndex > 0 then
         case PilotOrder is
            when 1 | 3 =>
               DistanceTraveled := DistanceTraveled - RealSpeed(Player_Ship);
            when 2 =>
               DistanceTraveled := DistanceTraveled + RealSpeed(Player_Ship);
               if DistanceTraveled > 0 and EnemyPilotOrder /= 4 then
                  DistanceTraveled := 0;
               end if;
            when 4 =>
               DistanceTraveled := DistanceTraveled + RealSpeed(Player_Ship);
            when others =>
               null;
         end case;
      else
         DistanceTraveled := DistanceTraveled - RealSpeed(Player_Ship);
      end if;
      Enemy.Distance := Enemy.Distance + DistanceTraveled;
      if Enemy.Distance < 10 then
         Enemy.Distance := 10;
      end if;
      if Enemy.Distance >= 15_000 then
         if PilotOrder = 4 then
            Add_Message
              ("You escaped the " & To_String(EnemyName) & ".", COMBATMESSAGE);
         else
            Add_Message
              (To_String(EnemyName) & " escaped from you.", COMBATMESSAGE);
         end if;
         Kill_Boarding_Party_Loop :
         for I in Player_Ship.Crew.Iterate loop
            if Player_Ship.Crew(I).Order = BOARDING then
               Death
                 (Crew_Container.To_Index(I),
                  To_Unbounded_String("enemy crew"), Player_Ship, False);
            end if;
         end loop Kill_Boarding_Party_Loop;
         EndCombat := True;
         return;
      elsif Enemy.Distance < 15_000 and Enemy.Distance >= 10_000 then
         AccuracyBonus := AccuracyBonus - 10;
         EvadeBonus := EvadeBonus + 10;
         Log_Message("Distance: long", Log.COMBAT);
      elsif Enemy.Distance < 5_000 and Enemy.Distance >= 1_000 then
         AccuracyBonus := AccuracyBonus + 10;
         Log_Message("Distance: medium", Log.COMBAT);
      elsif Enemy.Distance < 1_000 then
         AccuracyBonus := AccuracyBonus + 20;
         EvadeBonus := EvadeBonus - 10;
         Log_Message("Distance: short or close", Log.COMBAT);
      end if;
      Attack(Player_Ship, Enemy.Ship); -- Player attack
      if not EndCombat then
         Attack(Enemy.Ship, Player_Ship); -- Enemy attack
      end if;
      if not EndCombat then
         declare
            HaveBoardingParty: Boolean := False;
         begin
            Check_For_Boarding_Party_Loop :
            for Member of Player_Ship.Crew loop
               if Member.Order = BOARDING then
                  HaveBoardingParty := True;
                  exit Check_For_Boarding_Party_Loop;
               end if;
            end loop Check_For_Boarding_Party_Loop;
            Check_For_Enemy_Boarding_Party :
            for Member of Enemy.Ship.Crew loop
               if Member.Order = BOARDING then
                  HaveBoardingParty := True;
                  exit Check_For_Enemy_Boarding_Party;
               end if;
            end loop Check_For_Enemy_Boarding_Party;
            if Enemy.HarpoonDuration > 0 or HarpoonDuration > 0 or
              HaveBoardingParty then
               if not EndCombat and
                 Enemy.Ship.Crew.Length >
                   0 then -- Characters combat (player boarding party)
                  MeleeCombat(Player_Ship.Crew, Enemy.Ship.Crew, True);
               end if;
               if not EndCombat and
                 Enemy.Ship.Crew.Length >
                   0 then -- Characters combat (enemy boarding party)
                  MeleeCombat(Enemy.Ship.Crew, Player_Ship.Crew, False);
               end if;
            end if;
         end;
      end if;
      if not EndCombat then
         if Enemy.HarpoonDuration > 0 then
            Enemy.HarpoonDuration := Enemy.HarpoonDuration - 1;
         end if;
         if HarpoonDuration > 0 then
            HarpoonDuration := HarpoonDuration - 1;
         end if;
         if Enemy.HarpoonDuration > 0 or
           HarpoonDuration >
             0 then -- Set defenders/boarding party on player ship
            Update_Orders(Player_Ship, True);
         end if;
         Update_Game(1, True);
      elsif Player_Ship.Crew(1).Health > 0 then
         declare
            WasBoarded: Boolean := False;
            LootAmount: Integer;
         begin
            if Find_Member(BOARDING) > 0 then
               WasBoarded := True;
            end if;
            Enemy.Ship.Modules(1).Durability := 0;
            Add_Message
              (To_String(EnemyName) & " is destroyed!", COMBATMESSAGE);
            LootAmount := Enemy.Loot;
            FreeSpace := FreeCargo((0 - LootAmount));
            if FreeSpace < 0 then
               LootAmount := LootAmount + FreeSpace;
            end if;
            if LootAmount > 0 then
               Add_Message
                 ("You looted" & Integer'Image(LootAmount) & " " &
                  To_String(Money_Name) & " from " & To_String(EnemyName) &
                  ".",
                  COMBATMESSAGE);
               UpdateCargo(Player_Ship, Money_Index, LootAmount);
            end if;
            FreeSpace := FreeCargo(0);
            if WasBoarded and FreeSpace > 0 then
               Message :=
                 To_Unbounded_String
                   ("Additionally, your boarding party takes from ") &
                 EnemyName & To_Unbounded_String(":");
               Looting_Loop :
               for Item of Enemy.Ship.Cargo loop
                  LootAmount := Item.Amount / 5;
                  FreeSpace := FreeCargo((0 - LootAmount));
                  if FreeSpace < 0 then
                     LootAmount := LootAmount + FreeSpace;
                  end if;
                  if Items_List(Item.Proto_Index).Price = 0 and
                    Item.Proto_Index /= Money_Index then
                     LootAmount := 0;
                  end if;
                  if LootAmount > 0 then
                     if Item /= Enemy.Ship.Cargo.First_Element then
                        Message := Message & To_Unbounded_String(",");
                     end if;
                     UpdateCargo(Player_Ship, Item.Proto_Index, LootAmount);
                     Message :=
                       Message & Positive'Image(LootAmount) &
                       To_Unbounded_String(" ") &
                       Items_List(Item.Proto_Index).Name;
                     FreeSpace := FreeCargo(0);
                     exit Looting_Loop when Item =
                       Enemy.Ship.Cargo.Last_Element or
                       FreeSpace = 0;
                  end if;
               end loop Looting_Loop;
               Add_Message(To_String(Message) & ".", COMBATMESSAGE);
               if Current_Story.Index /= Null_Unbounded_String then
                  declare
                     Step: constant Step_Data :=
                       (if Current_Story.Current_Step = 0 then
                          Stories_List(Current_Story.Index).Starting_Step
                        elsif Current_Story.Current_Step > 0 then
                          Stories_List(Current_Story.Index).Steps
                            (Current_Story.Current_Step)
                        else Stories_List(Current_Story.Index).Final_Step);
                     Tokens: Slice_Set;
                  begin
                     if Step.Finish_Condition = LOOT then
                        Create(Tokens, To_String(Current_Story.Data), ";");
                        if Slice(Tokens, 2) = "any" or
                          Slice(Tokens, 2) = To_String(EnemyShipIndex) then
                           if Progress_Story then
                              case Step.Finish_Condition is
                                 when LOOT =>
                                    UpdateCargo
                                      (Player_Ship,
                                       To_Bounded_String(Slice(Tokens, 1)), 1);
                                 when others =>
                                    null;
                              end case;
                           end if;
                        end if;
                     end if;
                  end;
               else
                  Start_Story(FactionName, DROPITEM);
               end if;
            end if;
            Give_Orders_Loop :
            for I in Player_Ship.Crew.Iterate loop
               if Player_Ship.Crew(I).Order = BOARDING then
                  Give_Orders(Player_Ship, Crew_Container.To_Index(I), REST);
               elsif Player_Ship.Crew(I).Order = DEFEND then
                  Give_Orders(Player_Ship, Crew_Container.To_Index(I), REST);
               end if;
            end loop Give_Orders_Loop;
         end;
         Enemy.Ship.Speed := FULL_STOP;
         Player_Ship.Speed := OldSpeed;
         if Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Event_Index > 0 then
            if Events_List
                (Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Event_Index)
                .E_Type =
              ATTACKONBASE then
               Gain_Rep
                 (Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Base_Index, 5);
            end if;
            Delete_Event
              (Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Event_Index);
         end if;
         if Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Mission_Index > 0
           and then
             Accepted_Missions
               (Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Mission_Index)
               .M_Type =
             DESTROY
           and then
             Proto_Ships_List
               (Accepted_Missions
                  (Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Mission_Index)
                  .Ship_Index)
               .Name =
             Enemy.Ship.Name then
            Update_Mission
              (Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Mission_Index);
         end if;
         declare
            LostReputationChance: Positive range 10 .. 40 := 10;
         begin
            if Proto_Ships_List(EnemyShipIndex).Owner =
              Player_Ship.Crew(1).Faction then
               LostReputationChance := 40;
            end if;
            if Get_Random(1, 100) < LostReputationChance then
               Gain_Rep(Enemy.Ship.Home_Base, -100);
            end if;
         end;
         Update_Destroyed_Ships(Enemy.Ship.Name);
         Update_Goal(DESTROY, EnemyShipIndex);
         if Current_Goal.Target_Index /= Null_Unbounded_String then
            Update_Goal(DESTROY, Proto_Ships_List(EnemyShipIndex).Owner);
         end if;
         if Current_Story.Index /= Null_Unbounded_String then
            declare
               FinishCondition: constant Step_Condition_Type :=
                 (if Current_Story.Current_Step = 0 then
                    Stories_List(Current_Story.Index).Starting_Step
                      .Finish_Condition
                  elsif Current_Story.Current_Step > 0 then
                    Stories_List(Current_Story.Index).Steps
                      (Current_Story.Current_Step)
                      .Finish_Condition
                  else Stories_List(Current_Story.Index).Final_Step
                      .Finish_Condition);
               Tokens: Slice_Set;
            begin
               if FinishCondition /= DESTROYSHIP then
                  return;
               end if;
               Create(Tokens, To_String(Current_Story.Data), ";");
               if Player_Ship.Sky_X = Positive'Value(Slice(Tokens, 1)) and
                 Player_Ship.Sky_Y = Positive'Value(Slice(Tokens, 2)) and
                 EnemyShipIndex = To_Unbounded_String(Slice(Tokens, 3)) then
                  if not Progress_Story(True) then
                     return;
                  end if;
               end if;
            end;
         end if;
      end if;
   end CombatTurn;

end Combat;
