class_name JsonTree
extends RefCounted

## Skrip untuk mengatur Tree JSON - building, navigasi, dan format

var _tree: Tree = null
var _json_data: Variant = null
var _warning_ids: Array[String] = []  # Array untuk menyimpan ID yang perlu di-highlight (legacy)
# Warning details: Array of {"id": "1", "column": "buyPrice"} untuk highlight spesifik kolom
var _warning_details: Array[Dictionary] = []
# Tracking current row id saat building tree
var _current_row_id: String = ""

## Inisialisasi dengan Tree reference
func init(tree: Tree) -> void:
	_tree = tree

## Set data JSON
func set_data(data: Variant) -> void:
	_json_data = data

## GET data JSON
func get_data() -> Variant:
	return _json_data

## Set warning IDs untuk highlighting
func set_warning_ids(ids: Array[String]) -> void:
	_warning_ids = ids.duplicate()
	print("[JsonTree] Warning IDs set: ", _warning_ids)

## Set warning IDs dari variant array (untuk kompatibilitas)
func set_warning_ids_variant(ids: Array) -> void:
	_warning_ids.clear()
	for id in ids:
		_warning_ids.append(str(id))
	print("[JsonTree] Warning IDs set from variant: ", _warning_ids)

## Set warning details dari variant array (untuk highlight spesifik kolom)
func set_warning_details_variant(details: Array) -> void:
	_warning_details.clear()
	_warning_ids.clear()
	for detail in details:
		if detail is Dictionary:
			var id_str = str(detail.get("id", ""))
			var col_str = str(detail.get("column", ""))
			var group_str = str(detail.get("group", ""))  # Group info (bisa kosong)
			_warning_details.append({"id": id_str, "column": col_str, "group": group_str})
			# Juga populate warning_ids untuk backward compatibility
			if not id_str.is_empty() and not _warning_ids.has(id_str):
				_warning_ids.append(id_str)
	print("[JsonTree] Warning details set from variant: ", _warning_details)

## Clear warning IDs
func clear_warning_ids() -> void:
	_warning_ids.clear()
	_warning_details.clear()
	_current_row_id = ""

## GET warning IDs (untuk debugging)
func get_warning_ids() -> Array[String]:
	return _warning_ids

## Cek apakah kolom tertentu pada ID tertentu ada dalam warning
## group_name: optional, untuk membedakan item dengan ID sama di group berbeda
func _is_warning_column(row_id: String, column_name: String, group_name: String = "") -> bool:
	if _warning_details.is_empty():
		return false

	for detail in _warning_details:
		var detail_id = detail.get("id", "")
		var detail_col = detail.get("column", "")
		var detail_group = detail.get("group", "")
		
		# Match ID dan column
		if detail_id == row_id and detail_col == column_name:
			# Jika warning detail punya group, harus match group juga
			if not detail_group.is_empty():
				if group_name.is_empty() or detail_group == group_name:
					return true
			else:
				# Warning detail tanpa group (legacy), selalu match
				return true
	return false

## Cek apakah row_id memiliki warning (untuk highlight parent)
## group_name: optional, untuk membedakan item dengan ID sama di group berbeda
func _row_has_any_warning(row_id: String, group_name: String = "") -> bool:
	if _warning_details.is_empty():
		return _warning_ids.has(row_id)

	for detail in _warning_details:
		var detail_id = detail.get("id", "")
		var detail_group = detail.get("group", "")
		
		if detail_id == row_id:
			# Jika warning detail punya group, harus match group juga
			if not detail_group.is_empty():
				if group_name.is_empty() or detail_group == group_name:
					return true
			else:
				# Warning detail tanpa group (legacy), selalu match
				return true
	return false

## Cek apakah ID ada dalam warning list
func _is_warning_id(id: String) -> bool:
	if _warning_ids.is_empty():
		return false
	return _warning_ids.has(id)

## Cek apakah data memiliki ID yang ada dalam warning list
func _check_data_for_warning_id(data: Variant) -> bool:
	if _warning_ids.is_empty():
		return false
	
	if data is Dictionary:
		# Cek apakah dictionary memiliki field "id" yang ada di warning list
		if data.has("id"):
			var id_value = _normalize_id(data["id"])
			print("[JsonTree] Checking 'id' field, value: '", id_value, "', warning_ids: ", _warning_ids, ", has: ", _warning_ids.has(id_value))
			if _warning_ids.has(id_value):
				print("[JsonTree] MATCH FOUND - id: ", id_value)
				return true
		# Cek juga field "lineid" untuk format dialog
		if data.has("lineid"):
			var lineid_value = _normalize_id(data["lineid"])
			print("[JsonTree] Checking 'lineid' field, value: '", lineid_value, "', has: ", _warning_ids.has(lineid_value))
			if _warning_ids.has(lineid_value):
				print("[JsonTree] MATCH FOUND - lineid: ", lineid_value)
				return true
		# Cek field "ID" (uppercase)
		if data.has("ID"):
			var id_value = _normalize_id(data["ID"])
			if _warning_ids.has(id_value):
				print("[JsonTree] MATCH FOUND - ID: ", id_value)
				return true
	return false

