extends GutTest

const FileTestUtils = preload("res://test/utils/file_test_utils.gd")
const TEST_FOLDER = FileTestUtils.TEST_FOLDER


func after_each() -> void:
	FileTestUtils.remove_folder()


##
## Test that relative paths are resolved inside user://, creating the needed folders
##
func test_relative_path() -> void:
	var path = HanpekiLoggerFileTransport._get_file_path("hanpeki_logger_tests/a/b/log.txt")

	assert_eq(path, TEST_FOLDER + "/a/b/log.txt")
	assert_true(DirAccess.dir_exists_absolute(TEST_FOLDER + "/a/b"))


##
## Test that absolute paths are kept as they are
##
func test_absolute_paths() -> void:
	# user:// paths
	var user_path = TEST_FOLDER + "/user/log.txt"
	assert_eq(HanpekiLoggerFileTransport._get_file_path(user_path), user_path)
	assert_true(DirAccess.dir_exists_absolute(TEST_FOLDER + "/user"))

	# res:// paths (with an existing folder, to avoid creating folders in the project)
	var res_path = "res://log.txt"
	assert_eq(HanpekiLoggerFileTransport._get_file_path(res_path), res_path)

	# OS absolute paths
	var os_folder = ProjectSettings.globalize_path(TEST_FOLDER)
	var os_path = os_folder + "/os/log.txt"
	assert_false(os_path.is_relative_path())
	assert_eq(HanpekiLoggerFileTransport._get_file_path(os_path), os_path)
	assert_true(DirAccess.dir_exists_absolute(os_folder + "/os"))


##
## Test that the {DATETIME} placeholder is replaced
##
func test_datetime_placeholder() -> void:
	var path = HanpekiLoggerFileTransport._get_file_path(TEST_FOLDER + "/log_{DATETIME}.txt")

	var regex = RegEx.create_from_string(
		"^" + TEST_FOLDER + "/log_\\d{4}-\\d{2}-\\d{2}_\\d{2}\\.\\d{2}\\.\\d{2}\\.txt$"
	)
	assert_not_null(regex.search(path), "Unexpected path: %s" % path)


##
## Test that transports using the same path share the same file, which is kept open until the
## last of them is freed
##
func test_shared_file() -> void:
	var path = TEST_FOLDER + "/shared.txt"
	var transport1 = FileTestUtils.create_transport(path)
	var transport2 = FileTestUtils.create_transport(path)

	assert_not_null(transport1._file)
	assert_same(transport1._file, transport2._file)

	var instance = HanpekiLogger.create()
	instance.add_transport(transport2)
	transport2 = null

	# Freeing one transport shouldn't close the file for the other one
	transport1 = null
	instance.error("Message after freeing a transport")
	assert_string_contains(
		FileAccess.get_file_as_string(path), "Message after freeing a transport"
	)

	# Once every transport is freed, the file is closed and not kept in the cache
	instance = null
	assert_null(HanpekiLoggerFileTransport._files[path].get_ref())

	# So a new transport opens it again
	var transport3 = FileTestUtils.create_transport(path)
	assert_not_null(transport3._file)
	assert_true(transport3._file.is_open())


##
## Test that a file that can't be opened is reported, ignored by the transport and not cached
##
func test_file_open_error() -> void:
	# A path whose parent is a file can't be opened in any OS
	DirAccess.make_dir_recursive_absolute(TEST_FOLDER)
	var blocker = TEST_FOLDER + "/blocker"
	FileAccess.open(blocker, FileAccess.WRITE).close()
	var path = blocker + "/log.txt"

	var transport = FileTestUtils.create_transport(path)
	assert_null(transport._file)
	assert_push_error("can't open the log file")
	_handle_engine_errors()
	assert_false(HanpekiLoggerFileTransport._files.has(path))

	# Messages are just ignored
	var instance = HanpekiLogger.create()
	instance.add_transport(transport)
	instance.error("Message")
	assert_false(FileAccess.file_exists(path))


##
## Test that, by default, the file is not created (nor the old ones rotated) until the first
## message is logged
##
func test_file_created_on_first_message() -> void:
	assert_false(HanpekiLoggerFileTransport.Options.new().create_file_on_start)

	FileTestUtils.create_files(["log-1.txt", "log-2.txt", "log-3.txt"])
	var options = HanpekiLoggerFileTransport.Options.new()
	options.file_path = TEST_FOLDER + "/log-{N}.txt"
	options.max_files = 2
	var transport = HanpekiLoggerFileTransport.create(options)

	assert_null(transport._file)
	assert_eq(
		FileTestUtils.get_files(), ["log-1.txt", "log-2.txt", "log-3.txt"] as Array[String]
	)

	var instance = HanpekiLogger.create()
	instance.add_transport(transport)
	instance.error("First message")

	assert_eq(transport._file.get_path(), TEST_FOLDER + "/log-4.txt")
	assert_eq(FileTestUtils.get_files(), ["log-3.txt", "log-4.txt"] as Array[String])
	assert_string_contains(
		FileAccess.get_file_as_string(TEST_FOLDER + "/log-4.txt"), "First message"
	)


