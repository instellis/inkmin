extends Panel

# general UI helper functions

const MAX_FONT_SIZE:=20
const EDITOR_FONT_MIN_SIZE:=12
const KNOT_LIST_FONT_MIN_SIZE:=10
const GAME_FONT_MIN_SIZE:=12

signal knot_list_reordered

@onready var knot_list:VBoxContainer = %knotlist
@onready var json_panel:Panel = %jsonpanel
@onready var main_split:HSplitContainer = json_panel.get_parent() as HSplitContainer
@onready var editor_split:HSplitContainer = json_panel.get_node("HBox") as HSplitContainer
@onready var knot_panel:Panel = editor_split.get_node("Panelleft") as Panel
@onready var editor_panel:Panel = editor_split.get_node("Panelright") as Panel
@onready var knot_menu:Control = knot_panel.get_node("margins/VBox/knotsmenu") as Control
@onready var editor_menu:Control = %menu
@onready var game_menu:HBoxContainer = %hideshow.get_parent()

var game_panel_expanded:=true
var game_size_flags:=0
var editor_size_flags:=0
var json_size_flags:=0
var saved_knot_width:=0.0
var saved_main_offset:=0
var saved_editor_offset:=0
var split_clamp_queued:=false

# Called by Godot when the UI enters the scene tree and its children are ready.
func _ready() -> void:
	%inktext.syntax_highlighter=LineHighlighter.new()
	game_size_flags=%gameview.size_flags_horizontal
	editor_size_flags=editor_panel.size_flags_horizontal
	json_size_flags=json_panel.size_flags_horizontal
	%hideshow.pressed.connect(_on_hideshow_pressed)
	%hideeditor.pressed.connect(_on_hideeditor_pressed)
	editor_split.dragged.connect(_on_split_dragged)
	main_split.dragged.connect(_on_split_dragged)
	editor_split.resized.connect(queue_split_clamp)
	main_split.resized.connect(queue_split_clamp)
	set_game_panel_expanded(true)
	queue_split_clamp()

# ----------------------------------
# Functions for applying UI settings

# Connected to the text editor's font + and -
func fontzoom(direction:String) -> void:
	change_font_size(&"editor_font_size", EDITOR_FONT_MIN_SIZE, direction)

# Connected to the knot list font + and - 
func knotlistfontzoom(direction:String) -> void:
	change_font_size(&"knotlist_font_size", KNOT_LIST_FONT_MIN_SIZE, direction)

# Connected to the game preview font + and - 
func gamefontzoom(direction:String) -> void:
	change_font_size(&"game_font_size", GAME_FONT_MIN_SIZE, direction)

func change_font_size(setting_name:StringName, minimum_size:int, direction:String) -> void:
	var step:=1 if direction == "+" else -1
	var font_size:=clampi(int(Autoload.get(setting_name))+step, minimum_size, MAX_FONT_SIZE)
	Autoload.set(setting_name, font_size)
	apply_font_settings()
	Autoload.save_settings()

func apply_font_settings() -> void:
	%inktext.add_theme_font_size_override("font_size", Autoload.editor_font_size)
	apply_knot_list_font_size(knot_list, Autoload.knotlist_font_size)
	apply_game_font_size(%gamedisplay, Autoload.game_font_size)

func apply_knot_list_font_size(node:Node, font_size:int) -> void:
	var button:=node as Button
	var label:=node as Label
	if button != null and button.name == "knot":
		button.add_theme_font_size_override("font_size", font_size)
	elif label != null and label.name == "groupname":
		label.add_theme_font_size_override("font_size", font_size+2)
	for child in node.get_children():
		apply_knot_list_font_size(child, font_size)

func apply_game_font_size(node:Node, font_size:int) -> void:
	var rich_text:=node as RichTextLabel
	var button:=node as Button
	if rich_text != null:
		for font_type in ["normal_font_size", "bold_font_size", "bold_italics_font_size", "italics_font_size", "mono_font_size"]:
			rich_text.add_theme_font_size_override(font_type, font_size)
	elif button != null:
		button.add_theme_font_size_override("font_size", font_size)
	for child in node.get_children():
		apply_game_font_size(child, font_size)

