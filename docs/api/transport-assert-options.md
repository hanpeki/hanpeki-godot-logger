# <a name="class-options"></a> [HanpekiLogger.Transport.Options](./hanpeki-logger-transport-options.md) > HanpekiLoggerAssertTransport.Options

`Options` class, internal to [HanpekiLoggerAssertTransport](./transport-assert-options.md). Extends [HanpekiLogger.Transport.Options](./hanpeki-logger-transport-options.md).

Stores the options to create instances of the `HanpekiLoggerAssertTransport` class.


## <a name="assert-levels"></a> assert_levels: [int](https://docs.godotengine.org/en/4.5/classes/class_int.html)

Union of the log levels that will call `assert(false, data.msg)` on [.process(data)](./hanpeki-logger-transport.md#process).

Note that the level must be processable (enabled in the logger and the transport).

Defaults to `HanpekiLogger.ERROR | HanpekiLogger.FATAL`
