extends GutTest


##
## Test that adding a transport attaches it to the logger
##
func test_add_transport() -> void:
	var instance = HanpekiLogger.create()
	var transport = HanpekiLoggerTestTransport.create()

	assert_null(transport._logger)

	instance.add_transport(transport)

	assert_true(instance._transports.has(transport))
	assert_eq(transport._logger.get_ref(), instance)


##
## Test that removed transports don't receive messages anymore
##
func test_remove_transport() -> void:
	var instance = HanpekiLogger.create()
	var transport1 = HanpekiLoggerTestTransport.create()
	var transport2 = HanpekiLoggerTestTransport.create()
	instance.add_transport(transport1)
	instance.add_transport(transport2)

	instance.error("Msg1")
	assert_true(transport1.has_processed_message("Msg1"))
	assert_true(transport2.has_processed_message("Msg1"))

	assert_true(instance.remove_transport(transport1))
	assert_false(instance._transports.has(transport1))
	assert_null(transport1._logger)

	instance.error("Msg2")
	assert_false(transport1.has_processed_message("Msg2"))
	assert_true(transport2.has_processed_message("Msg2"))


##
## Test that removing a transport not attached to the logger does nothing
##
func test_remove_unknown_transport() -> void:
	var instance = HanpekiLogger.create()
	var other_instance = HanpekiLogger.create()
	var transport = HanpekiLoggerTestTransport.create()
	var other_transport = HanpekiLoggerTestTransport.create()
	instance.add_transport(transport)
	other_instance.add_transport(other_transport)

	# Never added anywhere
	assert_false(instance.remove_transport(HanpekiLoggerTestTransport.create()))
	# Added to a different logger, which should keep it attached
	assert_false(instance.remove_transport(other_transport))
	assert_eq(other_transport._logger.get_ref(), other_instance)
	# Already removed
	assert_true(instance.remove_transport(transport))
	assert_false(instance.remove_transport(transport))

	assert_eq(instance._transports.size(), 0)
	assert_eq(other_instance._transports.size(), 1)


##
## Test that a removed transport can be added to a different logger
##
func test_move_transport() -> void:
	var instance1 = HanpekiLogger.create()
	var instance2 = HanpekiLogger.create()
	var transport = HanpekiLoggerTestTransport.create()

	instance1.add_transport(transport)
	instance1.remove_transport(transport)
	instance2.add_transport(transport)

	assert_eq(transport._logger.get_ref(), instance2)
	assert_eq(instance1._transports.size(), 0)
	assert_eq(instance2._transports.size(), 1)

	instance1.error("Msg via instance1")
	instance2.error("Msg via instance2")
	assert_false(transport.has_processed_message("Msg via instance1"))
	assert_true(transport.has_processed_message("Msg via instance2"))


##
## Test that the stack requirements are recalculated when removing transports
##
func test_remove_transport_recalculates_stack() -> void:
	var instance = HanpekiLogger.create()
	# Default transport options provide the stack for some levels
	var transport = HanpekiLoggerTestTransport.create()
	instance.add_transport(transport)
	assert_typeof(instance._provide_stack, TYPE_DICTIONARY)

	instance.remove_transport(transport)
	assert_false(instance._provide_stack)


##
## Test that transports don't keep their logger alive (no reference cycles),
## and that they can be added to another logger once the previous one is freed
##
func test_logger_is_freed() -> void:
	var instance = HanpekiLogger.create()
	var transport = HanpekiLoggerTestTransport.create()
	instance.add_transport(transport)

	var instance_ref = weakref(instance)
	instance = null

	assert_null(instance_ref.get_ref())
	assert_null(transport._logger.get_ref())

	var other_instance = HanpekiLogger.create()
	other_instance.add_transport(transport)
	assert_eq(transport._logger.get_ref(), other_instance)


##
## Test that transports are freed along with their logger
##
func test_transports_are_freed() -> void:
	var instance = HanpekiLogger.create()
	var transport = HanpekiLoggerTestTransport.create()
	instance.add_transport(transport)

	var transport_ref = weakref(transport)
	transport = null
	# Still alive, as the logger keeps it
	assert_not_null(transport_ref.get_ref())

	instance = null
	assert_null(transport_ref.get_ref())
