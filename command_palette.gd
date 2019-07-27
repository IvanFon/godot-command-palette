tool
extends EditorPlugin

const Finder = preload("res://addons/godot-command-palette/Finder.tscn")
const FileIndex = preload("res://addons/godot-command-palette/file_index.gd")

# Instance of finder scene
var finder: Node
var finder_window: WindowDialog
var finder_list: ItemList
var finder_search: LineEdit
# If finder is open
var open := false
# Input tracking
var inputs := {
	"up": false,
	"down": false,
}

var cur_mode

func _enter_tree() -> void:
	# Create finder and add to editor
	finder = Finder.instance() as Control
	add_control_to_container(CONTAINER_TOOLBAR, finder)
	
	# Get controls
	finder_window = finder.get_node("WindowDialog") as WindowDialog
	finder_list = finder.get_node("WindowDialog/List") as ItemList
	finder_search = finder.get_node("WindowDialog/Search") as LineEdit
	
	# Connect signals
	# Finder
	finder_window.connect("popup_hide", self, "_on_finder_closed")
	finder_search.connect("text_changed", self, "_on_search_text_changed")
	finder_search.connect("text_entered", self, "_on_search_text_entered")
	# Filesystem changes
	get_editor_interface().get_resource_filesystem().connect("filesystem_changed", self, "_on_filesystem_changed")
	
	# Setup FileSystem index
	var file_index = FileIndex.new(get_editor_interface().get_resource_filesystem().get_filesystem())
	
	cur_mode = preload("res://addons/godot-command-palette/modes/mode_files.gd").new(get_editor_interface(), file_index)

func _exit_tree() -> void:
	remove_control_from_container(CONTAINER_TOOLBAR, finder)

func _process(delta: float) -> void:
	# Keyboard shortcuts (closed)
	if (Input.is_key_pressed(KEY_CONTROL) &&
			Input.is_key_pressed(KEY_P)):
		open_finder()
	
	# Keyboard shortcuts (open)
	if !open: return
	if !Input.is_key_pressed(KEY_UP):
		if inputs.up:
			inputs.up = false
			move_selection_up()
	else:
		inputs.up = true
	
	if !Input.is_key_pressed(KEY_DOWN):
		if inputs.down:
			inputs.down = false
			move_selection_down()
	else:
		inputs.down = true

func open_finder() -> void:
	if open: return
	open = true
	
	# Show window
	finder_window.popup_centered()
	finder_search.grab_focus()
	
	cur_mode.palette_opened()
	
	# Populate file list
	cur_mode.populate_list(finder_list)

func close_finder() -> void:
	if !open: return
	open = false
	
	# Hide window
	finder_window.hide()

func _on_finder_closed() -> void:
	if !open: return
	open = false
	
	cur_mode.palette_closed()
	
	# Clear controls
	finder_list.clear()
	finder_search.clear()

# Filter list when search text changed
func _on_search_text_changed(text: String) -> void:
	cur_mode.search_changed(text, finder_list)

# Open result
func _on_search_text_entered(text: String) -> void:
	# Only cleanup if mode triggers successfully (true)
	if cur_mode.triggered(finder_list):
		finder_search.clear()
		close_finder()

# Get selected item index in item list
func get_selected_item_index() -> int:
	return finder_list.get_selected_items()[0]

func move_selection_up() -> void:
	if finder_list.get_item_count() == 0:
		return
	
	var cur_index = get_selected_item_index()
	if cur_index - 1 < 0:
		finder_list.select(finder_list.get_item_count() - 1)
	else:
		finder_list.select(cur_index - 1)
	
	finder_list.ensure_current_is_visible()

func move_selection_down() -> void:
	if finder_list.get_item_count() == 0:
		return
	
	var cur_index = get_selected_item_index()
	if cur_index + 1 > finder_list.get_item_count() - 1:
		finder_list.select(0)
	else:
		finder_list.select(cur_index + 1)
	
	finder_list.ensure_current_is_visible()

func _on_filesystem_changed():
	cur_mode.filesystem_changed()
