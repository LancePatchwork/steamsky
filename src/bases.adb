--    Copyright 2016-2023 Bartek thindil Jasicki
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

with Ada.Numerics.Elementary_Functions;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with Messages; use Messages;
with Ships.Crew; use Ships.Crew;
with Events; use Events;
with Utils; use Utils;
with Config;
with BasesTypes; use BasesTypes;
with Maps; use Maps;
with Mobs;
with Factions; use Factions;

package body Bases is

   procedure Gain_Rep(Base_Index: Bases_Range; Points: Integer) is
      procedure Gain_Ada_Rep(B_Index, Pnts: Integer) with
         Import => True,
         Convention => C,
         External_Name => "gainAdaRep";
   begin
      Get_Base_Reputation(Base_Index => Base_Index);
      Gain_Ada_Rep(B_Index => Base_Index, Pnts => Points);
      Set_Base_Reputation(Base_Index => Base_Index);
   end Gain_Rep;

   procedure Count_Price
     (Price: in out Natural; Trader_Index: Crew_Container.Extended_Index;
      Reduce: Boolean := True) is
      procedure Count_Ada_Price(P: in out Integer; T_Index, R: Integer) with
         Import => True,
         Convention => C,
         External_Name => "countAdaPrice";
   begin
      Get_Ada_Crew;
      if Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Base_Index > 0 then
         Get_Base_Reputation
           (Base_Index =>
              Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Base_Index);
      end if;
      Count_Ada_Price
        (P => Price, T_Index => Trader_Index, R => (if Reduce then 1 else 0));
   end Count_Price;

   function Generate_Base_Name
     (Faction_Index: Tiny_String.Bounded_String)
      return Tiny_String.Bounded_String is
      use Tiny_String;
      function Generate_Ada_Base_Name(F_Index: chars_ptr) return chars_ptr with
         Import => True,
         Convention => C,
         External_Name => "generateAdaBaseName";
   begin
      return
        To_Bounded_String
          (Source =>
             Value
               (Item =>
                  Generate_Ada_Base_Name
                    (F_Index =>
                       New_String
                         (Str => To_String(Source => Faction_Index)))));
   end Generate_Base_Name;

   procedure Generate_Recruits is
      use Config;
      use Tiny_String;

      Base_Index: constant Bases_Range :=
        Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Base_Index;
      Recruit_Base: Bases_Range := 1;
      Base_Recruits: Recruit_Container.Vector (Capacity => 5);
      Gender: Character := 'M';
      Price, Payment: Natural := 0;
      Skill_Index: Integer range -1 .. Integer'Last := -1;
      --## rule off IMPROPER_INITIALIZATION
      Attributes: Mob_Attributes(1 .. Attributes_Amount);
      Equipment: Equipment_Array;
      Inventory: Positive_Formal_Container.Vector (Capacity => 7);
      Skills: Skills_Container.Vector (Capacity => Skills_Amount);
      --## rule on IMPROPER_INITIALIZATION
      Temp_Tools: Positive_Indefinite_Container.Vector (Capacity => 32);
      Max_Skill_Level: Integer range -100 .. 100 := -100;
      Skill_Level, Highest_Level: Skill_Range := 0;
      Recruit_Faction: Bounded_String := Null_Bounded_String;
      Max_Recruits, Recruits_Amount: Recruit_Amount_Range;
      Local_Skills_Amount, Skill_Number, Highest_Skill: Skills_Amount_Range :=
        1;
      Max_Skill_Amount: Integer;
      Faction: Faction_Record; --## rule line off IMPROPER_INITIALIZATION
      procedure Add_Inventory
        (Items_Indexes: String; Equip_Index: Equipment_Locations) is
         Item_Index: Natural;
         use Mobs;

      begin
         if Get_Random(Min => 1, Max => 100) > 80 then
            return;
         end if;
         Item_Index :=
           Get_Random_Item
             (Items_Indexes => Items_Indexes, Equip_Index => Equip_Index,
              Highest_Level => Highest_Level,
              Weapon_Skill_Level =>
                Skills_Container.Element(Container => Skills, Index => 1)
                  .Level,
              Faction_Index => Recruit_Faction,
              Highest_Skill => Positive(Highest_Skill));
         if Item_Index = 0 then
            return;
         end if;
         Positive_Formal_Container.Append
           (Container => Inventory, New_Item => Item_Index);
         Equipment(Equip_Index) :=
           Positive_Formal_Container.Last_Index(Container => Inventory);
         Price :=
           Price +
           Get_Price
             (Base_Type => Sky_Bases(Base_Index).Base_Type,
              Item_Index => Item_Index);
         --## rule off SIMPLIFIABLE_EXPRESSIONS
         Payment :=
           Payment +
           (Get_Price
              (Base_Type => Sky_Bases(Base_Index).Base_Type,
               Item_Index => Item_Index) /
            10);
         --## rule on SIMPLIFIABLE_EXPRESSIONS
      end Add_Inventory;
   begin
      if Days_Difference
          (Date_To_Compare => Sky_Bases(Base_Index).Recruit_Date) <
        30 or
        Sky_Bases(Base_Index).Population = 0 then
         return;
      end if;
      Max_Recruits :=
        (if Sky_Bases(Base_Index).Population < 150 then 5
         elsif Sky_Bases(Base_Index).Population < 300 then 10 else 15);
      if Has_Flag
          (Base_Type => Sky_Bases(Base_Index).Base_Type,
           Flag => "barracks") then
         Max_Recruits := Max_Recruits * 2;
      end if;
      --## rule off SIMPLIFIABLE_EXPRESSIONS
      if Max_Recruits > (Sky_Bases(Base_Index).Population / 10) then
         Max_Recruits := (Sky_Bases(Base_Index).Population / 10) + 1;
      end if;
      --## rule on SIMPLIFIABLE_EXPRESSIONS
      Recruits_Amount := Get_Random(Min => 1, Max => Max_Recruits);
      Max_Skill_Amount :=
        Integer
          (Float(SkillsData_Container.Length(Container => Skills_List)) *
           (Float(Sky_Bases(Base_Index).Reputation.Level) / 100.0));
      if Max_Skill_Amount < 5 then
         Max_Skill_Amount := 5;
      end if;
      Generate_Recruits_Loop :
      for I in 1 .. Recruits_Amount loop
         Skills_Container.Clear(Container => Skills);
         Attributes := (others => <>);
         Price := 0;
         Positive_Formal_Container.Clear(Container => Inventory);
         Positive_Indefinite_Container.Clear(Container => Temp_Tools);
         Equipment := (others => 0);
         Payment := 0;
         Recruit_Faction :=
           (if Get_Random(Min => 1, Max => 100) < 99 then
              Sky_Bases(Base_Index).Owner
            else Get_Random_Faction);
         Faction := Get_Faction(Index => Recruit_Faction);
         if Faction.Flags.Contains
             (Item => To_Unbounded_String(Source => "nogender")) then
            Gender := 'M';
         else
            Gender :=
              (if Get_Random(Min => 1, Max => 2) = 1 then 'M' else 'F');
         end if;
         Local_Skills_Amount :=
           Skills_Amount_Range
             (Get_Random(Min => 1, Max => Natural(Skills_Amount)));
         if Local_Skills_Amount > Skills_Amount_Range(Max_Skill_Amount) then
            Local_Skills_Amount := Skills_Amount_Range(Max_Skill_Amount);
         end if;
         Highest_Level := 1;
         Highest_Skill := 1;
         Max_Skill_Level := Sky_Bases(Base_Index).Reputation.Level;
         if Max_Skill_Level < 20 then
            Max_Skill_Level := 20;
         end if;
         if Get_Random(Min => 1, Max => 100) > 95 then
            Max_Skill_Level := Get_Random(Min => Max_Skill_Level, Max => 100);
         end if;
         Generate_Skills_Loop :
         for J in 1 .. Local_Skills_Amount loop
            Skill_Number :=
              (if J > 1 then
                 Skills_Amount_Range
                   (Get_Random(Min => 1, Max => Natural(Skills_Amount)))
               else Faction.Weapon_Skill);
            Skill_Level := Get_Random(Min => 1, Max => Max_Skill_Level);
            if Skill_Level > Highest_Level then
               Highest_Level := Skill_Level;
               Highest_Skill := Skill_Number;
            end if;
            Skill_Index := 0;
            Get_Skill_Index_Loop :
            for D in
              Skills_Container.First_Index(Container => Skills) ..
                Skills_Container.Last_Index(Container => Skills) loop
               if Skills_Container.Element(Container => Skills, Index => D)
                   .Index =
                 Skill_Number then
                  Skill_Index :=
                    (if
                       Skills_Container.Element
                         (Container => Skills, Index => D)
                         .Level <
                       Skill_Level
                     then Integer(D)
                     else -1);
                  exit Get_Skill_Index_Loop;
               end if;
            end loop Get_Skill_Index_Loop;
            --## rule off SIMPLIFIABLE_STATEMENTS
            if Skill_Index = 0 then
               Skills_Container.Append
                 (Container => Skills,
                  New_Item =>
                    (Index => Skill_Number, Level => Skill_Level,
                     Experience => 0));
            elsif Skill_Index > 0 then
               Skills_Container.Replace_Element
                 (Container => Skills,
                  Index => Skills_Amount_Range(Skill_Index),
                  New_Item =>
                    (Index => Skill_Number, Level => Skill_Level,
                     Experience => 0));
            end if;
            --## rule on SIMPLIFIABLE_STATEMENTS
         end loop Generate_Skills_Loop;
         Generate_Attributes_Loop :
         for Attribute of Attributes loop
            Attribute :=
              (Level => Get_Random(Min => 3, Max => Max_Skill_Level / 3),
               Experience => 0);
         end loop Generate_Attributes_Loop;
         Update_Price_With_Skills_Loop :
         for Skill of Skills loop
            Price := Price + Skill.Level;
            Payment := Payment + Skill.Level;
         end loop Update_Price_With_Skills_Loop;
         Update_Price_With_Stats_Loop :
         for Stat of Attributes loop
            --## rule off SIMPLIFIABLE_EXPRESSIONS
            Price := Price + (Stat.Level * 2);
            Payment := Payment + (Stat.Level * 2);
            --## rule on SIMPLIFIABLE_EXPRESSIONS
         end loop Update_Price_With_Stats_Loop;
         Add_Inventory(Items_Indexes => "weapon", Equip_Index => WEAPON);
         Add_Inventory(Items_Indexes => "shield", Equip_Index => SHIELD);
         Add_Inventory(Items_Indexes => "helmet", Equip_Index => HELMET);
         Add_Inventory(Items_Indexes => "torso", Equip_Index => TORSO);
         Add_Inventory(Items_Indexes => "arms", Equip_Index => ARMS);
         Add_Inventory(Items_Indexes => "legs", Equip_Index => LEGS);
         Add_Inventory(Items_Indexes => "tool", Equip_Index => TOOL);
         if Has_Flag
             (Base_Type => Sky_Bases(Base_Index).Base_Type,
              Flag => "barracks") then
            Price := Price / 2;
            Payment := Payment / 2;
         end if;
         Price := Natural(Float(Price * 100) * New_Game_Settings.Prices_Bonus);
         if Price = 0 then
            Price := 1;
         end if;
         Recruit_Base :=
           (if Get_Random(Min => 1, Max => 100) < 99 then Base_Index
            else Get_Random(Min => Sky_Bases'First, Max => Sky_Bases'Last));
         Recruit_Container.Append
           (Container => Base_Recruits,
            New_Item =>
              (Amount_Of_Attributes => Attributes_Amount,
               Amount_Of_Skills => Skills_Amount,
               Name =>
                 Tiny_String.To_Bounded_String
                   (Source =>
                      To_String
                        (Source =>
                           Generate_Member_Name
                             (Gender => Gender,
                              Faction_Index => Recruit_Faction))),
               Gender => Gender, Price => Price, Skills => Skills,
               Attributes => Attributes, Inventory => Inventory,
               Equipment => Equipment, Payment => Payment,
               Home_Base => Recruit_Base, Faction => Recruit_Faction));
      end loop Generate_Recruits_Loop;
      Sky_Bases(Base_Index).Recruit_Date := Game_Date;
      Recruit_Container.Assign
        (Target => Sky_Bases(Base_Index).Recruits, Source => Base_Recruits);
   end Generate_Recruits;

   procedure Ask_For_Bases is
      use Tiny_String;

      Base_Index: constant Natural :=
        Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Base_Index;
      Tmp_Base_Index: Extended_Base_Range := 0;
      Ship_Index: Natural := 0;
      Unknown_Bases: Extended_Base_Range := 0;
      Trader_Index: constant Natural := Find_Member(Order => TALK);
      Amount: Natural range 0 .. 40;
      Radius: Integer range -40 .. 40;
      Temp_X, Temp_Y: Integer range -40 .. Bases_Range'Last + 40 := 0;
   begin
      if Trader_Index = 0 then
         return;
      end if;
      if Base_Index > 0 then -- asking in base
         if Sky_Bases(Base_Index).Population < 150 then
            Amount := 10;
            Radius := 10;
         elsif Sky_Bases(Base_Index).Population < 300 then
            Amount := 20;
            Radius := 20;
         else
            Amount := 40;
            Radius := 40;
         end if;
         Gain_Rep(Base_Index => Base_Index, Points => 1);
         Sky_Bases(Base_Index).Asked_For_Bases := True;
         Add_Message
           (Message =>
              To_String(Source => Player_Ship.Crew(Trader_Index).Name) &
              " asked for directions to other bases in base '" &
              To_String(Source => Sky_Bases(Base_Index).Name) & "'.",
            M_Type => ORDERMESSAGE);
      else -- asking friendly ship
         Radius := 40;
         Ship_Index :=
           Events_List
             (Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Event_Index)
             .Ship_Index;
         Amount :=
           (if Get_Proto_Ship(Proto_Index => Ship_Index).Crew.Length < 5 then 3
            elsif Get_Proto_Ship(Proto_Index => Ship_Index).Crew.Length < 10
            then 5
            else 10);
         Add_Message
           (Message =>
              To_String(Source => Player_Ship.Crew(Trader_Index).Name) &
              " asked ship '" &
              To_String
                (Source =>
                   Generate_Ship_Name
                     (Owner =>
                        Get_Proto_Ship(Proto_Index => Ship_Index).Owner)) &
              "' for directions to other bases.",
            M_Type => ORDERMESSAGE);
         Delete_Event
           (Event_Index =>
              Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Event_Index);
         Update_Orders(Ship => Player_Ship);
      end if;
      Bases_X_Loop :
      for X in -Radius .. Radius loop
         Bases_Y_Loop :
         for Y in -Radius .. Radius loop
            Temp_X := Player_Ship.Sky_X + X;
            Normalize_Coord(Coord => Temp_X);
            Temp_Y := Player_Ship.Sky_Y + Y;
            Normalize_Coord(Coord => Temp_Y, Is_X_Axis => False);
            Tmp_Base_Index := Sky_Map(Temp_X, Temp_Y).Base_Index;
            if Tmp_Base_Index > 0
              and then not Sky_Bases(Tmp_Base_Index).Known then
               Sky_Bases(Tmp_Base_Index).Known := True;
               Amount := Amount - 1;
               exit Bases_X_Loop when Amount = 0;
            end if;
         end loop Bases_Y_Loop;
      end loop Bases_X_Loop;
      if Amount > 0 then
         if Base_Index > 0 then -- asking in base
            if Sky_Bases(Base_Index).Population < 150 and then Amount > 1 then
               Amount := 1;
            elsif Sky_Bases(Base_Index).Population < 300
              and then Amount > 2 then
               Amount := 2;
            elsif Amount > 4 then
               Amount := 4;
            end if;
         else -- asking friendly ship
            Amount :=
              (if Get_Proto_Ship(Proto_Index => Ship_Index).Crew.Length < 5
               then 1
               elsif Get_Proto_Ship(Proto_Index => Ship_Index).Crew.Length < 10
               then 2
               else 4);
         end if;
         Count_Unknown_Bases_Loop :
         for Sky_Base of Sky_Bases loop
            if not Sky_Base.Known then
               Unknown_Bases := Unknown_Bases + 1;
            end if;
            exit Count_Unknown_Bases_Loop when Unknown_Bases >= Amount;
         end loop Count_Unknown_Bases_Loop;
         if Unknown_Bases >= Amount then
            Reveal_Random_Bases_Loop :
            loop
               Tmp_Base_Index := Get_Random(Min => 1, Max => 1_024);
               if not Sky_Bases(Tmp_Base_Index).Known then
                  Sky_Bases(Tmp_Base_Index).Known := True;
                  Amount := Amount - 1;
               end if;
               exit Reveal_Random_Bases_Loop when Amount = 0;
            end loop Reveal_Random_Bases_Loop;
         else
            Reveal_Bases_Loop :
            for Sky_Base of Sky_Bases loop
               if not Sky_Base.Known then
                  Sky_Base.Known := True;
               end if;
            end loop Reveal_Bases_Loop;
         end if;
      end if;
      Gain_Exp
        (Amount => 1, Skill_Number => Talking_Skill,
         Crew_Index => Trader_Index);
      Update_Game(Minutes => 30);
   end Ask_For_Bases;

   procedure Ask_For_Events is
      use Ada.Numerics.Elementary_Functions;
      use Tiny_String;

      Base_Index: constant Extended_Base_Range :=
        Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Base_Index;
      Event_Time, Diff_X, Diff_Y: Positive := 1;
      Event: Events_Types := NONE;
      Min_X, Min_Y, Max_X, Max_Y: Integer range -100 .. 1_124;
      --## rule off IMPROPER_INITIALIZATION
      Enemies: Positive_Container.Vector;
      --## rule on IMPROPER_INITIALIZATION
      Attempts: Natural range 0 .. 10 := 10;
      New_Item_Index: Natural := 0;
      Ship_Index: Natural := 0;
      Trader_Index: constant Crew_Container.Extended_Index :=
        Find_Member(Order => TALK);
      Max_Events, Events_Amount: Positive range 1 .. 15;
      Tmp_Base_Index: Bases_Range := 1;
      Event_X, Event_Y: Positive range 1 .. 1_024 := 1;
      Item_Index: Integer := 0;
   begin
      if Trader_Index = 0 then
         return;
      end if;
      if Base_Index > 0 then -- asking in base
         Max_Events :=
           (if Sky_Bases(Base_Index).Population < 150 then 5
            elsif Sky_Bases(Base_Index).Population < 300 then 10 else 15);
         Sky_Bases(Base_Index).Asked_For_Events := Game_Date;
         Add_Message
           (Message =>
              To_String(Source => Player_Ship.Crew(Trader_Index).Name) &
              " asked for recent events known at base '" &
              To_String(Source => Sky_Bases(Base_Index).Name) & "'.",
            M_Type => ORDERMESSAGE);
         Gain_Rep(Base_Index => Base_Index, Points => 1);
      else -- asking friendly ship
         Ship_Index :=
           Events_List
             (Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Event_Index)
             .Ship_Index;
         Max_Events :=
           (if Get_Proto_Ship(Proto_Index => Ship_Index).Crew.Length < 5 then 1
            elsif Get_Proto_Ship(Proto_Index => Ship_Index).Crew.Length < 10
            then 3
            else 5);
         Add_Message
           (Message =>
              To_String(Source => Player_Ship.Crew(Trader_Index).Name) &
              " asked ship '" &
              To_String
                (Source =>
                   Generate_Ship_Name
                     (Owner =>
                        Get_Proto_Ship(Proto_Index => Ship_Index).Owner)) &
              "' for recent events.",
            M_Type => ORDERMESSAGE);
         Delete_Event
           (Event_Index =>
              Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Event_Index);
         Update_Orders(Ship => Player_Ship);
      end if;
      Events_Amount := Get_Random(Min => 1, Max => Max_Events);
      Min_X := Player_Ship.Sky_X - 100;
      Normalize_Coord(Coord => Min_X);
      Max_X := Player_Ship.Sky_X + 100;
      Normalize_Coord(Coord => Max_X);
      Min_Y := Player_Ship.Sky_Y - 100;
      Normalize_Coord(Coord => Min_Y, Is_X_Axis => False);
      Max_Y := Player_Ship.Sky_Y + 100;
      Normalize_Coord(Coord => Max_Y, Is_X_Axis => False);
      --## rule off IMPROPER_INITIALIZATION
      Generate_Enemies(Enemies => Enemies);
      --## rule on IMPROPER_INITIALIZATION
      Generate_Events_Loop :
      for I in 1 .. Events_Amount loop
         Event := Events_Types'Val(Get_Random(Min => 1, Max => 5));
         Attempts := 10;
         Generate_Event_Location_Loop :
         loop
            if Event = ENEMYSHIP then
               Event_X := Get_Random(Min => Min_X, Max => Max_X);
               Event_Y := Get_Random(Min => Min_Y, Max => Max_Y);
               exit Generate_Event_Location_Loop when Sky_Map(Event_X, Event_Y)
                   .Base_Index =
                 0 and
                 Event_X /= Player_Ship.Sky_X and
                 Event_Y /= Player_Ship.Sky_Y and
                 Sky_Map(Event_X, Event_Y).Event_Index = 0;
            else
               Tmp_Base_Index := Get_Random(Min => 1, Max => 1_024);
               Event_X := Sky_Bases(Tmp_Base_Index).Sky_X;
               Event_Y := Sky_Bases(Tmp_Base_Index).Sky_Y;
               Attempts := Attempts - 1;
               if Attempts = 0 then
                  Event := ENEMYSHIP;
                  Regenerate_Event_Location_Loop :
                  loop
                     Event_X := Get_Random(Min => Min_X, Max => Max_X);
                     Event_Y := Get_Random(Min => Min_Y, Max => Max_Y);
                     exit Regenerate_Event_Location_Loop when Sky_Map
                         (Event_X, Event_Y)
                         .Base_Index =
                       0 and
                       Event_X /= Player_Ship.Sky_X and
                       Event_Y /= Player_Ship.Sky_Y and
                       Sky_Map(Event_X, Event_Y).Event_Index = 0;
                  end loop Regenerate_Event_Location_Loop;
                  exit Generate_Event_Location_Loop;
               end if;
               if Event_X /= Player_Ship.Sky_X and
                 Event_Y /= Player_Ship.Sky_Y and
                 Sky_Map(Event_X, Event_Y).Event_Index = 0 and
                 Sky_Bases(Sky_Map(Event_X, Event_Y).Base_Index).Known then
                  if Event = ATTACKONBASE and
                    Sky_Bases(Sky_Map(Event_X, Event_Y).Base_Index)
                        .Population /=
                      0 then
                     exit Generate_Event_Location_Loop;
                  end if;
                  if Event = DOUBLEPRICE and
                    Is_Friendly
                      (Source_Faction => Player_Ship.Crew(1).Faction,
                       Target_Faction =>
                         Sky_Bases(Sky_Map(Event_X, Event_Y).Base_Index)
                           .Owner) then
                     exit Generate_Event_Location_Loop;
                  end if;
                  if Event = DISEASE and
                    not Get_Faction
                      (Index =>
                         Sky_Bases(Sky_Map(Event_X, Event_Y).Base_Index).Owner)
                      .Flags
                      .Contains
                      (Item =>
                         To_Unbounded_String(Source => "diseaseimmune")) and
                    Is_Friendly
                      (Source_Faction => Player_Ship.Crew(1).Faction,
                       Target_Faction =>
                         Sky_Bases(Sky_Map(Event_X, Event_Y).Base_Index)
                           .Owner) then
                     exit Generate_Event_Location_Loop;
                  end if;
                  if Event = BASERECOVERY and
                    Sky_Bases(Sky_Map(Event_X, Event_Y).Base_Index)
                        .Population =
                      0 then
                     exit Generate_Event_Location_Loop;
                  end if;
               end if;
            end if;
         end loop Generate_Event_Location_Loop;
         Diff_X := abs (Player_Ship.Sky_X - Event_X);
         Diff_Y := abs (Player_Ship.Sky_Y - Event_Y);
         --## rule off SIMPLIFIABLE_EXPRESSIONS
         Event_Time :=
           Positive(60.0 * Sqrt(X => Float((Diff_X**2) + (Diff_Y**2))));
         --## rule on SIMPLIFIABLE_EXPRESSIONS
         case Event is
            when ENEMYSHIP =>
               Events_List.Append
                 (New_Item =>
                    (E_Type => ENEMYSHIP, Sky_X => Event_X, Sky_Y => Event_Y,
                     Time =>
                       Get_Random(Min => Event_Time, Max => Event_Time + 60),
                     Ship_Index =>
                       Enemies
                         (Get_Random
                            (Min => Enemies.First_Index,
                             Max => Enemies.Last_Index))));
            when ATTACKONBASE =>
               Generate_Enemies
                 (Enemies => Enemies,
                  Owner => Tiny_String.To_Bounded_String(Source => "Any"),
                  With_Traders => False);
               Events_List.Append
                 (New_Item =>
                    (E_Type => ATTACKONBASE, Sky_X => Event_X,
                     Sky_Y => Event_Y,
                     Time =>
                       Get_Random(Min => Event_Time, Max => Event_Time + 120),
                     Ship_Index =>
                       Enemies
                         (Get_Random
                            (Min => Enemies.First_Index,
                             Max => Enemies.Last_Index))));
               Generate_Enemies(Enemies => Enemies);
            when DISEASE =>
               Events_List.Append
                 (New_Item =>
                    (E_Type => DISEASE, Sky_X => Event_X, Sky_Y => Event_Y,
                     Time => Get_Random(Min => 10_080, Max => 12_000),
                     Data => 1));
            when DOUBLEPRICE =>
               Set_Double_Price_Event_Loop :
               loop
                  Item_Index := Get_Random(Min => 1, Max => Get_Proto_Amount);
                  Find_Item_Index_Loop :
                  for J in 1 .. Get_Proto_Amount loop
                     Item_Index := Item_Index - 1;
                     if Item_Index <= 0
                       and then
                         Get_Price
                           (Base_Type =>
                              Sky_Bases(Sky_Map(Event_X, Event_Y).Base_Index)
                                .Base_Type,
                            Item_Index => J) >
                         0 then
                        New_Item_Index := J;
                        exit Set_Double_Price_Event_Loop;
                     end if;
                  end loop Find_Item_Index_Loop;
               end loop Set_Double_Price_Event_Loop;
               Events_List.Append
                 (New_Item =>
                    (E_Type => DOUBLEPRICE, Sky_X => Event_X, Sky_Y => Event_Y,
                     Time =>
                       Get_Random
                         (Min => Event_Time * 3, Max => Event_Time * 4),
                     Item_Index => New_Item_Index));
            when BASERECOVERY =>
               Recover_Base
                 (Base_Index => Sky_Map(Event_X, Event_Y).Base_Index);
            when others =>
               null;
         end case;
         if Event /= BASERECOVERY then
            Sky_Map(Event_X, Event_Y).Event_Index := Events_List.Last_Index;
         end if;
      end loop Generate_Events_Loop;
      Gain_Exp
        (Amount => 1, Skill_Number => Talking_Skill,
         Crew_Index => Trader_Index);
      Update_Game(Minutes => 30);
   end Ask_For_Events;

   procedure Update_Population is
      Base_Index: constant Bases_Range :=
        Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Base_Index;
      Population_Diff: Integer := 0;
   begin
      if Days_Difference
          (Date_To_Compare => Sky_Bases(Base_Index).Recruit_Date) <
        30 then
         return;
      end if;
      if Sky_Bases(Base_Index).Population > 0 then
         if Get_Random(Min => 1, Max => 100) > 30 then
            return;
         end if;
         --## rule off SIMPLIFIABLE_EXPRESSIONS
         Population_Diff :=
           (if Get_Random(Min => 1, Max => 100) < 20 then
              -(Get_Random(Min => 1, Max => 10))
            else Get_Random(Min => 1, Max => 10));
         if Sky_Bases(Base_Index).Population + Population_Diff < 0 then
            Population_Diff := -(Sky_Bases(Base_Index).Population);
         end if;
         --## rule on SIMPLIFIABLE_EXPRESSIONS
         Sky_Bases(Base_Index).Population :=
           Sky_Bases(Base_Index).Population + Population_Diff;
         if Sky_Bases(Base_Index).Population = 0 then
            Sky_Bases(Base_Index).Reputation := Default_Reputation;
         end if;
      else
         if Get_Random(Min => 1, Max => 100) > 5 then
            return;
         end if;
         Sky_Bases(Base_Index).Population := Get_Random(Min => 5, Max => 10);
         Sky_Bases(Base_Index).Owner := Get_Random_Faction;
      end if;
   end Update_Population;

   procedure Update_Prices is
      Base_Index: constant Bases_Range :=
        Sky_Map(Player_Ship.Sky_X, Player_Ship.Sky_Y).Base_Index;
      Roll: Positive range 1 .. 100 := 1;
      Chance: Positive :=
        (if Sky_Bases(Base_Index).Population < 150 then 1
         elsif Sky_Bases(Base_Index).Population < 300 then 2 else 5);
      Item: Base_Cargo := Empty_Base_Cargo;
   begin
      if Sky_Bases(Base_Index).Population = 0 then
         return;
      end if;
      --## rule off SIMPLIFIABLE_EXPRESSIONS
      Chance :=
        Chance +
        (Days_Difference(Date_To_Compare => Sky_Bases(Base_Index).Visited) /
         10);
      --## rule on SIMPLIFIABLE_EXPRESSIONS
      if Get_Random(Min => 1, Max => 100) > Chance then
         return;
      end if;
      Update_Prices_Loop :
      for I in
        BaseCargo_Container.First_Index
          (Container => Sky_Bases(Base_Index).Cargo) ..
          BaseCargo_Container.Last_Index
            (Container => Sky_Bases(Base_Index).Cargo) loop
         Item :=
           BaseCargo_Container.Element
             (Container => Sky_Bases(Base_Index).Cargo, Index => I);
         Roll := Get_Random(Min => 1, Max => 100);
         if Roll < 30 and Item.Price > 1 then
            Item.Price := Item.Price - 1;
         elsif Roll < 60 and Item.Price > 0 then
            Item.Price := Item.Price + 1;
         end if;
         BaseCargo_Container.Replace_Element
           (Container => Sky_Bases(Base_Index).Cargo, Index => I,
            New_Item => Item);
      end loop Update_Prices_Loop;
   end Update_Prices;

   procedure Get_Base_Reputation(Base_Index: Bases_Range) is
      procedure Get_Ada_Base_Reputation
        (B_Index, Level, Experience: Integer) with
         Import => True,
         Convention => C,
         External_Name => "getAdaBaseReputation";
   begin
      Get_Ada_Base_Reputation
        (B_Index => Base_Index,
         Level => Sky_Bases(Base_Index).Reputation.Level,
         Experience => Sky_Bases(Base_Index).Reputation.Experience);
   end Get_Base_Reputation;

   procedure Set_Base_Reputation(Base_Index: Bases_Range) is
      procedure Set_Ada_Base_Reputation
        (B_Index: Integer; Level, Experience: out Integer) with
         Import => True,
         Convention => C,
         External_Name => "setAdaBaseReputation";
   begin
      Set_Ada_Base_Reputation
        (B_Index => Base_Index,
         Level => Sky_Bases(Base_Index).Reputation.Level,
         Experience => Sky_Bases(Base_Index).Reputation.Experience);
   end Set_Base_Reputation;

   procedure Get_Base_Owner(Base_Index: Bases_Range) is
      procedure Get_Ada_Base_Owner(B_Index: Integer; Owner: chars_ptr) with
         Import => True,
         Convention => C,
         External_Name => "getAdaBaseOwner";
   begin
      Get_Ada_Base_Owner
        (B_Index => Base_Index,
         Owner =>
           New_String
             (Str =>
                Tiny_String.To_String(Source => Sky_Bases(Base_Index).Owner)));
   end Get_Base_Owner;

end Bases;
