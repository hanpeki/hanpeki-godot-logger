##
## HanpekiLoggerEditorTransport is a special transport that sends every message to the
## [code]Logs[/code] dock of the Godot editor, through the debugger connection.
##
## It's fully static, as there's only one editor dock for every logger. It doesn't need to be
## added manually: [HanpekiLogger] uses it automatically when the game is running from the editor
## with the plugin enabled, and it receives every message (even the ones from disabled levels),
## as the filtering is done in the editor dock.
##
## It only holds plain values (colors), and it's never instantiated, so it can't cause leaks.
##
class_name HanpekiLoggerEditorTransport

## Prefix of the messages sent to the editor (captured by the editor debugger plugin)
const CAPTURE_PREFIX = "hanpeki_logger"
## Message sent for every log entry
const MSG_ENTRY = CAPTURE_PREFIX + ":entry"
## Message sent with the list of registered levels (when it changes)
const MSG_LEVELS = CAPTURE_PREFIX + ":levels"
## Message sent when a namespace is bound (via [method HanpekiLogger.bind_ns])
const MSG_NAMESPACE = CAPTURE_PREFIX + ":namespace"
## Message sent with the colors to use for levels and namespaces (when they change)
const MSG_COLORS = CAPTURE_PREFIX + ":colors"
## Message sent right before stopping the execution in a log breakpoint, with the location of the
## log call
const MSG_BREAK = CAPTURE_PREFIX + ":break"
## Message received from the editor with the breakpoints configuration
const MSG_BREAKPOINTS = CAPTURE_PREFIX + ":breakpoints"
## File where the editor saves the breakpoints configuration, read by the game when starting.
## Needed because messages sent by the editor when the game starts are received before the logger
## exists (so they are discarded), and to have the breakpoints from the very first message.
## It's inside [code].godot[/code], so it's local to the project (not versioned nor exported).
const BREAKPOINTS_FILE = "res://.godot/hanpeki_logger/breakpoints.cfg"
## Section of [constant BREAKPOINTS_FILE] with the breakpoints configuration
const BREAKPOINTS_SECTION = "breakpoints"
## Path of the plugin config, used to check if the plugin is enabled in the project
const PLUGIN_CFG_PATH = "res://addons/hanpeki_godot_logger/plugin.cfg"
## Milliseconds to wait when the game is closing, so the messages still queued in the debugger
## connection are sent to the editor (they are sent by another thread, and lost when the
## connection is closed). Otherwise, messages logged right before quitting wouldn't be displayed.
const EXIT_FLUSH_DELAY_MS = 100

## Cached result of [method is_available] ([code]null[/code] until checked)
static var _available: Variant = null
## Colors used in the editor dock for each level
static var _level_colors: Dictionary[int, Color] = (
	HanpekiLogger.Transport.DEFAULT_LEVEL_COLORS.duplicate()
)
## Color used in the editor dock for levels without a specific one
static var _level_default_color: Color = HanpekiLogger.Transport.DEFAULT_CUSTOM_LEVEL_COLOR
## Colors used in the editor dock for each namespace
static var _ns_colors: Dictionary[StringName, Color] = {}
## Color used in the editor dock for namespaces without a specific one
static var _ns_default_color: Color = HanpekiLogger.Transport.DEFAULT_NS_COLOR
## Whether the capture to receive messages from the editor is already registered
static var _capture_registered: bool = false
## Union of the levels stopping the execution when logged (configured from the editor, these are
## the defaults until the configuration is received)
static var _break_levels: int = HanpekiLogger.ERROR | HanpekiLogger.FATAL
## Namespaces stopping the execution when logged (configured from the editor)
static var _break_namespaces: Dictionary[StringName, bool] = {}
## If [code]true[/code], both the level and the namespace need to be set to stop the execution
## (AND). Otherwise, any of them is enough (OR). AND behaves like OR when no level or no
## namespace is set
static var _break_on_both: bool = false
## Whether the breakpoints are ignored (configured from the editor)
static var _breakpoints_ignored: bool = false


