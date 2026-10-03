# Copyright (c) 2025 Hanpeki Games
# Distributed under the terms of the MIT license.
# https://github.com/hanpeki/hanpeki-godot-logger/blob/main/LICENSE
#
# Upstream repo: https://github.com/hanpeki/hanpeki-godot-logger

##
## Hanpeki Logger class accepting custom levels, namespaces and transports
##
class_name HanpekiLogger

##
## Default levels provided by the class
##
enum {
	## Special level to be used by transports to use the logger level
	INHERIT = -1,
	## Not a level itself. Enables every level when used with [method enable_levels_from],
	## or none when it's the only value in [member Options.levels]
	NONE = 0,
	## Debug messages
	DEBUG = 1 << 5,
	## Informational messages to follow the code flow
	INFO = 1 << 10,
	## Important messages but not warning nor errors
	CORE = 1 << 15,
	## Unexpected, but non-breaking happenings
	WARN = 1 << 20,
	## Unexpected happening that might break parts when not handled
	ERROR = 1 << 25,
	## Only used for errors that make the app crash
	FATAL = 1 << 30,
	## Maximum level just for reference. Every custom defined level must be
	## lower than this one.
	## It can be used with [method enable_levels_from] to disable all logs
	MAX_LEVEL = 1 << 62 # (highest positive power of two in Godot: 2^62)
}

##
## Evaluates to [enum StackLevelMode] depending on the environment
##
enum StackLevelConfig {
	## Only valid for transports. Evaluates to [enum StackLevelMode.INHERIT], to use the
	## stack mode of the logger the transport is attached to
	INHERIT = -1,
	## Always evaluates to [enum StackLevelMode.NONE]
	NONE,
	## Always evaluates to [enum StackLevelMode.ORIGIN]
	ORIGIN,
	## Always evaluates to [enum StackLevelMode.FULL]
	FULL,
	## Evaluates to [enum StackLevelMode.ORIGIN] if [method OS.is_debug_build]
	## and [enum StackLevelMode.NONE] otherwise
	ORIGIN_IF_DEBUG,
	## Evaluates to [enum StackLevelMode.FULL] if [method OS.is_debug_build]
	## and [enum StackLevelMode.NONE] otherwise
	FULL_IF_DEBUG,
	## Evaluates to [enum StackLevelMode.ORIGIN] if not [method OS.is_debug_build]
	## and [enum StackLevelMode.NONE] otherwise
	ORIGIN_IF_PROD,
	## Evaluates to [enum StackLevelMode.FULL] if not [method OS.is_debug_build]
	## and [enum StackLevelMode.NONE] otherwise
	FULL_IF_PROD,
}

## Version of the library, used in the build process for the zip filename.
## It needs to match the version in [code]plugin.cfg[/code] (checked by the build and the tests)
const VERSION = "1.0.1"
## Value for undefined namespaces
const NS_UNDEFINED = &""
## Default stack mode of the logger (see [member Options.stack_mode])
const DEFAULT_STACK_LEVEL: Dictionary[int, StackLevelConfig] = {
	FATAL: StackLevelConfig.FULL,
	ERROR: StackLevelConfig.ORIGIN,
	WARN: StackLevelConfig.ORIGIN_IF_DEBUG,
}
## Union of the predefined levels, which can't be deregistered as they are used by the built-in
## methods ([method debug], [method info], etc.)
const PREDEFINED_LEVELS = DEBUG | INFO | CORE | WARN | ERROR | FATAL
## Names of the predefined levels
const PREDEFINED_LEVEL_NAMES: Dictionary[int, String] = {
	DEBUG: "Debug",
	INFO: "Info",
	CORE: "Core",
	WARN: "Warn",
	ERROR: "Error",
	FATAL: "Fatal",
}

## Unix time (in milliseconds) when the app started, calculated once so the time of each message
## can be obtained from [method Time.get_ticks_msec] only, keeping the relative time between
## messages consistent and avoiding calling [method Time.get_unix_time_from_system] every time.
## Note that changes in the system clock while the app is running won't be reflected.
static var _start_unix_ms: int = (
	int(Time.get_unix_time_from_system() * 1000) - Time.get_ticks_msec()
)

## Name to display for each level
var _names: Dictionary[int, String] = PREDEFINED_LEVEL_NAMES.duplicate()

