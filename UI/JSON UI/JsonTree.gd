class_name JsonTree
extends RefCounted

## Skrip untuk mengatur Tree JSON - building, navigasi, dan format

var _tree: Tree = null
var _json_data: Variant = null

## Inisialisasi dengan Tree reference
func init(tree: Tree) -> void:
	_tree = tree

## Set data JSON
func set_data(data: Variant) -> void:
	_json_data = data

## GET data JSON
func get_data() -> Variant:
	return _json_data

## Buat tree dari data yang diberikan
func build_tree(data: Variant, filter_text: String = "") -> void:
	if _tree == null:
		return
	
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

## Menambahkan item baru untuk setiap item di data ke visual tree
func _add_tree_items(parent: TreeItem, data: Variant, key: String, filter_text: String = "", path: Array = []) -> TreeItem:
	var item = _tree.create_item(parent)
	var should_show = filter_text.is_empty()
	var current_path = path.duplicate()
	
	# Parse key untuk path (handle array index)
	if key.begins_with("[") and key.ends_with("]"):
		current_path.append(int(key.substr(1, key.length() - 2)))
	else:
		current_path.append(key)
	
	# Set metadata untuk tracking path
	item.set_metadata(0, current_path)
	
	# Check apakah item adalah dictionary atau array
	if data is Dictionary:
		var dict_size = data.size()
		item.set_text(0, "%s {%d}" % [key, dict_size])
		item.set_collapsed(true)
		
		# Rekursif untuk menambahkan item baru untuk setiap item di dictionary
		for dict_key in data.keys():
			var child_item = _add_tree_items(item, data[dict_key], str(dict_key), filter_text, current_path)
			if child_item != null and not filter_text.is_empty():
				should_show = true
		
	elif data is Array:
		var arr_size = data.size()
		item.set_text(0, "%s [%d]" % [key, arr_size])
		item.set_collapsed(true)
		
		# rekursif untuk menambahkan item baru untuk setiap item di array
		for i in range(data.size()):
			var child_item = _add_tree_items(item, data[i], "[%d]" % i, filter_text, current_path)
			if child_item != null and not filter_text.is_empty():
				should_show = true
		
	else:
		# Item adalah nilai dasar (editable)
		var value_str = format_value(data)
		var display_text = "%s: %s" % [key, value_str]
		item.set_text(0, display_text)
		item.set_meta("is_editable", true)
		item.set_meta("value_type", JsonEditor.get_type_string(data))
		
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