##
## Check if the messages can be sent to the editor: the game needs to be running from the editor
## (with the debugger connected) and the plugin needs to be enabled (to receive the messages).
## The result is cached, as it doesn't change while the game is running.
##
static func is_available() -> bool:
	if _available == null:
		var plugins = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
		_available = EngineDebugger.is_active() && PLUGIN_CFG_PATH in plugins
	return _available


##
## Set the [param color] to display the given [param level] in the editor dock.
## It can be configured before creating any logger, and it's not sent anywhere when not running
## from the editor (so it can be called in production builds as well).
##
static func set_level_color(level: int, color: Color) -> void:
	_level_colors[level] = color
	_send_colors()


##
## Set the [param color] to display levels without a specific one (usually custom levels)
## in the editor dock
##
static func set_level_default_color(color: Color) -> void:
	_level_default_color = color
	_send_colors()


##
## Set the [param color] to display the given namespace [param ns] in the editor dock
##
static func set_ns_color(ns: StringName, color: Color) -> void:
	_ns_colors[ns] = color
	_send_colors()


##
## Set the [param color] to display namespaces without a specific one in the editor dock
##
static func set_ns_default_color(color: Color) -> void:
	_ns_default_color = color
	_send_colors()


##
## Called by [HanpekiLogger] when it's created, to send the current configuration (colors and
## [param names] of the registered levels) to the editor dock
##
static func _on_logger_created(names: Dictionary[int, String]) -> void:
	if !_capture_registered:
		EngineDebugger.register_message_capture(CAPTURE_PREFIX, _on_editor_message)
		_capture_registered = true
		_load_breakpoints_file()
		var main_loop = Engine.get_main_loop()
		if main_loop is SceneTree:
			main_loop.root.tree_exiting.connect(_on_game_exiting)
	_send_colors()
	_send_levels(names)


##
## Called when the game is closing, before the debugger connection is closed
##
static func _on_game_exiting() -> void:
	# give time to the debugger connection to send the queued messages (see EXIT_FLUSH_DELAY_MS)
	OS.delay_msec(EXIT_FLUSH_DELAY_MS)
	# Unregistered here, as Godot reports an error when trying to unregister it by itself after the
	# debugger has been already shut down
	_unregister_capture()


##
## Unregister the capture receiving the messages from the editor
##
static func _unregister_capture() -> void:
	if _capture_registered && EngineDebugger.has_capture(CAPTURE_PREFIX):
		EngineDebugger.unregister_message_capture(CAPTURE_PREFIX)
	_capture_registered = false


##
## Save the breakpoints configuration [param data] (see [method _set_breakpoints]) in
## [constant BREAKPOINTS_FILE], to be read by the game when it starts. Called from the editor.
##
static func _save_breakpoints_file(data: Array) -> void:
	DirAccess.make_dir_recursive_absolute(BREAKPOINTS_FILE.get_base_dir())
	var config = ConfigFile.new()
	config.set_value(BREAKPOINTS_SECTION, "levels", data[0])
	config.set_value(BREAKPOINTS_SECTION, "namespaces", data[1])
	config.set_value(BREAKPOINTS_SECTION, "on_both", data[2])
	config.set_value(BREAKPOINTS_SECTION, "ignored", data[3])
	config.save(BREAKPOINTS_FILE)


##
## Load the breakpoints configuration saved by the editor in [constant BREAKPOINTS_FILE]
## (keeping the defaults if it doesn't exist or it's not valid)
##
static func _load_breakpoints_file() -> void:
	var config = ConfigFile.new()
	if config.load(BREAKPOINTS_FILE) != OK:
		return
	for key in ["levels", "namespaces", "on_both", "ignored"]:
		if !config.has_section_key(BREAKPOINTS_SECTION, key):
			return
	var levels = config.get_value(BREAKPOINTS_SECTION, "levels")
	var namespaces = config.get_value(BREAKPOINTS_SECTION, "namespaces")
	var on_both = config.get_value(BREAKPOINTS_SECTION, "on_both")
	var ignored = config.get_value(BREAKPOINTS_SECTION, "ignored")
	if (
		typeof(levels) == TYPE_INT
		&& typeof(namespaces) == TYPE_ARRAY
		&& typeof(on_both) == TYPE_BOOL
		&& typeof(ignored) == TYPE_BOOL
	):
		_set_breakpoints([levels, namespaces, on_both, ignored])


