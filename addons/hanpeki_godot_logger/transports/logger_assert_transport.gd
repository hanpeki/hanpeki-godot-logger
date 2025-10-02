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

## Union of the log levels that will call [code]assert(false, data.msg)[/code]
var _assert_levels: int


##
## Constructor with [param options]
##
static func create(options: Options = null) -> HanpekiLoggerAssertTransport:
	if !options:
		options = Options.new()
	return HanpekiLoggerAssertTransport.new(options)


func process(data: HanpekiLogger.MsgData) -> void:
	if data.level & _assert_levels != 0:
		assert(false, data.msg)


func set_options(options: Transport.Options) -> void:
	## Godot OOP is not the best...
	assert(
		options is Options,
		"HanpekiLoggerAssertTransport.setOptions requires HanpekiLoggerAssertTransport.Options"
	)
	super.set_options(options)
	_assert_levels = (options as Options).assert_levels


##
## Called on instanciation.
## It checks that a proper Options object has been provided, and encourages to use the static
## method [method create] as a constructor/builder.
##
func _init(options: Options) -> void:
	assert(options, "No options found. Please use HanpekiLoggerAssertTransport.create()")
	set_options(options)


class Options:
	extends Transport.Options
	## Union of the log levels that will call [code]assert(false, data.msg)[/code]
	var assert_levels: int = HanpekiLogger.ERROR | HanpekiLogger.FATAL
