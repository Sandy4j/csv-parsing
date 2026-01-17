class_name FieldTransformers
extends RefCounted

## Skrip untuk mengubah value field berdasarkan type

## Transform value berdasarkan type
static func transform(raw_value: String, field_type: String, default_value = null) -> Variant:
	if raw_value.is_empty() and default_value != null:
		return default_value
	
	match field_type:
		"string":
			return raw_value
		"int":
			return raw_value.to_int() if raw_value.is_valid_int() else (default_value if default_value != null else 0)
		"float":
			return raw_value.to_float() if raw_value.is_valid_float() else (default_value if default_value != null else 0.0)
		"bool":
			return raw_value.to_lower() == "true"
		"array":
			return parse_array(raw_value)
		"array_int":
			return parse_array_int(raw_value)
		"scene_props":
			return parse_scene_props(raw_value)
		"next_line":
			return parse_next_line(raw_value)
		"traits":
			return parse_traits(raw_value)
		_:
			return raw_value


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
static func parse_array_int(field: String) -> Array:
	var result = []
	var parts = field.split(",")
	for part in parts:
		var trimmed = part.strip_edges()
		if trimmed.is_valid_int():
			result.append(trimmed.to_int())
	return result


## Parse scene_properties dengan konversi boolean
static func parse_scene_props(field: String) -> Array:
	var result = []
	var parts = field.split(",")
	for i in range(parts.size()):
		var part = parts[i].strip_edges()
		if part.is_empty():
			continue
		if result.is_empty():
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
static func parse_next_line(field: String) -> Array:
	var result = []
	var parts = field.split(",")
	for part in parts:
		var trimmed = part.strip_edges()
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
static func parse_traits(field: String) -> Dictionary:
	var result = {}
	var parts = field.split(",")
	var keys = ["richness", "boldness", "fanciness"]
	for i in range(min(parts.size(), keys.size())):
		var value = parts[i].strip_edges()
		result[keys[i]] = value.to_int() if value.is_valid_int() else 0
	return result

