Some general informations about adding/editing some game elements (skills,
ships, ships modules, etc.)

## Skills

### General informations
- Open file *game.dat* in *data* directory and edit line which starts with
  SkillsNames.
- Each value for skills must be separated by comma and space: `, `
- Whole SkillsNames entry must be done in one line (if your text editor have
  automatic line wrap enabled, don't forget to fix it).

### Changing existing skills names
- You can change name of any existing skill, just remember, that first skill is
  always used by Pilot, second by Engineer, third by Gunner and forth by person
  who talk/trade in bases.
- After change skill name, you been need to made proper changes in other game
  data files (recipes, items)

### Adding new skills
- To add new skill, just append it name to SkillsNames entry.

## Items types

### General informations
- Open file *game.dat* in *data* directory and edit line which starts with
  ItemsTypes.
- Each value for item type must be separated by comma and space: `, `
- Whole ItemsTypes entry must be done in one line (if your text editor have
  automatic line wrap enabled, don't forget to fix it).

### Changing existing items types
- After change of Item Type don't forget to do proper changes in other data
  files (like items or recipes) and in this same file if item type was used in
  one of below settings.

### Adding new items types
- To add new item type, just append it name to ItemsTypes entry.
- Each new ammunition type must starts with `Ammo` (example: *Ammo150*).

## Repair tools type
To change which item type is used for repair/upgrading tools, open file 
*game.dat* in *data* directory and edit line which starts with RepairTools.
Value after equal sign must be existing item type.

## Cleaning tools type
To change which item type is used for cleaning ship, open file *game.dat* in 
*data* directory and edit line which starts with CleaningTools. Value after 
equal sign must be existing item type.

## Healing tools type
To change which item type is used for healing crew members and for deliver
medicines to bases, open file *game.dat* in *data* directory and edit line
which starts with HealingTools. Value after equal sign must be existing 
item type.

## Player Ship index
To change which ship is used as a player ship, open file *game.dat* in *data*
directory and edit line which starts with PlayerShipIndex. Value after equal
sign must be existing ship index from any ships file from *data/ships*
directory.

## Alchemy tools type
To change which item type is used for deconstruct items, open file *game.dat* 
in *data* directory and edit line which starts with AlchemyTools. Value after 
equal sign must be existing item type.

## Drinks type
To change which item type is used for reduce thirst, open file *game.dat* 
in *data* directory and edit line which starts with DrinksType. Value after 
equal sign must be existing item type.

## Corpse index
To change which item is used as a body for dead, open file *game.dat* in *data*
directory and edit line which starts with CorpseIndex. Value after equal sign 
must be existing item index from any items file from *data/items* directory.

## Mission items type
To change which item type is used for delivery missions, open file *game.dat* 
in *data* directory and edit line which starts with MissionItemsType. Value 
after equal sign must be existing item type.

## Food items types
To change which items types are used as food, open file *game.dat* in *data*
directory and edit line which starts with FoodTypes. First type is main food
type, second type is used by crew members when first type isn't found in ship
cargo. Values after equal sign must be existing items types, separated by coma
and space: `, `.

## Fuel item type
To change which item type is used as a fuel for ship, open file *game.dat* in 
*data* directory and edit line which starts with FuelType. Value after equal 
sign must be existing item type.

## Money index
To change which item is used as a money, open file *game.dat* in *data* 
directory and edit line which starts with MoneyIndex. Value after equal sign 
must be existing item index from any items file from *data/items* directory.

## Items

### General informations
- Open file *items.dat* in *data/items* directory or create new file with *dat*
  extension in this directory (example: *myitems.dat*)
- Each value in item data structure must be one line length.
- File must end with `[]`.

### Item data structure
- Each item start from `[` symbol. Any value between `[` and `]` is a item
  index (it can be number or text) and must be unique. This value is used in
  ships and recipes data entries.
- Name: name of item displayed in various places (cargo info, crafting, etc.)
- Weight: weight of one item in kilograms
- Type: item type of item (from *game.dat* file, entry *ItemsTypes*)
- Prices: item base price in bases. Each value mean price in selected base
  type: Industrial, Agricultural, Refinery, Shipyard. If you want that item
  will be not possible to buy/sellable in bases (or only selected base type) 
  set it price to 0.
- Buyable: did item can be bough in selected type of base: Industrial,
  Agricultural, Refinery, Shipyard. Y mean yes, N means No.
- ShowType: optional parameter. If you want to show item type in game (for
  example in cargo or in trade screen) different than item type from *game.dat*
  file, you can set this parameter to any text value.
- Value: optional parameter. For 'Food' or 'Raw Food' it is value of hunger 
  reduced by one portion. For 'Drink', value of thirst reduced by one portion.
  For ammunition it is damage done by that ammunition. For working tools it is
  chance for item to be damaged during work.
- Description: Any length description of item.

## Recipes

### General informations
- Open file *recipes.dat* in *data/recipes* directory or create new file with
  *dat* extension in this directory (example: *myrecipes.dat*).
- Each value in recipe data structure must be one line length.
- File must end with `[]`.

### Recipe data structure
- Each recipe start from `[` symbol. Any value between `[` and `]` is a recipe 
  index (it can be number or text) and must be unique. This value is used at
  this moment for set starting recipes and in Craft types of goals.
- Material: Item type of materials need for recipe. Each material must be
  separated with `, ` (comma and space)
- Amount: Amount of crafting materials needed for recipe. If you set more than
  one material for recipe, you must set amount for each of them. Each material
  amount must be separated with `, ` (comma and space)
- Result: Item index which will be produced by recipe (you can check this index
  in *items* directory)
- Crafted: Amount of items crafted from one recipe
- Workplace: Type of ship module in which recipe is made. Available options
  are: Alchemy\_Lab, Furnace, Water\_Collector, Workshop, Greenhouse
- Skill: Name of skill used during crafting selected recipe (skills names are
  in *game.dat* file)
- Tool: Type of item used as tool in crafting selected recipe (items types are
  in *game.dat* file)
- Difficulty: optional parameter. How complicated recipe is. Should be between 
  1 and 100.
- BaseType: In which bases type recipe can be bought. If not set, recipe will be
  know from beginning of game. Values: 1 for Industrial, 2 for Agricultural, 3
  for Refinery and 4 for Shipyard
- Time: optional parameter. How long in minutes take crafting selected recipe.
  If not set, it take 15 minutes.

## Ship modules

### General informations
- Open file *shipmodules.dat* in *data/shipmodules* directory or create new
  file with *dat* extension in that directory (example: *myshipmodules.dat*).
- Each value in ship module data structure must be one line length.
- File must end with `[]`.

### Ship module data structure
- Each ship module start from `[` symbol. Any value between `[` and `]` is a
  module index (it can be number or text) and must be unique. This value is
  used in ships data entries.
- Name: Standard name of module. Will be visible in ship info screen and in
  shipyards.
- Type: Type of module. Available options are: Engine, Cabin, Cockpit, Turret,
  Gun, Cargo, Hull, Armor, Battering\_ram, Alchemy\_Lab, Furnace,
  Water\_Collector, Workshop, Greenhouse, Medical\_room
- Weight: Weight of module in kilograms.
- Value: Depends on type of module. For 'Engine' it is fuel usage for travel by
  one map field. For 'Cabin' it is value of reduced tiredness of owner who rest
  there. For 'Gun' it is index of item type used as ammunition (item types are
  in *game.dat* file). For any other type of modules should be 0 (zero).
- MaxValue: Depends on type of module. For 'Hull' it is max free module space.
  For 'Engine' it is engine power. For 'Cabin' should be that same like Value
  value. For 'Cargo' it is maximum capacity in kilograms for cargo for that
  module. For 'Gun' or 'Battering\_ram' it is amount of damage done by selected
  weapon. For any other type of modules should be 0 (zero).
- Durability: Base durability of module. How many damage module can take before
  will be destroyed.
- Material: Type of item which will be used to repair or upgrade module.
- Skill: Name of skill which will be used during repair or upgrading module.
- Price: Base buy or sell price of module in shipyard.
- InstallTime: How long in minutes take install/remove selected module from
  ship.
- Unique: If set to 'Yes' then each ship can have only one module of that type.
- Size: Amount of hull module space used by module.
- Description: Any length description of ship module.

## Ships

### General informations
- Open file *ships.dat* in *data/ships* directory or create new file with *dat*
  extension in that directory (example: *myships.dat*).
- Each value in ship data structure must be one line length.
- File must end with `[]`.

### Ship data structure
- Each ship start from `[` symbol. Any value between `[` and `]` is a index 
  (it can be number or text) and must be unique. This value is used at this
  moment to set player ship and in Destroy types of goals.
- Name: Type of ship. Will be visible during combat information.
- Modules: List of modules indexes (from *shipmodules* directory), separated 
  by `, ` (comma and space).
- Accuracy: Bonus to accuracy for ship. Can be constant value (example: 1) or 
  range from minimum value to max value, separated by `..` (double dots)
  (example: 1..5).
- CombatAI: Behavior of ship in combat (NPC ships only). Possible values are:
  Berserker - attack to end, no matter how heavy damage take.
  Attacker - aggressive but will be run away from combat when lost all
  ammunition or weapons.
  Coward - try run from combat, attack only in self-defense.
  Disarmer - same as Attacker but first aim for player ship weapons before
  start destroying ship.
- Evasion: Bonus to evasion for ship. Can be constant value or range from 
  minimum value to max value, separated by `..` (double dots).
- Loot: Amount of moneys earned for destroying that ship. Can be constant value
  or range from minimum value to max value, separated by `..` (double dots).
- Perception: Bonus to perception for ship. Can be constant value or range 
  from minimum value to max value, separated by `..` (double dots).
- Cargo: List of cargo of ship. Each item in cargo is separated by `, ` (comma
  and space). Each item entry is Amount`x`Item index (from *items* directory).
  Amount can be constant value or range from minimum value to max value, 
  separated by `..` (double dots).
- Skills: List of crew members skills and its levels. Each crew member skills
  list is separated by `; ` (semicolon and space). Each crew member skill is
  separated by `, ` (comma and space).
- Orders: Orders for each crew member. Must be in this same amount as skills of
  crew members. Possible values are: Pilot, Engineer, Gunner, Repair, Craft,
  Upgrading, Talk, Heal, Clean, Rest.
- Description: Any length description of ship.
- Owner: Which fraction own ship. Possible values are: Poleis, Independent,
  Pirates, Undead, Drones, Inquisition.
- Priorities: Orders priorities for each crew member (player ship only). Must
  be in this same amount as skills of crew members. Each priority entry is
  Order`:`Priority where Order is: Piloting, Engineering, Operating guns, 
  Repair ship, Manufacturing, Upgrading ship, Talking in bases, Healing 
  wounded, Cleaning ship and Priority is: Normal or Highest (one per crew 
  member).
- Recipes: List of know recipes indexes (from *recipes* directory, player ship
  only), separated by `, ` (comma and space).

## Help

### General informations
- Open file *help.dat* in *data/help* directory or create new file with *dat* 
  extension in that directory (example: *myhelp.dat*).
- File must end with `[]`.

### Help data structure
- Each help entry starts from `[` symbol. Any value between `[` and `]` is a
  menu entry in main help menu. It can be number or text.
- Whole text below (until next new line which starts from `[`) is help entry
  text visible when player select this option from help menu.

## Goals

### General informations
- Open file *goals.dat* in *data/goals* directory or create new file with *dat*
  extension in that directory (example: *mygoals.dat*).
- Each value in goal data structure must be one line length.
- File must end with `[]`.

### Goal data structure
- Each ship start from `[` symbol. Any value between `[` and `]` is a index 
  (it can be number or text) and must be unique. At this moment this value is
  used to set/update goal in game.
- Type: Type/category of goal which define what is needed to do for finish
  selected goal. Possible values: Reputation - gain max reputation in X bases,
  Destroy - destroy X ships, Discover - discover X fields of map, Visit - visit
  (discover) X bases, Craft - craft X items
- Amount: Amount of target for selected goal to do for finish it. For example
  100 ships to destroy, etc.
- Target: Optional parameter, ignored for Discover type, exact target for 
  goal, depends on type of goal. Possible values: for Reputation and Visit, 
  bases owners names: Poleis, Independent, Pirates, Undead, Drones, 
  Inquisition. For Destroy, any enemy ship index (from *ships* directory). For
  Craft, recipe index (from *recipes* directory).

## Debugging
If you want test your changes, you may run game in debug mode. In this mode
game create file *debug.log* in *data* directory. To start game in debug mode
run it with parameter --debug=[debugtype]. Example:

`./steamsky --debug=everything`

At this moment available are two types of debug:

- Option 'everything' mean to log each debug message to file. At this moment
  this mean informations about loading game data (ships/recipes/items/modules)
  and some combat data. This option may be useful to check correctness of data
  of added new items, etc.
- Option 'combat' mean to log debug messages only from combat.