# ----------------------------------------------
# Functions for highlighting editor lines

class LineHighlighter extends SyntaxHighlighter:
	# determine the color to be used depending on tags
	func get_line_style(line:String) -> Dictionary:
		var text:=line.strip_edges()
		if text.begins_with("= "):
			return {"background_color": Autoload.stitch_color}
		if text.begins_with("#"):
			return {"color": Autoload.codetag_color}
		if text.begins_with("->"):
			return {"color": Autoload.goto_color}
		if text.begins_with("~"):
			return {"color": Autoload.variable_color}
		if text.begins_with("+"):
			return {"color": Autoload.choice_color, "start": line.find(text), "length": text.length()-text.lstrip("+").length()} # only the tag
		return {}

	# Called by TextEdit when it needs the font color for a line.
	func _get_line_syntax_highlighting(line:int) -> Dictionary:
		var text:=get_text_edit().get_line(line)
		var style:=get_line_style(text)
		var normal_color:=get_text_edit().get_theme_color("font_color")
		var highlighting:={}
		if style.has("color"):
			var start:int=style.get("start", 0)
			highlighting[start]={"color": style.color}
			if style.has("length"):
				highlighting[start+style.length]={"color": normal_color}
		var trimmed:=text.strip_edges()
		if not trimmed.begins_with("//") and (trimmed.begins_with("{") or trimmed.ends_with("}")):
			var text_color:Color=style.get("color", normal_color) if not style.has("length") else normal_color
			for column in text.length():
				if text[column]=="{" or text[column]=="}":
					highlighting[column]={"color": Autoload.choice_color}
					highlighting[column+1]={"color": text_color}
		return highlighting

# Called by editor.gd after startup, displaying or editing text, and by Settings after color changes.
func highlight_lines() -> void:
	var highlighter=%inktext.syntax_highlighter
	highlighter.clear_highlighting_cache()
	for line_index in range(%inktext.get_line_count()):
		var style:Dictionary=highlighter.get_line_style(%inktext.get_line(line_index))
		# Keep backgrounds used by root validation warnings.
		if %inktext.get_line_background_color(line_index)==Color.LIGHT_CORAL:
			continue
		%inktext.set_line_background_color(line_index, style.get("background_color", Color.TRANSPARENT))

# ----------------------------------------------
# Functions for handling split UI panels

# main objective: split UI containers should not eat each other 

# Called by Godot for engine notifications, including editor language changes.
func _notification(event:int) -> void:
	# necessary to adapt split UI to new language in menus
	if event == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		queue_split_clamp()

# Connected in _ready() to both split containers' dragged signals.
func _on_split_dragged(_offset:int) -> void:
	# triggered when a split UI panel is dragged
	queue_split_clamp()

# Called on startup, split resize/drag, translation changes, and panel toggles.
func queue_split_clamp() -> void:
	if split_clamp_queued: return
	split_clamp_queued=true
	call_deferred("clamp_split_offsets")

# Deferred by queue_split_clamp() so layout can update before clamping.
func clamp_split_offsets() -> void:
	split_clamp_queued=false
	update_split_minimum_widths()
	editor_split.clamp_split_offset()
	main_split.clamp_split_offset()

# Called by clamp_split_offsets() before clamping the dividers.
func update_split_minimum_widths() -> void:
	var editor_controls:Control=editor_menu if %textzone.visible else %hideeditor
	for panel_and_menu in [[knot_panel, knot_menu], [editor_panel, editor_controls], [%gameview, game_menu]]:
		var panel:=panel_and_menu[0] as Panel
		var menu_bar:=panel_and_menu[1] as Control
		var horizontal_margins:=0
		for child in panel.get_children():
			var margins:=child as MarginContainer
			if margins != null:
				horizontal_margins=margins.get_theme_constant(&"margin_left") + margins.get_theme_constant(&"margin_right")
				break
		panel.custom_minimum_size.x=ceil(menu_bar.get_combined_minimum_size().x + horizontal_margins)
	if not %textzone.visible and game_panel_expanded:
		knot_panel.custom_minimum_size.x=max(knot_panel.custom_minimum_size.x, saved_knot_width)
	json_panel.size_flags_horizontal=json_size_flags if %textzone.visible or not game_panel_expanded else Control.SIZE_SHRINK_BEGIN
	var editor_width:=knot_panel.custom_minimum_size.x + editor_panel.custom_minimum_size.x + editor_split.get_theme_constant(&"separation")
	editor_split.custom_minimum_size.x=editor_width
	json_panel.custom_minimum_size.x=editor_width
	main_split.custom_minimum_size.x=editor_width + %gameview.custom_minimum_size.x + main_split.get_theme_constant(&"separation")

