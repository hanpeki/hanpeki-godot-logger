extends GutTest


##
## Test setting options from a HanpekiLogger.Options object
##
func test_set_options() -> void:
	var instance = HanpekiLogger.create()
	var transport = HanpekiLoggerTestTransport.create()
	instance.add_transport(transport)

	var options = HanpekiLogger.Options.new()
	var important := {
		# More important than "warn"
		"level": HanpekiLogger.WARN << 1,
		"name": "Important"
	}
	var trivial := {
		# Less important than "debug"
		"level": HanpekiLogger.DEBUG >> 1,
		"name": "Trivial",
	}
	options.custom_levels.append_array([important, trivial])
	options.level = HanpekiLogger.WARN
	options.levels = [HanpekiLogger.FATAL, "Warn", important.level, "Trivial"]

	instance.set_options(options)

	instance.fatal("Fatal message")
	instance.error("Error message")
	instance.warn("Warn message")
	instance.core("Core message")
	instance.info("Info message")
	instance.debug("Debug message")
	instance.message(important.level, "Important message")
	instance.message(trivial.level, "Trivial message")

	assert_true(transport.has_processed_message("Fatal message"))
	assert_true(transport.has_processed_message("Error message"))
	assert_true(transport.has_processed_message("Warn message"))
	assert_false(transport.has_processed_message("Core message"))
	assert_false(transport.has_processed_message("Info message"))
	assert_false(transport.has_processed_message("Debug message"))
	assert_true(transport.has_processed_message("Important message"))
	assert_true(transport.has_processed_message("Trivial message"))


##
## Test enabling/disabling levels one by one
##
func test_set_level() -> void:
	var instance = HanpekiLogger.create()
	var transport = HanpekiLoggerTestTransport.create()
	instance.add_transport(transport)

	assert(instance._level == TestUtils.DEFAULT_LEVEL)

	# Can disable levels
	instance.set_level(HanpekiLogger.ERROR, false)
	assert_eq(instance._level, HanpekiLogger.FATAL | HanpekiLogger.WARN | HanpekiLogger.CORE)
	# Disabling a level twice does nothing
	instance.set_level(HanpekiLogger.ERROR, false)
	assert_eq(instance._level, HanpekiLogger.FATAL | HanpekiLogger.WARN | HanpekiLogger.CORE)

	# Can enable levels
	instance.set_level(HanpekiLogger.DEBUG, true)
	assert_eq(
		instance._level,
		HanpekiLogger.FATAL | HanpekiLogger.WARN | HanpekiLogger.CORE | HanpekiLogger.DEBUG
	)
	# Enabling a level twice does nothing
	instance.set_level(HanpekiLogger.DEBUG, true)
	assert_eq(
		instance._level,
		HanpekiLogger.FATAL | HanpekiLogger.WARN | HanpekiLogger.CORE | HanpekiLogger.DEBUG
	)

	#instance.set_level(7, true)
	#assert_engine_error("invalid level")


##
## Test enabling multiple levels at once from a minimum one
##
func test_enable_levels_from() -> void:
	var instance = HanpekiLogger.create()
	var transport = HanpekiLoggerTestTransport.create()
	instance.add_transport(transport)

	assert(instance._level == TestUtils.DEFAULT_LEVEL)

	instance.enable_levels_from(HanpekiLogger.ERROR)
	assert_eq(instance._level, HanpekiLogger.FATAL | HanpekiLogger.ERROR)

	# should also work with custom levels
	var custom_level = HanpekiLogger.WARN >> 1
	instance.register_level(custom_level, "Custom")
	assert_eq(instance._level, HanpekiLogger.FATAL | HanpekiLogger.ERROR)

	instance.enable_levels_from(custom_level)
	assert_eq(
		instance._level,
		HanpekiLogger.FATAL | HanpekiLogger.ERROR | HanpekiLogger.WARN | custom_level
	)


