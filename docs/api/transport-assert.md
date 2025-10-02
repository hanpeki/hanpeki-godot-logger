# <a name="class-hanpeki-logger-console-transport"></a>[HanpekiLogger.Transport](./hanpeki-logger-transport.md) > HanpekiLoggerAssertTransport

Pre-defined **special** [HanpekiLogger.Transport](./hanpeki-logger-transport.md) that doesn't log messages but instead triggers the [`assert`](https://docs.godotengine.org/en/4.5/classes/class_@gdscript.html#class-gdscript-method-assert) function based on the log message level to help with development.


## Static methods

### <a name="static-create"></a> static create

>**static func create(options: [Options](./transport-assert-options.md)) → [HanpekiLoggerAssertTransport](#class-hanpeki-logger-assert-transport)**

Returns a new instance of [`HanpekiLoggerAssertTransport`](#class-hanpeki-logger-file-transport) created with the provided (required) `options`.
