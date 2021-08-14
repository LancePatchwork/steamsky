-- Copyright (c) 2020-2021 Bartek thindil Jasicki <thindil@laeran.pl>
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Characters.Latin_1; use Ada.Characters.Latin_1;
with Ada.Containers.Generic_Array_Sort;
with Ada.Strings; use Ada.Strings;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Interfaces.C; use Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with CArgv;
with Tcl; use Tcl;
with Tcl.Ada; use Tcl.Ada;
with Tcl.Tk.Ada; use Tcl.Tk.Ada;
with Tcl.Tk.Ada.Grid;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.Canvas; use Tcl.Tk.Ada.Widgets.Canvas;
with Tcl.Tk.Ada.Widgets.Menu; use Tcl.Tk.Ada.Widgets.Menu;
with Tcl.Tk.Ada.Widgets.Text; use Tcl.Tk.Ada.Widgets.Text;
with Tcl.Tk.Ada.Widgets.Toplevel.MainWindow;
use Tcl.Tk.Ada.Widgets.Toplevel.MainWindow;
with Tcl.Tk.Ada.Widgets.TtkButton; use Tcl.Tk.Ada.Widgets.TtkButton;
with Tcl.Tk.Ada.Widgets.TtkEntry; use Tcl.Tk.Ada.Widgets.TtkEntry;
with Tcl.Tk.Ada.Widgets.TtkEntry.TtkSpinBox;
use Tcl.Tk.Ada.Widgets.TtkEntry.TtkSpinBox;
with Tcl.Tk.Ada.Widgets.TtkEntry.TtkComboBox;
use Tcl.Tk.Ada.Widgets.TtkEntry.TtkComboBox;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Tcl.Tk.Ada.Widgets.TtkLabel; use Tcl.Tk.Ada.Widgets.TtkLabel;
with Tcl.Tk.Ada.Widgets.TtkPanedWindow; use Tcl.Tk.Ada.Widgets.TtkPanedWindow;
with Tcl.Tk.Ada.Widgets.TtkScrollbar; use Tcl.Tk.Ada.Widgets.TtkScrollbar;
with Tcl.Tk.Ada.Winfo; use Tcl.Tk.Ada.Winfo;
with CoreUI; use CoreUI;
with Dialogs; use Dialogs;
with Items; use Items;
with Maps.UI; use Maps.UI;
with Table; use Table;
with Utils.UI; use Utils.UI;

