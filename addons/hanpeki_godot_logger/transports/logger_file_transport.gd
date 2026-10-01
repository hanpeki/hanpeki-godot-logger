##
## HanpekiLoggerFileTransport is a [HanpekiLogger.Transport] that can be used with [HanpekiLogger]
## to output messages to a specified file, apart from the one used by Godot natively
##
class_name HanpekiLoggerFileTransport extends HanpekiLogger.Transport

const DEFAULT_FILE_PATH = "logs/{DATETIME}.txt"

## Opened files, by their final path, so they are shared when multiple
## HanpekiLoggerFileTransport write into the same file (avoiding opening it twice).
## They are stored as [WeakRef] so the cache doesn't keep them open: each [FileAccess] is closed
## automatically when the last transport using it is freed (or changes its file).
static var _files: Dictionary[String, WeakRef] = {}

## File to write into ([code]null[/code] if it couldn't be opened)
var _file: FileAccess
## Minimum time between flushes, in milliseconds (see [member Options.flush_interval_ms])
var _flush_interval_ms: int
## Levels that are always flushed right away (see [member Options.flush_levels])
var _flush_levels: int
## Time of the last flush, as [member HanpekiLogger.MsgData.utime]
var _last_flush: int = 0


##
## Constructor with [param options]
##
static func create(options: Options = null) -> HanpekiLoggerFileTransport:
	if !options:
		options = Options.new()
	return HanpekiLoggerFileTransport.new(options)


func process(data: HanpekiLogger.MsgData) -> void:
	if !_file:
		return
	var time = _get_time_str(data)
	var ns = "" if data.ns == HanpekiLogger.NS_UNDEFINED else "[%s]" % data.ns
	var to_log = "%s %s[%s] %s%s\n" % [time, ns, data.level_name, data.msg, _get_stack_str(data)]
	_file.store_string(to_log)
	# data.utime is used as the current time to avoid getting it again
	if data.level & _flush_levels != 0 || data.utime - _last_flush >= _flush_interval_ms:
		_file.flush()
		_last_flush = data.utime


func set_options(options: Transport.Options) -> void:
	# Godot OOP is not the best...
	assert(
		options is Options,
		"HanpekiLoggerFileTransport.setOptions requires HanpekiLoggerFileTransport.Options"
	)
	super.set_options(options)
	var file_path = options.file_path
	_file = _get_file(file_path)
	_flush_interval_ms = options.flush_interval_ms
	_flush_levels = options.flush_levels


##
## Called on instanciation.
## It checks that a proper Options object has been provided, and encourages to use the static
## method [method create] as a constructor/builder.
##
func _init(options: Options) -> void:
	assert(options, "No options found. Please use HanpekiLoggerFileTransport.create()")
	set_options(options)


##
## Get the [FileAccess] given the [param file_path]. This allows reusing them
## if multiple Transports are writing into the same file.
## Returns [code]null[/code] (reporting the error) if the file can't be opened.
##
static func _get_file(file_path: String) -> FileAccess:
	var final_file_path = _get_file_path(file_path)
	var file = _files[final_file_path].get_ref() if _files.has(final_file_path) else null
	if file:
		return file

	file = FileAccess.open(final_file_path, FileAccess.WRITE)
	if !file:
		push_error(
			(
				'HanpekiLoggerFileTransport can\'t open the log file "%s": %s'
				% [final_file_path, error_string(FileAccess.get_open_error())]
			)
		)
		# Not cached, so it's retried the next time
		_files.erase(final_file_path)
		return null

	_files[final_file_path] = weakref(file)
	return file


##
## - Replace placeholders
##   - {DATETIME}
## - Pre-pend "user://" for relative paths (absolute ones, like "res://" or OS paths, are kept)
## - Creates the parent folder if it doesn't exist
## Returns the filepath for the log file
##
static func _get_file_path(filepath: String) -> String:
	var res = filepath
	if filepath.contains("{DATETIME}"):
		var time = Time.get_datetime_dict_from_system()
		var datetime = (
			"%04d-%02d-%02d_%02d.%02d.%02d"
			% [time.year, time.month, time.day, time.hour, time.minute, time.second]
		)
		res = res.replace("{DATETIME}", datetime)

	if res.is_relative_path():
		res = "user://" + res

	DirAccess.make_dir_recursive_absolute(res.get_base_dir())
	return res


class Options:
	extends Transport.Options
	## Path to use for the file to write to.
	## Relative paths are relative to [code]user://[/code], while absolute ones
	## ([code]user://[/code], [code]res://[/code] or OS paths) are used as they are.
	## Note that [code]res://[/code] is read-only in exported projects.
	var file_path: String = DEFAULT_FILE_PATH
	## Minimum time (in milliseconds) between flushes of the file, as flushing after every message
	## can be a performance hit. The check is done when a message is logged, so messages logged
	## after the last flush are written when the next message is logged, the internal buffer is
	## full, or the file is closed (when the last transport using it is freed).
	## [code]0[/code] flushes after every message.
	## Defaults to [code]0[/code] in debug builds and [code]5000[/code] (5 seconds) in release ones.
	var flush_interval_ms: int = 0 if OS.is_debug_build() else 5000
	## Union of the levels that are always flushed right away, regardless of
	## [member flush_interval_ms], so the important messages are not lost if the app crashes.
	## Defaults to [code]HanpekiLogger.ERROR | HanpekiLogger.FATAL[/code].
	var flush_levels: int = HanpekiLogger.ERROR | HanpekiLogger.FATAL