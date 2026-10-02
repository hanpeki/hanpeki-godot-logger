extends GutTest

const FileTestUtils = preload("res://test/utils/file_test_utils.gd")
const TEST_FOLDER = FileTestUtils.TEST_FOLDER


func after_each() -> void:
	FileTestUtils.remove_folder()


##
## Test the {N} placeholder, which uses the next number after the highest existing one
##
func test_n_placeholder() -> void:
	var template = TEST_FOLDER + "/log-{N}.txt"
	assert_eq(HanpekiLoggerFileTransport._get_file_path(template), TEST_FOLDER + "/log-1.txt")

	FileTestUtils.create_files(["log-1.txt", "log-5.txt", "log-x.txt", "other-9.txt", "log-7.log"])
	assert_eq(HanpekiLoggerFileTransport._get_file_path(template), TEST_FOLDER + "/log-6.txt")


##
## Test the {N,padding} placeholder
##
func test_n_placeholder_padding() -> void:
	var template = TEST_FOLDER + "/log-{N,3}.txt"
	assert_eq(HanpekiLoggerFileTransport._get_file_path(template), TEST_FOLDER + "/log-001.txt")

	# Numbers with less digits than the padding don't match
	FileTestUtils.create_files(["log-009.txt", "log-50.txt"])
	assert_eq(HanpekiLoggerFileTransport._get_file_path(template), TEST_FOLDER + "/log-010.txt")

	# But they can grow over the padding
	FileTestUtils.create_files(["log-999.txt"])
	assert_eq(HanpekiLoggerFileTransport._get_file_path(template), TEST_FOLDER + "/log-1000.txt")


##
## Test the validation of the placeholders in the file path
##
func test_validate_file_path() -> void:
	var validate = HanpekiLoggerFileTransport._validate_file_path

	# Valid paths
	for path in [
		"logs/game.txt",
		"logs/{DATETIME}.txt",
		"logs/{N}/game-{N,3}_{DATETIME}.txt",
		"user://logs/{N,1}.txt",
		HanpekiLoggerFileTransport.DEFAULT_FILE_PATH,
	]:
		assert_eq(validate.call(path), "", "Path should be valid: %s" % path)

	# Unknown placeholders
	for placeholder in ["{TIME}", "{datetime}", "{n}", "{}"]:
		var error = validate.call("logs/game-%s.txt" % placeholder)
		assert_string_contains(error, 'Unknown placeholder "%s"' % placeholder)

	# Invalid paddings
	for placeholder in ["{N,0}", "{N,}", "{N,x}", "{N,-1}", "{N, 3}", "{N,3,2}"]:
		var error = validate.call("logs/{DATETIME}/game-%s.txt" % placeholder)
		assert_string_contains(error, 'Invalid padding in placeholder "%s"' % placeholder)


##
## Test that only the files matching the template are detected as log files
##
func test_find_log_files() -> void:
	FileTestUtils.create_files(
		[
			"log_2025-01-02_03.04.05.txt",
			"log_2025-01-02_03.04.06.txt",
			# Not matching
			"log_2025-1-2_03.04.05.txt",
			"log_2025-01-02_03.04.05.log",
			"other_2025-01-02_03.04.05.txt",
			"log_{DATETIME}.txt",
		]
	)
	# Folders are not files, even if their name matches
	DirAccess.make_dir_recursive_absolute(TEST_FOLDER + "/log_2025-01-02_03.04.07.txt")

	var files = HanpekiLoggerFileTransport._find_log_files(TEST_FOLDER + "/log_{DATETIME}.txt")
	var paths = files.map(func(log_file): return log_file.path)
	paths.sort()

	assert_eq(
		paths,
		[
			TEST_FOLDER + "/log_2025-01-02_03.04.05.txt",
			TEST_FOLDER + "/log_2025-01-02_03.04.06.txt",
		]
	)
	for log_file in files:
		assert_eq(log_file.values.size(), 1)
		assert_true(log_file.path.ends_with("log_%s.txt" % log_file.values[0]))


##
## Test detecting log files with placeholders in the folders
##
func test_find_log_files_in_folders() -> void:
	FileTestUtils.create_files(
		["1/game.txt", "1/other.txt", "2/game.txt", "3/other.txt", "x/game.txt"]
	)

	var files = HanpekiLoggerFileTransport._find_log_files(TEST_FOLDER + "/{N}/game.txt")
	files.sort_custom(func(a, b): return a.path < b.path)

	assert_eq(files.size(), 2)
	assert_eq(files[0].path, TEST_FOLDER + "/1/game.txt")
	assert_eq(files[0].values, [1])
	assert_eq(files[1].path, TEST_FOLDER + "/2/game.txt")
	assert_eq(files[1].values, [2])


