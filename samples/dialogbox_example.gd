extends Control

@export var use_linebreaks := true # wait for "OK" before next line, or not

@onready var inkmin = $inkminreader
var dialogue_blocks: Array[Dictionary] = []
const theroot := "res://samples/jsons/" # location of jsons

# internal use for linebreak system
var waiting_for_linebreak := false 
var linebreak_processing_scheduled := false

# signals triggered by json parsing
signal narrative_signal(instruction: String)
signal knot_changed(knot_name: String)
signal variable_changed(variable_name: String, value: Variant)
signal dialogue_ended

func _ready() -> void:
	%LinebreakButton.pressed.connect(continue_linebreak)
	%LinebreakButton.hide()
	inkmin.dialoguefolder = theroot
	inkmin.inkminfeed.connect(_on_inkminfeed)
	inkmin.initiatedialogs()
	if not inkmin.languages.is_empty(): inkmin.currentlang = inkmin.languages[0]
	inkmin.loadandstartknot("root")

# -----------------------------------
# ---- inkmin standard functions ----

# This looping function parses the jsons and implements them
func _on_inkminfeed(output: Dictionary) -> void:
	if output.has("text") or output.has("choice"):
		if use_linebreaks:
			dialogue_blocks.push_back(output)
			if not linebreak_processing_scheduled and not waiting_for_linebreak:
				linebreak_processing_scheduled = true
				call_deferred("show_next_linebreak_blocks")
		else:
			show_dialogue_block(output)
	# consequences of a choice
	elif output.has("choicemade"):
		dialogue_blocks.clear()
		waiting_for_linebreak = false
		%LinebreakButton.hide()
		%dialogtext.clear()
		for button in %choices.get_children():
			button.queue_free()
	# emits a signal to be executed
	elif output.has("signal"):
		var instruction := str(output.signal)
		narrative_signal.emit(instruction)
		handle_narrative_signal(instruction)
	# changes knot
	elif output.has("newknot"):
		dialogue_blocks.clear()
		waiting_for_linebreak = false
		%LinebreakButton.hide()
		%dialogtext.clear()
		knot_changed.emit(str(output.newknot))
	# emits a signal to be executed
	elif output.has("varchange"):
		var variable_name := str(output.varchange)
		var value = inkmin.playervars.get(variable_name)
		variable_changed.emit(variable_name, value)
		handle_variable_changed(variable_name, value)
	# emits a signal ending the dialog
	elif output.has("theend"):
		dialogue_blocks.clear()
		waiting_for_linebreak = false
		%LinebreakButton.hide()
		%dialogtext.clear()
		for button in %choices.get_children():
			button.queue_free()
		dialogue_ended.emit()
		handle_dialogue_end()

func show_next_linebreak_blocks() -> void:
	linebreak_processing_scheduled = false
	while not dialogue_blocks.is_empty():
		var block: Dictionary = dialogue_blocks.pop_front()
		show_dialogue_block(block)
		if block.has("text") and not dialogue_blocks.is_empty() and not dialogue_blocks[0].has("choice"):
			waiting_for_linebreak = true
			%LinebreakButton.show()
			return

func show_dialogue_block(block: Dictionary) -> void:
	# normal text (narrative or dialog)
	if block.has("text"):
		%dialogtext.add_text(str(block.text) + "\n")
		%dialogtext.scroll_to_line(%dialogtext.get_line_count())
	# choices
	elif block.has("choice"):
		var button := Button.new()
		button.text = str(block.choice)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			inkmin.choicemade(str(block.next), str(block.get("blocid", ""))))
		%choices.add_child(button)

# functions required when the linebreak bool is true
func _unhandled_input(event: InputEvent) -> void:
	if not use_linebreaks or not waiting_for_linebreak: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		continue_linebreak()
		get_viewport().set_input_as_handled()

func continue_linebreak() -> void:
	if not waiting_for_linebreak:return
	waiting_for_linebreak = false
	%LinebreakButton.hide()
	show_next_linebreak_blocks()

# ---------------------------------
# ---- game-specific functions ----

# Add consequences to game-specific narrative tags here
# E.g. background changes when the dialogue contains "# BG: forest".
func handle_narrative_signal(_instruction: String) -> void:
	pass

# Add game-specific consequences of variable changes
func handle_variable_changed(_variable_name: String, _value: Variant) -> void:
	pass

# Add game-specific end-of-dialogue behavior here
func handle_dialogue_end() -> void:
	pass
