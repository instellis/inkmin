extends Control

signal changed
signal deleterequested(groupUID: String)

var groupUID := ""
var graph_position := Vector2.ZERO
var graph_size := Vector2(320, 220)
var current_zoom := 1.0
var header_height := 34.0
var resize_handle_size := 18.0
var min_graph_size := Vector2(300, 300)
var _header_px := 34.0
var _handle_px := 18.0
var _drag_mode := ""
var _drag_start_mouse_graph := Vector2.ZERO
var _drag_start_position := Vector2.ZERO
var _drag_start_size := Vector2.ZERO

var _name_edit: LineEdit = LineEdit.new()
var _delete_button: Button = Button.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE

	_name_edit.placeholder_text = "group"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(_on_name_changed)
	add_child(_name_edit)

	_delete_button.text = "x"
	_delete_button.flat = true
	_delete_button.pressed.connect(_on_delete_pressed)
	add_child(_delete_button)

	_update_child_layout()
	queue_redraw()

func setupgroup(newUID: String, groupname: String, groupposition: Vector2, groupsize: Vector2) -> void:
	groupUID = newUID
	_name_edit.text = groupname
	graph_position = groupposition
	graph_size = Vector2(max(groupsize.x, min_graph_size.x), max(groupsize.y, min_graph_size.y))
	custom_minimum_size = min_graph_size * current_zoom
	size = graph_size * current_zoom
	_update_child_layout()
	queue_redraw()

func synccanvas(scrolloffset: Vector2, zoom: float) -> void:
	current_zoom = max(zoom, 0.001)
	position = graph_position * current_zoom - scrolloffset
	custom_minimum_size = min_graph_size * current_zoom
	size = graph_size * current_zoom
	_update_child_layout()
	queue_redraw()

func getsavedata() -> Dictionary:
	return {
		"id": groupUID,
		"name": _name_edit.text,
		"coords": graph_position,
		"size": graph_size
	}

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var local_pos:Vector2 = event.position
			if Rect2(_delete_button.position, _delete_button.size).has_point(local_pos):
				return
			if _is_in_resize_handle(local_pos):
				_start_drag("resize", local_pos)
				accept_event()
				return
			if local_pos.y <= _header_px:
				_start_drag("move", local_pos)
				accept_event()
				return
			return
		_drag_mode = ""
		return

	if event is InputEventMouseMotion and _drag_mode != "":
		var mouse_graph:Vector2 = event.position / current_zoom
		if _drag_mode == "move":
			graph_position = _drag_start_position + (mouse_graph - _drag_start_mouse_graph)
		elif _drag_mode == "resize":
			var size_delta:Vector2 = mouse_graph - _drag_start_mouse_graph
			graph_size = Vector2(
				max(min_graph_size.x, _drag_start_size.x + size_delta.x),
				max(min_graph_size.y, _drag_start_size.y + size_delta.y)
			)
		changed.emit()
		accept_event()

func _draw() -> void:
	var border_color := Color(0.16, 0.31, 0.41, 0.85)
	var fill_color := Color(0.60, 0.78, 0.89, 0.18)
	var header_color := Color(0.60, 0.78, 0.89, 0.35)
	draw_rect(Rect2(Vector2.ZERO, size), fill_color, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, _header_px)), header_color, true)
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, 2.0)
	var handle_size := Vector2(_handle_px, _handle_px)
	var handle_rect := Rect2(size - handle_size, handle_size)
	draw_rect(handle_rect, border_color, true)

func _start_drag(mode: String, local_mouse_pos: Vector2) -> void:
	_drag_mode = mode
	_drag_start_mouse_graph = local_mouse_pos / current_zoom
	_drag_start_position = graph_position
	_drag_start_size = graph_size

func _update_child_layout() -> void:
	_header_px = clamp(header_height * current_zoom, 24.0, 54.0)
	_handle_px = clamp(resize_handle_size * current_zoom, 14.0, 24.0)
	if not is_node_ready():
		return
	var margin := 6.0
	var delete_width := 28.0
	_name_edit.position = Vector2(margin, margin)
	_name_edit.size = Vector2(max(60.0, size.x - delete_width - margin * 3.0), max(22.0, _header_px - margin * 2.0))
	_delete_button.position = Vector2(max(margin, size.x - delete_width - margin), margin)
	_delete_button.size = Vector2(delete_width, max(22.0, _header_px - margin * 2.0))

func _is_in_resize_handle(local_pos: Vector2) -> bool:
	return local_pos.x >= size.x - _handle_px and local_pos.y >= size.y - _handle_px

func _on_name_changed(_new_text: String) -> void:
	changed.emit()

func _on_delete_pressed() -> void:
	deleterequested.emit(groupUID)
