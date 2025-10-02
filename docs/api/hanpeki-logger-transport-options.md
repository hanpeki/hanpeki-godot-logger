# <a name="class-options"></a> HanpekiLogger.Transport.Options

`Options` class, internal to [HanpekiLogger.Transport](./hanpeki-logger-transport.md)

Stores the options to create instances of the `HanpekiLogger.Transport` class.


## <a name="level"></a> level: [int](https://docs.godotengine.org/en/4.5/classes/class_int.html)

Level to use by the [`Transport`](./hanpeki-logger-transport.md).

Defaults to [`HanpekiLogger.INHERIT`](./hanpeki-logger.md#enum-inherit), to use the one from the logger is attached to.


## <a name="time_format"></a> time_format: [HanpekiLogger.Transport.TimeFormat](./hanpeki-logger-transport.md#enum-time-format)

How to format the displayed time.

Defaults to [`TimeFormat.SYSTEM_TIME`](./hanpeki-logger-transport.md#enum-system-time).


## <a name="stack_mode"></a> stack_mode: [`StackLevelConfig`](./hanpeki-logger.md#enum-stacklevelconfig) | Dictionary[[int](https://docs.godotengine.org/en/4.5/classes/class_int.html), [`StackLevelConfig`](./hanpeki-logger.md#enum-stacklevelconfig)]

Whether to include the stack of the log call in the data printed.

Can be provided both as [`StackLevelConfig`](./hanpeki-logger.md#enum-stacklevelconfig) (same for all levels), or per-level via `Dictionary[int, StackLevelConfig]`.

Defaults to:
```
{
  HanpekiLogger.FATAL: StackLevelConfig.FULL_IF_DEBUG,
  HanpekiLogger.ERROR: StackLevelConfig.ORIGIN_IF_DEBUG,
  HanpekiLogger.WARN: StackLevelConfig.ORIGIN_IF_DEBUG,
}
```
