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
@onready var save_button: Button = %SaveButton
@onready var edit_popup: PopupPanel = %EditPopup
@onready var edit_value_edit: LineEdit = %EditValueEdit
@onready var edit_type_label: Label = %EditTypeLabel
@onready var edit_confirm_button: Button = %EditConfirmButton
@onready var edit_cancel_button: Button = %EditCancelButton
@onready var container_popup: PopupPanel = %ContainerPopup
@onready var container_type_label: Label = %ContainerTypeLabel
@onready var add_key_edit: LineEdit = %AddKeyEdit
@onready var add_value_edit: LineEdit = %AddValueEdit
@onready var add_value_type_option: OptionButton = %AddValueTypeOption
@onready var add_button: Button = %AddButton
@onready var delete_button: Button = %DeleteButton
@onready var container_cancel_button: Button = %ContainerCancelButton

var current_json_data: Variant = null
var current_file_path: String = ""
var json_editor: JsonEditor = null
var tree_handler: JsonTree = null

# Untuk tracking item yang sedang diedit
var _editing_item: TreeItem = null
var _editing_path: Array = []
var _editing_original_type: String = ""
var _container_item: TreeItem = null
var _container_path: Array = []
var _container_is_array: bool = false

func _ready() -> void:
	json_editor = JsonEditor.new()
	tree_handler = JsonTree.new()
	tree_handler.init(json_tree)
	_connect_signals()
	update_status("Ready - Select JSON file to view")

