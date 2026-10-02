# <a name="class-MsgData"></a> HanpekiLogger.MsgData

`MsgData` class, internal to [HanpekiLogger](./hanpeki-logger.md)

Stores the data to pass when calling [`Transport.process`](./hanpeki-logger-transport.md#process)

## <a name="level"></a> level: [int](https://docs.godotengine.org/en/4.6/classes/class_int.html)

Message level.

## <a name="level_name"></a> level_name: [String](https://docs.godotengine.org/en/4.6/classes/class_string.html)

Name of the message level.

## <a name="time"></a> time: [int](https://docs.godotengine.org/en/4.6/classes/class_int.html)

Unix time (elapsed seconds from 1970).

To avoid reading the system clock on every message, it's calculated from [`utime`](#utime) and the Unix time when the app started. This keeps the time between messages consistent, but changes in the system clock while the app is running (e.g. NTP sync or DST changes) won't be reflected.

## <a name="utime"></a> utime: [int](https://docs.godotengine.org/en/4.6/classes/class_int.html)

Milliseconds since the app started.

## <a name="stack"></a> stack: Array[Dictionary]

Result from [`get_stack`](https://docs.godotengine.org/en/4.6/classes/class_@gdscript.html#class-gdscript-method-get-stack) with the entries for the logger internal code filtered out, so `stack[0]` will always be
the line making the log call.

Will be `Array[Dictionary]` unless not available, in which case it will be `null` (see [`get_stack`](https://docs.godotengine.org/en/4.6/classes/class_@gdscript.html#class-gdscript-method-get-stack) for details on how to enable for production builds).

It's only retrieved when at least one of the transports processing the message is going to display it, based on the stack mode of the logger and the transports. Transports should only display the part of it allowed by their resolved stack mode (see [custom transports](./hanpeki-logger-transport.md#custom-transports)).

## <a name="ns"></a> ns: [StringName](https://docs.godotengine.org/en/4.6/classes/class_stringname.html)

Namespace

## <a name="msg"></a> msg: [String](https://docs.godotengine.org/en/4.6/classes/class_string.html)

Message text