## All registered levels, as they need to be unique at bit level (i.e. 1 | 2 | 4 ... 64)
var _registered_levels: int = PREDEFINED_LEVELS
## Levels to log, defaults to CORE, WARN, ERROR and FATAL
var _level: int = CORE | WARN | ERROR | FATAL
## Evaluated default stack mode for the transports inheriting it.
## [code]StackLevelMode | Dictionary[int, StackLevelMode][/code]
var _stack_mode: Variant = Transport._eval_provide_stack(DEFAULT_STACK_LEVEL)
## Cache with the levels for which the stack needs to be retrieved (only levels with
## [code]true[/code] are stored). It's not an option, but calculated from the stack mode of the
## logger and the attached transports, to avoid calling [method get_stack] when no transport is
## going to use it. Updated via [method _recalculate_is_stack_needed] when any of those change.
var _stack_needed: Dictionary[int, bool] = {}

## List of added transports
var _transports: Array[Transport]
## Whether every message is sent to the [code]Logs[/code] editor dock (via the static
## [HanpekiLoggerEditorTransport]), regardless of the enabled levels. Only when the game is
## running from the editor with the plugin enabled.
var _send_to_editor: bool = false


##
## Constructor with [param options]
##
static func create(options: Options = null) -> HanpekiLogger:
	if !options:
		options = Options.new()
	return HanpekiLogger.new(options)


##
## Apply multiple settings at once from the given [param options] configuration
##
func set_options(options: HanpekiLogger.Options) -> void:
	for entry in options.custom_levels:
		if !entry.has("level"):
			assert(false, 'wrong configuration in "custom_levels". "level" field not found')
			continue
		if !entry.has("name"):
			assert(false, 'wrong configuration in "custom_levels". "name" field not found')
			continue
		register_level(entry.level, entry.name)

	if options.level != null:
		var level = _resolve_level(options.level)
		if level == null:
			assert(false, 'unknown level in "level"')
		else:
			enable_levels_from(level)

	# set levels only when provided (NONE can be provided explicitly to disable every level)
	# if no levels are given, the defaults are kept
	if options.levels.size() > 0:
		if options.level == null:
			_level = NONE
		for entry in options.levels:
			var level = _resolve_level(entry)
			if level == null:
				assert(false, 'unknown level in "levels"')
				continue
			# NONE is accepted, but it doesn't enable any level
			if level == NONE:
				continue
			set_level(level, true)

	if options.stack_mode != null:
		set_stack_mode(options.stack_mode)


##
## Retrieves the value of a level from its name (case-insensitive)
##
func get_level_from_name(name: StringName) -> Variant:
	var lc = name.to_lower()
	for level in _names:
		if _names[level].to_lower() == lc:
			return level
	return null


##
## Retrieves the name of a given [param level]
##
func get_level_name(level: int) -> String:
	assert(_is_valid_level(level), "Trying to get the name for an invalid level")
	assert(
		_registered_levels & level != NONE,
		"Trying to get the name for a level that is not registered"
	)
	return _names[level]


##
## Registers a custom [param level] with the given [param name].
## The level needs to be a positive power of two (i.e. [code]1 << 5[/code]) lower than
## [enum MAX_LEVEL] that is not already registered, which allows more flexibility than just
## strict numerical order when enabling/disabling them.
## Since the predefined levels are not consecutive, custom levels can be registered between them
## to be ordered by priority (i.e. to be used with [method enable_levels_from]).
##
func register_level(level: int, name: String) -> void:
	assert(
		_is_valid_level(level),
		"Level must be a power of two, greater than NONE and lower than MAX_LEVEL (%d)" % MAX_LEVEL
	)
	assert(_registered_levels & level == NONE, "Level already exists. It will be overwritten")
	var is_unique_name = true
	var lc_name = name.to_lower()
	for k in _names:
		if _names[k].to_lower() == lc_name:
			is_unique_name = false
			break
	assert(
		is_unique_name,
		'A level with name "%s" already exists. Please provide an unique name' % name
	)
	_registered_levels |= level
	_names[level] = name
	_recalculate_is_stack_needed()
	if _send_to_editor:
		HanpekiLoggerEditorTransport._send_levels(_names)