func _connect_signals() -> void:
	browse_button.pressed.connect(_on_browse_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	expand_all_button.pressed.connect(_on_expand_all_pressed)
	collapse_all_button.pressed.connect(_on_collapse_all_pressed)
	back_button.pressed.connect(_on_back_pressed)
	search_edit.text_changed.connect(_on_search_text_changed)
	save_button.pressed.connect(_on_save_pressed)
	json_tree.item_activated.connect(_on_tree_item_activated)
	edit_confirm_button.pressed.connect(_on_edit_confirm_pressed)
	edit_cancel_button.pressed.connect(_on_edit_cancel_pressed)
	edit_value_edit.text_submitted.connect(_on_edit_value_submitted)
	json_editor.json_saved.connect(_on_json_saved)
	json_editor.save_failed.connect(_on_save_failed)
	add_button.pressed.connect(_on_add_button_pressed)
	delete_button.pressed.connect(_on_delete_button_pressed)
	container_cancel_button.pressed.connect(_on_container_cancel_pressed)

func _on_browse_pressed() -> void:
	file_dialog.popup_centered()

func _on_file_selected(path: String) -> void:
	file_path_edit.text = path
	current_file_path = path
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
	current_file_path = path
	json_editor.init(current_json_data, current_file_path)
	tree_handler.set_data(current_json_data)
	tree_handler.build_tree(current_json_data)
	update_status("Loaded: " + path.get_file() + " (Double-click to edit values)")

## Fungsi expand/collapse semua item di tree
func _on_expand_all_pressed() -> void:
	tree_handler.expand_all()
	update_status("All nodes expanded")
func _on_collapse_all_pressed() -> void:
	tree_handler.collapse_all()
	update_status("All nodes collapsed")


## Kembail ke Main UI
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://UI/Main/Main.tscn")

## Fungsi untuk mengatur filter tree berdasarkan text yang diberikan
func _on_search_text_changed(new_text: String) -> void:
	if current_json_data == null:
		return
	if new_text.is_empty():
		tree_handler.build_tree(current_json_data)
		update_status("Filter cleared")
	else:
		tree_handler.build_tree(current_json_data, new_text)
		update_status("Filtering: " + new_text)

## Update status label di UI
func update_status(message: String) -> void:
	status_label.text = "Status: " + message

## Handler untuk double-click pada tree item (mulai edit)
func _on_tree_item_activated() -> void:
	var selected = json_tree.get_selected()
	if selected == null:
		return
	
	var item_path = selected.get_metadata(0)
	if item_path == null:
		item_path = []
	
	# Cek apakah item adalah container (dict/array)
	var current_value = json_editor.get_value_at_path(item_path)
	
	if current_value is Dictionary:
		_show_container_popup(selected, false)
		return
	elif current_value is Array:
		_show_container_popup(selected, true)
		return
	
	# Cek apakah item bisa diedit (hanya value primitif)
	if not selected.has_meta("is_editable") or not selected.get_meta("is_editable"):
		update_status("Cannot edit this item")
		return
	
	_editing_item = selected
	_editing_path = item_path
	_editing_original_type = selected.get_meta("value_type")
	
	# Dapatkan value saat ini (sudah di cek di atas)
	var value_str = JsonTree.value_to_edit_string(current_value)
	
	# Setup popup edit
	edit_type_label.text = "Type: " + _editing_original_type
	edit_value_edit.text = value_str
	edit_value_edit.select_all()
	
	# Tampilkan popup
	edit_popup.popup_centered()
	edit_value_edit.grab_focus()

## Konfirmasi edit value
func _on_edit_confirm_pressed() -> void:
	_apply_edit()

## Handler untuk submit value dengan Enter
func _on_edit_value_submitted(_new_text: String) -> void:
	_apply_edit()

## Apply perubahan edit
func _apply_edit() -> void:
	if _editing_item == null:
		edit_popup.hide()
		return
	
	var new_value_str = edit_value_edit.text
	var new_value = JsonEditor.parse_value_string(new_value_str, _editing_original_type)
	
	# Update via JsonEditor
	if json_editor.edit_value(_editing_path, new_value):
		# Rebuild tree untuk menampilkan perubahan
		current_json_data = json_editor.get_data()
		tree_handler.build_tree(current_json_data)
		update_status("Value updated (unsaved)")
	else:
		update_status("Error: Failed to update value")
	
	_editing_item = null
	_editing_path = []
	edit_popup.hide()

## Batal edit
func _on_edit_cancel_pressed() -> void:
	_editing_item = null
	_editing_path = []
	edit_popup.hide()
	update_status("Edit cancelled")

## Save JSON ke file
func _on_save_pressed() -> void:
	if current_file_path.is_empty():
		update_status("Error: No file loaded")
		return
	
	if not json_editor.has_unsaved_changes():
		update_status("No changes to save")
		return
	
	json_editor.save_to_file()

## Callback saat JSON berhasil disimpan
func _on_json_saved(path: String) -> void:
	update_status("Saved: " + path.get_file())

## Callback saat save gagal
func _on_save_failed(error: String) -> void:
	update_status("Save Error: " + error)

## Handler untuk tombol Add di container popup
func _on_add_button_pressed() -> void:
	if _container_item == null:
		return
	
	var new_value_str = add_value_edit.text.strip_edges()
	var new_value_type = add_value_type_option.get_selected_id()
	var new_value: Variant = null
	
	# Tentukan nilai baru berdasarkan tipe yang dipilih
	match new_value_type:
		0: # String
			new_value = new_value_str
		1: # Number (int/float)
			if new_value_str.is_valid_int():
				new_value = new_value_str.to_int()
			elif new_value_str.is_valid_float():
				new_value = new_value_str.to_float()
			else:
				new_value = 0
		2: # Boolean
			new_value = new_value_str.to_lower() == "true"
		3: # Null
			new_value = null
		4: # Empty Dict
			new_value = {}
		5: # Empty Array
			new_value = []
		_:
			update_status("Error: Invalid type selected")
			return
	
	# Tambahkan item baru ke JSON
	if _container_is_array:
		# Untuk array, tidak perlu key
		if json_editor.add_to_array(_container_path, new_value):
			update_status("Item added (unsaved)")
			current_json_data = json_editor.get_data()
			tree_handler.build_tree(current_json_data)
			container_popup.hide()
		else:
			update_status("Error: Failed to add item")
	else:
		# Untuk dictionary, perlu key
		var new_key = add_key_edit.text.strip_edges()
		if new_key.is_empty():
			update_status("Error: Key cannot be empty")
			return
		if json_editor.add_to_dict(_container_path, new_key, new_value):
			update_status("Item added (unsaved)")
			current_json_data = json_editor.get_data()
			tree_handler.build_tree(current_json_data)
			container_popup.hide()
		else:
			update_status("Error: Failed to add item")

## Handler untuk tombol Delete di container popup
func _on_delete_button_pressed() -> void:
	if _container_path.is_empty():
		update_status("Error: Cannot delete root")
		container_popup.hide()
		return
	
	# Hapus container dari parent
	if json_editor.delete_from_parent(_container_path):
		update_status("Item deleted (unsaved)")
		current_json_data = json_editor.get_data()
		tree_handler.build_tree(current_json_data)
		container_popup.hide()
	else:
		update_status("Error: Failed to delete item")

## Fungsi untuk menampilkan popup add/delete container
func _show_container_popup(item: TreeItem, is_array: bool) -> void:
	_container_item = item
	_container_path = item.get_metadata(0)
	if _container_path == null:
		_container_path = []
	_container_is_array = is_array
	
	# Setup popup fields
	if is_array:
		container_type_label.text = "Array Options"
		add_key_edit.hide()
	else:
		container_type_label.text = "Dictionary Options"
		add_key_edit.show()
		add_key_edit.clear()
	
	add_value_edit.clear()
	add_value_type_option.clear()
	add_value_type_option.add_item("String", 0)
	add_value_type_option.add_item("Number", 1)
	add_value_type_option.add_item("Boolean", 2)
	add_value_type_option.add_item("Null", 3)
	add_value_type_option.add_item("Empty Object {}", 4)
	add_value_type_option.add_item("Empty Array []", 5)
	add_value_type_option.select(0)
	
	container_popup.popup_centered()

## Handler untuk cancel container popup
func _on_container_cancel_pressed() -> void:
	_container_item = null
	_container_path = []
	container_popup.hide()
