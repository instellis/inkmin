extends Control

# script for the inkmin settings menu

const MAX_FONT_SIZE := 20
const EDITOR_FONT_MIN_SIZE := 12
const KNOT_LIST_FONT_MIN_SIZE := 10
const GAME_FONT_MIN_SIZE := 12

@onready var editor_language: OptionButton = $Panel/Margins/VBox/EditorLanguageRow/EditorLanguage
@onready var editor_font_size: Label = $Panel/Margins/VBox/EditorFontSize/Value
@onready var knot_list_font_size: Label = $Panel/Margins/VBox/KnotListFontSize/Value
@onready var game_font_size: Label = $Panel/Margins/VBox/GameFontSize/Value
@onready var stitch_color: ColorPickerButton = $Panel/Margins/VBox/StitchColor/Color
@onready var codetag_color: ColorPickerButton = $Panel/Margins/VBox/CodetagColor/Color
@onready var goto_color: ColorPickerButton = $Panel/Margins/VBox/GotoColor/Color
@onready var choice_color: ColorPickerButton = $Panel/Margins/VBox/ChoiceColor/Color
@onready var variable_color: ColorPickerButton = $Panel/Margins/VBox/VariableColor/Color

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	refresh_settings()

func _on_visibility_changed() -> void:
	if visible: refresh_settings()

func refresh_settings() -> void:
	editor_font_size.text = str(Autoload.editor_font_size)
	knot_list_font_size.text = str(Autoload.knotlist_font_size)
	game_font_size.text = str(Autoload.game_font_size)
	stitch_color.color = Autoload.stitch_color
	codetag_color.color = Autoload.codetag_color
	goto_color.color = Autoload.goto_color
	choice_color.color = Autoload.choice_color
	variable_color.color = Autoload.variable_color
	# language selector
	editor_language.clear()
	var languages:Array[String] = available_editor_languages()
	if not languages.has(Autoload.editorlang):
		languages.push_front(Autoload.editorlang)
	for language in languages:
		editor_language.add_item(language)
		if language == Autoload.editorlang:
			editor_language.select(editor_language.get_item_count() - 1)

func available_editor_languages() -> Array[String]:
	var languages:Array[String] = []
	for language in TranslationServer.get_loaded_locales():
		if not language.is_empty(): languages.append(language)
	if languages.is_empty(): languages.append("en")
	languages.sort()
	return languages

func _on_editor_language_item_selected(index:int) -> void:
	Autoload.editorlang = editor_language.get_item_text(index)
	TranslationServer.set_locale(Autoload.editorlang)
	var ui:=get_parent()
	ui.call(&"set_game_panel_expanded", ui.get(&"game_panel_expanded"))
	if Autoload.editornode != null:
		Autoload.editornode.resetlangmenu()
	Autoload.save_settings()

func _on_editor_font_size_pressed(direction:String) -> void:
	change_font_size(&"editor_font_size", EDITOR_FONT_MIN_SIZE, direction)

func _on_knot_list_font_size_pressed(direction:String) -> void:
	change_font_size(&"knotlist_font_size", KNOT_LIST_FONT_MIN_SIZE, direction)

func _on_game_font_size_pressed(direction:String) -> void:
	change_font_size(&"game_font_size", GAME_FONT_MIN_SIZE, direction)

func change_font_size(setting_name:StringName, minimum_size:int, direction:String) -> void:
	var step:=1 if direction == "+" else -1
	var font_size:=clampi(int(Autoload.get(setting_name)) + step, minimum_size, MAX_FONT_SIZE)
	Autoload.set(setting_name, font_size)
	get_parent().call(&"apply_font_settings")
	Autoload.save_settings()
	refresh_settings()

# Connected to the highlighting color pickers in editor.tscn.
func _on_highlight_color_changed(color:Color, setting_name:StringName) -> void:
	Autoload.set(setting_name, color)
	get_parent().call(&"highlight_lines")
	Autoload.save_settings()

func close_pressed() -> void:
	hide()
