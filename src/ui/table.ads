-- Copyright (c) 2021 Bartek thindil Jasicki <thindil@laeran.pl>
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
with Tcl.Tk.Ada.Widgets.Canvas; use Tcl.Tk.Ada.Widgets.Canvas;
with Tcl.Tk.Ada.Widgets.TtkScrollbar; use Tcl.Tk.Ada.Widgets.TtkScrollbar;

-- ****h* Table/Table
-- FUNCTION
-- Provides code for create and manipulate more advanced table widget
-- SOURCE
package Table is
-- ****

   -- ****t* Table/Table.Width_Array
   -- FUNCTION
   -- Used to store width of Table_Widget columns
   -- SOURCE
   type Width_Array is array(Positive range <>) of Positive;
   -- ****

   -- ****s* Table/Table.Table_Widget
   -- FUNCTION
   -- Store data for each created table
   -- PARAMETERS
   -- Canvas        - Tk_Canvas which is used as table
   -- Columns_Width - The array with the width for each column in the table
   -- Row           - The current row of the table
   -- Row_Height    - The height of each row
   -- Scrollbar     - The vertical Ttk_Scrollbar associated with the table
   -- SOURCE
   type Table_Widget(Amount: Positive) is record
      Canvas: Tk_Canvas;
      Columns_Width: Width_Array(1 .. Amount) := (others => 1);
      Row: Positive := 1;
      Row_Height: Positive := 1;
      Scrollbar: Ttk_Scrollbar;
   end record;
   -- ****

   -- ****t* Table/Table.Headers_Array
   -- FUNCTION
   -- Used to store the titles for columns in the selected table
   -- SOURCE
   type Headers_Array is array(Positive range <>) of Unbounded_String;
   -- ****

   -- ****f* Table/Table.CreateTable
   -- FUNCTION
   -- Create a new table and columns headers in it
   -- PARAMETERS
   -- Parent    - The Tk path for the parent widget
   -- Headers   - The titles for the table headers
   -- Scrollbar - Ttk_Scrollbar associated with the table. If empty
   --             then create a new scrollbars. Default value is empty.
   -- Command   - The Tcl command executed when the player press the table
   --             header. If empty, no command is executed. Default value is
   --             empty
   -- RESULT
   -- The newly created Table_Widget
   -- HISTORY
   -- 5.7 - Added
   -- 6.4 - Added Command parameter
   -- SOURCE
   function CreateTable
     (Parent: String; Headers: Headers_Array;
      Scrollbar: Ttk_Scrollbar := Get_Widget("."); Command: String := "")
      return Table_Widget with
      Pre => Parent'Length > 0 and Headers'Length > 0,
      Post => CreateTable'Result.Row_Height > 1;
   -- ****

     -- ****f* Table/Table.ClearTable
     -- FUNCTION
     -- Clear data from the table
     -- PARAMETERS
     -- Table - The Table_Widget which will be cleared
     -- OUTPUT
     -- Cleared Table parameter Table_Widget
     -- HISTORY
     -- 5.7 - Added
     -- SOURCE
   procedure ClearTable(Table: in out Table_Widget) with
      Pre => Table.Row_Height > 1;
   -- ****

   -- ****f* Table/Table.AddButton
   -- FUNCTION
   -- Add button item to the selected Table_Widget
   -- PARAMETERS
   -- Table   - The Table_Widget in which button will be added
   -- Text    - The text displayed on the button
   -- Tooltip - The tooltip show when user hover mouse over button
   -- Command - Tcl command which will be executed when button was clicked
   -- Column  - The column in which the button will be added
   -- NewRow  - If True, increase current number of row in the Table_Widget.
   --           Default value is False.
   -- Color   - The color of the text on button which will be added. If empty,
   --           use default interface color. Default value is empty.
   -- OUTPUT
   -- Updated Table parameter Table_Widget
   -- HISTORY
   -- 5.7 - Added
   -- SOURCE
   procedure AddButton
     (Table: in out Table_Widget; Text, Tooltip, Command: String;
      Column: Positive; NewRow: Boolean := False; Color: String := "") with
      Pre => Table.Row_Height > 1 and Command'Length > 0;
   -- ****

   -- ****f* Table/Table.UpdateTable
   -- FUNCTION
   -- Update size and coordinates of all elements in the selected table
   -- PARAMETERS
   -- Table - The Table_Widget which elements will be resized if needed
   -- HISTORY
   -- 5.7 - Added
   -- SOURCE
   procedure UpdateTable(Table: in out Table_Widget) with
      Pre => Table.Row_Height > 1;
   -- ****

   -- ****f* Table/Table.AddProgressBar
   -- FUNCTION
   -- Add progress bar item to the selected Table_Widget
   -- PARAMETERS
   -- Table        - The Table_Widget in which progress bar will be added
   -- Value        - The current value of the progress bar
   -- MaxValue     - The maximum value of the progress bar
   -- Tooltip      - The tooltip show when user hover mouse over progress bar
   -- Command      - Tcl command which will be executed when the row in which the
   --                the progress bar is was clicked
   -- Column       - The column in which the progress bar will be added
   -- NewRow       - If True, increase current number of row in the Table_Widget.
   --                Default value is False.
   -- InvertColors - Invert colors of the progress bar (small amount green, max
   --                red instead of small amount red and max green)
   -- OUTPUT
   -- Updated Table parameter Table_Widget
   -- HISTORY
   -- 5.7 - Added
   -- SOURCE
   procedure AddProgressBar
     (Table: in out Table_Widget; Value: Natural; MaxValue: Positive;
      Tooltip, Command: String; Column: Positive;
      NewRow, InvertColors: Boolean := False) with
      Pre => Table.Row_Height > 1 and Value <= MaxValue;
   -- ****

   -- ****f* Table/Table.AddPagination
   -- FUNCTION
   -- Add pagination buttons to the bottom of the table
   -- PARAMETERS
   -- Table           - The Table_Widget to which buttons will be added
   -- PreviousCommand - The Tcl command which will be executed by the previous
   --                   button. If empty, button will not be shown.
   -- NextCommand     - The Tcl command which will be executed by the next
   --                   button. If empty, button will not be shown.
   -- HISTORY
   -- 5.9 - Added
   -- SOURCE
   procedure AddPagination
     (Table: in out Table_Widget; PreviousCommand, NextCommand: String) with
      Pre => Table.Row_Height > 1;
   -- ****

   -- ****f* Table/Table.AddCheckButton
   -- FUNCTION
   -- Add check button item to the selected Table_Widget
   -- PARAMETERS
   -- Table   - The Table_Widget in which button will be added
   -- Tooltip - The tooltip show when user hover mouse over button
   -- Command - Tcl command which will be executed when button was clicked. If
   --           empty, the button will be disabled
   -- Checked - If True, the button will be checked
   -- Column  - The column in which the button will be added
   -- NewRow  - If True, increase current number of row in the Table_Widget.
   --           Default value is False.
   -- HISTORY
   -- 6.0 - Added
   -- SOURCE
   procedure AddCheckButton
     (Table: in out Table_Widget; Tooltip, Command: String; Checked: Boolean;
      Column: Positive; NewRow: Boolean := False) with
      Pre => Table.Row_Height > 1;
      -- ****

end Table;