##
## Deregisters the given custom [param level].
## Predefined levels ([constant PREDEFINED_LEVELS]) can't be deregistered, as they are used by
## the built-in methods ([method debug], [method info], etc.)
##
func deregister_level(level: int) -> void:
	assert(_is_valid_level(level), "Trying to deregister an invalid level")
	if level & PREDEFINED_LEVELS != NONE:
		assert(false, "Predefined levels can't be deregistered")
		return
	assert(
		_registered_levels & level != NONE, "Trying to deregister a level that is not registered"
	)
	_registered_levels &= ~level
	_names.erase(level)
	_recalculate_is_stack_needed()
	if _send_to_editor:
		HanpekiLoggerEditorTransport._send_levels(_names)


##
## Sets the given [param level] as [param enabled] or not
##
func set_level(level: int, enabled: bool) -> void:
	assert(
		level == NONE || level == MAX_LEVEL || _is_valid_level(level),
		"Trying to set an invalid level"
	)
	assert(_registered_levels & level != NONE, "Trying to set an unregistered level")
	if enabled:
		_level |= level
	else:
		_level &= ~level


##
## Enable all levels higher or equal than the given [param level].
## Useful if all the defined levels are sorted from the least important (1) to the most
## important (2^n) like most libraries do.
## If [member NONE] is given, every level will be enabled.
## If [member MAX_LEVEL] is given, every level will be disabled.
##
func enable_levels_from(level: int) -> void:
	if level == NONE:
		_level = _registered_levels
		return

	if level == MAX_LEVEL:
		_level = NONE
		return

	assert(_is_valid_level(level), "Trying to enable levels but an invalid value was given")
	assert(_registered_levels & level != NONE, "Trying to set an unregistered level")
	_level = ~(level - 1) & _registered_levels


##
## Sets the default stack mode used by the transports inheriting it
## ([enum StackLevelConfig.INHERIT], which is their default), as a [enum StackLevelConfig] for all
## levels or per level via [code]Dictionary[int, StackLevelConfig][/code] (levels not included
## won't provide any stack).
## Transports with their own stack mode override this one.
## [enum StackLevelConfig.INHERIT] is only valid for transports.
##
func set_stack_mode(config: Variant) -> void:
	var mode = Transport._eval_provide_stack(config)
	if typeof(mode) == TYPE_INT:
		assert(
			mode != Transport.StackLevelMode.INHERIT,
			"StackLevelConfig.INHERIT can't be used in the logger stack mode"
		)
	else:
		assert(
			!mode.values().has(Transport.StackLevelMode.INHERIT),
			"StackLevelConfig.INHERIT can't be used in the logger stack mode"
		)
	_stack_mode = mode
	_recalculate_is_stack_needed()


##
## Adds a transport to process the messages. Messages will be provided to
## transports in the order they are added.
## A transport can only be attached to one logger at a time. Use [method remove_transport]
## before adding it to a different one.
##
func add_transport(transport: Transport) -> void:
	var current = transport._logger.get_ref() if transport._logger else null
	if current == self:
		assert(false, "Trying to add a transport that was already added to this logger")
		return
	if current:
		assert(false, "Trying to add a transport that is already attached to another logger")
		return
	transport._logger = weakref(self)
	_transports.append(transport)
	_recalculate_is_stack_needed()


##
## Removes a registered transport.
## Providing an unknown transport will return false, but won't throw an error.
##
func remove_transport(transport: Transport) -> bool:
	var i = _transports.find(transport)
	if i == -1:
		return false
	_transports.remove_at(i)
	transport._logger = null
	_recalculate_is_stack_needed()
	return true


##
## Returns a [HanpekiLogger] with the [param ns] namespace bound, where logging the methods
## don't need the [code]ns[/code] parameter anymore as they will use the provided [param ns]
##
func bind_ns(ns: StringName) -> WithBoundNs:
	if _send_to_editor:
		HanpekiLoggerEditorTransport._send_namespace(ns)
	return WithBoundNs.new(ns, self)


##
## Logs the given [param msg] with level = [enum HanpekiLogger.DEBUG] and an optional [param ns]
##
func debug(msg: String, ns: StringName = NS_UNDEFINED) -> void:
	_message(DEBUG, msg, ns)


##
## Logs the given [param msg] with level = [enum HanpekiLogger.INFO] and an optional [param ns]
##
func info(msg: String, ns: StringName = NS_UNDEFINED) -> void:
	_message(INFO, msg, ns)


##
## Logs the given [param msg] with level = [enum HanpekiLogger.CORE] and an optional [param ns]
##
func core(msg: String, ns: StringName = NS_UNDEFINED) -> void:
	_message(CORE, msg, ns)


