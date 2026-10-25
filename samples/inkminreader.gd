extends Node

var dialoguefolder:=""
var current_knot_name:=""
var currentknot:={}
var currentbloc:={}
var languages:=["en"] # change this to change initial default language
var currentlang:="en" # change this to change initial default language
var choicerank:=0 # choice rank where the player is
var playervars:={} # stores game variables, needs to be saved
var allknots:=[] # stores all knots of the initial inkfile
var knotstructure:=[] # stores the current knot in simplified form, sorted by order of occurence
var currentstitch:="" # empty string means the knot's main section
var pending_condition_choices: Dictionary = {}
var next_condition_choice_id := 0

signal inkminfeed (output:Dictionary)

func initiatedialogs(path:=dialoguefolder+"root.json") -> void:
	var rootdata:=load_json_file(path)
	if rootdata=={}:return
	# initiate game variables, list of knots and languages
	playervars.clear()
	if rootdata["root"].has("variables"):
		for vardata in rootdata["root"]["variables"]:
			playervars[vardata["name"]]=vardata["content"]
	if rootdata["root"].has("knots"): allknots=rootdata["root"]["knots"]
	if rootdata["root"].has("languages"): languages=rootdata["root"]["languages"]
	else: rootdata["root"]["languages"]=["en"] # system needs a default language

func loadandstartknot(knotname) -> void: # starts root of a block
	pending_condition_choices.clear()
	current_knot_name=str(knotname)
	currentknot=load_json_file(dialoguefolder+current_knot_name+".json")
	knotstructure=sortknot(currentknot)
	currentstitch=""
	if currentknot.size()==0:return
	executebloc(currentknot.root, "root")

