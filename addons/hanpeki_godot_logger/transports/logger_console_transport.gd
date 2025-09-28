##
## HanpekiLoggerConsoleTransport is a [HanpekiLogger.Transport] that can be used with
## [HanpekiLogger] to output messages to the console, in plain or formatted text
##
class_name HanpekiLoggerConsoleTransport extends HanpekiLogger.Transport

## Whether to use formatting or not.
## Note that when formatting is enabled, spaces between elements are added in the BBTags
var _formatting: bool
## Format to apply to the time as a BBTag with [code]{time}[/code] replaced
var _datetime_format: String = "[bgcolor=#333033][color=grey] {time} [/color][/bgcolor]"
## Formats to apply to the levels as a BBTag with [code]{level}[/code] replaced
var _level_formats: Dictionary[int, String] = {
	DEBUG: "[color=grey][{level}][/color]",
	INFO: "[color=#5cf][{level}][/color] ",
	CORE: "[color=green][{level}][/color] ",
	WARN: "[color=yellow][{level}][/color] ",
	ERROR: "[color=red][{level}][/color]",
	FATAL: "[bgcolor=red][color=white][{level}][/color][/bgcolor]",
}
## Formats to apply to the levels as a BBTag with [code]{ns}[/code] replaced
var _ns_formats: Dictionary[StringName, String] = {}
## Format to apply when an unregistered level is used as a BBTag with [code]{level}[/code] replaced
var _level_default_format = "[{level}]"
## Format to apply when an unregistered namespace is used as a BBTag with [code]{ns}[/code] replaced
var _ns_default_format = "[bgcolor=#335][color=#eee] {ns} [/color][/bgcolor]"
## Format to display when the stack is logged as a BBTag with [code]{stack}[/code] replaced
var _stack_format = "[color=#99a]{stack}[/color]"


##
## Constructor with [param options]
##
static func create(options: Options = null) -> HanpekiLoggerConsoleTransport:
	var instance = HanpekiLoggerConsoleTransport.new()
	if !options:
		options = Options.new()
	instance.set_options(options)
	instance._formatting = options.formatting
	return instance


func process(data: HanpekiLogger.MsgData) -> void:
	var time = _get_time_str(data)

	if _formatting:
		var t = _datetime_format.replace("{time}", time)
		var level = _format_level(data)
		print_rich("%s%s%s%s%s" % [t, level, _format_ns(data), data.msg, _format_stack(data)])
	else:
		var ns = "" if data.ns == HanpekiLogger.NS_UNDEFINED else "[%s]" % data.ns
		print("%s %s[%s] %s%s" % [time, data.level_name, ns, data.msg, _get_stack_str(data)])


##
## Set the format to use when printing the level name, as a template string
## accepting BBTags, with the [code]{level}[/code] placeholder.
##
func set_level_format(level: int, format: String) -> void:
	_level_formats[level] = format


##
## Set the format to use when printing a namespace name without an explicit format configured,
## as a template string accepting BBTags with the [code]{level}[/code] placeholder.
##
func set_level_default_format(format: String) -> void:
	_level_default_format = format


##
## Set the format to use when printing a namespace name, as a template string
## accepting BBTags, with the [code]{ns}[/code] placeholder.
##
func set_ns_format(ns: StringName, format: String) -> void:
	_ns_formats[ns] = format


##
## Set the format to use when printing a level name without a format configured,
## (usually custom levels), as a template string accepting BBTags,
## with the [code]{level}[/code] placeholder.
##
func set_ns_default_format(format: String) -> void:
	_ns_default_format = format


##
## Set the format to use when printing a stack (if configured to do so and available),
## as a template string accepting BBTags, with the [code]{stack}[/code] placeholder.
##
func set_stack_format(format: String) -> void:
	_stack_format = format


func _format_level(data: HanpekiLogger.MsgData) -> String:
	var format = _level_formats.get(data.level, _level_default_format)
	return format.replace("{level}", data.level_name)


func _format_ns(data: HanpekiLogger.MsgData) -> String:
	if data.ns == HanpekiLogger.NS_UNDEFINED:
		return ""
	var format = _ns_formats.get(data.ns, _ns_default_format)
	return format.replace("{ns}", "[%s]" % data.ns)


func _format_stack(data: HanpekiLogger.MsgData) -> String:
	if !data.stack:
		return ""
	return _stack_format.replace("{stack}", _get_stack_str(data))


class Options:
	extends Transport.Options
	## Whether to use formatting or not
	var formatting: bool = true
