--    Copyright 2018 Bartek thindil Jasicki
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

with Ada.Text_IO; use Ada.Text_IO;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with Gtkada.Builder; use Gtkada.Builder;
with Gtk.Widget; use Gtk.Widget;
with Gtk.Label; use Gtk.Label;
with Gtk.Tree_Model; use Gtk.Tree_Model;
with Gtk.List_Store; use Gtk.List_Store;
with Gtk.Tree_View; use Gtk.Tree_View;
with Gtk.Tree_View_Column; use Gtk.Tree_View_Column;
with Gtk.Tree_Selection; use Gtk.Tree_Selection;
with Gtk.Button; use Gtk.Button;
with Glib; use Glib;
with Glib.Error; use Glib.Error;
with Glib.Object; use Glib.Object;
with Maps; use Maps;
with Maps.UI; use Maps.UI;
with Messages; use Messages;
with Ships; use Ships;
with Ships.Crew; use Ships.Crew;
with Items; use Items;
with Bases.Ship; use Bases.Ship;
with Bases.Trade; use Bases.Trade;
with Crafts; use Crafts;
with Utils.UI; use Utils.UI;

package body Bases.UI is

   Builder: Gtkada_Builder;
   type States is (RECIPES, REPAIRS, HEAL, CLEARING);
   CurrentState: States;

   procedure HideLastMessage2(User_Data: access GObject_Record'Class) is
   begin
      Hide(Gtk_Widget(User_Data));
      LastMessage := Null_Unbounded_String;
   end HideLastMessage2;

   procedure ShowLastMessage2 is
   begin
      if LastMessage = Null_Unbounded_String then
         HideLastMessage2(Get_Object(Builder, "infolastmessage1"));
      else
         Set_Text
           (Gtk_Label(Get_Object(Builder, "lbllastmessage1")),
            To_String(LastMessage));
         Show_All(Gtk_Widget(Get_Object(Builder, "infolastmessage1")));
         LastMessage := Null_Unbounded_String;
      end if;
   end ShowLastMessage2;

   procedure ShowRecruitInfo(Object: access Gtkada_Builder_Record'Class) is
      RecruitIter, Iter: Gtk_Tree_Iter;
      RecruitModel: Gtk_Tree_Model;
      RecruitInfo: Unbounded_String;
      Recruit: Recruit_Data;
      BaseIndex: constant Positive :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex;
      List: Gtk_List_Store;
      MoneyIndex2: Natural;
      Cost, RecruitIndex: Positive;
   begin
      Get_Selected
        (Gtk.Tree_View.Get_Selection
           (Gtk_Tree_View(Get_Object(Object, "treerecruits"))),
         RecruitModel,
         RecruitIter);
      if RecruitIter = Null_Iter then
         return;
      end if;
      RecruitIndex := Positive(Get_Int(RecruitModel, RecruitIter, 1));
      Recruit := SkyBases(BaseIndex).Recruits(RecruitIndex);
      if Recruit.Gender = 'M' then
         RecruitInfo := To_Unbounded_String("Gender: Male");
      else
         RecruitInfo := To_Unbounded_String("Gender: Female");
      end if;
      Set_Markup
        (Gtk_Label(Get_Object(Object, "lblrecruitinfo")),
         To_String(RecruitInfo));
      List := Gtk_List_Store(Get_Object(Object, "statslist"));
      Clear(List);
      for I in Recruit.Attributes.Iterate loop
         Append(List, Iter);
         Set
           (List,
            Iter,
            0,
            To_String(Attributes_Names(Attributes_Container.To_Index(I))));
         Set(List, Iter, 1, Gint(Recruit.Attributes(I)(1) * 2));
      end loop;
      List := Gtk_List_Store(Get_Object(Object, "skillslist"));
      Clear(List);
      for Skill of Recruit.Skills loop
         Append(List, Iter);
         Set(List, Iter, 0, To_String(Skills_List(Skill(1)).Name));
         Set(List, Iter, 1, Gint(Skill(2)));
      end loop;
      MoneyIndex2 := FindItem(PlayerShip.Cargo, FindProtoItem(MoneyIndex));
      if MoneyIndex2 > 0 then
         Set_Label
           (Gtk_Label(Get_Object(Object, "lblrecruitmoney")),
            "You have" &
            Natural'Image(PlayerShip.Cargo(MoneyIndex2).Amount) &
            " " &
            To_String(MoneyName) &
            ".");
         Cost := Recruit.Price;
         CountPrice(Cost, FindMember(Talk));
         Set_Label
           (Gtk_Button(Get_Object(Object, "btnrecruit")),
            "Hire for" & Positive'Image(Cost) & " " & To_String(MoneyName));
         if PlayerShip.Cargo(MoneyIndex2).Amount < Cost then
            Set_Sensitive(Gtk_Widget(Get_Object(Object, "btnrecruit")), False);
         else
            Set_Sensitive(Gtk_Widget(Get_Object(Object, "btnrecruit")), True);
         end if;
      else
         Set_Label
           (Gtk_Label(Get_Object(Object, "lblrecruitmoney")),
            "You don't have any money for recruit anyone");
         Set_Sensitive(Gtk_Widget(Get_Object(Object, "btnrecruit")), False);
      end if;
   end ShowRecruitInfo;

   procedure SetActiveRow(TreeViewName, ColumnName: String) is
   begin
      Set_Cursor
        (Gtk_Tree_View(Get_Object(Builder, TreeViewName)),
         Gtk_Tree_Path_New_From_String("0"),
         Gtk_Tree_View_Column(Get_Object(Builder, ColumnName)),
         False);
   end SetActiveRow;

   procedure Hire(Object: access Gtkada_Builder_Record'Class) is
      RecruitIter: Gtk_Tree_Iter;
      RecruitModel: Gtk_Tree_Model;
      RecruitIndex: Positive;
   begin
      Get_Selected
        (Gtk.Tree_View.Get_Selection
           (Gtk_Tree_View(Get_Object(Object, "treerecruits"))),
         RecruitModel,
         RecruitIter);
      RecruitIndex :=
        Natural'Value(To_String(Get_Path(RecruitModel, RecruitIter))) + 1;
      HireRecruit(RecruitIndex);
      Remove(-(RecruitModel), RecruitIter);
      SetActiveRow("treerecruits", "columnname");
      ShowLastMessage(Object);
   end Hire;

   procedure ObjectSelected(Object: access Gtkada_Builder_Record'Class) is
      Iter: Gtk_Tree_Iter;
      Model: Gtk_Tree_Model;
      Cost, Time: Natural := 0;
      BaseIndex: constant Positive :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex;
      BaseType: constant Positive :=
        Bases_Types'Pos(SkyBases(BaseIndex).BaseType) + 1;
      MoneyIndex2: Natural;
      ObjectIndex: Integer;
      MinChildren: Gint;
   begin
      if CurrentState = CLEARING then
         return;
      end if;
      Get_Selected
        (Gtk.Tree_View.Get_Selection
           (Gtk_Tree_View(Get_Object(Object, "treebases"))),
         Model,
         Iter);
      if Iter = Null_Iter then
         return;
      end if;
      case CurrentState is
         when RECIPES =>
            if N_Children(Model, Null_Iter) = 0 then
               Hide(Gtk_Widget(Get_Object(Object, "basewindow")));
               CreateSkyMap;
               return;
            end if;
         when REPAIRS =>
            if SkyBases(BaseIndex).Population < 150 then
               MinChildren := 1;
            elsif SkyBases(BaseIndex).Population > 149 and
              SkyBases(BaseIndex).Population < 300 then
               MinChildren := 2;
            else
               MinChildren := 3;
            end if;
            if N_Children(Model, Null_Iter) = MinChildren then
               Hide(Gtk_Widget(Get_Object(Object, "basewindow")));
               CreateSkyMap;
               return;
            end if;
         when HEAL =>
            if N_Children(Model, Null_Iter) = 1 then
               Hide(Gtk_Widget(Get_Object(Object, "basewindow")));
               CreateSkyMap;
               return;
            end if;
         when CLEARING =>
            null;
      end case;
      ObjectIndex := Integer(Get_Int(Model, Iter, 1));
      case CurrentState is
         when RECIPES =>
            if Items_List(Recipes_List(ObjectIndex).ResultIndex).Prices
                (BaseType) >
              0 then
               Cost :=
                 Items_List(Recipes_List(ObjectIndex).ResultIndex).Prices
                   (BaseType) *
                 Recipes_List(ObjectIndex).Difficulty *
                 100;
            else
               Cost := Recipes_List(ObjectIndex).Difficulty * 100;
            end if;
            CountPrice(Cost, FindMember(Talk));
            Set_Label
              (Gtk_Label(Get_Object(Object, "lblinfo")),
               "Base price:" &
               Positive'Image(Cost) &
               " " &
               To_String(MoneyName));
         when REPAIRS =>
            RepairCost(Cost, Time, ObjectIndex);
            CountPrice(Cost, FindMember(Talk));
            Set_Label
              (Gtk_Label(Get_Object(Object, "lblinfo")),
               "Repair cost:" &
               Natural'Image(Cost) &
               " " &
               To_String(MoneyName) &
               ASCII.LF &
               "Repair time:" &
               Natural'Image(Time) &
               " minutes");
         when HEAL =>
            HealCost(Cost, Time, ObjectIndex);
            Set_Label
              (Gtk_Label(Get_Object(Object, "lblinfo")),
               "Heal cost:" &
               Natural'Image(Cost) &
               " " &
               To_String(MoneyName) &
               ASCII.LF &
               "Heal time:" &
               Natural'Image(Time) &
               " minutes");
         when CLEARING =>
            null;
      end case;
      MoneyIndex2 := FindItem(PlayerShip.Cargo, FindProtoItem(MoneyIndex));
      if MoneyIndex2 > 0 then
         Set_Label
           (Gtk_Label(Get_Object(Object, "lblmoneyamount")),
            "You have" &
            Natural'Image(PlayerShip.Cargo(MoneyIndex2).Amount) &
            " " &
            To_String(MoneyName) &
            ".");
         if PlayerShip.Cargo(MoneyIndex2).Amount < Cost then
            Set_Sensitive(Gtk_Widget(Get_Object(Object, "btnaccept")), False);
         else
            Set_Sensitive(Gtk_Widget(Get_Object(Object, "btnaccept")), True);
         end if;
      else
         Set_Sensitive(Gtk_Widget(Get_Object(Object, "btnaccept")), False);
         Set_Label
           (Gtk_Label(Get_Object(Object, "lblmoneyamount")),
            "You don't have any money.");
      end if;
   end ObjectSelected;

   procedure AcceptAction(Object: access Gtkada_Builder_Record'Class) is
      Iter: Gtk_Tree_Iter;
      Model: Gtk_Tree_Model;
   begin
      Get_Selected
        (Gtk.Tree_View.Get_Selection
           (Gtk_Tree_View(Get_Object(Object, "treebases"))),
         Model,
         Iter);
      if Iter = Null_Iter then
         return;
      end if;
      case CurrentState is
         when RECIPES =>
            BuyRecipe(Positive(Get_Int(Model, Iter, 1)));
         when REPAIRS =>
            Bases.Ship.RepairShip(Integer(Get_Int(Model, Iter, 1)));
         when HEAL =>
            HealWounded(Natural(Get_Int(Model, Iter, 1)));
         when CLEARING =>
            null;
      end case;
      Remove(-(Model), Iter);
      SetActiveRow("treebases", "columnbases");
      ShowLastMessage2;
   end AcceptAction;

   procedure CreateBasesUI is
      Error: aliased GError;
   begin
      if Builder /= null then
         return;
      end if;
      Gtk_New(Builder);
      if Add_From_File
          (Builder,
           To_String(DataDirectory) & "ui" & Dir_Separator & "bases.glade",
           Error'Access) =
        Guint(0) then
         Put_Line("Error : " & Get_Message(Error));
         return;
      end if;
      Register_Handler(Builder, "Hide_Base_Window", HideInfo'Access);
      Register_Handler(Builder, "Hide_Last_Message", HideLastMessage2'Access);
      Register_Handler(Builder, "Show_Recruit_Info", ShowRecruitInfo'Access);
      Register_Handler(Builder, "Hire_Recruit", Hire'Access);
      Register_Handler(Builder, "Object_Selected", ObjectSelected'Access);
      Register_Handler(Builder, "Accept_Action", AcceptAction'Access);
      Do_Connect(Builder);
      On_Key_Release_Event
        (Gtk_Widget(Get_Object(Builder, "basewindow")),
         CloseWindow'Access);
      On_Key_Release_Event
        (Gtk_Widget(Get_Object(Builder, "recruitwindow")),
         CloseWindow'Access);
   end CreateBasesUI;

   procedure ShowRecruitUI is
      RecruitIter: Gtk_Tree_Iter;
      RecruitList: Gtk_List_Store;
      BaseIndex: constant Positive :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex;
   begin
      RecruitList := Gtk_List_Store(Get_Object(Builder, "recruitlist"));
      Clear(RecruitList);
      for I in SkyBases(BaseIndex).Recruits.Iterate loop
         Append(RecruitList, RecruitIter);
         Set
           (RecruitList,
            RecruitIter,
            0,
            To_String(SkyBases(BaseIndex).Recruits(I).Name));
         Set(RecruitList, RecruitIter, 1, Gint(Recruit_Container.To_Index(I)));
      end loop;
      Show_All(Gtk_Widget(Get_Object(Builder, "recruitwindow")));
      SetActiveRow("treerecruits", "columnname");
      ShowLastMessage(Builder);
   end ShowRecruitUI;

   procedure ShowBuyRecipesUI is
      RecipesIter: Gtk_Tree_Iter;
      RecipesList: Gtk_List_Store;
      BaseIndex: constant Positive :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex;
      BaseType: constant Positive :=
        Bases_Types'Pos(SkyBases(BaseIndex).BaseType) + 1;
   begin
      CurrentState := CLEARING;
      RecipesList := Gtk_List_Store(Get_Object(Builder, "itemslist"));
      Clear(RecipesList);
      CurrentState := RECIPES;
      for I in Recipes_List.Iterate loop
         if Recipes_List(I).BaseType = BaseType and
           Known_Recipes.Find_Index(Item => Recipes_Container.To_Index(I)) =
             Positive_Container.No_Index then
            Append(RecipesList, RecipesIter);
            Set
              (RecipesList,
               RecipesIter,
               0,
               To_String(Items_List(Recipes_List(I).ResultIndex).Name));
            Set
              (RecipesList,
               RecipesIter,
               1,
               Gint(Recipes_Container.To_Index(I)));
         end if;
      end loop;
      Set_Label(Gtk_Button(Get_Object(Builder, "btnaccept")), "Buy recipe");
      Show_All(Gtk_Widget(Get_Object(Builder, "basewindow")));
      SetActiveRow("treebases", "columnbases");
      ShowLastMessage2;
   end ShowBuyRecipesUI;

   procedure ShowRepairUI is
      RepairsIter: Gtk_Tree_Iter;
      RepairsList: Gtk_List_Store;
      BaseIndex: constant Positive :=
        SkyMap(PlayerShip.SkyX, PlayerShip.SkyY).BaseIndex;
   begin
      CurrentState := CLEARING;
      RepairsList := Gtk_List_Store(Get_Object(Builder, "itemslist"));
      Clear(RepairsList);
      CurrentState := REPAIRS;
      for I in PlayerShip.Modules.Iterate loop
         if PlayerShip.Modules(I).Durability <
           PlayerShip.Modules(I).MaxDurability then
            Append(RepairsList, RepairsIter);
            Set
              (RepairsList,
               RepairsIter,
               0,
               To_String(PlayerShip.Modules(I).Name));
            Set
              (RepairsList,
               RepairsIter,
               1,
               Gint(Modules_Container.To_Index(I)));
         end if;
      end loop;
      Append(RepairsList, RepairsIter);
      Set(RepairsList, RepairsIter, 0, "Slowly repair whole ship");
      Set(RepairsList, RepairsIter, 1, 0);
      if SkyBases(BaseIndex).Population > 149 then
         Append(RepairsList, RepairsIter);
         Set(RepairsList, RepairsIter, 0, "Repair whole ship");
         Set(RepairsList, RepairsIter, 1, -1);
      end if;
      if SkyBases(BaseIndex).Population > 299 then
         Append(RepairsList, RepairsIter);
         Set(RepairsList, RepairsIter, 0, "Fast repair whole ship");
         Set(RepairsList, RepairsIter, 1, -2);
      end if;
      Set_Label(Gtk_Button(Get_Object(Builder, "btnaccept")), "Buy repairs");
      Show_All(Gtk_Widget(Get_Object(Builder, "basewindow")));
      SetActiveRow("treebases", "columnbases");
      ShowLastMessage2;
   end ShowRepairUI;

   procedure ShowHealUI is
      HealsIter: Gtk_Tree_Iter;
      HealsList: Gtk_List_Store;
   begin
      CurrentState := CLEARING;
      HealsList := Gtk_List_Store(Get_Object(Builder, "itemslist"));
      Clear(HealsList);
      CurrentState := HEAL;
      for I in PlayerShip.Crew.Iterate loop
         if PlayerShip.Crew(I).Health < 100 then
            Append(HealsList, HealsIter);
            Set(HealsList, HealsIter, 0, To_String(PlayerShip.Crew(I).Name));
            Set(HealsList, HealsIter, 1, Gint(Crew_Container.To_Index(I)));
         end if;
      end loop;
      Append(HealsList, HealsIter);
      Set(HealsList, HealsIter, 0, "Heal all wounded crew members");
      Set(HealsList, HealsIter, 1, 0);
      Set_Label(Gtk_Button(Get_Object(Builder, "btnaccept")), "Buy healing");
      Show_All(Gtk_Widget(Get_Object(Builder, "basewindow")));
      SetActiveRow("treebases", "columnbases");
      ShowLastMessage2;
   end ShowHealUI;

end Bases.UI;
