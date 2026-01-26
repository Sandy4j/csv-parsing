extends Node
class_name PatronDataLoader

## Loader untuk memproses 4 file CSV terkait Patron:
## Patrons.csv, PatronStory.csv, Orders.csv, IdleTalkReqs.csv

signal loading_started
signal loading_finished(success: bool, data: Dictionary, errors: Array)

var _errors: Array = []
var _mapped_data: Dictionary = {}
var _config: Dictionary = {}
var _raw_data: Dictionary = {} # Store raw CSV data for validation

func _init() -> void:
	_config = DataSchemas.get_patron_files_config()

## Fungsi untuk validasi keberadaan file saja
func validate_files_only(base_dir: String) -> Dictionary:
	_errors.clear()
	if not _validate_files(base_dir):
		return {"success": false, "errors": _errors}
	return {"success": true, "errors": []}

## Fungsi utama untuk memvalidasi dan memuat semua data
func load_patron_data(base_dir: String, selected_character: String) -> Dictionary:
	_errors.clear()
	_raw_data.clear()
	_mapped_data = {
		"character_name": selected_character,
		"patron_info": {},
		"story_data": [],
		"orders_data": [],
		"idletalk_data": []
	}
	
	# 1. Validasi keberadaan semua file
	if not _validate_files(base_dir):
		return {"success": false, "errors": _errors}
	
	# 2. Validasi karakter ditemukan di semua file CSV
	var validation_result: Dictionary = _validate_character_exists(base_dir, selected_character)
	if not validation_result.get("success", false):
		return {"success": false, "errors": _errors}
		
	# 3. Baca data dari masing-masing file
	_load_patron_info(base_dir.path_join(_config["PATRONS"]["filename"]), selected_character)
	_load_story_data(base_dir.path_join(_config["STORY"]["filename"]), selected_character)
	_load_orders_data(base_dir.path_join(_config["ORDERS"]["filename"]), selected_character)
	_load_idletalk_data(base_dir.path_join(_config["IDLETALK"]["filename"]), selected_character)
	
	return {
		"success": true,
		"data": _mapped_data,
		"errors": _errors
	}

## Validasi karakter ada di semua file CSV yang diperlukan
func _validate_character_exists(base_dir: String, character_name: String) -> Dictionary:
	var missing_files: Array = []
	var found_in_patrons: bool = false
	
	# Check Patrons.csv first (master file)
	var patrons_path: String = base_dir.path_join(_config["PATRONS"]["filename"])
	var patrons_rows: Array = _parse_csv_to_array(patrons_path)
	if patrons_rows.size() > 1:
		var headers: Array = patrons_rows[0]
		var name_idx: int = _find_column_index(headers, _config["PATRONS"]["char_header"])
		if name_idx != -1:
			for i in range(1, patrons_rows.size()):
				var row: Array = patrons_rows[i]
				if row.size() > name_idx and str(row[name_idx]).strip_edges() == character_name:
					found_in_patrons = true
					break
	
	if not found_in_patrons:
		_errors.append("ERROR: Karakter '%s' tidak ditemukan di %s" % [character_name, _config["PATRONS"]["filename"]])
		return {"success": false}
	
	# Check PatronStory.csv
	var story_path: String = base_dir.path_join(_config["STORY"]["filename"])
	if not _character_exists_in_file(story_path, _config["STORY"]["char_header"], character_name, false):
		missing_files.append(_config["STORY"]["filename"])
	
	# Check Orders.csv (uses begins_with for pattern like "CharacterNameOrdersX")
	var orders_path: String = base_dir.path_join(_config["ORDERS"]["filename"])
	if not _character_exists_in_file(orders_path, _config["ORDERS"]["char_header"], character_name, true):
		missing_files.append(_config["ORDERS"]["filename"])
	
	# Check IdleTalkReqs.csv
	var idletalk_path: String = base_dir.path_join(_config["IDLETALK"]["filename"])
	if not _character_exists_in_file(idletalk_path, _config["IDLETALK"]["char_header"], character_name, false):
		missing_files.append(_config["IDLETALK"]["filename"])
	
	if missing_files.size() > 0:
		var files_list: String = ", ".join(missing_files)
		_errors.append("ERROR: Karakter '%s' ditemukan di %s tetapi tidak ada di file: %s" % [
			character_name, 
			_config["PATRONS"]["filename"], 
			files_list
		])
		return {"success": false}
	
	return {"success": true}

## Cek apakah karakter ada di file tertentu
func _character_exists_in_file(path: String, char_header: String, character_name: String, use_begins_with: bool) -> bool:
	var rows: Array = _parse_csv_to_array(path)
	if rows.size() <= 1: 
		return false
	
	var headers: Array = rows[0]
	var name_idx: int = _find_column_index(headers, char_header)
	if name_idx == -1:
		return false
	
	for i in range(1, rows.size()):
		var row: Array = rows[i]
		if row.size() > name_idx:
			var value: String = str(row[name_idx]).strip_edges()
			if use_begins_with:
				if value.begins_with(character_name):
					return true
			else:
				if value == character_name:
					return true
	return false