##
## Logs the given [param msg] with level = [enum HanpekiLogger.WARN] and an optional [param ns]
##
func warn(msg: String, ns: StringName = NS_UNDEFINED) -> void:
	_message(WARN, msg, ns)


##
## Logs the given [param msg] with level = [enum HanpekiLogger.ERROR] and an optional [param ns]
##
func error(msg: String, ns: StringName = NS_UNDEFINED) -> void:
	_message(ERROR, msg, ns)


##
## Logs the given [param msg] with level = [enum HanpekiLogger.FATAL] and an optional [param ns]
##
func fatal(msg: String, ns: StringName = NS_UNDEFINED) -> void:
	_message(FATAL, msg, ns)


##
## Logs a [param msg] in a custom [param level] with an optional [param ns]
##
func message(level: int, msg: String, ns: StringName = NS_UNDEFINED) -> void:
	assert(_is_valid_level(level), "Trying to send a message using an invalid level")
	assert(_registered_levels & level != NONE, "Trying to use an unregistered level")
	_message(level, msg, ns)


##
## Internal implementation of every logging method, deciding if the message needs to be processed.
## [param ns_level] is the level of the [WithBoundNs] logging the message, which can disable
## levels only for its namespace. It's omitted ([enum INHERIT]) when logging directly.
## Messages disabled by levels still reach the editor transport (when running from the editor),
## so they can be filtered in the editor instead.
##
func _message(level: int, msg: String, ns: StringName, ns_level: int = INHERIT) -> void:
	var enabled = level & _level != NONE && (ns_level == INHERIT || ns_level & level != NONE)
	# stop as soon as possible when nothing needs the message
	if !enabled && !_send_to_editor:
		return
	var transports: Array[Transport] = []
	if enabled:
		transports = _get_active_transports(level)
	if transports.is_empty() && !_send_to_editor:
		return

	var msg_data = MsgData.new()
	msg_data.utime = Time.get_ticks_msec()
	@warning_ignore("integer_division")
	msg_data.time = (_start_unix_ms + msg_data.utime) / 1000
	msg_data.level = level
	msg_data.level_name = _names[level]
	msg_data.msg = msg
	msg_data.ns = ns

	# the editor transport always receives the full stack
	if _send_to_editor || _stack_needed.has(level):
		var stack = get_stack()
		if stack:
			var source = stack[0].source
			# stack[0] is the get_stack() call
			# the real origin can be stack[1] when calling the Hanpeki.message method directly,
			# or stack[2] when calling any level method or using WithBoundsNs
			# but basically, is the first entry out of the current file
			for i in range(stack.size()):
				var s = stack[i]
				if s.source != source:
					msg_data.stack = stack.slice(i)
					break

	# the editor transport is always the first one
	if _send_to_editor:
		HanpekiLoggerEditorTransport._send_entry(msg_data)
	for transport in transports:
		transport.process(msg_data)

	# Stop the execution if a breakpoint is set for this message in the editor `Logs` dock, after
	# every transport processed it. The log call is a few frames below in the debugger stack.
	if _send_to_editor && HanpekiLoggerEditorTransport._should_break(level, ns):
		HanpekiLoggerEditorTransport._notify_break(msg_data)
		breakpoint


##
## Converts a level given as an [int], or as its name ([String] or [StringName],
## case-insensitive) into its [int] value.
## Ints are returned as they are, to be validated by the method using them (as some of them accept
## special values like [enum NONE]). Returns [code]null[/code] for unknown names or other types.
##
func _resolve_level(value: Variant) -> Variant:
	var type = typeof(value)
	if type == TYPE_INT:
		return value
	if type == TYPE_STRING || type == TYPE_STRING_NAME:
		return get_level_from_name(value)
	return null


##
## Check if a [param level] is valid: a positive power of two lower than [enum MAX_LEVEL]
## ([enum MAX_LEVEL] is reserved and never a valid level)
##
static func _is_valid_level(level: int) -> bool:
	# must be power of two
	if (level & (level - 1)) != 0:
		return false
	return level > 0 && level < MAX_LEVEL


##
## Called on instanciation.
## It checks that a proper Options object has been provided, and encourages to use the static
## method [method create] as a constructor/builder.
##
func _init(options: Options) -> void:
	assert(options, "No options found. Please use HanpekiLogger.create()")
	# checked before applying the options, so registered custom levels are sent to the editor
	_send_to_editor = HanpekiLoggerEditorTransport.is_available()
	if _send_to_editor:
		HanpekiLoggerEditorTransport._on_logger_created(_names)
	set_options(options)


