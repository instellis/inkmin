extends Control

# Window for exporting, checking and importing .csv language files

var jsonfolder:="" # updated by editor
var languages:=[]
var mainlang:=""
var allknots:=[]
var thefiledialog:FileDialog
var filedialogmission=""
var csvdata:=[]

func get_condition_translation_texts(consequence: Variant) -> Array:
	if not (consequence is Dictionary):
		return []
	if consequence.get("type", "") != "choice":
		return [consequence]
	var localized_texts := []
	if consequence.get("text", "") is Dictionary:
		localized_texts.push_back(consequence["text"])
	for choice_consequence in consequence.get("consequences", []):
		if choice_consequence is Dictionary:
			localized_texts.push_back(choice_consequence)
	return localized_texts

func _on_closebutton_pressed() -> void:
	languages.clear()
	mainlang=""
	allknots.clear()
	csvdata.clear()
	hide()

func _on_clearlog_pressed() -> void:
	%translationlog.text=""

func _on_exportcsv_pressed() -> void:
	# initiate data
	csvdata.clear()
	loadroot()
	if languages.size()<2:
		%translationlog.text+="[color=red]"+tr("Add a translation language in the root knot before exporting")+"[/color]\n"
		return
	if allknots.size()<1 or mainlang=="":
		%translationlog.text+="[color=red]Problem with the root json file[/color]\n"
		return
	# load each json and create the csv data
	# csv format : knotname, UID, type, lang1, lang2, etc 
	var alltheknots:=allknots.duplicate() ; alltheknots.erase("root")
	var blockdata="knot name"+"\t"+"UID"+"\t"+"type"+"\t"
	for lang in languages: blockdata+=lang+"\t"
	blockdata=blockdata.strip_edges()
	csvdata.push_back(blockdata)
	for knot in alltheknots:
		var theknot:=load_json_file(jsonfolder+knot+".json")
		if theknot.size()<1:
			%translationlog.text+="[color=red]Problem with the json file "+knot+".json[/color]\n"
			return
		else: %translationlog.text+="[color=black]Extracted data from json file "+knot+".json[/color]\n"
		var thedata:=sort_theknot_by_inkline(theknot) # sorted array of blocks
		for block in thedata:
			blockdata=""
			match block.type:
				"text":
					blockdata=knot+"\t"+block.UID+"\t"+block.type+"\t"
					for lang in languages:blockdata+=block.text.get(lang,"<<translation>>")+"\t"
					blockdata=blockdata.strip_edges()
				"choice":
					blockdata=knot+"\t"+block.UID+"\t"+block.type+"\t"
					for lang in languages:blockdata+=block.text.get(lang,"<<translation>>")+"\t"
					blockdata=blockdata.strip_edges()
				"weave":
					if block.text.get(mainlang,"").length()>0:
						blockdata=knot+"\t"+block.UID+"\t"+block.type+"\t"
						for lang in languages:blockdata+=block.text.get(lang,"<<translation>>")+"\t"
						blockdata=blockdata.strip_edges()
				"condition":
					for cons in block.consequences:
						for localized_text in get_condition_translation_texts(cons):
							blockdata=knot+"\t"+block.UID+"\t"+block.type+"\t"
							for lang in languages:blockdata+=localized_text.get(lang,"<<translation>>")+"\t"
							csvdata.push_back(blockdata) ; blockdata=""
			if blockdata!="":csvdata.push_back(blockdata)

	# determine save file path 
	thefiledialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
	thefiledialog.filters=["*.tsv"]
	filedialogmission="savecsv"
	thefiledialog.show() ; thefiledialog.get_ok_button().text=tr("save")

func _on_checkcsv_pressed() -> void:
	# initiate data
	loadroot()
	if languages.size()<2 or allknots.size()<1 or mainlang=="":
		%translationlog.text+="[color=red]Problem with the root json file[/color]\n"
		return
	# load csv data
	thefiledialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
	thefiledialog.filters=["*.tsv"]
	filedialogmission="checkcsv"
	thefiledialog.show() ; thefiledialog.get_ok_button().text=tr("check")

func savecsv(path)->void: # called by filedialog results in editor.gd
	save_array_to_tsv(csvdata,path)

func _on_injectcsv_pressed() -> void:
	Autoload.editornode.popup("Are you sure you want to change all the json files?",true)
	var answer = await Autoload.editornode.yesornoanswer
	if answer=="no":return
	# initiate data
	loadroot()
	if languages.size()<2 or allknots.size()<1 or mainlang=="":
		%translationlog.text+="[color=red]Problem with the root json file[/color]\n"
		return
	# load csv data
	thefiledialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
	thefiledialog.filters=["*.tsv"]
	filedialogmission="injectcsv"
	thefiledialog.show() ; thefiledialog.get_ok_button().text=tr("load")

