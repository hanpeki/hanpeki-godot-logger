# HanpekiLogger.WithBoundNs

### <a name="set_level"></a>

>**set_level(level: [int](https://docs.godotengine.org/en/4.5/classes/class_int.html), enabled: [bool](https://docs.godotengine.org/en/4.5/classes/class_bool.html)) → void**

Enables or disables the given `level` for this bound instance.
The `level` must be registered in the parent [`HanpekiLogger`](./hanpeki-logger.md).

**Important**: A level must be enabled both in this bound instance **and**
in the parent logger to take effect. Message flow works as follows:

1. [`.message(level, msg)`](#message) is called.
2. If the bound instance has `level` disabled → the message is dropped.
3. If the parent logger has `level` disabled → the message is dropped.
4. Only if both are enabled → the message is delivered to the parent's transports.


### <a name="debug"></a>

>**debug(msg: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html)) → void**

Log the given `msg` with a [`DEBUG`](./hanpeki-logger.md#enum-debug) level using the bound namespace.


### <a name="info"></a>

>**info(msg: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html)) → void**

Log the given `msg` with a [`INFO`](./hanpeki-logger.md#enum-info) level using the bound namespace.


### <a name="core"></a>

>**core(msg: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html)) → void**

Log the given `msg` with a [`CORE`](./hanpeki-logger.md#enum-core) level using the bound namespace.


### <a name="warn"></a>

>**warn(msg: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html)) → void**

Log the given `msg` with a [`WARN`](./hanpeki-logger.md#enum-warn) level using the bound namespace.


### <a name="error"></a>

>**error(msg: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html)) → void**

Log the given `msg` with a [`ERROR`](./hanpeki-logger.md#enum-error) level using the bound namespace.


### <a name="fatal"></a>

>**fatal(msg: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html)) → void**

Log the given `msg` with a [`FATAL`](./hanpeki-logger.md#enum-fatal) level using the bound namespace.


### <a name="message"></a>

>**message(level: [int](https://docs.godotengine.org/en/4.5/classes/class_int.html), msg: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html)) → void**


Log the given `msg` with the given `level` using the bound namespace.
