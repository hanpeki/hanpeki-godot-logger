extends GutTest

##
## Ensures that [member HanpekiLogger.VERSION] exist and it's semantic
##
func test_version() -> void:
	var semver_regex = RegEx.create_from_string("".join([
		"^",
		"(0|[1-9]\\d*)", # major version with no leading zeros except 0 itself
		"\\.(0|[1-9]\\d*)", # minor version
		"\\.(0|[1-9]\\d*)", # patch version
		"(?:-([0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*))?", # optional pre-release tag
		"(?:\\+([0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*))?", # +exp.sha.hash etc
		"$"
	]))
	var matches = semver_regex.search(HanpekiLogger.VERSION)
	assert_not_null(matches)

##
## Test that is possible to create HanpekiLogger instances by passing options directly
##
func test_create() -> void:
	var options = HanpekiLogger.Options.new()
	var IMPORTANT := {
		# More important than "warn"
		"level": HanpekiLogger.WARN << 1,
		"name": "Important"
	}
	var TRIVIAL := {
		# Less important than "debug"
		"level": HanpekiLogger.DEBUG >> 1,
		"name": "Trivial",
	}
	options.custom_levels.append_array([IMPORTANT, TRIVIAL])
	options.level = HanpekiLogger.WARN
	options.levels = [HanpekiLogger.FATAL, "Warn", IMPORTANT.level, "Trivial"]
	
	var instance = HanpekiLogger.create(options)
	
	var transport = HanpekiLoggerTestTransport.new()
	instance.add_transport(transport)
	
	instance.fatal('Fatal message')
	instance.error('Error message')
	instance.warn('Warn message')
	instance.core('Core message')
	instance.info('Info message')
	instance.debug('Debug message')
	instance.message(IMPORTANT.level, "Important message")
	instance.message(TRIVIAL.level, "Trivial message")
	
	assert_true(transport.has_processed_message('Fatal message'))
	assert_true(transport.has_processed_message('Error message'))
	assert_true(transport.has_processed_message('Warn message'))
	assert_false(transport.has_processed_message('Core message'))
	assert_false(transport.has_processed_message('Info message'))
	assert_false(transport.has_processed_message('Debug message'))
	assert_true(transport.has_processed_message('Important message'))
	assert_true(transport.has_processed_message('Trivial message'))

##
## Test the internal utility to validate level values
##
func test_is_valid_level():
	# 0 is not a valid level
	assert_false(HanpekiLogger._is_valid_level(0))
	
	# Power of two are valid levels
	assert_true(HanpekiLogger._is_valid_level(2 << 1))
	assert_true(HanpekiLogger._is_valid_level(2 << 2))
	assert_true(HanpekiLogger._is_valid_level(2 << 4))
	assert_true(HanpekiLogger._is_valid_level(2 << 15))
	assert_true(HanpekiLogger._is_valid_level(2 << 45))
	assert_true(HanpekiLogger._is_valid_level(2 << 61))
	
	# Negative numbers are not valid levels
	assert_false(HanpekiLogger._is_valid_level(-1))
	assert_false(HanpekiLogger._is_valid_level(-123))
	assert_false(HanpekiLogger._is_valid_level(-123456))
	
	# Negative numbers are not valid levels even if they are power of two
	assert_false(HanpekiLogger._is_valid_level(2 << 63)) # Yes, 2^64 is not possible in 64 signed bit
	assert_false(HanpekiLogger._is_valid_level(2 << 62)) # Yes, 2^63 is also out of the limit
	assert_false(HanpekiLogger._is_valid_level(-(2 << 1)))
	assert_false(HanpekiLogger._is_valid_level(-(2 << 2)))
	assert_false(HanpekiLogger._is_valid_level(-(2 << 5)))
	assert_false(HanpekiLogger._is_valid_level(-(2 << 25)))
	
	# Not power of two are not valid levels
	assert_false(HanpekiLogger._is_valid_level(3))
	assert_false(HanpekiLogger._is_valid_level(5))
	assert_false(HanpekiLogger._is_valid_level(6))
	assert_false(HanpekiLogger._is_valid_level(7))
	assert_false(HanpekiLogger._is_valid_level(9))
	assert_false(HanpekiLogger._is_valid_level(10))
	assert_false(HanpekiLogger._is_valid_level(25))
	assert_false(HanpekiLogger._is_valid_level(34))
	assert_false(HanpekiLogger._is_valid_level(60))
	assert_false(HanpekiLogger._is_valid_level(90))
	assert_false(HanpekiLogger._is_valid_level(1234567))
	