func injectcsv(path)->void: # called by filedialog results in editor.gd
	# load and convert the TSV data into a dictionary sorted by knot name
	csvdata=load_tsv_file(path)
	csvdata.remove_at(0) # remove TSV header information
	var translationdata := {}
	# translationdata has knot name as key and all mainlang texts as array elements
	for line in csvdata:
		if line.size() >= 3+languages.size():
			var key = line[0] # knot name
			var value = {} ; var counter:=0
			for lang in languages:
				value[lang]=line[3+counter]
				counter+=1
			if not translationdata.has(key):translationdata[key] = []
			translationdata[key].append(value)

	 #check out TSV data against each json file concerned
	var alltheknots:=allknots.duplicate() ; alltheknots.erase("root")
	var errors:=0
	for knot in alltheknots:
		var theknot:=load_json_file(jsonfolder+knot+".json")
		if theknot.size()<1:
			%translationlog.text+="[color=red]Problem with the json file "+knot+".json[/color]\n"
			return
		else: %translationlog.text+="[color=black]Checking json file "+knot+".json[/color]\n"
		for block in theknot.keys():
			var theblock:Dictionary=theknot[block]
			match theblock["type"]:
				"text":
					var foundmatch:=false
					for item in translationdata[knot]:
						if item[mainlang] == theblock["text"][mainlang]: 
							foundmatch=true
							for lang in languages:
								if lang!=mainlang: theblock["text"][lang]=item[lang]
					if not foundmatch:
						%translationlog.text+="[color=red]Main language mismatch for UID "+block+"[/color]\n"
						errors+=1
				"choice":
					var foundmatch:=false
					for item in translationdata[knot]:
						if item[mainlang] == theblock["text"][mainlang]: 
							foundmatch=true
							for lang in languages:
								if lang!=mainlang: theblock["text"][lang]=item[lang]
					if not foundmatch:
						%translationlog.text+="[color=red]Main language mismatch for UID "+block+"[/color]\n"
						errors+=1
				"weave":
					if theblock["text"][mainlang].length()>1:
						var foundmatch:=false
						for item in translationdata[knot]:
							if item[mainlang] == theblock["text"][mainlang]: 
								foundmatch=true
								for lang in languages:
									if lang!=mainlang: theblock["text"][lang]=item[lang]
						if not foundmatch:
							%translationlog.text+="[color=red]Main language mismatch for UID "+block+"[/color]\n"
							errors+=1
					elif theblock["text"][mainlang]=="" or theblock["text"][mainlang]==" ":
						for lang in languages:
							if lang!=mainlang: theblock["text"][lang]="" # clean up <<translation>> tag when no text in weave
				"condition":
					for cons in theblock.consequences:
						for localized_text in get_condition_translation_texts(cons):
							var foundmatch:=false
							for item in translationdata[knot]:
								if item[mainlang] == localized_text[mainlang]:
									foundmatch=true
									for lang in languages:
										if lang!=mainlang: localized_text[lang]=item[lang]
							if not foundmatch:
								%translationlog.text+="[color=red]Main language mismatch for UID "+block+"[/color]\n"
								errors+=1
		if not save_dict_to_json_file(theknot,jsonfolder+knot+".json"):
			%translationlog.text+="[color=red]"+(tr("Could not save file: %s") % (jsonfolder+knot+".json"))+"[/color]\n"
			return
	%translationlog.text+="[color=blue]Finished injecting TSV file. Found "+str(errors)+" missing translation lines.\n"
	csvdata.clear()
	# reset situation in the main editor
	Autoload.editornode.displayroot()

