tool
extends EditorPlugin

const Finder = preload("res://addons/godot-command-palette/Finder.tscn")
const FileIndex = preload("res://addons/godot-command-palette/file_index.gd")

# Instance of finder scene
var finder: Node
var finder_window: WindowDialog
var finder_list: ItemList
var finder_search: LineEdit
# FileSystem index
var file_index
# If finder is open
var open := false
# Input tracking
var inputs := {
	"up": false,
	"down": false,
}

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
	file_index = FileIndex.new(get_editor_interface().get_resource_filesystem().get_filesystem())

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
	
	# Populate file list
	populate_list()

func close_finder() -> void:
	if !open: return
	open = false
	
	# Hide window
	finder_window.hide()

func _on_finder_closed() -> void:
	if !open: return
	open = false
	
	# Clear controls
	finder_list.clear()
	finder_search.clear()

# Add resources to list
func populate_list():
	finder_list.clear()
	for res in file_index.resources_filtered:
		finder_list.add_item(res.path)
		finder_list.set_item_metadata(finder_list.get_item_count() - 1, res.type)
	
	# Select first item
	if finder_list.get_item_count() > 0:
		finder_list.select(0)

# Filter list when search text changed
# warning-ignore: unused_argument
func _on_search_text_changed(new_text: String) -> void:
	# Filter and display results
	file_index.filter(finder_search.text)
	populate_list()

# Open result
func _on_search_text_entered(new_text: String) -> void:
	if finder_list.get_item_count() == 0:
		return
	
	# Get item type
	var path = finder_list.get_item_text(get_selected_item_index())
	var type = finder_list.get_item_metadata(get_selected_item_index())
	match type:
		"PackedScene":
			get_editor_interface().open_scene_from_path(path)
		"GDScript":
			get_editor_interface().edit_resource(load(path))
		_:
			get_editor_interface().select_file(path)
			get_editor_interface().edit_resource(load(path))
	
	# Clear search
	finder_search.clear()
	# Close window
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
	file_index.build_index()
