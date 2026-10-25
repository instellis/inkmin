extends Node

var sortedcontent:Dictionary={} # contains ink code in sequential order
var inkarray:=[]
var currentlang:="en"
var mainlang:="en"
var languages:=["en"]

signal conversionfinished
signal parserwarning(message: String)

func get_block_main_text(block: Dictionary) -> String:
	if block.has("text"):
		if block["text"] is Dictionary:
			return str(block["text"].get(mainlang, "")).strip_edges()
		return str(block["text"]).strip_edges()
	return ""

func find_reusable_block_id(existingjson: Dictionary, used_existing_ids: Dictionary, block_type: String, main_text: String, choicerank: int = -999999) -> String:
	if existingjson == {}:
		return ""
	var sortedexisting := sortknot(existingjson)
	for item in sortedexisting:
		var blockid := str(item.get("key", ""))
		if blockid == "" or used_existing_ids.has(blockid):
			continue
		var block: Dictionary = existingjson.get(blockid, {})
		if block.get("type", "") != block_type:
			continue
		if choicerank != -999999 and int(block.get("choicerank", -999999)) != choicerank:
			continue
		if get_block_main_text(block) == main_text.strip_edges():
			return blockid
	return ""

func convertinkfile(file_path, target_path)->void:

	# load ink file and strip empty lines and comments
	var inkfilecontent:=loadinkfile(file_path)
	var convertedinkfile:={}
	
	# convert loaded ink file into big dictionary of knots and blocks
	if inkfilecontent.size()>0:
		convertedinkfile=parseinkfile(inkfilecontent)

	# cut knots into jsons saved at target_path
	for knot in convertedinkfile:
		if not save_dict_to_json_file(convertedinkfile[knot],target_path+knot+".json"):
			return
	
	emit_signal("conversionfinished")

# ---------------------------
# parsing the ink file

# parsing creates and dictionary with all the knots as main key, beginning with "root" 
# json is a dictionary, in the format {"root":{"next":UID},"UID":{content}}, also beginning with "root"
# each block is a {} containing a "type" and other characteristics (e.g. "UID-xzy":{"type":"text","text":"blabla", "next":"UID-xyz"}
# most blocks contain a "inkline" number referring to the line number after removal of empty lines

