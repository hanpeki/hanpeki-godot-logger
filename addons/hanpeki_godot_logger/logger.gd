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
	## Not really used, but available for consistency
	NONE = 0,
	## The lower level, only used for set the Logger silent
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
	## lower than this one (and greater than FATAL).
	## It can be used with [member enable_levels_from] to disable all logs
	MAX_LEVEL = 1 << 62 # (highest positive power of two in Godot: 2^62)
}

# This version is used in the build process for the plugin config and the zip filename
const VERSION = "1.0.0-rc.1"
## Value for undefined namespaces
const NS_UNDEFINED = &""

##
## Constructor with [param options]
##
static func create(options: Options) -> HanpekiLogger:
	var logger = HanpekiLogger.new()
	logger.set_options(options)
	return logger

## Name to display for each level
var _names: Dictionary[int, String] = {
	DEBUG: "Debug",
	INFO: "Info",
	CORE: "Core",
	WARN: "Warn",
	ERROR: "Error",
	FATAL: "Fatal",
}

## All registered levels, as they need to be unique at bit level (i.e. 1 | 2 | 4 ... 64)
var _registered_levels: int = DEBUG | INFO | CORE | WARN | ERROR | FATAL
## Levels to log, defaults to IMPORTANT, WARN, ERROR and FATAL
var _level: int = CORE | WARN | ERROR | FATAL

## List of added transports
var _transports: Array[Transport]

##
## Apply multiple settings at once from the given [param options] configuration
##
func set_options(options: HanpekiLogger.Options) -> void:
	for entry in options.custom_levels:
		if (!entry.has("level")):
			assert(false, 'wrong configuration in "custom_levels". "level" field not found')
			continue;
		if (!entry.has("name")):
			assert(false, 'wrong configuration in "custom_levels". "name" field not found')
			continue;
		register_level(entry.level, entry.name)

	if (options.level):
		enable_levels_from(options.level)

	# set levels only when provided (NONE can be provided explicitly)
	# if no levels are given, the defaults are kept
	if (options.levels.size() > 0):
		if (!options.level):
			_level = NONE
		for entry in options.levels:
			var level = null
			if (typeof(entry) == TYPE_INT):
				level = entry
			elif (typeof(entry) == TYPE_STRING):
				level = get_level_from_name(entry)
			if (level == null):
				assert(false, 'unknown level in "levels"')
			set_level(level, true)

##
## Retrieves the value of a level from its name (case-insensitive)
##
func get_level_from_name(name: StringName) -> Variant:
	var lc = name.to_lower()
	for level in _names:
		if (_names[level].to_lower() == lc):
			return level
	return null

##
## Retrieves the name of a given [param level]
##
func get_level_name(level: int) -> String:
	assert(_is_valid_level(level), "Trying to get the name for an invalid level")
	assert(_registered_levels & level != NONE, "Trying to get the name for a level that is not registered")
	return _names[level]

##
## Registers a custom [param level]. It needs to be greater than
## [enum HanpekiLogger.FATAL] to avoid modifying the default levels,
## and a power of two (i.e. [code]1 << 5[/code]) which allows more flexibility
## than just strict numerical order when enabling/disabling them
##
func register_level(level: int, name: String) -> void:
	assert(
		_is_valid_level(level),
		"Level must be greater than FATAL (%d), lower than MAX_LEVEL (%d) and a power of two" % [
			FATAL, MAX_LEVEL
		])
	assert(_registered_levels & level == NONE, "Level already exists. It will be overwritten")
	var is_unique_name = true
	var lc_name = name.to_lower()
	for k in _names:
		if (_names[k].to_lower() == lc_name):
			is_unique_name = false
			break
	assert(is_unique_name, 'A level with name "%s" already exists. Please provide an unique name')
	_registered_levels |= level
	_names[level] = name

##
## Deregisters the given [param level]. It needs to be greater than
## [enum HanpekiLogger.FATAL] to avoid modifying the default levels
##
func deregister_level(level: int) -> void:
	assert(_is_valid_level(level), "Trying to deregister an invalid level")
	assert(_registered_levels & level != NONE, "Trying to deregister a level that is not registered")
	_registered_levels &= ~level
	_names.erase(level)

##
## Sets the given [param level] as [param enabled] or not
##
func set_level(level: int, enabled: bool) -> void:
	assert(_is_valid_level(level), "Trying to set an invalid level")
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
	assert(_is_valid_level(level), "Trying to enable levels but an invalid value was given")
	assert(level == NONE || _registered_levels & level != NONE, "Trying to set an unregistered level")
	_level = ~(level - 1) & _registered_levels