##
## Get the evaluated stack mode of the logger for the given [param level]
##
func _get_stack_mode(level: int) -> Transport.StackLevelMode:
	var mode = (
		_stack_mode
		if typeof(_stack_mode) == TYPE_INT
		else _stack_mode.get(level, Transport.StackLevelMode.NONE)
	)
	# INHERIT is not valid for the logger, as there's nothing to inherit from
	if mode == Transport.StackLevelMode.INHERIT:
		return Transport.StackLevelMode.NONE
	return mode


##
## Calculate for which levels the stack is needed, based on the stack mode of the logger and the
## attached transports, and stores it in [member _stack_needed].
## Consider this method Protected, as it's called internaly by the transports
## when setting new options (and internally when the logger stack mode changes, levels are
## registered or deregistered, or transports are added or removed)
##
func _recalculate_is_stack_needed() -> void:
	_stack_needed.clear()
	for level in _names:
		var logger_mode = _get_stack_mode(level)
		for transport in _transports:
			if (
				transport._resolve_stack_mode(level, logger_mode)
				!= Transport.StackLevelMode.NONE
			):
				_stack_needed[level] = true
				break


##
## Gets the list of transports to use for a given [param level]
## (this could have been a one-line lambda with filter, but this is supposed to be faster)
##
func _get_active_transports(level: int) -> Array[Transport]:
	var res: Array[Transport]
	for transport in _transports:
		var transport_level = _level if transport._level == INHERIT else transport._level
		if transport_level & level != NONE:
			res.append(transport)
	return res


##
## Object storing the options to create [HanpekiLogger] instances via [method HanpekiLogger.create]
## or to be used in [method HanpekiLogger.set_options]
##
class Options:
	## List of custom levels to add (appart from the default ones) as
	## [code]{ level: int, name: string }[/code]
	var custom_levels: Array[Dictionary]
	## Minimum level set to be enabled with [member HanpekiLogger.enable_levels_from]
	## Can be provided as the int value or the level name (case-insensitive)
	## Leave empty to use only [code]levels[/code] or the default levels
	var level: Variant
	## List of active levels. Any other level will be disabled
	## Each level can be provided as the int value or the level name (case-insensitive)
	## [enum NONE] is accepted but doesn't enable any level, so [code][NONE][/code] can be used
	## to disable every level
	## Leave empty to use only [code]level[/code] or the default levels
	var levels: Array[Variant]
	## Default stack mode for the transports inheriting it, applied with
	## [method HanpekiLogger.set_stack_mode].
	## Can be provided both as [enum StackLevelConfig] (same for all levels)
	## or per-level via [code]Dictionary[int, StackLevelConfig][/code].
	## Leave to [code]null[/code] to keep the current one ([constant DEFAULT_STACK_LEVEL] for
	## new instances).
	##
	## Note that the stack is only available in release builds when the project setting
	## [code]debug/settings/gdscript/always_track_call_stacks[/code] is enabled.
	## See [method get_stack] for details.
	var stack_mode: Variant