func parseinkfile(inkfilecontent:Dictionary,singlejson:=false,existingjson:={})->Dictionary:
	# go through each line, determine what it is and add create knots and blocks
	var modifiedcontent:={"root":{"root":{"type":"root","variables":[],"knots":["root"],"languages":[currentlang], "inkline":0}}}
	var currentknot:="root" # contains name of current knot
	var previousblock="root" # used to store block needing "next" instructions
	var choicerank:=0 # used to detect if blocks are the consequence of a choice, and at which rank
	var insidecondition:=false # parsed block is inside {}
	var insidechoice:=false # parsed block is between two +
	var used_existing_ids:={}
	
	for linenb in inkfilecontent:
		var line:String=inkfilecontent[linenb]
		
		var blockid:=generate_unique_id() # each block has an id
		sortedcontent[linenb]=line + "<<" + blockid + ">>" # sorted in format linenb: inkmin content (not json content)

		# A multiline condition is parsed in one pass from its opening line. Do not
		# also parse its contents as regular top-level blocks.
		if insidecondition:
			if line.strip_edges().ends_with("}"):
				insidecondition=false
			continue

		# definition of variables (beginning of ink file)
		var cleanline:=line.strip_edges()
		var variableline := cleanline.trim_prefix("#").strip_edges()
		var is_variable := cleanline.begins_with("# VAR") or cleanline.begins_with("#VAR") or cleanline.begins_with("VAR")
		if not singlejson:
			is_variable = variableline.begins_with("VAR ") or variableline.begins_with("VAR\t")
		if is_variable:
			var variablecontent = variableline.substr(3).strip_edges().split("=", false, 1)
			if variablecontent.size() > 1 and not insidechoice and not insidecondition:
				var name = variablecontent[0].strip_edges()
				var value = variablecontent[1].strip_edges()
				# type conversion
				var is_quoted_string := value.length() >= 2 and value.begins_with("\"") and value.ends_with("\"")
				if is_quoted_string:
					value = value.trim_prefix("\"").trim_suffix("\"")
					if not singlejson and not cleanline.begins_with("#"):
						value = unescapeinkstring(value)
				elif value.to_lower() == "true": value = true
				elif value.to_lower() == "false": value = false
				elif value.is_valid_int(): value = value.to_int()
				elif value.is_valid_float(): value = value.to_float()
				else: value = value.strip_edges()
				if not modifiedcontent["root"]["root"].has("variables"):
					modifiedcontent["root"]["root"]["variables"] = []
				var vars = modifiedcontent["root"]["root"]["variables"]
				var exists := false
				for v in vars:
					if v["name"] == name:
						exists = true
						break
				if not exists:
					vars.append({"name": name, "content": value})

		# choice blocks
		elif line.strip_edges().begins_with("+") and line.strip_edges().length() > 1:
			line = line.strip_edges()
			# Count number of '+' to determine rank
			var rank := 0
			for c in line:
				if c == "+": rank += 1
				else: break
			choicerank = rank
			insidechoice = true
			# Remove all '+' prefixes
			line = line.substr(rank).strip_edges()
			var choiceblock = {"type":"choice", "next": ""}
			choiceblock["text"] = {}
			choiceblock["text"][mainlang] = line.replace("[","").replace("]","").strip_edges()
			if languages.size() > 1:
				for lang in languages:
					if not singlejson:
						if lang != mainlang:
							choiceblock["text"][lang] = "<<translation>>"
					elif existingjson != {} and lang != mainlang:
						for bloc in existingjson.keys():
							if existingjson[bloc].has("text") and existingjson[bloc]["text"][mainlang] == choiceblock["text"][mainlang]:
								if existingjson[bloc]["text"].has(lang):
									choiceblock["text"][lang] = existingjson[bloc]["text"][lang]
								else: choiceblock["text"][lang] = "<<translation>>"
					elif lang != mainlang: choiceblock["text"][lang] = "<<translation>>"
			choiceblock["choicerank"] = choicerank
			choiceblock["inkline"] = linenb
			if existingjson != {}:
				var reusable_choice_id := find_reusable_block_id(existingjson, used_existing_ids, "choice", choiceblock["text"][mainlang], choicerank)
				if reusable_choice_id != "":
					blockid = reusable_choice_id
					used_existing_ids[blockid] = true
					sortedcontent[linenb] = line + "<<" + blockid + ">>"
			modifiedcontent[currentknot][blockid] = choiceblock

			# avoid making this choice block the "next" of the consequence of a previous choice
			var prev = modifiedcontent[currentknot][previousblock]
			var prev_rank = prev.get("choicerank", 0)
			var next_rank = choicerank
			# a lower-rank choice belongs to an outer branch
			if next_rank < prev_rank:
				modifiedcontent[currentknot][previousblock]["next"] = ""
			# normal behavior
			else:
				if prev["type"] != "choice" and next_rank == prev_rank:
					modifiedcontent[currentknot][previousblock]["next"] = ""
				else:
					modifiedcontent[currentknot][previousblock]["next"] = blockid

			# ----------------------------------------
			# check if previous line is also a choice
			if inkfilecontent.has(linenb-1) and inkfilecontent[linenb-1].strip_edges().begins_with("+"):
				modifiedcontent[currentknot][previousblock]["next"] = ""

			# ----------------------------------------
			# check if next line is a weave
			if inkfilecontent.has(linenb+1) and inkfilecontent[linenb+1].strip_edges().begins_with("-"):
				modifiedcontent[currentknot][blockid]["next"] = ""

			previousblock = blockid
			#print(str("create a choice : "+line.replace("[","").replace("]","")).indent(createtabs(choicerank-1)))

		# stitches are local named sections inside the current knot.
		elif line.strip_edges().begins_with("=") and not line.strip_edges().begins_with("=="):
			var stitchname := line.strip_edges().trim_prefix("=").strip_edges()
			if currentknot == "root":
				emit_signal("parserwarning", "Stitches are not allowed in the root knot (line %d)." % linenb)
				continue
			var duplicate_stitch := false
			for existing_block in modifiedcontent[currentknot].values():
				if existing_block.get("type", "") == "stitch" and existing_block.get("name", "") == stitchname:
					duplicate_stitch = true
					break
			if stitchname == "":
				emit_signal("parserwarning", "Stitch on line %d needs a name." % linenb)
				continue
			if duplicate_stitch:
				emit_signal("parserwarning", "Duplicate stitch '%s' in knot '%s' on line %d." % [stitchname, currentknot, linenb])
				continue
			modifiedcontent[currentknot][previousblock]["next"] = ""
			var stitchblock := {"type":"stitch", "name":stitchname, "next":"", "choicerank":0, "inkline":linenb}
			modifiedcontent[currentknot][blockid] = stitchblock
			previousblock = blockid
			choicerank = 0
			insidechoice = false

		# divert to other knot or stitch
		elif line.strip_edges().begins_with("->"):
				# divert to new knot from another block than root
				var divertblock={"type":"goto"}
				divertblock["destination"]=line.replace("->","").strip_edges()
				divertblock["choicerank"]=choicerank
				divertblock["inkline"]=linenb
				modifiedcontent[currentknot][blockid]=divertblock
				modifiedcontent[currentknot][previousblock]["next"]=blockid
				previousblock=blockid
				#print(str("divert to knot: "+line.replace("->","").strip_edges()).indent(createtabs(choicerank)))
				if choicerank>0:choicerank=0 # player leaves choice branching

		# new knot 
		elif line.strip_edges().begins_with("==="):
			currentknot=line.replace("===","").strip_edges()
			if not singlejson and currentknot == "root":
				# Keep declarations from the preamble when an explicit root follows.
				modifiedcontent["root"]["root"]["inkline"] = linenb
				modifiedcontent["root"]["root"]["choicerank"] = 0
			else:
				modifiedcontent[currentknot]={"root":{"type":"root", "next":"","inkline":linenb,"choicerank":0}}
			if not modifiedcontent["root"]["root"].has("knots"):modifiedcontent["root"]["root"]["knots"]=[]
			if singlejson or not currentknot in modifiedcontent["root"]["root"]["knots"]:
				modifiedcontent["root"]["root"]["knots"].push_back(currentknot) # update root json
			previousblock="root"
			choicerank=0
			if not singlejson:
				insidechoice=false
			used_existing_ids.clear()
			#print("------------------")
			#print("create a new knot: "+currentknot)

		# conditional blocks
		
		elif not "{" in line.strip_edges()and line.strip_edges().ends_with("}"):
			# this ends a condition with multiple consequences when } is on a single line
			insidecondition=false 
		
		elif line.strip_edges().begins_with("{"):
			# this is a condition with multiple consequences (several lines of consequences)
			if not line.strip_edges().ends_with("}") and not "}" in line:
				insidecondition=true
				var condstat:=line.split(":",true,1)
				var consequences:Array=[]
				var active_choice_index := -1
				# first line
				if condstat[1].strip_edges().length()>0:
					var first_consequence := condstat[1].strip_edges()
					if first_consequence.begins_with("->") or first_consequence.begins_with("~") or first_consequence.begins_with("#"):
						consequences.push_back(first_consequence)
					else:
						var localized_first_consequence := {mainlang: first_consequence}
						for lang in languages:
							if not singlejson and lang != mainlang:
								localized_first_consequence[lang] = "<<translation>>"
						consequences.push_back(localized_first_consequence)
				# check next lines for consequences (up to 100)
				for i in range(1, 101):
					if not inkfilecontent.has(linenb + i):
						break
					var raw_consequence := str(inkfilecontent[linenb + i]).strip_edges()
					var closes_condition := raw_consequence.ends_with("}")
					raw_consequence = raw_consequence.trim_suffix("}").strip_edges()
					if raw_consequence.begins_with("+"):
						var conditional_choice_text := raw_consequence
						while conditional_choice_text.begins_with("+"):
							conditional_choice_text = conditional_choice_text.trim_prefix("+")
						var localized_choice_text := {mainlang: conditional_choice_text.strip_edges()}
						for lang in languages:
							if not singlejson and lang != mainlang:
								localized_choice_text[lang] = "<<translation>>"
						consequences.push_back({"type": "choice", "text": localized_choice_text, "consequences": []})
						active_choice_index = consequences.size() - 1
					elif raw_consequence != "":
						var parsed_consequence: Variant = raw_consequence
						if not raw_consequence.begins_with("->") and not raw_consequence.begins_with("~") and not raw_consequence.begins_with("#"):
							var localized_consequence := {mainlang: raw_consequence}
							for lang in languages:
								if not singlejson and lang != mainlang:
									localized_consequence[lang] = "<<translation>>"
							parsed_consequence = localized_consequence
						if active_choice_index >= 0:
							var conditional_choice: Dictionary = consequences[active_choice_index]
							conditional_choice["consequences"].push_back(parsed_consequence)
							consequences[active_choice_index] = conditional_choice
						else:
							consequences.push_back(parsed_consequence)
					if closes_condition:
						break
				var conditionblock={"type":"condition"}
				conditionblock["condition"]=condstat[0].strip_edges().trim_prefix("{").strip_edges()
				conditionblock["consequences"]=consequences # consequences are in an array
				conditionblock["choicerank"]=choicerank
				conditionblock["inkline"]=linenb
				modifiedcontent[currentknot][blockid]=conditionblock
				modifiedcontent[currentknot][previousblock]["next"]=blockid
				previousblock=blockid
				continue
			# line is not a condition with multiple sequences
			var regex = RegEx.new()
			regex.compile(r"{[^}]+}")  # Matches anything inside {}
			var underbrackets:=regex.search(line).get_string()
			# this is text starting with variable
			if not ":" in underbrackets:
				var textblock:=gentextblock(line,choicerank,linenb,singlejson,existingjson)
				modifiedcontent[currentknot][blockid]=textblock
			# this is a one-line conditional statement
			else: 
				underbrackets=underbrackets.strip_edges().trim_suffix("}").trim_prefix("{")
				var condstat:=underbrackets.split(":",true,1)
				var conditionblock={"type":"condition"}
				var consequences=condstat[1].strip_edges()
				if not consequences.begins_with("->") and not consequences.begins_with("~") and not consequences.begins_with("#"):
					if existingjson!={}:
						for item in existingjson.keys():
							if existingjson[item]["type"]=="condition":
								for cons in existingjson[item]["consequences"]:
									if cons is Dictionary and cons[mainlang] == consequences:
										blockid=item ; sortedcontent[linenb]=line + "<<" + blockid + ">>"
					var thecons:={} ; thecons[mainlang]=consequences
					for lang in languages: 
						if not singlejson and lang!=mainlang:thecons[lang]="<<translation>>"
						elif existingjson!={} and lang != mainlang:
							thecons[lang]="<<translation>>" # default
							for bloc in existingjson.keys():
								if existingjson[bloc].has("consequences") and existingjson[bloc]["consequences"][0] is Dictionary and existingjson[bloc]["consequences"][0][mainlang]==thecons[mainlang]:
									if existingjson[bloc]["consequences"][0].has(lang):
										thecons[lang]=existingjson[bloc]["consequences"][0][lang]
						elif lang!=mainlang: thecons[lang]="<<translation>>"
					consequences=thecons
				conditionblock["condition"]=condstat[0].strip_edges()
				conditionblock["consequences"]=[consequences] # consequences are in an array
				conditionblock["choicerank"]=choicerank
				conditionblock["inkline"]=linenb
				modifiedcontent[currentknot][blockid]=conditionblock
				#print(str("condition: "+condstat[0] + " consequence: "+condstat[1]).indent(createtabs(choicerank)))
			modifiedcontent[currentknot][previousblock]["next"]=blockid
			previousblock=blockid

		# code blocks (tag)
		elif line.strip_edges().begins_with("#") and line.strip_edges().length()>3:
			# specific root knot stuff
			if currentknot=="root" and line.begins_with("# LANG="):
				var langlist:String=line.trim_prefix("# LANG=")
				var langarray:=langlist.split(",")
				for item in langarray:
					var new:=item.strip_edges()
					langarray[langarray.find(item)]=new
				if langarray.size()>0:modifiedcontent["root"]["root"]["languages"]=langarray
				else:modifiedcontent["root"]["root"]["languages"]=[currentlang]
				if not singlejson: # situation where whole ink file is loaded
					Autoload.languages=langarray
					Autoload.currentlang=langarray[0]
					Autoload.mainlang=langarray[0]
				#print("specifying languages in the root knot: "+str(langarray))
			elif currentknot=="root" and line.begins_with("# GROUP="):
				var groupdata:String=line.trim_prefix("# GROUP=")
				var parts:=groupdata.split("|", false, 3)
				var groupname:=""
				var groupknots:Array=[]
				var groupcolor:=""
				if parts.size()>0:
					groupname=parts[0].strip_edges()
				if parts.size()>1 and parts[1].strip_edges()!="":
					for knot in parts[1].split(",", false):
						var normalized_knot:=knot.strip_edges()
						if normalized_knot!="":
							groupknots.push_back(normalized_knot)
				if parts.size()>2:
					groupcolor=parts[2].strip_edges().to_upper()
				if groupname!="":
					if not modifiedcontent["root"]["root"].has("groups"):
						modifiedcontent["root"]["root"]["groups"]=[]
					modifiedcontent["root"]["root"]["groups"].push_back({
						"name":groupname,
						"knots":groupknots,
						"collapsed":false,
						"color":groupcolor
					})
			# normal case
			else: 
				var tagblock={"type":"signal"}
				tagblock["instruction"]=line.replace("#","").strip_edges()
				tagblock["choicerank"]=choicerank
				tagblock["inkline"]=linenb
				modifiedcontent[currentknot][blockid]=tagblock
				modifiedcontent[currentknot][previousblock]["next"]=blockid
				previousblock=blockid
				#print(str("create a tag: "+line.trim_prefix("#").strip_edges()).indent(createtabs(choicerank)))

		# comments
		elif line.strip_edges().begins_with("//"):
			line = line.strip_edges()
			var tagblock={"type":"comment"}
			tagblock["comtext"]=line.trim_prefix("//").strip_edges()
			tagblock["choicerank"]=choicerank
			tagblock["inkline"]=linenb
			modifiedcontent[currentknot][blockid]=tagblock
			modifiedcontent[currentknot][previousblock]["next"]=blockid
			previousblock=blockid

		# weave blocks
		elif line.strip_edges().begins_with("-"):
			line = line.strip_edges()
			choicerank-=1 ; if choicerank<0:choicerank=0
			if choicerank==0: insidechoice=false
			var weaveblock={"type":"weave","text":{}}
			weaveblock["text"][mainlang]=line.trim_prefix("-").strip_edges()
			if existingjson!={} and weaveblock["text"][mainlang].length()>1:
				var reusable_weave_id := find_reusable_block_id(existingjson, used_existing_ids, "weave", weaveblock["text"][mainlang], choicerank)
				if reusable_weave_id != "":
					blockid = reusable_weave_id
					used_existing_ids[blockid] = true
					sortedcontent[linenb]=line + "<<" + blockid + ">>"
			if languages.size()>1:
				for lang in languages:
					if weaveblock["text"][mainlang].length()<2:weaveblock["text"][lang]=""
					elif not singlejson and lang!=mainlang: weaveblock["text"][lang]="<<translation>>"
					elif existingjson!={} and lang != mainlang:
						for bloc in existingjson.keys():
							if existingjson[bloc].has("text") and existingjson[bloc]["text"][mainlang]==weaveblock["text"][mainlang]:
								if existingjson[bloc]["text"].has(lang):weaveblock["text"][lang]=existingjson[bloc]["text"][lang]
								else: weaveblock["text"][lang]="<<translation>>"
							else: weaveblock["text"][lang]="<<translation>>"
					elif lang!=mainlang: weaveblock["text"][lang]="<<translation>>"
			weaveblock["choicerank"]=choicerank
			weaveblock["inkline"]=linenb
			modifiedcontent[currentknot][blockid]=weaveblock
			# find all possible previous blocks leading to the weave and connect them to weave block
			modifiedcontent[currentknot][previousblock]["next"]=blockid # block right before the weave leads to the weave
			# other previously constructed blocks without "next" info need to lead to the weave
			for item in modifiedcontent[currentknot]:
				if modifiedcontent[currentknot][item].has("next") and modifiedcontent[currentknot][item]["next"]=="":
					modifiedcontent[currentknot][item]["next"]=blockid
			previousblock=blockid

		# tag for manipulating variables
		elif line.strip_edges().begins_with("~") and line.strip_edges().length()>3:
			var tagblock={"type":"execute"}
			tagblock["instruction"]=line.strip_edges().trim_prefix("~").strip_edges()
			tagblock["choicerank"]=choicerank
			tagblock["inkline"]=linenb
			modifiedcontent[currentknot][blockid]=tagblock
			modifiedcontent[currentknot][previousblock]["next"]=blockid
			previousblock=blockid
			#print(str("change a variable: "+line.strip_edges().trim_prefix("~")).indent(createtabs(choicerank)))

		# all other cases: treat line as text to be displayed
		else:
			var textblock:=gentextblock(line,choicerank,linenb,singlejson,existingjson)
			if existingjson!={}:
				var reusable_text_id := find_reusable_block_id(existingjson, used_existing_ids, "text", textblock["text"][mainlang], choicerank)
				if reusable_text_id != "":
					blockid = reusable_text_id
					used_existing_ids[blockid] = true
					sortedcontent[linenb]=line + "<<" + blockid + ">>"
			modifiedcontent[currentknot][blockid]=textblock
			modifiedcontent[currentknot][previousblock]["next"]=blockid
			previousblock=blockid
			#print(str("print text: "+line.strip_edges()).indent(createtabs(choicerank)))
	return modifiedcontent

