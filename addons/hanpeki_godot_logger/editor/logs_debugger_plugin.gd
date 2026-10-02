@tool
##
## Receives the messages sent by [HanpekiLoggerEditorTransport] from the running game (through the
## debugger connection) and passes them to the [code]Logs[/code] dock panel.
## It also sends the breakpoints configured in the panel to the running game.
##
extends EditorDebuggerPlugin

const LogsPanel = preload("res://addons/hanpeki_godot_logger/editor/logs_panel.gd")

## Folder of the plugin, to skip its frames when selecting the log call in the debugger stack
const PLUGIN_FOLDER = "res://addons/hanpeki_godot_logger/"
## Title of the column of the [Tree] with the stack frames in the editor debugger
const STACK_FRAMES_TITLE = "Stack Frames"
## Seconds to wait before opening the log call in the script editor when the stack frame can't
## be selected (fallback), so it's done after the editor shows the line where the execution stopped
const OPEN_SCRIPT_DELAY = 0.2

## Panel showing the received entries
var _panel: LogsPanel


func _init(panel: LogsPanel) -> void:
	_panel = panel
	_panel.breakpoints_changed.connect(_send_breakpoints)
	# save the current configuration, so it's available for the next run
	HanpekiLoggerEditorTransport._save_breakpoints_file(_panel.get_breakpoints_payload())


func _has_capture(capture: String) -> bool:
	return capture == HanpekiLoggerEditorTransport.CAPTURE_PREFIX


func _capture(message: String, data: Array, session_id: int) -> bool:
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
			_on_log_break(data, session_id)
		_:
			return false
	return true


func _setup_session(session_id: int) -> void:
	var session = get_session(session_id)
	# Note that messages can't be sent to the game when the session starts, as the logger doesn't
	# exist yet to receive them. The breakpoints are read from a file instead (see
	# HanpekiLoggerEditorTransport.BREAKPOINTS_FILE)
	session.started.connect(_panel.on_session_started)


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
## Called when the game is going to stop because of a log breakpoint, with the [param location]
## ([code][source, line][/code]) of the log call.
## The [code]breakpoint[/code] is executed inside the logger, so the editor would select that
## frame. Instead, the frame of the log call is selected when the stack is received (showing its
## code and variables). This relies on the internal nodes of the editor debugger (there's no API
## for it), so if they are not found, the log call is just opened in the script editor.
##
func _on_log_break(location: Array, session_id: int) -> void:
	var debugger = _get_editor_debugger(session_id)
	if debugger && debugger.has_signal("stack_dump"):
		debugger.connect(
			"stack_dump",
			func(_stack): _select_log_call_frame.call_deferred(debugger, location),
			CONNECT_ONE_SHOT
		)
	elif !location.is_empty():
		_open_script_later(location[0], location[1])


##
## Get the internal node of the editor debugger for the given [param session_id]
## (named "Session N", starting from 1), or [code]null[/code] if not found
##
func _get_editor_debugger(session_id: int) -> Node:
	var name = "Session %d" % (session_id + 1)
	var found = EditorInterface.get_base_control().find_children(
		name, "ScriptEditorDebugger", true, false
	)
	return found[0] if !found.is_empty() else null


##
## Select the first frame of the stack (in the editor [param debugger]) outside of the plugin code,
## which is the log call. Falls back to open the [param location] in the script editor.
##
func _select_log_call_frame(debugger: Node, location: Array) -> void:
	var tree = _get_stack_frames_tree(debugger)
	if tree:
		var item = tree.get_root().get_first_child() if tree.get_root() else null
		while item:
			if !item.get_text(0).contains(PLUGIN_FOLDER):
				# selecting it does the same as clicking it (showing its code and variables)
				tree.set_selected(item, 0)
				tree.scroll_to_item(item)
				return
			item = item.get_next()
	if !location.is_empty():
		_open_script_later(location[0], location[1])


##
## Get the [Tree] with the stack frames inside the given editor [param debugger]
##
func _get_stack_frames_tree(debugger: Node) -> Tree:
	for tree in debugger.find_children("*", "Tree", true, false):
		if tree.columns > 0 && tree.get_column_title(0) == STACK_FRAMES_TITLE:
			return tree
	return null


##
## Open the script at [param source] in the given [param line] after a short delay
## (see [constant OPEN_SCRIPT_DELAY])
##
func _open_script_later(source: String, line: int) -> void:
	await Engine.get_main_loop().create_timer(OPEN_SCRIPT_DELAY).timeout
	_open_script(source, line)


func _open_script(source: String, line: int) -> void:
	if !ResourceLoader.exists(source):
		return
	var script = load(source)
	if script is Script:
		EditorInterface.edit_script(script, line)
