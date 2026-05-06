@tool
extends EditorPlugin

var _dock: EditorDock          # The dock wrapper registered with the editor
var _view = preload("uid://dnna7ajx7urn5")
var _settings_dirty: bool = false

const SETTINGS_PATH = "res://addons/inheritance_viewer/inheritance_view_settings.tres"

func _enter_tree() -> void:
	_view = _view.instantiate()

	#_view.settings = _load_or_create_settings()
	_view.settings.changed.connect(func(): _settings_dirty = true)

	# --- EditorDock setup ---
	_dock = EditorDock.new()
	_dock.title = "Inheritance Viewer"

	# Start in the bottom panel slot (equivalent to the old add_control_to_bottom_panel).
	_dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM

	# Allow the dock to live in the bottom panel OR as a floating window.
	# Remove DOCK_LAYOUT_FLOATING if you want to prevent floating.
	_dock.available_layouts = EditorDock.DOCK_LAYOUT_HORIZONTAL \
			| EditorDock.DOCK_LAYOUT_FLOATING

	_dock.add_child(_view)

	# Registers the dock with the editor. The "Make Floating" option is
	# built into the dock's "⋮" context menu automatically.
	add_dock(_dock)
	_dock.make_visible()

func _exit_tree() -> void:
	if _settings_dirty:
		ResourceSaver.save(_view.settings, SETTINGS_PATH)

	remove_dock(_dock)
	_dock.queue_free()   # also frees _view as a child
	
func _load_or_create_settings() -> InheritanceViewSettings:
	if ResourceLoader.exists(SETTINGS_PATH):
		return load(SETTINGS_PATH) as InheritanceViewSettings
	var s := InheritanceViewSettings.new()
	DirAccess.make_dir_recursive_absolute(SETTINGS_PATH.get_base_dir())
	ResourceSaver.save(s, SETTINGS_PATH)
	return s
