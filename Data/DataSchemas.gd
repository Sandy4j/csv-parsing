class_name DataSchemas
extends RefCounted

## Preset skema untuk parsing CSV data

## Schema untuk file Dialog CSV
static func get_dialog_schema() -> Dictionary:
	return {
		"lineid": {"header_name": "lineid", "type": "string", "is_id": true},
		"name": {"header_name": "Name", "type": "string", "default": ""},
		"text": {"header_name": "text", "type": "string", "default": ""},
		"character": {"header_name": "character", "type": "array", "default": []},
		"left": {"header_name": "left", "type": "array", "default": []},
		"middle_left": {"header_name": "middle-left", "type": "array", "default": []},
		"middle": {"header_name": "middle", "type": "array", "default": []},
		"middle_right": {"header_name": "middle-right", "type": "array", "default": []},
		"right": {"header_name": "right", "type": "array", "default": []},
		"scene_properties": {"header_name": "scene_properties", "type": "scene_props", "default": []},
		"dialogue_choice": {"header_name": "dialogue_choice", "type": "string", "default": ""},
		"next_line_properties": {"header_name": "next_line_properties", "type": "next_line", "default": []},
		"give_item": {"header_name": "give_item", "type": "array", "default": []},
		"chapterid": {"header_name": "chapter", "type": "string", "default": ""},
		"goto": {"header_name": "goto", "type": "string", "default": ""},
		"special_effects": {"header_name": "special_effects", "type": "array", "default": []},
		"sound_effect": {"header_name": "sound_effects", "type": "string", "default": ""},
		"music_effect": {"header_name": "music_effect", "type": "string", "default": ""}
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


## Dialog parser configuration
static func get_dialog_config() -> Dictionary:
	return {
		"schema": get_dialog_schema(),
		"group_header": "chapter",       # Grouping menggunakan kolom 'chapter'
		"header_row": 0,                   # Header ada di baris pertama (0)
		"start_row": 4,                    # Data dimulai baris ke-5
		"id_header": "lineid",             # lineid sebagai ID
		"metadata_header": "Name",         # Name column untuk deteksi BUTTONHEADER
		"metadata_value_header": "text",   # Text column untuk nilai button header
		"supported_metadata_types": ["BUTTONHEADER"],
		"key_order": get_dialog_key_order()
	}


## Schema untuk Ingredient Data CSV
static func get_ingredient_schema() -> Dictionary:
	return {
		"id": {"header_name": "id", "type": "int", "is_id": true},
		"nameEnglish": {"header_name": "name", "type": "string", "default": ""},
		"nameIndonesian": {"header_name": "name_id", "type": "string", "default": null},
		"description": {"header_name": "description", "type": "string", "default": ""},
		"iconBig": {"header_name": "icon", "type": "string", "default": "placeholder"},
		"iconHovered": {"header_name": "icon", "type": "string", "default": "placeholder"},
		"iconFocused": {"header_name": "icon", "type": "string", "default": "placeholder"},
		"iconDefault": {"header_name": "icon", "type": "string", "default": ""},
		"iconFull": {"header_name": "icon", "type": "string", "default": ""},
		"traits": {
			"type": "nested",
			"fields": {
				"richness": {"header_name": "richness", "type": "int", "default": 0},
				"boldness": {"header_name": "boldness", "type": "int", "default": 0},
				"fanciness": {"header_name": "fanciness", "type": "int", "default": 0}
			}
		},
		"unlockPrice": {"header_name": "unlock_price", "type": "float", "default": 0.0},
		"shopLocation": {"header_name": "shop_location", "type": "string", "default": "-"}
	}


## Key order untuk Ingredient JSON output
static func get_ingredient_key_order() -> Array:
	return [
		"id", "nameEnglish", "nameIndonesian", "description",
		"iconBig", "iconHovered", "iconFocused", "iconDefault", "iconFull",
		"traits", "unlockPrice", "shopLocation"
	]


## Ingredient parser configuration
static func get_ingredient_config() -> Dictionary:
	return {
		"schema": get_ingredient_schema(),
		"group_header": "type",           # Group by Type header
		"header_row": 0,                  # Baris ke-0 adalah header
		"start_row": 1,                   # Skip header row
		"id_header": "id",                # id sebagai ID
		"metadata_header": "",            # No metadata
		"metadata_value_header": "",
		"supported_metadata_types": [],
		"key_order": get_ingredient_key_order(),
	}


## Schema untuk Item Data CSV
static func get_item_schema() -> Dictionary:
	return {
		"id": {"header_name": "IngredientId", "type": "int", "is_id": true},
		"name": {"header_name": "Ingredient Name", "type": "string", "default": ""},
		"type": {"header_name": "Type", "type": "string", "default": ""},
		"description": {"header_name": "Description", "type": "string", "default": ""},
		"traits": {
			"type": "nested",
			"fields": {
				"richness": {"header_name": "Richness Gain", "type": "int", "default": 0},
				"boldness": {"header_name": "Boldness Gain", "type": "int", "default": 0},
				"fanciness": {"header_name": "Fanciness Gain", "type": "int", "default": 0}
			}
		},
		"unlockPrice": {"header_name": "Unlock Price", "type": "int", "default": 0},
		"buyPrice": {"header_name": "Buy Price", "type": "int", "default": 0},
		"icon": {"header_name": "filename_default", "type": "string", "default": ""},
		"shopLocation": {"header_name": "Where to Get", "type": "string", "default": "-"}
	}


## Key order untuk Item JSON output
static func get_item_key_order() -> Array:
	return [
		"id", "name", "type", "description",
		"traits", "unlockPrice", "buyPrice",
		"icon", "shopLocation"
	]


## Item parser configuration
static func get_item_config() -> Dictionary:
	return {
		"schema": get_item_schema(),
		"group_header": "type",           # Group by Type column
		"header_row": 0,                  # Baris ke-0 adalah header
		"start_row": 1,                   # Data dimulai baris ke-2 (skip header)
		"id_header": "ingredientid",      # IngredientId sebagai ID
		"metadata_header": "",            # No metadata
		"metadata_value_header": "",
		"supported_metadata_types": [],
		"key_order": get_item_key_order(),
	}
