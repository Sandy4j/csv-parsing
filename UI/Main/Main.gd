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
@onready var patron_selection_container: VBoxContainer = %PatronSelectionContainer
@onready var patron_checkbox_container: VBoxContainer = %PatronCheckboxContainer

# Preload scripts
const CSVParserScript = preload("res://Data/Parser.gd")
const JSONGeneratorScript = preload("res://Data/Json_generate.gd")
const MergeSystemScript = preload("res://UI/MergeSystem.gd")
const PatronsManagerScript = preload("res://Data/PatronManager/PatronsManager.gd")
const PatronDataLoaderScript = preload("res://Data/PatronManager/PatronDataLoader.gd")

# Core components
var parser: Node
var json_generator: Node
var patron_loader: Node
var Group_Manager: GroupManager
var Patron_Manager: RefCounted
var current_csv_type: CSVConfig.CSVType = CSVConfig.CSVType.UNKNOWN

var error_dialog: AcceptDialog
var error_text_edit: TextEdit
var merge_confirmation_dialog: ConfirmationDialog


func _ready() -> void:
	_init_components()
	_init_error_dialog()
	_init_merge_confirmation_dialog()
	_connect_signals()
	_update_status("Ready - Select CSV file and output location")
	chapter_filter_container.visible = false

func _init_components() -> void:
	parser = CSVParserScript.new()
	json_generator = JSONGeneratorScript.new()
	patron_loader = PatronDataLoaderScript.new()
	add_child(parser)
	add_child(json_generator)
	add_child(patron_loader)
	Group_Manager = GroupManager.new(chapter_checkbox_container)
	Group_Manager.selection_changed.connect(_on_filter_selection_changed)
	Patron_Manager = PatronsManagerScript.new(patron_checkbox_container)
	Patron_Manager.patron_selected.connect(_on_patron_selected_callback)

func _on_patron_selected_callback(patron_name: String) -> void:
	_update_status("Patron terpilih: " + patron_name)
	print("[Main] Selected patron saved to GlobalData: ", GlobalData.selected_patron)
	
	# Load all related data for the selected patron
	var csv_path = file_path_edit.text.strip_edges()
	if not csv_path.is_empty():
		var dir = csv_path.get_base_dir()
		var result = patron_loader.load_patron_data(dir, patron_name)
		if result.get("success", false):
			print("[Main] Mapped data for ", patron_name, ": ", result.get("data", {}).keys())
		else:
			var errors: Array = result.get("errors", [])
			if errors.size() > 0:
				# Use call_deferred to prevent exclusive window conflict
				call_deferred("_show_error_report", errors)

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

func _init_merge_confirmation_dialog() -> void:
	merge_confirmation_dialog = ConfirmationDialog.new()
	merge_confirmation_dialog.title = "Konfirmasi Batch Parsing"
	merge_confirmation_dialog.dialog_text = "Apakah file CSV dengan type INGREDIENT, RECIPE, BEVERAGE, atau DECORATION sudah dalam 1 folder?"
	merge_confirmation_dialog.ok_button_text = "Ya"
	merge_confirmation_dialog.cancel_button_text = "Tidak"
	merge_confirmation_dialog.confirmed.connect(_on_merge_confirmed)
	merge_confirmation_dialog.canceled.connect(_on_merge_canceled)
	add_child(merge_confirmation_dialog)

func _on_merge_confirmed() -> void:
	var csv_path = file_path_edit.text.strip_edges()
	var output_path = output_path_edit.text.strip_edges()
	_process_batch_merge(csv_path, output_path)

func _on_merge_canceled() -> void:
	_update_status("Parsing dibatalkan oleh pengguna.")

func _should_confirm_merge(type: CSVConfig.CSVType) -> bool:
	match type:
		CSVConfig.CSVType.INGREDIENT, \
		CSVConfig.CSVType.RECIPE, \
		CSVConfig.CSVType.BEVERAGE, \
		CSVConfig.CSVType.DECORATION:
			return true
	return false

func _process_single_csv(csv_path: String, output_path: String) -> void:
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

