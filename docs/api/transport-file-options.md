# <a name="class-options"></a> [HanpekiLogger.Transport.Options](./hanpeki-logger-transport-options.md) > HanpekiLoggerFileTransport.Options

`Options` class, internal to [HanpekiLoggerFileTransport](./transport-file.md). Extends [HanpekiLogger.Transport.Options](./hanpeki-logger-transport-options.md).

Stores the options to create instances of the `HanpekiLoggerFileTransport` class.


## <a name="file-path"></a> file_path: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html)

Path to use for the file to write to, relative to `user://`.

Defaults to `"logs/{DATETIME}.txt"`.

The `{DATETIME}` placeholder is available, being replaced with the date and time as `YYYY-MM-DD_hh.mm.ss` when the file is created (parent folders will be created too if not existing already).