func executebloc(bloc:Dictionary, blocid: String = "") -> void:
	if bloc.size()==0:return
	# block invalid choice execution
	if bloc.type == "choice":
		if currentbloc.has("choicerank") and bloc.choicerank < currentbloc.choicerank:
			var weave_id = find_weave_after(currentbloc.inkline, currentbloc.choicerank)
			if weave_id != "": executebloc(currentknot[weave_id], weave_id)
			return
	currentbloc=bloc
	match bloc.type:
		"root":
			currentstitch=""
			if bloc.has("next") and currentknot.has(bloc.next):executebloc(currentknot[bloc.next], bloc.next)
		"goto":
			if bloc.destination=="END":
				inkminfeed.emit({"theend":true})
				return
			if bloc.destination=="":return
			var stitch_id := find_stitch_id(bloc.destination)
			if stitch_id != "":
				executebloc(currentknot[stitch_id], stitch_id)
				return
			var destination_parts := str(bloc.destination).split(".", false, 1)
			var destination_knot := str(bloc.destination)
			var destination_stitch := ""
			if destination_parts.size() == 2:
				destination_knot = destination_parts[0]
				destination_stitch = destination_parts[1]
			if not destination_knot in allknots:
				return
			inkminfeed.emit({"newknot":destination_knot})
			current_knot_name=destination_knot
			currentknot=load_json_file(dialoguefolder+current_knot_name+".json")
			knotstructure=sortknot(currentknot)
			currentstitch=""
			if not currentknot.has("root"):return # failsafe
			if destination_stitch != "":
				stitch_id = find_stitch_id(destination_stitch)
				if stitch_id != "":
					executebloc(currentknot[stitch_id], stitch_id)
				return
			bloc=currentknot.root
			if bloc.has("next") and bloc["next"]!="":executebloc(currentknot[bloc.next], bloc.next)
		"stitch":
			currentstitch = str(bloc.name)
			if bloc.has("next") and bloc.next != "": executebloc(currentknot[bloc.next], bloc.next)
		"signal":
			# output = tag sent by json
			inkminfeed.emit({"signal":bloc.instruction})
			decide_nextstep(bloc)
		"comment":
			# output = comment sent by json
			inkminfeed.emit({"comtext":bloc.comtext})
			if bloc.has("next") and bloc["next"]!="":executebloc(currentknot[bloc.next], bloc.next)
		"text":
			# output = text sent by json 
			var thetext:=""
			if bloc.text is Dictionary: thetext=bloc.text[currentlang] # multilanguage
			else: thetext=bloc.text # one language
			thetext=replace_variables(thetext)
			var nextnode:="" ; if bloc.has("next"): nextnode=bloc.next
			inkminfeed.emit({"text":thetext,"next":nextnode})
			decide_nextstep(bloc)
		"choice":
			# output = choice sent by json
			var thetext:=""
			if bloc.text is Dictionary : thetext=bloc.text[currentlang] # multilanguage
			else: thetext=bloc.text # one language
			thetext=replace_variables(thetext)
			inkminfeed.emit({"choice":thetext, "next":bloc.next, "blocid":blocid})
			# look for other choices of same rank after this one
			for item in knotstructure:
				if item.inkline > bloc.inkline:
					if not is_in_current_stitch(item): break
					# stop when leaving this choice level
					if item.type == "choice" and item.choicerank < bloc.choicerank: break
					# stop on weave (normal boundary)
					if item.type == "weave":break
					# show the other choices at this level
					if item.type == "choice" and item.choicerank == bloc.choicerank:
						var txt = currentknot[item.key].text
						if txt is Dictionary:
							inkminfeed.emit({"choice": txt[currentlang], "next": currentknot[item.key].next, "blocid": item.key})
						else:
							inkminfeed.emit({"choice": txt, "next": currentknot[item.key].next, "blocid": item.key})
		"weave":
			# output = text sent by json
			var nextnode:="" ; if bloc.has("next"): nextnode=bloc.next
			var thetext:=""
			if bloc.text is Dictionary : thetext=bloc.text[currentlang] # multilanguage
			else: thetext=bloc.text # one language
			thetext=replace_variables(thetext)
			if thetext.length()>0:inkminfeed.emit({"text":thetext,"next":nextnode})
			decide_nextstep(bloc)
		"execute":
			# output = instructions concerning variables sent by json
			dothemath(bloc.instruction)
			decide_nextstep(bloc)
		"condition":
			if "=" in bloc.condition or ">" in bloc.condition or "<" in bloc.condition:
				var condition_result := checkiftrue(bloc.condition)
				if condition_result==true:
					var conditional_choices: Array = []
					var immediate_consequences: Array = []
					for consequence in bloc.consequences:
						if consequence is Dictionary and consequence.get("type", "") == "choice":
							conditional_choices.push_back(consequence)
						else:
							immediate_consequences.push_back(consequence)
					if execute_condition_consequences(immediate_consequences, bloc):
							return
					if not conditional_choices.is_empty():
						pending_condition_choices.clear()
						for conditional_choice in conditional_choices:
							next_condition_choice_id += 1
							var choice_id := "__condition_choice_%d" % next_condition_choice_id
							pending_condition_choices[choice_id] = {"condition": bloc, "choice": conditional_choice}
							var choice_text = conditional_choice.get("text", "")
							if choice_text is Dictionary:
								choice_text = choice_text.get(currentlang, "")
							inkminfeed.emit({"choice": replace_variables(str(choice_text)), "next": choice_id, "blocid": ""})
						var next_choice_id := str(bloc.get("next", ""))
						if next_choice_id != "" and currentknot.has(next_choice_id) and currentknot[next_choice_id].get("type", "") == "choice":
							executebloc(currentknot[next_choice_id], next_choice_id)
						return
			decide_nextstep(bloc)

