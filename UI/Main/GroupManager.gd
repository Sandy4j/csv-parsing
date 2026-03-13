class_name GroupManager
extends RefCounted

## Manager untuk Chapter/Group Filter UI
## Menghandle loading chapters dari CSV dan manage checkbox UI

signal selection_changed(selected: Array)
signal chapters_loaded(groups: Array, type_name: String)
signal load_error(message: String, errors: Array)

var _container: VBoxContainer
var _checkboxes: Array[CheckBox] = []
var _selected_groups: Array[String] = []

# Parser reference untuk loading chapters
var _parser: Node = null
var _current_csv_type: CSVConfig.CSVType = CSVConfig.CSVType.UNKNOWN


func _init(checkbox_container: VBoxContainer, parser: Node = null) -> void:
	_container = checkbox_container
	_parser = parser


## SET parser untuk loading chapters
func set_parser(parser: Node) -> void:
	_parser = parser


## Load chapters dari CSV file
func load_chapters(csv_path: String, csv_type: CSVConfig.CSVType) -> void:
	_current_csv_type = csv_type
	
	if _parser == null:
		load_error.emit("Parser tidak ditemukan", ["Parser belum di-set"])
		return
	
	# Configure parser untuk CSV type ini (chapter loading tidak butuh generator)
	CSVConfig.configure_parser(_parser, csv_type)
	var type_name = CSVConfig.get_type_name(csv_type)
	
	# Parse dalam mode STRUCTURE_ONLY (hanya untuk load chapters)
	_parser.set_parse_mode(CSVParser.ParseMode.STRUCTURE_ONLY)
	
	if not _parser.parse_csv_from_path(csv_path):
		var structural_errors: Array[String] = []
		for err in _parser.parsing_errors:
			if err is String:
				structural_errors.append(err)
		load_error.emit("Gagal memproses file CSV", structural_errors)
		return
	
	var groups = _parser.get_available_groups()
	chapters_loaded.emit(groups, type_name)


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
		if checkbox.toggled.is_connected(_on_checkbox_toggled.bind(checkbox.text)):
			checkbox.toggled.disconnect(_on_checkbox_toggled.bind(checkbox.text))
		checkbox.button_pressed = true
		if not checkbox.toggled.is_connected(_on_checkbox_toggled.bind(checkbox.text)):
			checkbox.toggled.connect(_on_checkbox_toggled.bind(checkbox.text))
		_selected_groups.append(checkbox.text)
	selection_changed.emit(_selected_groups.duplicate())


func deselect_all() -> void:
	for checkbox in _checkboxes:
		if checkbox.toggled.is_connected(_on_checkbox_toggled.bind(checkbox.text)):
			checkbox.toggled.disconnect(_on_checkbox_toggled.bind(checkbox.text))
		checkbox.button_pressed = false
		if not checkbox.toggled.is_connected(_on_checkbox_toggled.bind(checkbox.text)):
			checkbox.toggled.connect(_on_checkbox_toggled.bind(checkbox.text))
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


## GET current CSV type
func get_current_csv_type() -> CSVConfig.CSVType:
	return _current_csv_type


## Callback untuk checkbox
func _on_checkbox_toggled(toggled_on: bool, group_name: String) -> void:
	if toggled_on:
		if not _selected_groups.has(group_name):
			_selected_groups.append(group_name)
	else:
		_selected_groups.erase(group_name)

	selection_changed.emit(_selected_groups.duplicate())
