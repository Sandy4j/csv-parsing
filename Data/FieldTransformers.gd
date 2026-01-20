class_name FieldTransformers
extends RefCounted

## Skrip untuk mengubah value field berdasarkan type

## Buat error dictionary dengan detail
static func create_error(msg: String, r_id: String = "", line: int = 0, field: String = "", is_fatal: bool = false) -> Dictionary:
	return {
		"message": msg,
		"row_id": r_id,
		"line_number": line,
		"field_name": field,
		"is_fatal": is_fatal
	}

## Transform value berdasarkan type
## error_log: Array opsional untuk mengumpulkan pesan error
## context: String konteks lokasi data (misal: "Baris [ID: 5], Kolom: amount")
## row_id: ID dari baris yang sedang diproses
## line_number: Nomor baris dalam CSV
## field_name: Nama field yang sedang diproses
static func transform(raw_value: String, field_type: String, default_value = null, error_log: Array = [], context: String = "", row_id: String = "", line_number: int = 0, field_name: String = "") -> Variant:
	if raw_value.is_empty() and default_value != null:
		return default_value
	
	match field_type:
		"string":
			return raw_value
		"int":
			if raw_value.is_valid_int():
				return raw_value.to_int()
			else:
				var default_int = default_value if default_value != null else 0
				if not raw_value.is_empty():
					var msg = "Konversi Integer Gagal: '%s' pada %s. Menggunakan default: %s" % [raw_value, context, str(default_int)]
					push_warning(msg)
					_log_error(error_log, msg, row_id, line_number, field_name if not field_name.is_empty() else context)
				return default_int
		"float":
			if raw_value.is_valid_float():
				return raw_value.to_float()
			else:
				var default_float = default_value if default_value != null else 0.0
				if not raw_value.is_empty():
					var msg = "Konversi Float Gagal: '%s' pada %s. Menggunakan default: %s" % [raw_value, context, str(default_float)]
					push_warning(msg)
					_log_error(error_log, msg, row_id, line_number, field_name if not field_name.is_empty() else context)
				return default_float
		"bool":
			return raw_value.to_lower() == "true"
		"array":
			return parse_array(raw_value)
		"array_int":
			return parse_array_int(raw_value, error_log, context, row_id, line_number)
		"scene_props":
			return parse_scene_props(raw_value, error_log, context, row_id, line_number, field_name if not field_name.is_empty() else "scene_properties")
		"next_line":
			return parse_next_line(raw_value, error_log, context, row_id, line_number, field_name if not field_name.is_empty() else "next_line_properties")
		"traits":
			return parse_traits(raw_value, error_log, context, row_id, line_number)
		_:
			return raw_value


## Catat error ke array jika tersedia (sekarang menyimpan Dictionary)
static func _log_error(error_log: Array, message: String, row_id: String = "", line_number: int = 0, field: String = "", is_fatal: bool = false) -> void:
	if error_log != null and not message.is_empty():
		var err = create_error(message, row_id, line_number, field, is_fatal)
		error_log.append(err)


## Parse field menjadi array string
static func parse_array(field: String) -> Array:
	var result = []
	var parts = field.split(",")
	for part in parts:
		var trimmed = part.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)
	return result


## Parse field menjadi array integer
static func parse_array_int(field: String, error_log: Array = [], context: String = "", row_id: String = "", line_number: int = 0) -> Array:
	var result = []
	var parts = field.split(",")
	for i in range(parts.size()):
		var trimmed = parts[i].strip_edges()
		if trimmed.is_valid_int():
			result.append(trimmed.to_int())
		elif not trimmed.is_empty():
			var msg = "Integer tidak valid dalam array: '%s' pada index %d di %s. Nilai dilewati." % [trimmed, i, context]
			push_warning(msg)
			_log_error(error_log, msg, row_id, line_number, context)
	return result


## Parse scene_properties dengan konversi boolean
## Array harus memiliki tepat 5 elemen (comma-separated, empty slots allowed)
static func parse_scene_props(field: String, error_log: Array = [], context: String = "", row_id: String = "", line_number: int = 0, field_name: String = "scene_properties") -> Array:
	var result = []
	var parts = field.split(",")
	
	# Validasi panjang array berdasarkan jumlah comma-separated parts
	# Harus tepat 5 parts (bisa termasuk empty)
	if parts.size() != 5 and not field.strip_edges().is_empty():
		var msg = "Array scene_properties harus memiliki tepat 5 elemen (comma-separated), ditemukan %d elemen pada %s." % [parts.size(), context]
		push_warning(msg)
		_log_error(error_log, msg, row_id, line_number, field_name, true)
	
	# Parse setiap part
	for i in range(parts.size()):
		var part = parts[i].strip_edges()
		# Tambahkan empty/default untuk empty parts
		if part.is_empty():
			result.append("")
			continue
		if result.is_empty():
			# Elemen pertama harus boolean
			if part.to_lower() != "true" and part.to_lower() != "false":
				var msg = "Boolean tidak valid di scene_props: '%s' pada index %d di %s. Diharapkan true/false." % [part, i, context]
				push_warning(msg)
				_log_error(error_log, msg, row_id, line_number, field_name)
			result.append(part.to_lower() == "true")
		elif result.size() == 3:
			if part.to_lower() == "true":
				result.append(true)
			elif part.to_lower() == "false" or part.to_lower() == "none":
				result.append(false)
			else:
				result.append(part)
		else:
			if part.to_lower() == "true":
				result.append(true)
			elif part.to_lower() == "false":
				result.append(false)
			else:
				result.append(part)
	
	return result


## Parse next_line_properties dengan konversi tipe
## Array harus memiliki tepat 5 elemen (comma-separated, empty slots allowed)
static func parse_next_line(field: String, error_log: Array = [], context: String = "", row_id: String = "", line_number: int = 0, field_name: String = "next_line_properties") -> Array:
	var result = []
	var parts = field.split(",")
	
	# Validasi panjang array berdasarkan jumlah comma-separated parts
	# Harus tepat 5 parts (bisa termasuk empty)
	if parts.size() != 5 and not field.strip_edges().is_empty():
		var msg = "Array next_line_properties harus memiliki tepat 5 elemen (comma-separated), ditemukan %d elemen pada %s." % [parts.size(), context]
		push_warning(msg)
		_log_error(error_log, msg, row_id, line_number, field_name, true)
	
	# Parse setiap part
	for part in parts:
		var trimmed = part.strip_edges()
		# Tambahkan empty string untuk empty parts (placeholder)
		if trimmed.is_empty():
			result.append("")
			continue
		if trimmed.is_valid_int():
			result.append(int(trimmed))
		elif trimmed.to_lower() == "true":
			result.append(true)
		elif trimmed.to_lower() == "false":
			result.append(false)
		else:
			result.append(trimmed)
	

	return result


## Parsing sesuai dengan traits fields
static func parse_traits(field: String, error_log: Array = [], context: String = "", row_id: String = "", line_number: int = 0) -> Dictionary:
	var result = {}
	var parts = field.split(",")
	var keys = ["richness", "boldness", "fanciness"]
	for i in range(min(parts.size(), keys.size())):
		var value = parts[i].strip_edges()
		if value.is_valid_int():
			result[keys[i]] = value.to_int()
		else:
			if not value.is_empty():
				var msg = "Integer tidak valid untuk trait '%s': '%s' di %s. Menggunakan default: 0" % [keys[i], value, context]
				push_warning(msg)
				_log_error(error_log, msg, row_id, line_number, context)
			result[keys[i]] = 0
	return result
