# <a name="class-hanpeki-logger-file-transport"></a>[HanpekiLogger.Transport](./hanpeki-logger-transport.md) > HanpekiLoggerFileTransport

Pre-defined [HanpekiLogger.Transport](./hanpeki-logger-transport.md) to log messages into files.

Each message is written as plain text in a line (followed by its stack, if any), as `time [Namespace][Level] message`.

## Constants

- `DEFAULT_FILE_PATH`: Default value for [`Options.file_path`](./transport-file-options.md#file-path) (`"logs/{DATETIME}.txt"`).
- `DEFAULT_MAX_FILES`: Default value for [`Options.max_files`](./transport-file-options.md#max-files) (`15`).

## Static methods

### <a name="static-create"></a> static create

> **static func create(options: [Options](./transport-file-options.md) = null) → [HanpekiLoggerFileTransport](#class-hanpeki-logger-file-transport)**

Returns a new instance of [`HanpekiLoggerFileTransport`](#class-hanpeki-logger-file-transport) created with the provided (optional) `options`.