##
## Adds a transport to process the messages. Messages will be provided to
## transports in the order they are added.
##
func add_transport(transport: Transport) -> void:
	_transports.push_back(transport)

##
## Returns a [HanpekiLogger] with the [param ns] namespace bound, where logging the methods
## don't need the [code]ns[/code] parameter anymore as they will use the provided [param ns]
##
func bind_ns(ns: StringName) -> WithBoundNs:
	var bound = WithBoundNs.new()
	bound._logger = self
	bound._ns = ns
	return bound

##
## Logs the given [param msg] with level = [enum HanpekiLogger.DEBUG] and an optional [param ns]
##
func debug(msg: String, ns: StringName = NS_UNDEFINED) -> void:
	message(DEBUG, msg, ns)

##
## Logs the given [param msg] with level = [enum HanpekiLogger.INFO] and an optional [param ns]
##
func info(msg: String, ns: StringName = NS_UNDEFINED) -> void:
	message(INFO, msg, ns)

##
## Logs the given [param msg] with level = [enum HanpekiLogger.CORE] and an optional [param ns]
##
func core(msg: String, ns: StringName = NS_UNDEFINED) -> void:
	message(CORE, msg, ns)

##
## Logs the given [param msg] with level = [enum HanpekiLogger.WARN] and an optional [param ns]
##
func warn(msg: String, ns: StringName = NS_UNDEFINED) -> void:
	message(WARN, msg, ns)

##
## Logs the given [param msg] with level = [enum HanpekiLogger.ERROR] and an optional [param ns]
##
func error(msg: String, ns: StringName = NS_UNDEFINED) -> void:
	message(ERROR, msg, ns)

##
## Logs the given [param msg] with level = [enum HanpekiLogger.FATAL] and an optional [param ns]
##
func fatal(msg: String, ns: StringName = NS_UNDEFINED) -> void:
	message(FATAL, msg, ns)

##
## Logs a [param msg] in a custom [param level] with an optional [param ns]
##
func message(level: int, msg: String, ns: StringName = NS_UNDEFINED) -> void:
	assert(_is_valid_level(level), "Trying to send a message using an invalid level")
	assert(_registered_levels & level != NONE, "Trying to use an unregistered level")

	if (level & _level == NONE): return
	var transports = _get_active_transports(level)
	if (transports.size() == NONE): return

	var msgData = MsgData.new()
	msgData.time = Time.get_unix_time_from_system()
	msgData.utime = Time.get_ticks_msec()
	msgData.level = level
	msgData.level_name = _names[level]
	msgData.msg = msg
	msgData.ns = ns

	for transport in transports:
		transport.process(msgData)

##
## Check if a level is valid
##
static func _is_valid_level(level: int, custom: bool = false) -> bool:
	# must be power of two
	if (level & (level - 1)) != 0: return false
	return (
		# custom levels must be in a valid range
		(level > FATAL && level < MAX_LEVEL) if custom
		# in any case, they should be positive
		else (level > 0 && level <= MAX_LEVEL)
	)

##
## Gets the list of transports to use for a given [param level]
## (this could have been a one-line lambda with filter, but this is supposed to be faster)
##
func _get_active_transports(level: int) -> Array[Transport]:
	var res: Array[Transport]
	for transport in _transports:
		var transportLevel = _level if transport._level == INHERIT else transport._level
		if (transportLevel & level != NONE):
			res.append(transport)
	return res


##
## Object storing the options to create [HanpekiLogger] instances via [member HanpekiLogger.create]
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
	## Leave empty to use only [code]level[/code] or the default levels
	var levels: Array[Variant]


