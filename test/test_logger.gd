extends GutTest


##
## Test basic functions of a default instance
##
func test_default_instance() -> void:
	var instance = HanpekiLogger.create()
	assert_eq(instance._level, TestUtils.DEFAULT_LEVEL)

	var transport = HanpekiLoggerTestTransport.create()
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
	var instance = HanpekiLogger.create()
	var transport = HanpekiLoggerTestTransport.create()
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
	var instance = HanpekiLogger.create()

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
	var instance = HanpekiLogger.create()

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


##
## Test that the stack is disabled
##
func test_stack_disabled() -> void:
	# When disabled, it should be null
	var options = HanpekiLogger.Options.new()
	options.disable_stack = true
	var instance = HanpekiLogger.create(options)
	var transport_options = HanpekiLogger.Transport.Options.new()
	transport_options.stack_mode = HanpekiLogger.StackLevelConfig.NONE
	var transport = HanpekiLoggerTestTransport.create(transport_options)
	instance.add_transport(transport)

	assert_false(instance._provide_stack)

	instance.info("Info message")
	instance.warn("Warn message", "With NS")
	instance.message(HanpekiLogger.DEBUG, "Debug message")

	for msg in transport.get_processed():
		assert_null(msg.stack)


##
## Test that the stack is correctly provided
##
func test_stack() -> void:
	var options = HanpekiLogger.Options.new()
	options.level = HanpekiLogger.DEBUG
	var instance = HanpekiLogger.create(options)
	var transport = HanpekiLoggerTestTransport.create()
	instance.add_transport(transport)

	var bound = instance.bind_ns("NS")

	assert_typeof(instance._provide_stack, TYPE_DICTIONARY)

	# Test first the levels that should NOT include the stack
	instance.message(HanpekiLogger.DEBUG, "debug msg")
	instance.info("info msg")
	instance.core("core msg")

	for msg in transport.get_processed():
		assert_null(msg.stack)

	# Then test the levels that should include the stack
	transport.reset_processed()

	bound.warn("warn msg")
	bound.error("error msg")
	bound.message(HanpekiLogger.FATAL, "fatal msg")

	var function_name = get_stack()[0].function
	for msg in transport.get_processed():
		var stack = msg.stack as Array[Dictionary]
		assert_not_null(stack)
		assert_gt(stack.size(), 1)
		assert_eq(stack[0].function, function_name)
