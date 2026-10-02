extends Node

#
# This class is set up in the project as a global called `Log`
#

# Custom levels, which can be placed between the predefined ones as they are not consecutive
# Less important than DEBUG
const TRACE = HanpekiLogger.DEBUG >> 1
# More important than WARN, but less than ERROR
const IMPORTANT = HanpekiLogger.WARN << 1

# Colors used for the custom levels and namespaces, shared by the transports to be consistent
const TRACE_COLOR = Color(0.45, 0.45, 0.45)
const IMPORTANT_COLOR = Color(1.0, 0.6, 0.2)
const COLORED_NAMESPACE_COLOR = Color(0.6, 0.9, 0.6)

# Namespace for global logs
static var global: HanpekiLogger.WithBoundNs
# Namespace for logs related to the Script Manager
static var scriptManager: HanpekiLogger.WithBoundNs
# Namespace with custom colors, to compare it with the default ones
static var coloredNamespace: HanpekiLogger.WithBoundNs

##
## Initialize the Log class with the desired settings
##
## See scenes/main.gd to check how it's used
##
static func _init() -> void:
	var options = HanpekiLogger.Options.new()
	options.custom_levels.append_array(
		[
			{"level": TRACE, "name": "Trace"},
			{"level": IMPORTANT, "name": "Important"},
		]
	)
	if OS.is_debug_build():
		# On debug builds we want to see every log call, so setting the minimum level to
		# DEBUG (lowest level) achieves it
		options.level = HanpekiLogger.DEBUG
	else:
		# on production builds, only log errors
		options.levels = [HanpekiLogger.FATAL, HanpekiLogger.ERROR]

	var instance = HanpekiLogger.create(options)

	# Only want to output logs to the console when developing.
	# Same goes for stopping the code execution via assert on certain levels.
	if OS.is_debug_build():
		var console_transport = HanpekiLoggerConsoleTransport.create()
		console_transport.set_level_format(
			TRACE, "[color=#%s][{level}][/color] " % TRACE_COLOR.to_html(false)
		)
		console_transport.set_level_format(
			IMPORTANT, "[color=#%s][{level}][/color] " % IMPORTANT_COLOR.to_html(false)
		)
		console_transport.set_ns_format(
			&"ColoredNamespace",
			"[color=#%s] {ns} [/color]" % COLORED_NAMESPACE_COLOR.to_html(false)
		)
		instance.add_transport(console_transport)

		# Same colors for the editor `Logs` dock (only used when running from the editor)
		HanpekiLoggerEditorTransport.set_level_color(TRACE, TRACE_COLOR)
		HanpekiLoggerEditorTransport.set_level_color(IMPORTANT, IMPORTANT_COLOR)
		HanpekiLoggerEditorTransport.set_ns_color(&"ColoredNamespace", COLORED_NAMESPACE_COLOR)

		# By default AssertTransport stops on ERROR and FATAL. Let's set this to stop also on WARN:
		var assert_opt = HanpekiLoggerAssertTransport.Options.new()
		assert_opt.assert_levels = HanpekiLogger.FATAL | HanpekiLogger.ERROR | HanpekiLogger.WARN
		var assert_transport = HanpekiLoggerAssertTransport.create(assert_opt)
		instance.add_transport(assert_transport)

	# We always want to output into a file
	var file_transport = HanpekiLoggerFileTransport.create()
	instance.add_transport(file_transport)

	# Set up the bound namespaces we want to expose, as the "raw" instance is not exposed
	global = instance.bind_ns(&"")
	scriptManager = instance.bind_ns(&"ScriptManager")
	coloredNamespace = instance.bind_ns(&"ColoredNamespace")
