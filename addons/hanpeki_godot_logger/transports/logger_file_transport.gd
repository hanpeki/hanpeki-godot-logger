##
## HanpekiLoggerFileTransport is a [HanpekiLogger.Transport] that can be used with [HanpekiLogger]
## to output messages to a specified file, apart from the one used by Godot natively
##
class_name HanpekiLoggerFileTransport extends HanpekiLogger.Transport

const DEFAULT_FILE_PATH = "logs/{DATETIME}.txt"
## Default value for [member Options.max_files]
const DEFAULT_MAX_FILES = 15
## Format used to replace the [code]{DATETIME}[/code] placeholder
const DATETIME_FORMAT = "%04d-%02d-%02d_%02d.%02d.%02d"
## Regular expression matching the values generated for [code]{DATETIME}[/code]
const DATETIME_REGEX = "\\d{4}-\\d{2}-\\d{2}_\\d{2}\\.\\d{2}\\.\\d{2}"

## Opened files, by their final path, so they are shared when multiple
## HanpekiLoggerFileTransport write into the same file (avoiding opening it twice).
## They are stored as [WeakRef] so the cache doesn't keep them open: each [FileAccess] is closed
## automatically when the last transport using it is freed (or changes its file).
static var _files: Dictionary[String, WeakRef] = {}
## Final path of the file opened for each path template (with placeholders) during the session,
## so transports with the same [member Options.file_path] share the same file, even when
## placeholders would generate a different one (i.e. a new [code]{N}[/code] value)
static var _template_paths: Dictionary[String, String] = {}
## Regular expression to find the supported placeholders:
## [code]{DATETIME}[/code], [code]{N}[/code] and [code]{N,padding}[/code]
static var _placeholder_regex: RegEx = RegEx.create_from_string("\\{(DATETIME|N(?:,(\\d+))?)\\}")
## Regular expression to find anything looking like a placeholder (text between braces),
## to detect unknown ones
static var _any_placeholder_regex: RegEx = RegEx.create_from_string("\\{[^{}/]*\\}")

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
	assert(options.max_files >= 0, "HanpekiLoggerFileTransport max_files can't be negative")
	var file_path_error = _validate_file_path(options.file_path)
	assert(file_path_error.is_empty(), file_path_error)
	_file = _get_file(options.file_path, options.max_files)
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
## Get the [FileAccess] given the [param file_path] (which can contain placeholders).
## This allows reusing them if multiple Transports are writing into the same file.
## When a new file is opened, the old log files matching [param file_path] are rotated, keeping
## only the latest [param max_files] (see [method _rotate_files]).
## Returns [code]null[/code] (reporting the error) if the file can't be opened.
##
static func _get_file(file_path: String, max_files: int = 0) -> FileAccess:
	var template = _get_template(file_path)

	# Reuse the file already opened for the same template in this session
	if _template_paths.has(template):
		var reused_file = _get_opened_file(_template_paths[template])
		if reused_file:
			return reused_file

	var has_placeholders = _placeholder_regex.search(template) != null
	var existing: Array[Dictionary] = []
	if has_placeholders && (max_files > 0 || _has_n_placeholder(template)):
		existing = _find_log_files(template)

	var final_file_path = _get_file_path(template, existing)
	var file = _get_opened_file(final_file_path)
	if file:
		_template_paths[template] = final_file_path
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
	_template_paths[template] = final_file_path
	if max_files > 0:
		_rotate_files(existing, final_file_path, max_files)
	return file


##
## Validate the placeholders of the given [param file_path]: any text between braces must be a
## known placeholder ([code]{DATETIME}[/code], [code]{N}[/code] or [code]{N,padding}[/code]),
## and the padding must be greater than 0.
## Returns the error message, or an empty string if it's valid.
##
static func _validate_file_path(file_path: String) -> String:
	for m in _any_placeholder_regex.search_all(file_path):
		var placeholder = m.get_string()
		var known = _placeholder_regex.search(placeholder)
		if placeholder.begins_with("{N,") && (!known || known.get_string(2).to_int() <= 0):
			return (
				'Invalid padding in placeholder "%s" of HanpekiLoggerFileTransport file_path "%s".'
				% [placeholder, file_path]
				+ " It must be an integer greater than 0"
			)
		if !known || known.get_string() != placeholder:
			return (
				'Unknown placeholder "%s" in HanpekiLoggerFileTransport file_path "%s".'
				% [placeholder, file_path]
				+ " Available ones are {DATETIME}, {N} and {N,padding}"
			)
	return ""


