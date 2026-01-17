class_name CSVConfig
extends RefCounted

## Skrip untuk menentukan tipe CSV dan konfigurasi parser dan generator

enum CSVType {
	DIALOG,
	ITEMS,
	INGREDIENT
}

const TYPE_CONFIGS: Dictionary = {
	CSVType.DIALOG: {
		"name": "dialog",
		"group_label": "chapters",
		"root_name": "Default",
		"header_patterns": []  # Default fallback
	},
	CSVType.ITEMS: {
		"name": "items",
		"group_label": "categories",
		"root_name": "Items",
		"header_patterns": [["item", "type"]]  # Kedua keyword ini harus ada
	},
	CSVType.INGREDIENT: {
		"name": "ingredient",
		"group_label": "categories",
		"root_name": "",
		"header_patterns": [["ingredientid"], ["ingredient name"]]  # Any of these
	}
}


## Deteksi tipe CSV dari path file
static func detect_type(csv_path: String) -> CSVType:
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return CSVType.DIALOG
	
	var first_line = file.get_line().to_lower()
	file.close()
	
	return _detect_from_header(first_line)


## Deteksi tipe CSV dari header string
static func _detect_from_header(header: String) -> CSVType:
	header = header.to_lower()
	
	# Check INGREDIENT type terlebih dahulu karena header ini lebih mudah dipahami
	for pattern in TYPE_CONFIGS[CSVType.INGREDIENT]["header_patterns"]:
		if _matches_pattern(header, pattern):
			return CSVType.INGREDIENT
	
	# Check ITEMS type
	for pattern in TYPE_CONFIGS[CSVType.ITEMS]["header_patterns"]:
		if _matches_pattern(header, pattern):
			return CSVType.ITEMS
			
	# Default fallback
	return CSVType.DIALOG

## Cek apakah header string memenuhi pattern
static func _matches_pattern(header: String, pattern: Array) -> bool:
	for keyword in pattern:
		if header.find(keyword) < 0:
			return false
	return true



## Configure parser berdasarkan tipe CSV
static func configure_parser(parser: Node, csv_type: CSVType) -> void:
	match csv_type:
		CSVType.ITEMS:
			parser.configure_for_items()
		CSVType.INGREDIENT:
			parser.configure_for_ingredient()
		_:
			parser.configure_for_dialog()


## Configure generator berdasarkan tipe CSV
static func configure_generator(generator: Node, csv_type: CSVType) -> void:
	match csv_type:
		CSVType.ITEMS:
			generator.configure_for_items()
		CSVType.INGREDIENT:
			generator.configure_for_ingredient()
		_:
			generator.configure_for_dialog()


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
