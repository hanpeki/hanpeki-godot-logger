extends Node

#
# This class is set up in the project as a global called `Log`
#

# Example of custom levels, which can be defined if the predefined ones are not enough, can be
# "placed between" the predefined ones as they are not consecutive (in terms of importance)
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
		# Note that the editor `Logs` dock will still receive every log call, but the transports
		# will only output the ones that are ERROR or FATAL
		options.levels = [HanpekiLogger.FATAL, HanpekiLogger.ERROR]

	var instance = HanpekiLogger.create(options)

	# Only want to output logs to the console when developing.
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

	# We always want to output into a file
	var file_options = HanpekiLoggerFileTransport.Options.new()
	file_options.max_files = 10 # Customize how many files to keep, older ones are deleted
	var file_transport = HanpekiLoggerFileTransport.create(file_options)
	instance.add_transport(file_transport)

	# Set up the bound namespaces we want to expose, as the "raw" instance is not exposed
	# (could be, but this way we can control what namespaces are exposed and how they are used)
	global = instance.bind_ns(&"")
	scriptManager = instance.bind_ns(&"ScriptManager")
	coloredNamespace = instance.bind_ns(&"ColoredNamespace")
