extends Control

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

# Referensi UI untuk Chapter Filter
@onready var load_chapters_button: Button = %LoadChaptersButton
@onready var chapter_scroll_container: ScrollContainer = %ChapterScrollContainer
@onready var chapter_checkbox_container: VBoxContainer = %ChapterCheckboxContainer
@onready var select_all_button: Button = %SelectAllButton
@onready var deselect_all_button: Button = %DeselectAllButton
@onready var chapter_filter_container: VBoxContainer = %ChapterFilterContainer
@onready var open_json_viewer_button: Button = %OpenJsonViewerButton

# Referensi ke script Parser dan JsonGenerate
var parser: Node
var json_generator: Node
var selected_chapters: Array = []
var chapter_checkboxes: Array = []

func _ready() -> void:
	parser = preload("res://Data/Parser.gd").new()
	json_generator = preload("res://Data/Json_generate.gd").new()
	add_child(parser)
	add_child(json_generator)
	
	_connect_signals()
	update_status("Ready - Select CSV file and output location")
	
	# Sembunyikan chapter filter sampai CSV di-load
	chapter_filter_container.visible = false

func _connect_signals() -> void:
	browse_button.pressed.connect(_on_browse_pressed)
	output_browse_button.pressed.connect(_on_output_browse_pressed)
	generate_button.pressed.connect(_on_generate_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	output_file_dialog.file_selected.connect(_on_output_file_selected)
	load_chapters_button.pressed.connect(_on_load_chapters_pressed)
	select_all_button.pressed.connect(_on_select_all_pressed)
	deselect_all_button.pressed.connect(_on_deselect_all_pressed)
	open_json_viewer_button.pressed.connect(_on_open_json_viewer_pressed)

func _on_browse_pressed() -> void:
	file_dialog.popup_centered()

func _on_output_browse_pressed() -> void:
	output_file_dialog.popup_centered()

func _on_file_selected(path: String) -> void:
	file_path_edit.text = path
	# Reset chapter filter saat file baru dipilih
	_clear_chapter_checkboxes()
	selected_chapters.clear()
	chapter_filter_container.visible = false
	update_status("CSV file selected. Click 'Load Chapters' to see available chapters.")

func _on_output_file_selected(path: String) -> void:
	# Pastikan path berakhiran .json
	if not path.ends_with(".json"):
		path += ".json"
	output_path_edit.text = path

func _on_load_chapters_pressed() -> void:
	var csv_path = file_path_edit.text.strip_edges()
	
	if csv_path.is_empty():
		update_status("Error: Please select a CSV file first")
		return
	
	update_status("Loading chapters from CSV...")
	
	# Parse CSV untuk mendapatkan daftar chapter
	var parse_success = parser.parse_csv_from_path(csv_path)
	if not parse_success:
		update_status("Error: Failed to parse CSV file")
		return
	
	# Ambil daftar chapter yang tersedia
	var chapters = parser.get_available_chapters()
	
	if chapters.is_empty():
		update_status("No chapters found in CSV file")
		return
	
	# Tampilkan chapter filter
	chapter_filter_container.visible = true
	
	# bersihkan checkbox
	_clear_chapter_checkboxes()
	
	# Buat checkbox untuk setiap chapter
	for chapter in chapters:
		var checkbox = CheckBox.new()
		checkbox.text = chapter
		checkbox.button_pressed = true
		checkbox.toggled.connect(_on_checkbox_toggled.bind(chapter))
		chapter_checkbox_container.add_child(checkbox)
		chapter_checkboxes.append(checkbox)
		selected_chapters.append(chapter)
	
	update_status("Found %d chapters. Click on chapters to select/deselect." % chapters.size())

func _clear_chapter_checkboxes() -> void:
	for checkbox in chapter_checkboxes:
		checkbox.queue_free()
	chapter_checkboxes.clear()

func _on_checkbox_toggled(toggled_on: bool, chapter_name: String) -> void:
	if toggled_on:
		if not selected_chapters.has(chapter_name):
			selected_chapters.append(chapter_name)
	else:
		selected_chapters.erase(chapter_name)
	
	_update_selection_status()

func _on_select_all_pressed() -> void:
	selected_chapters.clear()
	for checkbox in chapter_checkboxes:
		checkbox.toggled.disconnect(_on_checkbox_toggled.bind(checkbox.text))
		checkbox.button_pressed = true
		checkbox.toggled.connect(_on_checkbox_toggled.bind(checkbox.text))
		selected_chapters.append(checkbox.text)
	_update_selection_status()

func _on_deselect_all_pressed() -> void:
	for checkbox in chapter_checkboxes:
		checkbox.toggled.disconnect(_on_checkbox_toggled.bind(checkbox.text))
		checkbox.button_pressed = false
		checkbox.toggled.connect(_on_checkbox_toggled.bind(checkbox.text))
	selected_chapters.clear()
	_update_selection_status()

func _update_selection_status() -> void:
	var total = chapter_checkboxes.size()
	var selected = selected_chapters.size()
	update_status("Selected %d/%d chapters" % [selected, total])

func _on_generate_pressed() -> void:
	var csv_path = file_path_edit.text.strip_edges()
	var output_path = output_path_edit.text.strip_edges()
	
	# Validasi input
	if csv_path.is_empty():
		update_status("Error: Please select a CSV file")
		return
	
	if output_path.is_empty():
		update_status("Error: Please select output JSON location")
		return
	
	# Pastikan nama file berakhiran .json
	if not output_path.ends_with(".json"):
		output_path += ".json"
	
	update_status("Parsing CSV...")
	
	# Parse CSV menggunakan Parser.gd
	var parse_success = parser.parse_csv_from_path(csv_path)
	if not parse_success:
		update_status("Error: Failed to parse CSV file")
		return
	
	# Ambil data yang sudah difilter berdasarkan chapter yang dipilih
	var data_to_export = parser.get_filtered_data(selected_chapters)
	
	if data_to_export.is_empty():
		update_status("Error: No data to export. Please select at least one chapter.")
		return
	
	update_status("Generating JSON...")
	
	# Ambil root name dari input user atau gunakan default
	var root_name = root_name_edit.text.strip_edges()
	if root_name.is_empty():
		root_name = "DefaultRoot"
	
	# Generate JSON menggunakan Json_generate.gd
	var json_string = json_generator.generate_json_to_path(data_to_export, output_path, root_name)
	if json_string.is_empty():
		update_status("Error: Failed to generate JSON")
		return
	
	var chapter_count = data_to_export.size()
	update_status("Success! Exported %d chapters to: %s" % [chapter_count, output_path])

func update_status(message: String) -> void:
	status_label.text = "Status: " + message

func _on_open_json_viewer_pressed() -> void:
	get_tree().change_scene_to_file("res://UI/JSON UI/Json UI.tscn")