func checkcsv(path)->void: # called by filedialog results in editor.gd
	# load and convert the TSV data into a dictionary sorted by knot name
	csvdata=load_tsv_file(path)
	if csvdata.is_empty():
		%translationlog.text+="[color=red]"+tr("No TSV data to check")+"[/color]\n"
		return
	var header=csvdata[0]
	var maincolumn:int=header.find(mainlang)
	if maincolumn<0:
		%translationlog.text+="[color=red]"+(tr("Main language column missing: %s") % mainlang)+"[/color]\n"
		csvdata.clear()
		return
	csvdata.remove_at(0) # remove TSV header information
	var translationdata := {}
	var missingtranslations:=0
	var rownumber:=1
	# translationdata has knot name as key and all mainlang texts as array elements
	for line in csvdata:
		rownumber+=1
		if line.size() > maincolumn:
			var key = line[0] # knot name
			var value = line[maincolumn] # mainlang text
			if not translationdata.has(key):translationdata[key] = []
			translationdata[key].append(value)
		for lang in languages:
			if lang==mainlang:continue
			var column:int=header.find(lang)
			var text:=""
			if column>=0 and column<line.size():text=line[column].strip_edges()
			if text=="" or text=="<<translation>>":
				%translationlog.text+="[color=red]"+(tr("Missing %s translation at TSV row %d") % [lang,rownumber])+"[/color]\n"
				missingtranslations+=1

	 #check out TSV data against each json file concerned
	var alltheknots:=allknots.duplicate() ; alltheknots.erase("root")
	var errors:=0
	for knot in alltheknots:
		var theknot:=load_json_file(jsonfolder+knot+".json")
		if theknot.size()<1:
			%translationlog.text+="[color=red]Problem with the json file "+knot+".json[/color]\n"
			return
		else: %translationlog.text+="[color=black]Checking json file "+knot+".json[/color]\n"
		for block in theknot.keys():
			var theblock:Dictionary=theknot[block]
			match theblock["type"]:
				"text": 
					if not translationdata.get(knot,[]).has(theblock["text"][mainlang]):
						%translationlog.text+="[color=red]"+(tr("Source line missing from TSV for UID %s") % block)+"[/color]\n"
						errors+=1
				"choice":
					if not translationdata.get(knot,[]).has(theblock["text"][mainlang]):
						%translationlog.text+="[color=red]"+(tr("Source line missing from TSV for UID %s") % block)+"[/color]\n"
						errors+=1
				"weave":
					if theblock["text"].get(mainlang,"").length()>0 and not translationdata.get(knot,[]).has(theblock["text"][mainlang]):
						%translationlog.text+="[color=red]"+(tr("Source line missing from TSV for UID %s") % block)+"[/color]\n"
						errors+=1
				"condition":
					for cons in theblock.consequences:
						for localized_text in get_condition_translation_texts(cons):
							if not translationdata.get(knot,[]).has(localized_text[mainlang]):
								%translationlog.text+="[color=red]"+(tr("Source line missing from TSV for UID %s") % block)+"[/color]\n"
								errors+=1
	%translationlog.text+="[color=blue]"+(tr("Finished checking TSV file. Found %d missing source lines and %d missing translations.") % [errors,missingtranslations])+"[/color]\n"
	csvdata.clear()

func sort_theknot_by_inkline(theknot: Dictionary) -> Array:
	var pairs = []
	# Convert the dictionary into an array of key-value pairs
	for key in theknot.keys():
		var value = theknot[key]
		value["UID"]=key
		if value["type"]=="text" or value["type"]=="weave" or value["type"]=="choice" or value["type"]=="condition":
			pairs.append(value)
	# Sort the array by "inkline" value
	pairs.sort_custom(func(a, b):
		return a.get("inkline", 0) < b.get("inkline", 0)
	)
	return pairs

func fileselected(path)->void:
	match filedialogmission:
		"checkcsv": checkcsv(path) 
		"savecsv": savecsv(path)
		"injectcsv": injectcsv(path)
	filedialogmission=""

func loadroot()->void:
	# load rootjson to get initial data
	var rootknot:=load_json_file(jsonfolder+"root.json")
	if rootknot.size()<2:%translationlog.text+="[color=red]Root json could not be loaded[/color]\n"
	else:%translationlog.text+="[color=black]Root json loaded[/color]\n"
	languages=rootknot["root"]["languages"]
	mainlang=languages[0]
	allknots=rootknot["root"]["knots"]
	%translationlog.text+="[color=blue]Identified languages: "+str(languages)+"\n"

func save_array_to_tsv(array_data: Array, file_path: String):
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		%translationlog.text+="[color=red]Failed to open file for writing: %s\n" % file_path
		return
	for line in array_data:
		file.store_line(line)
	file.close()
	%translationlog.text+="[color=blue]Saved tsv file: %s" % file_path+ "[/color]\n"
	csvdata.clear()

func load_tsv_file(file_path: String) -> Array:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		%translationlog.text+="[color=red]Failed to open file: %s [/color]\n" % file_path
		return []
	var result := []
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var fields := line.split("\t")
		result.append(fields)
	file.close()
	%translationlog.text+="[color=blue]Tsv file loaded [/color]\n"
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

func save_dict_to_json_file(dict: Dictionary, file_path: String) -> bool:
	return Autoload.editornode.get_node("inkminconverter").save_dict_to_json_file(dict,file_path)
