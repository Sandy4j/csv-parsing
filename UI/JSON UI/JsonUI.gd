extends Control

# Referensi UI
@onready var file_path_edit: LineEdit = %FilePathEdit
@onready var browse_button: Button = %BrowseButton
@onready var json_tree: Tree = %JsonTree
@onready var status_label: Label = %StatusLabel
@onready var file_dialog: FileDialog = %FileDialog
@onready var expand_all_button: Button = %ExpandAllButton
@onready var collapse_all_button: Button = %CollapseAllButton
@onready var back_button: Button = %BackButton
@onready var search_edit: LineEdit = %SearchEdit

var current_json_data: Variant = null

func _ready() -> void:
	_connect_signals()
	update_status("Ready - Select JSON file to view")

func _connect_signals() -> void:
	browse_button.pressed.connect(_on_browse_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	expand_all_button.pressed.connect(_on_expand_all_pressed)
	collapse_all_button.pressed.connect(_on_collapse_all_pressed)
	back_button.pressed.connect(_on_back_pressed)
	search_edit.text_changed.connect(_on_search_text_changed)

func _on_browse_pressed() -> void:
	file_dialog.popup_centered()

func _on_file_selected(path: String) -> void:
	file_path_edit.text = path
	_load_json_file(path)

## Load file JSON dari path yang diberikan
func _load_json_file(path: String) -> void:
	update_status("Loading JSON...")
	
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		update_status("Error: Cannot open file - " + str(FileAccess.get_open_error()))
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	# Parse file JSON
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		update_status("Error: Invalid JSON - " + json.get_error_message() + " at line " + str(json.get_error_line()))
		return
	
	current_json_data = json.data
	_build_tree(current_json_data)
	update_status("Loaded: " + path.get_file())

## Buat tree dari data yang diberikan
func _build_tree(data: Variant, filter_text: String = "") -> void:
	json_tree.clear()
	
	var root = json_tree.create_item()
	root.set_text(0, "JSON Root")
	
	# Cek apakah data adalah dictionary atau array
	if data is Dictionary:
		for key in data.keys():
			_add_tree_items(root, data[key], str(key), filter_text)
	elif data is Array:
		for i in range(data.size()):
			_add_tree_items(root, data[i], "[%d]" % i, filter_text)
	else:
		_add_tree_items(root, data, "value", filter_text)
	
	# Expand root secara default
	root.set_collapsed(false)

## Menambahkan item baru untuk setiap item di data ke visual tree
func _add_tree_items(parent: TreeItem, data: Variant, key: String, filter_text: String = "") -> TreeItem:
	var item = json_tree.create_item(parent)
	var should_show = filter_text.is_empty()
	
	# Check apakah item adalah dictionary atau array
	if data is Dictionary:
		var dict_size = data.size()
		item.set_text(0, "%s {%d}" % [key, dict_size])
		item.set_collapsed(true)
		
		# Rekursif untuk menambahkan item baru untuk setiap item di dictionary
		for dict_key in data.keys():
			var child_item = _add_tree_items(item, data[dict_key], str(dict_key), filter_text)
			if child_item != null and not filter_text.is_empty():
				should_show = true
		
	elif data is Array:
		var arr_size = data.size()
		item.set_text(0, "%s [%d]" % [key, arr_size])
		item.set_collapsed(true)
		
		# rekursif untuk menambahkan item baru untuk setiap item di array
		for i in range(data.size()):
			var child_item = _add_tree_items(item, data[i], "[%d]" % i, filter_text)
			if child_item != null and not filter_text.is_empty():
				should_show = true
		
	else:
		# Item adalah nilai dasar
		var value_str = _format_value(data)
		var display_text = "%s: %s" % [key, value_str]
		item.set_text(0, display_text)
		
		# Cek apakah item harus ditampilkan
		if not filter_text.is_empty():
			if filter_text.to_lower() in display_text.to_lower():
				should_show = true
	
	# Handle sistem filter
	if not filter_text.is_empty() and not should_show:
		item.free()
		return null
	
	return item

## Fungsi untuk mengatur format nilai untuk menampilkan ke visual tree
func _format_value(value: Variant) -> String:
	if value == null:
		return "null"
	elif value is String:
		# Mengatur limit karakter untuk string
		if value.length() > 100:
			return '"%s..."' % value.substr(0, 100)
		return '"%s"' % value
	elif value is bool:
		return "true" if value else "false"
	else:
		return str(value)

## GET tipe data dari nilai
func _get_value_type(value: Variant) -> String:
	if value == null:
		return "null"
	elif value is String:
		return "string"
	elif value is bool:
		return "bool"
	elif value is int or value is float:
		return "number"
	else:
		return "unknown"

## Fungsi expand/collapse semua item di tree
func _on_expand_all_pressed() -> void:
	_set_all_collapsed(false)
	update_status("All nodes expanded")
func _on_collapse_all_pressed() -> void:
	_set_all_collapsed(true)
	update_status("All nodes collapsed")

## Fungsi untuk mengatur semua item di tree menjadi collapsed atau expanded
func _set_all_collapsed(collapsed: bool) -> void:
	var root = json_tree.get_root()
	if root == null:
		return
	_set_item_collapsed_recursive(root, collapsed)
func _set_item_collapsed_recursive(item: TreeItem, collapsed: bool) -> void:
	item.set_collapsed(collapsed)
	var child = item.get_first_child()
	while child != null:
		_set_item_collapsed_recursive(child, collapsed)
		child = child.get_next()

## Kembail ke Main UI
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://UI/Main/Main.tscn")

## Fungsi untuk mengatur filter tree berdasarkan text yang diberikan
func _on_search_text_changed(new_text: String) -> void:
	if current_json_data == null:
		return
	if new_text.is_empty():
		_build_tree(current_json_data)
		update_status("Filter cleared")
	else:
		_build_tree(current_json_data, new_text)
		update_status("Filtering: " + new_text)

## Update status label di UI
func update_status(message: String) -> void:
	status_label.text = "Status: " + message
