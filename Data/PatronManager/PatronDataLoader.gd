extends Node
class_name PatronDataLoader

## Loader untuk memproses 4 file CSV terkait Patron menggunakan komponen modular

signal loading_started
signal loading_finished(success: bool, data: Dictionary, errors: Array)

var _errors: Array = []
var _config: Dictionary = {}
var _detected_files: Dictionary = {}

func _init() -> void:
	_config = DataSchemas.get_patron_files_config()

## Fungsi untuk validasi keberadaan file saja
func validate_files_only(base_dir: String) -> Dictionary:
	var result: Dictionary = PatronValidator.validate_files(base_dir, _config)
	_errors = result.get("errors", [])
	_detected_files = result.get("files", {})
	
	if _errors.size() > 0:
		return {"success": false, "errors": _errors}
	return {"success": true, "errors": [], "detected_files": _detected_files}

## Fungsi utama untuk memvalidasi dan memuat semua data
func load_patron_data(base_dir: String, selected_character: String) -> Dictionary:
	_errors.clear()
	
	# 1. Validasi dan deteksi file CSV
	var file_result: Dictionary = PatronValidator.validate_files(base_dir, _config)
	_detected_files = file_result.get("files", {})
	var file_errors: Array = file_result.get("errors", [])
	
	if file_errors.size() > 0:
		_errors.append_array(file_errors)
		return {"success": false, "errors": _errors}
	
	# 2. Validasi karakter ditemukan di semua file CSV
	var char_errors = PatronValidator.validate_character_in_files(base_dir, selected_character, _config, _detected_files)
	if char_errors.size() > 0:
		_errors.append_array(char_errors)
		return {"success": false, "errors": _errors}
		
	# 3. Baca data dari masing-masing file yang sudah terdeteksi
	var mapped_data = {
		"character_name": selected_character,
		"patron_info": {},
		"story_data": [],
		"orders_data": [],
		"idletalk_data": []
	}
	
	# Load each CSV using detected file paths
	if _detected_files.has("PATRONS"):
		var patrons_rows = PatronParser.parse_patron_csv(_detected_files["PATRONS"])
		mapped_data["patron_info"] = PatronParser.get_patron_info(patrons_rows, selected_character, _config["PATRONS"]["char_header"])
	
	if _detected_files.has("STORY"):
		var story_rows = PatronParser.parse_patron_csv(_detected_files["STORY"])
		mapped_data["story_data"] = PatronParser.get_story_data(story_rows, selected_character, _config["STORY"]["char_header"])
	
	if _detected_files.has("ORDERS"):
		var orders_rows = PatronParser.parse_patron_csv(_detected_files["ORDERS"])
		mapped_data["orders_data"] = PatronParser.get_orders_data(orders_rows, selected_character, _config["ORDERS"]["char_header"])
	
	if _detected_files.has("IDLETALK"):
		var idletalk_rows = PatronParser.parse_patron_csv(_detected_files["IDLETALK"])
		mapped_data["idletalk_data"] = PatronParser.get_idletalk_data(idletalk_rows, selected_character, _config["IDLETALK"]["char_header"])
	
	return {
		"success": true,
		"data": mapped_data,
		"errors": _errors
	}

## Generate JSON struktur sesuai format 
func generate_character_json(data: Dictionary) -> Dictionary:
	return PatronTransformer.generate_character_json(data)

## Simpan JSON ke file dengan nama karakter
func save_character_json(output_dir: String, character_name: String, json_data: Dictionary) -> Dictionary:
	var file_path: String = output_dir.path_join(character_name + ".json")
	var json_string: String = _stringify_dict(json_data)
	
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

## Mendapatkan file path berdasarkan tipe yang sudah terdeteksi
func get_detected_file_path(file_type: String) -> String:
	return _detected_files.get(file_type, "")


#region Custom JSON Stringify (preserve integer types)
const _INDENT := "\t"

func _stringify_dict(data: Dictionary, indent_level: int = 0) -> String:
	if data.is_empty():
		return "{}"
	
	var lines: Array[String] = []
	var indent := _INDENT.repeat(indent_level)
	var inner_indent := _INDENT.repeat(indent_level + 1)
	
	lines.append("{")
	var keys := data.keys()
	for i in range(keys.size()):
		var key = keys[i]
		var value = data[key]
		var comma := "," if i < keys.size() - 1 else ""
		var value_str := _value_to_json(value, indent_level + 1)
		lines.append("%s\"%s\": %s%s" % [inner_indent, key, value_str, comma])
	lines.append("%s}" % indent)
	
	return "\n".join(lines)


func _stringify_array(arr: Array, indent_level: int) -> String:
	if arr.is_empty():
		return "[]"
	
	var lines: Array[String] = []
	var indent := _INDENT.repeat(indent_level)
	var inner_indent := _INDENT.repeat(indent_level + 1)
	
	lines.append("[")
	for i in range(arr.size()):
		var item = arr[i]
		var comma := "," if i < arr.size() - 1 else ""
		var value_str := _value_to_json(item, indent_level + 1)
		lines.append("%s%s%s" % [inner_indent, value_str, comma])
	lines.append("%s]" % indent)
	
	return "\n".join(lines)


func _value_to_json(value: Variant, indent_level: int = 0) -> String:
	if value is String:
		return "\"%s\"" % _escape_json_string(value)
	elif value is bool:
		return "true" if value else "false"
	elif value is int:
		return str(value)
	elif value is float:
		if is_equal_approx(value, float(int(value))):
			return str(int(value))
		return str(value)
	elif value is Array:
		return _stringify_array(value, indent_level)
	elif value is Dictionary:
		return _stringify_dict(value, indent_level)
	elif value == null:
		return "null"
	else:
		return "\"%s\"" % str(value)


func _escape_json_string(s: String) -> String:
	s = s.replace("\\", "\\\\")
	s = s.replace("\"", "\\\"")
	s = s.replace("\n", "\\n")
	s = s.replace("\r", "\\r")
	s = s.replace("\t", "\\t")
	return s
#endregion

