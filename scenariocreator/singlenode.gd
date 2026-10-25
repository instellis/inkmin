extends GraphNode

func _ready() -> void:
	theme = load("res://scenariocreator/singlenode.theme")
	var changebutton:=Button.new()
	changebutton.text="C" ; changebutton.size=Vector2(30,30)
	changebutton.connect("pressed",renamenodetype)
	get_titlebar_hbox().add_child(changebutton)
	var closebutton:=Button.new()
	closebutton.text="x" ; closebutton.size=Vector2(30,30)
	closebutton.connect("pressed",deletenode)
	get_titlebar_hbox().add_child(closebutton)

func renamenodetype() -> void:
	var eventscreator = get_tree().get_first_node_in_group("eventscreator")
	if eventscreator != null and has_meta("nodetype"):
		eventscreator.renamenodetypepopup(str(get_meta("nodetype")))

func deletenode() -> void:
	var eventscreator = get_tree().get_first_node_in_group("eventscreator")
	if eventscreator != null and eventscreator.has_method("delete_graph_node"):
		eventscreator.delete_graph_node(self)
	else:
		queue_free()
