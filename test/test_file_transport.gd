extends GutTest

## Folder where all the files of these tests are created (removed after each test)
const TEST_FOLDER = "user://hanpeki_logger_tests"


func after_each() -> void:
	_remove_folder(TEST_FOLDER)


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
	var transport1 = _create_transport(path)
	var transport2 = _create_transport(path)

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
	var transport3 = _create_transport(path)
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

	var transport = _create_transport(path)
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
## Create a [HanpekiLoggerFileTransport] writing to the given [param path]
##
func _create_transport(path: String) -> HanpekiLoggerFileTransport:
	var options = HanpekiLoggerFileTransport.Options.new()
	options.file_path = path
	return HanpekiLoggerFileTransport.create(options)


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


##
## Remove the given folder and all its content
##
func _remove_folder(path: String) -> void:
	var dir = DirAccess.open(path)
	if !dir:
		return
	for file in dir.get_files():
		dir.remove(file)
	for folder in dir.get_directories():
		_remove_folder(path.path_join(folder))
	DirAccess.remove_absolute(path)