## Normalize ID ke string (handle float -> int conversion)
func _normalize_id(value: Variant) -> String:
	if value is float:
		# Jika float adalah bilangan bulat (1.0, 2.0), convert ke int string
		if value == floor(value):
			return str(int(value))
		else:
			return str(value)
	elif value is int:
		return str(value)
	else:
		return str(value)

## Buat tree dari data yang diberikan
func build_tree(data: Variant, filter_text: String = "") -> void:
	if _tree == null:
		return
	
	print("[JsonTree] build_tree called - warning_ids count: ", _warning_ids.size(), " ids: ", _warning_ids)
	
	_tree.clear()
	_json_data = data
	
	var root = _tree.create_item()
	root.set_text(0, "JSON Root")
	
	# Cek apakah data adalah dictionary atau array
	if data is Dictionary:
		for key in data.keys():
			_add_tree_items(root, data[key], str(key), filter_text)
	elif data is Array:
		for i in range(data.size()):
			_add_tree_items(root, data[i], "[%d]" % i, filter_text)
	else:
		_add_tree_items(root, data, "value", filter_text)
	
	# Expand root secara default
	root.set_collapsed(false)
	
	# Post-process: expand semua parent dari warning items
	if not _warning_ids.is_empty():
		_expand_warning_parents(root)

## Expand semua parent dari item yang memiliki warning
func _expand_warning_parents(item: TreeItem) -> bool:
	var has_warning = false
	
	# Cek apakah item ini memiliki warning
	if item.has_meta("has_warning") and item.get_meta("has_warning"):
		has_warning = true
	
	# Rekursif ke semua children
	var child = item.get_first_child()
	while child != null:
		if _expand_warning_parents(child):
			has_warning = true
		child = child.get_next()
	
	# Jika ada warning di subtree ini, expand item ini
	if has_warning and item.get_child_count() > 0:
		item.set_collapsed(false)
	
	return has_warning

