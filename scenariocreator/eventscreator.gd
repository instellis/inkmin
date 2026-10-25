extends Panel

# Standalone scenario creator system
# Allows miro-style visual scenario  

const GROUPBOX_SCRIPT := preload("res://scenariocreator/groupbox.gd")

var nodes:={
	"cutscene":[{"name":"label"},{"description":"biglabel"},{"conditions":"biglabel"},{"color":Color.AQUAMARINE}],
	"event":[{"name":"label"},{"description":"biglabel"},{"conditions":"biglabel"},{"color":Color.ANTIQUE_WHITE}],
	"dialog":[{"name":"label"},{"description":"biglabel"},{"color":Color.LIGHT_YELLOW}],
	"tech":[{"name":"label"},{"description":"biglabel"},{"color":Color.SKY_BLUE}]
	}

var filedialogmission:="" # used by filedialog to know what to do
var UIDlist:=[] # stores all used UIDs
var theconnections:=[] # stores all connections based on UIDs
var unsavedchanges:=false
var eventsdir:="" # latest events directory
var nodetypetorename:String = ""
var groups:=[]
var grouplayer := Control.new()
var nodecolors := [
	Color(0.68, 0.85, 0.95, 1.0), # light blue
	Color(0.68, 0.88, 0.68, 1.0), # green
	Color(0.92, 0.63, 0.63, 1.0), # red
	Color(0.78, 0.78, 0.78, 1.0), # gray
	Color(0.96, 0.76, 0.84, 1.0)  # pink
]

func _ready() -> void:
	add_to_group("eventscreator")
	randomize()
	for but in nodes.keys():
		addnodetypebutton(but)
	grouplayer.name = "group_layer"
	grouplayer.set_anchors_preset(Control.PRESET_FULL_RECT)
	grouplayer.mouse_filter = Control.MOUSE_FILTER_PASS
	%thecanvas.add_child(grouplayer)
	%thecanvas.move_child(grouplayer, 0)
	%create_node.connect("pressed", Callable(self, "newnodetypepopup"))
	%create_group.pressed.connect(creategroup)
	%erase_node.connect("pressed", Callable(self, "erasenodetypepopup"))
	%thecanvas.connect("connection_request", Callable(self, "_node_connection_request"))
	%thecanvas.connect("disconnection_request", Callable(self, "_node_disconnection_request"))
	set_process(true)

func _process(_delta: float) -> void:
	syncgroups()

func _input(event: InputEvent) -> void:
	if unsavedchanges and event.is_action_pressed("savejson") and not %thefiledialog.visible:
		saveeventfile()
		get_viewport().set_input_as_handled()

func addnodetypebutton(nodetype:String) -> void:
	if %topmenu.has_node(NodePath(nodetype)):
		var thebutton:Button = %topmenu.get_node(NodePath(nodetype))
		var thecallable := createnode.bind(nodetype)
		if not thebutton.is_connected("pressed", thecallable):
			thebutton.connect("pressed", thecallable)
		return
	var thebutton := Button.new()
	thebutton.name = nodetype
	thebutton.text = nodetype.replace("_", " ")
	thebutton.connect("pressed", createnode.bind(nodetype))
	%topmenu.add_child(thebutton)
	%topmenu.move_child(thebutton, %topmenu.get_node("spacer").get_index())

func newnodetypepopup() -> void:
	%new_node_name.text = ""
	%new_node_has_condition.button_pressed = false
	%create_node_popup.popup_centered()
	%new_node_name.grab_focus()

func erasenodetypepopup() -> void:
	updateerasenodetypes()
	if %erase_node_type.item_count == 0:
		return
	%erase_node_popup.popup_centered()

func renamenodetypepopup(nodetype:String) -> void:
	if not nodes.has(nodetype):
		return
	nodetypetorename = nodetype
	%rename_node_name.text = nodetype.replace("_", " ")
	%rename_node_popup.popup_centered()
	%rename_node_name.grab_focus()

func updateerasenodetypes() -> void:
	%erase_node_type.clear()
	var nodetypes := nodes.keys()
	nodetypes.sort()
	for nodetype in nodetypes:
		%erase_node_type.add_item(nodetype.replace("_", " "))
		%erase_node_type.set_item_metadata(%erase_node_type.item_count - 1, nodetype)
	if %erase_node_type.item_count > 0:
		%erase_node_type.select(0)

