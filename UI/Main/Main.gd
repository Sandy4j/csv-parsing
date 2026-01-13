extends Control

# Referensi UI
@onready var file_path_edit: LineEdit = %FilePathEdit
@onready var browse_button: Button = %BrowseButton
@onready var output_path_edit: LineEdit = %OutputPathEdit
@onready var output_browse_button: Button = %OutputBrowseButton
@onready var generate_button: Button = %GenerateButton
@onready var status_label: Label = %StatusLabel
@onready var json_output: TextEdit = %JsonOutput
@onready var file_dialog: FileDialog = %FileDialog
@onready var output_file_dialog: FileDialog = %OutputFileDialog

# Referensi ke script Parser dan JsonGenerate
var parser: Node
var json_generator: Node

func _ready() -> void:
	parser = preload("res://Data/Parser.gd").new()
	json_generator = preload("res://Data/Json_generate.gd").new()
	add_child(parser)
	add_child(json_generator)
	
	_connect_signals()
	update_status("Ready - Select CSV file and output location")

func _connect_signals() -> void:
	browse_button.pressed.connect(_on_browse_pressed)
	output_browse_button.pressed.connect(_on_output_browse_pressed)
	generate_button.pressed.connect(_on_generate_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	output_file_dialog.file_selected.connect(_on_output_file_selected)

func _on_browse_pressed() -> void:
	file_dialog.popup_centered()

func _on_output_browse_pressed() -> void:
	output_file_dialog.popup_centered()

func _on_file_selected(path: String) -> void:
	file_path_edit.text = path

func _on_output_file_selected(path: String) -> void:
	# Pastikan path berakhiran .json
	if not path.ends_with(".json"):
		path += ".json"
	output_path_edit.text = path

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
	
	update_status("Generating JSON...")
	
	# Generate JSON menggunakan Json_generate.gd
	var json_string = json_generator.generate_json_to_path(parser.data_rows, output_path)
	if json_string.is_empty():
		update_status("Error: Failed to generate JSON")
		return
	
	# Tampilkan output JSON
	json_output.text = json_string
	update_status("Success! JSON saved to: " + output_path)

func update_status(message: String) -> void:
	status_label.text = "Status: " + message
