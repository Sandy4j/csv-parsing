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

# Error dialog
var error_dialog: AcceptDialog
var error_text_edit: TextEdit


func _ready() -> void:
	_init_components()
	_init_error_dialog()
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

func _init_error_dialog() -> void:
	error_dialog = AcceptDialog.new()
	error_dialog.title = "Error Log"
	error_dialog.ok_button_text = "Close"
	error_dialog.min_size = Vector2(600, 400)
	
	error_text_edit = TextEdit.new()
	error_text_edit.editable = false
	error_text_edit.custom_minimum_size = Vector2(580, 350)
	error_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	
	error_dialog.add_child(error_text_edit)
	add_child(error_dialog)


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
		_update_status("Error: Silakan pilih file CSV terlebih dahulu")
		return
	
	_update_status("Mendeteksi tipe CSV...")
	current_csv_type = CSVConfig.detect_type(csv_path)
	
	# Cegah proses jika tipe UNKNOWN
	if current_csv_type == CSVConfig.CSVType.UNKNOWN:
		_update_status("Error: Format CSV tidak dikenali")
		var detailed_error = CSVConfig.get_detection_error(csv_path)
		_show_error_report([detailed_error])
		return
	
	CSVConfig.configure_all(parser, json_generator, current_csv_type)
	var type_name = CSVConfig.get_type_name(current_csv_type)
	_update_status("Terdeteksi: Format %s. Memuat grup..." % type_name)
	
	# Parse CSV dalam mode STRUCTURE_ONLY
	parser.set_parse_mode(CSVParser.ParseMode.STRUCTURE_ONLY)
	if not parser.parse_csv_from_path(csv_path):
		_update_status("Error: Gagal memproses file CSV")
		# Hanya tampilkan error struktural, bukan conversion errors
		var structural_errors: Array[String] = []
		for err in parser.parsing_errors:
			if err is String:
				structural_errors.append(err)
		if not structural_errors.is_empty():
			_show_error_report(structural_errors)
		return
	
	# Tidak menampilkan popup warning untuk mode Load Chapters
	
	# Dapatkan groups yang tersedia
	var groups = parser.get_available_groups()
	
	if groups.is_empty():
		_update_status("Tidak ada grup ditemukan (mode data flat)")
		chapter_filter_container.visible = false
		return
	
	# Populate filter
	chapter_filter_container.visible = true
	Group_Manager.populate(groups)
	
	var group_label = CSVConfig.get_group_label(current_csv_type)
	var status_msg = "Ditemukan %d %s. Klik untuk memilih/membatalkan." % [groups.size(), group_label]
	_update_status(status_msg)

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
	
	_update_status("Mendeteksi tipe CSV...")
	current_csv_type = CSVConfig.detect_type(csv_path)
	
	# Cegah proses jika tipe UNKNOWN
	if current_csv_type == CSVConfig.CSVType.UNKNOWN:
		_update_status("Error: Format CSV tidak dikenali")
		var detailed_error = CSVConfig.get_detection_error(csv_path)
		_show_error_report([detailed_error])
		return
	
	CSVConfig.configure_all(parser, json_generator, current_csv_type)
	_update_status("Memproses CSV...")
	
	# Parse dalam mode FULL_VALIDATION
	parser.set_parse_mode(CSVParser.ParseMode.FULL_VALIDATION)
	if not parser.parse_csv_from_path(csv_path):
		_update_status("Error: Gagal memproses file CSV")
		if not parser.parsing_errors.is_empty():
			_show_error_report(parser.get_error_messages())
		return
	
	# Get data
	var data_to_export = _get_export_data()
	if data_to_export.is_empty():
		_update_status("Error: Tidak ada data untuk diekspor.")
		return
	
	# Generate JSON
	_update_status("Membuat JSON...")
	_apply_root_name()
	
	var fatal_array_issue: bool = parser.has_fatal_warnings()
	var json_string: String = ""
	if fatal_array_issue:
		json_string = json_generator.generate_json_string(data_to_export)
	else:
		json_string = json_generator.generate_json_to_path(data_to_export, output_path)
	
	if json_string.is_empty():
		_update_status("Error: Gagal membuat JSON")
		return
	
	var group_label = CSVConfig.get_group_label(current_csv_type)
	var status_msg = "Berhasil! Mengekspor %d %s ke: %s" % [data_to_export.size(), group_label, output_path]
	
	# Tampilkan warning jika ada dan hubungkan ke scene change
	if parser.has_conversion_errors():
		status_msg = "Selesai dengan peringatan! %d %s diproses" % [data_to_export.size(), group_label]
		if fatal_array_issue:
			status_msg = "Peringatan fatal: array wajib 5 elemen. File belum disimpan. Buka editor untuk perbaiki lalu Save." 
		_update_status(status_msg)
		_show_error_report_with_navigation(parser.get_error_messages(), output_path, parser.get_warning_row_ids(), parser.get_warning_details(), json_string if fatal_array_issue else "", fatal_array_issue)
	else:
		_update_status(status_msg)

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



