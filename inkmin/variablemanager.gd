extends Control

# Variable manager : replace variables and check errors

var jsonfolder:=""
var reader=load("res://inkmin/inkminreader.gd").new()

func openmanager()->void:
	if Autoload.jsonfolder=="":return
	jsonfolder=Autoload.jsonfolder
	listvariables()
	show()

# ----------------
# Replacing variables

func listvariables()->void:
	for child in %variablelist.get_children():
		%variablelist.remove_child(child)
		child.queue_free()
	var rootjson:=loadknot("root")
	if rootjson.is_empty():return
	var variables:Array=rootjson.root.get("variables",[])
	if variables.is_empty():
		var label:=Label.new()
		label.text=tr("No variable defined in root knot")
		%variablelist.add_child(label)
		return
	for variable in variables:
		var row=%varmodel.duplicate()
		row.unique_name_in_owner=false
		row.get_node("varname").text=str(variable.name)
		row.get_node("varname").auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
		var field:LineEdit=row.get_node("newvar")
		field.text=""
		row.get_node("confirm").pressed.connect(_on_replace_pressed.bind(str(variable.name),field))
		%variablelist.add_child(row)
		row.show()

func _on_replace_pressed(oldname:String,field:LineEdit)->void:
	var editor=Autoload.editornode
	if editor.knotchanged:
		editor.savejson()
		if editor.knotchanged:
			%variableerrors.add_text(tr("Save the current knot before renaming variables.")+"\n")
			return
	if not renamevariable(oldname,field.text.strip_edges()):return
	editor.loadrootdata()
	editor.reloadplayervarsfromroot()
	editor.displayeditor()
	editor._on_play_pressed()
	editor.displayvariables()
	listvariables()

func renamevariable(oldname:String,newname:String)->bool:
	newname=reader.normalize_variable_name(newname)
	var oldkey:String=reader.normalize_variable_name(oldname)
	var identifier:=RegEx.new()
	identifier.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
	if identifier.search(newname)==null or newname.to_lower() in ["true","false","null","and","or","not"]:
		%variableerrors.add_text(tr("Use a variable name starting with a letter or underscore, followed by letters, digits or underscores.")+"\n")
		return false
	if oldname==newname:return false
	var rootjson:=loadknot("root")
	if rootjson.is_empty():return false
	var found:=false
	for variable in rootjson.root.get("variables",[]):
		if reader.normalize_variable_name(str(variable.name))==oldkey:
			found=true
		elif reader.normalize_variable_name(str(variable.name))==newname:
			%variableerrors.add_text((tr("Variable already declared: %s") % newname)+"\n")
			return false
	if not found:
		%variableerrors.add_text((tr("Variable is no longer declared: %s") % oldname)+"\n")
		return false
	reader.playervars.clear()
	for variable in rootjson.root.get("variables",[]):
		reader.playervars[str(variable.name)]=variable.content
	var changes:={}
	for knot in projectknots(rootjson):
		var data:Dictionary=rootjson if knot=="root" else loadknot(knot)
		if data.is_empty():return false
		var before:=JSON.stringify(data)
		if knot=="root":
			for variable in data.root.variables:
				if reader.normalize_variable_name(str(variable.name))==oldkey:variable.name=newname
		for block in data.values():
			renameblock(block,oldname,newname)
		if JSON.stringify(data)!=before:
			changes[jsonfolder.path_join(knot+".json")]=data
	if not savechanges(changes):return false
	%variableerrors.push_color(Color.DARK_GREEN)
	%variableerrors.add_text((tr("Replaced %s variable by %s") % [oldname,newname])+"\n")
	%variableerrors.pop()
	return true

func renameblock(block:Dictionary,oldname:String,newname:String)->void:
	match block.get("type",""):
		"text","choice","weave":
			block.text=replacetext(block.text,oldname,newname)
		"execute":
			block.instruction=replaceinstruction(block.instruction,oldname,newname)
		"condition":
			block.condition=replaceexpression(block.condition,oldname,newname)
	if block.has("consequences"):
		for i in block.consequences.size():
			var consequence=block.consequences[i]
			if consequence is Dictionary and consequence.has("type"):
				renameblock(consequence,oldname,newname)
				continue
			if consequence is String:
				var instruction:String=consequence.strip_edges()
				if instruction.begins_with("~"):
					block.consequences[i]=replaceinstruction(consequence,oldname,newname)
					continue
				if instruction.begins_with("#") or instruction.begins_with("->"):continue
			block.consequences[i]=replacetext(consequence,oldname,newname)

