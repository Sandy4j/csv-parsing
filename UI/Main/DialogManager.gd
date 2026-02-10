class_name DialogManager
extends RefCounted

## Mengelola error dialog dan merge confirmation dialog

signal merge_confirmed
signal merge_canceled
signal navigate_to_json_viewer

var _error_dialog: AcceptDialog
var _error_text_edit: TextEdit
var _merge_confirmation_dialog: ConfirmationDialog
var _parent: Node


func _init(parent: Node) -> void:
	_parent = parent


func setup() -> void:
	_init_error_dialog()
	_init_merge_confirmation_dialog()


func _init_error_dialog() -> void:
	_error_dialog = AcceptDialog.new()
	_error_dialog.title = "Error Log"
	_error_dialog.ok_button_text = "Close"
	_error_dialog.min_size = Vector2(600, 400)
	
	_error_text_edit = TextEdit.new()
	_error_text_edit.editable = false
	_error_text_edit.custom_minimum_size = Vector2(580, 350)
	_error_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	
	_error_dialog.add_child(_error_text_edit)
	_parent.add_child(_error_dialog)


func _init_merge_confirmation_dialog() -> void:
	_merge_confirmation_dialog = ConfirmationDialog.new()
	_merge_confirmation_dialog.title = "Konfirmasi Batch Parsing"
	_merge_confirmation_dialog.dialog_text = "Apakah file CSV dengan type INGREDIENT, RECIPE, BEVERAGE, atau DECORATION sudah dalam 1 folder?"
	_merge_confirmation_dialog.ok_button_text = "Ya"
	_merge_confirmation_dialog.cancel_button_text = "Tidak"
	_merge_confirmation_dialog.confirmed.connect(_on_merge_confirmed)
	_merge_confirmation_dialog.canceled.connect(_on_merge_canceled)
	_parent.add_child(_merge_confirmation_dialog)


func _on_merge_confirmed() -> void:
	merge_confirmed.emit()


func _on_merge_canceled() -> void:
	merge_canceled.emit()


## Menampilkan popup laporan kesalahan (tanpa navigasi)
func show_error_report(errors: Array) -> void:
	var error_text = "Ditemukan %d Error :\n\n" % errors.size()
	for i in range(errors.size()):
		error_text += "%d. %s\n\n" % [i + 1, errors[i]]
	
	_error_text_edit.text = error_text
	# Disconnect any previous connections to prevent navigation
	_disconnect_navigation_signals()
	_error_dialog.popup_centered()


## Menampilkan popup laporan kesalahan dengan navigasi ke JSON Viewer
func show_error_report_with_navigation(errors: Array, json_path: String, warning_ids: Array[String], warning_details: Array[Dictionary] = [], json_text: String = "", prevent_auto_save: bool = false) -> void:
	print("[DialogManager] show_error_report_with_navigation called")
	print("[DialogManager] json_path: ", json_path)
	print("[DialogManager] warning_ids: ", warning_ids)
	print("[DialogManager] warning_details: ", warning_details)
	print("[DialogManager] prevent_auto_save: ", prevent_auto_save)
	
	var error_text = "Ditemukan %d Warning/Error :\n\n" % errors.size()
	for i in range(errors.size()):
		error_text += "%d. %s\n\n" % [i + 1, errors[i]]
	if prevent_auto_save:
		error_text += "Catatan: File belum disimpan otomatis karena warning fatal array (wajib 5 elemen)."
	_error_text_edit.text = error_text
	
	# Simpan data ke GlobalData autoload
	if warning_details.size() > 0:
		GlobalData.set_pending_data_with_details(json_path, warning_details, json_text, prevent_auto_save)
	else:
		GlobalData.set_pending_data(json_path, warning_ids, json_text, prevent_auto_save)
	
	# Connect signal untuk navigasi (pastikan hanya terkoneksi sekali)
	if not _error_dialog.confirmed.is_connected(_on_error_dialog_navigate):
		_error_dialog.confirmed.connect(_on_error_dialog_navigate)
	if not _error_dialog.canceled.is_connected(_on_error_dialog_navigate):
		_error_dialog.canceled.connect(_on_error_dialog_navigate)
	
	_error_dialog.popup_centered()


func _on_error_dialog_navigate() -> void:
	print("[DialogManager] _on_error_dialog_navigate called - emitting navigate signal")
	_disconnect_navigation_signals()
	navigate_to_json_viewer.emit()


func _disconnect_navigation_signals() -> void:
	if _error_dialog.confirmed.is_connected(_on_error_dialog_navigate):
		_error_dialog.confirmed.disconnect(_on_error_dialog_navigate)
	if _error_dialog.canceled.is_connected(_on_error_dialog_navigate):
		_error_dialog.canceled.disconnect(_on_error_dialog_navigate)


func show_merge_confirmation() -> void:
	_merge_confirmation_dialog.popup_centered()
