## General Info

Steam Sky is an open source roguelike with a steampunk setting. You are the
commander of a flying ship, as leader you will be traveling across floating
bases, engaging in combat, trading goods etc. There is no mandatory ending
to the game, you may freely play until your character dies. The game is
currently in constant development, but is in a playable state. Steam Sky is
available for Linux and Windows 64-bit platforms. If you read this file
on GitHub: **please don't send pull requests here**. All will be automatically
closed. Any code propositions should go to the [Fossil](https://www.laeran.pl/repositories/steamsky) repository.

## Game versions

There are currently 2 versions of the game:

* 9.0.x: "stable" version of game. This version will receive bug fixes but
  no new features. Source code for this version is in the *9.0* branch.
* 10.x: "development" version of game, future version 10.0. This is where
  game feature updates happen. Due to new features, save compatibility
  will typically break between releases. Use this version at your own risk.
  Source code for this version is in the *trunk* branch. **This** version.

## Build game from sources

At this moment the only supported way to build the game is to use Docker images.
Later the normal way will back.

### Docker way

You can use Docker images `build` and `buildwin64` from the project
[Docker](https://github.com/thindil/docker). They contain all libraries

and compiler needed to build the game.

To build the game for Linux, download `build` image and type in console:

`docker run --rm -v [path to source code]:/app ghcr.io/thindil/build /bin/bash -c "cd /app && others/build.tcl"`

To build the game for Windows 64-bit, download `buildwin64` image and type in console:

`docker run --rm -v [path to source code]:/app ghcr.io/thindil/buildwin64 /bin/bash -c "cd /app && others/build.tcl x86_64-linux-gnu"`

It will build the game and put all needed files (except libraries) to directory
*release* in the project root directory (where file steamsky.gpr is).

### Build unit tests

Use the script `tests.nims` from the `others` directory. In the project's main
directory (where this file is):

* From console: type `others/tests.nims 1`. The argument is how many times
  repeat the tests.

The project's tests use package [unittest2](https://github.com/status-im/nim-unittest2),
thus all its runtime options can be used to run the tests.

## Generating code documentation

To generate (or regenerate) code documentation, you need [ROBODoc](https://rfsber.home.xs4all.nl/Robo/).
If you have it, in main program directory (where this file is) enter terminal
command: `others/generatedocs.tcl`. For more information about this script,
please look [here](https://github.com/thindil/roboada#generatedocspy). This
version of script have set all default settings for Steam Sky code.

## Running Steam Sky

If you compiled the game just clicking on (or executing in console) `steamsky`
(on Linux) or `steamsky.exe` (on Windows) in `bin` directory should run it.
If you use the downloaded version, the executable file is in the main
directory.

### Libraries needed to run the game

Additionally, the game requires a few more libraries to run. They are included
in the releases:

* TkLib. Included in MagicSplat version for Windows, on Linux should
  be available in all mayor distributions.

* Tk extension *tksvg*. You can get it from:

   <https://github.com/auriocus/tksvg>

* Tk extension *extrafont*. You can get it from:

   <https://wiki.tcl-lang.org/page/extrafont>

### Starting parameters
You can specify the game directories through command-line parameters.
Possible options are:

* --datadir=[directory] This is where the game data files are kept.
   Example: `./steamsky --datadir=/home/user/game/tmp`.
   Default value is *data/*

* --savedir=[directory] This is where savegames and logs are kept.
   The Game must have written permission to this directory.
   Example: `./steamsky --savedir=/home/user/.saves`.
   Default value is *data/saves/*

* --docdir=[directory] This is where the game documentation is.
   Example `./steamsky --docdir=/usr/share/steamsky/doc`.
   Default value is *doc/*.

* --modsdir=[directory] This is where mods are loaded from.
   Example:`./steamsky --modsdir=/home/user/.mods`.
   Default value is *data/mods/*

* --themesdir=[directory] This is where custom themes are loaded from.
   Example: `./steamsky --themesdir=/home/user/.mods`.
   Default value is *data/themes/*

Of course, you can set all the parameters at once:
`./steamsky --datadir=somedir/ --savedir=otherdir/ --docdir=anotherdir/`

Paths to directories can be absolute or relative where file `steamsky` is. For
Windows, use `steamsky.exe` instead `./steamsky`. If you use AppImage version
of the game, you can also use all of this starting parameters.

### Testing versions

Here are available testing versions of the game. You can find them
in [GitHub Actions](https://github.com/thindil/steamsky/actions/workflows/ada-devel.yml).
Just select option from the list of results to see Artifacts list.
To use them, first you must download normal release. Then unpack files
(replace existing) to the proper location where the game is installed.

* steamsky-development-windows.tar contains Windows 64-bit version of the game.

* steamsky-development-linux.tar contains Linux 64-bit version of the game.

Size is a file's size after unpacking. You will download it compressed with
Zip.

## Modding Support
For detailed information about modifying various game elements or debugging
game, see [MODDING.md](bin/doc/MODDING.md)

## Contributing to project
For detailed information about contributing to the project
(bug reporting, ideas propositions, code conduct, etc),
see [CONTRIBUTING.md](bin/doc/CONTRIBUTING.md)

## Licenses
The game is available under the GPLv3 license.

The Tashy library distributed with the game is under GPLv2 license with the
linking exception.

Tcl/Tk, Tklib, Tksvg and Extrafont libraries distributed with the game are
under BSD-like license.

The Licensing for the fonts distributed with the game is as follows:

* Font Amarante is under SIL Open Font License: https://fonts.google.com/specimen/Amarante
* Font Rye is under Open Font License: https://fonts.google.com/specimen/Rye
* Font Hack Nerd Font is under MiT license: https://nerdfonts.com/
* Font Roboto is under Apache v2.0 license: https://fonts.google.com/specimen/Roboto

All images used by the game are from https://game-icons.net, distributed under
CC-BY-3.0 license.


The changelog and a copy of the GPLv3 license can be found in the [doc](bin/doc) directory.

---
That's all for now, as usual, I have probably forgotten about something important ;)

Bartek thindil Jasicki
