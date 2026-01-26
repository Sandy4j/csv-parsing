class_name PatronsManager
extends RefCounted

## Manager untuk Patron Selection UI

signal patron_selected(patron_name: String)

var _container: VBoxContainer
var _checkboxes: Array[CheckBox] = []
var _selected_patron: String = ""

func _init(container: VBoxContainer) -> void:
	_container = container

## Populate checkboxes dari daftar patron names
func populate(patron_names: Array) -> void:
	clear()
	
	var group = ButtonGroup.new()
	
	for patron_name in patron_names:
		var checkbox = CheckBox.new()
		checkbox.text = str(patron_name)
		checkbox.button_group = group
		checkbox.toggled.connect(_on_checkbox_toggled.bind(str(patron_name)))
		_container.add_child(checkbox)
		_checkboxes.append(checkbox)

## Clear semua checkboxes
func clear() -> void:
	for checkbox in _checkboxes:
		if is_instance_valid(checkbox):
			checkbox.queue_free()
	_checkboxes.clear()
	_selected_patron = ""

## GET patron yang dipilih
func get_selected_patron() -> String:
	return _selected_patron

## Callback untuk checkbox
func _on_checkbox_toggled(toggled_on: bool, patron_name: String) -> void:
	if toggled_on:
		_selected_patron = patron_name
		GlobalData.selected_patron = patron_name
		patron_selected.emit(patron_name)
