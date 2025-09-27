extends GutTest


##
## Test basic functions of a default instance
##
func test_default_instance() -> void:
	var instance = HanpekiLogger.new()
	assert_eq(instance._level, TestUtils.DEFAULT_LEVEL)

	var transport = HanpekiLoggerTestTransport.new()
	assert_eq(transport._level, HanpekiLogger.INHERIT)
	assert_eq(transport.get_processed().size(), 0)

	instance.add_transport(transport)

	instance.fatal("Fatal message")
	instance.error("Error message")
	instance.warn("Warn message")
	instance.core("Core message")
	instance.info("Info message")
	instance.debug("Debug message")

	assert_true(transport.has_processed_message("Fatal message"))
	assert_true(transport.has_processed_message("Error message"))
	assert_true(transport.has_processed_message("Warn message"))
	assert_true(transport.has_processed_message("Core message"))
	assert_false(transport.has_processed_message("Info message"))
	assert_false(transport.has_processed_message("Debug message"))

	var info = transport.get_processed_message("Fatal message", HanpekiLogger.FATAL)
	assert_eq(info.ns, &"")


##
## Test basic functions with namespace of a default instance
##
func test_default_instance_ns() -> void:
	var instance = HanpekiLogger.new()
	var transport = HanpekiLoggerTestTransport.new()
	instance.add_transport(transport)

	instance.fatal("Fatal message", &"Test NS")
	instance.error("Error message", &"Test NS")
	instance.warn("Warn message", &"Test NS")
	instance.core("Core message", &"Test NS")
	instance.info("Info message", &"Test NS")
	instance.debug("Debug message", &"Test NS")

	assert_true(transport.has_processed_message("Fatal message"))
	assert_true(transport.has_processed_message("Error message"))
	assert_true(transport.has_processed_message("Warn message"))
	assert_true(transport.has_processed_message("Core message"))
	assert_false(transport.has_processed_message("Info message"))
	assert_false(transport.has_processed_message("Debug message"))

	var info = transport.get_processed_message("Fatal message", HanpekiLogger.FATAL)
	assert_eq(info.ns, &"Test NS")


##
## Test getting the level value from a level name
##
func test_get_level_from_name() -> void:
	var instance = HanpekiLogger.new()

	instance.register_level(2 << 7, "Level 256")
	instance.register_level(2 << 11, "Level 2048")

	# Should work for predefined levels
	assert_eq(instance.get_level_from_name("Fatal"), HanpekiLogger.FATAL)
	assert_eq(instance.get_level_from_name("Debug"), HanpekiLogger.DEBUG)
	assert_eq(instance.get_level_from_name("Info"), HanpekiLogger.INFO)
	assert_eq(instance.get_level_from_name("Core"), HanpekiLogger.CORE)
	assert_eq(instance.get_level_from_name("Warn"), HanpekiLogger.WARN)
	assert_eq(instance.get_level_from_name("Error"), HanpekiLogger.ERROR)
	assert_eq(instance.get_level_from_name("Fatal"), HanpekiLogger.FATAL)

	# Should work for custom levels
	assert_eq(instance.get_level_from_name("Level 256"), 2 << 7)
	assert_eq(instance.get_level_from_name("Level 2048"), 2 << 11)

	# Should be case-insensitive when comparing names
	assert_eq(instance.get_level_from_name("Fatal"), HanpekiLogger.FATAL)
	assert_eq(instance.get_level_from_name("LEVEL 256"), 2 << 7)


##
## Test getting the name associated to a level value
##
func test_level_name() -> void:
	var instance = HanpekiLogger.new()

	instance.register_level(2 << 7, "Level 256")
	instance.register_level(2 << 11, "Level 2048")

	# Should work for predefined levels
	assert_eq(instance.get_level_name(HanpekiLogger.FATAL), "Fatal")
	assert_eq(instance.get_level_name(HanpekiLogger.DEBUG), "Debug")
	assert_eq(instance.get_level_name(HanpekiLogger.INFO), "Info")
	assert_eq(instance.get_level_name(HanpekiLogger.CORE), "Core")
	assert_eq(instance.get_level_name(HanpekiLogger.WARN), "Warn")
	assert_eq(instance.get_level_name(HanpekiLogger.ERROR), "Error")
	assert_eq(instance.get_level_name(HanpekiLogger.FATAL), "Fatal")

	# Should work for custom levels
	assert_eq(instance.get_level_name(2 << 7), "Level 256")
	assert_eq(instance.get_level_name(2 << 11), "Level 2048")
