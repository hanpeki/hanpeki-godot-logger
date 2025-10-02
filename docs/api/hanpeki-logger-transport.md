# Transport

A `Transport` is an abstract class defining the interface for specifying how messages sent to the logger should be handled.


## Enums

### <a name="enum-time-format"></a> enum TimeFormat

`TimeFormat` defines the possible values to pass via [`Transport.Options`](./hanpeki-logger-transport-options.md) to the pre-defined [`Transport`](./hanpeki-logger-transport.md) instances. Custom transports can follow how they are implemented and reuse this values for consistency, or provide their own implementations when displaying times (if needed).

- <a name="enum-system-time"></a>`SYSTEM_TIME`: Formats the time as the local system.
- <a name="enum-system-date-time"></a>`SYSTEM_DATE_TIME`: Formats the date and the time as the local system time.
- <a name="enum-utc-time"></a>`UTC_TIME`: Formats the time as the UTC time.
- <a name="enum-utc-date-time"></a>`UTC_DATE_TIME`: Formats the time as the UTC date and time.
- <a name="enum-relative"></a>`RELATIVE`: Formats the time as the ellapsed time since the game started.

### <a name="enum-stack-level-mode"></a> enum StackLevelMode

`StackLevelMode` defines the possible values to pass via [`Transport.Options`](./hanpeki-logger-transport-options.md) to the pre-defined [`Transport`](./hanpeki-logger-transport.md) instances. Custom transports can follow how they are implemented and reuse this values for consistency, or provide their own implementations when displaying stack traces (if needed).

- <a name="inherit"></a> `INHERIT`: Special level to be used by transports to use the logger level.
- <a name="none"></a> `NONE`: Include no stack information.
- <a name="origin"></a> `ORIGIN`: Only provide the origin (where the log was called from). Note that this is only possible if the stack information is available.
- <a name="full"></a> `FULL`: Provide the full stack. Note that this is only possible if the stack information is available.

## Instance Methods

### <a name="set_options"></a> set_options

>**set_options(options: [Options](./hanpeki-logger-transport-options.md)) → void**

Apply a `options` object.


### <a name="set_level"></a> set_level

>**set_level(level: [int](https://docs.godotengine.org/en/4.5/classes/class_int.html), enabled: [bool](https://docs.godotengine.org/en/4.5/classes/class_bool.html)) → void**

Level to use by this `Transport` independently from the one set in the logger.

Note that it works as an **AND** operation. If the logger has a level disabled, the messages won't reach the `Transport`, so this is used mainly to disable levels in the `Transport`.


### <a name="set_time_format"></a> set_time_format

>**set_time_format(time_format: [TimeFormat](#enum-time-format)) → void**

Set how to format the time displayed in the messages logged by this transport.


### <a name="process"></a> abstract process

>**process(_data: [MsgData](./hanpeki-logger-msg-data.md)) → void**

Method called when the transport needs to log an already "_parsed_" message. Extending classes must implement it.
