##
## HanpekiLoggerEditorTransport is a special [HanpekiLogger.Transport] that sends every message to
## the [code]Logs[/code] dock of the Godot editor, through the debugger connection.
##
## It doesn't need to be added manually: [HanpekiLogger] creates it automatically when the game is
## running from the editor with the plugin enabled, and it receives every message (even the ones
## from disabled levels), as the filtering is done in the editor dock.
##
class_name HanpekiLoggerEditorTransport extends HanpekiLogger.Transport

## Prefix of the messages sent to the editor (captured by the editor debugger plugin)
const CAPTURE_PREFIX = "hanpeki_logger"
## Message sent for every log entry
const MSG_ENTRY = CAPTURE_PREFIX + ":entry"
## Message sent with the list of registered levels (when it changes)
const MSG_LEVELS = CAPTURE_PREFIX + ":levels"
## Message sent when a namespace is bound (via [method HanpekiLogger.bind_ns])
const MSG_NAMESPACE = CAPTURE_PREFIX + ":namespace"
## Path of the plugin config, used to check if the plugin is enabled in the project
const PLUGIN_CFG_PATH = "res://addons/hanpeki_godot_logger/plugin.cfg"


##
## Constructor with [param options]
##
static func create(options: Options = null) -> HanpekiLoggerEditorTransport:
	if !options:
		options = Options.new()
	return HanpekiLoggerEditorTransport.new(options)


##
## Check if the editor transport can be used: the game needs to be running from the editor
## (with the debugger connected) and the plugin needs to be enabled (to receive the messages)
##
static func is_available() -> bool:
	if !EngineDebugger.is_active():
		return false
	var plugins = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	return PLUGIN_CFG_PATH in plugins


func process(data: HanpekiLogger.MsgData) -> void:
	EngineDebugger.send_message(MSG_ENTRY, _to_payload(data))


##
## Send the list of registered levels as [code]{ level: name }[/code]
##
func send_levels(names: Dictionary[int, String]) -> void:
	var levels: Array = []
	for level in names:
		levels.append([level, names[level]])
	EngineDebugger.send_message(MSG_LEVELS, levels)


##
## Send a namespace bound via [method HanpekiLogger.bind_ns], so it appears in the editor dock
## even before any message is logged with it
##
func send_namespace(ns: StringName) -> void:
	EngineDebugger.send_message(MSG_NAMESPACE, [String(ns)])


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
## Called on instanciation.
## It checks that a proper Options object has been provided, and encourages to use the static
## method [method create] as a constructor/builder.
##
func _init(options: Options) -> void:
	assert(options, "No options found. Please use HanpekiLoggerEditorTransport.create()")
	set_options(options)
