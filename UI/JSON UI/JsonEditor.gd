class_name JsonEditor
extends RefCounted

## Skrip untuk mengatur editing value JSON

signal value_changed(json_path: Array, new_value: Variant)
signal json_saved(path: String)
signal save_failed(error: String)

# Definisi urutan key yang akan disimpan
const KEY_ORDER = [
	"lineid",
	"name",
	"character",
	"text",
	"left",
	"middle_right",
	"middle",
	"middle_left",
	"right",
	"scene_properties",
	"dialogue_choice",
	"next_line_properties",
	"give_item",
	"chapterid",
	"goto",
	"special_effects",
	"sound_effect",
	"music_effect"
]

var _json_data: Variant = null
var _file_path: String = ""
var _has_unsaved_changes: bool = false

## Inisialisasi editor dengan data JSON
func init(data: Variant, file_path: String) -> void:
	_json_data = data
	_file_path = file_path
	_has_unsaved_changes = false

## GET data JSON saat ini
func get_data() -> Variant:
	return _json_data

## GET status apakah ada perubahan yang belum disimpan
func has_unsaved_changes() -> bool:
	return _has_unsaved_changes

## Edit value di path tertentu
## json_path adalah array dari key/index untuk navigasi ke value
func edit_value(json_path: Array, new_value: Variant) -> bool:
	if _json_data == null:
		return false
	
	if json_path.is_empty():
		_json_data = new_value
		_has_unsaved_changes = true
		value_changed.emit(json_path, new_value)
		return true
	
	# Navigasi ke parent dari value yang akan diedit
	var current = _json_data
	for i in range(json_path.size() - 1):
		var key = json_path[i]
		if current is Dictionary:
			if not current.has(key):
				return false
			current = current[key]
		elif current is Array:
			if key >= current.size():
				return false
			current = current[key]
		else:
			return false
	
	# Set value baru
	var final_key = json_path[json_path.size() - 1]
	if current is Dictionary:
		current[final_key] = new_value
		_has_unsaved_changes = true
		value_changed.emit(json_path, new_value)
		return true
	elif current is Array:
		if final_key < current.size():
			current[final_key] = new_value
			_has_unsaved_changes = true
			value_changed.emit(json_path, new_value)
			return true
	
	return false

## GET value dari path tertentu
func get_value_at_path(json_path: Array) -> Variant:
	if _json_data == null:
		return null
	
	if json_path.is_empty():
		return _json_data
	
	var current = _json_data
	for key in json_path:
		if current is Dictionary:
			if not current.has(key):
				return null
			current = current[key]
		elif current is Array:
			if key >= current.size():
				return null
			current = current[key]
		else:
			return null
	
	return current

## Tambahkan value ke array di path tertentu
func add_to_array(json_path: Array, value: Variant) -> bool:
	var container = get_value_at_path(json_path)
	if container == null or not container is Array:
		return false
	
	container.append(value)
	_has_unsaved_changes = true
	return true

## Tambahkan key-value ke dictionary di path tertentu
func add_to_dict(json_path: Array, key: String, value: Variant) -> bool:
	var container = get_value_at_path(json_path)
	if container == null or not container is Dictionary:
		return false
	
	container[key] = value
	_has_unsaved_changes = true
	return true

## Hapus item dari parent (gunakan path item yang akan dihapus)
func delete_from_parent(json_path: Array) -> bool:
	if json_path.is_empty():
		return false  # Tidak bisa hapus root
	
	# Dapatkan parent path dan key item yang akan dihapus
	var parent_path = json_path.slice(0, json_path.size() - 1)
	var item_key = json_path[json_path.size() - 1]
	
	var parent = get_value_at_path(parent_path)
	if parent == null:
		return false
	
	if parent is Dictionary:
		if parent.has(item_key):
			parent.erase(item_key)
			_has_unsaved_changes = true
			return true
	elif parent is Array:
		if item_key is int and item_key >= 0 and item_key < parent.size():
			parent.remove_at(item_key)
			_has_unsaved_changes = true
			return true
	
	return false

## Parse string ke number (int atau float)
static func parse_number_string(value_str: String) -> Variant:
	value_str = value_str.strip_edges()
	if value_str.is_valid_int():
		return value_str.to_int()
	elif value_str.is_valid_float():
		return value_str.to_float()
	return 0

