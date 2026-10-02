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
## Test resolving levels given as int, String or StringName into their int value
##
func test_resolve_level() -> void:
	var instance = HanpekiLogger.create()
	var custom_level = HanpekiLogger.DEBUG >> 1
	instance.register_level(custom_level, "Custom")

	# Ints are returned as they are (validated later by the method using them)
	assert_eq(instance._resolve_level(HanpekiLogger.WARN), HanpekiLogger.WARN)
	assert_eq(instance._resolve_level(HanpekiLogger.NONE), HanpekiLogger.NONE)
	assert_eq(instance._resolve_level(HanpekiLogger.MAX_LEVEL), HanpekiLogger.MAX_LEVEL)

	# Names, as String or StringName, case-insensitive (also for custom levels)
	assert_eq(instance._resolve_level("Warn"), HanpekiLogger.WARN)
	assert_eq(instance._resolve_level("FATAL"), HanpekiLogger.FATAL)
	assert_eq(instance._resolve_level(&"debug"), HanpekiLogger.DEBUG)
	assert_eq(instance._resolve_level(&"custom"), custom_level)

	# Unknown names and other types are not resolved
	assert_null(instance._resolve_level("Unknown"))
	assert_null(instance._resolve_level(&"Unknown"))
	assert_null(instance._resolve_level(null))
	assert_null(instance._resolve_level(1.0))
	assert_null(instance._resolve_level(true))
	assert_null(instance._resolve_level([HanpekiLogger.WARN]))


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
## Test that the stack is not provided when no transport needs it
##
func test_stack_disabled() -> void:
	# Enable every level so all the messages reach the transport
	var options = HanpekiLogger.Options.new()
	options.level = HanpekiLogger.DEBUG
	options.stack_mode = HanpekiLogger.StackLevelConfig.FULL
	var instance = HanpekiLogger.create(options)
	var transport_options = HanpekiLogger.Transport.Options.new()
	transport_options.stack_mode = HanpekiLogger.StackLevelConfig.NONE
	var transport = HanpekiLoggerTestTransport.create(transport_options)
	instance.add_transport(transport)

	# Even if the logger provides it, no transport is going to use it
	for level in instance._names:
		assert_false(instance._stack_needed.has(level))

	instance.info("Info message")
	instance.warn("Warn message", "With NS")
	instance.message(HanpekiLogger.DEBUG, "Debug message")

	assert_eq(transport.get_processed().size(), 3)
	for msg in transport.get_processed():
		assert_null(msg.stack)


##
## Test that the stack is correctly provided with the default configuration
##
func test_stack() -> void:
	var options = HanpekiLogger.Options.new()
	options.level = HanpekiLogger.DEBUG
	var instance = HanpekiLogger.create(options)
	var transport = HanpekiLoggerTestTransport.create()
	instance.add_transport(transport)

	var bound = instance.bind_ns("NS")

	# Test first the levels that should NOT include the stack
	instance.message(HanpekiLogger.DEBUG, "debug msg")
	instance.info("info msg")
	instance.core("core msg")

	assert_eq(transport.get_processed().size(), 3)
	for msg in transport.get_processed():
		assert_null(msg.stack)

	# Then test the levels that should include the stack
	transport.reset_processed()

	if OS.is_debug_build():
		bound.warn("warn msg")
	bound.error("error msg")
	bound.message(HanpekiLogger.FATAL, "fatal msg")

	var function_name = get_stack()[0].function
	assert_gt(transport.get_processed().size(), 0)
	for msg in transport.get_processed():
		var stack = msg.stack as Array[Dictionary]
		assert_not_null(stack)
		assert_gt(stack.size(), 1)
		assert_eq(stack[0].function, function_name)