func execute_condition_consequences(consequences: Array, condition_bloc: Dictionary) -> bool:
	for consequence in consequences:
		if consequence is String:
			var instruction: String = str(consequence).strip_edges()
			if instruction.begins_with("~"):
				dothemath(instruction.trim_prefix("~").strip_edges())
			elif instruction.begins_with("#"):
				inkminfeed.emit({"signal": instruction.trim_prefix("#").strip_edges()})
			elif instruction.begins_with("->"):
				executebloc({"type": "goto", "destination": instruction.trim_prefix("->").strip_edges()})
				return true
			elif instruction != "":
				inkminfeed.emit({"text": replace_variables(instruction), "next": str(condition_bloc.get("next", ""))})
		elif consequence is Dictionary:
			inkminfeed.emit({"text": replace_variables(str(consequence.get(currentlang, ""))), "next": str(condition_bloc.get("next", ""))})
	return false

func decide_nextstep(bloc: Dictionary) -> void:
	# normal next
	if bloc.has("next") and bloc.next != "":
		executebloc(currentknot[bloc.next], bloc.next)
		return
	# scan forward
	for item in knotstructure:
		if item.inkline > bloc.inkline:
			if not is_in_current_stitch(item): break
			# stop scanning at a choice from an outer level
			if item.type == "choice" and item.choicerank < bloc.choicerank:
				break
			# continue at the next weave
			if item.type == "weave":
				executebloc(currentknot[item.key], item.key)
				return
			# stop if new branch starts
			if item.type == "choice" and item.choicerank == bloc.choicerank:
				return
	# fallback: try weave
	var weave_id = find_weave_after(bloc.inkline, bloc.choicerank)
	if weave_id != "":
		executebloc(currentknot[weave_id], weave_id)

func find_weave_after(start_inkline: int, max_rank: int) -> String:
	for item in knotstructure:
		if item.inkline > start_inkline:
			if not is_in_current_stitch(item): break
			if item.type == "weave" and item.choicerank <= max_rank:
				return item.key
			# keep searching past outer choices for a shared weave
			if item.type == "choice" and item.choicerank < max_rank:
				continue
	return ""

func choicemade(blocid, selected_choice_id: String = "") -> void: # callback from choice
	inkminfeed.emit({"choicemade": blocid})
	if pending_condition_choices.has(blocid):
		var selection: Dictionary = pending_condition_choices[blocid]
		pending_condition_choices.clear()
		var selected_choice: Dictionary = selection["choice"]
		if execute_condition_consequences(selected_choice.get("consequences", []), selection["condition"]):
			return
		currentbloc = selection["condition"]
		decide_nextstep(currentbloc)
		return
	if blocid != "":
		executebloc(currentknot[blocid], blocid)
	else: # try weave
		var choicebloc := currentbloc
		if selected_choice_id != "" and currentknot.has(selected_choice_id):
			choicebloc = currentknot[selected_choice_id]
		var weave_id = find_weave_after(choicebloc.inkline, choicebloc.choicerank)
		if weave_id != "":
			executebloc(currentknot[weave_id], weave_id)

func lastblockreached() -> bool: # can be checked from user script
	if not currentbloc.has("next") or currentbloc["next"]=="":return true
	else: return false

func sortknot(knot) -> Array: # organizes the bloc by inkline rank
	var simplified_array = []
	for key in knot:
		var entry = knot[key]
		simplified_array.append({
			"key": key,
			"type": entry.get("type", ""),
			"inkline": entry.get("inkline", -1),
			"choicerank": entry.get("choicerank", 0)
		})
	simplified_array.sort_custom(func(a, b): return a["inkline"] < b["inkline"])
	return simplified_array

func find_stitch_id(stitch_name: String) -> String:
	for item in knotstructure:
		if item.type == "stitch" and str(currentknot[item.key].get("name", "")) == stitch_name:
			return str(item.key)
	return ""

func is_in_current_stitch(item: Dictionary) -> bool:
	var stitch_name := ""
	for candidate in knotstructure:
		if candidate.inkline > item.inkline:
			break
		if candidate.type == "stitch":
			stitch_name = str(currentknot[candidate.key].get("name", ""))
	return stitch_name == currentstitch