func createnodetype() -> void:
	var rawname:String = %new_node_name.text.strip_edges()
	var nodename:String = rawname.to_lower().replace(" ", "_")
	if nodename == "":
		return
	if nodes.has(nodename):
		return

	var thedefinition := [
		{"name":"label"},
		{"description":"biglabel"}
	]
	if %new_node_has_condition.button_pressed:
		thedefinition.push_back({"conditions":"biglabel"})
	thedefinition.push_back({"color": nodecolors[randi() % nodecolors.size()]})

	nodes[nodename] = thedefinition
	addnodetypebutton(nodename)
	somethingchanged()
	%create_node_popup.hide()

func erasenodetype() -> void:
	if %erase_node_type.item_count == 0:
		return
	var selectedindex:int = %erase_node_type.get_selected_id()
	if selectedindex < 0:
		return
	var nodetype:String = str(%erase_node_type.get_item_metadata(selectedindex))
	if isnodetypeused(nodetype):
		%erase_node_popup.hide()
		%erase_node_warning.dialog_text = "Careful, you are using this node type in your project"
		%erase_node_warning.popup_centered()
		return

	nodes.erase(nodetype)
	if %topmenu.has_node(NodePath(nodetype)):
		%topmenu.get_node(nodetype).queue_free()
	somethingchanged()
	%erase_node_popup.hide()

func renamenodetype() -> void:
	var rawname:String = %rename_node_name.text.strip_edges()
	var newtype:String = rawname.to_lower().replace(" ", "_")
	if nodetypetorename == "":
		return
	if newtype == "":
		return
	if newtype == nodetypetorename:
		nodetypetorename = ""
		%rename_node_popup.hide()
		return
	if nodes.has(newtype):
		return

	var thedefinition = nodes[nodetypetorename]
	nodes.erase(nodetypetorename)
	nodes[newtype] = thedefinition
	renamenodetypebutton(nodetypetorename, newtype)
	updatenodetypes(nodetypetorename, newtype)
	nodetypetorename = ""
	somethingchanged()
	%rename_node_popup.hide()

func isnodetypeused(nodetype:String) -> bool:
	for child in %thecanvas.get_children():
		if child is GraphNode and child.has_meta("nodetype") and str(child.get_meta("nodetype")) == nodetype:
			return true
	return false

func renamenodetypebutton(oldtype:String, newtype:String) -> void:
	if %topmenu.has_node(NodePath(oldtype)):
		%topmenu.get_node(NodePath(oldtype)).queue_free()
	addnodetypebutton(newtype)

func updatenodetypes(oldtype:String, newtype:String) -> void:
	for child in %thecanvas.get_children():
		if child is GraphNode and child.has_meta("nodetype") and str(child.get_meta("nodetype")) == oldtype:
			child.set_meta("nodetype", newtype)
			child.title = newtype.to_upper()

func _on_close_pressed() -> void:
	hide()

# -----------------------
# create and change nodes