##
## A Transport is an abstract class that processes messages to log in their own way
##
class Transport:
	## Level to use by the transport, by default the same as the logger where it's registered
	var _level: int = HanpekiLogger.INHERIT
	## How to format the time with [member _get_time_str]
	var _time_format: TimeFormat = TimeFormat.SYSTEM_TIME
	## Timezone offset in secs
	var _time_bias: int

	##
	## Apply an [param options] object
	##
	func set_options(options: Options) -> void:
		_level = HanpekiLogger.INHERIT if options == null else options.level
		_time_format = HanpekiLogger.Transport.TimeFormat.SYSTEM_TIME if options == null else options.time_format

	##
	## Level to use by this Transport independently from the one set in the logger.
	## Note that it works as an AND operation. If the logger has a level disabled, the messages
	## won't reach the Transport, so this is used mainly to disable levels in the Transport
	##
	func set_level(level: int, enabled: bool) -> void:
		assert(HanpekiLogger._is_valid_level(level), "Trying to set an invalid level")
		if (enabled):
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
		assert(false, "%s is an abstract class that must be extended" % get_class())

	func _init() -> void:
		_time_bias = Time.get_time_zone_from_system().bias * 60

	## Get the time to log for the given [param data]
	func _get_time_str(data: MsgData) -> String:
		if (_time_format == TimeFormat.RELATIVE):
			@warning_ignore("integer_division")
			var time = Time.get_time_dict_from_unix_time(data.utime / 1000)
			var ms = data.utime % 1000
			return "%02d:%02d:%02d.%03d" % [time.hour, time.minute, time.second, ms]
		else:
			var unix = (data.time
				if (_time_format == TimeFormat.UTC_TIME || _time_format == TimeFormat.UTC_DATE_TIME)
				else data.time + _time_bias)
			var ms = data.utime % 1000

			if (_time_format == TimeFormat.UTC_TIME || _time_format == TimeFormat.SYSTEM_TIME):
				var time = Time.get_time_dict_from_unix_time(unix)
				return "%02d:%02d:%02d.%03d" % [time.hour, time.minute, time.second, ms]
			else:
				var time = Time.get_datetime_dict_from_unix_time(unix)
				return "%04d-%02d-%02d %02d:%02d:%02d.%03d" % [
					time.year, time.month, time.day,
					time.hour, time.minute, time.second,
					ms
				]

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

	class Options:
		## Level to use by the transport. Defaults to use the one from the logger is attached to
		var level: int = INHERIT
		## How to format time in [member _get_time_str]
		var time_format: TimeFormat = TimeFormat.SYSTEM_TIME

##
## Object storing the data to pass when calling [member Transport.process]
##
class MsgData:
	## message level
	var level: int
	## name of the message level
	var level_name: String
	## unix time
	var time: int
	## milliseconds since the app started
	var utime: int
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
			'Trying to set an unregistered level in the Bound HanpekiLogger with namespace "%s"' % _ns
		)
		if enabled:
			_level |= level
		else:
			_level &= ~level

	##
	## Logs the given [param msg] with level = [enum HanpekiLogger.DEBUG] using the bound namespace
	##
	func debug(msg: String) -> void:
		if (!_isActive(DEBUG)): return
		_logger.message(DEBUG, msg, _ns)

	##
	## Logs the given [param msg] with level = [enum HanpekiLogger.INFO] using the bound namespace
	##
	func info(msg: String) -> void:
		if (!_isActive(INFO)): return
		_logger.message(INFO, msg, _ns)

	##
	## Logs the given [param msg] with level = [enum HanpekiLogger.CORE] using the bound namespace
	##
	func core(msg: String) -> void:
		if (!_isActive(CORE)): return
		_logger.message(CORE, msg, _ns)

	##
	## Logs the given [param msg] with level = [enum HanpekiLogger.WARN] using the bound namespace
	##
	func warn(msg: String) -> void:
		if (!_isActive(WARN)): return
		_logger.message(WARN, msg, _ns)

	##
	## Logs the given [param msg] with level = [enum HanpekiLogger.ERROR] using the bound namespace
	##
	func error(msg: String) -> void:
		if (!_isActive(ERROR)): return
		_logger.message(ERROR, msg, _ns)

	##
	## Logs the given [param msg] with level = [enum HanpekiLogger.FATAL] using the bound namespace
	##
	func fatal(msg: String) -> void:
		if (!_isActive(FATAL)): return
		_logger.message(FATAL, msg, _ns)

	##
	## Logs a [param msg] in a custom [param level] with the bound namespace
	##
	func message(level: int, msg: String) -> void:
		if (!_isActive(level)): return
		_logger.message(level, msg, _ns)

	##
	## Check if this bound instance is active for the given [param level].
	## Having the level set to [enum HanpekiLogger.INHERIT] will always return [code]true[/code]
	## for it to be checked in the bound logger.
	##
	func _isActive(level: int) -> bool:
		if (_level == HanpekiLogger.INHERIT): return true
		return _level & level != NONE
