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

with Ada.Characters.Latin_1; use Ada.Characters.Latin_1;
with Gtk.Message_Dialog; use Gtk.Message_Dialog;
with Gtk.Dialog; use Gtk.Dialog;
with Gtk.Accel_Group; use Gtk.Accel_Group;
with Gtk.Stack; use Gtk.Stack;
with Gtk.Menu; use Gtk.Menu;
with Gdk.Types; use Gdk.Types;
with Gdk.Types.Keysyms; use Gdk.Types.Keysyms;
with Glib.Main; use Glib.Main;
with MainMenu; use MainMenu;
with Game; use Game;
with Messages; use Messages;
with Maps.UI; use Maps.UI;
with Combat.UI; use Combat.UI;
with GameOptions; use GameOptions;
with Statistics.UI; use Statistics.UI;
with Ships; use Ships;
with Ships.Crew; use Ships.Crew;
with Ships.Movement; use Ships.Movement;
with Items; use Items;
with Config; use Config;

package body Utils.UI is

   Builder: Gtkada_Builder;

   procedure ShowDialog(Message: String; Parent: Gtk_Window) is
      MessageDialog: constant Gtk_Message_Dialog :=
        Gtk_Message_Dialog_New
          (Parent, Modal, Message_Error, Buttons_Close, Message);
   begin
      if Run(MessageDialog) /= Gtk_Response_None then
         Destroy(MessageDialog);
      end if;
   end ShowDialog;

   function HideWindow
     (User_Data: access GObject_Record'Class) return Boolean is
   begin
      return Hide_On_Delete(Gtk_Widget(User_Data));
   end HideWindow;

   procedure ShowWindow(User_Data: access GObject_Record'Class) is
   begin
      Show_All(Gtk_Widget(User_Data));
   end ShowWindow;

   function ShowConfirmDialog(Message: String;
      Parent: Gtk_Window) return Boolean is
      MessageDialog: constant Gtk_Message_Dialog :=
        Gtk_Message_Dialog_New
          (Parent, Modal, Message_Question, Buttons_Yes_No, Message);
   begin
      if Run(MessageDialog) = Gtk_Response_Yes then
         Destroy(MessageDialog);
         return True;
      end if;
      Destroy(MessageDialog);
      return False;
   end ShowConfirmDialog;

   function QuitGame(User_Data: access GObject_Record'Class) return Boolean is
   begin
      if ShowConfirmDialog
          ("Are you sure want to quit?", Gtk_Window(User_Data)) then
         EndGame(True);
         ShowMainMenu;
         return Hide_On_Delete(Gtk_Widget(User_Data));
      end if;
      return True;
   end QuitGame;

   procedure HideLastMessage(Object: access Gtkada_Builder_Record'Class) is
   begin
      Hide(Gtk_Widget(Get_Object(Object, "inforevealer")));
      LastMessage := Null_Unbounded_String;
      Set_Margin_Top(Gtk_Widget(Get_Object(Object, "gamestack")), 0);
   end HideLastMessage;

   function AutoHideLastMessage return Boolean is
   begin
      HideLastMessage(Builder);
      return False;
   end AutoHideLastMessage;

   procedure ShowLastMessage(Object: access Gtkada_Builder_Record'Class) is
   begin
      if not GameSettings.ShowLastMessage then
         return;
      end if;
      if LastMessage = Null_Unbounded_String then
         HideLastMessage(Object);
      else
         Set_Text
           (Gtk_Label(Get_Object(Object, "lbllastmessage")),
            To_String(LastMessage));
         Show_All(Gtk_Widget(Get_Object(Object, "inforevealer")));
         if Get_Visible_Child_Name
             (Gtk_Stack(Get_Object(Object, "gamestack"))) /=
           "skymap" then
            Set_Margin_Top
              (Gtk_Widget(Get_Object(Object, "gamestack")),
               Gint(GameSettings.InterfaceFontSize * 3));
         end if;
         LastMessage := Null_Unbounded_String;
         declare
            Source_Id: G_Source_Id;
            pragma Unreferenced(Source_Id);
         begin
            Source_Id := Timeout_Add(4000, AutoHideLastMessage'Access);
         end;
      end if;
      UpdateHeader;
   end ShowLastMessage;

   function CloseWindow(Self: access Gtk_Widget_Record'Class;
      Event: Gdk_Event_Key) return Boolean is
      KeyMods: constant Gdk_Modifier_Type :=
        Event.State and Get_Default_Mod_Mask;
   begin
      if KeyMods = 0 and Event.Keyval = GDK_Escape then
         Close(Gtk_Window(Self));
         return False;
      end if;
      return True;
   end CloseWindow;

   procedure CloseMessages(Object: access Gtkada_Builder_Record'Class) is
      VisibleChildName: constant String :=
        Get_Visible_Child_Name(Gtk_Stack(Get_Object(Object, "gamestack")));
      MenuArray: constant array(1 .. 11) of Unbounded_String :=
        (To_Unbounded_String("menuorders"),
         To_Unbounded_String("menucrafting"),
         To_Unbounded_String("menubaseslist"),
         To_Unbounded_String("menuevents"),
         To_Unbounded_String("menumissions"), To_Unbounded_String("menustory"),
         To_Unbounded_String("menuwait"), To_Unbounded_String("menumovemap"),
         To_Unbounded_String("menustats"), To_Unbounded_String("menuhelp"),
         To_Unbounded_String("menuoptions"));
   begin
      if VisibleChildName = "options" then
         CloseOptions(Object);
         return;
      end if;
      if VisibleChildName = "inventory" then
         Set_Visible_Child_Name
           (Gtk_Stack(Get_Object(Object, "gamestack")), "crew");
         return;
      end if;
      if VisibleChildName = "gamestats" then
         HideStatistics;
         return;
      end if;
      if VisibleChildName = "combat" then
         Set_Sensitive(Gtk_Widget(Get_Object(Object, "treecrew1")), True);
         for I in MenuArray'Range loop
            Show_All(Gtk_Widget(Get_Object(Object, To_String(MenuArray(I)))));
         end loop;
         UpdateOrders(PlayerShip);
      end if;
      Hide(Gtk_Widget(Get_Object(Object, "btnclose")));
      case PreviousGameState is
         when SkyMap_View =>
            Show_All(Gtk_Widget(Get_Object(Object, "menuwait")));
            Show_All(Gtk_Widget(Get_Object(Object, "menumovemap")));
            ShowSkyMap;
         when Combat_View =>
            ShowCombatUI(False);
         when Main_Menu =>
            null;
      end case;
   end CloseMessages;

   function SelectElement(Self: access GObject_Record'Class;
      Event: Gdk_Event_Key) return Boolean is
      KeyMods: constant Gdk_Modifier_Type :=
        Event.State and Get_Default_Mod_Mask;
   begin
      if KeyMods = 0 and
        (Event.Keyval = GDK_Return or Event.Keyval = GDK_Escape) then
         Grab_Focus(Gtk_Widget(Self));
         return True;
      end if;
      return False;
   end SelectElement;

   procedure TravelInfo(InfoText: in out Unbounded_String; Distance: Positive;
      ShowFuelName: Boolean := False) is
      type SpeedType is digits 2;
      Speed: constant SpeedType :=
        (SpeedType(RealSpeed(PlayerShip, True)) / 1000.0);
      MinutesDiff: Integer;
   begin
      MinutesDiff := Integer(100.0 / Speed);
      case PlayerShip.Speed is
         when QUARTER_SPEED =>
            if MinutesDiff < 60 then
               MinutesDiff := 60;
            end if;
         when HALF_SPEED =>
            if MinutesDiff < 30 then
               MinutesDiff := 30;
            end if;
         when FULL_SPEED =>
            if MinutesDiff < 15 then
               MinutesDiff := 15;
            end if;
         when others =>
            null;
      end case;
      Append(InfoText, LF & "ETA:");
      MinutesDiff := MinutesDiff * Distance;
      MinutesToDate(MinutesDiff, InfoText);
      Append
        (InfoText,
         LF & "Approx fuel usage:" &
         Natural'Image(abs (Distance * CountFuelNeeded)) & " ");
      if ShowFuelName then
         Append
           (InfoText, Items_List(FindProtoItem(ItemType => FuelType)).Name);
      end if;
   end TravelInfo;

   procedure MinutesToDate(Minutes: Natural;
      InfoText: in out Unbounded_String) is
      TravelTime: Date_Record := (others => 0);
      MinutesDiff: Integer := Minutes;
   begin
      while MinutesDiff > 0 loop
         if MinutesDiff >= 518400 then
            TravelTime.Year := TravelTime.Year + 1;
            MinutesDiff := MinutesDiff - 518400;
         elsif MinutesDiff >= 43200 then
            TravelTime.Month := TravelTime.Month + 1;
            MinutesDiff := MinutesDiff - 43200;
         elsif MinutesDiff >= 1440 then
            TravelTime.Day := TravelTime.Day + 1;
            MinutesDiff := MinutesDiff - 1440;
         elsif MinutesDiff >= 60 then
            TravelTime.Hour := TravelTime.Hour + 1;
            MinutesDiff := MinutesDiff - 60;
         else
            TravelTime.Minutes := MinutesDiff;
            MinutesDiff := 0;
         end if;
      end loop;
      if TravelTime.Year > 0 then
         Append(InfoText, Positive'Image(TravelTime.Year) & "y");
      end if;
      if TravelTime.Month > 0 then
         Append(InfoText, Positive'Image(TravelTime.Month) & "m");
      end if;
      if TravelTime.Day > 0 then
         Append(InfoText, Positive'Image(TravelTime.Day) & "d");
      end if;
      if TravelTime.Hour > 0 then
         Append(InfoText, Positive'Image(TravelTime.Hour) & "h");
      end if;
      if TravelTime.Minutes > 0 then
         Append(InfoText, Positive'Image(TravelTime.Minutes) & "mins");
      end if;
   end MinutesToDate;

   procedure ShowInventoryItemInfo(Label: Gtk_Label; ItemIndex: Positive;
      MemberIndex: Natural) is
      ProtoIndex: Positive;
      ItemInfo: Unbounded_String;
   begin
      if MemberIndex > 0 then
         ProtoIndex :=
           PlayerShip.Crew(MemberIndex).Inventory(ItemIndex).ProtoIndex;
      else
         ProtoIndex := PlayerShip.Cargo(ItemIndex).ProtoIndex;
      end if;
      Append
        (ItemInfo,
         "Weight:" & Positive'Image(Items_List(ProtoIndex).Weight) & " kg");
      if Items_List(ProtoIndex).IType = WeaponType then
         Append
           (ItemInfo,
            LF & "Skill: " &
            Skills_List(Items_List(ProtoIndex).Value(3)).Name & "/" &
            Attributes_List
              (Skills_List(Items_List(ProtoIndex).Value(3)).Attribute)
              .Name);
         if Items_List(ProtoIndex).Value(4) = 1 then
            Append(ItemInfo, LF & "Can be used with shield.");
         else
            Append
              (ItemInfo,
               LF & "Can't be used with shield (two-handed weapon).");
         end if;
         Append(ItemInfo, LF & "Damage type: ");
         case Items_List(ProtoIndex).Value(5) is
            when 1 =>
               Append(ItemInfo, "cutting");
            when 2 =>
               Append(ItemInfo, "impaling");
            when 3 =>
               Append(ItemInfo, "blunt");
            when others =>
               null;
         end case;
      end if;
      if Items_List(ProtoIndex).Description /= Null_Unbounded_String then
         Append
           (ItemInfo, LF & LF & To_String(Items_List(ProtoIndex).Description));
      end if;
      Set_Markup(Label, To_String(ItemInfo));
   end ShowInventoryItemInfo;

   procedure HideItemInfo(User_Data: access GObject_Record'Class) is
      ItemInfoBox: constant Gtk_Widget := Gtk_Widget(User_Data);
   begin
      Set_Visible(ItemInfoBox, not Get_Visible(ItemInfoBox));
   end HideItemInfo;

   function ShowPopupMenu
     (User_Data: access GObject_Record'Class) return Boolean is
   begin
      Popup(Gtk_Menu(User_Data));
      return False;
   end ShowPopupMenu;

   function ShowPopupMenuButton(Self: access Gtk_Widget_Record'Class;
      Event: Gdk_Event_Button) return Boolean is
   begin
      if Event.Button = 3 then
         if Self = Gtk_Widget(Get_Object(Builder, "treebases")) then
            return ShowPopupMenu(Get_Object(Builder, "baseslistmenu"));
         elsif Self = Gtk_Widget(Get_Object(Builder, "treemissions1")) then
            return ShowPopupMenu(Get_Object(Builder, "acceptedmissionsmenu"));
         elsif Self = Gtk_Widget(Get_Object(Builder, "treeevents")) then
            return ShowPopupMenu(Get_Object(Builder, "eventsmenu"));
         elsif Self = Gtk_Widget(Get_Object(Builder, "treemissions")) then
            return ShowPopupMenu(Get_Object(Builder, "availablemissionsmenu"));
         end if;
      end if;
      return False;
   end ShowPopupMenuButton;

   procedure SetUtilsBuilder(NewBuilder: Gtkada_Builder) is
   begin
      Builder := NewBuilder;
   end SetUtilsBuilder;

end Utils.UI;