##
## Get the [FileAccess] already opened for the given final [param path], if any
##
static func _get_opened_file(path: String) -> FileAccess:
	return _files[path].get_ref() if _files.has(path) else null


##
## Pre-pend "user://" to relative paths (absolute ones, like "res://" or OS paths, are kept)
##
static func _get_template(file_path: String) -> String:
	return "user://" + file_path if file_path.is_relative_path() else file_path


##
## Check if the given [param template] contains any [code]{N}[/code] placeholder
##
static func _has_n_placeholder(template: String) -> bool:
	for m in _placeholder_regex.search_all(template):
		if m.get_string(1).begins_with("N"):
			return true
	return false


##
## - Pre-pend "user://" for relative paths (absolute ones, like "res://" or OS paths, are kept)
## - Replace placeholders
##   - {DATETIME}: with the current date and time
##   - {N} / {N,padding}: with the next number after the highest one found in the
##     [param existing] log files (see [method _find_log_files]), which are searched if not
##     provided
## - Creates the parent folder if it doesn't exist
## Returns the filepath for the log file
##
static func _get_file_path(file_path: String, existing: Variant = null) -> String:
	var template = _get_template(file_path)

	var n = 1
	if _has_n_placeholder(template):
		if existing == null:
			existing = _find_log_files(template)
		for log_file in existing:
			for value in log_file.values:
				if typeof(value) == TYPE_INT:
					n = maxi(n, value + 1)

	var time = Time.get_datetime_dict_from_system()
	var datetime = (
		DATETIME_FORMAT % [time.year, time.month, time.day, time.hour, time.minute, time.second]
	)

	var res = ""
	var last = 0
	for m in _placeholder_regex.search_all(template):
		res += template.substr(last, m.get_start() - last)
		if m.get_string(1) == "DATETIME":
			res += datetime
		else:
			var padding = m.get_string(2)
			res += str(n).pad_zeros(padding.to_int()) if padding else str(n)
		last = m.get_end()
	res += template.substr(last)

	DirAccess.make_dir_recursive_absolute(res.get_base_dir())
	return res


##
## Find the existing log files matching the given [param template] (a path with placeholders).
## Placeholders can be used both in the file name and in the folders, and only the files whose
## path matches the template are returned, so unrelated files are never included.
## Returns a list of [code]{ path: String, time: int, values: Array }[/code] where
## [code]time[/code] is the modification time and [code]values[/code] the values of the
## placeholders found in the path ([String] for [code]{DATETIME}[/code] and [int] for
## [code]{N}[/code]), in order.
## Returns an empty list if the template has no placeholders.
##
static func _find_log_files(template: String) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	var first = _placeholder_regex.search(template)
	if !first:
		return res
	# The base folder is the deepest one without placeholders
	var slash = template.rfind("/", first.get_start())
	var base = template.substr(0, slash + 1)
	var segments = template.substr(slash + 1).split("/")
	_find_matching_files(base, segments, [], res)
	return res


##
## Recursively find the files in [param folder] matching the remaining path [param segments],
## adding them to [param res] (see [method _find_log_files])
##
static func _find_matching_files(
	folder: String, segments: PackedStringArray, values: Array, res: Array[Dictionary]
) -> void:
	if !DirAccess.dir_exists_absolute(folder):
		return
	var is_file = segments.size() == 1
	var matcher = _get_segment_matcher(segments[0])
	var entries = DirAccess.get_files_at(folder) if is_file else DirAccess.get_directories_at(folder)

	for entry in entries:
		var found = matcher.regex.search(entry)
		if !found:
			continue
		var entry_values = values.duplicate()
		for i in range(matcher.types.size()):
			var value = found.get_string(i + 1)
			entry_values.append(value if matcher.types[i] == "DATETIME" else value.to_int())

		var path = folder.path_join(entry)
		if is_file:
			res.append(
				{"path": path, "time": FileAccess.get_modified_time(path), "values": entry_values}
			)
		else:
			_find_matching_files(path, segments.slice(1), entry_values, res)


