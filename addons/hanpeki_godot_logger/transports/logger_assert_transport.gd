##
## HanpekiLoggerAssertTransport is a [HanpekiLogger.Transport] that works with
## [HanpekiLogger] to trigger the [code]assert[/code] function based on the
## log message level, instead of printing messages to the console.
##
## It is recommended to add this as the last transport, so other transports
## (file, console, custom, etc.) can process the log first. This ensures that
## information is available before execution pauses when an assert is triggered.
##
## Note that asserts are not triggered in production builds.
##
class_name HanpekiLoggerAssertTransport extends HanpekiLogger.Transport

## Levels that will call [code]assert(false, data.msg)[/code]
var _assert_levels: Array[int]


##
## Constructor with [param options]
##
static func create(options: Options = null) -> HanpekiLoggerAssertTransport:
	var instance = HanpekiLoggerAssertTransport.new()
	if !options:
		options = Options.new()
	instance.set_options(options)
	instance._assert_levels = options.assert_levels
	return instance


func process(data: HanpekiLogger.MsgData) -> void:
	if _assert_levels.has(data.level):
		assert(false, data.msg)


class Options:
	extends Transport.Options
	## Levels that will call [code]assert(false, data.msg)[/code]
	var assert_levels: Array[int] = [HanpekiLogger.ERROR, HanpekiLogger.FATAL]
