extends Node

# Definisikan urutan key untuk menyimpan data ke JSON
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

func _ready() -> void:
	pass

## Generate JSON dari data yang diberikan ke output path yang ditentukan
func generate_json_to_path(data: Dictionary, output_path: String, root_name: String = "MainStory") -> String:
	if data.is_empty():
		push_error("Data is empty")
		return ""
	
	# Buat string JSON dengan urutan key yang ditentukan
	var json_string = stringify_order(data, root_name)
	
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to create JSON file: " + output_path)
		return ""
		
	# Menyimpan teks JSON ke file
	file.store_string(json_string)
	file.close()
	print("JSON file generated successfully at " + output_path)
	
	return json_string

## Fungsi untuk menghasilkan string JSON dengan urutan key yang ditentukan
func stringify_order(data: Dictionary, root_name: String = "DefaultRoot") -> String:
	var lines = []
	lines.append("{")
	lines.append("\t\"%s\": {" % root_name)
	
	# Menulis key-value untuk setiap chapter
	var chapter_keys = data.keys()
	for c_idx in range(chapter_keys.size()):
		var chapter = chapter_keys[c_idx]
		lines.append("\t\t\"%s\": {" % chapter)
		
		# Menulis key-value untuk setiap line
		var line_keys = data[chapter].keys()
		for l_idx in range(line_keys.size()):
			var lineid = line_keys[l_idx]
			var row = data[chapter][lineid]
			lines.append("\t\t\t\"%s\": {" % lineid)
			
			# Menulis key-value sesuai urutan di KEY_ORDER
			for k_idx in range(KEY_ORDER.size()):
				var key = KEY_ORDER[k_idx]
				if row.has(key):
					var value_str = value_to_json(row[key], 4)
					var comma = "," if k_idx < KEY_ORDER.size() - 1 else ""
					lines.append("\t\t\t\t\"%s\": %s%s" % [key, value_str, comma])
			
			# Tutup tag line
			var line_comma = "," if l_idx < line_keys.size() - 1 else ""
			lines.append("\t\t\t}%s" % line_comma)
		
		# Tutup tag chapter
		var chapter_comma = "," if c_idx < chapter_keys.size() - 1 else ""
		lines.append("\t\t}%s" % chapter_comma)
	
	# Tutup tag MainStory
	lines.append("\t}")
	lines.append("}")
	
	# Join semua baris ke satu string
	return "\n".join(lines)

## Konversi tipe data (string,bool,int) ke format JSON
func value_to_json(value, indent_level: int = 0) -> String:
	# Jika teks, tambahkan tanda petik dan bersihkan karakter khusus
	if value is String:
		return "\"%s\"" % escape_json_string(value)
	# Jika boolean, konversi ke string "true" atau "false"
	elif value is bool:
		return "true" if value else "false"
	# Jika angka, konversi langsung ke string
	elif value is int or value is float:
		return str(value)
	# Jika array, proses setiap item di dalamnya
	elif value is Array:
		if value.is_empty():
			return "[]"
		var items = []
		for item in value:
			items.append(value_to_json(item, indent_level))
		# Untuk array yang singkat, gunakan format sederhana
		var joined = ", ".join(items)
		if joined.length() < 60:
			return "[%s]" % joined
		# Untuk array yang panjang, gunakan format terindentasi
		var indent = "\t".repeat(indent_level + 1)
		var close_indent = "\t".repeat(indent_level)
		var formatted_items = []
		for item in value:
			formatted_items.append("%s%s" % [indent, value_to_json(item, indent_level + 1)])
		return "[\n%s\n%s]" % [",\n".join(formatted_items), close_indent]
	elif value is Dictionary:
		return JSON.stringify(value)
	else:
		return "\"%s\"" % str(value)

## Fungsi untuk membersihkan spesial karakter dalam string JSON
func escape_json_string(s: String) -> String:
	s = s.replace("\\", "\\\\")
	s = s.replace("\"", "\\\"")
	s = s.replace("\n", "\\n")
	s = s.replace("\r", "\\r")
	s = s.replace("\t", "\\t")
	return s