##
## Get a matcher for a path [param segment] (file or folder name) with placeholders, as
## [code]{ regex: RegEx, types: Array[String] }[/code] where [code]types[/code] are the
## placeholders captured by each group of the regular expression, in order.
## Any text apart from the placeholders needs to match exactly.
##
static func _get_segment_matcher(segment: String) -> Dictionary:
	var pattern = "^"
	var types: Array[String] = []
	var last = 0
	for m in _placeholder_regex.search_all(segment):
		pattern += _escape_regex(segment.substr(last, m.get_start() - last))
		if m.get_string(1) == "DATETIME":
			pattern += "(%s)" % DATETIME_REGEX
			types.append("DATETIME")
		else:
			var padding = m.get_string(2)
			# padded numbers have at least the padding digits, but can grow longer
			# (invalid paddings, like 0, are treated as no padding)
			pattern += "(\\d{%d,})" % padding.to_int() if padding.to_int() > 0 else "(\\d+)"
			types.append("N")
		last = m.get_end()
	pattern += _escape_regex(segment.substr(last)) + "$"
	return {"regex": RegEx.create_from_string(pattern), "types": types}


##
## Escape the special characters of a regular expression in the given [param text]
##
static func _escape_regex(text: String) -> String:
	var res = ""
	for c in text:
		res += "\\" + c if "\\.^$|?*+()[]{}".contains(c) else c
	return res


##
## Delete the oldest [param existing] log files (see [method _find_log_files]) so there are
## only [param max_files] including the [param new_path] one.
## Files are ordered by modification time and, for files with the same time, by the values of
## their placeholders (which are incremental).
## If a file can't be deleted (i.e. due to OS permissions), the rotation stops and it will be
## tried again the next time.
##
static func _rotate_files(existing: Array[Dictionary], new_path: String, max_files: int) -> void:
	var files = existing.filter(func(log_file): return log_file.path != new_path)
	# the new file counts as one of the max_files
	var to_delete = files.size() - (max_files - 1)
	if to_delete <= 0:
		return

	files.sort_custom(_is_older_log_file)
	for i in range(to_delete):
		if DirAccess.remove_absolute(files[i].path) != OK:
			return


##
## Comparison function to sort log files from the oldest to the newest one
## (see [method _rotate_files])
##
static func _is_older_log_file(a: Dictionary, b: Dictionary) -> bool:
	if a.time != b.time:
		return a.time < b.time
	for i in range(mini(a.values.size(), b.values.size())):
		if a.values[i] != b.values[i]:
			return a.values[i] < b.values[i]
	return false


class Options:
	extends Transport.Options
	## Path to use for the file to write to.
	## Relative paths are relative to [code]user://[/code], while absolute ones
	## ([code]user://[/code], [code]res://[/code] or OS paths) are used as they are.
	## Note that [code]res://[/code] is read-only in exported projects.
	## It accepts the following placeholders (both in the file name and in the folders):
	## - [code]{DATETIME}[/code]: the date and time as [code]YYYY-MM-DD_hh.mm.ss[/code]
	## - [code]{N}[/code]: the next number after the highest one found in the existing log files
	##   (starting from 1)
	## - [code]{N,padding}[/code]: same as [code]{N}[/code], but padded with zeros to have at
	##   least [code]padding[/code] digits (i.e. [code]{N,3}[/code] generates [code]001[/code])
	## Any other text between braces (i.e. [code]{TIME}[/code]) or invalid paddings
	## (i.e. [code]{N,0}[/code]) are reported via [code]assert[/code].
	var file_path: String = DEFAULT_FILE_PATH
	## Maximum number of log files to keep (including the new one), deleting the oldest ones when
	## a new file is created. Only files matching [member file_path] are considered, so unrelated
	## files are never deleted. It only has effect when [member file_path] has placeholders, as
	## otherwise the same file is used (and overwritten) every time.
	## [code]0[/code] disables the rotation.
	var max_files: int = DEFAULT_MAX_FILES
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