##
## Test the default stack mode of the logger and transports.
## The logger one depends on the environment, and transports inherit it by default
##
func test_default_stack_mode() -> void:
	var is_debug = OS.is_debug_build()
	var expected: Dictionary[int, HanpekiLogger.Transport.StackLevelMode] = {
		HanpekiLogger.FATAL: HanpekiLogger.Transport.StackLevelMode.FULL,
		HanpekiLogger.ERROR: HanpekiLogger.Transport.StackLevelMode.ORIGIN,
		HanpekiLogger.WARN:
		(
			HanpekiLogger.Transport.StackLevelMode.ORIGIN
			if is_debug
			else HanpekiLogger.Transport.StackLevelMode.NONE
		),
	}
	var inherit = HanpekiLogger.Transport.StackLevelMode.INHERIT

	assert_eq_deep(HanpekiLogger.create()._stack_mode, expected)
	assert_eq(HanpekiLoggerTestTransport.create()._stack_mode, inherit)
	# Even when set_options is never called
	assert_eq(HanpekiLogger.Transport.new()._stack_mode, inherit)


##
## Test setting the stack mode of the logger, used as default by the transports inheriting it,
## while transports with their own stack mode override it
##
func test_logger_stack_mode() -> void:
	var options = HanpekiLogger.Options.new()
	options.level = HanpekiLogger.DEBUG
	options.stack_mode = HanpekiLogger.StackLevelConfig.FULL
	var instance = HanpekiLogger.create(options)
	var inherit_transport = HanpekiLoggerTestTransport.create()
	var override_options = HanpekiLogger.Transport.Options.new()
	override_options.stack_mode = HanpekiLogger.StackLevelConfig.FULL
	var override_transport = HanpekiLoggerTestTransport.create(override_options)
	instance.add_transport(inherit_transport)
	instance.add_transport(override_transport)

	# Set via options, for all levels
	assert_eq(instance._stack_mode, HanpekiLogger.Transport.StackLevelMode.FULL)
	assert_eq(
		inherit_transport._get_stack_mode(HanpekiLogger.DEBUG),
		HanpekiLogger.Transport.StackLevelMode.FULL
	)
	assert_true(instance._stack_needed.has(HanpekiLogger.DEBUG))

	# Set per level. Levels not included are disabled for the inheriting transports
	instance.set_stack_mode({HanpekiLogger.INFO: HanpekiLogger.StackLevelConfig.ORIGIN})
	assert_eq(
		inherit_transport._get_stack_mode(HanpekiLogger.DEBUG),
		HanpekiLogger.Transport.StackLevelMode.NONE
	)
	assert_eq(
		inherit_transport._get_stack_mode(HanpekiLogger.INFO),
		HanpekiLogger.Transport.StackLevelMode.ORIGIN
	)
	# But transports with their own stack mode are not affected
	assert_eq(
		override_transport._get_stack_mode(HanpekiLogger.DEBUG),
		HanpekiLogger.Transport.StackLevelMode.FULL
	)
	assert_true(instance._stack_needed.has(HanpekiLogger.DEBUG))
	instance.debug("Msg1")
	assert_not_null(override_transport.get_processed_message("Msg1").stack)

	# Disabled for all levels, the stack is only needed for the overriding transport
	instance.set_stack_mode(HanpekiLogger.StackLevelConfig.NONE)
	for level in instance._names:
		assert_true(instance._stack_needed.has(level))
	instance.remove_transport(override_transport)
	for level in instance._names:
		assert_false(instance._stack_needed.has(level))
	instance.fatal("Msg2")
	assert_null(inherit_transport.get_processed_message("Msg2").stack)

	# Setting options without stack_mode keeps the current one
	instance.set_options(HanpekiLogger.Options.new())
	assert_eq(instance._stack_mode, HanpekiLogger.Transport.StackLevelMode.NONE)


##
## Test that the stack requirements are recalculated when registering and deregistering levels
##
func test_stack_needed_custom_levels() -> void:
	var instance = HanpekiLogger.create()
	var options = HanpekiLogger.Transport.Options.new()
	options.stack_mode = HanpekiLogger.StackLevelConfig.FULL
	instance.add_transport(HanpekiLoggerTestTransport.create(options))
	var custom_level = HanpekiLogger.DEBUG >> 1

	assert_false(instance._stack_needed.has(custom_level))
	instance.register_level(custom_level, "Custom")
	assert_true(instance._stack_needed.has(custom_level))
	instance.deregister_level(custom_level)
	assert_false(instance._stack_needed.has(custom_level))


