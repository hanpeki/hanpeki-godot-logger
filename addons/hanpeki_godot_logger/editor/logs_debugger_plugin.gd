@tool
##
## Receives the messages sent by [HanpekiLoggerEditorTransport] from the running game (through the
## debugger connection) and passes them to the [code]Logs[/code] dock panel
##
extends EditorDebuggerPlugin

const LogsPanel = preload("res://addons/hanpeki_godot_logger/editor/logs_panel.gd")

## Panel showing the received entries
var _panel: LogsPanel


func _init(panel: LogsPanel) -> void:
	_panel = panel


func _has_capture(capture: String) -> bool:
	return capture == HanpekiLoggerEditorTransport.CAPTURE_PREFIX


func _capture(message: String, data: Array, _session_id: int) -> bool:
	match message:
		HanpekiLoggerEditorTransport.MSG_ENTRY:
			_panel.add_entry(data)
		HanpekiLoggerEditorTransport.MSG_LEVELS:
			_panel.set_levels(data)
		HanpekiLoggerEditorTransport.MSG_NAMESPACE:
			_panel.add_namespace(data[0])
		_:
			return false
	return true


func _setup_session(session_id: int) -> void:
	var session = get_session(session_id)
	session.started.connect(_panel.on_session_started)