func _on_hideeditor_pressed() -> void:
	var expanded:bool=not %textzone.visible
	if not expanded:
		saved_knot_width=knot_panel.size.x
		saved_main_offset=main_split.split_offset
		saved_editor_offset=editor_split.split_offset
	for child in %consolemenu.get_children():
		if child is CanvasItem and child != %hideeditor:
			child.visible=expanded
	for child in %consolemenu.get_parent().get_children():
		if child is CanvasItem and child != %consolemenu:
			child.visible=expanded
	%hideeditor.text="hide editor" if expanded else "show editor"
	editor_split.dragging_enabled=expanded
	editor_split.dragger_visibility=SplitContainer.DRAGGER_VISIBLE if expanded else SplitContainer.DRAGGER_HIDDEN
	editor_panel.size_flags_horizontal=editor_size_flags if expanded else Control.SIZE_SHRINK_BEGIN
	queue_split_clamp()
	if expanded:
		# Restore the outer divider first, then the inner one after it resizes.
		await get_tree().process_frame
		if not %textzone.visible:return
		main_split.split_offset=saved_main_offset
		await get_tree().process_frame
		if %textzone.visible:editor_split.split_offset=saved_editor_offset

# Connected in _ready() to the game panel's hide/show button.
func _on_hideshow_pressed() -> void:
	set_game_panel_expanded(not game_panel_expanded)

# Called on startup, hide/show button presses, and settings language changes.
func set_game_panel_expanded(expanded:bool) -> void:
	game_panel_expanded=expanded
	main_split.dragging_enabled=expanded
	main_split.dragger_visibility=SplitContainer.DRAGGER_VISIBLE if expanded else SplitContainer.DRAGGER_HIDDEN
	var game_content:VBoxContainer=game_menu.get_parent() as VBoxContainer
	for child in game_menu.get_children():
		if child is CanvasItem and child != %hideshow:
			child.visible=expanded
	for child in game_content.get_children():
		if child is CanvasItem and child != game_menu:
			child.visible=expanded
	%hideshow.text="hide game" if expanded else "show game"
	if expanded:
		%gameview.size_flags_horizontal=game_size_flags
	else:
		%gameview.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	queue_split_clamp()

# ----------------------------------------------
# Functions for dragging knots and groups around

# Called by editor.gd when it creates knot buttons or group controls.
func setup_knot_list_drag(item:Control) -> void:
	if item == null:
		return
	setup_knot_list_drag_child(item, item)
	if item.has_node("knot"):
		setup_knot_list_drag_child(item.get_node("knot"), item)
		setup_knot_list_drag_child(item.get_node("spacer"), item)
	elif item.has_node("VBox/menu"):
		setup_knot_list_drag_child(item.get_node("VBox/menu"), item)
		setup_knot_list_drag_child(item.get_node("VBox/menu/VBox/groupname"), item)
		setup_knot_list_drag_child(item.get_node("VBox/menu/VBox/spacer"), item)

# Called by setup_knot_list_drag() for the item itself and its child controls.
func setup_knot_list_drag_child(control:Control, item:Control) -> void:
	control.set_script(preload("res://inkmin/knotlist_drag_item.gd"))
	control.ui_helper = self
	control.drag_item = item
	control.drop_item = item

# Called by knotlist_drag_item.gd when Godot requests data to start a drag.
func get_knot_list_drag_data(item:Control) -> Variant:
	if not is_knot_list_draggable(item):
		return null
	return {"source": item}

