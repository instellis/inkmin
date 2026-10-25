# Editor help

## Editor

### Starting a project
Creating a project requires choosing a project folder first, in which the story sequence will be saved as `.json` files. 
Every project must start with a `root` knot, which defines languages and, if needed, the variables of the story. 
This root knot can only contain the vartiable definitions, languages and end with a `->` tag leading to a first story knot.

### Knots
A knot is a "scene", which has a name and includes various "blocs" of instructions such as dialogs and code instructions. 
In practice, one knot becomes one `.json` file stored in your project folder and loaded into the game.
See the Inkmin language help sections to understand how the content of knots must be drafted.  

### Blocs
Inside a knot, the story is made of lines of narrative instructions: plain text that will be displayed, choices, consequences of choices, conditions with consequences, signals to the game code, or comments. 
The editor shows these blocs in a plain readable format, but in the backend they are transformed into instructions stored in the `.json` files, including the translations. 
When a line is simply plain text it will be read by the game as plain text, but when it starts with a tag such as `#`, `+`, or `-`, those tags give instructions to the game code.

### File system
The editor expects a project folder that contains `root.json` and the other knot files beside it. You must always chose a single folder to contain all of these json files.
Loading a project means selecting the `root.json` corresponding to the project. Creating a new project means choosing an empty or dedicated folder where the editor can create the `root.json` file and the other knot files.

### Editor layout
The left panel is a project structure view, which lists the knots. The knots listed there can be organized in groups, but that has no consequence on the game code, it only serves readability purposes. 
The center panel is the text editor in which the scenario is written, like in an ordinary text editor. 
The right panel is a game simulation that allows testing the scenario and also displays the variables in the bottom part.

### Languages
There is a main language, which is editable, and there can be translation languages, which are read-only. This is important to preserve all the instructions that are given to the code in the main language.
If nothing is specified, English (`en`) is the default language of the scenario. Other languages can be specified in the root knot. 
The language manager can export a `.tsv` file for use in spreadsheets to outsource translations and then import it back into the `.json` files.
But translations can also be made directly by clicking on the button next to each line when choosing a language other than the main language.

### Scenario creator
The scenario creator is a separate helper editor for planning scenario graphs. See the Scenario creator help tab for details.

### Ink converter
The ink export and import buttons are an attempt at exporting one single file containing the whole scenario in text format. 
This can serve as backup or also for use in other game systems. Importing requires chosing a project folder first and it will create all json files in that folder.
Be careful to test results, as conversion may not be perfect because ink and inkmin language implementation is not 100% ne the sale. 

## Inkmin language

### Basic scenario structure
All knots start with a header, with its name included in `===` tags.

Example:
```text
=== scene 1 ===
```
The knot name is always required when you create the knot. It can be changed by clicking the button next to its name.

The first knot is always named `=== root ===` and its content is limited to metadata.
For example, this `root` knot defines English as the main language, French as a translation language, and a starting value for the `score` variable, then jumps to the first story knot, `intro`:

```text
=== root ===
# LANG=en,fr
# VAR score = 0
-> intro
```

### Plain lines of text
Any line that is not preceded by a tag is a plain line of text. The game will then treat it as planned by the game code, for example by displaying it somewhere on screen, as a dialog or plain text.
This is the default behaviour for any text that is not preceded by a recognized tag. 

### Choices
Lines starting with the `+` tag create choices. More `+` tags mean deeper choice rank.

Example:
```text
+ this is my first choice
  ++ this is a subchoice that comes after my first choice
+ this is my second choice
```

### Stitches
Stitches are named sections inside a knot. Start a stitch with `= stitch_name`; it can contain the same story blocks as a knot. Divert to a stitch in the same knot with `-> stitch_name`, or to one in another knot with `-> knot_name.stitch_name`. Stitch names must be unique within their knot.

### Weaves
Lines starting with the `-` tag are weave lines. They are used to create a common final consequence for all choice branches. After various choices and their consequences, the weave line creates a new instruction in the narrative flow that closes the choice phase. It can be followed by one or several lines of instructions or plain text.

Example:
```text
+ choice 1
  consequence 1
+ choice 2
  consequence 2
-
consequence of both choice 1 and choice 2
```

### Gotos
Lines starting with `-> "destination"` jump to the destination knot. This allows navigating from knot to knot.

### Signals
Lines starting with the `# "instruction"` tag emit a signal that the game code can react to. What the instruction is depends on each game and needs to be implemented in the game code.
This can only have an effect if the syntax expected by the game code is complied with.

Example:
```text
# playsound : dingdong
```

### Variables
Variables must be defined in the root knot, for example `# VAR variable = 0`. Values may be integers, decimals, Booleans (`true` and `false`), or strings (i.e. simple text).
Variable names ignore case and accents. When saving JSON, Inkmin stores them in uppercase without Latin accents: `activité` becomes `ACTIVITE`. Story text and string values keep their accents.
The variable manager also applies this conversion and saves changed JSON files when it checks the project.
Variables can then be manipulated later in other knots with simple operations using the `~` tag.

