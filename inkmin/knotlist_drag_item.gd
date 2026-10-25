extends Control

# used by UI.gd to make knots and groups draggable

var ui_helper:Node
var drag_item:Control
var drop_item: Control

func _get_drag_data(at_position:Vector2) -> Variant:
	if ui_helper == null or drag_item == null:return null
	var data:Variant = ui_helper.get_knot_list_drag_data(drag_item)
	if data != null:
		set_drag_preview(ui_helper.get_knot_list_drag_preview(drag_item))
	return data

func _can_drop_data(at_position:Vector2, data:Variant) -> bool:
	if ui_helper == null or drop_item == null: return false
	return ui_helper.can_drop_knot_list_item(drop_item, at_position, data)

func _drop_data(at_position:Vector2, data:Variant) -> void:
	if ui_helper == null or drop_item == null: return
	ui_helper.drop_knot_list_item(drop_item, at_position, data)
