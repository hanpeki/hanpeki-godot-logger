@tool
##
## [code]Logs[/code] editor dock, containing the [code]LogsPanel[/code] and saving its state with
## the editor layout (so it's restored when opening the editor again)
##
extends EditorDock

const LogsPanel = preload("res://addons/hanpeki_godot_logger/editor/logs_panel.gd")

## Version of the saved state, to be able to migrate it if its format changes
const STATE_VERSION = 1
## Keys of the panel state saved in the layout (see [method LogsPanel.get_state])
const STATE_KEYS = [
	"show_namespaces",
	"show_levels",
	"preserve_logs",
	"disabled_levels",
	"disabled_namespaces",
	"split_offset",
	"filters_split_offset",
]

## Panel with the logs
var panel: LogsPanel


func _init() -> void:
	set_title("Logs")
	set_icon_name("FileList")
	set_layout_key("hanpeki_logger_logs")
	set_default_slot(DOCK_SLOT_BOTTOM)
	set_available_layouts(DOCK_LAYOUT_HORIZONTAL | DOCK_LAYOUT_FLOATING)
	panel = LogsPanel.new()
	add_child(panel)


func _save_layout_to_config(config: ConfigFile, section: String) -> void:
	var state = panel.get_state()
	config.set_value(section, "version", STATE_VERSION)
	for key in STATE_KEYS:
		config.set_value(section, key, state[key])


func _load_layout_from_config(config: ConfigFile, section: String) -> void:
	# Unknown versions are ignored, keeping the default state
	if config.get_value(section, "version", 0) != STATE_VERSION:
		return
	var state = {}
	for key in STATE_KEYS:
		if config.has_section_key(section, key):
			state[key] = config.get_value(section, key)
	panel.apply_state(state)