func createnode(nodetype:String, fromfile:=false, forced_uid:String="") -> GraphNode:
	# unknown node type (version problem)
	if not nodes.has(nodetype):
		var gnode := GraphNode.new()
		gnode.title = nodetype.to_upper() + " (MISSING)"
		gnode.set_meta("nodetype", nodetype)
		var label := Label.new()
		label.text = tr("Missing node type: %s") % nodetype
		gnode.add_child(label)
		var theUID := forced_uid if forced_uid != "" else generate_unique_id()
		UIDlist.push_back(theUID)
		gnode.set_meta("UID", theUID)
		gnode.name = theUID
		%thecanvas.add_child(gnode)
		return gnode
	# normal situation
	var gnode := GraphNode.new() ; gnode.size=Vector2(300,300) ; gnode.resizable=true
	gnode.script=load("res://scenariocreator/singlenode.gd")
	gnode.title = nodetype.to_upper()
	gnode.set_meta("nodetype",nodetype)
	for item in nodes[nodetype]:
		if item.has("color"): 
			if item["color"] is String:
				item["color"]= item["color"].strip_edges().trim_prefix("(").trim_suffix(")")
				var parts = item["color"].split(",", false)
				item["color"]=Color(parts[0].to_float(), parts[1].to_float(), parts[2].to_float(),1.0)
			var thestyle:StyleBoxFlat=gnode.get_theme_stylebox("titlebar").duplicate()
			thestyle.bg_color=item["color"]
			gnode.add_theme_stylebox_override("titlebar",thestyle)
			gnode.add_theme_stylebox_override("titlebar_selected",thestyle)
	for item in nodes[nodetype]:
		if item.has("color"):continue
		for key in item.keys():
			var title:=Label.new() ; title.text=key+":" ; gnode.add_child(title)
			if item[key]=="label":
				var theline:=LineEdit.new() ; gnode.add_child(theline)
				theline.connect("text_changed",somethingchanged)
			elif item[key]=="biglabel":
				var thebox:=TextEdit.new() ; thebox.custom_minimum_size.y=110; thebox.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY ; gnode.add_child(thebox)
				thebox.connect("text_changed",somethingchanged)
	var theUID := forced_uid if forced_uid != "" else generate_unique_id()
	UIDlist.push_back(theUID) ; gnode.set_meta("UID",theUID)
	gnode.name = theUID
	var view_center_graph := get_graph_view_center()
	%thecanvas.add_child(gnode)
	if not fromfile:
		_center_graph_node_in_view.call_deferred(gnode, view_center_graph)
	gnode.set_slot(0,true,0,Color.LIGHT_GRAY,true,0,Color.LIGHT_GRAY)
	if not fromfile:somethingchanged()
	return gnode

func delete_graph_node(gnode: GraphNode) -> void:
	if not is_instance_valid(gnode):
		return
	var uid := ""
	if gnode.has_meta("UID"):
		uid = str(gnode.get_meta("UID"))
	if uid != "":
		UIDlist.erase(uid)
		var remaining_connections := []
		for con in theconnections:
			if str(con["from_node"]) == uid or str(con["to_node"]) == uid:
				continue
			remaining_connections.push_back(con)
		theconnections = remaining_connections
	somethingchanged()
	gnode.queue_free()

func array_has_key(thearray:Array,thekey:String) -> bool:
	for item in thearray:
		if item is Dictionary and item.has(thekey):
			return true
	return false

func _center_graph_node_in_view(gnode: GraphNode, view_center_graph: Vector2) -> void:
	await get_tree().process_frame
	if not is_instance_valid(gnode):
		return
	gnode.position_offset = view_center_graph - gnode.size * 0.5

func get_graph_view_center() -> Vector2:
	return (%thecanvas.get_rect().size * 0.5 + %thecanvas.scroll_offset) / %thecanvas.zoom

func get_live_connections_from_canvas() -> Array:
	var live_connections := []
	for con in %thecanvas.get_connection_list():
		var from_node_name := str(con.get("from_node", ""))
		var to_node_name := str(con.get("to_node", ""))
		if not %thecanvas.has_node(NodePath(from_node_name)) or not %thecanvas.has_node(NodePath(to_node_name)):
			continue
		var from_uid := str(%thecanvas.get_node(NodePath(from_node_name)).get_meta("UID"))
		var to_uid := str(%thecanvas.get_node(NodePath(to_node_name)).get_meta("UID"))
		live_connections.push_back({
			"from_node": from_uid,
			"from_slot": int(con.get("from_slot", con.get("from_port", 0))),
			"to_node": to_uid,
			"to_slot": int(con.get("to_slot", con.get("to_port", 0)))
		})
	return live_connections

# called each time a connection is made between nodes 
func _node_connection_request(from_node, from_slot, to_node, to_slot)->void:
	somethingchanged()
	%thecanvas.connect_node(from_node, from_slot, to_node, to_slot)
	theconnections.push_back(
		{"from_node":%thecanvas.get_node(NodePath(from_node)).get_meta("UID"),"from_slot":from_slot,
		"to_node":%thecanvas.get_node(NodePath(to_node)).get_meta("UID"),"to_slot":to_slot})

func _node_disconnection_request(from_node, from_slot, to_node, to_slot)->void:
	somethingchanged()
	%thecanvas.disconnect_node(from_node, from_slot, to_node, to_slot)
	theconnections.erase(
		{"from_node":%thecanvas.get_node(NodePath(from_node)).get_meta("UID"),"from_slot":from_slot,
		"to_node":%thecanvas.get_node(NodePath(to_node)).get_meta("UID"),"to_slot":to_slot})