func _validate_files(base_dir: String) -> bool:
	var all_present: bool = true
	for key in _config:
		var file_path: String = base_dir.path_join(_config[key]["filename"])
		if not FileAccess.file_exists(file_path):
			_errors.append("File %s tidak ditemukan, coba masukan file dalam satu folder" % _config[key]["filename"])
			all_present = false
	return all_present

func _load_patron_info(path: String, character_name: String) -> void:
	var rows: Array = _parse_csv_to_array(path)
	if rows.is_empty(): return
	
	var headers: Array = rows[0]
	var char_header: String = _config["PATRONS"]["char_header"]
	var name_idx: int = _find_column_index(headers, char_header)
	
	if name_idx == -1:
		_errors.append("Kolom '%s' tidak ditemukan di %s" % [char_header, _config["PATRONS"]["filename"]])
		return

	for i in range(1, rows.size()):
		var row: Array = rows[i]
		if row.size() > name_idx and str(row[name_idx]).strip_edges() == character_name:
			var info: Dictionary = {}
			for j in range(mini(headers.size(), row.size())):
				info[str(headers[j]).strip_edges()] = str(row[j]).strip_edges()
			_mapped_data["patron_info"] = info
			break

func _load_story_data(path: String, character_name: String) -> void:
	var rows: Array = _parse_csv_to_array(path)
	if rows.is_empty(): return
	
	var headers: Array = rows[0]
	var char_header: String = _config["STORY"]["char_header"]
	var name_idx: int = _find_column_index(headers, char_header)
	
	if name_idx == -1:
		_errors.append("Kolom '%s' tidak ditemukan di %s" % [char_header, _config["STORY"]["filename"]])
		return

	for i in range(1, rows.size()):
		var row: Array = rows[i]
		if row.size() > name_idx and str(row[name_idx]).strip_edges() == character_name:
			var story_entry: Dictionary = {}
			for j in range(mini(headers.size(), row.size())):
				story_entry[str(headers[j]).strip_edges()] = str(row[j]).strip_edges()
			_mapped_data["story_data"].append(story_entry)

func _load_orders_data(path: String, character_name: String) -> void:
	var rows: Array = _parse_csv_to_array(path)
	if rows.is_empty(): return
	
	var headers: Array = rows[0]
	var char_header: String = _config["ORDERS"]["char_header"]
	var order_name_idx: int = _find_column_index(headers, char_header)
	
	if order_name_idx == -1:
		_errors.append("Kolom '%s' tidak ditemukan di %s" % [char_header, _config["ORDERS"]["filename"]])
		return

	for i in range(1, rows.size()):
		var row: Array = rows[i]
		# Orders.csv biasanya menggunakan Format: CharacterNameOrdersX
		if row.size() > order_name_idx and str(row[order_name_idx]).strip_edges().begins_with(character_name):
			var order_entry: Dictionary = {}
			for j in range(mini(headers.size(), row.size())):
				order_entry[str(headers[j]).strip_edges()] = str(row[j]).strip_edges()
			_mapped_data["orders_data"].append(order_entry)

func _load_idletalk_data(path: String, character_name: String) -> void:
	var rows: Array = _parse_csv_to_array(path)
	if rows.is_empty(): return
	
	var headers: Array = rows[0]
	var char_header: String = _config["IDLETALK"]["char_header"]
	var name_idx: int = _find_column_index(headers, char_header)
	
	if name_idx == -1:
		_errors.append("Kolom '%s' tidak ditemukan di %s" % [char_header, _config["IDLETALK"]["filename"]])
		return

	for i in range(1, rows.size()):
		var row: Array = rows[i]
		if row.size() > name_idx and str(row[name_idx]).strip_edges() == character_name:
			var talk_entry: Dictionary = {}
			for j in range(mini(headers.size(), row.size())):
				talk_entry[str(headers[j]).strip_edges()] = str(row[j]).strip_edges()
			_mapped_data["idletalk_data"].append(talk_entry)

func _parse_csv_to_array(path: String) -> Array:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null: return []
	
	var rows = []
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() > 0 and not (line.size() == 1 and line[0].strip_edges().is_empty()):
			# Handle format aneh dimana satu baris dibungkus kutip eksternal
			if line.size() == 1 and line[0].contains(","):
				var parsed_fields = _parse_csv_line_proper(line[0])
				rows.append(parsed_fields)
			else:
				rows.append(line)
	file.close()
	return rows

