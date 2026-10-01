# HanpekiLogger.WithBoundNs

A logger bound to a parent [`HanpekiLogger`](./hanpeki-logger.md) and a namespace, created with [`HanpekiLogger.bind_ns`](./hanpeki-logger.md#bind_ns).

The transports and registered levels are the same as the parent logger. Its logging methods don't accept a `ns` parameter, as they always use the bound one.

## Instance methods

### <a name="set_level"></a> set_level

> **set_level(level: [int](https://docs.godotengine.org/en/4.6/classes/class_int.html), enabled: [bool](https://docs.godotengine.org/en/4.6/classes/class_bool.html)) → void**

Enables or disables the given `level` for this bound instance.
The `level` must be registered in the parent [`HanpekiLogger`](./hanpeki-logger.md).

**Important**: A level must be enabled both in this bound instance **and**
in the parent logger to take effect. Message flow works as follows:

1. [`.message(level, msg)`](#message) is called.
2. If the bound instance has `level` disabled → the message is dropped.
3. If the parent logger has `level` disabled → the message is dropped.
4. Only if both are enabled → the message is delivered to the parent's transports.

By default, every level is enabled in the bound instance (using the levels of the parent logger), so this is mainly used to disable levels only for this namespace.

### <a name="debug"></a> debug

> **debug(msg: [String](https://docs.godotengine.org/en/4.6/classes/class_string.html)) → void**

Log the given `msg` with a [`DEBUG`](./hanpeki-logger.md#enum-debug) level using the bound namespace.

### <a name="info"></a> info

> **info(msg: [String](https://docs.godotengine.org/en/4.6/classes/class_string.html)) → void**

Log the given `msg` with a [`INFO`](./hanpeki-logger.md#enum-info) level using the bound namespace.

### <a name="core"></a> core

> **core(msg: [String](https://docs.godotengine.org/en/4.6/classes/class_string.html)) → void**

Log the given `msg` with a [`CORE`](./hanpeki-logger.md#enum-core) level using the bound namespace.

### <a name="warn"></a> warn

> **warn(msg: [String](https://docs.godotengine.org/en/4.6/classes/class_string.html)) → void**

Log the given `msg` with a [`WARN`](./hanpeki-logger.md#enum-warn) level using the bound namespace.

### <a name="error"></a> error

> **error(msg: [String](https://docs.godotengine.org/en/4.6/classes/class_string.html)) → void**

Log the given `msg` with a [`ERROR`](./hanpeki-logger.md#enum-error) level using the bound namespace.

### <a name="fatal"></a> fatal

> **fatal(msg: [String](https://docs.godotengine.org/en/4.6/classes/class_string.html)) → void**

Log the given `msg` with a [`FATAL`](./hanpeki-logger.md#enum-fatal) level using the bound namespace.

### <a name="message"></a> message

> **message(level: [int](https://docs.godotengine.org/en/4.6/classes/class_int.html), msg: [String](https://docs.godotengine.org/en/4.6/classes/class_string.html)) → void**

Log the given `msg` with the given `level` using the bound namespace.