func _process_batch_merge(base_csv_path: String, final_output_path: String) -> void:
	var folder_path = base_csv_path.get_base_dir()
	var dir = DirAccess.open(folder_path)
	if dir == null:
		_update_status("Error: Gagal membuka folder " + folder_path)
		return
	
	dir.list_dir_begin()
	var csv_files: Array[String] = []
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".csv"):
			csv_files.append(folder_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	
	if csv_files.is_empty():
		_update_status("Error: Tidak ada file CSV ditemukan di folder.")
		return
	
	_update_status("Memproses %d file CSV..." % csv_files.size())
	
	var temp_json_paths: Array[String] = []
	var all_errors: Array[String] = []
	var skipped_files: Array[String] = []
	var processed_types: Array[String] = []  # Untuk reporting
	var seen_types: Array[CSVConfig.CSVType] = [] # ✅ Untuk mendeteksi duplikasi tipe
	
	# ✅ Daftar tipe yang BOLEH di-merge
	var mergeable_types = [
		CSVConfig.CSVType.INGREDIENT,
		CSVConfig.CSVType.RECIPE,
		CSVConfig.CSVType.BEVERAGE,
		CSVConfig.CSVType.DECORATION
	]
	
	# Create temp directory
	var temp_dir = "user://temp_parsing/"
	if not DirAccess.dir_exists_absolute(temp_dir):
		DirAccess.make_dir_recursive_absolute(temp_dir)
	
	for csv_file in csv_files:
		var file_type = CSVConfig.detect_type(csv_file)
		
		# ✅ Skip jika UNKNOWN
		if file_type == CSVConfig.CSVType.UNKNOWN:
			skipped_files.append(csv_file.get_file() + " (tipe tidak dikenali)")
			continue
		
		# ✅ Skip jika BUKAN salah satu dari 4 tipe mergeable
		if file_type not in mergeable_types:
			var type_name = CSVConfig.get_type_name(file_type)
			skipped_files.append(csv_file.get_file() + " (tipe %s tidak dapat di-merge)" % type_name)
			continue
		
		# ✅ Exception Handling: Hiraukan jika duplikasi tipe ditemukan
		if file_type in seen_types:
			var type_name = CSVConfig.get_type_name(file_type)
			skipped_files.append(csv_file.get_file() + " (duplikasi tipe %s diabaikan)" % type_name)
			continue
		
		# ✅ Tandai tipe ini sudah diproses
		seen_types.append(file_type)
		var type_name = CSVConfig.get_type_name(file_type)
		if type_name not in processed_types:
			processed_types.append(type_name)
		
		CSVConfig.configure_all(parser, json_generator, file_type)
		parser.set_parse_mode(CSVParser.ParseMode.FULL_VALIDATION)
		
		if parser.parse_csv_from_path(csv_file):
			var data = parser.get_data()
			if not data.is_empty():
				var temp_json_name = csv_file.get_file().replace(".csv", ".json")
				var temp_path = temp_dir.path_join(temp_json_name)
				
				var original_no_root = json_generator.no_root_wrapper
				
				json_generator.set_no_root_wrapper(true)
				json_generator.generate_json_to_path(data, temp_path)
				temp_json_paths.append(temp_path)
				
				json_generator.set_no_root_wrapper(original_no_root)
			
			if parser.has_conversion_errors():
				all_errors.append_array(parser.get_error_messages())
		else:
			all_errors.append("Gagal parse: " + csv_file.get_file())
	
	# ✅ Informasi file yang di-skip
	if not skipped_files.is_empty():
		var skip_msg = "File yang di-skip (%d):\n%s" % [skipped_files.size(), "\n".join(skipped_files)]
		all_errors.insert(0, skip_msg)
	
	if temp_json_paths.is_empty():
		_update_status("Error: Tidak ada file CSV yang valid untuk di-merge (hanya INGREDIENT, RECIPE, BEVERAGE, DECORATION).")
		if not all_errors.is_empty():
			_show_error_report(all_errors)
		if DirAccess.dir_exists_absolute(temp_dir):
			DirAccess.remove_absolute(temp_dir)
		return
	
	# Merge files
	_update_status("Menggabungkan %d hasil parsing..." % temp_json_paths.size())
	var merger = MergeSystemScript.new()
	add_child(merger)
	var merge_result = merger.merge_json_files(temp_json_paths, final_output_path)
	
	if merge_result.success:
		# ✅ Tampilkan tipe apa saja yang berhasil di-merge
		var types_merged = ", ".join(processed_types)
		_update_status("Berhasil menggabungkan %d file [%s] ke: %s" % [temp_json_paths.size(), types_merged, final_output_path])
		if not all_errors.is_empty():
			_show_error_report(all_errors)
	else:
		_update_status("Error saat menggabungkan: " + ", ".join(merge_result.errors))
		_show_error_report(merge_result.errors + all_errors)
	
	# Cleanup temp files
	for path in temp_json_paths:
		DirAccess.remove_absolute(path)
	
	var remove_dir_err = DirAccess.remove_absolute(temp_dir)
	if remove_dir_err != OK:
		push_warning("Gagal menghapus folder temp: " + temp_dir)
		
	merger.queue_free()

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
	file_dialog.hide()
	
	await get_tree().process_frame
	
	var dir = path.get_base_dir()
	_reset_chapter_filter()
	
	# Coba validasi file patron
	var result = patron_loader.validate_files_only(dir)
	
	if result.get("success", false):
		# Semua file patron terdeteksi berdasarkan header
		file_path_edit.text = path
		_update_status("CSV file selected. Patron list loaded.")
		var patrons_file_path: String = patron_loader.get_detected_file_path("PATRONS")
		if not patrons_file_path.is_empty():
			_load_patrons(patrons_file_path)
		else:
			_update_status("Error: File Patrons tidak terdeteksi")
			patron_selection_container.visible = false
	else:
		# Cek apakah ini file CSV non-patron atau error validasi
		var errors: Array = result.get("errors", [])
		if errors.size() > 0 and _is_patron_related_csv(path):
			file_path_edit.text = ""
			_update_status("Error: " + str(errors[0]))
			call_deferred("_show_error_report", errors)
			patron_selection_container.visible = false
		else:
			# Bukan file patron - lanjutkan sebagai file CSV biasa
			file_path_edit.text = path
			_update_status("CSV file selected. Click 'Load Chapters' to see available groups.")
			patron_selection_container.visible = false

## Cek apakah file CSV ini memiliki header yang terkait dengan patron system
func _is_patron_related_csv(path: String) -> bool:
	var rows = PatronParser.parse_patron_csv(path)
	if rows.is_empty():
		return false
	
	var headers: Array = rows[0]
	var header_line: String = ",".join(headers).to_lower()
	
	# Cek apakah ada header yang terkait patron
	var patron_keywords = ["patronid", "character_name", "storyreqs", "idletalkreqs", "set_order_name"]
	for keyword in patron_keywords:
		if header_line.find(keyword) >= 0:
			return true
	return false

func _load_patrons(path: String) -> void:
	var rows = PatronParser.parse_patron_csv(path)
	if rows.is_empty():
		var filename = path.get_file()
		_update_status("Error: Gagal membuka file " + filename)
		return
	
	var patron_config = DataSchemas.get_patron_files_config()
	var target_header: String = patron_config["PATRONS"]["char_header"]
	
	var patron_names = []
	var headers = rows[0]
	var name_idx = -1
	
	# Find character_name column index
	for i in range(headers.size()):
		if str(headers[i]).strip_edges().to_lower() == target_header.to_lower():
			name_idx = i
			break
	
	if name_idx == -1:
		_update_status("Error: Kolom '%s' tidak ditemukan di %s" % [target_header, patron_config["PATRONS"]["filename"]])
		patron_selection_container.visible = false
		return
	
	# Extract patron names from data rows
	for i in range(1, rows.size()):
		var row = rows[i]
		if row.size() > name_idx:
			var character_name = str(row[name_idx]).strip_edges()
			if not character_name.is_empty():
				patron_names.append(character_name)
			
	
	if patron_names.is_empty():
		_update_status("Tidak ada karakter patron yang ditemukan.")
		patron_selection_container.visible = false
	else:
		_update_status("Memuat %d karakter patron." % patron_names.size())
		patron_selection_container.visible = true
		Patron_Manager.populate(patron_names)

func _on_patron_selected(patron_name: String) -> void:
	# Fungsi ini dipanggil dari sinyal Patron_Manager.patron_selected
	pass
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
	
	# Handle PATRON type secara khusus
	if current_csv_type == CSVConfig.CSVType.PATRON:
		_process_patron_csv(csv_path, output_path)
		return
	
	# Cek apakah tipe membutuhkan konfirmasi merge
	if _should_confirm_merge(current_csv_type):
		merge_confirmation_dialog.popup_centered()
	else:
		_process_single_csv(csv_path, output_path)

## Validasi path input
func _validate_paths(csv_path: String, output_path: String) -> bool:
	if csv_path.is_empty():
		_update_status("Error: Please select a CSV file")
		return false
	
	if output_path.is_empty():
		_update_status("Error: Please select output JSON location")
		return false
	
	return true


## Process PATRON type CSV - menggunakan PatronDataLoader
func _process_patron_csv(csv_path: String, output_path: String) -> void:
	# Cek apakah ada patron yang dipilih
	var selected_patron: String = GlobalData.selected_patron
	if selected_patron.is_empty():
		_update_status("Error: Pilih karakter patron terlebih dahulu")
		_show_error_report(["Tidak ada karakter patron yang dipilih. Pilih karakter dari daftar patron terlebih dahulu."])
		return
	
	var dir: String = csv_path.get_base_dir()
	var output_dir: String = output_path.get_base_dir()
	
	_update_status("Memproses data patron: " + selected_patron + "...")
	
	# Gunakan process_character untuk load, generate, dan save sekaligus
	var result: Dictionary = patron_loader.process_character(dir, output_dir, selected_patron)
	
	if result.get("success", false):
		var file_path: String = result.get("file_path", "")
		var errors: Array = result.get("errors", [])
		
		if errors.size() > 0:
			# Ada warning tapi sukses
			_update_status("JSON berhasil dibuat dengan %d warning: %s" % [errors.size(), file_path])
			_show_error_report(errors)
		else:
			_update_status("JSON berhasil dibuat: " + file_path)
		
		print("[Main] Patron JSON saved to: ", file_path)
	else:
		var errors: Array = result.get("errors", [])
		if errors.size() > 0:
			_update_status("Error: " + str(errors[0]))
			_show_error_report(errors)
		else:
			_update_status("Error: Gagal memproses data patron")

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
	
	# Simpan data ke GlobalData autoload
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