##
## Test how the stack mode of a transport is resolved with the one of the logger
##
func test_resolve_transport_stack_mode() -> void:
	var none = HanpekiLogger.Transport.StackLevelMode.NONE
	var origin = HanpekiLogger.Transport.StackLevelMode.ORIGIN
	var full = HanpekiLogger.Transport.StackLevelMode.FULL
	var level = HanpekiLogger.ERROR
	var transport = HanpekiLoggerTestTransport.create()
	var options = HanpekiLogger.Transport.Options.new()

	# INHERIT uses the logger mode
	assert_eq(transport._resolve_stack_mode(level, none), none)
	assert_eq(transport._resolve_stack_mode(level, origin), origin)
	assert_eq(transport._resolve_stack_mode(level, full), full)

	# Any other value overrides the logger mode, providing more or less information
	options.stack_mode = HanpekiLogger.StackLevelConfig.ORIGIN
	transport.set_options(options)
	assert_eq(transport._resolve_stack_mode(level, none), origin)
	assert_eq(transport._resolve_stack_mode(level, origin), origin)
	assert_eq(transport._resolve_stack_mode(level, full), origin)

	options.stack_mode = HanpekiLogger.StackLevelConfig.NONE
	transport.set_options(options)
	assert_eq(transport._resolve_stack_mode(level, full), none)

	# Per-level: levels not included inherit the logger mode
	options.stack_mode = {
		HanpekiLogger.WARN: HanpekiLogger.StackLevelConfig.NONE,
		HanpekiLogger.FATAL: HanpekiLogger.StackLevelConfig.INHERIT,
	}
	transport.set_options(options)
	assert_eq(transport._resolve_stack_mode(HanpekiLogger.WARN, full), none)
	assert_eq(transport._resolve_stack_mode(HanpekiLogger.FATAL, full), full)
	assert_eq(transport._resolve_stack_mode(HanpekiLogger.ERROR, origin), origin)


##
## Test the stack mode used by a transport when displaying messages,
## which depends on the logger it's attached to
##
func test_transport_get_stack_mode() -> void:
	var options = HanpekiLogger.Options.new()
	options.stack_mode = HanpekiLogger.StackLevelConfig.ORIGIN
	var instance = HanpekiLogger.create(options)
	var transport = HanpekiLoggerTestTransport.create()

	# Not attached transports don't display any stack
	assert_eq(
		transport._get_stack_mode(HanpekiLogger.ERROR), HanpekiLogger.Transport.StackLevelMode.NONE
	)

	instance.add_transport(transport)
	assert_eq(
		transport._get_stack_mode(HanpekiLogger.ERROR),
		HanpekiLogger.Transport.StackLevelMode.ORIGIN
	)


##
## Test that transports not requiring the stack don't prevent other transports from getting it
##
func test_stack_with_mixed_transports() -> void:
	var instance = HanpekiLogger.create()
	var no_stack_options = HanpekiLogger.Transport.Options.new()
	no_stack_options.stack_mode = HanpekiLogger.StackLevelConfig.NONE
	var no_stack_transport = HanpekiLoggerTestTransport.create(no_stack_options)
	# Inherits the stack mode from the logger
	var stack_transport = HanpekiLoggerTestTransport.create()

	# The transport without stack is added first on purpose
	instance.add_transport(no_stack_transport)
	instance.add_transport(stack_transport)

	assert_true(instance._stack_needed.has(HanpekiLogger.ERROR))
	instance.error("Error message")
	assert_not_null(stack_transport.get_processed_message("Error message").stack)

	# A transport requiring the stack for every level overrides the logger mode
	var full_options = HanpekiLogger.Transport.Options.new()
	full_options.stack_mode = HanpekiLogger.StackLevelConfig.FULL
	instance.remove_transport(stack_transport)
	instance.add_transport(HanpekiLoggerTestTransport.create(full_options))

	assert_true(instance._stack_needed.has(HanpekiLogger.FATAL))
	assert_true(instance._stack_needed.has(HanpekiLogger.CORE))