# Called by knotlist_drag_item.gd after it obtains valid drag data.
func get_knot_list_drag_preview(item:Control) -> Control:
	var preview:=Label.new()
	preview.text = str(item.get_meta("name"))
	preview.add_theme_font_size_override("font_size", 12)
	preview.modulate = Color(1, 1, 1, 0.8)
	return preview

# Called by knotlist_drag_item.gd while Godot checks a potential drop target.
func can_drop_knot_list_item(target:Control, at_position:Vector2, data:Variant) -> bool:
	return get_knot_list_drop_index(target, at_position, data) != -1

# Called by knotlist_drag_item.gd when Godot accepts a drop.
func drop_knot_list_item(target:Control, at_position:Vector2, data:Variant) -> void:
	var drop_index:=get_knot_list_drop_index(target, at_position, data)
	if drop_index == -1:
		return
	var source:=data["source"] as Control
	var target_container:=get_knot_list_drop_container(source, target)
	if target_container == null:
		return
	var old_parent:=source.get_parent()
	var old_index:=source.get_index()
	if old_parent != target_container:
		old_parent.remove_child(source)
		target_container.add_child(source, true)
	target_container.move_child(source, drop_index)
	if old_parent != source.get_parent() or old_index != source.get_index():
		knot_list_reordered.emit()

# Called by can_drop_knot_list_item() and drop_knot_list_item().
func get_knot_list_drop_index(target:Control, at_position:Vector2, data:Variant) -> int:
	if not (data is Dictionary) or not data.has("source"):
		return -1
	var source:=data["source"] as Control
	if not is_knot_list_draggable(source):
		return -1
	if target == null or target == source:
		return -1
	var target_container:=get_knot_list_drop_container(source, target)
	if target_container == null:
		return -1
	var drop_index:=0
	if target_container == knot_list or target.get_parent() == target_container:
		drop_index = target.get_index()
	else:
		drop_index = target_container.get_child_count()
	if at_position.y > target.size.y * 0.5:
		drop_index += 1
	if source.get_parent() == target_container and source.get_index() < drop_index:
		drop_index -= 1
	var first_index:=0
	if target_container == knot_list:
		first_index = get_knot_list_first_movable_index()
	var last_index:=target_container.get_child_count()
	if source.get_parent() == target_container:
		last_index -= 1
	return clamp(drop_index, first_index, last_index)

# Called when starting a drag and when validating a drop's source item.
func is_knot_list_draggable(item:Control) -> bool:
	if item == null:
		return false
	if item.name.contains("model"):
		return false
	if item.get_meta("drag_type", "") == "":
		return false
	if item.get_meta("name", "") == "root":
		return false
	var container:=get_knot_list_item_container(item)
	if container == null:
		return false
	if container == knot_list:
		return item.get_index() >= get_knot_list_first_movable_index()
	return true

# Called when calculating a drop index and when moving the dropped item.
func get_knot_list_drop_container(source:Control, target:Control) -> Control:
	if source == null or target == null:
		return null
	var source_type:=str(source.get_meta("drag_type", ""))
	var target_type:=str(target.get_meta("drag_type", ""))
	if target.name.contains("model"):
		return null
	if source_type == "group":
		if target.get_parent() == knot_list:
			return knot_list
		return null
	if source_type == "knot":
		if target_type == "knot":
			return get_knot_list_item_container(target)
		if target_type == "group" and target.has_node("VBox/knots"):
			return target.get_node("VBox/knots") as Control
	return null

# Called by is_knot_list_draggable() and get_knot_list_drop_container().
func get_knot_list_item_container(item:Control) -> Control:
	if item == null: return null
	var parent:=item.get_parent()
	if parent == knot_list:
		return knot_list
	if parent is VBoxContainer and parent.name == "knots":
		return parent as Control
	return null

# Called when checking draggability and limiting drops in the main knot list.
func get_knot_list_first_movable_index() -> int:
	for item in knot_list.get_children():
		if item.get_meta("name", "") == "root":
			return item.get_index() + 1
	return 3
