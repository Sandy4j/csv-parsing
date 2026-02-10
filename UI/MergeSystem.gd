extends Node
class_name MergeSystem

signal merge_finished(success: bool, result: Dictionary)

const INDENT_STRING := "\t"

func merge_json_files(file_paths: Array[String], output_path: String) -> Dictionary:
	var result := {
		"success": false,
		"errors": [],
		"skipped": [],
		"merged_keys": [],
		"output_path": output_path
	}
	if file_paths.is_empty():
		result.errors.append("Tidak ada file yang dipilih.")
		return _finish(result)
	if output_path.strip_edges().is_empty():
		result.errors.append("Path output kosong.")
		return _finish(result)

	var merged: Dictionary = {}
	for path in file_paths:
		var data = _load_json(path, result.errors)
		if data == null:
			continue
		var arrays_map = _extract_array_payloads(data, path)
		if arrays_map.is_empty():
			result.skipped.append(path)
			continue
		for key in arrays_map.keys():
			if not merged.has(key):
				merged[key] = []
			merged[key].append_array(arrays_map[key])

	if merged.is_empty():
		result.errors.append("Tidak ada array yang bisa digabungkan.")
		return _finish(result)

	if not _ensure_output_dir(output_path, result.errors):
		return _finish(result)

	var json_text := _stringify_dict(merged)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		result.errors.append("Gagal menulis file: %s (error %s)" % [output_path, str(FileAccess.get_open_error())])
		return _finish(result)
	file.store_string(json_text)
	file.close()

	result.success = true
	result.merged_keys = merged.keys()
	return _finish(result)

func _load_json(path: String, errors: Array) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Tidak bisa membuka file: %s (error %s)" % [path, str(FileAccess.get_open_error())])
		return null
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		errors.append("JSON tidak valid: %s (line %d)" % [path, json.get_error_line()])
		return null
	
	# Konversi float ke int jika value adalah bilangan bulat
	return _convert_floats_to_ints(json.data)

func _extract_array_payloads(data: Variant, source_path: String) -> Dictionary:
	var output: Dictionary = {}
	if data is Dictionary:
		for key in data.keys():
			var value = data[key]
			if value is Array:
				output[key] = value
	elif data is Array:
		var inferred_key := source_path.get_file().trim_suffix("." + source_path.get_extension())
		if inferred_key.is_empty():
			inferred_key = "Data"
		output[inferred_key] = data
	return output

func _ensure_output_dir(output_path: String, errors: Array) -> bool:
	var dir_path := output_path.get_base_dir()
	if DirAccess.dir_exists_absolute(dir_path):
		return true
	var create_err := DirAccess.make_dir_recursive_absolute(dir_path)
	if create_err != OK:
		errors.append("Gagal membuat folder output: %s (error %s)" % [dir_path, str(create_err)])
		return false
	return true


## Konversi rekursif float ke int jika nilainya bilangan bulat
## Godot JSON.parse() mengkonversi semua angka ke float, ini mengembalikan ke int jika sesuai
func _convert_floats_to_ints(data: Variant) -> Variant:
	if data is Dictionary:
		var result: Dictionary = {}
		for key in data.keys():
			result[key] = _convert_floats_to_ints(data[key])
		return result
	elif data is Array:
		var result: Array = []
		for item in data:
			result.append(_convert_floats_to_ints(item))
		return result
	elif data is float:
		# Cek apakah float adalah bilangan bulat
		if is_equal_approx(data, float(int(data))):
			return int(data)
		return data
	else:
		return data

func _finish(result: Dictionary) -> Dictionary:
	merge_finished.emit(result.success, result)
	return result


