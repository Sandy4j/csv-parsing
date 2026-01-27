class_name PatronValidator
extends RefCounted

## Script untuk memvalidasi keberadaan file dan data patron

## Validasi file berdasarkan header
static func validate_files(base_dir: String, config: Dictionary) -> Dictionary:
	var errors: Array = []
	var detected_files: Dictionary = {}
	var duplicate_files: Dictionary = {}
	
	var csv_files: Array = _get_csv_files_in_dir(base_dir)
	if csv_files.is_empty():
		errors.append("Tidak ada file CSV ditemukan di folder: " + base_dir)
		return {"errors": errors, "files": {}}
	
	# Deteksi tipe file berdasarkan header
	for csv_file in csv_files:
		var file_path: String = base_dir.path_join(csv_file)
		var file_type: String = _detect_file_type(file_path, config)
		if not file_type.is_empty():
			# Cek duplikasi
			if detected_files.has(file_type):
				if not duplicate_files.has(file_type):
					duplicate_files[file_type] = [detected_files[file_type]]
				duplicate_files[file_type].append(file_path)
			else:
				detected_files[file_type] = file_path
	
	# Tambahkan warning untuk duplikasi
	for file_type in duplicate_files:
		var file_list = duplicate_files[file_type]
		var type_config_name = ""
		for key in config:
			if key == file_type:
				type_config_name = key
				break
		
		errors.append("WARNING: Ditemukan %d file dengan tipe %s. Yang digunakan: %s. Yang Diabaikan: %s" % [
			file_list.size(),
			type_config_name,
			detected_files[file_type].get_file(),
			", ".join(file_list.slice(1).map(func(p): return p.get_file()))
		])
	
	# Cek apakah semua file yang dibutuhkan sudah ditemukan
	for key in config:
		if not detected_files.has(key):
			var required_headers: Array = config[key].get("required_headers", [])
			if key == "STORY" or key == "IDLETALK":
				continue
			errors.append("File dengan header [%s] tidak ditemukan di folder" % ", ".join(required_headers))
	
	return {"errors": errors, "files": detected_files}

## Deteksi tipe file berdasarkan header
static func _detect_file_type(file_path: String, config: Dictionary) -> String:
	var rows: Array = PatronParser.parse_patron_csv(file_path)
	if rows.is_empty():
		return ""
	
	var headers: Array = rows[0]
	var header_line: String = ",".join(headers).to_lower()
	
	for key in config:
		var required_headers: Array = config[key].get("required_headers", [])
		if _matches_headers(header_line, required_headers):
			return key
	
	return ""

## Cek apakah header line mengandung semua required headers
static func _matches_headers(header_line: String, required_headers: Array) -> bool:
	for header in required_headers:
		if header_line.find(header.to_lower()) < 0:
			return false
	return true

## Dapatkan semua file CSV di folder
static func _get_csv_files_in_dir(dir_path: String) -> Array:
	var files: Array = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return files
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".csv"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return files

## Validasi karakter ada di semua file yang sudah terdeteksi
static func validate_character_in_files(base_dir: String, character_name: String, config: Dictionary, detected_files: Dictionary) -> Array:
	var errors: Array = []
	var missing_files: Array = []
	var found_in_patrons: bool = false
	
	# Cek di file PATRONS dulu
	if detected_files.has("PATRONS"):
		var patrons_path: String = detected_files["PATRONS"]
		var patrons_rows: Array = PatronParser.parse_patron_csv(patrons_path)
		if patrons_rows.size() > 1:
			var headers: Array = patrons_rows[0]
			var name_idx: int = _find_column_index(headers, config["PATRONS"]["char_header"])
			if name_idx != -1:
				for i in range(1, patrons_rows.size()):
					var row: Array = patrons_rows[i]
					if row.size() > name_idx and str(row[name_idx]).strip_edges() == character_name:
						found_in_patrons = true
						break
	
	if not found_in_patrons:
		errors.append("ERROR: Karakter '%s' tidak ditemukan di file Patrons" % character_name)
		return errors
	
	# Cek file lainnya
	var checks = [
		{"key": "STORY", "use_begins_with": false},
		{"key": "ORDERS", "use_begins_with": true},
		{"key": "IDLETALK", "use_begins_with": false}
	]
	
	var is_npc = character_name.begins_with("NPC")
	
	for check in checks:
		if detected_files.has(check.key):
			var path: String = detected_files[check.key]
			var file_config = config[check.key]
			if not _character_exists_in_file(path, file_config["char_header"], character_name, check.use_begins_with):
				if is_npc and (check.key == "STORY" or check.key == "IDLETALK"):
					continue
				missing_files.append(check.key)
		else:
			if not is_npc and (check.key == "STORY" or check.key == "IDLETALK"):
				missing_files.append(check.key + " (File tidak ditemukan)")
	
	if missing_files.size() > 0:
		var files_list: String = ", ".join(missing_files)
		errors.append("ERROR: Karakter '%s' memiliki data tidak lengkap di file: %s" % [character_name, files_list])
	
	return errors

static func _character_exists_in_file(path: String, char_header: String, character_name: String, use_begins_with: bool) -> bool:
	var rows: Array = PatronParser.parse_patron_csv(path)
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

static func _find_column_index(headers: Array, target: String) -> int:
	for i in range(headers.size()):
		if str(headers[i]).strip_edges().to_lower() == target.to_lower():
			return i
	return -1