func _update_status(message: String) -> void:
	status_label.text = "Status: " + message

## Menampilkan popup laporan kesalahan (tanpa navigasi)
func _show_error_report(errors: Array) -> void:
	var error_text = "Ditemukan %d Error :\n\n" % errors.size()
	for i in range(errors.size()):
		error_text += "%d. %s\n\n" % [i + 1, errors[i]]
	
	error_text_edit.text = error_text
	# Disconnect any previous connections to prevent navigation
	if error_dialog.confirmed.is_connected(_on_error_dialog_confirmed):
		error_dialog.confirmed.disconnect(_on_error_dialog_confirmed)
	if error_dialog.canceled.is_connected(_on_error_dialog_confirmed):
		error_dialog.canceled.disconnect(_on_error_dialog_confirmed)
	error_dialog.popup_centered()

## Menampilkan popup laporan kesalahan dengan navigasi ke JSON Viewer
func _show_error_report_with_navigation(errors: Array, json_path: String, warning_ids: Array[String], warning_details: Array[Dictionary] = [], json_text: String = "", prevent_auto_save: bool = false) -> void:
	print("[Main] _show_error_report_with_navigation called")
	print("[Main] json_path: ", json_path)
	print("[Main] warning_ids: ", warning_ids)
	print("[Main] warning_details: ", warning_details)
	print("[Main] prevent_auto_save: ", prevent_auto_save)
	
	var error_text = "Ditemukan %d Warning/Error :\n\n" % errors.size()
	for i in range(errors.size()):
		error_text += "%d. %s\n\n" % [i + 1, errors[i]]
	if prevent_auto_save:
		error_text += "Catatan: File belum disimpan otomatis karena warning fatal array (wajib 5 elemen)."
	error_text_edit.text = error_text
	
	# Simpan data ke GlobalData autoload (akan persist antar scene)
	# Gunakan warning_details jika tersedia, jika tidak gunakan warning_ids saja
	if warning_details.size() > 0:
		GlobalData.set_pending_data_with_details(json_path, warning_details, json_text, prevent_auto_save)
	else:
		GlobalData.set_pending_data(json_path, warning_ids, json_text, prevent_auto_save)
	
	# Connect signal untuk navigasi (pastikan hanya terkoneksi sekali)
	if not error_dialog.confirmed.is_connected(_on_error_dialog_confirmed):
		error_dialog.confirmed.connect(_on_error_dialog_confirmed)
	if not error_dialog.canceled.is_connected(_on_error_dialog_confirmed):
		error_dialog.canceled.connect(_on_error_dialog_confirmed)
	
	error_dialog.popup_centered()

## Handler untuk dialog confirmed/canceled - navigasi ke JSON Viewer
func _on_error_dialog_confirmed() -> void:
	print("[Main] _on_error_dialog_confirmed called - navigating to JsonUI")
	
	# Disconnect signals setelah digunakan
	if error_dialog.confirmed.is_connected(_on_error_dialog_confirmed):
		error_dialog.confirmed.disconnect(_on_error_dialog_confirmed)
	if error_dialog.canceled.is_connected(_on_error_dialog_confirmed):
		error_dialog.canceled.disconnect(_on_error_dialog_confirmed)
	
	# Pindah ke JSON Viewer scene
	get_tree().change_scene_to_file("res://UI/JSON UI/Json UI.tscn")

func _on_open_json_viewer_pressed() -> void:
	get_tree().change_scene_to_file("res://UI/JSON UI/Json UI.tscn")