func somethingchanged(newstuff:="")->void:
	unsavedchanges=true
	%save.modulate=Color.LIGHT_PINK

# ---------------------------------------------
# group functions (groups gather several nodes)

func creategroup(fromfile:=false, data:Dictionary={}) -> GROUPBOX_SCRIPT:
	var thegroup := GROUPBOX_SCRIPT.new()
	var groupUID := str(data.get("id", ""))
	if groupUID == "":
		groupUID = generate_unique_id()
	var groupname := str(data.get("name", "group"))
	var groupposition:Vector2 = data.get("coords", get_graph_view_center() - Vector2(160, 110))
	var groupsize:Vector2 = data.get("size", Vector2(320, 220))
	grouplayer.add_child(thegroup)
	thegroup.setupgroup(groupUID, groupname, groupposition, groupsize)
	thegroup.changed.connect(somethingchanged)
	thegroup.deleterequested.connect(deletegroup)
	syncgroups()
	if not fromfile:
		somethingchanged()
	return thegroup

func syncgroups() -> void:
	grouplayer.size = %thecanvas.size
	for thegroup: GROUPBOX_SCRIPT in grouplayer.get_children():
		thegroup.synccanvas(%thecanvas.scroll_offset, %thecanvas.zoom)

func getgroupsfromcanvas() -> Array:
	var thegroups := []
	for thegroup: GROUPBOX_SCRIPT in grouplayer.get_children():
		thegroups.push_back(thegroup.getsavedata())
	return thegroups

func cleargroups() -> void:
	for child in grouplayer.get_children():
		grouplayer.remove_child(child)
		child.queue_free()
	groups.clear()

func deletegroup(groupUID:String) -> void:
	for thegroup: GROUPBOX_SCRIPT in grouplayer.get_children():
		if thegroup.groupUID == groupUID:
			grouplayer.remove_child(thegroup)
			thegroup.queue_free()
			somethingchanged()
			return

# ---------------------
# load / save functions

func saveeventfile()->void:
	# determine save file path 
	%thefiledialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
	%thefiledialog.filters=["*.json"]
	filedialogmission="saveevent"
	%thefiledialog.show() ; %thefiledialog.get_ok_button().text=tr("save")

func loadeventfile() -> void:
	# determine load file path 
	if Autoload.eventsdir!="":%thefiledialog.current_dir=Autoload.eventsdir
	%thefiledialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
	%thefiledialog.filters=["*.json"]
	filedialogmission="loadevent"
	%thefiledialog.show() ; %thefiledialog.get_ok_button().text=tr("load")

