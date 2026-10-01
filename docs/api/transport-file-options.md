# <a name="class-options"></a> [HanpekiLogger.Transport.Options](./hanpeki-logger-transport-options.md) > HanpekiLoggerFileTransport.Options

`Options` class, internal to [HanpekiLoggerFileTransport](./transport-file.md). Extends [HanpekiLogger.Transport.Options](./hanpeki-logger-transport-options.md).

Stores the options to create instances of the `HanpekiLoggerFileTransport` class.

## <a name="file-path"></a> file_path: [String](https://docs.godotengine.org/en/4.6/classes/class_string.html)

Path to use for the file to write to.

Relative paths are relative to `user://`, while absolute ones (`user://`, `res://` or OS paths like `C:/logs/game.txt`) are used as they are. Note that `res://` is read-only in exported projects.

If the file can't be opened, the error is reported via [`push_error`](https://docs.godotengine.org/en/4.6/classes/class_@globalscope.html#class-globalscope-method-push-error) and the transport won't log anything.

Multiple transports using the same path share the same opened file, which is closed automatically when the last of them is freed.

Defaults to `"logs/{DATETIME}.txt"`.

The `{DATETIME}` placeholder is available, being replaced with the date and time as `YYYY-MM-DD_hh.mm.ss` when the file is created (parent folders will be created too if not existing already).


## <a name="flush-interval-ms"></a> flush_interval_ms: [int](https://docs.godotengine.org/en/4.6/classes/class_int.html)

Minimum time (in milliseconds) between flushes of the file, as flushing after every message can be a performance hit.

The check is done when a message is logged (no timers or nodes are involved), so messages logged after the last flush are written to disk when the next message is logged, the internal buffer is full, or the file is closed (when the last transport using it is freed).

`0` flushes after every message.

Defaults to `0` in debug builds and `5000` (5 seconds) in release builds.


## <a name="flush-levels"></a> flush_levels: [int](https://docs.godotengine.org/en/4.6/classes/class_int.html)

Union of the levels that are always flushed right away, regardless of [`flush_interval_ms`](#flush-interval-ms), so the important messages are not lost if the app crashes.

Defaults to `HanpekiLogger.ERROR | HanpekiLogger.FATAL`.