## Parse CSV line properly, handling quoted fields with commas
func _parse_csv_line_proper(line: String) -> Array:
	var fields = []
	var current_field = ""
	var in_quotes = false
	var i = 0
	
	while i < line.length():
		var c = line[i]
		
		if c == '"':
			# Check for escaped quotes ("")
			if in_quotes and i + 1 < line.length() and line[i + 1] == '"':
				current_field += '"'
				i += 2
				continue
			else:
				in_quotes = not in_quotes
		elif c == ',' and not in_quotes:
			fields.append(current_field.strip_edges())
			current_field = ""
		else:
			current_field += c
		
		i += 1
	
	# Tambahkan field terakhir
	fields.append(current_field.strip_edges())
	
	return fields

func _find_column_index(headers: Array, target: String) -> int:
	for i in range(headers.size()):
		if str(headers[i]).strip_edges().to_lower() == target.to_lower():
			return i
	return -1

## Generate JSON struktur sesuai format 
func generate_character_json(data: Dictionary) -> Dictionary:
	var patron_info: Dictionary = data.get("patron_info", {})
	var story_data: Array = data.get("story_data", [])
	var orders_data: Array = data.get("orders_data", [])
	var idletalk_data: Array = data.get("idletalk_data", [])
	var spawn_req: String = str(patron_info.get("required_story_id_to_spawn", ""))
	var json_output: Dictionary = {}

	json_output["character_name"] = data.get("character_name", "")
	json_output["character_name_stranger"] = str(patron_info.get("character_name_stranger", ""))
	json_output["patron_wealth"] = str(patron_info.get("patron_wealth", "Low"))
	json_output["partner_name"] = _parse_array_field(str(patron_info.get("partner_name", "")))
	json_output["is_spawnable"] = _parse_bool(str(patron_info.get("is_spawnable", "TRUE")))
	json_output["is_evening_spawnable"] = _parse_bool(str(patron_info.get("is_evening_spawnable", "TRUE")))
	json_output["is_night_spawnable"] = _parse_bool(str(patron_info.get("is_night_spawnable", "TRUE")))
	json_output["body_type"] = _parse_array_field(str(patron_info.get("body_type", "")))
	json_output["gender"] = _parse_array_field(str(patron_info.get("gender", "")))
	json_output["text_blip"] = str(patron_info.get("text_blip", ""))
	json_output["days_spawnable"] = _parse_days_array(str(patron_info.get("day_spawnable", "")))
	json_output["required_story_id_to_name"] = str(patron_info.get("required_story_id_to_name", ""))
	
	json_output["required_story_id_to_spawn"] = _parse_array_field(spawn_req) if not spawn_req.is_empty() else []
	json_output["story_requirements"] = _build_story_requirements(story_data)
	json_output["idle_talk_requirements"] = _build_idle_talk_requirements(idletalk_data)
	json_output["orders"] = _build_orders(orders_data)
	
	return json_output

func _parse_array_field(value: String) -> Array:
	if value.is_empty():
		return []
	var items: PackedStringArray = value.split(",")
	var result: Array = []
	for item in items:
		var stripped: String = item.strip_edges()
		if not stripped.is_empty():
			result.append(stripped)
	return result

func _parse_bool(value: String) -> bool:
	return value.strip_edges().to_upper() == "TRUE"

func _parse_days_array(value: String) -> Array:
	if value.is_empty():
		return []
	var items: PackedStringArray = value.split(",")
	var result: Array = []
	for item in items:
		var stripped: String = item.strip_edges()
		if stripped.is_valid_int():
			result.append(stripped.to_int())
	return result

func _build_story_requirements(story_data: Array) -> Dictionary:
	var story_reqs: Dictionary = {}
	
	if story_data.is_empty():
		return story_reqs
	
	# Find APPEAR entry for unlock requirement
	var unlock_req: Dictionary = {}
	var progress_reqs: Dictionary = {}
	
	for entry in story_data:
		var chapter_name: String = str(entry.get("chapter_name", ""))
		
		var req_entry: Dictionary = {
			"StoryId": _parse_array_field(str(entry.get("StoryId", ""))),
			"Visits": _parse_int(str(entry.get("Visits", "0"))),
			"Other_Visits": _parse_other_visits(str(entry.get("Other_Visits", ""))),
			"key_item": _parse_int(str(entry.get("key_item", "0"))),
			"Duration": _parse_int(str(entry.get("Duration", "0"))),
			"story_time": str(entry.get("story_time", "default")),
			"spawn_override": str(entry.get("spawn_override", "default")),
			"wealth_override": str(entry.get("wealth_override", "default"))
		}
		
		# Add badge_gain if present and non-zero
		var badge_gain: int = _parse_int(str(entry.get("badge_gain", "0")))
		if badge_gain > 0:
			req_entry["badge_gain"] = badge_gain
		
		if chapter_name == "APPEAR":
			unlock_req = req_entry
		else:
			progress_reqs[chapter_name] = req_entry
	
	if not unlock_req.is_empty():
		story_reqs["UnlockCharacterRequirement"] = unlock_req
	
	if not progress_reqs.is_empty():
		story_reqs["CharacterProgressRequirements"] = progress_reqs
	
	return story_reqs

