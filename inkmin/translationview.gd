extends VBoxContainer

@onready var translationhelp:Label = $translationhelp
@onready var translationrows:VBoxContainer = $translationrows

func displaytranslationeditor(current_knot_name: String) -> void:
	cleartranslationrows()
	translationhelp.text = tr("Translation mode: use T to replace the current line text.")
	addtranslationline("=== " + current_knot_name + " ===", current_knot_name)

	for sortedbloc in Autoload.sortededitorknot:
		var bloc_id:String = str(sortedbloc.key)
		var bloc:Dictionary = Autoload.currenteditorknot[bloc_id]
		match bloc.type:
			"root":
				if bloc.has("variables"):
					for variable in bloc.variables:
						addtranslationline("VAR " + variable.name + " = " + str(variable.content), current_knot_name)
			"goto":
				var gotoline := "-> " + str(bloc.destination)
				for i in bloc.choicerank:
					gotoline = gotoline.indent("\t")
				addtranslationline(gotoline, current_knot_name)
			"signal":
				var signalline := "# " + str(bloc.instruction)
				for i in bloc.choicerank:
					signalline = signalline.indent("\t")
				addtranslationline(signalline, current_knot_name)
			"comment":
				var commentline := "// " + str(bloc.comtext)
				for i in bloc.choicerank:
					commentline = commentline.indent("\t")
				addtranslationline(commentline, current_knot_name)
			"execute":
				var executeline := "~ " + str(bloc.instruction)
				for i in bloc.choicerank:
					executeline = executeline.indent("\t")
				addtranslationline(executeline, current_knot_name)
			"stitch":
				addtranslationline("= " + str(bloc.name), current_knot_name)
			"text":
				var rawtext := gettextvalue(bloc.text, Autoload.currentlang)
				var textline := rawtext
				for i in bloc.choicerank:
					textline = textline.indent("\t")
				addtranslationline(textline, current_knot_name, {"bloc_id": bloc_id, "field": "text"}, gettextvalue(bloc.text, Autoload.mainlang), rawtext)
			"choice":
				var choicetext := gettextvalue(bloc.text, Autoload.currentlang)
				var prefix := ""
				for i in range(bloc.choicerank):
					prefix += "+"
				var indent := ""
				for i in range(max(bloc.choicerank - 1, 0)):
					indent += "\t"
				addtranslationline(indent + prefix + " " + choicetext, current_knot_name, {"bloc_id": bloc_id, "field": "text"}, gettextvalue(bloc.text, Autoload.mainlang), choicetext)
			"weave":
				var weavetext := gettextvalue(bloc.text, Autoload.currentlang)
				var weaveline := "- " + weavetext
				for i in bloc.choicerank:
					weaveline = weaveline.indent("\t")
				var weavetarget := {}
				var weavesource := ""
				if has_translatable_text(bloc.text):
					weavetarget = {"bloc_id": bloc_id, "field": "text"}
					weavesource = gettextvalue(bloc.text, Autoload.mainlang)
				addtranslationline(weaveline, current_knot_name, weavetarget, weavesource, weavetext)
			"condition":
				var openingline := "{" + str(bloc.condition) + ":"
				for i in bloc.choicerank:
					openingline = openingline.indent("\t")
				if bloc.consequences.size() == 1 and not (bloc.consequences[0] is Dictionary):
					var singleline := openingline + str(bloc.consequences[0]) + "}"
					addtranslationline(singleline, current_knot_name)
					continue
				addtranslationline(openingline, current_knot_name)
				for index in range(bloc.consequences.size()):
					var consequence = bloc.consequences[index]
					var consline := str(consequence)
					if consequence is Dictionary and consequence.get("type", "") == "choice":
						var choice_text := gettextvalue(consequence.get("text", ""), Autoload.currentlang)
						addtranslationline("\t+ " + choice_text, current_knot_name, {"bloc_id": bloc_id, "field": "conditional_choice_text", "index": index}, gettextvalue(consequence.get("text", ""), Autoload.mainlang), choice_text)
						for choice_index in range(consequence.get("consequences", []).size()):
							var choice_consequence = consequence["consequences"][choice_index]
							if choice_consequence is Dictionary:
								var raw_choice_consequence := gettextvalue(choice_consequence, Autoload.currentlang)
								addtranslationline("\t\t" + raw_choice_consequence, current_knot_name, {"bloc_id": bloc_id, "field": "conditional_choice_consequence", "index": index, "choice_index": choice_index}, gettextvalue(choice_consequence, Autoload.mainlang), raw_choice_consequence)
							else:
								addtranslationline("\t\t" + str(choice_consequence), current_knot_name)
					elif consequence is Dictionary:
						var rawcons := gettextvalue(consequence, Autoload.currentlang)
						consline = rawcons
						addtranslationline(consline.indent("\t"), current_knot_name, {"bloc_id": bloc_id, "field": "consequence", "index": index}, gettextvalue(consequence, Autoload.mainlang), rawcons)
					else:
						addtranslationline(consline.indent("\t"), current_knot_name)
				var closingline := "}"
				for i in bloc.choicerank:
					closingline = closingline.indent("\t")
				addtranslationline(closingline, current_knot_name)

