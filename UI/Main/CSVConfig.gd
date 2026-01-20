class_name CSVConfig
extends RefCounted

## Skrip untuk menentukan tipe CSV dan konfigurasi parser dan generator

enum CSVType {
	DIALOG,
	INGREDIENT,
	ITEM,
	UNKNOWN
}

const TYPE_CONFIGS: Dictionary = {
	CSVType.DIALOG: {
		"name": "dialog",
		"group_label": "chapters",
		"root_name": "Default",
		"header_patterns": [["lineid", "text"]],  # Wajib ada lineid dan text
		"required_headers": ["lineid", "text"]    # Header yang wajib ada
	},
	CSVType.INGREDIENT: {
		"name": "ingredient",
		"group_label": "categories",
		"root_name": "",
		"header_patterns": [["ingredientid"], ["ingredient name"], ["item", "type"]],
		"required_headers": []
	},
	CSVType.ITEM: {
		"name": "item",
		"group_label": "types",
		"root_name": "",
		"header_patterns": [["ingredientid", "ingredient name", "type"]],
		"required_headers": ["ingredientid", "ingredient name"]
	},
	CSVType.UNKNOWN: {
		"name": "unknown",
		"group_label": "items",
		"root_name": "",
		"header_patterns": [],
		"required_headers": []
	}
}


## Deteksi tipe CSV dari path file
static func detect_type(csv_path: String) -> CSVType:
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		push_warning("CSVConfig: Gagal membuka file CSV: " + csv_path)
		return CSVType.UNKNOWN
	
	var first_line = file.get_line().to_lower()
	file.close()
	
	return _detect_from_header(first_line)


## Get detailed error message saat CSV type UNKNOWN
static func get_detection_error(csv_path: String) -> String:
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return "Gagal membuka file CSV: " + csv_path
	
	var first_line = file.get_line()
	file.close()
	
	var header = first_line.to_lower()
	var error_msg = "Format CSV tidak dikenali.\n\n"
	error_msg += "Header yang ditemukan:\n%s\n\n" % first_line
	error_msg += "Format yang didukung:\n\n"
	
	# Dialog format
	error_msg += "1. DIALOG CSV:\n"
	error_msg += "   Wajib ada header: 'lineid' dan 'text'\n"
	error_msg += "   Contoh: lineid,Name,text,character,...\n\n"
	
	# Ingredient format  
	error_msg += "2. INGREDIENT CSV:\n"
	error_msg += "   Wajib ada salah satu:\n"
	error_msg += "   - Header 'ingredientid'\n"
	error_msg += "   - Header 'ingredient name'\n"
	error_msg += "   - Header 'item' dan 'type'\n\n"
	
	# Item format
	error_msg += "3. ITEM CSV:\n"
	error_msg += "   Wajib ada header: 'ingredientid', 'ingredient name', dan 'type'\n"
	error_msg += "   Contoh: IngredientId,Ingredient Name,Type,Description,...\n\n"
	
	# Analisis header yang hilang
	error_msg += "Analisis header Anda:\n"
	
	# Check Dialog
	var has_lineid = header.find("lineid") >= 0
	var has_text = header.find("text") >= 0
	if not has_lineid and not has_text:
		error_msg += "✗ Bukan Dialog (tidak ada 'lineid' dan 'text')\n"
	elif not has_lineid:
		error_msg += "✗ Bukan Dialog (tidak ada 'lineid')\n"
	elif not has_text:
		error_msg += "✗ Bukan Dialog (tidak ada 'text')\n"
	
	# Check Item/Ingredient
	var has_ingredientid = header.find("ingredientid") >= 0
	var has_ingredient_name = header.find("ingredient name") >= 0
	var has_type = header.find("type") >= 0
	
	if not has_ingredientid and not has_ingredient_name:
		error_msg += "✗ Bukan Item/Ingredient (tidak ada 'ingredientid' atau 'ingredient name')\n"
	elif has_ingredientid and has_ingredient_name and not has_type:
		error_msg += "✗ Hampir cocok Item, tapi tidak ada kolom 'type'\n"
	
	return error_msg


## Deteksi tipe CSV dari header string dengan strict validation
static func _detect_from_header(header: String) -> CSVType:
	header = header.to_lower()
	
	# Check ITEM type (paling spesifik - harus ada IngredientId dan Ingredient Name)
	for pattern in TYPE_CONFIGS[CSVType.ITEM]["header_patterns"]:
		if _matches_pattern(header, pattern):
			return CSVType.ITEM
	
	# Check INGREDIENT type
	for pattern in TYPE_CONFIGS[CSVType.INGREDIENT]["header_patterns"]:
		if _matches_pattern(header, pattern):
			return CSVType.INGREDIENT
	
	# Check DIALOG type dengan strict validation (wajib ada lineid dan text)
	var dialog_required = TYPE_CONFIGS[CSVType.DIALOG]["required_headers"]
	if _matches_pattern(header, dialog_required):
		return CSVType.DIALOG
	
	# Tidak cocok dengan format manapun
	push_warning("CSVConfig: Format CSV tidak dikenali. Header: " + header)
	return CSVType.UNKNOWN

## Cek apakah header string memenuhi pattern
static func _matches_pattern(header: String, pattern: Array) -> bool:
	for keyword in pattern:
		if header.find(keyword) < 0:
			return false
	return true


## Configure parser berdasarkan tipe CSV
static func configure_parser(parser: Node, csv_type: CSVType) -> void:
	match csv_type:
		CSVType.INGREDIENT:
			parser.configure_for_ingredient()
		CSVType.ITEM:
			parser.configure_for_item()
		CSVType.DIALOG:
			parser.configure_for_dialog()
		CSVType.UNKNOWN:
			push_warning("CSVConfig: Tidak dapat mengkonfigurasi parser untuk tipe UNKNOWN")


## Configure generator berdasarkan tipe CSV
static func configure_generator(generator: Node, csv_type: CSVType) -> void:
	match csv_type:
		CSVType.INGREDIENT:
			generator.configure_for_ingredient()
		CSVType.ITEM:
			generator.configure_for_item()
		CSVType.DIALOG:
			generator.configure_for_dialog()
		CSVType.UNKNOWN:
			push_warning("CSVConfig: Tidak dapat mengkonfigurasi generator untuk tipe UNKNOWN")


## Konfigurasi parser dan generator secara bersamaan
static func configure_all(parser: Node, generator: Node, csv_type: CSVType) -> void:
	configure_parser(parser, csv_type)
	configure_generator(generator, csv_type)

## Get string name dari tipe
static func get_type_name(csv_type: CSVType) -> String:
	return TYPE_CONFIGS.get(csv_type, TYPE_CONFIGS[CSVType.DIALOG])["name"]
## Get label untuk groups berdasarkan tipe
static func get_group_label(csv_type: CSVType) -> String:
	return TYPE_CONFIGS.get(csv_type, TYPE_CONFIGS[CSVType.DIALOG])["group_label"]
## Get default root name berdasarkan tipe
static func get_default_root_name(csv_type: CSVType) -> String:
	return TYPE_CONFIGS.get(csv_type, TYPE_CONFIGS[CSVType.DIALOG])["root_name"]
