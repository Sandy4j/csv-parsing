class_name DataSchemas
extends RefCounted

## Preset skema untuk parsing CSV data

## Schema untuk file Dialog CSV
static func get_dialog_schema() -> Dictionary:
	return {
		"lineid": {"column": 0, "type": "string", "is_id": true},
		"name": {"column": 1, "type": "string", "default": ""},
		"text": {"column": 2, "type": "string", "default": ""},
		"character": {"column": 3, "type": "array", "default": []},
		"left": {"column": 4, "type": "array", "default": []},
		"middle_left": {"column": 5, "type": "array", "default": []},
		"middle": {"column": 6, "type": "array", "default": []},
		"middle_right": {"column": 7, "type": "array", "default": []},
		"right": {"column": 8, "type": "array", "default": []},
		"scene_properties": {"column": 9, "type": "scene_props", "default": []},
		"dialogue_choice": {"column": 10, "type": "string", "default": ""},
		"next_line_properties": {"column": 11, "type": "next_line", "default": []},
		"give_item": {"column": 12, "type": "array", "default": []},
		"chapterid": {"column": 13, "type": "string", "default": ""},
		"goto": {"column": 14, "type": "string", "default": ""},
		"special_effects": {"column": 15, "type": "array", "default": []},
		"sound_effect": {"column": 16, "type": "string", "default": ""},
		"music_effect": {"column": 17, "type": "string", "default": ""}
	}


## Schema untuk Item Data CSV
static func get_item_schema() -> Dictionary:
	return {
		"id": {"column": 0, "type": "int", "is_id": true},
		"name": {"column": 1, "type": "string", "default": ""},
		"type": {"column": 2, "type": "string", "default": ""},
		"description": {"column": 3, "type": "string", "default": ""},
		"richness": {"column": 4, "type": "int", "default": 0},
		"boldness": {"column": 5, "type": "int", "default": 0},
		"fanciness": {"column": 6, "type": "int", "default": 0},
		"unlock_price": {"column": 7, "type": "int", "default": 0},
		"buy_price": {"column": 8, "type": "int", "default": 0},
		"icon_default": {"column": 9, "type": "string", "default": ""},
		"where_to_get": {"column": 10, "type": "string", "default": ""}
	}


## Key order untuk dialog JSON output
static func get_dialog_key_order() -> Array:
	return [
		"lineid", "name", "character", "text",
		"left", "middle_left", "middle", "middle_right", "right",
		"scene_properties", "dialogue_choice", "next_line_properties",
		"give_item", "chapterid", "goto",
		"special_effects", "sound_effect", "music_effect"
	]


## Key order untuk Item JSON output
static func get_item_key_order() -> Array:
	return [
		"id", "name", "type", "description",
		"richness", "boldness", "fanciness",
		"unlock_price", "buy_price", "icon_default", "where_to_get"
	]


## Dialog parser configuration
static func get_dialog_config() -> Dictionary:
	return {
		"schema": get_dialog_schema(),
		"group_column": 13,       # Group by chapterid
		"start_row": 5,           # Skip first 5 header rows
		"id_column": 0,           # lineid as ID
		"metadata_column": 1,     # Name column untuk deteksi BUTTONHEADER
		"metadata_value_column": 2,  # Text column untuk nilai button header
		"supported_metadata_types": ["BUTTONHEADER"],
		"key_order": get_dialog_key_order()
	}


## Item parser configuration
static func get_item_config() -> Dictionary:
	return {
		"schema": get_item_schema(),
		"group_column": 2,        # Group by type
		"start_row": 1,           # Skip header row
		"id_column": 0,           # id as ID
		"metadata_column": -1,    # No metadata
		"metadata_value_column": -1,
		"supported_metadata_types": [],
		"key_order": get_item_key_order()
	}


## Schema untuk Ingredient Data CSV (output tanpa root)
static func get_ingredient_schema() -> Dictionary:
	return {
		"id": {"column": 0, "type": "int", "is_id": true},
		"nameEnglish": {"column": 1, "type": "string", "default": ""},
		"nameIndonesian": {"column": 1, "type": "string", "default": null},  # Same column, can be set differently if needed
		"description": {"column": 3, "type": "string", "default": ""},
		"iconBig": {"column": 9, "type": "string", "default": "placeholder"},
		"iconHovered": {"column": 9, "type": "string", "default": "placeholder"},
		"iconFocused": {"column": 9, "type": "string", "default": "placeholder"},
		"iconDefault": {"column": 9, "type": "string", "default": ""},
		"iconFull": {"column": 9, "type": "string", "default": ""},
		"traits": {
			"type": "nested",
			"fields": {
				"richness": {"column": 4, "type": "int", "default": 0},
				"boldness": {"column": 5, "type": "int", "default": 0},
				"fanciness": {"column": 6, "type": "int", "default": 0}
			}
		},
		"unlockPrice": {"column": 7, "type": "int", "default": 0},
		"shopLocation": {"column": 10, "type": "string", "default": "-"}
	}


## Key order untuk Ingredient JSON output (tanpa root)
static func get_ingredient_key_order() -> Array:
	return [
		"id", "nameEnglish", "nameIndonesian", "description",
		"iconBig", "iconHovered", "iconFocused", "iconDefault", "iconFull",
		"traits", "unlockPrice", "shopLocation"
	]


## Ingredient parser configuration (output langsung ke kategori tanpa root)
static func get_ingredient_config() -> Dictionary:
	return {
		"schema": get_ingredient_schema(),
		"group_column": 2,        # Group by Type (Base, Seasoning, etc.)
		"start_row": 1,           # Skip header row
		"id_column": 0,           # id as ID
		"metadata_column": -1,    # No metadata
		"metadata_value_column": -1,
		"supported_metadata_types": [],
		"key_order": get_ingredient_key_order(),
		"no_root": true           # Flag untuk output tanpa root
	}


