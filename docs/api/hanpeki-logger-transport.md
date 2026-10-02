# Transport

A `Transport` is an abstract class defining the interface for specifying how messages sent to the logger should be handled.

## Enums

### <a name="enum-time-format"></a> enum TimeFormat

`TimeFormat` defines the possible values to pass via [`Transport.Options`](./hanpeki-logger-transport-options.md) to the pre-defined [`Transport`](./hanpeki-logger-transport.md) instances. Custom transports can follow how they are implemented and reuse this values for consistency, or provide their own implementations when displaying times (if needed).

- <a name="enum-system-time"></a>`SYSTEM_TIME`: Formats the time as the local system.
- <a name="enum-system-date-time"></a>`SYSTEM_DATE_TIME`: Formats the date and the time as the local system time.
- <a name="enum-utc-time"></a>`UTC_TIME`: Formats the time as the UTC time.
- <a name="enum-utc-date-time"></a>`UTC_DATE_TIME`: Formats the time as the UTC date and time.
- <a name="enum-relative"></a>`RELATIVE`: Formats the time as the elapsed time since the game started.

### <a name="enum-stack-level-mode"></a> enum StackLevelMode

`StackLevelMode` defines how the stack is displayed in the current environment. It's the result of evaluating the [`StackLevelConfig`](./hanpeki-logger.md#enum-stacklevelconfig) values provided via [`HanpekiLogger.Options.stack_mode`](./hanpeki-logger-options.md#stack_mode) and [`Transport.Options.stack_mode`](./hanpeki-logger-transport-options.md#stack_mode), and it's used by the pre-defined [`Transport`](./hanpeki-logger-transport.md) instances when displaying stack traces. Custom transports can follow how they are implemented and reuse this values for consistency, or provide their own implementations when displaying stack traces (if needed).

- <a name="inherit"></a> `INHERIT`: Uses the stack mode of the logger the transport is attached to. Result of evaluating [`StackLevelConfig.INHERIT`](./hanpeki-logger.md#enum-stacklevelconfig-inherit).
- <a name="none"></a> `NONE`: Include no stack information.
- <a name="origin"></a> `ORIGIN`: Only provide the origin (where the log was called from). Note that this is only possible if the stack information is available.
- <a name="full"></a> `FULL`: Provide the full stack. Note that this is only possible if the stack information is available.

## Constants

Colors shared by the pre-defined transports, so the levels are displayed consistently. Each transport can still customize them (i.e. [`HanpekiLoggerConsoleTransport.set_level_format`](./transport-console.md#set_level_format) or [`HanpekiLoggerEditorTransport.set_level_color`](./transport-editor.md#set_level_color)).

- <a name="const-default-level-colors"></a>`DEFAULT_LEVEL_COLORS`: `Dictionary[int, Color]` with the color of each predefined level.
- <a name="const-default-custom-level-color"></a>`DEFAULT_CUSTOM_LEVEL_COLOR`: color for levels without a specific one (usually custom levels).
- <a name="const-default-ns-color"></a>`DEFAULT_NS_COLOR`: color for namespaces without a specific one.

## Instance Methods

### <a name="set_options"></a> set_options

> **set_options(options: [Options](./hanpeki-logger-transport-options.md)) → void**

Apply an `options` object. Providing `null` resets the default options.

Transports extending this class with their own options need to override it, calling `super.set_options(options)` and then applying their own options.

### <a name="set_level"></a> set_level

> **set_level(level: [int](https://docs.godotengine.org/en/4.6/classes/class_int.html), enabled: [bool](https://docs.godotengine.org/en/4.6/classes/class_bool.html)) → void**

Level to use by this `Transport` independently from the one set in the logger.

Note that it works as an **AND** operation. If the logger has a level disabled, the messages won't reach the `Transport`, so this is used mainly to disable levels in the `Transport`.

### <a name="set_time_format"></a> set_time_format

> **set_time_format(time_format: [TimeFormat](#enum-time-format)) → void**

Set how to format the time displayed in the messages logged by this transport.

### <a name="process"></a> abstract process

> **process(\_data: [MsgData](./hanpeki-logger-msg-data.md)) → void**

Method called when the transport needs to log an already "_parsed_" message. Extending classes must implement it.

It's only called for the messages enabled both in the logger and in the transport (see [`set_level`](#set_level)).

## <a name="custom-transports"></a> Custom transports

Custom transports extend `HanpekiLogger.Transport` and implement [`process`](#process). The following helpers are available to them, so they behave like the pre-defined ones:

- `_get_time_str(data: MsgData) → String`: the time of the message formatted as configured with [`set_time_format`](#set_time_format) (`hh:mm:ss.mmm`, or `YYYY-MM-DD hh:mm:ss.mmm` for the `*_DATE_TIME` formats). With `RELATIVE`, it's the time elapsed since the game started.
- `_get_stack_str(data: MsgData) → String`: the stack of the message as text, based on the stack mode resolved for its level (empty if none, or not available).
- `_get_stack_mode(level: int) → StackLevelMode`: the stack mode resolved for the given `level`, combining the transport and logger configuration (see [`Options.stack_mode`](./hanpeki-logger-transport-options.md#stack_mode)), to decide how much of [`MsgData.stack`](./hanpeki-logger-msg-data.md#stack) to display.

```gdscript
class_name RemoteTransport extends HanpekiLogger.Transport

func process(data: HanpekiLogger.MsgData) -> void:
	var text = "%s [%s] %s%s" % [_get_time_str(data), data.level_name, data.msg, _get_stack_str(data)]
	MyRemoteService.send(text)
```

```gdscript
var transport = RemoteTransport.new()
# Optional, the default options inherit the levels and stack mode of the logger
transport.set_options(options)
logger.add_transport(transport)
```

Transports with their own options extend [`Transport.Options`](./hanpeki-logger-transport-options.md) and override [`set_options`](#set_options) (see the pre-defined transports for reference).