func _build_idle_talk_requirements(idletalk_data: Array) -> Dictionary:
	var idle_reqs: Dictionary = {}
	var talk_entries: Dictionary = {}
	
	for entry in idletalk_data:
		var chapter_name: String = str(entry.get("chapter_name", ""))
		if chapter_name.is_empty():
			continue
		
		talk_entries[chapter_name] = {
			"StoryId": str(entry.get("StoryId", "")),
			"key_item": _parse_int(str(entry.get("key_item", "0")))
		}
	
	if not talk_entries.is_empty():
		idle_reqs["IdleTalkRequirements"] = talk_entries
	
	return idle_reqs

func _build_orders(orders_data: Array) -> Dictionary:
	var orders: Dictionary = {}
	
	for entry in orders_data:
		var order_set_name: String = str(entry.get("set_order_name", ""))
		# Extract set number from "CharacterNameOrdersX"
		var set_key: String = "set0"
		var orders_pos: int = order_set_name.find("Orders")
		if orders_pos != -1:
			var set_num: String = order_set_name.substr(orders_pos + 6)
			if not set_num.is_empty():
				set_key = "set" + set_num
		
		if not orders.has(set_key):
			orders[set_key] = {}
		
		var order_no: String = str(entry.get("no.", ""))
		if order_no.is_empty():
			continue
		
		var order_entry: Dictionary = {
			"entry_1_id": _parse_order_id(str(entry.get("entry_1_id", ""))),
			"entry_1_qty": _parse_int(str(entry.get("entry_1_qty", "1"))),
			"entry_2_id": _parse_order_id(str(entry.get("entry_2_id", ""))),
			"entry_2_qty": _parse_int(str(entry.get("entry_2_qty", "1"))),
			"traits": _build_order_traits(entry),
			"weighted_chance": _parse_int(str(entry.get("weighted_chance", "10")))
		}
		
		orders[set_key][order_no] = order_entry
	
	return orders

func _parse_int(value: String) -> int:
	var stripped: String = value.strip_edges()
	if stripped.is_valid_int():
		return stripped.to_int()
	return 0

func _parse_other_visits(value: String) -> Array:
	if value.is_empty():
		return []
	# Format: "CharacterName, count"
	var parts: PackedStringArray = value.split(",")
	var result: Array = []
	var i: int = 0
	while i < parts.size():
		var name_part: String = parts[i].strip_edges()
		if not name_part.is_empty():
			if i + 1 < parts.size() and parts[i + 1].strip_edges().is_valid_int():
				result.append({"character": name_part, "visits": parts[i + 1].strip_edges().to_int()})
				i += 2
				continue
			else:
				result.append(name_part)
		i += 1
	return result

func _parse_order_id(value: String) -> Variant:
	var stripped: String = value.strip_edges()
	if stripped.is_valid_int():
		return stripped.to_int()
	return stripped

func _build_order_traits(entry: Dictionary) -> Array:
	var traits: Array = []
	for i in range(1, 4):
		var trait_key: String = "trait_%d" % i
		var trait_val: String = str(entry.get(trait_key, ""))
		if not trait_val.is_empty() and trait_val != "-":
			traits.append(trait_val.strip_edges())
	return traits

## Simpan JSON ke file dengan nama karakter
func save_character_json(output_dir: String, character_name: String, json_data: Dictionary) -> Dictionary:
	var file_path: String = output_dir.path_join(character_name + ".json")
	
	var json_string: String = JSON.stringify(json_data, "\t")
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		var err: int = FileAccess.get_open_error()
		return {"success": false, "error": "Gagal membuat file: %s (Error: %d)" % [file_path, err]}
	
	file.store_string(json_string)
	file.close()
	
	return {"success": true, "path": file_path}

## Fungsi lengkap: load, generate, dan save JSON
func process_character(base_dir: String, output_dir: String, selected_character: String) -> Dictionary:
	# Load data
	var load_result: Dictionary = load_patron_data(base_dir, selected_character)
	if not load_result.get("success", false):
		return load_result
	
	var json_data: Dictionary = generate_character_json(load_result.get("data", {}))
	
	var save_result: Dictionary = save_character_json(output_dir, selected_character, json_data)
	if not save_result.get("success", false):
		return {"success": false, "errors": [save_result.get("error", "Unknown error")]}
	
	return {
		"success": true,
		"data": json_data,
		"file_path": save_result.get("path", ""),
		"errors": load_result.get("errors", [])
	}