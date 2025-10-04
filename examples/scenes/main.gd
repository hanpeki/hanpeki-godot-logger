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
	Log.global.debug("debug message")
	Log.global.info("info message")
	Log.global.core("core message")
	Log.global.warn("warn message") # Note, this will stop assert based on our config
	Log.global.error("error message") # Note, this will stop assert based on our config
	Log.global.fatal("fatal message") # Note, this will stop assert based on our config
	
	Log.scriptManager.debug("debug message")
	Log.scriptManager.info("info message")
	Log.scriptManager.core("core message")
	Log.scriptManager.warn("warn message") # Note, this will stop assert based on our config
	Log.scriptManager.error("error message") # Note, this will stop assert based on our config
	Log.scriptManager.fatal("fatal message") # Note, this will stop assert based on our config
