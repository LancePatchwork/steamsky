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

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Containers; use Ada.Containers;
with Ada.Directories; use Ada.Directories;
with Gtk.Widget; use Gtk.Widget;
with Gtk.Switch; use Gtk.Switch;
with Gtk.Combo_Box; use Gtk.Combo_Box;
with Gtk.Adjustment; use Gtk.Adjustment;
with Gtk.GEntry; use Gtk.GEntry;
with Gtk.Accel_Map; use Gtk.Accel_Map;
with Gtk.Accel_Group; use Gtk.Accel_Group;
with Gtk.Window; use Gtk.Window;
with Gtk.Stack; use Gtk.Stack;
with Gtk.Settings; use Gtk.Settings;
with Gtk.Label; use Gtk.Label;
with Gtk.Combo_Box_Text; use Gtk.Combo_Box_Text;
with Glib; use Glib;
with Glib.Object; use Glib.Object;
with Gdk.Event;
with Gdk.Types; use Gdk.Types;
with Game; use Game;
with Maps.UI; use Maps.UI;
with Config; use Config;
with Ships; use Ships;
with Utils.UI; use Utils.UI;
with Messages; use Messages;
with Themes; use Themes;

package body GameOptions is

   Builder: Gtkada_Builder;
   AccelNames: constant array(Positive range <>) of Unbounded_String :=
     (To_Unbounded_String("<skymapwindow>/btnupleft"),
      To_Unbounded_String("<skymapwindow>/btnup"),
      To_Unbounded_String("<skymapwindow>/btnupright"),
      To_Unbounded_String("<skymapwindow>/btnleft"),
      To_Unbounded_String("<skymapwindow>/btnmovewait"),
      To_Unbounded_String("<skymapwindow>/btnright"),
      To_Unbounded_String("<skymapwindow>/btnbottomleft"),
      To_Unbounded_String("<skymapwindow>/btnbottom"),
      To_Unbounded_String("<skymapwindow>/btnbottomright"),
      To_Unbounded_String("<skymapwindow>/btnmoveto"),
      To_Unbounded_String("<skymapwindow>/Menu/ShipInfo"),
      To_Unbounded_String("<skymapwindow>/Menu/ShipCargoInfo"),
      To_Unbounded_String("<skymapwindow>/Menu/CrewInfo"),
      To_Unbounded_String("<skymapwindow>/Menu/ShipOrders"),
      To_Unbounded_String("<skymapwindow>/Menu/CraftInfo"),
      To_Unbounded_String("<skymapwindow>/Menu/MessagesInfo"),
      To_Unbounded_String("<skymapwindow>/Menu/BasesInfo"),
      To_Unbounded_String("<skymapwindow>/Menu/EventsInfo"),
      To_Unbounded_String("<skymapwindow>/Menu/MissionsInfo"),
      To_Unbounded_String("<skymapwindow>/Menu/MoveMap"),
      To_Unbounded_String("<skymapwindow>/Menu/GameStats"),
      To_Unbounded_String("<skymapwindow>/Menu/Help"),
      To_Unbounded_String("<skymapwindow>/Menu/GameOptions"),
      To_Unbounded_String("<skymapwindow>/Menu/QuitGame"),
      To_Unbounded_String("<skymapwindow>/Menu/ResignFromGame"),
      To_Unbounded_String("<skymapwindow>/Menu"),
      To_Unbounded_String("<skymapwindow>/Menu/WaitOrders"),
      To_Unbounded_String("<movemapwindow>/btncenter"),
      To_Unbounded_String("<skymapwindow>/btnmapleft"),
      To_Unbounded_String("<skymapwindow>/btnmapright"),
      To_Unbounded_String("<skymapwindow>/btnmapup"),
      To_Unbounded_String("<skymapwindow>/btnmapdown"),
      To_Unbounded_String("<skymapwindow>/cursorupleft"),
      To_Unbounded_String("<skymapwindow>/cursorup"),
      To_Unbounded_String("<skymapwindow>/cursorupright"),
      To_Unbounded_String("<skymapwindow>/cursorleft"),
      To_Unbounded_String("<skymapwindow>/cursorright"),
      To_Unbounded_String("<skymapwindow>/cursordownleft"),
      To_Unbounded_String("<skymapwindow>/cursordown"),
      To_Unbounded_String("<skymapwindow>/cursordownright"),
      To_Unbounded_String("<skymapwindow>/mouseclick"),
      To_Unbounded_String("<skymapwindow>/Menu/Stories"),
      To_Unbounded_String("<skymapwindow>/zoomin"),
      To_Unbounded_String("<skymapwindow>/zoomout"));
   EditNames: constant array(AccelNames'Range) of Unbounded_String :=
     (To_Unbounded_String("edtupleft"), To_Unbounded_String("edtup"),
      To_Unbounded_String("edtupright"), To_Unbounded_String("edtleft"),
      To_Unbounded_String("edtmovewait"), To_Unbounded_String("edtright"),
      To_Unbounded_String("edtdownleft"), To_Unbounded_String("edtdown"),
      To_Unbounded_String("edtdownright"), To_Unbounded_String("edtmoveto"),
      To_Unbounded_String("edtshipinfo"), To_Unbounded_String("edtcargo"),
      To_Unbounded_String("edtcrew"), To_Unbounded_String("edtorders"),
      To_Unbounded_String("edtcrafts"), To_Unbounded_String("edtmessages"),
      To_Unbounded_String("edtbases"), To_Unbounded_String("edtevents"),
      To_Unbounded_String("edtmissions"), To_Unbounded_String("edtmap"),
      To_Unbounded_String("edtgamestats"), To_Unbounded_String("edthelp"),
      To_Unbounded_String("edtgameoptions"), To_Unbounded_String("edtquit"),
      To_Unbounded_String("edtresign"), To_Unbounded_String("edtmenu"),
      To_Unbounded_String("edtwaitorders"),
      To_Unbounded_String("edtcentermap"),
      To_Unbounded_String("edtmovemapleft"),
      To_Unbounded_String("edtmovemapright"),
      To_Unbounded_String("edtmovemapup"),
      To_Unbounded_String("edtmovemapdown"),
      To_Unbounded_String("edtmovecursorupleft"),
      To_Unbounded_String("edtmovecursorup"),
      To_Unbounded_String("edtmovecursorupright"),
      To_Unbounded_String("edtmovecursorleft"),
      To_Unbounded_String("edtmovecursorright"),
      To_Unbounded_String("edtmovecursordownleft"),
      To_Unbounded_String("edtmovecursordown"),
      To_Unbounded_String("edtmovecursordownright"),
      To_Unbounded_String("edtclickmouse"), To_Unbounded_String("edtstories"),
      To_Unbounded_String("edtzoomin"), To_Unbounded_String("edtzoomout"));

   procedure CloseOptions(Object: access Gtkada_Builder_Record'Class) is
   begin
      GameSettings.AutoRest :=
        Get_State(Gtk_Switch(Get_Object(Object, "switchautorest")));
      GameSettings.UndockSpeed :=
        ShipSpeed'Val
          (Get_Active(Gtk_Combo_Box(Get_Object(Object, "cmbspeed1"))) + 1);
      GameSettings.AutoCenter :=
        Get_State(Gtk_Switch(Get_Object(Object, "switchautocenter")));
      GameSettings.AutoReturn :=
        Get_State(Gtk_Switch(Get_Object(Object, "switchautoreturn")));
      GameSettings.AutoFinish :=
        Get_State(Gtk_Switch(Get_Object(Object, "switchautofinish")));
      GameSettings.LowFuel :=
        Positive(Get_Value(Gtk_Adjustment(Get_Object(Object, "adjfuel"))));
      GameSettings.LowDrinks :=
        Positive(Get_Value(Gtk_Adjustment(Get_Object(Object, "adjdrinks"))));
      GameSettings.LowFood :=
        Positive(Get_Value(Gtk_Adjustment(Get_Object(Object, "adjfood"))));
      GameSettings.AutoMoveStop :=
        AutoMoveBreak'Val
          (Get_Active(Gtk_Combo_Box(Get_Object(Object, "cmbautomovestop"))));
      if Get_State(Gtk_Switch(Get_Object(Object, "switchanimations"))) then
         GameSettings.AnimationsEnabled := 1;
      else
         GameSettings.AnimationsEnabled := 0;
      end if;
      Set_Long_Property
        (Get_Default, "gtk-enable-animations",
         Glong(GameSettings.AnimationsEnabled), "");
      GameSettings.AnimationType :=
        Positive
          (Get_Active(Gtk_Combo_Box(Get_Object(Object, "cmbanimations"))) + 1);
      Set_Transition_Type
        (Gtk_Stack(Get_Object(Builder, "gamestack")),
         Gtk_Stack_Transition_Type'Val(GameSettings.AnimationType));
      Set_Transition_Type
        (Gtk_Stack(Get_Object(Builder, "shipyardstack")),
         Gtk_Stack_Transition_Type'Val(GameSettings.AnimationType));
      Set_Transition_Type
        (Gtk_Stack(Get_Object(Builder, "optionsstack")),
         Gtk_Stack_Transition_Type'Val(GameSettings.AnimationType));
      Set_Transition_Type
        (Gtk_Stack(Get_Object(Builder, "combatstack")),
         Gtk_Stack_Transition_Type'Val(GameSettings.AnimationType));
      GameSettings.MessagesLimit :=
        Positive
          (Get_Value(Gtk_Adjustment(Get_Object(Object, "adjmessageslimit"))));
      if Natural(Messages_List.Length) > GameSettings.MessagesLimit then
         Messages_List.Delete_First
           (Count =>
              (Messages_List.Length - Count_Type(GameSettings.MessagesLimit)));
      end if;
      GameSettings.SavedMessages :=
        Positive
          (Get_Value(Gtk_Adjustment(Get_Object(Object, "adjsavedmessages"))));
      GameSettings.MessagesOrder :=
        MessagesOrderType'Val
          (Get_Active(Gtk_Combo_Box(Get_Object(Object, "cmbmessagesorder"))));
      GameSettings.AutoAskForBases :=
        Get_State(Gtk_Switch(Get_Object(Object, "switchautoaskforbases")));
      GameSettings.AutoAskForEvents :=
        Get_State(Gtk_Switch(Get_Object(Object, "switchautoaskforevents")));
      SaveConfig;
      Save(To_String(SaveDirectory) & "keys.cfg");
      ShowSkyMap;
      Set_Visible_Child_Name
        (Gtk_Stack(Get_Object(Builder, "gamestack")), "skymap");
   end CloseOptions;

   function SetAccelerator(Self: access Gtk_Widget_Record'Class;
      Event: Gdk.Event.Gdk_Event_Key) return Boolean is
      KeyMods: constant Gdk_Modifier_Type :=
        Event.State and Get_Default_Mod_Mask;
      Changed, Found: Boolean := False;
      Key: Gtk_Accel_Key;
   begin
      for I in AccelNames'Range loop
         Lookup_Entry(To_String(AccelNames(I)), Key, Found);
         if Key.Accel_Key = Event.Keyval and Key.Accel_Mods = KeyMods then
            ShowDialog
              ("This key is set for other action. Please choose a different key.",
               Gtk_Window(Get_Object(Builder, "skymapwindow")));
            return False;
         end if;
      end loop;
      for I in EditNames'Range loop
         if Self =
           Gtk_Widget(Get_Object(Builder, To_String(EditNames(I)))) then
            Changed :=
              Change_Entry
                (To_String(AccelNames(I)), Event.Keyval, KeyMods, True);
            exit;
         end if;
      end loop;
      if Changed then
         Set_Text
           (Gtk_Entry(Self), Accelerator_Get_Label(Event.Keyval, KeyMods));
      end if;
      return False;
   end SetAccelerator;

   procedure ResizeFont(User_Data: access GObject_Record'Class) is
   begin
      if User_Data = Get_Object(Builder, "adjhelpfont") then
         GameSettings.HelpFontSize :=
           Positive
             (Get_Value(Gtk_Adjustment(Get_Object(Builder, "adjhelpfont"))));
         SetFontSize("help");
      elsif User_Data = Get_Object(Builder, "adjmapfont") then
         GameSettings.MapFontSize :=
           Positive
             (Get_Value(Gtk_Adjustment(Get_Object(Builder, "adjmapfont"))));
         SetFontSize("map");
      else
         GameSettings.InterfaceFontSize :=
           Positive
             (Get_Value
                (Gtk_Adjustment(Get_Object(Builder, "adjinterfacefont"))));
         SetFontSize("interface");
      end if;
   end ResizeFont;

   procedure ApplyTheme(Object: access Gtkada_Builder_Record'Class) is
   begin
      GameSettings.InterfaceTheme :=
        To_Unbounded_String
          (Get_Active_Text
             (Gtk_Combo_Box_Text(Get_Object(Object, "cmbtheme"))));
      LoadTheme;
   end ApplyTheme;

   procedure SetFontsSizes is
   begin
      Set_Value
        (Gtk_Adjustment(Get_Object(Builder, "adjhelpfont")),
         Gdouble(GameSettings.HelpFontSize));
      Set_Value
        (Gtk_Adjustment(Get_Object(Builder, "adjmapfont")),
         Gdouble(GameSettings.MapFontSize));
      Set_Value
        (Gtk_Adjustment(Get_Object(Builder, "adjinterfacefont")),
         Gdouble(GameSettings.InterfaceFontSize));
   end SetFontsSizes;

   procedure SetDefaultFontSize(Object: access Gtkada_Builder_Record'Class) is
      pragma Unreferenced(Object);
   begin
      ResetFontsSizes;
      SetFontsSizes;
   end SetDefaultFontSize;

   procedure CreateGameOptions(NewBuilder: Gtkada_Builder) is
      ThemeIndex, FileIndex: Natural := 0;
      Files: Search_Type;
      FoundFile: Directory_Entry_Type;
      ThemesComboBox: constant Gtk_Combo_Box_Text :=
        Gtk_Combo_Box_Text(Get_Object(NewBuilder, "cmbtheme"));
   begin
      Builder := NewBuilder;
      Register_Handler(Builder, "Close_Options", CloseOptions'Access);
      Register_Handler(Builder, "Resize_Font", ResizeFont'Access);
      Register_Handler(Builder, "Apply_Theme", ApplyTheme'Access);
      Register_Handler
        (Builder, "Set_Default_Font_Size", SetDefaultFontSize'Access);
      for I in EditNames'Range loop
         On_Key_Press_Event
           (Gtk_Widget(Get_Object(Builder, To_String(EditNames(I)))),
            SetAccelerator'Access);
      end loop;
      Set_Text
        (Gtk_Label(Get_Object(Builder, "lbldatadir")),
         To_String(DataDirectory));
      Set_Text
        (Gtk_Label(Get_Object(Builder, "lblsavedir")),
         To_String(SaveDirectory));
      Set_Text
        (Gtk_Label(Get_Object(Builder, "lbldocdir")), To_String(DocDirectory));
      Set_Text
        (Gtk_Label(Get_Object(Builder, "lblmodsdir")),
         To_String(ModsDirectory));
      Append_Text(ThemesComboBox, "default");
      Start_Search(Files, To_String(ThemesDirectory), "*.css");
      while More_Entries(Files) loop
         Get_Next_Entry(Files, FoundFile);
         Append_Text
           (ThemesComboBox, Ada.Directories.Base_Name(Simple_Name(FoundFile)));
         if Ada.Directories.Base_Name(Simple_Name(FoundFile)) =
           To_String(GameSettings.InterfaceTheme) then
            ThemeIndex := FileIndex;
         end if;
         FileIndex := FileIndex + 1;
      end loop;
      Set_Active(ThemesComboBox, Gint(ThemeIndex));
      End_Search(Files);
   end CreateGameOptions;

   procedure ShowGameOptions is
      Key: Gtk_Accel_Key;
      Found: Boolean;
   begin
      Set_State
        (Gtk_Switch(Get_Object(Builder, "switchautorest")),
         GameSettings.AutoRest);
      Set_Active
        (Gtk_Combo_Box(Get_Object(Builder, "cmbspeed1")),
         (ShipSpeed'Pos(GameSettings.UndockSpeed) - 1));
      Set_State
        (Gtk_Switch(Get_Object(Builder, "switchautocenter")),
         GameSettings.AutoCenter);
      Set_State
        (Gtk_Switch(Get_Object(Builder, "switchautoreturn")),
         GameSettings.AutoReturn);
      Set_State
        (Gtk_Switch(Get_Object(Builder, "switchautofinish")),
         GameSettings.AutoFinish);
      Set_Value
        (Gtk_Adjustment(Get_Object(Builder, "adjfuel")),
         Gdouble(GameSettings.LowFuel));
      Set_Value
        (Gtk_Adjustment(Get_Object(Builder, "adjdrinks")),
         Gdouble(GameSettings.LowDrinks));
      Set_Value
        (Gtk_Adjustment(Get_Object(Builder, "adjfood")),
         Gdouble(GameSettings.LowFood));
      Set_Active
        (Gtk_Combo_Box(Get_Object(Builder, "cmbautomovestop")),
         (AutoMoveBreak'Pos(GameSettings.AutoMoveStop)));
      for I in EditNames'Range loop
         Lookup_Entry(To_String(AccelNames(I)), Key, Found);
         Set_Text
           (Gtk_Entry(Get_Object(Builder, To_String(EditNames(I)))),
            Accelerator_Get_Label(Key.Accel_Key, Key.Accel_Mods));
      end loop;
      if GameSettings.AnimationsEnabled = 1 then
         Set_State(Gtk_Switch(Get_Object(Builder, "switchanimations")), True);
      else
         Set_State(Gtk_Switch(Get_Object(Builder, "switchanimations")), False);
      end if;
      Set_Active
        (Gtk_Combo_Box(Get_Object(Builder, "cmbanimations")),
         Gint(GameSettings.AnimationType - 1));
      Set_Value
        (Gtk_Adjustment(Get_Object(Builder, "adjmessageslimit")),
         Gdouble(GameSettings.MessagesLimit));
      Set_Value
        (Gtk_Adjustment(Get_Object(Builder, "adjsavedmessages")),
         Gdouble(GameSettings.SavedMessages));
      Set_Active
        (Gtk_Combo_Box(Get_Object(Builder, "cmbmessagesorder")),
         (MessagesOrderType'Pos(GameSettings.MessagesOrder)));
      Set_State
        (Gtk_Switch(Get_Object(Builder, "switchautoaskforbases")),
         GameSettings.AutoAskForBases);
      Set_State
        (Gtk_Switch(Get_Object(Builder, "switchautoaskforevents")),
         GameSettings.AutoAskForEvents);
      SetFontsSizes;
      Set_Visible_Child_Name
        (Gtk_Stack(Get_Object(Builder, "gamestack")), "options");
   end ShowGameOptions;

end GameOptions;
