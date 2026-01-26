extends Node
class_name MergeSystem

signal merge_finished(success: bool, result: Dictionary)

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

	var json_text := JSON.stringify(merged, "\t")
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
	return json.data

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

func _finish(result: Dictionary) -> Dictionary:
	merge_finished.emit(result.success, result)
	return result