Example:
```text
~ variable = 0
~ variable = variable + 1
```

### Comments
Lines starting with `// blablabla` are comments and are ignored by the game code.

### Conditions
Conditions use the form `{condition:consequence}`. Multi-line consequences are also supported by the editor.
To require cumulative conditions, write them in one condition expression using `&&`: `{condition_1 && condition_2: consequence}`.
Acceptable conditions are mathematical conditions: =, < or >
Acceptable consequences are : text, goto, variable manipulation and choices

Example:
```text
{myvariable = 0 : my variable is empty}
```
or 
```text
{myvariable = 0 : 
my variable is empty
this is a second line
}
```

## Implementation

The Inkmin GitHub repository at `https://github.com/instellis/inkmin` contains the editor source code and a Godot integration example. The reader script, sample scene, and JSON files mentioned in this chapter are all in its `samples/` folder; paths beginning with `samples/` are relative to the root of that repository.

### Add the inkmin reader to a Godot game

- Copy `samples/inkminreader.gd` from the repository and your Inkmin-generated JSON files into your Godot project. Keep `root.json` and all the knot JSON files in one folder.
- Add a `Node` to the game scene and attach `inkminreader.gd` to it. The script parses the JSON files at runtime and emits a signal called `inkminfeed` with a dictionary for each narrative event.
- Connect your game code to the `inkminfeed` signal, as described in the next section, and interpret the dictionary to display dialogue, create choice buttons, and react to story instructions.

### Connect your game code to the inkmin reader
In the script that controls the dialogue UI, get a reference to the reader node. Set `dialoguefolder` to the folder containing the JSON files, including a trailing slash. Connect `inkminfeed` before starting the story so the first events are received. Call `initiatedialogs()` to load the languages, variables, and knot list from `root.json`, set `currentlang`, then call `loadandstartknot("root")`.

For example, if the reader node is named `inkminreader` and the JSON files are in `res://dialogues/`:

```gdscript
@onready var inkmin = $inkminreader

func _ready() -> void:
	inkmin.dialoguefolder = "res://dialogues/"
	inkmin.inkminfeed.connect(_on_inkminfeed)
	inkmin.initiatedialogs()
	inkmin.currentlang = inkmin.languages[0]
	inkmin.loadandstartknot("root")

func _on_inkminfeed(output: Dictionary) -> void:
	print(output)
```

### Handle reader events
Check which key the `output` dictionary contains:

- `text`: display the line of dialogue or narration.
- `choice`: display a button using `output.choice`. When the player selects it, call `inkmin.choicemade(str(output.next), str(output.get("blocid", "")))` to continue.
- `choicemade`: clear the previous choices or dialogue before showing the consequence.
- `signal`: interpret `output.signal` as a game-specific instruction, such as playing a sound.
- `newknot`: update the UI when the story moves to another knot.
- `varchange`: read the changed value from `inkmin.playervars` and update any game state that depends on it.
- `theend`: handle the end of the dialogue.

For a working example, open the repository as a Godot project, run `samples/dialogbox_example.tscn`, and inspect `samples/dialogbox_example.gd` with the story files in `samples/jsons/`.

## Scenario creator

Scenario creator is a simple visual help for creating scenario graphs. It is separate from the Inkmin system. 
The scenario is stored as a separate JSON. Implementation by the game code based on the json could be contemplated in a later version.

### Add and edit nodes
The built-in node types are `cutscene`, `scenario event`, `dialog`, and `unlock tech`. Custome node types can be created (see below).
Click a node type in the top bar to add a node in the center of the current view. Fill in the node's name and description, and its conditions field when available. Drag the title bar to move a node and resize it using its bottom-right corner.

### Customize node types
Click `create node` to define a new node type. Enter a unique name and optionally enable `Add condition` to include a conditions field. The new type appears as a button in the top bar; click it to create nodes of that type.
Click `C` in a node's title bar to rename its type. This updates all nodes of that type, rather than the name field of a single node.
Use `erase node` to remove a node type from the top bar. A type can only be erased when no nodes of that type remain on the canvas.

### Connect nodes
Drag connections from the port on the right side of a node to the port on the left side of another node to create a connection. To remove a connection, drag it away from its input port on the right-hand node.

### Organize with groups
Click `create group` to add a named box behind the nodes. Edit its name in the header, drag the header to move the box, and drag its bottom-right handle to resize it.
Groups are visual guides: moving a group does not move the nodes inside it. 

### Save and load
Click `save` to choose a `.json` file for the graph. It stores the node types, node text, positions, sizes, connections, and groups. The save button turns pink when changes need saving.
Click `load` to open a previously saved graph; loading replaces the current graph, so save any changes you want to keep first. 
