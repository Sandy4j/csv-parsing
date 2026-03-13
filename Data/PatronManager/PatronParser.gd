class_name PatronParser
extends RefCounted

## Script untuk parsing CSV terkait patron dan mengambil row data yang relevan

static func parse_patron_csv(path: String) -> Array:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null: return []
	
	var rows = []
	var is_first_row = true
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() > 0 and not (line.size() == 1 and line[0].strip_edges().is_empty()):
			# Handle format dimana satu baris dibungkus kutip eksternal
			if line.size() == 1 and line[0].contains(","):
				var raw_line = line[0]
				# Jika baris dimulai dan diakhiri dengan kutip, hapus kutip eksternal
				if raw_line.begins_with('"') and raw_line.ends_with('"'):
					raw_line = raw_line.substr(1, raw_line.length() - 2)
				var parsed_fields = _parse_csv_line_proper(raw_line)
				rows.append(parsed_fields)
			else:
				# Format normal - strip edges dari setiap field
				var cleaned_row: Array = []
				for field in line:
					cleaned_row.append(str(field).strip_edges())
				rows.append(cleaned_row)
		is_first_row = false
	file.close()
	return rows

## Mengambil satu baris info patron
static func get_patron_info(rows: Array, character_name: String, char_header: String) -> Dictionary:
	if rows.is_empty(): return {}
	
	var headers: Array = rows[0]
	var name_idx: int = _find_column_index(headers, char_header)
	
	if name_idx == -1: return {}

	for i in range(1, rows.size()):
		var row: Array = rows[i]
		if row.size() > name_idx and str(row[name_idx]).strip_edges() == character_name:
			var info: Dictionary = {}
			for j in range(mini(headers.size(), row.size())):
				info[str(headers[j]).strip_edges()] = str(row[j]).strip_edges()
			return info
	return {}

## Mengambil semua baris story data untuk karakter
static func get_story_data(rows: Array, character_name: String, char_header: String) -> Array:
	var result: Array = []
	if rows.is_empty(): return result
	
	var headers: Array = rows[0]
	var name_idx: int = _find_column_index(headers, char_header)
	
	if name_idx == -1: return result

	for i in range(1, rows.size()):
		var row: Array = rows[i]
		if row.size() > name_idx and str(row[name_idx]).strip_edges() == character_name:
			var entry: Dictionary = {}
			for j in range(mini(headers.size(), row.size())):
				entry[str(headers[j]).strip_edges()] = str(row[j]).strip_edges()
			result.append(entry)
	return result

## Mengambil semua baris order data (berdasarkan prefix nama karakter)
static func get_orders_data(rows: Array, character_name: String, char_header: String) -> Array:
	var result: Array = []
	if rows.is_empty(): return result
	
	var headers: Array = rows[0]
	var name_idx: int = _find_column_index(headers, char_header)
	
	if name_idx == -1: return result

	for i in range(1, rows.size()):
		var row: Array = rows[i]
		if row.size() > name_idx and str(row[name_idx]).strip_edges().begins_with(character_name):
			var entry: Dictionary = {}
			for j in range(mini(headers.size(), row.size())):
				entry[str(headers[j]).strip_edges()] = str(row[j]).strip_edges()
			result.append(entry)
	return result

## Mengambil semua baris idle talk data
static func get_idletalk_data(rows: Array, character_name: String, char_header: String) -> Array:
	return get_story_data(rows, character_name, char_header) # Logic sama dengan story data

static func _parse_csv_line_proper(line: String) -> Array:
	return JsonUtils.parse_csv_line(line)

static func _find_column_index(headers: Array, target: String) -> int:
	for i in range(headers.size()):
		if str(headers[i]).strip_edges().to_lower() == target.to_lower():
			return i
	return -1