func save_current_knot(current_knot_name: String) -> bool:
	if Autoload.jsonfolder == "" or current_knot_name == "" or Autoload.currenteditorknot.is_empty():
		return false
	var converter := getconverter()
	if converter == null:
		warning("Could not save translation line")
		return false
	Autoload.currenteditorknot = normalizeknotnumericfields(Autoload.currenteditorknot)
	return converter.save_dict_to_json_file(Autoload.currenteditorknot, Autoload.jsonfolder + current_knot_name + ".json")

func gettextvalue(value, lang: String) -> String:
	if value is Dictionary:
		return str(value.get(lang, ""))
	return str(value)

func has_translatable_text(value) -> bool:
	if value is Dictionary:
		return gettextvalue(value, Autoload.mainlang).strip_edges() != ""
	return str(value).strip_edges() != ""

func normalizeknotnumericfields(knot: Dictionary) -> Dictionary:
	var normalized:Dictionary = {}
	for key in knot.keys():
		var value = knot[key]
		if value is Dictionary:
			normalized[key] = normalizeknotnumericfields(value)
		elif value is Array:
			var normalized_array := []
			for item in value:
				if item is Dictionary:
					normalized_array.push_back(normalizeknotnumericfields(item))
				else:
					normalized_array.push_back(item)
			normalized[key] = normalized_array
		elif key == "choicerank" or key == "inkline":
			normalized[key] = int(value)
		else:
			normalized[key] = value
	return normalized

func cleartranslationrows() -> void:
	for item in translationrows.get_children():
		item.queue_free()