##
## Test that the logger recalculates the stack requirements when the options
## of an attached transport change
##
func test_stack_recalculated_on_transport_options() -> void:
	var instance = HanpekiLogger.create()
	var transport = HanpekiLoggerTestTransport.create()
	instance.add_transport(transport)
	assert_true(instance._stack_needed.has(HanpekiLogger.ERROR))

	# Disabling the stack in the transport should disable it in the logger
	var options = HanpekiLogger.Transport.Options.new()
	options.stack_mode = HanpekiLogger.StackLevelConfig.NONE
	transport.set_options(options)
	assert_false(instance._stack_needed.has(HanpekiLogger.ERROR))

	instance.error("Msg without stack")
	assert_null(transport.get_processed_message("Msg without stack").stack)

	# And enabling it again should enable it in the logger as well
	options.stack_mode = HanpekiLogger.StackLevelConfig.FULL
	transport.set_options(options)
	assert_true(instance._stack_needed.has(HanpekiLogger.ERROR))

	instance.error("Msg with stack")
	assert_not_null(transport.get_processed_message("Msg with stack").stack)


##
## Test that setting null options in a transport resets them to the defaults
##
func test_transport_null_options() -> void:
	var instance = HanpekiLogger.create()
	var options = HanpekiLogger.Transport.Options.new()
	options.level = HanpekiLogger.ERROR
	options.time_format = HanpekiLogger.Transport.TimeFormat.RELATIVE
	options.stack_mode = HanpekiLogger.StackLevelConfig.NONE
	var transport = HanpekiLoggerTestTransport.create(options)
	instance.add_transport(transport)
	assert_false(instance._stack_needed.has(HanpekiLogger.FATAL))

	transport.set_options(null)

	var defaults = HanpekiLogger.Transport.Options.new()
	assert_eq(transport._level, defaults.level)
	assert_eq(transport._time_format, defaults.time_format)
	assert_eq(transport._stack_mode, HanpekiLogger.Transport.StackLevelMode.INHERIT)
	assert_true(instance._stack_needed.has(HanpekiLogger.FATAL))



##
## Test registering custom levels at any position: below, between and above the predefined ones
##
func test_register_level() -> void:
	var instance = HanpekiLogger.create()
	var transport = HanpekiLoggerTestTransport.create()
	instance.add_transport(transport)
	assert_eq(instance._registered_levels, HanpekiLogger.PREDEFINED_LEVELS)

	var lowest = 1
	var between = HanpekiLogger.INFO << 1
	var highest = HanpekiLogger.FATAL << 1
	instance.register_level(lowest, "Lowest")
	instance.register_level(between, "Between")
	instance.register_level(highest, "Highest")

	assert_eq(
		instance._registered_levels,
		HanpekiLogger.PREDEFINED_LEVELS | lowest | between | highest
	)
	assert_eq(instance.get_level_from_name("lowest"), lowest)
	assert_eq(instance.get_level_name(between), "Between")

	# Custom levels are ordered by priority with the predefined ones
	instance.enable_levels_from(between)
	assert_eq(
		instance._level,
		(
			between
			| HanpekiLogger.CORE
			| HanpekiLogger.WARN
			| HanpekiLogger.ERROR
			| HanpekiLogger.FATAL
			| highest
		)
	)

	instance.message(lowest, "Lowest message")
	instance.message(between, "Between message")
	instance.message(highest, "Highest message")
	assert_false(transport.has_processed_message("Lowest message"))
	assert_true(transport.has_processed_message("Between message"))
	assert_true(transport.has_processed_message("Highest message"))


##
## Test deregistering custom levels
##
func test_deregister_level() -> void:
	var instance = HanpekiLogger.create()
	var custom_level = HanpekiLogger.WARN << 1
	instance.register_level(custom_level, "Custom")

	instance.deregister_level(custom_level)
	assert_eq(instance._registered_levels, HanpekiLogger.PREDEFINED_LEVELS)
	assert_false(instance._names.has(custom_level))
	assert_null(instance.get_level_from_name("Custom"))

	# The same value and name can be registered again
	instance.register_level(custom_level, "Custom")
	assert_eq(instance.get_level_from_name("Custom"), custom_level)
