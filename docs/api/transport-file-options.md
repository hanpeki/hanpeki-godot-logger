# <a name="class-options"></a> [HanpekiLogger.Transport.Options](./hanpeki-logger-transport-options.md) > HanpekiLoggerFileTransport.Options

`Options` class, internal to [HanpekiLoggerFileTransport](./transport-file.md). Extends [HanpekiLogger.Transport.Options](./hanpeki-logger-transport-options.md).

Stores the options to create instances of the `HanpekiLoggerFileTransport` class.

## <a name="file-path"></a> file_path: [String](https://docs.godotengine.org/en/4.6/classes/class_string.html)

Path to use for the file to write to.

Relative paths are relative to `user://`, while absolute ones (`user://`, `res://` or OS paths like `C:/logs/game.txt`) are used as they are. Note that `res://` is read-only in exported projects.

The file is created when the first message is logged, unless [`create_file_on_start`](#create-file-on-start) is enabled.

If the file can't be opened, the error is reported (once) via [`push_error`](https://docs.godotengine.org/en/4.6/classes/class_@globalscope.html#class-globalscope-method-push-error) and the transport won't log anything.

Multiple transports using the same path share the same opened file, which is closed automatically when the last of them is freed.

Defaults to `"logs/{DATETIME}.txt"`.

The following placeholders are available, both in the file name and in the folders (parent folders will be created if not existing already):

- `{DATETIME}`: replaced with the date and time as `YYYY-MM-DD_hh.mm.ss` when the file is created.
- `{N}`: replaced with the next number after the highest one found in the existing log files matching the path (starting from `1`). i.e. `logs/game-{N}.txt` generates `logs/game-1.txt`, `logs/game-2.txt`, etc.
- `{N,padding}`: same as `{N}`, but padded with zeros to have at least `padding` digits. i.e. `logs/game-{N,3}.txt` generates `logs/game-001.txt`, `logs/game-002.txt`, etc. (and can grow to `logs/game-1000.txt`).

Any other text between braces (i.e. `{TIME}`), or a padding that is not an integer greater than `0` (i.e. `{N,0}`), is reported as an error via `assert` when creating the transport.

Transports created with the same `file_path` during the same session share the same file, even if the placeholders would generate a different one (i.e. a new `{N}` value). Once every transport using it is freed, a new one would generate a new file.


## <a name="max-files"></a> max_files: [int](https://docs.godotengine.org/en/4.6/classes/class_int.html)

Maximum number of log files to keep, including the new one. When a new file is created, the oldest log files are deleted so only the latest `max_files` remain.

Only the files whose path matches [`file_path`](#file-path) (with its placeholders) are considered, so unrelated files in the same folders are never deleted. i.e. with `logs/game-{N}.txt`, `logs/game-3.txt` is a log file, but `logs/notes.txt` or `logs/game-x.txt` are not. When the placeholders are in the folders (i.e. `logs/{DATETIME}/game.txt`), only the log files are deleted from the oldest folders, keeping the folders and any other content.

Files are sorted by their modification time and, if equal, by the values of their placeholders.

If a file can't be deleted (i.e. due to OS permissions), the rotation stops, and it's tried again the next time a log file is created.

It only has effect when `file_path` contains placeholders, as otherwise the same file is used (and overwritten) every time.

`0` disables the rotation.

Defaults to `15`.


## <a name="flush-interval-ms"></a> flush_interval_ms: [int](https://docs.godotengine.org/en/4.6/classes/class_int.html)

Minimum time (in milliseconds) between flushes of the file, as flushing after every message can be a performance hit.

The check is done when a message is logged (no timers or nodes are involved), so messages logged after the last flush are written to disk when the next message is logged, the internal buffer is full, or the file is closed (when the last transport using it is freed).

`0` flushes after every message.

Defaults to `0` in debug builds and `5000` (5 seconds) in release builds.


## <a name="flush-levels"></a> flush_levels: [int](https://docs.godotengine.org/en/4.6/classes/class_int.html)

Union of the levels that are always flushed right away, regardless of [`flush_interval_ms`](#flush-interval-ms), so the important messages are not lost if the app crashes.

Defaults to `HanpekiLogger.ERROR | HanpekiLogger.FATAL`.


## <a name="create-file-on-start"></a> create_file_on_start: [bool](https://docs.godotengine.org/en/4.6/classes/class_bool.html)

When `true`, the log file is created (and the old ones rotated, see [`max_files`](#max-files)) as soon as the transport is created.

When `false`, it's delayed until the first message is logged. This avoids creating empty log files, and allows creating the transport before the values needed for its options are available (i.e. a [`file_path`](#file-path) read from settings loaded later), changing them via [`set_options`](./hanpeki-logger-transport.md) before anything is logged.

Note that the `{DATETIME}` placeholder uses the time when the file is created.

Defaults to `false`.