##
## Test enabling every level by providing NONE as the minimum level
##
func test_enable_levels_from_none() -> void:
	var instance = HanpekiLogger.create()
	var transport = HanpekiLoggerTestTransport.create()
	instance.add_transport(transport)
	var custom_level = HanpekiLogger.DEBUG >> 1
	instance.register_level(custom_level, "Custom")

	instance.enable_levels_from(HanpekiLogger.NONE)
	assert_eq(instance._level, instance._registered_levels)

	instance.debug("Debug message")
	instance.message(custom_level, "Custom message")
	assert_true(transport.has_processed_message("Debug message"))
	assert_true(transport.has_processed_message("Custom message"))


##
## Test disabling every level by providing MAX_LEVEL as the minimum level
##
func test_enable_levels_from_max_level() -> void:
	var instance = HanpekiLogger.create()
	var transport = HanpekiLoggerTestTransport.create()
	instance.add_transport(transport)

	instance.enable_levels_from(HanpekiLogger.MAX_LEVEL)
	assert_eq(instance._level, HanpekiLogger.NONE)

	instance.fatal("Fatal message")
	assert_eq(transport.get_processed().size(), 0)

	# Levels can still be enabled again afterwards
	instance.enable_levels_from(HanpekiLogger.NONE)
	instance.fatal("Fatal message")
	assert_true(transport.has_processed_message("Fatal message"))


##
## Test providing the minimum level in the options by its name
##
func test_options_level_name() -> void:
	var options = HanpekiLogger.Options.new()

	# As String (case-insensitive)
	options.level = "warn"
	var instance = HanpekiLogger.create(options)
	assert_eq(instance._level, HanpekiLogger.WARN | HanpekiLogger.ERROR | HanpekiLogger.FATAL)

	# As StringName
	options.level = &"ERROR"
	instance.set_options(options)
	assert_eq(instance._level, HanpekiLogger.ERROR | HanpekiLogger.FATAL)


##
## Test providing the list of levels in the options by their names
##
func test_options_levels_names() -> void:
	var options = HanpekiLogger.Options.new()
	options.levels = ["debug", &"Error", HanpekiLogger.FATAL]
	var instance = HanpekiLogger.create(options)

	assert_eq(instance._level, HanpekiLogger.DEBUG | HanpekiLogger.ERROR | HanpekiLogger.FATAL)


##
## Test the special values NONE and MAX_LEVEL as the minimum level in the options
##
func test_options_level_special_values() -> void:
	var options = HanpekiLogger.Options.new()

	# NONE enables every level
	options.level = HanpekiLogger.NONE
	var instance = HanpekiLogger.create(options)
	assert_eq(instance._level, instance._registered_levels)

	# Also when combined with a list of levels, which shouldn't reset them
	options.levels = [HanpekiLogger.FATAL]
	instance = HanpekiLogger.create(options)
	assert_eq(instance._level, instance._registered_levels)

	# MAX_LEVEL disables every level, so only the listed ones are enabled
	options.level = HanpekiLogger.MAX_LEVEL
	instance = HanpekiLogger.create(options)
	assert_eq(instance._level, HanpekiLogger.FATAL)


##
## Test that setting options without levels keeps the current ones
##
func test_options_keep_levels() -> void:
	var instance = HanpekiLogger.create()
	instance.set_level(HanpekiLogger.DEBUG, true)
	var expected = instance._level

	instance.set_options(HanpekiLogger.Options.new())
	assert_eq(instance._level, expected)


##
## Test providing NONE in the list of levels, which doesn't enable any level
##
func test_options_levels_none() -> void:
	var options = HanpekiLogger.Options.new()

	# Only NONE disables every level
	options.levels = [HanpekiLogger.NONE]
	var instance = HanpekiLogger.create(options)
	var transport = HanpekiLoggerTestTransport.create()
	instance.add_transport(transport)
	assert_eq(instance._level, HanpekiLogger.NONE)
	instance.fatal("Fatal message")
	assert_eq(transport.get_processed().size(), 0)

	# Combined with other levels, only those are enabled
	options.levels = [HanpekiLogger.NONE, "Fatal"]
	instance.set_options(options)
	assert_eq(instance._level, HanpekiLogger.FATAL)
