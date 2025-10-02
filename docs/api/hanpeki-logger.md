# <a name="class-hanpeki-logger"></a> HanpekiLogger

Main class providing the logging functionalities. Usually it would be provided as a static class using the singleton pattern.

## Constants

- `VERSION`: Version of the library
- <a name="const-ns-undefined"></a>`NS_UNDEFINED`: Value used for undefined namespaces

## <a name="enums"></a> Enums

List of global enum values available in [`HanpekiLogger`](#class-hanpeki-logger):

- <a name="enum-inherit"></a> `INHERIT`: Special level to be used by transports to use the logger level.
- <a name="enum-none"></a> `NONE`: The lowest level, only used for set the Logger silent
- <a name="enum-debug"></a> `DEBUG`: Debug messages
- <a name="enum-info"></a> `INFO`: Informational messages to follow the code flow
- <a name="enum-core"></a> `CORE`: Important messages but not warning nor errors
- <a name="enum-warn"></a> `WARN`: Unexpected, but non-breaking happenings
- <a name="enum-error"></a> `ERROR`: Unexpected happening that might break parts when not handled
- <a name="enum-fatal"></a> `FATAL`: Only used for errors that make the app crash


### enum StackLevelConfig

Values that can be provided via [`HanpekiLogger.Transport.Options`](./hanpeki-logger-transport-options.md).

- <a name="enum-stacklevelconfig-none"></a> `NONE`: stack is always disabled regardless of the environment.
- <a name="enum-stacklevelconfig-origin"></a> `ORIGIN`: stack is always displayed as only the origin of the log call (when available)
- <a name="enum-stacklevelconfig-full"></a> `FULL`: stack is always displayed as the full stack from the line that made the log call
- <a name="enum-stacklevelconfig-origin-if-debug"></a> `ORIGIN_IF_DEBUG`: stack is displayed as the origin of the log call on debug builds, but disabled on production builds.
- <a name="enum-stacklevelconfig-full-if-debug"></a> `FULL_IF_DEBUG`: stack is fully displayed on debug builds, but disabled on production builds.
- <a name="enum-stacklevelconfig-origin-if-prod"></a> `ORIGIN_IF_PROD`: stack is displayed as the origin of the log call on production builds (when available), but disabled on debug builds.
- <a name="enum-stacklevelconfig-full-if-prod"></a> `FULL_IF_PROD`: stack is fully displayed on production builds (when available), but disabled on debug builds.


## Internal classes

- [`Options`](./hanpeki-logger-options.md)
- [`MsgData`](./hanpeki-logger-msg-data.md)
- [`Transport`](./hanpeki-logger-transport.md)

## Static methods

### <a name="static-create"></a> static create

>**static func create(options: [Options](./hanpeki-logger-options.md) = null) → [HanpekiLogger](#class-hanpeki-logger)**

Returns a new instance of [`HanpekiLogger`](#class-hanpeki-logger) created with the provided (optional) `options`.


## Instance methods

### <a name="set_options"></a> set_options

>**set_options(options: [Options](./hanpeki-logger-options.md)) → void**

Apply the given `options` to the logger.


### <a name="get_level_from_name"></a> get_level_from_name

>**get_level_from_name(name: [StringName](https://docs.godotengine.org/en/4.5/classes/class_stringname.html)) → [int](https://docs.godotengine.org/en/4.5/classes/class_int.html) | null**

Get the level as [`int`](https://docs.godotengine.org/en/4.5/classes/class_int.html) from a registered `name` (case-insensitive)


### <a name="get_level_name"></a> get_level_name

>**get_level_name(level: [int](https://docs.godotengine.org/en/4.5/classes/class_int.html)) → [String](https://docs.godotengine.org/en/4.5/classes/class_string.html) | null**

Get the name `level` as the registered [String](https://docs.godotengine.org/en/4.5/classes/class_string.html).


### <a name="register_level"></a> register_level

>**register_level(level: [int](https://docs.godotengine.org/en/4.5/classes/class_int.html), name: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html)) → void**

Register a `level` from its numeric value and the name to display.

`level` must be a positive power of two that hasn't been registered before and less than `2^63`.

This approach allows granularity when deciding what level to enable or disable (i.e. `DEBUG` and `ERROR`) via [`set_level`](#set_level) instead of the usual way which sets the minimum level and everything over it (which is also possible via [`enable_levels_from`](#enable_levels_from)).

Since the pre-defined levels are not consecutive, custom levels can be registered between them in case they want to be ordered by priority (to be used with [`enable_levels_from`](#enable_levels_from)).


### <a name="deregister_level"></a> deregister_level

>**deregister_level(level: [int](https://docs.godotengine.org/en/4.5/classes/class_int.html)) → void**

Deregister a previously registered `level`.


### <a name="set_level"></a> set_level

>**set_level(level: [int](https://docs.godotengine.org/en/4.5/classes/class_int.html), enabled: [bool](https://docs.godotengine.org/en/4.5/classes/class_bool.html)) → void**

Set the given `level` `enabled` or `disabled`


### <a name="enable_levels_from"></a> enable_levels_from

>**enable_levels_from(level: [int](https://docs.godotengine.org/en/4.5/classes/class_int.html)) → void**

Set every level greater or equal to the given `level` as enabled, and disable the rest.


### <a name="add_transport"></a> add_transport

>**add_transport(transport: [Transport](./hanpeki-logger-transport.md))) → void**

Add a [Transport](./hanpeki-logger-transport.md) instance to be used by the logger.

It can be one of the provided ones or a custom one.


### <a name="bind_ns"></a> bind_ns

>**bind_ns(ns: [StringName](https://docs.godotengine.org/en/4.5/classes/class_stringname.html)) → [WithBoundNs](./hanpeki-logger-with-bound-ns)**

Bind a namespace to the logger instance. This will provide logging methods without accepting the second parameter `ns`, and will use instead always the bound one.

Options, levels and transports will be shared with the logger instance.


### <a name="debug"></a> debug

>**debug(msg: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html), ns: [StringName](https://docs.godotengine.org/en/4.5/classes/class_stringname.html) = [NS_UNDEFINED](#const-ns-undefined)) → void**

Log the given `msg` with a [`DEBUG`](#enum-debug) level using an optional namespace `ns`.

### <a name="info"></a> info

>**info(msg: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html), ns: [StringName](https://docs.godotengine.org/en/4.5/classes/class_stringname.html) = [NS_UNDEFINED](#const-ns-undefined)) → void**

Log the given `msg` with a [`INFO`](#enum-info) level using an optional namespace `ns`.


### <a name="core"></a> core

>**core(msg: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html), ns: [StringName](https://docs.godotengine.org/en/4.5/classes/class_stringname.html) = [NS_UNDEFINED](#const-ns-undefined)) → void**

Log the given `msg` with a [`CORE`](#enum-core) level using an optional namespace `ns`.


### <a name="warn"></a> warn

>**warn(msg: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html), ns: [StringName](https://docs.godotengine.org/en/4.5/classes/class_stringname.html) = [NS_UNDEFINED](#const-ns-undefined)) → void**

Log the given `msg` with a [`WARN`](#enum-warn) level using an optional namespace `ns`.


### <a name="error"></a> error

>**error(msg: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html), ns: [StringName](https://docs.godotengine.org/en/4.5/classes/class_stringname.html) = [NS_UNDEFINED](#const-ns-undefined)) → void**

Log the given `msg` with a [`ERROR`](#enum-error) level using an optional namespace `ns`.


### <a name="fatal"></a> fatal

>**fatal(msg: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html), ns: [StringName](https://docs.godotengine.org/en/4.5/classes/class_stringname.html) = [NS_UNDEFINED](#const-ns-undefined)) → void**

Log the given `msg` with a [`FATAL`](#enum-fatal) level using an optional namespace `ns`.


### <a name="message"></a> message

>**message(level: [int](https://docs.godotengine.org/en/4.5/classes/class_int.html), msg: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html), ns: [StringName](https://docs.godotengine.org/en/4.5/classes/class_stringname.html) = [NS_UNDEFINED](#const-ns-undefined)) → void**


Log the given `msg` with the given `level` using an optional namespace `ns`.