func replaceinstruction(text:String,oldname:String,newname:String)->String:
	var parts:=text.split("=",true,1)
	parts[0]=replaceexpression(parts[0],oldname,newname)
	if parts.size()==2 and reader.get_literal_string_value(parts[1].strip_edges())==null:
		parts[1]=replaceexpression(parts[1],oldname,newname)
	return "=".join(parts)

func replaceexpression(text:String,oldname:String,newname:String)->String:
	var tokens:=RegEx.new()
	tokens.compile(r""""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"""
		+r"|0[xX][0-9a-fA-F]+"
		+r"|(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?"
		+r"|[\p{L}_][\p{L}\p{M}\p{N}_]*")
	var result:=""
	var previous:=0
	for token in tokens.search_all(text):
		result+=text.substr(previous,token.get_start()-previous)
		var name:=token.get_string()
		var matches:bool=reader.normalize_variable_name(name)==reader.normalize_variable_name(oldname)
		if text.substr(token.get_end()).strip_edges().begins_with("(") or text.substr(0,token.get_start()).strip_edges().ends_with("."):matches=false
		result+=newname if matches else name
		previous=token.get_end()
	return result+text.substr(previous)

func replacetext(text:Variant,oldname:String,newname:String)->Variant:
	if text is Dictionary:
		for lang in text:
			text[lang]=replacetext(text[lang],oldname,newname)
		return text
	if not text is String:return text
	var placeholders:=RegEx.new()
	placeholders.compile(r"\{([\p{L}_][\p{L}\p{M}\p{N}_]*)\}")
	for placeholder in placeholders.search_all(text):
		if reader.normalize_variable_name(placeholder.get_string(1))==reader.normalize_variable_name(oldname):
			text=text.replace(placeholder.get_string(),"{"+newname+"}")
	return text

# ------------------------
# Check variable errors

func _on_visibility_changed()->void:
	if is_visible_in_tree():checkerrors()

func checkerrors()->void:
	if jsonfolder=="":jsonfolder=Autoload.jsonfolder
	if jsonfolder=="":return
	var rootjson:=loadknot("root")
	if rootjson.is_empty():return
	reader.playervars.clear()
	for variable in rootjson.root.get("variables",[]):
		var name:String=reader.normalize_variable_name(str(variable.name))
		if reader.playervars.has(name):
			%variableerrors.push_color(Color.RED)
			%variableerrors.add_text((tr("Variable already declared: %s") % name)+"\n")
			%variableerrors.pop()
			return
		reader.playervars[name]=variable.content
	var editor=Autoload.editornode
	var converter=editor.get_node("inkminconverter")
	var knots:={}
	var changes:={}
	for knot in projectknots(rootjson):
		var data:Dictionary=rootjson if knot=="root" else loadknot(knot)
		if data.is_empty():return
		var path:=jsonfolder.path_join(knot+".json")
		var before:=JSON.stringify(data)
		converter.uppercase_json_variables(data,path)
		knots[knot]=data
		if JSON.stringify(data)!=before:changes[path]=data
	if not changes.is_empty():
		if not savechanges(changes):return
		listvariables()
	if jsonfolder==Autoload.jsonfolder:
		var preview=editor.get_node("inkminreader")
		var values:Dictionary=preview.playervars.duplicate()
		if not changes.is_empty():
			editor.loadrootdata()
			if not editor.knotchanged and editor.knotname!="":editor.displayeditor()
		editor.reloadplayervarsfromroot(rootjson)
		for name in values:
			preview.playervars[reader.normalize_variable_name(str(name))]=values[name]
		editor.displayvariables()
	for knot in knots:
		var unknown:Array[String]=[]
		for block in knots[knot].values():
			checkblock(block,unknown)
		for name in unknown:
			%variableerrors.push_color(Color.RED)
			%variableerrors.add_text((tr("unknown variable %s used in knot named %s") % [name,knot])+"\n")
			%variableerrors.pop()

func checkblock(block:Dictionary,unknown:Array[String])->void:
	match block.get("type",""):
		"condition":
			checkexpression(block.condition,unknown)
		"execute":
			checkinstruction(block.instruction,unknown)
	for consequence in block.get("consequences",[]):
		if consequence is Dictionary and consequence.has("type"):
			checkblock(consequence,unknown)
		elif consequence is String and consequence.strip_edges().begins_with("~"):
			checkinstruction(consequence.strip_edges().trim_prefix("~"),unknown)

