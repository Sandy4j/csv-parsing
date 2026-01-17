class_name GroupManager
extends RefCounted

## Manager untuk Chapter/Group Filter UI

signal selection_changed(selected: Array)

var _container: VBoxContainer
var _checkboxes: Array[CheckBox] = []
var _selected_groups: Array[String] = []


func _init(checkbox_container: VBoxContainer) -> void:
	_container = checkbox_container


## Populate checkboxes dari daftar groups
func populate(groups: Array) -> void:
	clear()
	
	for group in groups:
		var checkbox = CheckBox.new()
		checkbox.text = str(group)
		checkbox.button_pressed = true
		checkbox.toggled.connect(_on_checkbox_toggled.bind(str(group)))
		_container.add_child(checkbox)
		_checkboxes.append(checkbox)
		_selected_groups.append(str(group))
## Clear semua checkboxes
func clear() -> void:
	for checkbox in _checkboxes:
		if is_instance_valid(checkbox):
			checkbox.queue_free()
	_checkboxes.clear()
	_selected_groups.clear()


## Select/Deselect all checkboxes
func select_all() -> void:
	_selected_groups.clear()
	for checkbox in _checkboxes:
		_disconnect_checkbox(checkbox)
		checkbox.button_pressed = true
		_connect_checkbox(checkbox)
		_selected_groups.append(checkbox.text)
	selection_changed.emit(_selected_groups.duplicate())
func deselect_all() -> void:
	for checkbox in _checkboxes:
		_disconnect_checkbox(checkbox)
		checkbox.button_pressed = false
		_connect_checkbox(checkbox)
	_selected_groups.clear()
	selection_changed.emit(_selected_groups.duplicate())


## GET grup yang dipilih
func get_selected() -> Array[String]:
	return _selected_groups.duplicate()
## GET jumlah total checkbox
func get_total_count() -> int:
	return _checkboxes.size()
## GET jumlah checkbox yang dipilih	
func get_selected_count() -> int:
	return _selected_groups.size()


## Check apakah ada grup yang dipilih
func has_groups() -> bool:
	return not _checkboxes.is_empty()

## Callback untuk checkbox
func _on_checkbox_toggled(toggled_on: bool, group_name: String) -> void:
	if toggled_on:
		if not _selected_groups.has(group_name):
			_selected_groups.append(group_name)
	else:
		_selected_groups.erase(group_name)

	selection_changed.emit(_selected_groups.duplicate())

## Function untuk menghubungkan/memutus signal toggled
func _disconnect_checkbox(checkbox: CheckBox) -> void:
	if checkbox.toggled.is_connected(_on_checkbox_toggled.bind(checkbox.text)):
		checkbox.toggled.disconnect(_on_checkbox_toggled.bind(checkbox.text))
func _connect_checkbox(checkbox: CheckBox) -> void:
	if not checkbox.toggled.is_connected(_on_checkbox_toggled.bind(checkbox.text)):
		checkbox.toggled.connect(_on_checkbox_toggled.bind(checkbox.text))
