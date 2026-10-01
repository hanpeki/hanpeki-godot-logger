# <a name="class-hanpeki-logger-assert-transport"></a>[HanpekiLogger.Transport](./hanpeki-logger-transport.md) > HanpekiLoggerAssertTransport

Pre-defined **special** [HanpekiLogger.Transport](./hanpeki-logger-transport.md) that doesn't log messages but instead triggers the [`assert`](https://docs.godotengine.org/en/4.6/classes/class_@gdscript.html#class-gdscript-method-assert) function based on the log message level to help with development.

Note that asserts are not triggered in release builds.

It's recommended to add it as the last transport, so the other ones (file, console, custom, etc.) can process the message before the execution is stopped by the `assert`.

## Static methods

### <a name="static-create"></a> static create

> **static func create(options: [Options](./transport-assert-options.md) = null) → [HanpekiLoggerAssertTransport](#class-hanpeki-logger-assert-transport)**

Returns a new instance of [`HanpekiLoggerAssertTransport`](#class-hanpeki-logger-assert-transport) created with the provided (optional) `options`.
