--    Copyright 2018-2022 Bartek thindil Jasicki
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
with Ada.Containers.Vectors; use Ada.Containers;
with Ada.Strings.Unbounded.Hash;
with Ada.Containers.Hashed_Maps;
with DOM.Readers; use DOM.Readers;
with Game; use Game;

-- ****h* Stories/Stories
-- FUNCTION
-- Provide code for manipulate the game stories
-- SOURCE
package Stories is
-- ****

   -- ****t* Stories/Stories.Start_Condition_Type
   -- FUNCTION
   -- Types of conditions to start stories
   -- SOURCE
   type Start_Condition_Type is (DROPITEM) with
      Default_Value => DROPITEM;
   -- ****

   -- ****t* Stories/Stories.Step_Condition_Type
   -- FUNCTION
   -- Types of conditions to finish story step
   -- SOURCE
   type Step_Condition_Type is (ASKINBASE, DESTROYSHIP, EXPLORE, ANY, LOOT) with
      Default_Value => ANY;
   -- ****

   -- ****s* Stories/Stories.Step_Text_Data
   -- FUNCTION
   -- Data structure for stories steps texts
   -- PARAMETERS
   -- Condition - Finish condition of previous step
   -- Text      - Text which will be show to player when step starts.
   -- SOURCE
   type Step_Text_Data is record
      Condition: Step_Condition_Type;
      Text: Unbounded_String;
   end record;
   -- ****

   -- ****t* Stories/Stories.StepTexts_Container
   -- FUNCTION
   -- Used to store stories steps text data
   -- SOURCE
   package StepTexts_Container is new Vectors(Index_Type => Positive, Element_Type => Step_Text_Data);
   -- ****

   -- ****s* Stories/Stories.Step_Finish_Data
   -- FUNCTION
   -- Structure for finish condition data
   -- PARAMETERS
   -- Name  - Name of data
   -- Value - Value of data
   -- SOURCE
   type Step_Finish_Data is record
      Name: Unbounded_String;
      Value: Unbounded_String;
   end record;
   -- ****

   -- ****t* Stories/Stories.StepData_Container
   -- FUNCTION
   -- Used to store stories steps data
   -- SOURCE
   package StepData_Container is new Vectors(Index_Type => Positive, Element_Type => Step_Finish_Data);
   -- ****

   -- ****s* Stories/Stories.Step_Data
   -- FUNCTION
   -- Data structure for stories steps
   -- PARAMETERS
   -- Index            - Index of step
   -- Finish_Condition - Condition which must be met to finish selected step
   --                    and process to next
   -- Finish_Data      - Data for finish condition
   -- Texts            - Texts which will be show to player when step starts,
   --                    depends on finish condition of previous step.
   -- Fail_Text        - Text which will be show to player when step fails to
   --                    progress.
   -- SOURCE
   type Step_Data is record
      Index: Unbounded_String;
      Finish_Condition: Step_Condition_Type;
      Finish_Data: StepData_Container.Vector;
      Texts: StepTexts_Container.Vector;
      Fail_Text: Unbounded_String;
   end record;
   -- ****

   -- ****t* Stories/Stories.Steps_Container
   -- FUNCTION
   -- Used to store stories steps
   -- SOURCE
   package Steps_Container is new Vectors(Index_Type => Positive, Element_Type => Step_Data);
   -- ****

   -- ****s* Stories/Stories.Story_Data
   -- FUNCTION
   -- Data structure for stories
   -- PARAMETERS
   -- Start_Condition    - Condition which must be met to start story
   -- Start_Data         - Data for starting condition
   -- Min_Steps          - Minimal amount of steps in story
   -- Max_Steps          - Maxium amount of steps in story
   -- Starting_Step      - Starting step of story
   -- Steps              - Contains all steps in story
   -- Final_Step         - Final step of story
   -- End_Text           - Text which will be show to player when story ends.
   -- Name               - Name of story, show in game
   -- Forbidden_Factions - If player is in one of this factions, he/she can't
   --                      start this story.
   -- SOURCE
   type Story_Data is record
      Start_Condition: Start_Condition_Type;
      Start_Data: UnboundedString_Container.Vector;
      Min_Steps: Positive := 1;
      Max_Steps: Positive := 1;
      Starting_Step: Step_Data;
      Steps: Steps_Container.Vector;
      Final_Step: Step_Data;
      End_Text: Unbounded_String;
      Name: Unbounded_String;
      Forbidden_Factions: UnboundedString_Container.Vector;
   end record;
   -- ****

   -- ****t* Stories/Stories.Stories_Container
   -- FUNCTION
   -- Used to store stories
   -- SOURCE
   package Stories_Container is new Hashed_Maps
     (Unbounded_String, Story_Data, Ada.Strings.Unbounded.Hash, "=");
   -- ****

   -- ****s* Stories/Stories.CurrentStory_Data
   -- FUNCTION
   -- Data structure for current active story
   -- PARAMETERS
   -- Index        - Index of story or empty string if no story currently
   --                active
   -- Step         - Number of current step in story
   -- CurrentStep  - Index of current step, 0 for starting step, -1 for finish
   --                step
   -- MaxSteps     - Number of maxium  amounts of steps in story
   -- ShowText     - If true, show text of current step to player
   -- Data         - Various data for current step, depends on step
   -- FinishedStep - Finish condition for previous step
   -- SOURCE
   type CurrentStory_Data is record
      Index: Unbounded_String;
      Step: Positive := 1;
      CurrentStep: Integer range -3 .. Integer'Last;
      MaxSteps: Positive := 1;
      ShowText: Boolean;
      Data: Unbounded_String;
      FinishedStep: Step_Condition_Type;
   end record;
   -- ****

   -- ****s* Stories/Stories.FinishedStory_Data
   -- FUNCTION
   -- Data structure for finished story/steps
   -- PARAMETERS
   -- Index       - Index of story
   -- StepsAmount - Amount of steps in this story
   -- StepsTexts  - Texts of steps done in this story. If less than
   --               StepsAmount then it is current story.
   -- SOURCE
   type FinishedStory_Data is record
      Index: Unbounded_String;
      StepsAmount: Positive := 1;
      StepsTexts: UnboundedString_Container.Vector;
   end record;
   -- ****

   -- ****t* Stories/Stories.FinishedStories_Container
   -- FUNCTIONS
   -- Used to store finished stories
   -- SOURCE
   package FinishedStories_Container is new Vectors
     (Positive, FinishedStory_Data);
   -- ****

   -- ****v* Stories/Stories.CurrentStory
   -- FUNCTION
   -- Contains data about current story on which player is
   -- SOURCE
   CurrentStory: CurrentStory_Data;
   -- ****

   -- ****v* Stories/Stories.Stories_List
   -- FUNCTION
   -- List of available stories in game
   -- SOURCE
   Stories_List: Stories_Container.Map;
   -- ****

   -- ****v* Stories/Stories.FinishedStories
   -- FUNCTION
   -- List of finished stories (or past data of current story)
   -- SOURCE
   FinishedStories: FinishedStories_Container.Vector;
   -- ****

   -- ****f* Stories/Stories.LoadStories
   -- FUNCTION
   -- Load stories data from files
   -- PARAMETERS
   -- Reader - XML Reader from which data will be read
   -- SOURCE
   procedure LoadStories(Reader: Tree_Reader);
   -- ****

   -- ****f* Stories/Stories.StartStory
   -- FUNCTION
   -- Check if any story can starts
   -- PARAMETERS
   -- FactionName - Name of faction to which players belongs
   -- Condition   - Starting condition which was triggered
   -- SOURCE
   procedure StartStory
     (FactionName: Unbounded_String; Condition: Start_Condition_Type) with
      Pre => FactionName /= Null_Unbounded_String,
      Test_Case => (Name => "Test_StartStory", Mode => Nominal);
      -- ****

      -- ****f* Stories/Stories.ClearCurrentStory
      -- FUNCTION
      -- Resets current story
      -- SOURCE
   procedure ClearCurrentStory with
      Post => CurrentStory.Index = Null_Unbounded_String,
      Test_Case => (Name => "Test_ClearCurrentStory", Mode => Nominal);
      -- ****

      -- ****f* Stories/Stories.ProgressStory
      -- FUNCTION
      -- Progress current story one step
      -- PARAMETERS
      -- NextStep - Used with DESTROYSHIP condition. If false, progress to the
      --            next step in story. Default is false.
      -- RESULT
      -- True if story goes to next step, otherwise false
      -- SOURCE
   function ProgressStory(NextStep: Boolean := False) return Boolean with
      Test_Case => (Name => "Test_ProgressStory", Mode => Robustness);
      -- ****

      -- ****f* Stories/Stories.GetCurrentStoryText
      -- FUNCTION
      -- Get text of current step in story
      -- RESULT
      -- Text of current step in current story
      -- SOURCE
   function GetCurrentStoryText return Unbounded_String with
      Test_Case => (Name => "Tets_GetCurrentStoryText", Mode => Robustness);
      -- ****

      -- ****f* Stories/Stories.GetStepData
      -- FUNCTION
      -- Get step finish data with selected name
      -- PARAMETERS
      -- FinishData - List of step data
      -- Name       - Name of data to get
      -- RESULT
      -- Selected data from FinishData parameter
      -- SOURCE
   function GetStepData
     (FinishData: StepData_Container.Vector; Name: String)
      return Unbounded_String with
      Pre => Name'Length > 0,
      Test_Case => (Name => "Test_GetStepData", Mode => Nominal);
      -- ****

      -- ****f* Stories/Stories.GetStoryLocation
      -- FUNCTION
      -- Get target location of current story
      -- PARAMETERS
      -- StoryX - X coordination of current story target
      -- StoryY - Y coordination of current story target
      -- RESULT
      -- Parameters X and Y
      -- SOURCE
   procedure GetStoryLocation
     (StoryX: out Map_X_Range; StoryY: out Map_Y_Range) with
      Test_Case => (Name => "Test_GetStoryLocation", Mode => Robustness);
      -- ****

end Stories;
