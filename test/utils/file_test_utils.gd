##
## Utilities for the tests of [HanpekiLoggerFileTransport]
## (loaded via [code]preload[/code] in each test script)
##

## Folder where all the files of the tests are created (to be removed after each test)
const TEST_FOLDER = "user://hanpeki_logger_tests"


##
## Create a [HanpekiLoggerFileTransport] writing to the given [param path].
## The file is created right away by default (see
## [member HanpekiLoggerFileTransport.Options.create_file_on_start]) so it can be checked.
##
static func create_transport(
	path: String,
	max_files: int = HanpekiLoggerFileTransport.DEFAULT_MAX_FILES,
	create_file_on_start: bool = true
) -> HanpekiLoggerFileTransport:
	var options = HanpekiLoggerFileTransport.Options.new()
	options.file_path = path
	options.max_files = max_files
	options.create_file_on_start = create_file_on_start
	return HanpekiLoggerFileTransport.create(options)


##
## Create empty files in the [constant TEST_FOLDER] with the given relative [param paths],
## in the given order (so their modification time is also ordered)
##
static func create_files(paths: Array[String]) -> void:
	for path in paths:
		var full_path = TEST_FOLDER.path_join(path)
		DirAccess.make_dir_recursive_absolute(full_path.get_base_dir())
		FileAccess.open(full_path, FileAccess.WRITE).close()


##
## Get the sorted list of file names in the [constant TEST_FOLDER]
##
static func get_files() -> Array[String]:
	var res: Array[String] = []
	res.assign(DirAccess.get_files_at(TEST_FOLDER))
	res.sort()
	return res


##
## Remove the given folder ([constant TEST_FOLDER] by default) and all its content
##
static func remove_folder(path: String = TEST_FOLDER) -> void:
	var dir = DirAccess.open(path)
	if !dir:
		return
	for file in dir.get_files():
		dir.remove(file)
	for folder in dir.get_directories():
		remove_folder(path.path_join(folder))
	DirAccess.remove_absolute(path)
