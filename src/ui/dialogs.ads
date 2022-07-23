-- Copyright (c) 2021-2022 Bartek thindil Jasicki <thindil@laeran.pl>
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

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Interfaces.C; use Interfaces.C;
with CArgv;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Game; use Game;
with Items; use Items;

-- ****h* Dialogs/Dialogs
-- FUNCTION
-- Provide code to show various in game dialogs (messages, questins, etc)
-- SOURCE
package Dialogs is
-- ****

   -- ****s* Dialogs/Dialogs.Button_Settings
   -- FUNCTION
   -- Data structure for setting various options for a dialog's buttons
   -- PARAMETERS
   -- Text    - The text to display on the button. If empty, the button will
   --           not be displayed. Default value is empty
   -- Command - The Tcl command to execute when the button pressed. Default
   --           value is empty
   -- Icon    - The Tcl icon to display on the button. Default value is empty
   -- Tooltip - The button's tooltip text. Default value is empty
   -- HISTORY
   -- 7.7 - Added
   -- SOURCE
   type Button_Settings is record
      Text: Unbounded_String := Null_Unbounded_String;
      Command: Unbounded_String := Null_Unbounded_String;
      Icon: Unbounded_String := Null_Unbounded_String;
      Tooltip: Unbounded_String := Null_Unbounded_String;
   end record;

   -- ****d* Dialogs/Dialogs.Empty_Button_Settings
   -- FUNCTION
   -- Default value of Button_Settings
   -- SOURCE
   Empty_Button_Settings: constant Button_Settings :=
     (Text => Null_Unbounded_String, Command => Null_Unbounded_String,
      Icon => Null_Unbounded_String, Tooltip => Null_Unbounded_String);
   -- ****

   -- ****f* Dialogs/Dialogs.Create_Dialog
   -- FUNCTION
   -- Create a new dialog with the selected title
   -- PARAMETERS
   -- Name        - The Tk path name of the new dialog
   -- Title       - The title of the new dialog
   -- Title_Width - The maximum width of the title. Used to set wrapping for
   --               it. Default value is 275 pixels. Can be empty.
   -- Columns     - The amount of columns which dialog will have. Used to set
   --               the title. Default value is 1 column. Can be empty.
   -- RESULT
   -- The newly created Dialog as Ttk_Frame
   -- SOURCE
   function Create_Dialog
     (Name, Title: String; Title_Width: Positive := 275;
      Columns: Positive := 1; Parent_Name: String := ".gameframe")
      return Ttk_Frame;
      -- ****

      -- ****f* Dialogs/Dialogs.Add_Close_Button
      -- FUNCTION
      -- Add button to close the selected dialog and set proper bindings for
      -- it.
      -- PARAMETERS
      -- Name        - The Tk path name for the button
      -- Text        - The text to display on the button
      -- Command     - The Tcl command to run when the button was clicked
      -- Column_Span - The amount of columns to merge when placing the close
      --               button. Can be empty. Default value is 1 (no merging).
      -- Row         - The row in which the button will be placed. Can be empty.
      --               Default value is 0 (place button in the next row)
      -- Column      - The column in which the button will be placed. Can be empty.
      --               Default value is 0 (place button in the first column)
      -- Icon        - The Tcl image which will be displayed on the button instead
      --               of text
      -- SOURCE
   procedure Add_Close_Button
     (Name, Text, Command: String; Column_Span: Positive := 1;
      Row, Column: Natural := 0; Icon: String := "exiticon");
   -- ****

   -- ****f* Dialogs/Dialogs.Show_Dialog
   -- FUNCTION
   -- Show the selected dialog to the player
   -- PARAMETERS
   -- Dialog       - The dialog which will be shown
   -- Parent_Frame - The parent frame name for the dialog. Can be empty.
   --                Default value is .gameframe
   -- With_Timer   - If True, add timer to the dialog. Can be empty. Default
   --                value is False
   -- Relative_X   - Relative X coordinate inside of parent frame for the
   --                dialog. 0.0 is left border. Can be empty. Default value
   --                is 0.3
   -- Relative_Y   - Relative Y coordinate inside of parent frame for the
   --                dialog. 0.0 is top border. Can be empty. Default value is
   --                0.3
   -- SOURCE
   procedure Show_Dialog
     (Dialog: Ttk_Frame; Parent_Frame: String := ".gameframe";
      With_Timer: Boolean := False;
      Relative_X, Relative_Y: Damage_Factor := 0.3);
   -- ****

   -- ****o* Dialogs/Dialogs.Close_Dialog_Command
   -- FUNCTION
   -- Close the selected dialog
   -- PARAMETERS
   -- Client_Data - Custom data send to the command. Unused
   -- Interp      - Tcl interpreter in which command was executed.
   -- Argc        - Number of arguments passed to the command.
   -- Argv        - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- CloseDialog dialogname
   -- Dialogname is name of the dialog to close
   -- SOURCE
   function Close_Dialog_Command
     (Client_Data: Integer; Interp: Tcl.Tcl_Interp; Argc: Interfaces.C.int;
      Argv: CArgv.Chars_Ptr_Ptr) return Interfaces.C.int with
      Convention => C;
      -- ****

      -- ****f* Dialogs/Dialogs.Change_Title
      -- FUNCTION
      -- Change the title of the selected dialog
      -- PARAMETERS
      -- Dialog    - The dialog which title will be changed
      -- New_Title - The new title for the selected dialog
      -- HISTORY
      -- 6.8 - Added
      -- SOURCE
   procedure Change_Title(Dialog: Ttk_Frame; New_Title: String);
   -- ****

      -- ****f* Dialogs/Dialogs.Add_Commands
      -- FUNCTION
      -- Add Tcl commands related to dialogs
      -- SOURCE
   procedure Add_Commands;
   -- ****

      -- ****f* Dialogs/Dialogs.Show_Message
      -- FUNCTION
      -- Show the selected message to a player
      -- PARAMETERS
      -- Text         - Text of message to show
      -- Parent_Frame - The parent frame of the message dialog. Default is
      --                the game frame. Can be empty
      -- Title        - The text show in the dialog header.
      -- SOURCE
   procedure Show_Message
     (Text: String; Parent_Frame: String := ".gameframe"; Title: String) with
      Pre => Text'Length > 0 and Parent_Frame'Length > 0;
   -- ****

      -- ****f* Dialogs/Dialogs.Show_Info
      -- FUNCTION
      -- Show the selected info to a player
      -- PARAMETERS
      -- Text             - Text of info to show
      -- Parent_Name      - Name of the parent widget. If empty, then the main game
      --                    window will be used as parent for widget. Default value
      --                    is .gameframe
      -- Title            - The text show in the dialog header.
      -- Button_1_Text    - The text displayed on the first optional button. If empty,
      --                    the button will not show. Default value is empty.
      -- Button_1_Command - The command for the first optional button. Has meaning
      --                    only if Button_1_Text is set. Default value is empty.
      -- Button_1_Icon    - The image to show on the first optional button. If set,
      --                    Button_1_Text will be used as tooltip. Default value is
      --                    empty.
      -- Button_2_Text    - The text displayed on the second optional button. If empty,
      --                    the button will not show. Default value is empty.
      -- Button_2_Command - The command for the first optional button. Has meaning
      --                    only if Button_2_Text is set. Default value is empty.
      -- Button_2_Icon    - The image to show on the second optional button. If set,
      --                    Button_2_Text will be used as tooltip. Default value is
      --                    empty.
      -- SOURCE
   procedure Show_Info
     (Text: String; Parent_Name: String := ".gameframe"; Title: String;
      Button_1, Button_2: Button_Settings := Empty_Button_Settings) with
      Pre => Text'Length > 0 and Parent_Name'Length > 0;
      -- ****

      -- ****f* Dialogs/Dialogs.Show_Manipulate_Item
      -- FUNCTION
      -- Show the dialog for manipulate items amount in cargo (like selling,
      -- dropping, etc).
      -- PARAMETERS
      -- Title      - Title of the dialog
      -- Command    - Tcl command which will be executed when the player hit
      --              the button Ok
      -- Action     - The name of action which the player is doing (like drop,
      --              sell, ect)
      -- Item_Index - The index of the item which will be manipulated
      -- Max_Amount - Max amount of the items to manipualate. If zero, use max
      --              amount of items from player ship cargo. Default value is
      --              zero.
      -- Cost       - The cost (in buying) or gain (in selling) for one item in
      --              the game money. Can be zero. Default value is zero.
      -- SOURCE
   procedure Show_Manipulate_Item
     (Title, Command, Action: String;
      Item_Index: Inventory_Container.Extended_Index;
      Max_Amount, Cost: Natural := 0) with
      Pre => Title'Length > 0 and Command'Length > 0;
      -- ****

      -- ****f* Dialogs/Dialogs.Show_Question
      -- FUNCTION
      -- Show the dialog with question to the player
      -- PARAMETERS
      -- Question - The question which will be the player asked for
      -- Result   - The value set for Ok button
      -- In_Game  - The question in show during game
      -- HISTORY
      -- 5.9 - Added
      -- SOURCE
   procedure Show_Question
     (Question, Result: String; In_Game: Boolean := True) with
      Pre => Question'Length > 0;
      -- ****

end Dialogs;
