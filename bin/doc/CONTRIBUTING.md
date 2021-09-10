## Bugs reporting

Bugs and game crashes are not the only problems, but typos too. If you find any bugs
in the game, please report it at options available at [contact page](https://www.laeran.pl/repositories/steamsky/wiki?name=Contact).

### Some general hints about reporting bugs

* In the "Title" field try to write short but not a too vague description
  of the problem. Good example: "Game crashed when entering base". Bad example:
  "Game crashes often."
* In the body/comment field try to write as much information about the problem
  as possible. In most cases, more information is better than less. General
  rule of a good problem report is to give enough information to allow other people
  to reproduce the problem. It may be in the form of the steps which are
  needed for recreating this problem.
* If the game crashed, in most cases it should create file *error.log* in
  *data* directory. It will be a lot of help if you can attach that file to the
  bug report. Every bug information in this file contains: Date when the crash
  occured, version of the game used, the source code file and line in this file.
  If game can't discover the source code file, it writes memory address instead.
  You can check this last information by using command `addr2line` in the
  directory where *steamsky* executable file is. Example:

  `addr2line -e steamsky [here full list of memory addresses from error.log]`

### Example of bug report:

Title: "Game crashed when entering a base"

Body:

1. Dock to the base
2. Open the base actions menu
3. Select option "Trade" from the menu with arrows keys
4. Press enter
5. Game crashed

## Features propositions

At this moment, please, don't give any propositions about new game features or
mechanics. I have my own long TODO list and your propositions may be duplicates or
go against my ideas. Of course, if you really want it, you can always start
discussion about a new feature, just I'm afraid, it may take a long time to
implement it into the game.

If you want to talk/propose changes to any existing features/mechanics in the game,
feel free to contact with me via options available at [contact page](https://www.laeran.pl/repositories/steamsky/wiki?name=Contact).
General rule about propositions is same as for bugs reports - please, try to
write as much information as possible. This help us better understand the
purpose of your changes.

List of things which I wish to add to the game, can be found [here](https://www.laeran.pl/repositories/steamsky/wiki?name=To-Do)
Please read carefully the description on how to discuss or how they will be
implemented in the game.

## Code propositions

### General information

If you want start helping in the development of the gane, please consider starting with
something easy like fixing bugs. Before you begin to add new feature to
the game, please contact with me options available at [contact page](https://www.laeran.pl/repositories/steamsky/wiki?name=Contact).
Same as with features proposition - your code may "collide" with my work and
at this moment you may just lose time by working on it. So it is better that
we first discuss your proposition. In any other case, fell free to fix and or
improve my code.

### Coding standard

The full description of coding style used by the project, you can find on the
[Coding Standard](https://www.laeran.pl/repositories/steamsky/wiki?name=Coding%20Standard) page.
On the page [Testing the Project](https://www.laeran.pl/repositories/steamsky/wiki?name=Testing%20the%20Project) you will
find information how to test your code, so it will be compliant with the
project standards.

#### Code comments formatting

The game uses [ROBODoc](https://rfsber.home.xs4all.nl/Robo/) for generating
code documentation. When you write your own code, please add proper header
documentation to it. If you use Vim/NeoVim, the easiest way is to use plugin
[RoboVim](https://github.com/thindil/robovim). Example of documentation
header:

    1 -- ****f* Utils/GetRandom
    2 -- FUNCTION
    3 -- Return random number from Min to Max range
    4 -- PARAMETERS
    5 -- Min - Starting value from which generate random number
    6 -- Max - End value from which generate random number
    7 -- RESULT
    8 -- Random number between Min and Max
    9 -- SOURCE
    10 function GetRandom(Min, Max: Integer) return Integer;
    11 -- ****

1 - Documentation header. Steam Sky uses `-- ****[letter]* [package]/[itemname]`
format for documentation headers.

2-9 - Documentation. For all available options, please refer to ROBODoc
documentation. Steam sky uses `-- ` for start all documentation lines.

10 - Source code of item.

11 - Documentation footer. Steam Sky uses `-- ****` for closing documentation.

How to generate the code documentation is described in main *README.md* file.

### Code submission
A preferred way to submit your code is to use [tickets](https://www.laeran.pl/repositories/steamsky/ticket)
on the project page. Please attach to that ticket file with diff changes,
the best if done with command `fossil patch`. Another diff program will
work too. In that situation, please add information which program was used to
create the diff file. If you prefer you can also use other options from
[contact page](https://www.laeran.pl/repositories/steamsky/wiki?name=Contact).

## Additional debugging options

### Code analysis

To enable check for `gcov` (code coverage) and `gprof` (code profiling) compile
the game with mode `analyze` (in the main project directory, where
*steamsky.gpr* file is):

`gprbuild -XMode=analyze`

or, if you prefer (and you have installed), use [Bob](https://www.laeran.pl/repositories/bob):

`bob analyze`

More information about code coverage and profiling, you can find in the proper
documentation for both programs.

#### Generating reports

After running the game in `analyze` mode, you can generate reports by using
command:

`gprof bin/steamsky gmon.out` for generate report for the code profiling

or, if you prefer (and you have installed), use [Bob](https://www.laeran.pl/repositories/bob):

`bob gprof`

### Generating unit tests

To generate (or regenerate) unit tests use command `gnattest` which generate
skeletons code for tests units (in the main project directory, where
*steamsky.gpr* file is):

`gnattest -P steamsky.gpr`

or, if you prefer (and you have installed), use [Bob](https://www.laeran.pl/repositories/bob):

`bob createtests`

Tests are generated only for these subprograms which have explicitly declared
tests cases in declarations. Thus, if here are no tests cases declared in the
game code, there will be no unit tests generated.

### Running unit tests

First, you must build all tests. How to do it, is described in main
*README.md* file. Then, in console, in the main project directory, type:
`others/tests.sh [amount]`

or, if you prefer (and you have installed), use [Bob](https://www.laeran.pl/repositories/bob):

`bob tests [amount]`

The `[amount]` is how many times the tests should be run. It is recommended
to run them few times in a row to catch all problems. Tests will stops if there
will be any problem. At this moment unit tests are available only on Linux.

More information about GnatTest (how to create unit test, etc.) you can find
[here](http://docs.adacore.com/live/wave/gnat_ugn/html/gnat_ugn/gnat_ugn/gnat_utility_programs.html#the-unit-test-generator-gnattest).
