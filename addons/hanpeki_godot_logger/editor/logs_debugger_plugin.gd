@tool
##
## Receives the messages sent by [HanpekiLoggerEditorTransport] from the running game (through the
## debugger connection) and passes them to the [code]Logs[/code] dock panel.
## It also sends the breakpoints configured in the panel to the running game.
##
extends EditorDebuggerPlugin

const LogsPanel = preload("res://addons/hanpeki_godot_logger/editor/logs_panel.gd")

## Panel showing the received entries
var _panel: LogsPanel
## Location ([code][source, line][/code]) of the log call that stopped the execution, to show it
## when the debugger breaks
var _break_location: Array = []


func _init(panel: LogsPanel) -> void:
	_panel = panel
	_panel.breakpoints_changed.connect(_send_breakpoints)
	# save the current configuration, so it's available for the next run
	HanpekiLoggerEditorTransport._save_breakpoints_file(_panel.get_breakpoints_payload())


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
		HanpekiLoggerEditorTransport.MSG_COLORS:
			_panel.set_colors(data)
		HanpekiLoggerEditorTransport.MSG_BREAK:
			_break_location = data
		_:
			return false
	return true


func _setup_session(session_id: int) -> void:
	var session = get_session(session_id)
	# Note that messages can't be sent to the game when the session starts, as the logger doesn't
	# exist yet to receive them. The breakpoints are read from a file instead (see
	# HanpekiLoggerEditorTransport.BREAKPOINTS_FILE)
	session.started.connect(_panel.on_session_started)
	session.breaked.connect(_on_session_breaked)


##
## Save the breakpoints configured in the panel (for the next runs) and send them to every running
## game (to apply the changes while running)
##
func _send_breakpoints() -> void:
	var payload = _panel.get_breakpoints_payload()
	HanpekiLoggerEditorTransport._save_breakpoints_file(payload)
	for session in get_sessions():
		if session.is_active():
			session.send_message(HanpekiLoggerEditorTransport.MSG_BREAKPOINTS, payload)


##
## When the execution stops because of a log breakpoint, show the log call in the script editor
## (instead of the [code]breakpoint[/code] line inside the logger)
##
func _on_session_breaked(_can_debug: bool) -> void:
	if _break_location.is_empty():
		return
	var location = _break_location
	_break_location = []
	# deferred, so it's done after the editor shows the line where the execution stopped
	_open_script.call_deferred(location[0], location[1])


func _open_script(source: String, line: int) -> void:
	if !ResourceLoader.exists(source):
		return
	var script = load(source)
	if script is Script:
		EditorInterface.edit_script(script, line)
