extends Node
class_name CSVParser

## Skrip untuk parsing CSV data

# Configuration
var schema: Dictionary = {}
var group_by_column: int = -1
var start_row: int = 0
var id_column: int = 0
var skip_empty_groups: bool = true
var default_group_name: String = "Uncategorized"

# Metadata configuration
var metadata_column: int = -1
var metadata_value_column: int = -1
var supported_metadata_types: Array = []

# Penyimpanan data
var _data_rows: Dictionary = {}
var _available_groups: Array = []
var _group_metadata: Dictionary = {}


## SET Configuration
func set_schema(new_schema: Dictionary) -> CSVParser:
	schema = new_schema
	return self
func set_group_column(column: int) -> CSVParser:
	group_by_column = column
	return self
func set_start_row(row: int) -> CSVParser:
	start_row = row
	return self
func set_id_column(column: int) -> CSVParser:
	id_column = column
	return self
func set_skip_empty_groups(skip: bool) -> CSVParser:
	skip_empty_groups = skip
	return self
func set_default_group_name(name: String) -> CSVParser:
	default_group_name = name
	return self
func set_metadata_column(column: int) -> CSVParser:
	metadata_column = column
	return self
func set_metadata_value_column(column: int) -> CSVParser:
	metadata_value_column = column
	return self
func set_supported_metadata_types(types: Array) -> CSVParser:
	supported_metadata_types = types
	return self
func add_metadata_type(meta_type: String) -> CSVParser:
	if not supported_metadata_types.has(meta_type):
		supported_metadata_types.append(meta_type)
	return self



## Preset Konfigurasi untuk CSV file diambil dari DataSchemas
func configure_for_dialog() -> CSVParser:
	var config = DataSchemas.get_dialog_config()
	schema = config.schema
	group_by_column = config.group_column
	start_row = config.start_row
	id_column = config.id_column
	metadata_column = config.metadata_column
	metadata_value_column = config.metadata_value_column
	supported_metadata_types = config.supported_metadata_types
	return self
func configure_for_items() -> CSVParser:
	var config = DataSchemas.get_item_config()
	schema = config.schema
	group_by_column = config.group_column
	start_row = config.start_row
	id_column = config.id_column
	metadata_column = config.metadata_column
	metadata_value_column = config.metadata_value_column
	supported_metadata_types = config.supported_metadata_types
	return self
func configure_for_ingredient() -> CSVParser:
	var config = DataSchemas.get_ingredient_config()
	schema = config.schema
	group_by_column = config.group_column
	start_row = config.start_row
	id_column = config.id_column
	metadata_column = config.metadata_column
	metadata_value_column = config.metadata_value_column
	supported_metadata_types = config.supported_metadata_types
	return self



## Fungsi untuk parsing CSV file
func parse_csv_from_path(file_path: String) -> bool:
	_clear_data()
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open CSV file: " + file_path)
		return false
	
	var csv_text = file.get_as_text()
	file.close()
	
	return parse_csv_text(csv_text)

## Fungsi untuk parsing CSV text
func parse_csv_text(csv_text: String) -> bool:
	var lines = csv_text.split("\n")
	
	for i in range(start_row, lines.size()):
		var line = lines[i].strip_edges()
		if line.is_empty():
			continue
		
		var row = _parse_csv_line(line)
		
		# Cek apakah baris ini metadata
		if _is_metadata_row(row):
			_store_metadata(row)
			continue
		
		var row_data = _process_row(row)
		if row_data.is_empty():
			continue
		
		# Memasukkan data ke penyimpanan
		_store_row_data(row, row_data)
	
	_update_available_groups()
	return true

## Mengosongkan data penyimpanan
func _clear_data() -> void:
	_data_rows.clear()
	_available_groups.clear()
	_group_metadata.clear()

## Mengubah satu baris CSV menjadi array
func _parse_csv_line(line: String) -> Array:
	var result = []
	var current_field = ""
	var in_quotes = false
	var i = 0

	while i < line.length():
		var c = line[i]
		if c == '"':
			if in_quotes and i + 1 < line.length() and line[i + 1] == '"':
				current_field += '"'
				i += 1
			else:
				in_quotes = !in_quotes
		elif c == ',' and !in_quotes:
			result.append(current_field)
			current_field = ""
		else:
			current_field += c
		i += 1

	result.append(current_field)
	return result