##
## Test that only the latest log files are kept, without removing unrelated files
##
func test_rotation() -> void:
	FileTestUtils.create_files(
		["log-1.txt", "log-2.txt", "log-3.txt", "log-4.txt", "log-5.txt", "notes.txt", "log-a.txt"]
	)

	var transport = FileTestUtils.create_transport(TEST_FOLDER + "/log-{N}.txt", 3)
	assert_eq(transport._file.get_path(), TEST_FOLDER + "/log-6.txt")

	# The new file counts as one of the max_files
	assert_eq(
		FileTestUtils.get_files(),
		["log-4.txt", "log-5.txt", "log-6.txt", "log-a.txt", "notes.txt"] as Array[String]
	)


##
## Test rotating log files named with the {DATETIME} placeholder
##
func test_rotation_datetime() -> void:
	FileTestUtils.create_files(
		[
			"log_2025-01-01_00.00.00.txt",
			"log_2025-01-02_00.00.00.txt",
			"log_2025-01-03_00.00.00.txt",
		]
	)

	var transport = FileTestUtils.create_transport(TEST_FOLDER + "/log_{DATETIME}.txt", 2)
	var new_file = transport._file.get_path().get_file()

	assert_eq(FileTestUtils.get_files(), ["log_2025-01-03_00.00.00.txt", new_file] as Array[String])


##
## Test that a max_files of 0 disables the rotation
##
func test_rotation_disabled() -> void:
	FileTestUtils.create_files(["log-1.txt", "log-2.txt", "log-3.txt"])

	var transport = FileTestUtils.create_transport(TEST_FOLDER + "/log-{N}.txt", 0)
	assert_eq(transport._file.get_path(), TEST_FOLDER + "/log-4.txt")

	assert_eq(
		FileTestUtils.get_files(), ["log-1.txt", "log-2.txt", "log-3.txt", "log-4.txt"] as Array[String]
	)


##
## Test the rotation with placeholders in the folders, which deletes only the log files
##
func test_rotation_in_folders() -> void:
	FileTestUtils.create_files(["1/game.txt", "1/other.txt", "2/game.txt", "3/game.txt"])

	var transport = FileTestUtils.create_transport(TEST_FOLDER + "/{N}/game.txt", 2)
	assert_eq(transport._file.get_path(), TEST_FOLDER + "/4/game.txt")

	assert_false(FileAccess.file_exists(TEST_FOLDER + "/1/game.txt"))
	assert_false(FileAccess.file_exists(TEST_FOLDER + "/2/game.txt"))
	assert_true(FileAccess.file_exists(TEST_FOLDER + "/3/game.txt"))
	# Unrelated files and folders are kept
	assert_true(FileAccess.file_exists(TEST_FOLDER + "/1/other.txt"))
	assert_true(DirAccess.dir_exists_absolute(TEST_FOLDER + "/2"))


##
## Test that files without placeholders don't rotate anything
##
func test_rotation_without_placeholders() -> void:
	FileTestUtils.create_files(["log-1.txt", "log-2.txt", "other.txt"])

	var transport = FileTestUtils.create_transport(TEST_FOLDER + "/log.txt", 1)
	assert_not_null(transport._file)

	assert_eq(
		FileTestUtils.get_files(), ["log-1.txt", "log-2.txt", "log.txt", "other.txt"] as Array[String]
	)


##
## Test that transports with the same template share the same file during the session,
## even if the placeholders would generate a new one
##
func test_shared_template() -> void:
	var template = TEST_FOLDER + "/log-{N}.txt"
	var transport1 = FileTestUtils.create_transport(template, 2)
	var transport2 = FileTestUtils.create_transport(template, 2)

	assert_eq(transport1._file.get_path(), TEST_FOLDER + "/log-1.txt")
	assert_same(transport1._file, transport2._file)

	# Once the file is closed, a new one is generated
	transport1 = null
	transport2 = null
	var transport3 = FileTestUtils.create_transport(template, 2)
	assert_eq(transport3._file.get_path(), TEST_FOLDER + "/log-2.txt")


##
## Test the order of the log files: by modification time and then by placeholder values
##
func test_log_files_order() -> void:
	var is_older = HanpekiLoggerFileTransport._is_older_log_file

	# Modification time first
	assert_true(is_older.call({"time": 1, "values": [5]}, {"time": 2, "values": [1]}))
	assert_false(is_older.call({"time": 2, "values": [1]}, {"time": 1, "values": [5]}))

	# Then placeholder values, in order
	assert_true(is_older.call({"time": 1, "values": [1]}, {"time": 1, "values": [2]}))
	assert_true(
		is_older.call(
			{"time": 1, "values": ["2025-01-01_00.00.00", 9]},
			{"time": 1, "values": ["2025-01-02_00.00.00", 1]}
		)
	)
	assert_true(
		is_older.call(
			{"time": 1, "values": ["2025-01-01_00.00.00", 1]},
			{"time": 1, "values": ["2025-01-01_00.00.00", 2]}
		)
	)
	assert_false(is_older.call({"time": 1, "values": [1]}, {"time": 1, "values": [1]}))
