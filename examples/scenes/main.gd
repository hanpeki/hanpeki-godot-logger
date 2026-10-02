extends Node

##
## This scene shows the usage of the HanpekiLoger.
##
## Check singletons/log.gd to see how is configured
##
func _ready() -> void:
	test_logger()
	get_tree().quit()

func test_logger() -> void:
	# Custom levels are logged with `message`
	# Note that TRACE is lower than DEBUG, so it's not logged by the configured transports,
	# but it still appears in the editor `Logs` dock, which receives every message
	Log.global.message(Log.TRACE, "trace message")
	Log.global.debug("debug message")
	Log.global.info("info message")
	Log.global.core("core message")
	Log.global.warn("warn message")
	Log.global.message(Log.IMPORTANT, "important message")
	Log.global.error("error message")
	Log.global.fatal("fatal message")

	Log.scriptManager.message(Log.TRACE, "trace message")
	Log.scriptManager.debug("debug message")
	Log.scriptManager.info("info message")
	Log.scriptManager.core("core message")
	Log.scriptManager.warn("warn message")
	Log.scriptManager.message(Log.IMPORTANT, "important message")
	Log.scriptManager.error("error message")
	Log.scriptManager.fatal("fatal message")

	# Same messages with a namespace with custom colors (see singletons/log.gd), to compare them
	# with the default namespace formatting used by ScriptManager
	Log.coloredNamespace.message(Log.TRACE, "trace message")
	Log.coloredNamespace.debug("debug message")
	Log.coloredNamespace.info("info message")
	Log.coloredNamespace.core("core message")
	Log.coloredNamespace.warn("warn message")
	Log.coloredNamespace.message(Log.IMPORTANT, "important message")
	Log.coloredNamespace.message(HanpekiLogger.ERROR, "error message")
	Log.coloredNamespace.fatal("fatal message")