## Mengubah satu baris CSV menjadi dictionary
func _process_row(row: Array) -> Dictionary:
	if schema.is_empty():
		return {}
	
	var result = {}
	
	for field_name in schema:
		var field_config = schema[field_name]
		var field_type = field_config.get("type", "string")
		
		# Handle nested fields
		if field_type == "nested":
			var nested_fields = field_config.get("fields", {})
			var nested_result = {}
			for nested_key in nested_fields:
				var nested_config = nested_fields[nested_key]
				var nested_column = nested_config.get("column", -1)
				var nested_type = nested_config.get("type", "string")
				var nested_default = nested_config.get("default", "")
				
				if nested_column < 0 or nested_column >= row.size():
					nested_result[nested_key] = nested_default
					continue
				
				var nested_raw = row[nested_column].strip_edges()
				nested_result[nested_key] = FieldTransformers.transform(nested_raw, nested_type, nested_default)
			result[field_name] = nested_result
			continue
		
		# Handle normal fields
		var column_index = field_config.get("column", -1)
		var default_value = field_config.get("default", "")
		
		if column_index < 0 or column_index >= row.size():
			result[field_name] = default_value
			continue
		
		var raw_value = row[column_index].strip_edges()
		result[field_name] = FieldTransformers.transform(raw_value, field_type, default_value)
	
	# Skip rows with empty ID
	var id_field = _get_id_field_name()
	if id_field != "" and result.has(id_field):
		if str(result[id_field]).strip_edges().is_empty():
			return {}
	
	return result

## Menyimpan data baris ke penyimpanan data
func _store_row_data(row: Array, row_data: Dictionary) -> void:
	var row_id = _get_row_id(row, row_data)
	
	if group_by_column >= 0 and row.size() > group_by_column:
		var group_key = row[group_by_column].strip_edges()
		
		if group_key.is_empty():
			if skip_empty_groups:
				return
			else:
				group_key = default_group_name
		
		if not _data_rows.has(group_key):
			_data_rows[group_key] = {}
		_data_rows[group_key][row_id] = row_data
	else:
		_data_rows[row_id] = row_data

## GET ID untuk baris data
func _get_row_id(row: Array, row_data: Dictionary) -> String:
	var id_field = _get_id_field_name()
	if id_field != "" and row_data.has(id_field):
		return str(row_data[id_field])
	
	if id_column >= 0 and id_column < row.size():
		return row[id_column].strip_edges()
	
	return str(randi())

## GET ID field name
func _get_id_field_name() -> String:
	for field_name in schema:
		if schema[field_name].get("is_id", false):
			return field_name
	return ""

## Update list group yang tersedia
func _update_available_groups() -> void:
	_available_groups.clear()
	if group_by_column >= 0:
		for group in _data_rows.keys():
			if not _available_groups.has(group):
				_available_groups.append(group)



## Cek apakah baris ini adalah metadata
func _is_metadata_row(row: Array) -> bool:
	if metadata_column < 0 or metadata_column >= row.size():
		return false
	var meta_type = row[metadata_column].strip_edges()
	return supported_metadata_types.has(meta_type)

## Simpan metadata ke penyimpanan metadata
func _store_metadata(row: Array) -> void:
	if group_by_column < 0 or group_by_column >= row.size():
		return
	
	var group_key = row[group_by_column].strip_edges()
	if group_key.is_empty():
		return
	
	var meta_type = row[metadata_column].strip_edges()
	var meta_value = ""
	if metadata_value_column >= 0 and metadata_value_column < row.size():
		meta_value = row[metadata_value_column].strip_edges()
	
	if not _group_metadata.has(group_key):
		_group_metadata[group_key] = {}
	
	_group_metadata[group_key][meta_type] = meta_value



## GET Functions
func get_data() -> Dictionary:
	return _data_rows
func get_data_with_metadata() -> Dictionary:
	return _merge_metadata_into_data(_data_rows)
func get_group_metadata() -> Dictionary:
	return _group_metadata
func get_metadata_for_group(group_key: String) -> Dictionary:
	return _group_metadata.get(group_key, {})
func get_available_groups() -> Array:
	return _available_groups
	
## GET data yang telah difilter	
func get_filtered_data(selected_groups: Array) -> Dictionary:
	if selected_groups.is_empty():
		return _merge_metadata_into_data(_data_rows)
	
	var filtered = {}
	for group in selected_groups:
		if _data_rows.has(group):
			filtered[group] = _data_rows[group]
	return _merge_metadata_into_data(filtered)
	
## GET data dalam bentuk array	
func get_data_as_array() -> Array:
	var result = []
	if group_by_column >= 0:
		for group in _data_rows:
			for id in _data_rows[group]:
				result.append(_data_rows[group][id])
	else:
		for id in _data_rows:
			result.append(_data_rows[id])
	return result

## Merge metadata ke data
func _merge_metadata_into_data(data: Dictionary) -> Dictionary:
	var result = {}
	for group_key in data:
		result[group_key] = {}
		# Add metadata first
		if _group_metadata.has(group_key):
			for meta_key in _group_metadata[group_key]:
				result[group_key][meta_key] = _group_metadata[group_key][meta_key]
		# Then add data items
		for item_key in data[group_key]:
			result[group_key][item_key] = data[group_key][item_key]
	return result
