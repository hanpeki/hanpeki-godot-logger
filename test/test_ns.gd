extends GutTest

##
## Test message methods and values of a default instance
##
func test_default_ns_instance() -> void:
	var instance = HanpekiLogger.new()
	var transport = HanpekiLoggerTestTransport.new()
	instance.add_transport(transport)
	
	assert(instance._level == TestUtils.DEFAULT_LEVEL)
	
	var bound = instance.bind_ns(&'Test')
	assert_eq(bound._level, HanpekiLogger.INHERIT)
	
	bound.fatal('Fatal message')
	bound.error('Error message')
	bound.warn('Warn message')
	bound.core('Core message')
	bound.info('Info message')
	bound.debug('Debug message')
	
	assert_true(transport.has_processed_message('Fatal message'))
	assert_true(transport.has_processed_message('Error message'))
	assert_true(transport.has_processed_message('Warn message'))
	assert_true(transport.has_processed_message('Core message'))
	assert_false(transport.has_processed_message('Info message'))
	assert_false(transport.has_processed_message('Debug message'))
	
	var info = transport.get_processed_message('Fatal message', HanpekiLogger.FATAL)
	assert_eq(info.ns, &'Test')

func test_ns_level() -> void:
	var instance = HanpekiLogger.new()
	var transport = HanpekiLoggerTestTransport.new()
	instance.add_transport(transport)
	
	assert(instance._level == TestUtils.DEFAULT_LEVEL)
	
	var bound1 = instance.bind_ns(&'Bound 1')
	var bound2 = instance.bind_ns(&'Bound 2')
	assert_eq(bound1._level, HanpekiLogger.INHERIT)
	assert_eq(bound2._level, HanpekiLogger.INHERIT)
	
	# By default, bound instances should have the same levels as the main instance
	instance.error('Msg1 via instance')
	bound1.error('Msg1 via bound1')
	bound2.error('Msg1 via bound2')
	
	assert_eq(transport.get_processed_message('Msg1 via instance').ns, &'')
	assert_eq(transport.get_processed_message('Msg1 via bound1').ns, &'Bound 1')
	assert_eq(transport.get_processed_message('Msg1 via bound2').ns, &'Bound 2')
	
	# Disabling a level in the main instance should affect the sync'ed ones
	instance.set_level(HanpekiLogger.ERROR, false)
	instance.error('Msg2 via instance')
	bound1.error('Msg2 via bound1')
	bound2.error('Msg2 via bound2')
	assert_false(transport.has_processed_message('Msg2 via instance'))
	assert_false(transport.has_processed_message('Msg2 via bound1'))
	assert_false(transport.has_processed_message('Msg2 via bound2'))
	
	# Levels can be disabled in bound instances directly
	bound1.set_level(HanpekiLogger.FATAL, false)
	instance.fatal('Msg3 via instance')
	bound1.fatal('Msg3 via bound1')
	bound2.fatal('Msg3 via bound2')
	assert_true(transport.has_processed_message('Msg3 via instance'))
	assert_false(transport.has_processed_message('Msg3 via bound1'))
	assert_true(transport.has_processed_message('Msg3 via bound2'))
	
	# But enabling levels in bound instances won't work if the main one has it disabled
	bound2.set_level(HanpekiLogger.ERROR, true)
	instance.error('Msg4 via instance')
	bound1.error('Msg4 via bound1')
	bound2.error('Msg4 via bound2')
	assert_false(transport.has_processed_message('Msg4 via instance'))
	assert_false(transport.has_processed_message('Msg4 via bound1'))
	assert_false(transport.has_processed_message('Msg4 via bound2'))
	
	# Changing levels shouldn't "de-sync" bound instances from the main one
	bound2.set_level(HanpekiLogger.ERROR, false)
	bound2.set_level(HanpekiLogger.ERROR, true)
	instance.set_level(HanpekiLogger.ERROR, true)
	instance.error('Msg5 via instance')
	bound1.error('Msg5 via bound1')
	bound2.error('Msg5 via bound2')
	assert_true(transport.has_processed_message('Msg5 via instance'))
	assert_true(transport.has_processed_message('Msg5 via bound1'))
	assert_true(transport.has_processed_message('Msg5 via bound2'))
