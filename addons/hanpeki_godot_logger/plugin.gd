@tool
extends EditorPlugin

const LogsDock = preload("res://addons/hanpeki_godot_logger/editor/logs_dock.gd")
const LogsDebuggerPlugin = preload(
	"res://addons/hanpeki_godot_logger/editor/logs_debugger_plugin.gd"
)

## Dock showing the logs received from the running game
var _dock: LogsDock
## Debugger plugin receiving the logs from the running game
var _debugger_plugin: LogsDebuggerPlugin


func _enter_tree() -> void:
	_dock = LogsDock.new()
	add_dock(_dock)
	# save the editor layout (including the dock state) when it changes
	_dock.panel.state_changed.connect(queue_save_layout)

	_debugger_plugin = LogsDebuggerPlugin.new(_dock.panel)
	add_debugger_plugin(_debugger_plugin)


func _exit_tree() -> void:
	remove_debugger_plugin(_debugger_plugin)
	_debugger_plugin = null
	remove_dock(_dock)
	_dock.queue_free()
	_dock = null