func normalize_variable_name(var_name: String) -> String:
	var accents := {
		"A": "ÀÁÂÃÄÅĀĂĄǍ", "C": "ÇĆĈĊČ", "D": "ĎĐ",
		"E": "ÈÉÊËĒĔĖĘĚ", "G": "ĜĞĠĢ", "H": "ĤĦ",
		"I": "ÌÍÎÏĨĪĬĮİǏ", "J": "Ĵ", "K": "Ķ", "L": "ĹĻĽŁ",
		"N": "ÑŃŅŇ", "O": "ÒÓÔÕÖØŌŎŐǑ", "R": "ŔŖŘ",
		"S": "ŚŜŞŠ", "T": "ŢŤŦ", "U": "ÙÚÛÜŨŪŬŮŰŲǓǕǗǙǛ",
		"W": "ŴẀẂẄ", "Y": "ÝŸŶỲ", "Z": "ŹŻŽ",
		"AE": "ÆǼǢ", "OE": "Œ", "SS": "ẞß"
	}
	var result := ""
	for character in var_name.to_upper():
		var code := character.unicode_at(0)
		if code >= 0x0300 and code <= 0x036f:continue
		var letter := character
		if code > 127:
			for base in accents:
				if character in accents[base]:
					letter = base
					break
		result += letter
	return result

func find_variable_name_case_insensitive(var_name: String) -> String:
	if playervars.has(var_name):
		return var_name
	var normalized_name := normalize_variable_name(var_name)
	for existing_name in playervars.keys():
		var candidate := str(existing_name)
		if normalize_variable_name(candidate) == normalized_name:
			return candidate
	return ""

func normalize_expression_variables_case(expression_text: String) -> String:
	var regex := RegEx.new()
	regex.compile(r""""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"""
		+r"|0[xX][0-9a-fA-F]+"
		+r"|(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?"
		+r"|([\p{L}_][\p{L}\p{M}\p{N}_]*)")
	var normalized := ""
	var previous_end := 0
	for match in regex.search_all(expression_text):
		var start := match.get_start()
		var end := match.get_end()
		var token := match.get_string()
		normalized += expression_text.substr(previous_end, start - previous_end)
		var normalized_name := ""
		if match.get_string(1) != "":
			if not expression_text.substr(end).strip_edges().begins_with("(") and not expression_text.substr(0, start).strip_edges().ends_with("."):
				normalized_name = find_variable_name_case_insensitive(token)
		if normalized_name != "":
			normalized += normalized_name
		else:
			normalized += token
		previous_end = end
	normalized += expression_text.substr(previous_end)
	return normalized

func get_literal_string_value(value_text: String) -> Variant:
	# Needed to recognize variables as string or other types
	if value_text.length() >= 2:
		var opening_quote := value_text[0]
		if (opening_quote == '"' or opening_quote == "'") and value_text[value_text.length() - 1] == opening_quote:
			return value_text.substr(1, value_text.length() - 2)
	if value_text.is_valid_int() or value_text.is_valid_float():
		return null
	if value_text.to_lower() in ["true", "false", "null"]:
		return null
	if find_variable_name_case_insensitive(value_text) != "":
		return null
	for operator in ["+", "-", "*", "/", "%", "(", ")", "<", ">", "!", "&", "|", "["]:
		if value_text.contains(operator):
			return null
	return value_text