## Simpan JSON ke file dengan urutan key yang terjaga
func save_to_file(path: String = "") -> bool:
	var save_path = path if not path.is_empty() else _file_path
	
	if save_path.is_empty():
		save_failed.emit("No file path specified")
		return false
	
	# Gunakan custom stringify untuk mempertahankan urutan key
	var json_string = stringify_ordered(_json_data)
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		var error_msg = "Cannot save file: " + str(FileAccess.get_open_error())
		save_failed.emit(error_msg)
		return false
	
	file.store_string(json_string)
	file.close()
	
	_file_path = save_path
	_has_unsaved_changes = false
	json_saved.emit(save_path)
	return true

## Fungsi Custom JSON stringify yang mempertahankan urutan key asli
func stringify_ordered(data: Variant, indent_level: int = 0) -> String:
	var indent = "\t".repeat(indent_level)
	var child_indent = "\t".repeat(indent_level + 1)
	
	if data == null:
		return "null"
	elif data is bool:
		return "true" if data else "false"
	elif data is int or data is float:
		return str(data)
	elif data is String:
		return "\"%s\"" % _escape_json_string(data)
	elif data is Array:
		if data.is_empty():
			return "[]"
			
		var items = []
		for item in data:
			items.append(child_indent + stringify_ordered(item, indent_level + 1))
		return "[\n%s\n%s]" % [",\n".join(items), indent]
	elif data is Dictionary:
		if data.is_empty():
			return "{}"
		
		var lines = []
		var keys = _get_ordered_keys(data)
		
		# Looping untuk setiap key di data
		for i in range(keys.size()):
			var key = keys[i]
			var value_str = stringify_ordered(data[key], indent_level + 1)
			var comma = "," if i < keys.size() - 1 else ""
			lines.append("%s\"%s\": %s%s" % [child_indent, key, value_str, comma])
		
		return "{\n%s\n%s}" % ["\n".join(lines), indent]
	else:
		return "\"%s\"" % str(data)

## GET keys dalam urutan yang sudah ditentukan
func _get_ordered_keys(dict: Dictionary) -> Array:
	var keys = dict.keys()
	var ordered_keys = []
	
	# Cek apakah ini adalah row data (memiliki key dari KEY_ORDER)
	var has_key_order_keys = false
	for key in KEY_ORDER:
		if dict.has(key):
			has_key_order_keys = true
			break
	
	if has_key_order_keys:
		# Gunakan KEY_ORDER untuk mengurutkan
		for key in KEY_ORDER:
			if dict.has(key):
				ordered_keys.append(key)
		# Tambahkan key lain yang tidak ada di KEY_ORDER
		for key in keys:
			if key not in ordered_keys:
				ordered_keys.append(key)
	else:
		# Gunakan urutan asli
		ordered_keys = keys
	
	return ordered_keys

## Escape karakter khusus dalam string JSON
func _escape_json_string(s: String) -> String:
	s = s.replace("\\", "\\\\")
	s = s.replace("\"", "\\\"")
	s = s.replace("\n", "\\n")
	s = s.replace("\r", "\\r")
	s = s.replace("\t", "\\t")
	return s

## Parse string value ke tipe yang sesuai
static func parse_value_string(value_str: String, original_type: String) -> Variant:
	value_str = value_str.strip_edges()
	
	match original_type:
		"null":
			if value_str.to_lower() == "null":
				return null
			return value_str
		"bool":
			if value_str.to_lower() == "true":
				return true
			elif value_str.to_lower() == "false":
				return false
			return value_str
		"int":
			if value_str.is_valid_int():
				return value_str.to_int()
			return value_str
		"float":
			if value_str.is_valid_float():
				return value_str.to_float()
			return value_str
		_:
			# Auto-detect type
			if value_str.to_lower() == "null":
				return null
			elif value_str.to_lower() == "true":
				return true
			elif value_str.to_lower() == "false":
				return false
			elif value_str.is_valid_int():
				return value_str.to_int()
			elif value_str.is_valid_float():
				return value_str.to_float()
			else:
				return value_str

## Mendapatkan tipe dari value sebagai string
static func get_type_string(value: Variant) -> String:
	if value == null:
		return "null"
	elif value is bool:
		return "bool"
	elif value is int:
		return "int"
	elif value is float:
		return "float"
	elif value is String:
		return "string"
	elif value is Dictionary:
		return "dict"
	elif value is Array:
		return "array"
	else:
		return "unknown"