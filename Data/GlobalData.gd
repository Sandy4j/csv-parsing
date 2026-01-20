extends Node

## Autoload singleton untuk menyimpan data antar scene

# Data untuk transfer dari Main ke JsonUI
var pending_json_path: String = ""
var pending_warning_ids: Array[String] = []
# Warning details: Array of Dictionary {"id": "1", "column": "buyPrice"}
var pending_warning_details: Array[Dictionary] = []

## Set pending data untuk JsonUI (legacy - hanya ID)
func set_pending_data(json_path: String, warning_ids: Array[String]) -> void:
	pending_json_path = json_path
	pending_warning_ids = warning_ids.duplicate()
	pending_warning_details.clear()
	print("[GlobalData] Data set - path: ", pending_json_path, ", warning_ids: ", pending_warning_ids)

## Set pending data dengan warning details (ID + kolom)
func set_pending_data_with_details(json_path: String, warning_details: Array[Dictionary]) -> void:
	pending_json_path = json_path
	pending_warning_details = warning_details.duplicate()
	# Juga populate warning_ids untuk backward compatibility
	pending_warning_ids.clear()
	for detail in warning_details:
		var id_str = str(detail.get("id", ""))
		if not id_str.is_empty() and not pending_warning_ids.has(id_str):
			pending_warning_ids.append(id_str)
	print("[GlobalData] Data set with details - path: ", pending_json_path, ", warning_details: ", pending_warning_details)

## Get dan clear pending data
func get_and_clear_pending_data() -> Dictionary:
	var data = {
		"path": pending_json_path,
		"warning_ids": pending_warning_ids.duplicate(),
		"warning_details": pending_warning_details.duplicate()
	}
	# Clear setelah diambil
	pending_json_path = ""
	pending_warning_ids.clear()
	pending_warning_details.clear()
	print("[GlobalData] Data retrieved and cleared")
	return data

## Cek apakah ada pending data
func has_pending_data() -> bool:
	return not pending_json_path.is_empty()