## Custom stringify untuk Dictionary dengan preservasi tipe integer
func _stringify_dict(data: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("{")
	
	var keys = data.keys()
	for i in range(keys.size()):
		var key = keys[i]
		var value = data[key]
		var comma = "," if i < keys.size() - 1 else ""
		
		if value is Array:
			lines.append("%s\"%s\": [" % [INDENT_STRING, key])
			lines.append_array(_stringify_array_items(value, 2))
			lines.append("%s]%s" % [INDENT_STRING, comma])
		elif value is Dictionary:
			lines.append("%s\"%s\": %s%s" % [INDENT_STRING, key, _stringify_nested_dict(value, 1), comma])
		else:
			lines.append("%s\"%s\": %s%s" % [INDENT_STRING, key, _value_to_json(value), comma])
	
	lines.append("}")
	return "\n".join(lines)


## Stringify array items dengan indentasi
func _stringify_array_items(arr: Array, indent_level: int) -> Array[String]:
	var lines: Array[String] = []
	var indent = INDENT_STRING.repeat(indent_level)
	
	for i in range(arr.size()):
		var item = arr[i]
		var comma = "," if i < arr.size() - 1 else ""
		
		if item is Dictionary:
			lines.append("%s{" % indent)
			lines.append_array(_stringify_object_fields(item, indent_level + 1))
			lines.append("%s}%s" % [indent, comma])
		elif item is Array:
			lines.append("%s%s%s" % [indent, _stringify_inline_array(item), comma])
		else:
			lines.append("%s%s%s" % [indent, _value_to_json(item), comma])
	
	return lines


## Stringify object fields dengan key order yang sudah diurutkan
func _stringify_object_fields(obj: Dictionary, indent_level: int) -> Array[String]:
	var lines: Array[String] = []
	var indent = INDENT_STRING.repeat(indent_level)
	var keys = obj.keys()
	
	for i in range(keys.size()):
		var key = keys[i]
		var value = obj[key]
		var comma = "," if i < keys.size() - 1 else ""
		
		if value is Dictionary:
			lines.append("%s\"%s\": %s%s" % [indent, key, _stringify_nested_dict(value, indent_level), comma])
		elif value is Array:
			lines.append("%s\"%s\": %s%s" % [indent, key, _stringify_inline_array(value), comma])
		else:
			lines.append("%s\"%s\": %s%s" % [indent, key, _value_to_json(value), comma])
	
	return lines


## Stringify nested dictionary (untuk object di dalam object)
func _stringify_nested_dict(dict: Dictionary, indent_level: int) -> String:
	if dict.is_empty():
		return "{}"
	
	var items: Array[String] = []
	for key in dict.keys():
		var value = dict[key]
		if value is Dictionary:
			items.append("\"%s\": %s" % [key, _stringify_nested_dict(value, indent_level + 1)])
		elif value is Array:
			items.append("\"%s\": %s" % [key, _stringify_inline_array(value)])
		else:
			items.append("\"%s\": %s" % [key, _value_to_json(value)])
	
	return "{%s}" % ", ".join(items)


## Stringify array secara inline (compact)
func _stringify_inline_array(arr: Array) -> String:
	if arr.is_empty():
		return "[]"
	
	var items: Array[String] = []
	for item in arr:
		if item is Dictionary:
			items.append(_stringify_nested_dict(item, 0))
		elif item is Array:
			items.append(_stringify_inline_array(item))
		else:
			items.append(_value_to_json(item))
	
	return "[%s]" % ", ".join(items)


## Konversi value ke JSON string dengan preservasi tipe integer
func _value_to_json(value: Variant) -> String:
	if value is String:
		return "\"%s\"" % _escape_json_string(value)
	elif value is bool:
		return "true" if value else "false"
	elif value is int:
		return str(value)
	elif value is float:
		# Jika float tanpa pecahan, tampilkan sebagai int
		if is_equal_approx(value, float(int(value))):
			return str(int(value))
		return str(value)
	elif value == null:
		return "null"
	else:
		return "\"%s\"" % str(value)


## Escape karakter khusus untuk JSON string
func _escape_json_string(s: String) -> String:
	s = s.replace("\\", "\\\\")
	s = s.replace("\"", "\\\"")
	s = s.replace("\n", "\\n")
	s = s.replace("\r", "\\r")
	s = s.replace("\t", "\\t")
	return s