func gentextblock(line,choicerank,inkline, singlejson, existingjson) -> Dictionary: # generates a text block
	var textblock:={"type":"text","text":{}}
	textblock["text"][mainlang]=line.strip_edges()
	if languages.size()>1:
		for lang in languages:
			# case where parsing is done when importing .ink file
			if not singlejson and lang != mainlang:textblock["text"][lang]="<<translation>>"
			# case where parsing is done to save a single json
			elif existingjson!={} and lang != mainlang and textblock["text"][mainlang].length()>1:
				textblock["text"][lang]="<<translation>>" # default
				for bloc in existingjson.keys():
					if existingjson[bloc].has("text") and existingjson[bloc]["text"][mainlang]==textblock["text"][mainlang]:
						if existingjson[bloc]["text"].has(lang):textblock["text"][lang]=existingjson[bloc]["text"][lang]
			elif lang!=mainlang: textblock["text"][lang]="<<translation>>"
	textblock["choicerank"]=choicerank
	textblock["inkline"]=inkline
	textblock["next"]=""
	return textblock

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
	return "".join(uuid)

func createtabs(choicerank) ->String:
	var indent:=""
	for item in choicerank:
		indent+=" "
	return indent

func sortknot(knot) -> Array: 
	# organizes the bloc by inkline rank
	var simplified_array = []
	for key in knot:
		var entry = knot[key]
		simplified_array.append({
			"key": key,
			"type": entry.get("type", ""),
			"inkline": entry.get("inkline"),
			"choicerank": entry.get("choicerank")
		})
	simplified_array.sort_custom(func(a, b): return a["inkline"] < b["inkline"])
	return simplified_array