##
## Receive the messages sent from the editor to the running game
##
static func _on_editor_message(message: String, data: Array) -> bool:
	# depending on the Godot version, the message can be received with or without the prefix
	if message == MSG_BREAKPOINTS || CAPTURE_PREFIX + ":" + message == MSG_BREAKPOINTS:
		_set_breakpoints(data)
		return true
	return false


##
## Set the breakpoints configuration received from the editor, as
## [code][levels, namespaces, on_both, ignored][/code]
##
static func _set_breakpoints(data: Array) -> void:
	_break_levels = data[0]
	_break_namespaces.clear()
	for ns in data[1]:
		_break_namespaces[StringName(ns)] = true
	_break_on_both = data[2]
	_breakpoints_ignored = data[3]


##
## Check if the execution needs to be stopped when logging a message with the given
## [param level] and namespace [param ns], based on the breakpoints configured in the editor
##
static func _should_break(level: int, ns: StringName) -> bool:
	if _breakpoints_ignored:
		return false
	var by_level = _break_levels & level != 0
	var by_ns = _break_namespaces.has(ns)
	# AND only applies when both levels and namespaces are set, otherwise it behaves like OR
	if _break_on_both && _break_levels != 0 && !_break_namespaces.is_empty():
		return by_level && by_ns
	return by_level || by_ns


##
## Notify the editor that the execution is going to stop because of the message [param data],
## sending the location of the log call (so the editor can show it)
##
static func _notify_break(data: HanpekiLogger.MsgData) -> void:
	var location = []
	if data.stack:
		location = [data.stack[0].source, data.stack[0].line]
	EngineDebugger.send_message(MSG_BREAK, location)


##
## Send a message [param data] to the editor dock
##
static func _send_entry(data: HanpekiLogger.MsgData) -> void:
	EngineDebugger.send_message(MSG_ENTRY, _to_payload(data))


##
## Send the list of registered levels, from their [param names] as [code]{ level: name }[/code]
##
static func _send_levels(names: Dictionary[int, String]) -> void:
	var levels: Array = []
	for level in names:
		levels.append([level, names[level]])
	EngineDebugger.send_message(MSG_LEVELS, levels)


##
## Send a namespace bound via [method HanpekiLogger.bind_ns], so it appears in the editor dock
## even before any message is logged with it
##
static func _send_namespace(ns: StringName) -> void:
	EngineDebugger.send_message(MSG_NAMESPACE, [String(ns)])


##
## Send the configured colors to the editor dock, if running from the editor.
## The whole configuration is sent every time, so the dock replaces whatever it had
## (i.e. colors from a previous run)
##
static func _send_colors() -> void:
	if is_available():
		EngineDebugger.send_message(MSG_COLORS, _get_colors_payload())


##
## Convert the [param data] of a message into the payload sent to the editor, as
## [code][level, level_name, ns, msg, unix_ms, stack][/code] where [code]stack[/code] is a list
## of [code][source, line, function][/code] (empty if not available)
##
static func _to_payload(data: HanpekiLogger.MsgData) -> Array:
	var stack: Array = []
	if data.stack:
		for item in data.stack:
			stack.append([item.source, item.line, item.function])
	return [
		data.level,
		data.level_name,
		String(data.ns),
		data.msg,
		HanpekiLogger._start_unix_ms + data.utime,
		stack,
	]


##
## Get the configured colors as the payload sent to the editor, as
## [code][level_colors, level_default_color, ns_colors, ns_default_color][/code] where
## [code]level_colors[/code] is a list of [code][level, color][/code] and [code]ns_colors[/code]
## a list of [code][ns, color][/code]
##
static func _get_colors_payload() -> Array:
	var levels: Array = []
	for level in _level_colors:
		levels.append([level, _level_colors[level]])
	var namespaces: Array = []
	for ns in _ns_colors:
		namespaces.append([String(ns), _ns_colors[ns]])
	return [levels, _level_default_color, namespaces, _ns_default_color]
