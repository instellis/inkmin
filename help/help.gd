extends AcceptDialog

# Help script, triggered by pressing the help button in the editor
# Reads help files depending on language and displays them

# NB: MD format is used so help can also be used on Github

@onready var tabs: TabContainer = %Tabs

func _ready() -> void:
	load_help_content() 

# Called when window opens but also by editor when language changes 
func load_help_content() -> void:
	var path := "%s/help.%s.md" % ["res://help", Autoload.editorlang]
	var markdown:=""
	if FileAccess.file_exists(path): 
		markdown = FileAccess.get_file_as_string(path)

	var help_title := "Editor help"
	var sections: Array = []
	var current_title := ""
	var current_lines: Array[String] = []

	for raw_line in markdown.split("\n", true):
		var line := raw_line.rstrip("\r")
		if line.begins_with("# ") and sections.is_empty() and current_title == "":
			help_title = line.trim_prefix("# ").strip_edges()
			continue
		if line.begins_with("## "): # sections begin with ##
			if current_title != "":
				sections.push_back({
					"title": current_title,
					"body": _markdown_to_bbcode("\n".join(current_lines))
				})
			current_title = line.trim_prefix("## ").strip_edges()
			current_lines.clear()
			continue
		current_lines.push_back(line)

	if current_title != "":
		sections.push_back({
			"title": current_title,
			"body": _markdown_to_bbcode("\n".join(current_lines))
		})

	if sections.is_empty():
		sections.push_back({"title": "Help", "body": _markdown_to_bbcode(markdown)})

	title = help_title
	for child in tabs.get_children():
		tabs.remove_child(child)
		child.queue_free()

	# create one tab per section
	for index in sections.size():
		var section: Dictionary = sections[index]
		var container := MarginContainer.new()
		container.name = "Section%d" % index
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.add_theme_constant_override("margin_left", 8)
		container.add_theme_constant_override("margin_top", 8)
		container.add_theme_constant_override("margin_right", 8)
		container.add_theme_constant_override("margin_bottom", 8)

		var scroll := ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.size_flags_vertical = Control.SIZE_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.text = str(section.get("body", ""))
		scroll.add_child(text)
		container.add_child(scroll)

		tabs.add_child(container)
		tabs.set_tab_title(index, str(section.get("title", "Help")))

	if tabs.get_tab_count() > 0: tabs.current_tab = 0

# conversion of MD format to bbcode for richtextlabel node
func _markdown_to_bbcode(markdown: String) -> String:
	var output: Array[String] = []
	var in_code_block := false
	var code_lines: Array[String] = []

	for raw_line in markdown.split("\n", true):
		var line := raw_line.rstrip("\r")
		var trimmed := line.strip_edges()
		if trimmed.begins_with("```"):
			if in_code_block:
				output.push_back("[indent][code]%s[/code][/indent]" % "\n".join(code_lines))
				code_lines.clear()
			else:
				code_lines.clear()
			in_code_block = not in_code_block
			continue
		if in_code_block:
			code_lines.push_back(line.replace("[", "[lb]"))
			continue
		if trimmed.begins_with("### "):
			if not output.is_empty() and output[-1] != "": output.push_back("")
			output.push_back("[b]%s[/b]" % _format_inline_markdown(trimmed.trim_prefix("### ").strip_edges()))
			continue
		if trimmed.begins_with("- "):
			output.push_back("• %s" % _format_inline_markdown(trimmed.trim_prefix("- ").strip_edges()))
			continue
		output.push_back(_format_inline_markdown(line))

	if in_code_block:
		output.push_back("[indent][code]%s[/code][/indent]" % "\n".join(code_lines))

	var normalized_output: Array[String] = []
	var previous_blank := false
	for entry in output:
		var is_blank := entry == ""
		if is_blank and previous_blank:
			continue
		normalized_output.push_back(entry)
		previous_blank = is_blank
	return "\n".join(normalized_output).strip_edges()

func _format_inline_markdown(text: String) -> String:
	var formatted := text.replace("[", "[lb]")
	formatted = _replace_inline_pairs(formatted, "**", "[b]", "[/b]")
	formatted = _replace_inline_pairs(formatted, "`", "[code]", "[/code]")
	return formatted

func _replace_inline_pairs(text: String, marker: String, open_tag: String, close_tag: String) -> String:
	var result := ""
	var search_from := 0
	var open := true
	while true:
		var index := text.find(marker, search_from)
		if index == -1:
			result += text.substr(search_from)
			break
		result += text.substr(search_from, index - search_from)
		result += open_tag if open else close_tag
		open = not open
		search_from = index + marker.length()
	return result