func inkvariableline(name:String,value)->String:
	# specific function required for ink style exports
	var literal:=str(value)
	if value is String:
		literal="\""
		for character in value:
			if character in "\\\"{}|#~<>/-":literal+="\\"
			literal+=character
		literal+="\""
	elif value is float and not "." in literal and not "e" in literal.to_lower():
		literal+=".0"
	return "VAR "+name+" = "+literal

func unescapeinkstring(text:String)->String:
	# in ink language, backslash escapes the next character
	var result:=""
	var escaped:=false
	for character in text:
		if character=="\\" and not escaped:
			escaped=true
			continue
		result+=character
		escaped=false
	if escaped:result+="\\"
	return result

func jsontoink(knotname,jsoncontent:Dictionary)->Array:
	inkarray.clear()
	if jsoncontent.size()<2: print ("cannot convert json"); return []
	var sortedknot:=sortknot(jsoncontent)
	inkarray.push_back("=== "+knotname+" ==="+"\n\n")
	var suffixes:={"goto":"-> ","signal":"# ","text":"","choice":"+ ","weave":"- ","execute":"~ ","root":"","condition":"","comment":"// ","stitch":"= "}
	for sortedbloc in sortedknot:
		var bloc=jsoncontent[sortedbloc.key]
		var suffix:String=suffixes[bloc.type]
		match bloc.type:
			"root":
				if bloc.has("variables"):
					for variable in bloc.variables:
						inkarray.push_back(inkvariableline(str(variable.name), variable.content)+"\n")
			"goto":
				inkarray.push_back(suffix+str(bloc.destination) +"\n")
			"signal":
				inkarray.push_back(suffix+str(bloc.instruction) +"\n")
			"comment":
				inkarray.push_back(suffix+str(bloc.comtext) +"\n")
			"text":
				var thetext:String
				if bloc.text is Dictionary:thetext=bloc.text[mainlang]
				else: thetext=bloc.text
				inkarray.push_back(thetext +"\n")
			"choice":
				var thetext:String
				if bloc.text is Dictionary: thetext = bloc.text[mainlang]
				else: thetext = bloc.text
				var prefix := ""
				for i in range(bloc.choicerank): prefix += "+"
				inkarray.push_back("\n" + prefix + " " + str(thetext) + "\n")
			"weave":
				var thetext:String
				if bloc.text is Dictionary:thetext=bloc.text[mainlang]
				else: thetext=bloc.text
				inkarray.push_back("\n"+suffix+str(thetext) +"\n")
			"execute":
				inkarray.push_back(suffix+str(bloc.instruction) +"\n")
			"stitch":
				inkarray.push_back("\n= " + str(bloc.name) + "\n")
			"condition":
				var conditiontext:="{"+str(bloc.condition)+":"
				var has_conditional_choice := false
				for consequence in bloc.consequences:
					if consequence is Dictionary and consequence.get("type", "") == "choice":
						has_conditional_choice = true
						break
				if bloc.consequences.size()>1 or has_conditional_choice:
					for cons in bloc.consequences:
						if cons is Dictionary and cons.get("type", "") == "choice":
							var conditional_choice_text = cons.get("text", "")
							if conditional_choice_text is Dictionary:
								conditional_choice_text = conditional_choice_text.get(mainlang, "")
							conditiontext += "\n\t+ " + str(conditional_choice_text)
							for choice_consequence in cons.get("consequences", []):
								if choice_consequence is Dictionary:
									choice_consequence = choice_consequence.get(mainlang, "")
								conditiontext += "\n\t\t" + str(choice_consequence)
						else:
							if cons is Dictionary: cons=cons[mainlang]
							conditiontext += "\n" + str(cons)
					conditiontext+="}" +"\n"
				else:
					var theconsequence:=str(bloc.consequences[0])
					if bloc.consequences[0] is Dictionary: theconsequence=str(bloc.consequences[0][mainlang])
					conditiontext+=theconsequence+"}" +"\n"
				inkarray.push_back(conditiontext.replace("[\"","").replace("\"]","").replace("\\", ""))

	return inkarray 
	

