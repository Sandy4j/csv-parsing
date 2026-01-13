extends Node

var data_rows = {}  # Dictionary untuk menyimpan data
var available_chapters = []  # Array untuk menyimpan daftar chapter ID yang tersedia

func _ready():
	pass

## Parse CSV dari path yang diberikan
func parse_csv_from_path(file_path: String) -> bool:
	data_rows.clear()
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open CSV file: " + file_path)
		return false
	
	var csv_text = file.get_as_text()
	file.close()
	
	var lines = csv_text.split("\n")
	
	# Mulai dari baris ke-5 (index 5) karena data awalnya berada di baris ke-6
	for i in range(5, lines.size()):
		var line = lines[i].strip_edges()
		if line.is_empty():
			continue
		
		# Memecah baris CSV menjadi array kolom
		var row = parse_csv_line(line)
		
		# Validasi minimal kolom (18 kolom) dan pastikan ID baris tidak kosong
		if row.size() < 18 or row[0].strip_edges().is_empty():
			continue
		
		var lineid = row[0].strip_edges()
		var chapter = row[13].strip_edges()
		
		# Memasukkan setiap kolom ke dalam key yang sesuai
		var row_data = {
			"lineid": lineid,
			"name": row[1].strip_edges(),
			"character": parse_array_field(row[3]),
			"text": row[2].strip_edges(),
			"left": parse_array_field(row[4]),
			"middle_left": parse_array_field(row[5]),
			"middle": parse_array_field(row[6]),
			"middle_right": parse_array_field(row[7]),
			"right": parse_array_field(row[8]),
			"scene_properties": parse_scene_properties(row[9]),
			"dialogue_choice": row[10].strip_edges(),
			"next_line_properties": parse_next_line_properties(row[11]),
			"give_item": parse_array_field(row[12]),
			"chapterid": chapter,
			"goto": row[14].strip_edges(),
			"special_effects": parse_array_field(row[15]),
			"sound_effect": row[16].strip_edges(),
			"music_effect": row[17].strip_edges() if row.size() > 17 else ""
		}

		# Kelompokkan data berdasarkan Chapter ID
		if not data_rows.has(chapter):
			data_rows[chapter] = {}
		data_rows[chapter][lineid] = row_data
	
	# Perbarui daftar chapter yang tersedia
	update_available_chapters()
	
	return true

## Fungsi untuk memperbarui daftar chapter yang tersedia
func update_available_chapters():
	available_chapters.clear()
	for chapter in data_rows.keys():
		if not available_chapters.has(chapter):
			available_chapters.append(chapter)

## Fungsi memecah teks string dengan koma menjadi Array
func parse_array_field(field: String) -> Array:
	var result = []
	var parts = field.split(",")
	for part in parts:
		var trimmed = part.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)
	return result
	
## Fungsi khusus untuk scene_properties (mengonversi teks "true"/"false" jadi Boolean)
func parse_scene_properties(field: String) -> Array:
	var result = []
	var parts = field.split(",")
	for i in range(parts.size()):
		var part = parts[i].strip_edges()
		if part.is_empty():
			continue
			# Lewati bagian kosong
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

## Fungsi khusus next_line_properties (mengonversi ke Angka atau Boolean)
func parse_next_line_properties(field: String) -> Array:
	var result = []
	var parts = field.split(",")
	for part in parts:
		var trimmed = part.strip_edges()
		if trimmed.is_empty():
			result.append("")
			continue
		if trimmed.is_valid_int(): # Jika angka, simpan sebagai Integer
			result.append(int(trimmed))
		elif trimmed.to_lower() == "true":
			result.append(true)
		elif trimmed.to_lower() == "false":
			result.append(false)
		else:
			result.append(trimmed)
	return result

## Logika inti pembaca CSV: Menangani koma di dalam tanda petik agar teks dialog tidak pecah
func parse_csv_line(line: String) -> Array:
	var result = []
	var current_field = ""
	var in_quotes = false
	var i = 0
	
	while i < line.length():
		var c = line[i]
		
		if c == '"':
			# Menangani double quotes (escaped quotes)
			if in_quotes and i + 1 < line.length() and line[i + 1] == '"':
				current_field += '"'
				i += 1
			else:
				# Toggel status in_quotes
				in_quotes = !in_quotes
		elif c == ',' and !in_quotes:
			# Koma hanya dianggap pemisah jika berada di luar tanda petik
			result.append(current_field)
			current_field = ""
		else:
			current_field += c
		
		i += 1
	
	# Tambahkan field terakhir
	result.append(current_field)
	return result

## Fungsi untuk menampilkan contoh penggunaan parser
func print_example_usage():
	print("=== CSV Parsing Example Output ===")
	var total_rows = 0
	for chapter in data_rows:
		total_rows += data_rows[chapter].size()
	print("Total chapters: ", data_rows.size())
	print("Total rows parsed: ", total_rows)
	print()

	var count = 0
	for chapter in data_rows:
		if count >= 1:
			break
		print("--- Chapter: ", chapter, " ---")
		var line_count = 0
		for lineid in data_rows[chapter]:
			if line_count >= 2:
				break
			var row_data = data_rows[chapter][lineid]
			print("  Line ID: ", row_data["lineid"])
			print("  Name: ", row_data["name"])
			print("  Text: ", row_data["text"])
			print("  Character: ", row_data["character"])
			print("  Scene Properties: ", row_data["scene_properties"])
			print("  Next Line Properties: ", row_data["next_line_properties"])
			print()
			line_count += 1
		count += 1
	

## Fungsi untuk mendapatkan daftar chapter ID yang tersedia
func get_available_chapters() -> Array:
	return available_chapters

## Fungsi untuk mendapatkan data berdasarkan chapter yang dipilih
func get_filtered_data(selected_chapters: Array) -> Dictionary:
	if selected_chapters.is_empty():
		return data_rows
	
	var filtered = {}
	for chapter in selected_chapters:
		if data_rows.has(chapter):
			filtered[chapter] = data_rows[chapter]
	return filtered