##
## A Transport is an abstract class that processes messages to log in their own way
##
class Transport:
	## Available ways to format the time via [member _get_time_str]
	enum TimeFormat {
		## Formats the time as the local system
		SYSTEM_TIME,
		## Formats the date and the time as the local system time
		SYSTEM_DATE_TIME,
		## Formats the time as the UTC time
		UTC_TIME,
		## Formats the time as the UTC date and time
		UTC_DATE_TIME,
		## Formats the time as the ellapsed time since the game started
		RELATIVE,
	}

	## Define what stack information to include in the mesage data passed to transports
	enum StackLevelMode {
		## Special value to be used by transports to use the logger stack mode
		INHERIT = -1,
		## Include no stack information
		NONE,
		## Only provide the origin (where the log was called from)
		## Note that this is only possible if the stack information is available
		ORIGIN,
		## Provide the full stack
		## Note that this is only possible if the stack information is available
		FULL,
	}

	## Default colors for the predefined levels, shared by the predefined transports so they are
	## displayed consistently (each transport can still customize them)
	const DEFAULT_LEVEL_COLORS: Dictionary[int, Color] = {
		HanpekiLogger.DEBUG: Color(0.6, 0.6, 0.6),
		HanpekiLogger.INFO: Color(0.35, 0.8, 1.0),
		HanpekiLogger.CORE: Color(0.4, 0.85, 0.4),
		HanpekiLogger.WARN: Color(1.0, 0.85, 0.3),
		HanpekiLogger.ERROR: Color(1.0, 0.4, 0.4),
		HanpekiLogger.FATAL: Color(1.0, 0.2, 0.5),
	}
	## Default color for levels without a specific one (usually custom levels)
	const DEFAULT_CUSTOM_LEVEL_COLOR = Color(0.85, 0.85, 0.85)
	## Default color for namespaces without a specific one
	const DEFAULT_NS_COLOR = Color(0.8, 0.8, 0.8)

	## Level to use by the transport, by default the same as the logger where it's registered
	var _level: int = HanpekiLogger.INHERIT
	## How to format the time with [member _get_time_str]
	var _time_format: TimeFormat = TimeFormat.SYSTEM_TIME
	## Timezone offset in secs
	var _time_bias: int
	## Evaluated [member Options.stack_mode]: StackLevelMode | Dictionary[int, StackLevelMode]
	var _stack_mode: Variant = StackLevelMode.INHERIT
	## Associated logger instance when attached (WeakRef | null)
	var _logger: WeakRef = null

	##
	## Apply an [param options] object. Providing [code]null[/code] resets the default options.
	##
	func set_options(options: Options) -> void:
		if !options:
			options = Options.new()
		_level = options.level
		_time_format = options.time_format
		_stack_mode = _eval_provide_stack(options.stack_mode)
		# if attached, the logger needs to recalculate its stack requirements with the new mode
		var logger = _logger.get_ref() if _logger else null
		if logger:
			(logger as HanpekiLogger)._recalculate_is_stack_needed()

	##
	## Level to use by this Transport independently from the one set in the logger.
	## Note that it works as an AND operation. If the logger has a level disabled, the messages
	## won't reach the Transport, so this is used mainly to disable levels in the Transport
	##
	func set_level(level: int, enabled: bool) -> void:
		assert(HanpekiLogger._is_valid_level(level), "Trying to set an invalid level")
		if enabled:
			_level |= level
		else:
			_level &= ~level

	##
	## How to format the time displayed in the messages logged by this transport
	##
	func set_time_format(time_format: TimeFormat) -> void:
		_time_format = time_format

	##
	## Method called when the transport needs to log an already "parsed" message
	##
	func process(_data: MsgData) -> void:
		assert(false, "HanpekiLogger.Transport is an abstract class that must be extended")

	##
	## Evaluates the [member Options.stack_mode] config based on the current environment.
	## The returned value will vary depending on the provided [param config]:
	## - If given a [enum StackLevelConfig], a single [enum StackLevelMode] will be returned.
	## - In the case of being given a [code]Dictionary[int, StackLevelConfig][/code], then a
	## [code]Dictionary[int, StackLevelMode][/code] will be returned
	##
	static func _eval_provide_stack(config: Variant) -> Variant:
		var is_debug = OS.is_debug_build()

		if typeof(config) == TYPE_INT:
			return _eval_provide_stack_value(config, is_debug)

		var res: Dictionary[int, StackLevelMode] = {}

		for level in config:
			res[level] = _eval_provide_stack_value(config[level], is_debug)

		return res

	##
	## Evaluates a single [enum StackLevelConfig] value based on the current environment.
	## Returns a single [enum StackLevelMode] value.
	##
	static func _eval_provide_stack_value(
		config: StackLevelConfig,
		is_debug: bool) -> StackLevelMode:
		if config == StackLevelConfig.INHERIT:
			return StackLevelMode.INHERIT
		if config == StackLevelConfig.NONE:
			return StackLevelMode.NONE
		if config == StackLevelConfig.ORIGIN:
			return StackLevelMode.ORIGIN
		if config == StackLevelConfig.FULL:
			return StackLevelMode.FULL
		if config == StackLevelConfig.ORIGIN_IF_DEBUG:
			return StackLevelMode.ORIGIN if is_debug else StackLevelMode.NONE
		if config == StackLevelConfig.FULL_IF_DEBUG:
			return StackLevelMode.FULL if is_debug else StackLevelMode.NONE
		if config == StackLevelConfig.ORIGIN_IF_PROD:
			return StackLevelMode.ORIGIN if !is_debug else StackLevelMode.NONE
		if config == StackLevelConfig.FULL_IF_PROD:
			return StackLevelMode.FULL if !is_debug else StackLevelMode.NONE
		assert(false, "Unknown StackLevelConfig value: %s" % config)
		return StackLevelMode.FULL if is_debug else StackLevelMode.NONE

	##
	## Resolves the stack mode of this transport for the given [param level], given the
	## [param logger_mode] of the logger for the same level.
	## [enum StackLevelMode.INHERIT] and levels not included in a per-level configuration
	## use the [param logger_mode]. Otherwise the transport mode overrides it.
	##
	func _resolve_stack_mode(level: int, logger_mode: StackLevelMode) -> StackLevelMode:
		var mode = (
			_stack_mode
			if typeof(_stack_mode) == TYPE_INT
			else _stack_mode.get(level, StackLevelMode.INHERIT)
		)
		if mode == StackLevelMode.INHERIT:
			return logger_mode
		return mode

	##
	## Get the stack mode to use for the given [param level], based on the configuration of this
	## transport and the logger it's attached to (see [method _resolve_stack_mode])
	##
	func _get_stack_mode(level: int) -> StackLevelMode:
		var logger = _logger.get_ref() if _logger else null
		if !logger:
			return StackLevelMode.NONE
		return _resolve_stack_mode(level, (logger as HanpekiLogger)._get_stack_mode(level))

	func _init() -> void:
		_time_bias = Time.get_time_zone_from_system().bias * 60

	## Get the time to log for the given [param data]
	func _get_time_str(data: MsgData) -> String:
		if _time_format == TimeFormat.RELATIVE:
			@warning_ignore("integer_division")
			var elapsed = Time.get_time_dict_from_unix_time(data.utime / 1000)
			var elapsed_ms = data.utime % 1000
			return (
				"%02d:%02d:%02d.%03d"
				% [elapsed.hour, elapsed.minute, elapsed.second, elapsed_ms]
			)

		var unix = (
			data.time
			if (_time_format == TimeFormat.UTC_TIME || _time_format == TimeFormat.UTC_DATE_TIME)
			else data.time + _time_bias
		)
		# milliseconds need to be calculated the same way as data.time to be consistent
		var ms = (HanpekiLogger._start_unix_ms + data.utime) % 1000

		if _time_format == TimeFormat.UTC_TIME || _time_format == TimeFormat.SYSTEM_TIME:
			var day_time = Time.get_time_dict_from_unix_time(unix)
			return "%02d:%02d:%02d.%03d" % [day_time.hour, day_time.minute, day_time.second, ms]

		var time = Time.get_datetime_dict_from_unix_time(unix)
		return (
			"%04d-%02d-%02d %02d:%02d:%02d.%03d"
			% [time.year, time.month, time.day, time.hour, time.minute, time.second, ms]
		)

	## Get the stack as a string for the given [param data] based on the current settings
	func _get_stack_str(data: MsgData) -> String:
		if !data.stack:
			return ""

		var mode = _get_stack_mode(data.level)
		if mode == StackLevelMode.NONE:
			return ""

		if mode == StackLevelMode.ORIGIN:
			var item = data.stack[0]
			return "\n  at: %s (%s:%d)" % [item.function, item.source, item.line]

		assert(mode == StackLevelMode.FULL)
		var res: Array[String] = []
		for i in range(data.stack.size()):
			var item = data.stack[i]
			res.append("[%d] %s (%s:%d)" % [i, item.function, item.source, item.line])
		return "\n  at: " + "\n      ".join(res)


	class Options:
		## Level to use by the transport. Defaults to use the one from the logger is attached to
		var level: int = INHERIT
		## How to format time in [member _get_time_str]
		var time_format: TimeFormat = TimeFormat.SYSTEM_TIME
		## Whether to include the stack of the log call in the data printed.
		## Can be provided both as [enum StackLevelConfig] (same for all levels)
		## or per-level via [code]Dictionary[int, StackLevelConfig][/code].
		## It's evaluated into [enum StackLevelMode] values when the options are set.
		##
		## Defaults to [enum StackLevelConfig.INHERIT], using the stack mode of the logger.
		## Levels not included in a per-level configuration also inherit it.
		## Any other value overrides the stack mode of the logger for this transport, either
		## providing more or less stack information.
		## Note that this is different from levels, where the logger acts as a limit.
		var stack_mode: Variant = StackLevelConfig.INHERIT


