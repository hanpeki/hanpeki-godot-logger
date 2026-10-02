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
## Path of the plugin config, used to check if the plugin is enabled in the project
const PLUGIN_CFG_PATH = "res://addons/hanpeki_godot_logger/plugin.cfg"

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
	_send_colors()
	_send_levels(names)


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