package body Crafts.UI is

   -- ****iv* CUI4/CUI4.RecipesTable
   -- FUNCTION
   -- Table with info about available crafting recipes
   -- SOURCE
   RecipesTable: Table_Widget (5);
   -- ****

   -- ****iv* CUI4/CUI4.Modules_Indexes
   -- FUNCTION
   -- Indexes of the player ship modules
   -- SOURCE
   Recipes_Indexes: UnboundedString_Container.Vector;
   -- ****

   -- ****iv* Crafts.UI/Studies
   -- FUNCTION
   -- The list of available study recipes
   -- SOURCE
   Studies: UnboundedString_Container.Vector;
   -- ****

   -- ****iv* Crafts.UI/Deconstructs
   -- FUNCTION
   -- The list of available deconstruct recipes
   -- SOURCE
   Deconstructs: UnboundedString_Container.Vector;
   -- ****

   -- ****o* CUI4/CUI4.Show_Crafting_Command
   -- FUNCTION
   -- Show information about available crafting recipes
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command.
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowCrafting page recipename
   -- Page is the current page of recipes list to show, recipename is the
   -- text which will be searching in the recipes names. Can be empty, then
   -- show all recipes.
   -- SOURCE
   function Show_Crafting_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Crafting_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData);
      CraftsFrame: Ttk_Frame := Get_Widget(Main_Paned & ".craftframe", Interp);
      CraftsCanvas: constant Tk_Canvas :=
        Get_Widget(CraftsFrame & ".canvas", Interp);
      CanCraft, Has_Tool, Has_Workplace, Has_Materials: Boolean := True;
      Recipe: Craft_Data;
      CargoIndex: Natural;
      Page: constant Positive :=
        (if Argc = 2 then Positive'Value(CArgv.Arg(Argv, 1)) else 1);
      Start_Row: constant Positive := ((Page - 1) * 25) + 1;
      Current_Row: Positive := 1;
      RecipeName: constant String :=
        (if Argc = 3 then CArgv.Arg(Argv, 2) else "");
      SearchEntry: constant Ttk_Entry :=
        Get_Widget(CraftsCanvas & ".craft.sframe.search");
      procedure CheckTool(ToolNeeded: Unbounded_String) is
      begin
         if ToolNeeded /= To_Unbounded_String("None") then
            Has_Tool := False;
            Check_Tool_Loop :
            for I in Items_List.Iterate loop
               if Items_List(I).IType = ToolNeeded then
                  CargoIndex :=
                    FindItem(Player_Ship.Cargo, Objects_Container.Key(I));
                  if CargoIndex > 0 then
                     Has_Tool := True;
                     exit Check_Tool_Loop;
                  end if;
               end if;
            end loop Check_Tool_Loop;
         end if;
      end CheckTool;
   begin
      if Winfo_Get(CraftsCanvas, "exists") = "0" then
         Tcl_EvalFile
           (Get_Context,
            To_String(Data_Directory) & "ui" & Dir_Separator & "crafts.tcl");
         Bind(CraftsFrame, "<Configure>", "{ResizeCanvas %W.canvas %w %h}");
      elsif Winfo_Get(CraftsCanvas, "ismapped") = "1" and Argc = 1 then
         Entry_Configure(GameMenu, "Help", "-command {ShowHelp general}");
         Tcl_Eval(Interp, "InvokeButton " & Close_Button);
         Tcl.Tk.Ada.Grid.Grid_Remove(Close_Button);
         return TCL_OK;
      end if;
      if RecipeName'Length = 0 then
         configure(SearchEntry, "-validatecommand {}");
         Delete(SearchEntry, "0", "end");
         configure(SearchEntry, "-validatecommand {ShowCrafting 1 %P}");
      end if;
      Entry_Configure(GameMenu, "Help", "-command {ShowHelp crafts}");
      Studies.Clear;
      Deconstructs.Clear;
      Find_Possible_Recipes_Loop :
      for Item of Player_Ship.Cargo loop
         Add_Recipes_Loop :
         for J in Recipes_List.Iterate loop
            if Recipes_List(J).ResultIndex = Item.ProtoIndex then
               if Known_Recipes.Find_Index(Item => Recipes_Container.Key(J)) =
                 Positive_Container.No_Index and
                 Studies.Find_Index(Item => Item.ProtoIndex) =
                   Positive_Container.No_Index then
                  Studies.Append(New_Item => Item.ProtoIndex);
               end if;
               if Recipes_List(J).MaterialAmounts(1) > 1 and
                 Recipes_List(J).ResultAmount = 1 then
                  Deconstructs.Append(New_Item => Item.ProtoIndex);
               end if;
            end if;
         end loop Add_Recipes_Loop;
      end loop Find_Possible_Recipes_Loop;
      if Recipes_Indexes.Length /=
        Known_Recipes.Length + Studies.Length + Deconstructs.Length then
         Recipes_Indexes.Clear;
         for I in Known_Recipes.Iterate loop
            Recipes_Indexes.Append
              (To_Unbounded_String
                 (Trim
                    (Positive'Image
                       (Positive(UnboundedString_Container.To_Index(I))),
                     Left)));
         end loop;
         for I in Studies.Iterate loop
            Recipes_Indexes.Append
              (To_Unbounded_String
                 (Trim
                    (Positive'Image
                       (Positive(UnboundedString_Container.To_Index(I))),
                     Left)));
         end loop;
         for I in Deconstructs.Iterate loop
            Recipes_Indexes.Append
              (To_Unbounded_String
                 (Trim
                    (Positive'Image
                       (Positive(UnboundedString_Container.To_Index(I))),
                     Left)));
         end loop;
      end if;
      if RecipesTable.Row_Height = 1 then
         RecipesTable :=
           CreateTable
             (CraftsCanvas & ".craft",
              (To_Unbounded_String("Name"), To_Unbounded_String("Craftable"),
               To_Unbounded_String("Workshop"), To_Unbounded_String("Tools"),
               To_Unbounded_String("Materials")),
              Get_Widget(CraftsFrame & ".scrolly"));
      else
         ClearTable(RecipesTable);
      end if;
      Show_Recipes_Loop :
      for I in Known_Recipes.Iterate loop
         if RecipeName'Length > 0
           and then
             Index
               (To_Lower
                  (To_String
                     (Items_List(Recipes_List(Known_Recipes(I)).ResultIndex)
                        .Name)),
                To_Lower(RecipeName), 1) =
             0 then
            goto End_Of_Loop;
         end if;
         if Current_Row < Start_Row then
            Current_Row := Current_Row + 1;
            goto End_Of_Loop;
         end if;
         CanCraft := False;
         Has_Workplace := False;
         Recipe := Recipes_List(Known_Recipes(I));
         Find_Workshop_Loop :
         for Module of Player_Ship.Modules loop
            if Modules_List(Module.Proto_Index).MType = Recipe.Workplace
              and then Module.Durability > 0 then
               Has_Workplace := True;
               exit Find_Workshop_Loop;
            end if;
         end loop Find_Workshop_Loop;
         CheckTool(Recipe.Tool);
         declare
            Materials: array
              (Recipe.MaterialTypes.First_Index ..
                   Recipe.MaterialTypes.Last_Index) of Boolean :=
              (others => False);
         begin
            Find_Materials_Loop :
            for K in
              Recipe.MaterialTypes.First_Index ..
                Recipe.MaterialTypes.Last_Index loop
               Find_Cargo_Index_Loop :
               for J in Items_List.Iterate loop
                  if Items_List(J).IType = Recipe.MaterialTypes(K) then
                     CargoIndex :=
                       FindItem(Player_Ship.Cargo, Objects_Container.Key(J));
                     if CargoIndex > 0
                       and then Player_Ship.Cargo(CargoIndex).Amount >=
                         Recipe.MaterialAmounts(K) then
                        Materials(K) := True;
                     end if;
                  end if;
               end loop Find_Cargo_Index_Loop;
            end loop Find_Materials_Loop;
            Has_Materials := True;
            Set_Can_Craft_Loop :
            for J in Materials'Range loop
               if not Materials(J) then
                  Has_Materials := False;
                  exit Set_Can_Craft_Loop;
               end if;
            end loop Set_Can_Craft_Loop;
         end;
         if Has_Tool and Has_Materials and Has_Workplace then
            CanCraft := True;
         end if;
         AddButton
           (RecipesTable,
            To_String
              (Items_List(Recipes_List(Known_Recipes(I)).ResultIndex).Name),
            "Show available recipe's options",
            "ShowRecipeMenu {" & To_String(Known_Recipes(I)) & "} " &
            Boolean'Image(CanCraft),
            1);
         AddCheckButton
           (RecipesTable, "Show available recipe's options",
            "ShowRecipeMenu {" & To_String(Known_Recipes(I)) & "} " &
            Boolean'Image(CanCraft),
            CanCraft, 2);
         AddCheckButton
           (RecipesTable, "Show available recipe's options",
            "ShowRecipeMenu {" & To_String(Known_Recipes(I)) & "} " &
            Boolean'Image(CanCraft),
            Has_Workplace, 3);
         AddCheckButton
           (RecipesTable, "Show available recipe's options",
            "ShowRecipeMenu {" & To_String(Known_Recipes(I)) & "} " &
            Boolean'Image(CanCraft),
            Has_Tool, 4);
         AddCheckButton
           (RecipesTable, "Show available recipe's options",
            "ShowRecipeMenu {" & To_String(Known_Recipes(I)) & "} " &
            Boolean'Image(CanCraft),
            Has_Materials, 5, True);
         exit Show_Recipes_Loop when RecipesTable.Row = 26;
         <<End_Of_Loop>>
      end loop Show_Recipes_Loop;
      CheckTool(Alchemy_Tools);
      CanCraft := False;
      Has_Workplace := False;
      Find_Alchemy_Lab_Loop :
      for Module of Player_Ship.Modules loop
         if Modules_List(Module.Proto_Index).MType = ALCHEMY_LAB
           and then Module.Durability > 0 then
            Has_Workplace := True;
            exit Find_Alchemy_Lab_Loop;
         end if;
      end loop Find_Alchemy_Lab_Loop;
      if Has_Workplace then
         CanCraft := True;
      end if;
      Set_Study_Recipes_Loop :
      for I in Studies.Iterate loop
         exit Set_Study_Recipes_Loop when RecipesTable.Row = 26;
         if RecipeName'Length > 0
           and then
             Index
               (To_Lower("Study " & To_String(Items_List(Studies(I)).Name)),
                To_Lower(RecipeName), 1) =
             0 then
            goto End_Of_Study_Loop;
         end if;
         if Current_Row < Start_Row then
            Current_Row := Current_Row + 1;
            goto End_Of_Study_Loop;
         end if;
         AddButton
           (RecipesTable, "Study " & To_String(Items_List(Studies(I)).Name),
            "Show available recipe's options",
            "ShowRecipeMenu {Study " & To_String(Studies(I)) & "} " &
            Boolean'Image(CanCraft),
            1);
         AddCheckButton
           (RecipesTable, "Show available recipe's options",
            "ShowRecipeMenu {Study " & To_String(Studies(I)) & "} " &
            Boolean'Image(CanCraft),
            CanCraft, 2);
         AddCheckButton
           (RecipesTable, "Show available recipe's options",
            "ShowRecipeMenu {Study " & To_String(Studies(I)) & "} " &
            Boolean'Image(CanCraft),
            Has_Workplace, 3);
         AddCheckButton
           (RecipesTable, "Show available recipe's options",
            "ShowRecipeMenu {Study " & To_String(Studies(I)) & "} " &
            Boolean'Image(CanCraft),
            Has_Tool, 4, True);
         <<End_Of_Study_Loop>>
      end loop Set_Study_Recipes_Loop;
      Set_Deconstruct_Recipes_Loop :
      for I in Deconstructs.Iterate loop
         exit Set_Deconstruct_Recipes_Loop when RecipesTable.Row = 26;
         if RecipeName'Length > 0
           and then
             Index
               (To_Lower
                  ("Deconstruct " &
                   To_String(Items_List(Deconstructs(I)).Name)),
                To_Lower(RecipeName), 1) =
             0 then
            goto End_Of_Deconstruct_Loop;
         end if;
         if Current_Row < Start_Row then
            Current_Row := Current_Row + 1;
            goto End_Of_Deconstruct_Loop;
         end if;
         AddButton
           (RecipesTable,
            "Decontruct " & To_String(Items_List(Deconstructs(I)).Name),
            "Show available recipe's options",
            "ShowRecipeMenu {Deconstruct " & To_String(Deconstructs(I)) &
            "} " & Boolean'Image(CanCraft),
            1);
         AddCheckButton
           (RecipesTable, "Show available recipe's options",
            "ShowRecipeMenu {Deconstruct " & To_String(Deconstructs(I)) &
            "} " & Boolean'Image(CanCraft),
            CanCraft, 2);
         AddCheckButton
           (RecipesTable, "Show available recipe's options",
            "ShowRecipeMenu {Deconstruct " & To_String(Deconstructs(I)) &
            "} " & Boolean'Image(CanCraft),
            Has_Workplace, 3);
         AddCheckButton
           (RecipesTable, "Show available recipe's options",
            "ShowRecipeMenu {Deconstruct " & To_String(Deconstructs(I)) &
            "} " & Boolean'Image(CanCraft),
            Has_Tool, 4, True);
         <<End_Of_Deconstruct_Loop>>
      end loop Set_Deconstruct_Recipes_Loop;
      Tcl.Tk.Ada.Grid.Grid(Close_Button, "-row 0 -column 1");
      if Page > 1 then
         if RecipesTable.Row < 26 then
            AddPagination
              (RecipesTable,
               "ShowCrafting" & Positive'Image(Page - 1) &
               (if RecipeName'Length > 0 then " {" & RecipeName & "}" else ""),
               "");
         else
            AddPagination
              (RecipesTable,
               "ShowCrafting" & Positive'Image(Page - 1) &
               (if RecipeName'Length > 0 then " {" & RecipeName & "}" else ""),
               "ShowCrafting" & Positive'Image(Page + 1) &
               (if RecipeName'Length > 0 then " {" & RecipeName & "}"
                else ""));
         end if;
      elsif RecipesTable.Row = 26 then
         AddPagination
           (RecipesTable, "",
            "ShowCrafting" & Positive'Image(Page + 1) &
            (if RecipeName'Length > 0 then " {" & RecipeName & "}" else ""));
      end if;
      UpdateTable(RecipesTable);
      CraftsFrame.Name := New_String(Widget_Image(CraftsCanvas) & ".craft");
      configure
        (CraftsCanvas,
         "-height [expr " & SashPos(Main_Paned, "0") & " - 20] -width " &
         cget(Main_Paned, "-width"));
      Tcl_Eval(Get_Context, "update");
      Canvas_Create
        (CraftsCanvas, "window",
         "0 0 -anchor nw -window " & Widget_Image(CraftsFrame));
      Tcl_Eval(Get_Context, "update");
      configure
        (CraftsCanvas,
         "-scrollregion [list " & BBox(CraftsCanvas, "all") & "]");
      ShowScreen("craftframe");
      Tcl_SetResult(Interp, "1");
      return TCL_OK;
   end Show_Crafting_Command;

   -- ****o* CUI4/CUI4.Show_Recipe_Menu_Command
   -- FUNCTION
   -- Show menu with available actions for the selected recipe
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowRecipeMenu index craftable
   -- Index is the index of the recipe to craft. If craftable is TRUE,
   -- then the recipe can be crafted, otherwise FALSE
   -- SOURCE
   function Show_Recipe_Menu_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Recipe_Menu_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      RecipeMenu: Tk_Menu := Get_Widget(".recipemenu", Interp);
   begin
      if Winfo_Get(RecipeMenu, "exists") = "0" then
         RecipeMenu := Create(".recipemenu", "-tearoff false");
      end if;
      Delete(RecipeMenu, "0", "end");
      if CArgv.Arg(Argv, 2) = "TRUE" then
         Menu.Add
           (RecipeMenu, "command",
            "-label {Set crafting order} -command {ShowSetRecipe {" &
            CArgv.Arg(Argv, 1) & "}}");
      end if;
      Menu.Add
        (RecipeMenu, "command",
         "-label {Show more info about the recipe} -command {ShowRecipeInfo {" &
         CArgv.Arg(Argv, 1) & "} " & CArgv.Arg(Argv, 2) & "}");
      Tk_Popup
        (RecipeMenu, Winfo_Get(Get_Main_Window(Interp), "pointerx"),
         Winfo_Get(Get_Main_Window(Interp), "pointery"));
      return TCL_OK;
   end Show_Recipe_Menu_Command;

   -- ****o* CUI4/CUI4.Show_Set_Recipe_Command
   -- FUNCTION
   -- Show dialog to set the selected recipe as crafting order
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed. Unused
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- SetRecipe index
   -- Index is the index of the recipe to craft.
   -- SOURCE
   function Show_Set_Recipe_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Set_Recipe_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Interp, Argc);
      MType: ModuleType;
      ModulesList: Unbounded_String;
      RecipeIndex: constant Unbounded_String :=
        To_Unbounded_String(CArgv.Arg(Argv, 1));
      RecipeLength: constant Positive := Length(RecipeIndex);
      RecipeType: constant String :=
        (if RecipeLength > 6 and then Slice(RecipeIndex, 1, 5) = "Study" then
           "Study"
         elsif RecipeLength > 6 and then Slice(RecipeIndex, 1, 5) = "Decon"
         then "Deconstruct"
         else "Craft");
      CraftDialog: constant Ttk_Frame :=
        Create_Dialog
          (".craftdialog",
           (if RecipeType = "Study" then
              "Study " &
              To_String
                (Items_List(Unbounded_Slice(RecipeIndex, 7, RecipeLength))
                   .Name)
            elsif RecipeType = "Deconstruct" then
              "Deconstruct " &
              To_String
                (Items_List(Unbounded_Slice(RecipeIndex, 13, RecipeLength))
                   .Name)
            else "Craft " &
              To_String
                (Items_List(Recipes_List(RecipeIndex).ResultIndex).Name)),
           275, 2);
      MaxAmount: constant Positive := CheckRecipe(RecipeIndex);
      Label: Ttk_Label :=
        Create(CraftDialog & ".amountlabel", "-text {Amount:}");
      ModulesBox: constant Ttk_ComboBox :=
        Create(CraftDialog & ".workshop", "-state readonly");
      AmountBox: constant Ttk_SpinBox :=
        Create
          (CraftDialog & ".amount",
           "-to" & Positive'Image(MaxAmount) &
           " -validatecommand {ValidateSpinbox %W %P} -width 20");
      Button: Ttk_Button :=
        Create
          (CraftDialog & ".maxamount",
           "-text {max" & Positive'Image(MaxAmount) & "} -command {" &
           AmountBox & " set" & Positive'Image(MaxAmount) & "}");
      ButtonRow: Positive := 1;
   begin
      Set(AmountBox, "1");
      if RecipeType /= "Study" then
         if MaxAmount > 1 then
            Tcl.Tk.Ada.Grid.Grid(Label);
            Tcl.Tk.Ada.Grid.Grid(Button, "-row 1 -column 1 -padx {0 5}");
         else
            Tcl.Tk.Ada.Grid.Grid(Label, "-columnspan 2");
         end if;
         Tcl.Tk.Ada.Grid.Grid(AmountBox, "-columnspan 2 -padx 5");
         ButtonRow := ButtonRow + 2;
      end if;
      if RecipeType in "Study" | "Deconstruct" then
         MType := ALCHEMY_LAB;
      else
         MType := Recipes_List(RecipeIndex).Workplace;
      end if;
      Show_Workshops_List_Loop :
      for Module of Player_Ship.Modules loop
         if Modules_List(Module.Proto_Index).MType = MType then
            Append(ModulesList, " {" & Module.Name & "}");
         end if;
      end loop Show_Workshops_List_Loop;
      configure(ModulesBox, "-values [list" & To_String(ModulesList) & "]");
      Current(ModulesBox, "0");
      if RecipeType = "Craft" then
         Label := Create(CraftDialog & ".workshoplabel", "-text {Wokshop:}");
         Tcl.Tk.Ada.Grid.Grid(Label, "-columnspan 2 -padx 5");
         Tcl.Tk.Ada.Grid.Grid(ModulesBox, "-columnspan 2 -padx 5");
         ButtonRow := ButtonRow + 2;
      end if;
      Button :=
        Create
          (CraftDialog & ".craft",
           "-text {Craft} -command {SetCrafting {" & CArgv.Arg(Argv, 1) &
           "};CloseDialog " & CraftDialog & "}");
      Tcl.Tk.Ada.Grid.Grid(Button, "-pady 5 -padx 5");
      Button :=
        Create
          (CraftDialog & ".cancel",
           "-text {Cancel} -command {CloseDialog " & CraftDialog & "}");
      Tcl.Tk.Ada.Grid.Grid
        (Button, "-pady 5 -padx 5 -column 1 -row" & Positive'Image(ButtonRow));
      Show_Dialog(CraftDialog);
      return TCL_OK;
   end Show_Set_Recipe_Command;

   -- ****o* CUI4/CUI4.Show_Recipe_Info_Command
   -- FUNCTION
   -- Show information about the selected recipe
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowRecipeInfo index cancraft
   -- Index is the index of the crafting recipe to show, cancraft if TRUE
   -- then recipe can be crafted (show craft button)
   -- SOURCE
   function Show_Recipe_Info_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Recipe_Info_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      RecipeIndex: constant Unbounded_String :=
        To_Unbounded_String(CArgv.Arg(Argv, 1));
      RecipeDialog: constant Ttk_Frame :=
        Create_Dialog(".recipedialog", "Recipe info");
      WorkplaceName: Unbounded_String := Null_Unbounded_String;
      Recipe: Craft_Data;
      MAmount, CargoIndex: Natural := 0;
      HaveWorkplace, IsMaterial: Boolean := True;
      HaveTool: Boolean := False;
      TextLength: Positive;
      RecipeText: constant Tk_Text :=
        Create
          (RecipeDialog & ".text", "-wrap char -height 15 -width 40", Interp);
   begin
      Tag_Configure(RecipeText, "red", "-foreground red");
      if Length(RecipeIndex) > 6
        and then Slice(RecipeIndex, 1, 5) = "Study" then
         Recipe.MaterialTypes.Append
           (New_Item =>
              Items_List(Unbounded_Slice(RecipeIndex, 7, Length(RecipeIndex)))
                .IType);
         Recipe.ResultIndex :=
           Unbounded_Slice(RecipeIndex, 7, Length(RecipeIndex));
         Recipe.MaterialAmounts.Append(New_Item => 1);
         Recipe.ResultAmount := 0;
         Recipe.Workplace := ALCHEMY_LAB;
         Set_Study_Recipe_Loop :
         for ProtoRecipe of Recipes_List loop
            if ProtoRecipe.ResultIndex = Recipe.ResultIndex then
               Recipe.Skill := ProtoRecipe.Skill;
               Recipe.Time := ProtoRecipe.Difficulty * 15;
               exit Set_Study_Recipe_Loop;
            end if;
         end loop Set_Study_Recipe_Loop;
         Recipe.Difficulty := 1;
         Recipe.Tool := Alchemy_Tools;
         Recipe.ToolQuality := 100;
      elsif Length(RecipeIndex) > 12
        and then Slice(RecipeIndex, 1, 11) = "Deconstruct" then
         Recipe.MaterialTypes.Append
           (New_Item =>
              Items_List(Unbounded_Slice(RecipeIndex, 13, Length(RecipeIndex)))
                .IType);
         Recipe.ResultIndex :=
           Unbounded_Slice(RecipeIndex, 13, Length(RecipeIndex));
         Recipe.MaterialAmounts.Append(New_Item => 1);
         Recipe.ResultAmount := 0;
         Recipe.Workplace := ALCHEMY_LAB;
         Set_Deconstruct_Recipe_Loop :
         for ProtoRecipe of Recipes_List loop
            if ProtoRecipe.ResultIndex = Recipe.ResultIndex then
               Recipe.Skill := ProtoRecipe.Skill;
               Recipe.Time := ProtoRecipe.Difficulty * 15;
               Recipe.Difficulty := ProtoRecipe.Difficulty;
               Recipe.ResultIndex :=
                 FindProtoItem(ProtoRecipe.MaterialTypes(1));
               Recipe.ResultAmount :=
                 Positive
                   (Float'Ceiling
                      (Float(ProtoRecipe.MaterialAmounts.Element(1)) * 0.8));
               exit Set_Deconstruct_Recipe_Loop;
            end if;
         end loop Set_Deconstruct_Recipe_Loop;
         Recipe.Tool := Alchemy_Tools;
         Recipe.ToolQuality := 100;
      else
         Recipe := Recipes_List(RecipeIndex);
         Insert
           (RecipeText, "end",
            "{Amount:" & Integer'Image(Recipe.ResultAmount) & LF & "}");
      end if;
      Insert(RecipeText, "end", "{Materials needed: }");
      Check_Materials_Loop :
      for I in
        Recipe.MaterialTypes.First_Index ..
          Recipe.MaterialTypes.Last_Index loop
         Insert(RecipeText, "end", "{" & LF & "-}");
         MAmount := 0;
         Find_Materials_Loop :
         for J in Items_List.Iterate loop
            IsMaterial := False;
            if Length(RecipeIndex) > 6
              and then Slice(RecipeIndex, 1, 5) = "Study" then
               if Items_List(J).Name = Items_List(Recipe.ResultIndex).Name then
                  IsMaterial := True;
               end if;
            elsif Length(RecipeIndex) > 12
              and then Slice(RecipeIndex, 1, 11) = "Deconstruct" then
               if Objects_Container.Key(J) =
                 Unbounded_Slice(RecipeIndex, 13, Length(RecipeIndex)) then
                  IsMaterial := True;
               end if;
            else
               if Items_List(J).IType = Recipe.MaterialTypes(I) then
                  IsMaterial := True;
               end if;
            end if;
            if IsMaterial then
               if MAmount > 0 then
                  Insert(RecipeText, "end", "{ or}");
               end if;
               CargoIndex :=
                 FindItem(Player_Ship.Cargo, Objects_Container.Key(J));
               if CargoIndex > 0
                 and then Player_Ship.Cargo(CargoIndex).Amount >=
                   Recipe.MaterialAmounts(I) then
                  TextLength :=
                    Positive'Image(Player_Ship.Cargo(CargoIndex).Amount)'
                      Length;
                  Insert
                    (RecipeText, "end",
                     "{" & Integer'Image(Recipe.MaterialAmounts(I)) & "x" &
                     To_String(Items_List(J).Name) & "(owned: " &
                     Positive'Image(Player_Ship.Cargo(CargoIndex).Amount)
                       (2 .. TextLength) &
                     ")}");
               else
                  Insert
                    (RecipeText, "end",
                     "{" & Integer'Image(Recipe.MaterialAmounts(I)) & "x" &
                     To_String(Items_List(J).Name) & "} [list red]");
               end if;
               MAmount := MAmount + 1;
            end if;
         end loop Find_Materials_Loop;
      end loop Check_Materials_Loop;
      if Recipe.Tool /= To_Unbounded_String("None") then
         Insert(RecipeText, "end", "{" & LF & "Tool: }");
         MAmount := 0;
         Check_Tool_Loop :
         for I in Items_List.Iterate loop
            if Items_List(I).IType = Recipe.Tool
              and then
              (Items_List(I).Value.Length > 0
               and then Items_List(I).Value(1) <= Recipe.ToolQuality) then
               if MAmount > 0 then
                  Insert(RecipeText, "end", "{ or }");
               end if;
               CargoIndex :=
                 FindItem
                   (Inventory => Player_Ship.Cargo,
                    ProtoIndex => Objects_Container.Key(I),
                    Quality => Recipe.ToolQuality);
               if CargoIndex > 0 then
                  HaveTool := True;
               end if;
               Insert
                 (RecipeText, "end",
                  "{" & To_String(Items_List(I).Name) & "}" &
                  (if not HaveTool then " [list red]" else ""));
               MAmount := MAmount + 1;
            end if;
         end loop Check_Tool_Loop;
      else
         HaveTool := True;
      end if;
      Insert(RecipeText, "end", "{" & LF & "Workplace: }");
      HaveWorkplace := False;
      Have_Workplace_Loop :
      for Module of Player_Ship.Modules loop
         if Modules_List(Module.Proto_Index).MType = Recipe.Workplace then
            WorkplaceName := Module.Name;
            if Module.Durability > 0 then
               HaveWorkplace := True;
               exit Have_Workplace_Loop;
            end if;
         end if;
      end loop Have_Workplace_Loop;
      if WorkplaceName = Null_Unbounded_String then
         Find_Workshop_Name_Loop :
         for I in Modules_List.Iterate loop
            if Modules_List(I).MType = Recipe.Workplace then
               WorkplaceName :=
                 To_Unbounded_String
                   (GetModuleType(BaseModules_Container.Key(I)));
               exit Find_Workshop_Name_Loop;
            end if;
         end loop Find_Workshop_Name_Loop;
      end if;
      Insert
        (RecipeText, "end",
         "{" & To_String(WorkplaceName) & "}" &
         (if not HaveWorkplace then " [list red]" else ""));
      Insert
        (RecipeText, "end",
         "{" & LF & "Skill: " & To_String(Skills_List(Recipe.Skill).Name) &
         "/" &
         To_String(Attributes_List(Skills_List(Recipe.Skill).Attribute).Name) &
         LF & "Time needed:" & Positive'Image(Recipe.Time) & " minutes}");
      configure(RecipeText, "-state disabled");
      Tcl.Tk.Ada.Grid.Grid(RecipeText, "-padx 5");
      if CArgv.Arg(Argv, 2) = "TRUE" then
         declare
            ButtonBox: constant Ttk_Frame := Create(RecipeDialog & ".buttons");
            Button: Ttk_Button;
         begin
            Button :=
              Create
                (ButtonBox & ".craft",
                 "-text Craft -command {ShowSetRecipe {" & CArgv.Arg(Argv, 1) &
                 "};CloseDialog " & RecipeDialog & "}");
            Tcl.Tk.Ada.Grid.Grid(Button);
            Button :=
              Create
                (ButtonBox & ".close",
                 "-text Close -command {CloseDialog " & RecipeDialog & "}");
            Tcl.Tk.Ada.Grid.Grid(Button, "-row 0 -column 1 -padx {5 0}");
            Focus(Button);
            Bind(Button, "<Tab>", "{focus " & ButtonBox & ".craft;break}");
            Bind(Button, "<Escape>", "{" & Button & " invoke;break}");
            Tcl.Tk.Ada.Grid.Grid(ButtonBox, "-pady 5");
         end;
      else
         Add_Close_Button
           (RecipeDialog & ".close", "Close", "CloseDialog " & RecipeDialog);
      end if;
      Show_Dialog
        (Dialog => RecipeDialog, Relative_X => 0.2, Relative_Y => 0.1);
      return TCL_OK;
   end Show_Recipe_Info_Command;

   -- ****o* CUI4/CUI4.Set_Crafting_Command
   -- FUNCTION
   -- Set the selected recipe as a crafting order in the selected workshop
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- SetCrafting index
   -- Index is the index of the crafting recipe to set
   -- SOURCE
   function Set_Crafting_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Set_Crafting_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      RecipeIndex: Unbounded_String := To_Unbounded_String(CArgv.Arg(Argv, 1));
      ModulesBox: constant Ttk_ComboBox := Get_Widget(".craftdialog.workshop");
      AmountBox: constant Ttk_SpinBox :=
        Get_Widget(".craftdialog.amount", Interp);
   begin
      if Element(RecipeIndex, 1) = '{' then
         RecipeIndex :=
           Unbounded_Slice(RecipeIndex, 2, Length(RecipeIndex) - 1);
      end if;
      Set_Module_Loop :
      for I in Player_Ship.Modules.Iterate loop
         if Player_Ship.Modules(I).Name =
           To_Unbounded_String(Get(ModulesBox)) then
            SetRecipe
              (Modules_Container.To_Index(I), Positive'Value(Get(AmountBox)),
               RecipeIndex);
            UpdateMessages;
            exit Set_Module_Loop;
         end if;
      end loop Set_Module_Loop;
      return TCL_OK;
   end Set_Crafting_Command;

   -- ****it* CUI4/CUI4.Recipes_Sort_Orders
   -- FUNCTION
   -- Sorting orders for the crafting recipes list
   -- OPTIONS
   -- NAMEASC    - Sort recipes by name ascending
   -- NAMEDESC   - Sort recipes by name descending
   -- NONE       - No sorting recipes (default)
   -- HISTORY
   -- 6.4 - Added
   -- SOURCE
   type Recipes_Sort_Orders is (NAMEASC, NAMEDESC, NONE) with
      Default_Value => NONE;
      -- ****

      -- ****id* CUI4/CUI4.Default_Recipes_Sort_Order
      -- FUNCTION
      -- Default sorting order for the crafting recipes
      -- HISTORY
      -- 6.4 - Added
      -- SOURCE
   Default_Recipes_Sort_Order: constant Recipes_Sort_Orders := NONE;
   -- ****

   -- ****iv* CUI4/CUI4.Recipes_Sort_Order
   -- FUNCTION
   -- The current sorting order for crafting recipes list
   -- HISTORY
   -- 6.4 - Added
   -- SOURCE
   Recipes_Sort_Order: Recipes_Sort_Orders := Default_Recipes_Sort_Order;
   -- ****

   -- ****o* CUI4/CUI4.Sort_Crafting_Command
   -- FUNCTION
   -- Sort the list of crafting recipes
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed. Unused
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- SortCrafting x
   -- X is X axis coordinate where the player clicked the mouse button
   -- SOURCE
   function Sort_Crafting_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

   function Sort_Crafting_Command
     (ClientData: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int is
      pragma Unreferenced(ClientData, Interp, Argc);
      Column: constant Positive :=
        Get_Column_Number(RecipesTable, Natural'Value(CArgv.Arg(Argv, 1)));
      type Local_Module_Data is record
         Name: Unbounded_String;
         Id: Unbounded_String;
      end record;
      type Recipes_Array is array(Positive range <>) of Local_Module_Data;
      Local_Recipes: Recipes_Array
        (1 ..
             Positive(Known_Recipes.Length) + Positive(Studies.Length) +
             Positive(Deconstructs.Length));
      function "<"(Left, Right: Local_Module_Data) return Boolean is
      begin
         if Recipes_Sort_Order = NAMEASC and then Left.Name < Right.Name then
            return True;
         end if;
         if Recipes_Sort_Order = NAMEDESC and then Left.Name > Right.Name then
            return True;
         end if;
         return False;
      end "<";
      procedure Sort_Recipes is new Ada.Containers.Generic_Array_Sort
        (Index_Type => Positive, Element_Type => Local_Module_Data,
         Array_Type => Recipes_Array);
   begin
      case Column is
         when 1 =>
            if Recipes_Sort_Order = NAMEASC then
               Recipes_Sort_Order := NAMEDESC;
            else
               Recipes_Sort_Order := NAMEASC;
            end if;
         when others =>
            null;
      end case;
      if Recipes_Sort_Order = NONE then
         return TCL_OK;
      end if;
      for I in Known_Recipes.Iterate loop
         Local_Recipes(UnboundedString_Container.To_Index(I)) :=
           (Name =>
              Items_List(Recipes_List(Known_Recipes(I)).ResultIndex).Name,
            Id =>
              To_Unbounded_String
                (Trim
                   (Positive'Image
                      (Positive(UnboundedString_Container.To_Index(I))),
                    Left)));
      end loop;
      for I in Studies.Iterate loop
         Local_Recipes
           (UnboundedString_Container.To_Index(I) +
            Positive(Known_Recipes.Length)) :=
           (Name => "Study " & Items_List(Studies(I)).Name,
            Id =>
              To_Unbounded_String
                (Trim
                   (Positive'Image
                      (Positive(UnboundedString_Container.To_Index(I))),
                    Left)));
      end loop;
      for I in Deconstructs.Iterate loop
         Local_Recipes
           (UnboundedString_Container.To_Index(I) +
            Positive(Known_Recipes.Length) + Positive(Studies.Length)) :=
           (Name => "Deconstruct " & Items_List(Deconstructs(I)).Name,
            Id =>
              To_Unbounded_String
                (Trim
                   (Positive'Image
                      (Positive(UnboundedString_Container.To_Index(I))),
                    Left)));
      end loop;
      Sort_Recipes(Local_Recipes);
      Recipes_Indexes.Clear;
      for Recipe of Local_Recipes loop
         Recipes_Indexes.Append(Recipe.Id);
      end loop;
      return TCL_OK;
   end Sort_Crafting_Command;

   procedure AddCommands is
   begin
      AddCommand("ShowCrafting", Show_Crafting_Command'Access);
      AddCommand("ShowRecipeMenu", Show_Recipe_Menu_Command'Access);
      AddCommand("ShowSetRecipe", Show_Set_Recipe_Command'Access);
      AddCommand("ShowRecipeInfo", Show_Recipe_Info_Command'Access);
      AddCommand("SetCrafting", Set_Crafting_Command'Access);
      AddCommand("SortCrafting", Sort_Crafting_Command'Access);
   end AddCommands;

end Crafts.UI;
