extends Control

## Main UI Controller - Mengelola interaksi utama antara UI dan pemrosesan CSV ke JSON

# Referensi UI
@onready var file_path_edit: LineEdit = %FilePathEdit
@onready var output_path_edit: LineEdit = %OutputPathEdit
@onready var output_browse_button: Button = %OutputBrowseButton
@onready var root_name_edit: LineEdit = %RootNameEdit
@onready var generate_button: Button = %GenerateButton
@onready var status_label: Label = %StatusLabel
@onready var file_dialog: FileDialog = %FileDialog
@onready var output_file_dialog: FileDialog = %OutputFileDialog

@onready var chapter_scroll_container: ScrollContainer = %ChapterScrollContainer
@onready var chapter_checkbox_container: VBoxContainer = %ChapterCheckboxContainer
@onready var select_all_button: Button = %SelectAllButton
@onready var deselect_all_button: Button = %DeselectAllButton
@onready var chapter_filter_container: VBoxContainer = %ChapterFilterContainer
@onready var open_json_viewer_button: Button = %OpenJsonViewerButton
@onready var patron_selection_container: VBoxContainer = %PatronSelectionContainer
@onready var patron_checkbox_container: VBoxContainer = %PatronCheckboxContainer
@onready var patrons_button: Button = %PatronsButton
@onready var dialog_button: Button = %DialogButton
@onready var items_button: Button = %ItemsButton
@onready var audio_button: Button = %AudioButton
@onready var npc_properties_button: Button = %NPCPropertiesButton
@onready var game_settings_button: Button = %GameSettingsButton
@onready var output_section: HBoxContainer = $Panel/VBoxContainer/OutputSection
@onready var root_name_section: HBoxContainer = $Panel/VBoxContainer/RootNameSection
@onready var buttons_container: HBoxContainer = $Panel/VBoxContainer/ButtonsContainer

enum FileType { NONE, PATRONS, DIALOG, ITEMS, AUDIO, NPC_PROPERTIES, SETTINGS }
var selected_file_type: FileType = FileType.NONE

const CSVParserScript = preload("res://Data/Parser.gd")
const JSONGeneratorScript = preload("res://Data/Json_generate.gd")
const PatronsManagerScript = preload("res://Data/PatronManager/PatronsManager.gd")
const PatronDataLoaderScript = preload("res://Data/PatronManager/PatronDataLoader.gd")

# Core components
var parser: Node
var json_generator: Node
var patron_loader: Node
var Group_Manager: GroupManager
var Patron_Manager: RefCounted
var current_csv_type: CSVConfig.CSVType = CSVConfig.CSVType.UNKNOWN
var dialog_manager: DialogManager
var ui_state_manager: UIStateManager
var csv_processor: CSVProcessor


func _ready() -> void:
	_init_components()
	_init_managers()
	_connect_signals()
	_connect_file_type_buttons()
	ui_state_manager.show_type_selection_required()
	_hide_all_sections()


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


func _init_managers() -> void:
	ui_state_manager = UIStateManager.new(status_label)
	dialog_manager = DialogManager.new(self)
	dialog_manager.setup()
	dialog_manager.merge_confirmed.connect(_on_merge_confirmed)
	dialog_manager.merge_canceled.connect(_on_merge_canceled)
	dialog_manager.navigate_to_json_viewer.connect(_on_navigate_to_json_viewer)
	csv_processor = CSVProcessor.new(parser, json_generator, patron_loader, self)
	csv_processor.processing_started.connect(_on_processing_started)
	csv_processor.processing_completed.connect(_on_processing_completed)
	csv_processor.processing_error.connect(_on_processing_error)
	csv_processor.processing_warning.connect(_on_processing_warning)