## Menambahkan item baru untuk setiap item di data ke visual tree
func _add_tree_items(parent: TreeItem, data: Variant, key: String, filter_text: String = "", path: Array = [], parent_row_id: String = "", parent_group_name: String = "") -> TreeItem:
	var item = _tree.create_item(parent)
	var should_show = filter_text.is_empty()
	var current_path = path.duplicate()
	var current_row_id = parent_row_id  # Inherit parent's row_id
	var current_group_name = parent_group_name  # Inherit parent's group_name
	
	# Parse key untuk path (handle array index)
	if key.begins_with("[") and key.ends_with("]"):
		current_path.append(int(key.substr(1, key.length() - 2)))
	else:
		current_path.append(key)
	
	# Set metadata untuk tracking path
	item.set_metadata(0, current_path)
	
	# Jika node ini sendiri adalah kolom yang di-warning, highlight dulu
	var self_warning = _is_warning_column(current_row_id, key, current_group_name)
	if self_warning:
		print("[JsonTree] APPLYING RED to column '%s' in row '%s' (group: %s)" % [key, current_row_id, current_group_name])
		item.set_custom_color(0, Color.RED)
		item.set_meta("has_warning", true)
	
	# Check apakah item adalah dictionary atau array
	if data is Dictionary:
		var dict_size = data.size()
		item.set_text(0, "%s {%d}" % [key, dict_size])
		item.set_collapsed(true)
		# Jika dictionary ini berada di level root (path size == 1), set sebagai group name
		if current_path.size() == 1:
			current_group_name = key
		# Cek apakah dictionary ini adalah row data dengan ID
		if data.has("id"):
			current_row_id = _normalize_id(data["id"])
		elif data.has("lineid"):
			current_row_id = _normalize_id(data["lineid"])

		# Cek apakah row ini memiliki warning (untuk highlight parent dengan warna orange)
		var row_has_warning = _row_has_any_warning(current_row_id, current_group_name)
		if row_has_warning:
			print("[JsonTree] Row %s (group: %s) has warning - applying ORANGE to parent dict" % [current_row_id, current_group_name])
			item.set_custom_color(0, Color.ORANGE)
			item.set_meta("has_warning", true)
		
		# Rekursif untuk menambahkan item baru untuk setiap item di dictionary
		for dict_key in data.keys():
			var child_item = _add_tree_items(item, data[dict_key], str(dict_key), filter_text, current_path, current_row_id, current_group_name)
			if child_item != null:
				if not filter_text.is_empty():
					should_show = true
				# Propagate warning flag ke parent
				if child_item.has_meta("has_warning") and child_item.get_meta("has_warning"):
					item.set_meta("has_warning", true)
		
	elif data is Array:
		var arr_size = data.size()
		item.set_text(0, "%s [%d]" % [key, arr_size])
		item.set_collapsed(true)
		
		# Jika ini adalah array di level group (contoh: "Base", "Seasoning"), set current_group_name
		# Key ini adalah nama group jika parent path kosong (langsung di bawah root)
		if path.is_empty():
			current_group_name = key
		
		# Rekursif untuk menambahkan item baru untuk setiap item di array
		for i in range(data.size()):
			var child_item = _add_tree_items(item, data[i], "[%d]" % i, filter_text, current_path, current_row_id, current_group_name)
			if child_item != null:
				if not filter_text.is_empty():
					should_show = true
				# Propagate warning flag ke parent
				if child_item.has_meta("has_warning") and child_item.get_meta("has_warning"):
					item.set_meta("has_warning", true)
		
	else:
		# Item adalah nilai dasar (editable)
		var value_str = format_value(data)
		var display_text = "%s: %s" % [key, value_str]
		item.set_text(0, display_text)
		item.set_meta("is_editable", true)
		item.set_meta("value_type", JsonEditor.get_type_string(data))
		
		# Cek apakah kolom ini spesifik perlu di-highlight (dari warning_details)
		var is_warning_column = _is_warning_column(current_row_id, key, current_group_name)
		if is_warning_column:
			print("[JsonTree] APPLYING RED to column '%s' in row '%s' (group: %s)" % [key, current_row_id, current_group_name])
			item.set_custom_color(0, Color.RED)
			item.set_meta("has_warning", true)
		
		# Cek apakah item harus ditampilkan
		if not filter_text.is_empty():
			if filter_text.to_lower() in display_text.to_lower():
				should_show = true
	

	# Handle sistem filter
	if not filter_text.is_empty() and not should_show:
		item.free()
		return null
	
	return item

## Fungsi untuk mengatur format nilai untuk menampilkan ke visual tree
static func format_value(value: Variant) -> String:
	if value == null:
		return "null"
	elif value is String:
		# Mengatur limit karakter untuk string
		if value.length() > 100:
			return '"%s..."' % value.substr(0, 100)
		return '"%s"' % value
	elif value is bool:
		return "true" if value else "false"
	else:
		return str(value)

## Fungsi expand/collapse semua item di tree
func expand_all() -> void:
	_set_all_collapsed(false)

func collapse_all() -> void:
	_set_all_collapsed(true)

## Fungsi untuk mengatur semua item di tree menjadi collapsed atau expanded
func _set_all_collapsed(collapsed: bool) -> void:
	var root = _tree.get_root()
	if root == null:
		return
	_set_item_collapsed_recursive(root, collapsed)

func _set_item_collapsed_recursive(item: TreeItem, collapsed: bool) -> void:
	item.set_collapsed(collapsed)
	var child = item.get_first_child()
	while child != null:
		_set_item_collapsed_recursive(child, collapsed)
		child = child.get_next()

## GET path dari item yang dipilih
func get_selected_path() -> Array:
	var selected = _tree.get_selected()
	if selected == null:
		return []
	
	var item_path = selected.get_metadata(0)
	if item_path == null:
		return []
	return item_path

## Cek apakah item yang dipilih bisa diedit (value primitif)
func is_selected_editable() -> bool:
	var selected = _tree.get_selected()
	if selected == null:
		return false
	return selected.has_meta("is_editable") and selected.get_meta("is_editable")

## GET tipe value dari item yang dipilih
func get_selected_value_type() -> String:
	var selected = _tree.get_selected()
	if selected == null:
		return ""
	if not selected.has_meta("value_type"):
		return ""
	return selected.get_meta("value_type")

## Convert value ke string untuk editing
static func value_to_edit_string(value: Variant) -> String:
	if value == null:
		return "null"
	elif value is String:
		return value
	elif value is bool:
		return "true" if value else "false"
	else:
		return str(value)