##
## Test that the options can be changed before the first message is logged, without creating
## the file of the previous ones
##
func test_options_changed_before_first_message() -> void:
	var transport = FileTestUtils.create_transport(TEST_FOLDER + "/old.txt", 0, false)

	var options = HanpekiLoggerFileTransport.Options.new()
	options.file_path = TEST_FOLDER + "/new.txt"
	transport.set_options(options)

	var instance = HanpekiLogger.create()
	instance.add_transport(transport)
	instance.error("Message")

	assert_false(FileAccess.file_exists(TEST_FOLDER + "/old.txt"))
	assert_string_contains(FileAccess.get_file_as_string(TEST_FOLDER + "/new.txt"), "Message")


##
## Test that, when the file is created on the first message and it can't be opened, the error is
## reported only once
##
func test_delayed_file_open_error() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_FOLDER)
	var blocker = TEST_FOLDER + "/blocker"
	FileAccess.open(blocker, FileAccess.WRITE).close()
	var path = blocker + "/log.txt"

	var transport = FileTestUtils.create_transport(path, 0, false)
	assert_push_error_count(0)

	var instance = HanpekiLogger.create()
	instance.add_transport(transport)
	instance.error("Message 1")
	instance.error("Message 2")
	assert_null(transport._file)
	# A second error would be left unhandled, failing the test
	assert_push_error("can't open the log file")
	_handle_engine_errors()
	assert_false(FileAccess.file_exists(path))


##
## Test the default flush options
##
func test_flush_defaults() -> void:
	var options = HanpekiLoggerFileTransport.Options.new()

	assert_eq(options.flush_interval_ms, 0 if OS.is_debug_build() else 5000)
	assert_eq(options.flush_levels, HanpekiLogger.ERROR | HanpekiLogger.FATAL)


##
## Test that the file is flushed only after the interval passes, or right away for the
## configured levels
##
func test_flush_interval() -> void:
	var path = TEST_FOLDER + "/flush.txt"
	var options = HanpekiLoggerFileTransport.Options.new()
	options.file_path = path
	options.flush_interval_ms = 5000
	options.flush_levels = HanpekiLogger.ERROR
	var transport = HanpekiLoggerFileTransport.create(options)

	# Within the interval, no flush
	transport.process(_create_msg_data(HanpekiLogger.INFO, "Msg1", 1000))
	assert_eq(transport._last_flush, 0)

	# Once the interval passes, flushed (including the previous messages)
	transport.process(_create_msg_data(HanpekiLogger.INFO, "Msg2", 5000))
	assert_eq(transport._last_flush, 5000)
	var content = FileAccess.get_file_as_string(path)
	assert_string_contains(content, "Msg1")
	assert_string_contains(content, "Msg2")

	# The interval counts from the last flush
	transport.process(_create_msg_data(HanpekiLogger.INFO, "Msg3", 9000))
	assert_eq(transport._last_flush, 5000)

	# Flush levels are flushed right away
	transport.process(_create_msg_data(HanpekiLogger.ERROR, "Msg4", 9500))
	assert_eq(transport._last_flush, 9500)
	content = FileAccess.get_file_as_string(path)
	assert_string_contains(content, "Msg3")
	assert_string_contains(content, "Msg4")

	# But other levels are not
	transport.process(_create_msg_data(HanpekiLogger.FATAL, "Msg5", 10000))
	assert_eq(transport._last_flush, 9500)


##
## Test that an interval of 0 flushes after every message
##
func test_flush_every_message() -> void:
	var path = TEST_FOLDER + "/flush_all.txt"
	var options = HanpekiLoggerFileTransport.Options.new()
	options.file_path = path
	options.flush_interval_ms = 0
	options.flush_levels = HanpekiLogger.NONE
	var transport = HanpekiLoggerFileTransport.create(options)

	transport.process(_create_msg_data(HanpekiLogger.DEBUG, "Msg1", 10))
	assert_eq(transport._last_flush, 10)
	transport.process(_create_msg_data(HanpekiLogger.DEBUG, "Msg2", 11))
	assert_eq(transport._last_flush, 11)
	assert_string_contains(FileAccess.get_file_as_string(path), "Msg2")


##
## Create a [HanpekiLogger.MsgData] with the given [param level], [param msg] and
## [param utime], to be processed directly by a transport
##
func _create_msg_data(level: int, msg: String, utime: int) -> HanpekiLogger.MsgData:
	var data = HanpekiLogger.MsgData.new()
	data.level = level
	data.level_name = "Level %d" % level
	data.msg = msg
	data.utime = utime
	return data


##
## Mark the engine errors as handled, as Godot can report its own errors when files or folders
## can't be created, apart from the one reported by the transport
##
func _handle_engine_errors() -> void:
	for error in get_errors():
		if error.is_engine_error():
			error.handled = true