# ----------------
# file management 

func loadinkfile(file_path) -> Dictionary:
	# converts ink file into lines, each line being an instruction
	var lines = read_lines_from_file(file_path)
	if lines == null:print("Failed to read file.")
	return lines

func save_array_to_file(array: Array, file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		for entry in array:
			file.store_line(str(entry))
		file.close()
	else:
		print("Failed to save file: ", file_path)

func read_lines_from_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("Cannot open file: %s" % path)
		return {}
	var linecount:=0
	var lines:= {}
	while not file.eof_reached():
		var line = file.get_line()
		if line.strip_edges()!="":
			linecount+=1
			lines[linecount]=line
	file.close()
	return lines

func save_dict_to_json_file(dict: Dictionary, file_path: String) -> bool:
	uppercase_json_variables(dict,file_path)
	var json_string = JSON.stringify(dict, "\t")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		parserwarning.emit(tr("Could not save file: %s") % file_path)
		return false
	file.store_string(json_string)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		parserwarning.emit(tr("Could not save file: %s") % file_path)
		return false
	return true

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

# ----------------
# Variable names

func uppercase_json_variables(data:Dictionary,file_path:String)->void:
	var rootdata:Dictionary=data
	var rootpath:=file_path.get_base_dir().path_join("root.json")
	if not data.get("root",{}).has("variables") and FileAccess.file_exists(rootpath):
		var loaded=JSON.parse_string(FileAccess.get_file_as_string(rootpath))
		if loaded is Dictionary:rootdata=loaded
	var reader=load("res://inkmin/inkminreader.gd").new()
	for variable in rootdata.get("root",{}).get("variables",[]):
		reader.playervars[str(variable.name)]=variable.content
	for variable in data.get("root",{}).get("variables",[]):
		variable.name=reader.normalize_variable_name(str(variable.name))
	for block in data.values():
		uppercase_block_variables(block,reader)
	reader.free()

func uppercase_block_variables(block:Dictionary,reader:Node)->void:
	match block.get("type",""):
		"text","choice","weave":
			block.text=uppercase_text_variables(block.text,reader)
		"execute":
			block.instruction=uppercase_instruction_variables(block.instruction,reader)
		"condition":
			block.condition=uppercase_expression_variables(block.condition,reader)
	for i in block.get("consequences",[]).size():
		var consequence=block.consequences[i]
		if consequence is Dictionary and consequence.has("type"):
			uppercase_block_variables(consequence,reader)
			continue
		if consequence is String:
			var instruction:String=consequence.strip_edges()
			if instruction.begins_with("~"):
				block.consequences[i]=uppercase_instruction_variables(consequence,reader)
				continue
			if instruction.begins_with("#") or instruction.begins_with("->"):continue
		block.consequences[i]=uppercase_text_variables(consequence,reader)

func uppercase_instruction_variables(text:String,reader:Node)->String:
	var parts:=text.split("=",true,1)
	parts[0]=reader.normalize_variable_name(parts[0])
	# Keep unquoted string assignments, as accepted by the reader.
	if parts.size()==2 and reader.get_literal_string_value(parts[1].strip_edges())==null:
		parts[1]=uppercase_expression_variables(parts[1],reader)
	return "=".join(parts)

func uppercase_expression_variables(text:String,reader:Node)->String:
	var tokens:=RegEx.new()
	tokens.compile(r""""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"""
		+r"|0[xX][0-9a-fA-F]+"
		+r"|(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?"
		+r"|([\p{L}_][\p{L}\p{M}\p{N}_]*)")
	var result:=""
	var previous:=0
	for token in tokens.search_all(text):
		var name:=token.get_string(1)
		if name=="":continue
		if name.to_lower() in ["true","false","null","and","or","not","in","is","as"] or name in ["PI","TAU","INF","NAN"]:continue
		if text.substr(token.get_end()).strip_edges().begins_with("("):continue
		if text.substr(0,token.get_start()).strip_edges().ends_with("."):continue
		result+=text.substr(previous,token.get_start()-previous)+reader.normalize_variable_name(name)
		previous=token.get_end()
	return result+text.substr(previous)

func uppercase_text_variables(text:Variant,reader:Node)->Variant:
	if text is Dictionary:
		for lang in text:
			text[lang]=uppercase_text_variables(text[lang],reader)
		return text
	if not text is String:return text
	var placeholders:=RegEx.new()
	placeholders.compile(r"\{([\p{L}_][\p{L}\p{M}\p{N}_]*)\}")
	for placeholder in placeholders.search_all(text):
		text=text.replace(placeholder.get_string(),"{"+reader.normalize_variable_name(placeholder.get_string(1))+"}")
	return text
