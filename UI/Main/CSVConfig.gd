class_name CSVConfig
extends RefCounted

## Skrip untuk menentukan tipe CSV dan konfigurasi parser dan generator

enum CSVType {
	DIALOG,
	INGREDIENT,
	ITEM,
	RECIPE,
	BEVERAGE,
	DECORATION,
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
	CSVType.RECIPE: {
		"name": "recipe",
		"group_label": "foods",
		"root_name": "Foods",
		"header_patterns": [["foodid", "name", "base ingredients"]],
		"required_headers": ["foodid", "name"]
	},
	CSVType.BEVERAGE: {
		"name": "beverage",
		"group_label": "items",
		"root_name": "Beverage",
		"header_patterns": [["name", "type", "description", "buy price", "sell price", "filename"]],
		"required_headers": ["name", "type", "filename"]
	},
	CSVType.DECORATION: {
		"name": "decoration",
		"group_label": "items",
		"root_name": "Decorations",
		"header_patterns": [["no.", "type", "filename", "name", "price", "description"]],
		"required_headers": ["no.", "name", "filename"]
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
	
	var headers: Array = []
	while not file.eof_reached() and headers.size() < 3:
		headers.append(file.get_line().to_lower())
	file.close()
	
	for header_line in headers:
		var detected = _detect_from_header(header_line, true)
		if detected != CSVType.UNKNOWN:
			return detected
	
	# Jika tetap tidak terdeteksi, warn sekali dengan header pertama
	if headers.size() > 0:
		push_warning("CSVConfig: Format CSV tidak dikenali. Header: " + headers[0])
	return CSVType.UNKNOWN


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
	return error_msg

## Deteksi tipe CSV dari header string dengan strict validation
static func _detect_from_header(header: String, suppress_warning: bool = false) -> CSVType:
	header = header.to_lower()
	
	# Check RECIPE type (harus ada foodid dan base ingredients)
	for pattern in TYPE_CONFIGS[CSVType.RECIPE]["header_patterns"]:
		if _matches_pattern(header, pattern):
			return CSVType.RECIPE
	
	# Check BEVERAGE type
	for pattern in TYPE_CONFIGS[CSVType.BEVERAGE]["header_patterns"]:
		if _matches_pattern(header, pattern):
			return CSVType.BEVERAGE
	
	# Check DECORATION type
	for pattern in TYPE_CONFIGS[CSVType.DECORATION]["header_patterns"]:
		if _matches_pattern(header, pattern):
			return CSVType.DECORATION
	
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
	if not suppress_warning:
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
		CSVType.RECIPE:
			parser.configure_for_recipe()
		CSVType.BEVERAGE:
			parser.configure_for_beverage()
		CSVType.DECORATION:
			parser.configure_for_decoration()
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
		CSVType.RECIPE:
			generator.configure_for_recipe()
		CSVType.BEVERAGE:
			generator.configure_for_beverage()
		CSVType.DECORATION:
			generator.configure_for_decoration()
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