##
## Object storing the data to pass when calling [member Transport.process]
##
class MsgData:
	## message level
	var level: int
	## name of the message level
	var level_name: String
	## unix time (in seconds), calculated from [member utime] and the unix time when the app
	## started, so changes in the system clock while the app is running won't be reflected
	var time: int
	## milliseconds since the app started
	var utime: int
	## Result from [method get_stack] with the entries for the logger internal code
	## filtered out, so `stack[0]` will always be the line making the log call.
	## Will be [code]Array[Dictionary][/code] unless not available, in which case will be
	## [code]null[/code] (see [method get_stack] for details on how to enable for production builds)
	## It's only retrieved when any transport is going to use it, based on the stack mode of the
	## logger and the transports. Use [method Transport._get_stack_mode] to know how much of it
	## should be displayed by a transport.
	var stack: Variant
	## namespace
	var ns: StringName
	## message text
	var msg: String
	## metadata that can be added when logging
	var data: Variant # Array[Variant] | null


##
## A logger bound to a parent [HanpekiLogger] and a [code]namespace[/code].
## The transports and registered levels are the same as the parent logger.
## Only a few methods related to messaging are available, and these don't accept a
## [code]ns[/code] param. Instead, they always use the bound one.
## It can have its own [code]level[/code] for granular setting per namespace.
##
class WithBoundNs:
	## Bound namespace
	var _ns: StringName
	## Bound logger
	var _logger: HanpekiLogger
	## Local level to this instance
	var _level: int = INHERIT

	##
	## Enables or disables the given [param level] for this bound instance.
	## The [param level] must be registered in the parent [HanpekiLogger].
	##
	## Important: A level must be enabled both in this bound instance *and*
	## in the parent logger to take effect. Message flow works as follows:
	##
	## 1. `bound.message(level, msg)` is called.
	## 2. If the bound instance has [param level] disabled → the message is dropped.
	## 3. If the parent logger has [param level] disabled → the message is dropped.
	## 4. Only if both are enabled → the message is delivered to the parent’s transports.
	##
	func set_level(level: int, enabled: bool) -> void:
		assert(
			HanpekiLogger._is_valid_level(level),
			'Trying to set an invalid level in the Bound HanpekiLogger with namespace "%s"' % _ns
		)
		assert(
			_logger._names.has(level),
			(
				'Trying to set an unregistered level in the Bound HanpekiLogger with namespace "%s"'
				% _ns
			)
		)
		if enabled:
			_level |= level
		else:
			_level &= ~level

	##
	## Logs the given [param msg] with level = [enum HanpekiLogger.DEBUG] using the bound namespace
	##
	func debug(msg: String) -> void:
		_logger._message(DEBUG, msg, _ns, _level)

	##
	## Logs the given [param msg] with level = [enum HanpekiLogger.INFO] using the bound namespace
	##
	func info(msg: String) -> void:
		_logger._message(INFO, msg, _ns, _level)

	##
	## Logs the given [param msg] with level = [enum HanpekiLogger.CORE] using the bound namespace
	##
	func core(msg: String) -> void:
		_logger._message(CORE, msg, _ns, _level)

	##
	## Logs the given [param msg] with level = [enum HanpekiLogger.WARN] using the bound namespace
	##
	func warn(msg: String) -> void:
		_logger._message(WARN, msg, _ns, _level)

	##
	## Logs the given [param msg] with level = [enum HanpekiLogger.ERROR] using the bound namespace
	##
	func error(msg: String) -> void:
		_logger._message(ERROR, msg, _ns, _level)

	##
	## Logs the given [param msg] with level = [enum HanpekiLogger.FATAL] using the bound namespace
	##
	func fatal(msg: String) -> void:
		_logger._message(FATAL, msg, _ns, _level)

	##
	## Logs a [param msg] in a custom [param level] with the bound namespace
	##
	func message(level: int, msg: String) -> void:
		assert(HanpekiLogger._is_valid_level(level), "Trying to send a message using an invalid level")
		assert(_logger._registered_levels & level != NONE, "Trying to use an unregistered level")
		_logger._message(level, msg, _ns, _level)

	##
	## Called on instanciation.
	## It checks that a proper Options object has been provided, and encourages to use the static
	## method [method create] as a constructor/builder.
	##
	func _init(ns: StringName, logger: HanpekiLogger = null) -> void:
		assert(
			logger,
			(
				"Instance not provided. "
				+"Do not instanciate HanpekiLogger.WithNsBound directly, "
				+"instead use HanpekiLogger.bind_ns()"
			)
		)
		_ns = ns
		_logger = logger