func dothemath(statement: String) -> void:
	var clean = statement.strip_edges()
	var knot_name := current_knot_name if current_knot_name != "" else "<unknown knot>"
	# failsafe
	if not clean.contains("="):
		print("Invalid math statement (missing '=') in knot '", knot_name, "': ", statement)
		return
	# split at the first "=" so the expression stays intact
	var parts = clean.split("=", false, 1)
	if parts.size() != 2:
		print("Invalid math statement in knot '", knot_name, "': ", statement)
		return
	var raw_var_name = parts[0].strip_edges()
	var var_name := find_variable_name_case_insensitive(raw_var_name)
	var raw_value_text := parts[1].strip_edges()
	if var_name == "":
		print("Undefined variable '", raw_var_name, "' in knot '", knot_name, "': ", statement)
		return
	var literal_value = get_literal_string_value(raw_value_text)
	if literal_value != null:
		playervars[var_name] = literal_value
		inkminfeed.emit({"varchange": var_name})
		return
	var expression_text = normalize_expression_variables_case(raw_value_text)
	# prepare expression
	var expression = Expression.new()
	var var_names = playervars.keys()
	var err = expression.parse(expression_text, var_names)
	if err != OK:
		print("Failed to parse expression in knot '", knot_name, "': ", expression.get_error_text(), " | ", statement)
		return
	# build values array
	var var_values := []
	for name in var_names:
		var_values.append(playervars.get(name, 0))
	var result = expression.execute(var_values, self)
	if expression.has_execute_failed():
		print("Expression execution failed in knot '", knot_name, "': ", statement)
		return
	# assign result
	playervars[var_name] = result
	inkminfeed.emit({"varchange": var_name})

func normalize_condition_expression(expression_str: String) -> String:
	var normalized := ""
	for i in expression_str.length():
		var current := expression_str[i]
		var previous := ""
		var next := ""
		if i > 0:
			previous = expression_str[i - 1]
		if i < expression_str.length() - 1:
			next = expression_str[i + 1]
		if current == "=" and previous != "=" and previous != "!" and previous != "<" and previous != ">" and next != "=":
			normalized += "=="
		else:
			normalized += current
	return normalized

func checkiftrue(expression_str: String) -> bool: # Check statements such as "x==true" or "x>1"
	var expression = Expression.new()
	var var_names = playervars.keys()
	var normalized_expression := normalize_expression_variables_case(normalize_condition_expression(expression_str))
	var err = expression.parse(normalized_expression, var_names)
	if err != OK:
		print("Parse error: ", expression.get_error_text())
		return false
	var boolean_comparison_variables := get_boolean_comparison_variables(normalized_expression)
	var var_values := []
	for thename in var_names:
		var variable_value = playervars.get(thename, false)
		if boolean_comparison_variables.has(str(thename)) and variable_value is String:
			var lower_value: String = str(variable_value).to_lower()
			if lower_value == "true" or lower_value == "false":
				variable_value = lower_value == "true"
		var_values.append(variable_value)
	var result = expression.execute(var_values, self)
	if expression.has_execute_failed():
		print("Execution failed.")
		return false
	return bool(result)

func get_boolean_comparison_variables(expression_text: String) -> Dictionary:
	var matches := {}
	var variable_on_left := RegEx.new()
	variable_on_left.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\b\s*(?:==|!=)\s*(?:true|false)\b")
	for match in variable_on_left.search_all(expression_text):
		matches[match.get_string(1)] = true
	var variable_on_right := RegEx.new()
	variable_on_right.compile(r"(?:true|false)\s*(?:==|!=)\s*([A-Za-z_][A-Za-z0-9_]*)\b")
	for match in variable_on_right.search_all(expression_text):
		matches[match.get_string(1)] = true
	return matches

func replace_variables(input: String) -> String:
	var pattern := r"\{([\p{L}_][\p{L}\p{M}\p{N}_]*)\}"  # Regex to match {varname}
	var regex := RegEx.new()
	regex.compile(pattern)
	var result := input
	for match in regex.search_all(input):
		var var_name := match.get_string(1)
		var normalized_name := find_variable_name_case_insensitive(var_name)
		if normalized_name != "":
			result = result.replace("{" + var_name + "}", str(playervars[normalized_name]))
		else:
			result = result.replace("{" + var_name + "}", "")  # Remove unknowns or keep as is
	return result

func load_json_file(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_text := file.get_as_text()
		file.close()

		var result = JSON.parse_string(json_text)
		if result is Dictionary:
			return result
		else:
			print("Failed to parse JSON.")
	else:
		print("Failed to open file:", file_path)
	return {}

func cleardata()->void:
	current_knot_name=""
	currentbloc.clear()
	currentknot.clear()
	knotstructure.clear()
	pending_condition_choices.clear()
	choicerank=0
