class_name PreferenceManager
extends RefCounted

## Manager untuk handle load/save user preferences

const PREFS_FILE: String = "user://prefs.cfg"

var last_csv_dir: String = ""
var last_output_dir: String = ""


## Load preferences dari user://prefs.cfg
func load_preferences() -> void:
	var config = ConfigFile.new()
	var err = config.load(PREFS_FILE)
	if err == OK:
		last_csv_dir = config.get_value("paths", "last_csv_dir", "")
		last_output_dir = config.get_value("paths", "last_output_dir", "")
		print("[PreferenceManager] Loaded - CSV dir: ", last_csv_dir, ", Output dir: ", last_output_dir)
	else:
		print("[PreferenceManager] No preferences file found, using defaults")


## Save preferences ke user://prefs.cfg
func save_preferences() -> void:
	var config = ConfigFile.new()
	config.set_value("paths", "last_csv_dir", last_csv_dir)
	config.set_value("paths", "last_output_dir", last_output_dir)
	var err = config.save(PREFS_FILE)
	if err != OK:
		push_warning("[PreferenceManager] Failed to save preferences: ", err)
	else:
		print("[PreferenceManager] Saved - CSV dir: ", last_csv_dir, ", Output dir: ", last_output_dir)


## GET last CSV directory
func get_last_csv_dir() -> String:
	return last_csv_dir


## GET last output directory
func get_last_output_dir() -> String:
	return last_output_dir


## SET last CSV directory
func set_last_csv_dir(path: String) -> void:
	last_csv_dir = path


## SET last output directory
func set_last_output_dir(path: String) -> void:
	last_output_dir = path