func _on_filedialog_file_selected(path: String) -> void:
	%thefiledialog.hide()
	match filedialogmission:
		"saveevent": 
			# 0 is the data structure as a dictionary, the rest are the nodes as dictionaries
			theconnections = get_live_connections_from_canvas()
			groups = getgroupsfromcanvas()
			var thedata:={} ; thedata["structure"]=nodes ; thedata["connections"]=theconnections ; thedata["groups"]=groups
			var thearray:=[] ; thearray.push_back(thedata)
			for nod in %thecanvas.get_children():
				if not nod.has_meta("UID"):continue
				var thenod:={}
				thenod["UID"]=nod.get_meta("UID") ; thenod["nodetype"]=nod.get_meta("nodetype")
				thenod["coords"]=nod.position_offset ; thenod["size"]=nod.size
				var offset:=0
				for itemnum in nod.get_child_count()/2: # store each pair (name, content)
					thenod[itemnum]={nod.get_child(offset+0).text:nod.get_child(offset+1).text}
					offset+=2
				thearray.push_back(thenod)
			# save json
			var error:=save_array_as_json(path,thearray)
			if error!=0:print("error in saving events json")
			else: unsavedchanges=false ; %save.modulate=Color.WHITE

		"loadevent":
			var f:=FileAccess.open(path,FileAccess.READ)
			var thearray:=[]
			if f != null: 
				var json := JSON.new()
				var thetext := f.get_as_text()
				var result = json.parse_string(thetext)
				if result is Array:thearray=result
				Autoload.eventsdir=path.get_base_dir()
				Autoload.save_settings()
			else: return
			# clear existing
			for child in %thecanvas.get_children(): 
				if child is GraphNode:child.queue_free()
			UIDlist.clear() ; theconnections.clear() ; cleargroups()
			# display nodes on graph canvas
			if thearray!=[]:
				theconnections=thearray[0]["connections"]
				groups=thearray[0].get("groups", [])
				# make sure node types are updated
				var loaded_nodes = thearray[0]["structure"]
				for key in loaded_nodes.keys():
					if not nodes.has(key):
						nodes[key] = loaded_nodes[key]
					addnodetypebutton(key)
				for groupdata in groups:
					if groupdata is Dictionary:
						if groupdata.get("coords", Vector2.ZERO) is String:
							groupdata["coords"]=groupdata["coords"].strip_edges().trim_prefix("(").trim_suffix(")")
							var groupparts = groupdata["coords"].split(",", false)
							groupdata["coords"]=Vector2(groupparts[0].to_float(), groupparts[1].to_float())
						if groupdata.get("size", Vector2.ZERO) is String:
							groupdata["size"]=groupdata["size"].strip_edges().trim_prefix("(").trim_suffix(")")
							var sizeparts = groupdata["size"].split(",", false)
							groupdata["size"]=Vector2(sizeparts[0].to_float(), sizeparts[1].to_float())
						creategroup(true, groupdata)
				# create each node
				for itemindex in thearray.size():
					if itemindex==0:continue
					var nodetype:String=thearray[itemindex]["nodetype"]
					var uid = thearray[itemindex]["UID"]
					if get_node_by_uid(uid): continue # avoid duplicates
					var thenode:=createnode(nodetype,true, thearray[itemindex]["UID"])
					thearray[itemindex]["coords"]=thearray[itemindex]["coords"].strip_edges().trim_prefix("(").trim_suffix(")")
					var parts=thearray[itemindex]["coords"].split(",", false)
					var coords:=Vector2(parts[0].to_float(),parts[1].to_float())
					thenode.position_offset=coords
					thearray[itemindex]["size"]=thearray[itemindex]["size"].strip_edges().trim_prefix("(").trim_suffix(")")
					parts=thearray[itemindex]["size"].split(",", false)
					var thesize:=Vector2(parts[0].to_float(),parts[1].to_float())
					thenode.size=thesize
					var offset:=0
					for itemnum in thenode.get_child_count()/2: # store each pair (name, content)
						thenode.get_child(offset+0).text=thearray[itemindex][str(itemnum)].keys()[0]
						thenode.get_child(offset+1).text=thearray[itemindex][str(itemnum)][thearray[itemindex][str(itemnum)].keys()[0]]
						offset+=2

			# recreate connections between nodes
			await get_tree().process_frame
			var valid_connections := []
			for con in theconnections:
				if not %thecanvas.has_node(con["from_node"]) or not %thecanvas.has_node(con["to_node"]):
					continue
				valid_connections.push_back(con)
			# overwrite dirty data
			theconnections = valid_connections
			for con in theconnections:
				%thecanvas.connect_node(
					con["from_node"],
					int(con["from_slot"]),
					con["to_node"],
					int(con["to_slot"])
				)

	filedialogmission=""

func get_node_by_uid(UID)->GraphNode:
	for item in %thecanvas.get_children():
		if item.has_meta("UID") and item.get_meta("UID")==UID:
			return item
	return null

func save_array_as_json(path: String, arr: Array) -> int:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return FileAccess.get_open_error()
	var json_str := JSON.stringify(arr, "\t")
	f.store_string(json_str)
	f.flush() ; f.close()
	return OK

func generate_unique_id() -> String:
	var uuid = []
	var hex = "0123456789abcdef"
	var template = "xxxx-4xxx-yxxx-xxxx"
	for c in template:
		match c:
			"x":
				uuid.append(hex[randi() % 16])
			"y":
				uuid.append(hex[(randi() % 4) + 8])  # y is 8–b
			"-":
				uuid.append("-")
			_:
				uuid.append(c)
	var result: = str("".join(uuid)) # transform into string
	if UIDlist.has(result):
		randomize()
		return generate_unique_id() # other attempt if already exists
	return result
