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
