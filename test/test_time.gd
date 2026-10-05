extends GutTest

const FileTestUtils = preload("res://test/utils/file_test_utils.gd")

## Unix time in milliseconds for 2025-01-02 03:04:05.678 UTC
const UNIX_MS = 1735787045678

## Value of [member HanpekiLogger._start_unix_ms] to restore after each test
var _original_start_unix_ms: int


func before_each() -> void:
	_original_start_unix_ms = HanpekiLogger._start_unix_ms


func after_each() -> void:
	HanpekiLogger._start_unix_ms = _original_start_unix_ms
	FileTestUtils.remove_folder()


##
## Test that every transport uses the system timezone, even the ones defining their own
## [code]_init[/code] without calling [code]super()[/code] (as Godot doesn't call the
## [code]_init[/code] of the base class then).
## Note that this can only fail when the tests run in a system with a timezone other than UTC.
##
func test_transports_time_bias() -> void:
	var bias = Time.get_time_zone_from_system().bias * 60
	var file_options = HanpekiLoggerFileTransport.Options.new()
	file_options.file_path = "hanpeki_logger_tests/log.txt"

	assert_eq(HanpekiLoggerConsoleTransport.create()._time_bias, bias)
	assert_eq(HanpekiLoggerFileTransport.create(file_options)._time_bias, bias)
	assert_eq(HanpekiLoggerTestTransport.create()._time_bias, bias)
	assert_eq(CustomInitTransport.new(true)._time_bias, bias)


##
## Test that the time of the messages is calculated from the ticks and the start time
##
func test_message_time() -> void:
	var instance = HanpekiLogger.create()
	var transport = HanpekiLoggerTestTransport.create()
	instance.add_transport(transport)

	instance.error("Msg")
	var msg = transport.get_processed_message("Msg")

	@warning_ignore("integer_division")
	assert_eq(msg.time, (HanpekiLogger._start_unix_ms + msg.utime) / 1000)
	# It should be close to the system time (allowing for the second to change while testing)
	assert_almost_eq(msg.time, int(Time.get_unix_time_from_system()), 1)


##
## Test the time formats based on UTC
##
func test_utc_time_format() -> void:
	HanpekiLogger._start_unix_ms = 0
	var transport = HanpekiLoggerTestTransport.create()
	var data = _create_msg_data(UNIX_MS)

	transport.set_time_format(HanpekiLogger.Transport.TimeFormat.UTC_TIME)
	assert_eq(transport._get_time_str(data), "03:04:05.678")

	transport.set_time_format(HanpekiLogger.Transport.TimeFormat.UTC_DATE_TIME)
	assert_eq(transport._get_time_str(data), "2025-01-02 03:04:05.678")


##
## Test the time formats based on the system timezone
##
func test_system_time_format() -> void:
	HanpekiLogger._start_unix_ms = 0
	var transport = HanpekiLoggerTestTransport.create()
	# Force a known timezone (UTC+9) instead of depending on the system running the tests
	transport._time_bias = 9 * 3600
	var data = _create_msg_data(UNIX_MS)

	transport.set_time_format(HanpekiLogger.Transport.TimeFormat.SYSTEM_TIME)
	assert_eq(transport._get_time_str(data), "12:04:05.678")

	transport.set_time_format(HanpekiLogger.Transport.TimeFormat.SYSTEM_DATE_TIME)
	assert_eq(transport._get_time_str(data), "2025-01-02 12:04:05.678")


##
## Test the time format relative to the app start, which doesn't depend on the start time
##
func test_relative_time_format() -> void:
	HanpekiLogger._start_unix_ms = UNIX_MS
	var transport = HanpekiLoggerTestTransport.create()
	transport.set_time_format(HanpekiLogger.Transport.TimeFormat.RELATIVE)

	# 1h 2m 3s 456ms after the app started
	assert_eq(transport._get_time_str(_create_msg_data(UNIX_MS + 3723456)), "01:02:03.456")


##
## Test that the formatted time keeps the order of the messages, even when the app didn't start
## at the beginning of a second.
## Taking the seconds from the system clock and the milliseconds from the ticks independently
## would display these messages as 12:00:01.700, 12:00:01.250 (before the previous one!) and
## 12:00:02.350
##
func test_time_format_order() -> void:
	# The app started at 12:00:00.700 UTC (1970-01-01)
	var start = 12 * 3600 * 1000
	HanpekiLogger._start_unix_ms = start + 700
	var transport = HanpekiLoggerTestTransport.create()
	transport.set_time_format(HanpekiLogger.Transport.TimeFormat.UTC_TIME)

	var times: Array[String] = [
		transport._get_time_str(_create_msg_data(start + 1400)),
		transport._get_time_str(_create_msg_data(start + 1950)),
		transport._get_time_str(_create_msg_data(start + 2050)),
	]
	assert_eq(times, ["12:00:01.400", "12:00:01.950", "12:00:02.050"] as Array[String])

	# The formatted times should be in the same order the messages were logged
	var sorted = times.duplicate()
	sorted.sort()
	assert_eq(times, sorted)


##
## Create a [HanpekiLogger.MsgData] logged at the given [param unix_ms], filling the time fields
## the same way [method HanpekiLogger.message] does, based on [member HanpekiLogger._start_unix_ms]
##
func _create_msg_data(unix_ms: int) -> HanpekiLogger.MsgData:
	var data = HanpekiLogger.MsgData.new()
	data.utime = unix_ms - HanpekiLogger._start_unix_ms
	@warning_ignore("integer_division")
	data.time = (HanpekiLogger._start_unix_ms + data.utime) / 1000
	return data


##
## Transport defining its own [code]_init[/code] without calling [code]super()[/code]
##
class CustomInitTransport:
	extends HanpekiLogger.Transport

	var _custom: bool

	func _init(custom: bool) -> void:
		_custom = custom

	func process(_data: HanpekiLogger.MsgData) -> void:
		pass
