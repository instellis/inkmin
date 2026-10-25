extends Node

var allknots:=[]:
	set(value): 
		allknots=value
		get_tree().root.get_node("Editor/inkminreader").allknots=value
var rootknot:={}
var currenteditorknot:={}
var sortededitorknot:=[]
var knotname:=""
var knotgroups:=[] # [{"name":"xxx","knots":[x,y,z]}]
var jsonfolder:="":
	set(value): 
		jsonfolder=value
		get_tree().root.get_node("Editor/%Languagemanager").jsonfolder=value
		get_tree().root.get_node("Editor/inkminreader").dialoguefolder=value
var languages:=["en"]:
	set(value): 
		languages=value
		get_tree().root.get_node("Editor/inkminreader").languages=value
		get_tree().root.get_node("Editor/inkminconverter").languages=value
var currentlang:="en":
	set(value): 
		currentlang=value
		get_tree().root.get_node("Editor/inkminreader").currentlang=value
		get_tree().root.get_node("Editor/inkminconverter").currentlang=value
var mainlang:="en":
	set(value): 
		mainlang=value
		get_tree().root.get_node("Editor/inkminconverter").mainlang=value

var editorlang:="en"
var editornode:Control # will be filled in by Editornode

func resetdata()->void:
	allknots=[]
	currenteditorknot={}
	sortededitorknot=[]
	rootknot={}
	knotname=""
	knotgroups=[]
	jsonfolder=""
	languages=["en"]
	currentlang="en"
	mainlang="en"

# -----------------------
# load & save settings

var eventsdir:=""
var dialogsdir:=""
var editor_font_size:=14
var knotlist_font_size:=12
var game_font_size:=16
var stitch_color:=Color(0.78, 0.78, 0.78, 0.45)
var codetag_color:=Color.DARK_CYAN
var goto_color:=Color.DARK_ORANGE
var choice_color:=Color.RED
var variable_color:=Color(0.4, 0.25, 0.65)

func save_settings():
	var path := "user://settings.txt"
	var file := FileAccess.open(path, FileAccess.WRITE)
	
	if file == null:
		print("Failed to open file for writing: " + path)
		return

	file.store_line("eventsdir=" + eventsdir)
	file.store_line("jsondir=" + dialogsdir)
	file.store_line("editor_font_size=" + str(editor_font_size))
	file.store_line("knotlist_font_size=" + str(knotlist_font_size))
	file.store_line("game_font_size=" + str(game_font_size))
	file.store_line("editorlang=" + editorlang)
	file.store_line("stitch_color=" + stitch_color.to_html())
	file.store_line("codetag_color=" + codetag_color.to_html())
	file.store_line("goto_color=" + goto_color.to_html())
	file.store_line("choice_color=" + choice_color.to_html())
	file.store_line("variable_color=" + variable_color.to_html())

func load_settings():
	var path := "user://settings.txt"
	
	if not FileAccess.file_exists(path):
		print("Settings file not found: " + path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("Failed to open settings file.")
		return

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():continue
		var parts := line.split("=")
		if parts.size() != 2: continue
		var key := parts[0]
		var value := parts[1]
		match key:
			"eventsdir": eventsdir = value
			"jsondir": dialogsdir = value
			"editor_font_size": editor_font_size = clamp(value.to_int(), 12, 20)
			"knotlist_font_size": knotlist_font_size = clamp(value.to_int(), 10, 20)
			"game_font_size": game_font_size = clamp(value.to_int(), 12, 20)
			"editorlang": editorlang = value
			"stitch_color": stitch_color = Color.from_string(value, stitch_color)
			"codetag_color": codetag_color = Color.from_string(value, codetag_color)
			"goto_color": goto_color = Color.from_string(value, goto_color)
			"choice_color": choice_color = Color.from_string(value, choice_color)
			"variable_color": variable_color = Color.from_string(value, variable_color)