func maketranslationlabel(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = 3
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	return label

func addtranslationline(display_text: String, current_knot_name: String, target := {}, source_text: String = "", editable_text: String = "") -> void:
	var linebox := VBoxContainer.new()
	linebox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linebox.add_theme_constant_override("separation", 4)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if not target.is_empty():
		var button := Button.new()
		button.text = "T"
		button.custom_minimum_size = Vector2(24, 24)
		button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		button.connect("pressed", Callable(self, "open_translation_popup").bind(current_knot_name, target, source_text, editable_text))
		row.add_child(button)

	var label := maketranslationlabel(display_text)
	row.add_child(label)

	linebox.add_child(row)
	translationrows.add_child(linebox)

func open_translation_popup(current_knot_name: String, target: Dictionary, source_text: String, current_text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = tr("Replace translation")
	dialog.dialog_text = ""
	dialog.exclusive = true
	dialog.dialog_hide_on_ok = false
	dialog.size = Vector2(640, 360)
	dialog.add_cancel_button(tr("Cancel"))
	dialog.get_ok_button().text = tr("Apply")

	var layout := VBoxContainer.new()
	layout.custom_minimum_size = Vector2(600, 280)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 6)
	dialog.add_child(layout)

	var sourcelabel := Label.new()
	sourcelabel.text = tr("Source (%s):") % Autoload.mainlang
	layout.add_child(sourcelabel)

	var sourcedisplay := TextEdit.new()
	sourcedisplay.custom_minimum_size = Vector2(0, 90)
	sourcedisplay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sourcedisplay.editable = false
	sourcedisplay.wrap_mode = 1
	sourcedisplay.text = source_text
	layout.add_child(sourcedisplay)

	var translationlabel := Label.new()
	translationlabel.text = tr("Translation (%s):") % Autoload.currentlang
	layout.add_child(translationlabel)

	var translationinput := TextEdit.new()
	translationinput.custom_minimum_size = Vector2(0, 120)
	translationinput.size_flags_vertical = Control.SIZE_EXPAND_FILL
	translationinput.wrap_mode = 1
	translationinput.text = current_text
	layout.add_child(translationinput)

	dialog.connect("confirmed", func():
		if savetranslationchange(current_knot_name, target, translationinput.text):
			dialog.queue_free())
	dialog.connect("canceled", func(): dialog.queue_free())

	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()
	await get_tree().process_frame
	translationinput.grab_focus()

func savetranslationchange(current_knot_name: String, target: Dictionary, new_text: String) -> bool:
	if Autoload.jsonfolder == "" or current_knot_name == "" or Autoload.currenteditorknot.is_empty():
		return false
	var bloc_id := str(target.get("bloc_id", ""))
	if bloc_id == "" or not Autoload.currenteditorknot.has(bloc_id):
		warning("Could not save translation line")
		return false

	var bloc:Dictionary = Autoload.currenteditorknot[bloc_id]
	match str(target.get("field", "")):
		"text":
			if bloc.text is Dictionary:
				bloc.text[Autoload.currentlang] = new_text
			else:
				var localized := {Autoload.mainlang: str(bloc.text)}
				for lang in Autoload.languages:
					if lang != Autoload.mainlang and not localized.has(lang):
						localized[lang] = "<<translation>>"
				localized[Autoload.currentlang] = new_text
				bloc.text = localized
		"consequence":
			var index := int(target.get("index", -1))
			if index < 0 or index >= bloc.consequences.size():
				warning("Could not save translation line")
				return false
			if bloc.consequences[index] is Dictionary:
				bloc.consequences[index][Autoload.currentlang] = new_text
			else:
				warning("Could not save translation line")
				return false
		"conditional_choice_text":
			var conditional_index := int(target.get("index", -1))
			if conditional_index < 0 or conditional_index >= bloc.consequences.size() or not (bloc.consequences[conditional_index] is Dictionary):
				warning("Could not save translation line")
				return false
			var conditional_choice: Dictionary = bloc.consequences[conditional_index]
			if conditional_choice.get("type", "") != "choice" or not (conditional_choice.get("text", "") is Dictionary):
				warning("Could not save translation line")
				return false
			conditional_choice["text"][Autoload.currentlang] = new_text
			bloc.consequences[conditional_index] = conditional_choice
		"conditional_choice_consequence":
			var conditional_consequence_index := int(target.get("index", -1))
			var choice_index := int(target.get("choice_index", -1))
			if conditional_consequence_index < 0 or conditional_consequence_index >= bloc.consequences.size() or not (bloc.consequences[conditional_consequence_index] is Dictionary):
				warning("Could not save translation line")
				return false
			var conditional_choice_with_consequence: Dictionary = bloc.consequences[conditional_consequence_index]
			if conditional_choice_with_consequence.get("type", "") != "choice" or choice_index < 0 or choice_index >= conditional_choice_with_consequence.get("consequences", []).size():
				warning("Could not save translation line")
				return false
			if conditional_choice_with_consequence["consequences"][choice_index] is Dictionary:
				conditional_choice_with_consequence["consequences"][choice_index][Autoload.currentlang] = new_text
				bloc.consequences[conditional_consequence_index] = conditional_choice_with_consequence
			else:
				warning("Could not save translation line")
				return false
		_:
			return false

	Autoload.currenteditorknot[bloc_id] = bloc
	var editor := geteditor()
	if editor:
		editor.knotchanged = true
	if not save_current_knot(current_knot_name):
		return false

	if editor:
		editor.knotchanged = false
		editor.displayeditor()
	return true

func geteditor() -> Node:
	return owner

func getconverter() -> Node:
	var editor := geteditor()
	if editor and editor.has_node("inkminconverter"):
		return editor.get_node("inkminconverter")
	return null

func warning(message: String) -> void:
	var editor := geteditor()
	if editor and editor.has_method("warning"):
		editor.warning(message)