func _connect_signals() -> void:
	output_browse_button.pressed.connect(_on_output_browse_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	output_file_dialog.file_selected.connect(_on_output_file_selected)
	generate_button.pressed.connect(_on_generate_pressed)
	open_json_viewer_button.pressed.connect(_on_open_json_viewer_pressed)
	select_all_button.pressed.connect(Group_Manager.select_all)
	deselect_all_button.pressed.connect(Group_Manager.deselect_all)


func _connect_file_type_buttons() -> void:
	patrons_button.pressed.connect(_on_file_type_pressed.bind(FileType.PATRONS))
	dialog_button.pressed.connect(_on_file_type_pressed.bind(FileType.DIALOG))
	items_button.pressed.connect(_on_file_type_pressed.bind(FileType.ITEMS))
	audio_button.pressed.connect(_on_file_type_pressed.bind(FileType.AUDIO))
	npc_properties_button.pressed.connect(_on_file_type_pressed.bind(FileType.NPC_PROPERTIES))
	game_settings_button.pressed.connect(_on_file_type_pressed.bind(FileType.SETTINGS))


func _on_file_type_pressed(file_type: FileType) -> void:
	patrons_button.button_pressed = (file_type == FileType.PATRONS)
	dialog_button.button_pressed = (file_type == FileType.DIALOG)
	items_button.button_pressed = (file_type == FileType.ITEMS)
	audio_button.button_pressed = (file_type == FileType.AUDIO)
	npc_properties_button.button_pressed = (file_type == FileType.NPC_PROPERTIES)
	game_settings_button.button_pressed = (file_type == FileType.SETTINGS)
	
	selected_file_type = file_type
	_reset_file_selection()
	_hide_all_sections()
	file_dialog.title = "Select %s CSV File" % _get_file_type_name(file_type)
	file_dialog.popup_centered()


func _hide_all_sections() -> void:
	output_section.visible = false
	root_name_section.visible = false
	buttons_container.visible = false
	chapter_filter_container.visible = false
	patron_selection_container.visible = false


func _update_sections_visibility() -> void:
	_hide_all_sections()
	
	match selected_file_type:
		FileType.PATRONS:
			output_section.visible = true
			buttons_container.visible = true
		FileType.DIALOG:
			output_section.visible = true
			root_name_section.visible = true
			buttons_container.visible = true
		FileType.ITEMS:
			output_section.visible = true
			buttons_container.visible = true
		FileType.AUDIO:
			output_section.visible = true
			buttons_container.visible = true
		FileType.NPC_PROPERTIES:
			output_section.visible = true
			buttons_container.visible = true
		FileType.SETTINGS:
			output_section.visible = true
			buttons_container.visible = true


func _reset_file_selection() -> void:
	file_path_edit.text = ""
	output_path_edit.text = ""
	root_name_edit.text = ""
	_reset_chapter_filter()
	Patron_Manager.clear()
	current_csv_type = CSVConfig.CSVType.UNKNOWN


func _get_file_type_name(file_type: FileType) -> String:
	match file_type:
		FileType.PATRONS:
			return "Patrons"
		FileType.DIALOG:
			return "Dialog"
		FileType.ITEMS:
			return "Items"
		FileType.AUDIO:
			return "Audio"
		FileType.NPC_PROPERTIES:
			return "NPC Properties"
		FileType.SETTINGS:
			return "Game Settings"
	return "Unknown"


# Signal Callbacks dari Managers
func _on_processing_started(message: String) -> void:
	ui_state_manager.update_status(message)


func _on_processing_completed(success: bool, message: String) -> void:
	if success:
		ui_state_manager.show_success(message)
	else:
		ui_state_manager.show_error(message)


func _on_processing_error(errors: Array) -> void:
	if errors.size() > 0:
		ui_state_manager.show_error(str(errors[0]))
	call_deferred("_show_error_report_deferred", errors)


func _show_error_report_deferred(errors: Array) -> void:
	dialog_manager.show_error_report(errors)


func _on_processing_warning(errors: Array, json_path: String, warning_ids: Array[String], warning_details: Array[Dictionary], json_text: String, prevent_auto_save: bool) -> void:
	dialog_manager.show_error_report_with_navigation(errors, json_path, warning_ids, warning_details, json_text, prevent_auto_save)


func _on_merge_confirmed() -> void:
	var csv_path = file_path_edit.text.strip_edges()
	var output_path = output_path_edit.text.strip_edges()
	csv_processor.process_batch_merge(csv_path, output_path)


func _on_merge_canceled() -> void:
	ui_state_manager.show_merge_canceled()


func _on_navigate_to_json_viewer() -> void:
	get_tree().change_scene_to_file("res://UI/JSON UI/Json UI.tscn")



#Patron Callbacks
func _on_patron_selected_callback(patron_name: String) -> void:
	ui_state_manager.show_patron_selected(patron_name)
	print("[Main] Selected patron saved to GlobalData: ", GlobalData.selected_patron)
	
	var csv_path = file_path_edit.text.strip_edges()
	if not csv_path.is_empty():
		var dir = csv_path.get_base_dir()
		var result = patron_loader.load_patron_data(dir, patron_name)
		if result.get("success", false):
			print("[Main] Mapped data for ", patron_name, ": ", result.get("data", {}).keys())
		else:
			var errors: Array = result.get("errors", [])
			if errors.size() > 0:
				call_deferred("_show_error_report_deferred", errors)


#UI Event Handlers
func _on_output_browse_pressed() -> void:
	output_file_dialog.popup_centered()


func _on_file_selected(path: String) -> void:
	file_dialog.hide()
	
	await get_tree().process_frame
	
	var validation = _validate_file_for_type(path)
	if not validation.get("valid", false):
		ui_state_manager.show_error(validation.get("message", "File tidak valid"))
		if validation.has("errors"):
			var errors: Array = validation.get("errors", [])
			if errors.size() > 0:
				dialog_manager.show_error_report(errors)
		
		_deselect_all_type_buttons()
		selected_file_type = FileType.NONE
		return
	
	file_path_edit.text = path
	file_path_edit.visible = true
	
	_update_sections_visibility()
	
	match selected_file_type:
		FileType.PATRONS:
			_handle_patron_file_selected(path)
		FileType.NPC_PROPERTIES:
			current_csv_type = CSVConfig.CSVType.NPC_PROPERTIES
			ui_state_manager.show_file_type_selected("NPC Properties")
		_:
			_update_chapter_filter(path)
	
	var type_name = _get_file_type_name(selected_file_type)
	if not output_path_edit.text.is_empty():
		return
	
	var dir = path.get_base_dir()
	var filename = path.get_file().get_basename()
	var default_output = dir.path_join(filename + ".json")
	output_path_edit.text = default_output
	
	
func _update_chapter_filter(csv_path: String) -> void:
	current_csv_type = CSVConfig.detect_type(csv_path)
	
	if current_csv_type == CSVConfig.CSVType.UNKNOWN:
		ui_state_manager.show_error("Format CSV tidak dikenali")
		var detailed_error = CSVConfig.get_detection_error(csv_path)
		dialog_manager.show_error_report([detailed_error])
		return
	
	CSVConfig.configure_all(parser, json_generator, current_csv_type)
	var type_name = CSVConfig.get_type_name(current_csv_type)
	
	parser.set_parse_mode(CSVParser.ParseMode.STRUCTURE_ONLY)
	if not parser.parse_csv_from_path(csv_path):
		ui_state_manager.show_error("Gagal memproses file CSV")
		var structural_errors: Array[String] = []
		for err in parser.parsing_errors:
			if err is String:
				structural_errors.append(err)
		if not structural_errors.is_empty():
			dialog_manager.show_error_report(structural_errors)
		return
	
	var groups = parser.get_available_groups()
	
	if groups.is_empty():
		ui_state_manager.show_file_type_selected(type_name)
		chapter_filter_container.visible = false
	else:
		chapter_filter_container.visible = true
		Group_Manager.populate(groups)
		var group_label = CSVConfig.get_group_label(current_csv_type)
		ui_state_manager.show_groups_found(groups.size(), group_label)


func _validate_file_for_type(path: String) -> Dictionary:
	var detected_type = CSVConfig.detect_type(path)
	
	match selected_file_type:
		FileType.PATRONS:
			# Untuk Patrons, validasi folder berisi file-file patron
			var dir = path.get_base_dir()
			var result = patron_loader.validate_files_only(dir)
			if result.get("success", false):
				return { "valid": true }
			else:
				var errors: Array = result.get("errors", [])
				if errors.size() > 0:
					return { "valid": false, "message": "File tidak sesuai format Patrons", "errors": errors }
				return { "valid": false, "message": "File tidak sesuai format Patrons" }
		
		FileType.DIALOG:
			if detected_type == CSVConfig.CSVType.DIALOG:
				return { "valid": true }
			return { "valid": false, "message": "File tidak sesuai format Dialog. Pastikan ada kolom 'lineid' dan 'text'." }
		
		FileType.ITEMS:
			if _is_item_type(detected_type):
				return { "valid": true }
			return { "valid": false, "message": "File tidak sesuai format Items (Ingredient/Recipe/Beverage/Decoration)" }
		
		FileType.AUDIO:
			if detected_type == CSVConfig.CSVType.AUDIO:
				return { "valid": true }
			return { "valid": false, "message": "File tidak sesuai format Audio" }
		
		FileType.NPC_PROPERTIES:
			if detected_type == CSVConfig.CSVType.NPC_PROPERTIES:
				return { "valid": true }
			# Juga cek apakah folder berisi Colors.csv atau NPC file
			var dir = path.get_base_dir()
			if _is_npc_properties_folder(dir):
				return { "valid": true }
			return { "valid": false, "message": "File tidak sesuai format NPC Properties" }
		
		FileType.SETTINGS:
			if detected_type == CSVConfig.CSVType.GAME_SETTINGS:
				return { "valid": true }
			return { "valid": false, "message": "File tidak sesuai format Game Settings. Pastikan ada kolom 'settings_name' dan 'default_value'." }
	
	return { "valid": false, "message": "Tipe file tidak dikenali" }


func _is_npc_properties_folder(dir: String) -> bool:
	var dir_access = DirAccess.open(dir)
	if dir_access == null:
		return false
	
	dir_access.list_dir_begin()
	var file_name = dir_access.get_next()
	while file_name != "":
		var lower_name = file_name.to_lower()
		if lower_name.ends_with(".csv"):
			if lower_name.find("colors") >= 0 or lower_name.find("npc") >= 0:
				dir_access.list_dir_end()
				return true
		file_name = dir_access.get_next()
	dir_access.list_dir_end()
	return false


func _deselect_all_type_buttons() -> void:
	patrons_button.button_pressed = false
	dialog_button.button_pressed = false
	items_button.button_pressed = false
	audio_button.button_pressed = false
	npc_properties_button.button_pressed = false
	game_settings_button.button_pressed = false


func _handle_patron_file_selected(path: String) -> void:
	var patrons_file_path: String = patron_loader.get_detected_file_path("PATRONS")
	if not patrons_file_path.is_empty():
		_load_patrons(patrons_file_path)
		patron_selection_container.visible = true
		ui_state_manager.show_csv_selected_with_patrons()
	else:
		ui_state_manager.show_file_type_selected("Patrons")
			
func _on_output_file_selected(path: String) -> void:
	if not path.ends_with(".json"):
		path += ".json"
	output_path_edit.text = path




func _on_filter_selection_changed(selected: Array) -> void:
	var total = Group_Manager.get_total_count()
	var count = Group_Manager.get_selected_count()
	var group_label = CSVConfig.get_group_label(current_csv_type)
	ui_state_manager.show_selection_changed(count, total, group_label)


func _on_generate_pressed() -> void:
	var csv_path = file_path_edit.text.strip_edges()
	var output_path = output_path_edit.text.strip_edges()
	
	if not _validate_paths(csv_path, output_path):
		return
	
	if not output_path.ends_with(".json"):
		output_path += ".json"
	
	# Use selected file type to determine CSV type
	match selected_file_type:
		FileType.PATRONS:
			current_csv_type = CSVConfig.CSVType.PATRON
			csv_processor.process_patron_csv(csv_path, output_path)
			return
		FileType.DIALOG:
			current_csv_type = CSVConfig.CSVType.DIALOG
		FileType.ITEMS:
			# Auto-detect item sub-type (ingredient, recipe, beverage, decoration)
			current_csv_type = CSVConfig.detect_type(csv_path)
			if not _is_item_type(current_csv_type):
				ui_state_manager.show_error("File CSV tidak sesuai dengan tipe Items")
				return
		FileType.AUDIO:
			current_csv_type = CSVConfig.CSVType.AUDIO
		FileType.NPC_PROPERTIES:
			current_csv_type = CSVConfig.CSVType.NPC_PROPERTIES
			csv_processor.process_npc_properties_csv(csv_path, output_path)
			return
		FileType.SETTINGS:
			current_csv_type = CSVConfig.CSVType.GAME_SETTINGS
		_:
			ui_state_manager.show_error("Pilih tipe file terlebih dahulu")
			return
	
	# Cek apakah tipe membutuhkan konfirmasi merge
	if csv_processor.should_confirm_merge(current_csv_type):
		dialog_manager.show_merge_confirmation()
	else:
		var selected_groups = Group_Manager.get_selected()
		var root_name = root_name_edit.text.strip_edges()
		csv_processor.process_single_csv(csv_path, output_path, current_csv_type, selected_groups, root_name)


func _is_item_type(csv_type: CSVConfig.CSVType) -> bool:
	return csv_type in [
		CSVConfig.CSVType.INGREDIENT,
		CSVConfig.CSVType.RECIPE,
		CSVConfig.CSVType.BEVERAGE,
		CSVConfig.CSVType.DECORATION,
		CSVConfig.CSVType.KEY_ITEM
	]


func _on_open_json_viewer_pressed() -> void:
	get_tree().change_scene_to_file("res://UI/JSON UI/Json UI.tscn")



#Helper Functions
func _validate_paths(csv_path: String, output_path: String) -> bool:
	if csv_path.is_empty():
		ui_state_manager.show_error("Please select a CSV file")
		return false
	
	if output_path.is_empty():
		ui_state_manager.show_error("Please select output JSON location")
		return false
	
	return true


func _reset_chapter_filter() -> void:
	Group_Manager.clear()
	chapter_filter_container.visible = false



func _load_patrons(path: String) -> void:
	var rows = PatronParser.parse_patron_csv(path)
	if rows.is_empty():
		var filename = path.get_file()
		ui_state_manager.show_error("Gagal membuka file " + filename)
		return
	
	var patron_config = DataSchemas.get_patron_files_config()
	var target_header: String = patron_config["PATRONS"]["char_header"]
	
	var patron_names = []
	var headers = rows[0]
	var name_idx = -1
	
	for i in range(headers.size()):
		if str(headers[i]).strip_edges().to_lower() == target_header.to_lower():
			name_idx = i
			break
	
	if name_idx == -1:
		ui_state_manager.show_error("Kolom '%s' tidak ditemukan di %s" % [target_header, patron_config["PATRONS"]["filename"]])
		patron_selection_container.visible = false
		return
	
	for i in range(1, rows.size()):
		var row = rows[i]
		if row.size() > name_idx:
			var character_name = str(row[name_idx]).strip_edges()
			if not character_name.is_empty():
				patron_names.append(character_name)
	
	if patron_names.is_empty():
		ui_state_manager.show_no_patrons()
		patron_selection_container.visible = false
	else:
		ui_state_manager.show_patrons_loaded(patron_names.size())
		patron_selection_container.visible = true
		Patron_Manager.populate(patron_names)
