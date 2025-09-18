extends HanpekiLogger.Transport

##
## HanpekiLoggerFileTransport is a [HanpekiLogger.Transport] that can be used with [HanpekiLogger]
## to output messages to a specified file, apart from the one used by Godot natively
##
class_name HanpekiLoggerFileTransport

const DEFAULT_FILE_PATH = "logs/{DATETIME}.txt"

## List of opened filed descriptors
## This is kept to avoid problems by opening two descriptors to the same file in case
## multiple HanpekiLoggerFileTransport were used by any reason
static var _files: Dictionary[String, FileAccess] = {}

## File descriptor to use
var _file: FileAccess

##
## Constructor with [param options]
##
static func create(options: Options = null) -> HanpekiLoggerFileTransport:
	var instance = HanpekiLoggerFileTransport.new()
	instance.set_options(options)
	var file_path = DEFAULT_FILE_PATH if options == null else options.file_path
	instance._file = _get_file(file_path)
	return instance

func process(data: HanpekiLogger.MsgData) -> void:
	if (!_file): return
	var time = _get_time_str(data)
	var ns = "" if data.ns == HanpekiLogger.NS_UNDEFINED else "[%s]" % data.ns
	var to_log = "%s %s[%s] %s\n" % [time, ns, data.level_name, data.msg]
	_file.store_string(to_log)
	_file.flush()

##
## Get the [FileAccess] given the [param file_path]. This allows reusing them
## if multiple Transports are writing into the same file
##
static func _get_file(file_path: String) -> FileAccess:
	var final_file_path = _get_file_path(file_path)
	if (_files.has(final_file_path)):
		return _files[final_file_path]
	else:
		var file = FileAccess.open(final_file_path, FileAccess.WRITE)
		_files[final_file_path] = file
		return file
	
##
## - Replace placeholders
##   - {DATETIME}
## - Pre-pend "user://" if not available
## - Creates the parent folder if it doesn't exist
## Returns the filepath for the log file
##
static func _get_file_path(filepath: String) -> String:
	var res = filepath
	if (filepath.contains('{DATETIME}')):
		var time = Time.get_datetime_dict_from_system()
		var datetime = "%04d-%02d-%02d_%02d.%02d.%02d" % [
			time.year, time.month, time.day,
			time.hour, time.minute, time.second
		]
		res = res.replace('{DATETIME}', datetime)
	
	var folder_path = _dirname(res.substr("user://".length()) if (res.begins_with("user://")) else res)
	if (folder_path != ""):
		DirAccess.make_dir_recursive_absolute("user://" + folder_path)
		
	return res if res.begins_with("user://") else "user://" + res

##
## posix dirname.
## Returns the directory for the given [param path]
## [code]dirname('a/b/c') # -> 'a/b'[/code]
##
static func _dirname(path: String) -> String:
	var i = path.rfind('/')
	if (i == -1): return ""
	return path.substr(0, i)

func _notification(what):
	if (what == NOTIFICATION_PREDELETE):
		_file.close()

class Options extends Transport.Options:
	## Path to use for the file to write to
	var file_path: String