func checkinstruction(instruction:String,unknown:Array[String])->void:
	var parts:=instruction.split("=",true,1)
	checkexpression(parts[0],unknown)
	if parts.size()<2:return
	var value:=parts[1].strip_edges()
	# The reader also accepts unquoted text as a string assignment.
	if reader.get_literal_string_value(value)==null:
		checkexpression(value,unknown)

func checkexpression(text:String,unknown:Array[String])->void:
	var tokens:=RegEx.new()
	tokens.compile(r""""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"""
		+r"|0[xX][0-9a-fA-F]+"
		+r"|(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?"
		+r"|[\p{L}_][\p{L}\p{M}\p{N}_]*")
	for token in tokens.search_all(text):
		var name:=token.get_string()
		if name.begins_with('"') or name.begins_with("'") or name[0].is_valid_int() or name.begins_with("."):continue
		if name.to_lower() in ["true","false","null","and","or","not","in","is","as"] or name in ["PI","TAU","INF","NAN"]:continue
		if text.substr(token.get_end()).strip_edges().begins_with("("):continue
		if text.substr(0,token.get_start()).strip_edges().ends_with("."):continue
		if reader.find_variable_name_case_insensitive(name)=="" and not unknown.any(func(existing:String):return reader.normalize_variable_name(existing)==reader.normalize_variable_name(name)):
			unknown.push_back(name)

# ----------------
# Other stuff

func _ready()->void:
	add_child(reader)
	$Panel/Margins/VBox/Errors.get_v_scroll_bar().changed.connect(_on_log_range_changed)

func _on_log_range_changed()->void:
	var scroll:ScrollContainer=$Panel/Margins/VBox/Errors
	scroll.set_deferred("scroll_vertical",scroll.get_v_scroll_bar().max_value)

func _on_closebutton_pressed() -> void:
	hide()

func loadknot(knot:String)->Dictionary:
	var path:=jsonfolder.path_join(knot+".json")
	var file:=FileAccess.open(path,FileAccess.READ)
	if file!=null:
		var data=JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			var rootblock=data.get("root",{})
			if rootblock is Dictionary and rootblock.get("type","")=="root":return data
	%variableerrors.add_text((tr("Could not load knot: %s") % path)+"\n")
	return {}

func projectknots(rootjson:Dictionary)->Array:
	var knots:Array=["root"]
	for knot in rootjson.root.get("knots",[]):
		if not knots.has(knot):knots.push_back(knot)
	return knots

func savechanges(changes:Dictionary)->bool:
	var suffix:=".varrename_"+str(Time.get_ticks_usec())
	var backups:Array[String]=[]
	for path in changes:
		Autoload.editornode.get_node("inkminconverter").uppercase_json_variables(changes[path],path)
		var file:=FileAccess.open(path+suffix,FileAccess.WRITE)
		var error:=FileAccess.get_open_error()
		if file!=null:
			file.store_string(JSON.stringify(changes[path],"\t"))
			file.flush()
			error=file.get_error()
			file.close()
		if error!=OK:
			%variableerrors.add_text((tr("Could not save file: %s") % path)+"\n")
			cleartemporaryfiles(changes,suffix)
			return false
	for path in changes:
		if DirAccess.rename_absolute(path,path+suffix+".old")!=OK:
			%variableerrors.add_text((tr("Could not save file: %s") % path)+"\n")
			restorefiles(backups,suffix)
			cleartemporaryfiles(changes,suffix)
			return false
		backups.push_back(path)
	for path in changes:
		if DirAccess.rename_absolute(path+suffix,path)!=OK:
			%variableerrors.add_text((tr("Could not save file: %s") % path)+"\n")
			restorefiles(backups,suffix)
			cleartemporaryfiles(changes,suffix)
			return false
	for path in backups:DirAccess.remove_absolute(path+suffix+".old")
	return true

func restorefiles(backups:Array[String],suffix:String)->void:
	for path in backups:
		if DirAccess.rename_absolute(path+suffix+".old",path)!=OK:
			%variableerrors.add_text((tr("Could not restore file; original kept at: %s") % (path+suffix+".old"))+"\n")

func cleartemporaryfiles(changes:Dictionary,suffix:String)->void:
	for path in changes:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
