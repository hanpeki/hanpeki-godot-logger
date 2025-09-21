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
	DEBUG = 1,
	## Informational messages to follow the code flow
	INFO = 1 << 1,
	## Important messages but not warning nor errors
	CORE = 1 << 2,
	## Unexpected, but non-breaking happenings
	WARN = 1 << 3,
	## Unexpected happening that might break parts when not handled
	ERROR = 1 << 4,
	## Only used for errors that make the app crash
	FATAL = 1 << 5,
	## Maximum level just for reference. Every custom defined level must be
	## lower than this one (and greater than FATAL).
	## It can be used with [member enable_levels_from] to disable all logs
	MAX_LEVEL = 1 << 63,
}

# This version is used in the build process for the plugin config and the zip filename
const VERSION = "1.0.0-rc.1"
## Name to display when an unregistered level is used
const LEVEL_DEFAULT_NAME = 'Unknown';
## Value for undefined namespaces
const NS_UNDEFINED = &""

##
## Constructor with [param options]
##
static func create(options: Options) -> HanpekiLogger:
	var logger = HanpekiLogger.new()

	for entry in options.custom_levels:
		if (!entry.has("level")):
			assert(false, 'wrong configuration in "custom_levels". "level" field not found')
			continue;
		var name = entry.get("name", LEVEL_DEFAULT_NAME)
		logger.register_level(entry.level, name)

	# set levels only when provided (NONE can be provided explicitly)
	# if no levels are given, the defaults are kept
	if (options.levels.size() > 0):
		logger._level = NONE
		for entry in options.levels:
			var level = null
			if (typeof(entry) == TYPE_INT):
				level = entry
			elif (typeof(entry) == TYPE_STRING):
				level = logger.get_level_from_name(entry)
			if (level == null):
				assert(false, 'unknown level in "levels"')
			logger.set_level(level, true)

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
		level > FATAL,
		"Level must be greater than FATAL (%d), lower than MAX_LEVEL (%d) and a power of two" % [
			FATAL, MAX_LEVEL
		])
	assert(_registered_levels & level == NONE, "Level already exist. It will be overwritten")
	_registered_levels |= level
	_names[level] = name

##
## Deregisters the given [param level]. It needs to be greater than
## [enum HanpekiLogger.FATAL] to avoid modifying the default levels
##
func deregister_level(level: int) -> void:
	assert(level > FATAL, "Level must be greater than FATAL (%d)" % FATAL)
	assert(_registered_levels & level != NONE, "Trying to deregister a level that is not registered")
	_registered_levels &= ~level
	_names.erase(level)

##
## Sets the given [param level] as [param enabled] or not
##
func set_level(level: int, enabled: bool) -> void:
	assert(_registered_levels & level != NONE, "Trying to set an unregistered level")
	if enabled:
		_level |= level
	else:
		_level &= ~level

##
## Adds a transport to process the messages. Messages will be provided to
## transports in the order they are added.
##
func add_transport(transport: Transport) -> void:
	_transports.push_back(transport)

##
## Returns a [HanpekiLogger] with the [param ns] namespace binded, where logging the methods
## don't need the [code]ns[/code] parameter anymore as they will use the provided [param ns]
##
func bind_ns(ns: StringName) -> WithBindedNs:
	var binded = WithBindedNs.new()
	binded._logger = self
	binded._ns = ns
	return binded

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
	assert(_registered_levels & level != NONE, "Trying to use an unregistered level")

	if (level & _level == NONE): return
	var transports = _get_active_transports(level)
	if (transports.size() == NONE): return

	var msgData = MsgData.new()
	msgData.time = Time.get_unix_time_from_system()
	msgData.utime = Time.get_ticks_msec()
	msgData.level = level
	msgData.level_name = _names.get(level, LEVEL_DEFAULT_NAME)
	msgData.msg = msg
	msgData.ns = ns

	for transport in transports:
		transport.process(msgData)

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
	## [code]{ level: int, name: string, color?: String | Color }[/code]
	var custom_levels: Array[Dictionary]
	## List of active levels. Any other level will be disabled
	## Can be provided as the int value or the level name (case-insensitive)
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
## A logger binded to a parent [HanpekiLogger] and a [code]namespace[/code].
## The transports and registered levels are the same as the parent logger.
## Only a few methods related to messaging are available, and these don't accept a [code]ns[/code]
## param. Instead, they always use the binded one.
## It can have its own [code]level[/code] for granular setting per namespace.
##
class WithBindedNs:
	## Binded namespace
	var _ns: StringName
	## Binded logger
	var _logger: HanpekiLogger
	## Local level to this instance
	var _level: int = INHERIT

	##
	## Sets the given [param level] as [param enabled] or not
	## The [param level] needs to be registered in the binded [HanpekiLogger]
	##
	func set_level(level: int, enabled: bool) -> void:
		assert(
			!_logger._names.has(level),
			'Trying to set an unregistered level in the Binded HanpekiLogger with namespace "%s"' % _ns
		)
		if enabled:
			_level |= level
		else:
			_level &= ~level

	##
	## Logs the given [param msg] with level = [enum HanpekiLogger.DEBUG] using the binded namespace
	##
	func debug(msg: String) -> void:
		if (!_isActive(DEBUG)): return
		_logger.message(DEBUG, msg, _ns)

	##
	## Logs the given [param msg] with level = [enum HanpekiLogger.INFO] using the binded namespace
	##
	func info(msg: String) -> void:
		if (!_isActive(INFO)): return
		_logger.message(INFO, msg, _ns)

	##
	## Logs the given [param msg] with level = [enum HanpekiLogger.CORE] using the binded namespace
	##
	func core(msg: String) -> void:
		if (!_isActive(CORE)): return
		_logger.message(CORE, msg, _ns)

	##
	## Logs the given [param msg] with level = [enum HanpekiLogger.WARN] using the binded namespace
	##
	func warn(msg: String) -> void:
		if (!_isActive(WARN)): return
		_logger.message(WARN, msg, _ns)

	##
	## Logs the given [param msg] with level = [enum HanpekiLogger.ERROR] using the binded namespace
	##
	func error(msg: String) -> void:
		if (!_isActive(ERROR)): return
		_logger.message(ERROR, msg, _ns)

	##
	## Logs the given [param msg] with level = [enum HanpekiLogger.FATAL] using the binded namespace
	##
	func fatal(msg: String) -> void:
		if (!_isActive(FATAL)): return
		_logger.message(FATAL, msg, _ns)

	##
	## Logs a [param msg] in a custom [param level] with the binded namespace
	##
	func message(level: int, msg: String) -> void:
		if (!_isActive(level)): return
		_logger.message(level, msg, _ns)

	##
	## Check if this binded instance is active for the given [param level].
	## Having the level set to [enum HanpekiLogger.INHERIT] will always return [code]true[/code]
	## for it to be checked in the binded logger.
	##
	func _isActive(level: int) -> bool:
		if (_level == HanpekiLogger.INHERIT): return true
		return _level & level != NONE
