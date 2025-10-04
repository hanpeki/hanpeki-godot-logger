extends Node

#
# This class is set up in the project as a global called `Log`
#

# Namespace for global logs
static var global: HanpekiLogger.WithBoundNs
# Namespace for logs related to the Script Manager
static var scriptManager: HanpekiLogger.WithBoundNs

##
## Initialize the Log class with the desired settings
##
## See scenes/main.gd to check how it's used
##
static func _init() -> void:
	
	var options = HanpekiLogger.Options.new()
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
		instance.add_transport(console_transport)
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
