extends Control

## Main UI Controller - Mengelola alur kerja CSV to JSON conversion

# Referensi UI
@onready var file_path_edit: LineEdit = %FilePathEdit
@onready var browse_button: Button = %BrowseButton
@onready var output_path_edit: LineEdit = %OutputPathEdit
@onready var output_browse_button: Button = %OutputBrowseButton
@onready var root_name_edit: LineEdit = %RootNameEdit
@onready var generate_button: Button = %GenerateButton
@onready var status_label: Label = %StatusLabel
@onready var file_dialog: FileDialog = %FileDialog
@onready var output_file_dialog: FileDialog = %OutputFileDialog

@onready var load_chapters_button: Button = %LoadChaptersButton
@onready var chapter_scroll_container: ScrollContainer = %ChapterScrollContainer
@onready var chapter_checkbox_container: VBoxContainer = %ChapterCheckboxContainer
@onready var select_all_button: Button = %SelectAllButton
@onready var deselect_all_button: Button = %DeselectAllButton
@onready var chapter_filter_container: VBoxContainer = %ChapterFilterContainer
@onready var open_json_viewer_button: Button = %OpenJsonViewerButton

# Preload scripts
const CSVParserScript = preload("res://Data/Parser.gd")
const JSONGeneratorScript = preload("res://Data/Json_generate.gd")

# Core components
var parser: Node
var json_generator: Node
var Group_Manager: GroupManager
var current_csv_type: CSVConfig.CSVType = CSVConfig.CSVType.DIALOG


func _ready() -> void:
	_init_components()
	_connect_signals()
	_update_status("Ready - Select CSV file and output location")
	chapter_filter_container.visible = false
func _init_components() -> void:
	parser = CSVParserScript.new()
	json_generator = JSONGeneratorScript.new()
	add_child(parser)
	add_child(json_generator)
	Group_Manager = GroupManager.new(chapter_checkbox_container)
	Group_Manager.selection_changed.connect(_on_filter_selection_changed)


func _connect_signals() -> void:
	browse_button.pressed.connect(_on_browse_pressed)
	output_browse_button.pressed.connect(_on_output_browse_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	output_file_dialog.file_selected.connect(_on_output_file_selected)
	load_chapters_button.pressed.connect(_on_load_chapters_pressed)
	generate_button.pressed.connect(_on_generate_pressed)
	open_json_viewer_button.pressed.connect(_on_open_json_viewer_pressed)
	select_all_button.pressed.connect(Group_Manager.select_all)
	deselect_all_button.pressed.connect(Group_Manager.deselect_all)

func _on_browse_pressed() -> void:
	file_dialog.popup_centered()
func _on_output_browse_pressed() -> void:
	output_file_dialog.popup_centered()
func _on_file_selected(path: String) -> void:
	file_path_edit.text = path
	_reset_chapter_filter()
	_update_status("CSV file selected. Click 'Load Chapters' to see available groups.")
func _on_output_file_selected(path: String) -> void:
	if not path.ends_with(".json"):
		path += ".json"
	output_path_edit.text = path

## Funcitons untuk mengelola filter chapters
func _on_load_chapters_pressed() -> void:
	var csv_path = file_path_edit.text.strip_edges()
	
	if csv_path.is_empty():
		_update_status("Error: Please select a CSV file first")
		return
	
	_detect_and_configure(csv_path)
	_update_status("Loading groups from CSV...")
	
	# Parse CSV
	if not parser.parse_csv_from_path(csv_path):
		_update_status("Error: Failed to parse CSV file")
		return
	
	# Dapatkan groups yang tersedia
	var groups = parser.get_available_groups()
	
	if groups.is_empty():
		_update_status("No groups found in CSV file (flat data mode)")
		chapter_filter_container.visible = false
		return
	
	# Populate filter
	chapter_filter_container.visible = true
	Group_Manager.populate(groups)
	
	var group_label = CSVConfig.get_group_label(current_csv_type)
	_update_status("Found %d %s. Click to select/deselect." % [groups.size(), group_label])

## Callback saat filter diubah
func _on_filter_selection_changed(selected: Array) -> void:
	var total = Group_Manager.get_total_count()
	var count = Group_Manager.get_selected_count()
	var group_label = CSVConfig.get_group_label(current_csv_type)
	_update_status("Selected %d/%d %s" % [count, total, group_label])
func _reset_chapter_filter() -> void:
	Group_Manager.clear()
	chapter_filter_container.visible = false



## Fungsi utama untuk generate JSON dari CSV
func _on_generate_pressed() -> void:
	var csv_path = file_path_edit.text.strip_edges()
	var output_path = output_path_edit.text.strip_edges()
	
	if not _validate_paths(csv_path, output_path):
		return
	
	if not output_path.ends_with(".json"):
		output_path += ".json"
	
	_detect_and_configure(csv_path)
	_update_status("Parsing CSV...")
	
	# Parse
	if not parser.parse_csv_from_path(csv_path):
		_update_status("Error: Failed to parse CSV file")
		return
	
	# Get data
	var data_to_export = _get_export_data()
	if data_to_export.is_empty():
		_update_status("Error: No data to export.")
		return
	
	# Generate JSON
	_update_status("Generating JSON...")
	_apply_root_name()
	
	var json_string = json_generator.generate_json_to_path(data_to_export, output_path)
	if json_string.is_empty():
		_update_status("Error: Failed to generate JSON")
		return
	
	# Success
	var group_label = CSVConfig.get_group_label(current_csv_type)
	_update_status("Success! Exported %d %s to: %s" % [data_to_export.size(), group_label, output_path])

## Validasi path input
func _validate_paths(csv_path: String, output_path: String) -> bool:
	if csv_path.is_empty():
		_update_status("Error: Please select a CSV file")
		return false
	
	if output_path.is_empty():
		_update_status("Error: Please select output JSON location")
		return false
	
	return true

## Dapatkan data yang akan diexport dari CSV
func _get_export_data() -> Dictionary:
	var selected = Group_Manager.get_selected()
	var data = parser.get_filtered_data(selected)
	
	if data.is_empty():
		data = parser.get_data()
	
	return data


func _apply_root_name() -> void:
	var root_name = root_name_edit.text.strip_edges()
	if root_name.is_empty():
		# Jika root name kosong, gunakan format tanpa root wrapper
		json_generator.set_no_root_wrapper(true)
	else:
		json_generator.set_no_root_wrapper(false)
		json_generator.set_root_name(root_name)



## Deteksi tipe CSV dan konfigurasi parser dan generator
func _detect_and_configure(csv_path: String) -> void:
	current_csv_type = CSVConfig.detect_type(csv_path)
	CSVConfig.configure_all(parser, json_generator, current_csv_type)
	
	var type_name = CSVConfig.get_type_name(current_csv_type)
	_update_status("Detected: %s CSV format" % type_name)


func _update_status(message: String) -> void:
	status_label.text = "Status: " + message
func _on_open_json_viewer_pressed() -> void:
	get_tree().change_scene_to_file("res://UI/JSON UI/Json UI.tscn")
