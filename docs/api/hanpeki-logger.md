# <a name="class-hanpeki-logger"></a> HanpekiLogger

Main class providing the logging functionalities. Usually it would be provided as a static class using the singleton pattern.

## Constants

- `VERSION`: Version of the library
- <a name="const-ns-undefined"></a>`NS_UNDEFINED`: Value used for undefined namespaces
- <a name="const-predefined-levels"></a>`PREDEFINED_LEVELS`: Union of the predefined levels (`DEBUG`, `INFO`, `CORE`, `WARN`, `ERROR` and `FATAL`), which can't be deregistered.
- <a name="const-predefined-level-names"></a>`PREDEFINED_LEVEL_NAMES`: `Dictionary[int, String]` with the names of the predefined levels (`"Debug"`, `"Info"`, `"Core"`, `"Warn"`, `"Error"` and `"Fatal"`).
- <a name="const-default-stack-level"></a>`DEFAULT_STACK_LEVEL`: Default stack mode of the logger (see [`Options.stack_mode`](./hanpeki-logger-options.md#stack_mode)):
  ```
  {
    HanpekiLogger.FATAL: StackLevelConfig.FULL,
    HanpekiLogger.ERROR: StackLevelConfig.ORIGIN,
    HanpekiLogger.WARN: StackLevelConfig.ORIGIN_IF_DEBUG,
  }
  ```

## <a name="enums"></a> Enums

List of global enum values available in [`HanpekiLogger`](#class-hanpeki-logger):

- <a name="enum-inherit"></a> `INHERIT`: Special level to be used by transports to use the logger level.
- <a name="enum-none"></a> `NONE`: Not a level itself. Enables every level when used with [`enable_levels_from`](#enable_levels_from), or none when it's the only value in [`Options.levels`](./hanpeki-logger-options.md#levels).
- <a name="enum-debug"></a> `DEBUG`: Debug messages
- <a name="enum-info"></a> `INFO`: Informational messages to follow the code flow
- <a name="enum-core"></a> `CORE`: Important messages but not warning nor errors
- <a name="enum-warn"></a> `WARN`: Unexpected, but non-breaking happenings
- <a name="enum-error"></a> `ERROR`: Unexpected happening that might break parts when not handled
- <a name="enum-fatal"></a> `FATAL`: Only used for errors that make the app crash
- <a name="enum-max-level"></a> `MAX_LEVEL`: Maximum level (`2^62`), just for reference. Custom levels must be lower than it. It can be used with [`enable_levels_from`](#enable_levels_from) to disable every level.

### <a name="enum-stacklevelconfig"></a> enum StackLevelConfig

Values that can be provided via [`HanpekiLogger.Options.stack_mode`](./hanpeki-logger-options.md#stack_mode) and [`HanpekiLogger.Transport.Options.stack_mode`](./hanpeki-logger-transport-options.md#stack_mode).

- <a name="enum-stacklevelconfig-inherit"></a> `INHERIT`: only valid for transports. Uses the stack mode of the logger the transport is attached to.
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
- [`WithBoundNs`](./hanpeki-logger-with-bound-ns.md)

## Static methods

### <a name="static-create"></a> static create

> **static func create(options: [Options](./hanpeki-logger-options.md) = null) → [HanpekiLogger](#class-hanpeki-logger)**

Returns a new instance of [`HanpekiLogger`](#class-hanpeki-logger) created with the provided (optional) `options`.

## Instance methods

### <a name="set_options"></a> set_options

> **set_options(options: [Options](./hanpeki-logger-options.md)) → void**

Apply the given `options` to the logger.

### <a name="get_level_from_name"></a> get_level_from_name

> **get_level_from_name(name: [StringName](https://docs.godotengine.org/en/4.6/classes/class_stringname.html)) → [int](https://docs.godotengine.org/en/4.6/classes/class_int.html) | null**

Get the level as [`int`](https://docs.godotengine.org/en/4.6/classes/class_int.html) from a registered `name` (case-insensitive)

### <a name="get_level_name"></a> get_level_name

> **get_level_name(level: [int](https://docs.godotengine.org/en/4.6/classes/class_int.html)) → [String](https://docs.godotengine.org/en/4.6/classes/class_string.html)**

Get the registered name of the given `level`. The `level` must be registered.

### <a name="register_level"></a> register_level

> **register_level(level: [int](https://docs.godotengine.org/en/4.6/classes/class_int.html), name: [String](https://docs.godotengine.org/en/4.6/classes/class_string.html)) → void**

Register a `level` from its numeric value and the name to display.

`level` must be a positive power of two that hasn't been registered before and lower than [`MAX_LEVEL`](#enum-max-level) (`2^62`). The `name` must be unique (case-insensitive).

This approach allows granularity when deciding what level to enable or disable (i.e. `DEBUG` and `ERROR`) via [`set_level`](#set_level) instead of the usual way which sets the minimum level and everything over it (which is also possible via [`enable_levels_from`](#enable_levels_from)).

Since the pre-defined levels are not consecutive, custom levels can be registered between them in case they want to be ordered by priority (to be used with [`enable_levels_from`](#enable_levels_from)).

### <a name="deregister_level"></a> deregister_level

> **deregister_level(level: [int](https://docs.godotengine.org/en/4.6/classes/class_int.html)) → void**

Deregister a previously registered custom `level`.

Predefined levels ([`PREDEFINED_LEVELS`](#const-predefined-levels)) can't be deregistered, as they are used by the built-in methods ([`debug`](#debug), [`info`](#info), etc.).

### <a name="set_level"></a> set_level

> **set_level(level: [int](https://docs.godotengine.org/en/4.6/classes/class_int.html), enabled: [bool](https://docs.godotengine.org/en/4.6/classes/class_bool.html)) → void**

Set the given `level` `enabled` or `disabled`

### <a name="enable_levels_from"></a> enable_levels_from

> **enable_levels_from(level: [int](https://docs.godotengine.org/en/4.6/classes/class_int.html)) → void**

Set every level greater or equal to the given `level` as enabled, and disable the rest.

Special values:

- [`NONE`](#enum-none) enables every registered level.
- [`MAX_LEVEL`](#enum-max-level) disables every level.

### <a name="set_stack_mode"></a> set_stack_mode

> **set_stack_mode(config: [StackLevelConfig](#enum-stacklevelconfig) | Dictionary[[int](https://docs.godotengine.org/en/4.6/classes/class_int.html), [StackLevelConfig](#enum-stacklevelconfig)]) → void**

Set the default stack mode for the transports inheriting it ([`StackLevelConfig.INHERIT`](#enum-stacklevelconfig-inherit), which is their default), for all levels or per level. Levels not included in a per-level configuration won't provide any stack for those transports.

Transports with their own stack mode override it, either displaying more or less stack information (see [`Transport.Options.stack_mode`](./hanpeki-logger-transport-options.md#stack_mode)). Note that this is different from levels, where the logger acts as a limit for the transports.

[`StackLevelConfig.INHERIT`](#enum-stacklevelconfig-inherit) is not valid here, as there's nothing to inherit from.

Note that the stack is only retrieved for the levels where at least one of the attached transports is going to display it.

### <a name="add_transport"></a> add_transport

> **add_transport(transport: [Transport](./hanpeki-logger-transport.md)) → void**

Add a [Transport](./hanpeki-logger-transport.md) instance to be used by the logger.

It can be one of the provided ones or a custom one.

A transport can only be attached to one logger at a time. Use [`remove_transport`](#remove_transport) before adding it to a different one.

### <a name="remove_transport"></a> remove_transport

> **remove_transport(transport: [Transport](./hanpeki-logger-transport.md)) → [bool](https://docs.godotengine.org/en/4.6/classes/class_bool.html)**

Remove a previously added [Transport](./hanpeki-logger-transport.md) instance, so it doesn't process any more messages from this logger.

Returns `false` if the transport was not attached to this logger.

### <a name="bind_ns"></a> bind_ns

> **bind_ns(ns: [StringName](https://docs.godotengine.org/en/4.6/classes/class_stringname.html)) → [WithBoundNs](./hanpeki-logger-with-bound-ns.md)**

Bind a namespace to the logger instance. This will provide logging methods without accepting the second parameter `ns`, and will use instead always the bound one.

Options, levels and transports will be shared with the logger instance. Each bound instance can also disable levels only for its namespace (see [`WithBoundNs.set_level`](./hanpeki-logger-with-bound-ns.md#set_level)).

### <a name="debug"></a> debug

> **debug(msg: [String](https://docs.godotengine.org/en/4.6/classes/class_string.html), ns: [StringName](https://docs.godotengine.org/en/4.6/classes/class_stringname.html) = [NS_UNDEFINED](#const-ns-undefined)) → void**

Log the given `msg` with a [`DEBUG`](#enum-debug) level using an optional namespace `ns`.

### <a name="info"></a> info

> **info(msg: [String](https://docs.godotengine.org/en/4.6/classes/class_string.html), ns: [StringName](https://docs.godotengine.org/en/4.6/classes/class_stringname.html) = [NS_UNDEFINED](#const-ns-undefined)) → void**

Log the given `msg` with a [`INFO`](#enum-info) level using an optional namespace `ns`.

### <a name="core"></a> core

> **core(msg: [String](https://docs.godotengine.org/en/4.6/classes/class_string.html), ns: [StringName](https://docs.godotengine.org/en/4.6/classes/class_stringname.html) = [NS_UNDEFINED](#const-ns-undefined)) → void**

Log the given `msg` with a [`CORE`](#enum-core) level using an optional namespace `ns`.

### <a name="warn"></a> warn

> **warn(msg: [String](https://docs.godotengine.org/en/4.6/classes/class_string.html), ns: [StringName](https://docs.godotengine.org/en/4.6/classes/class_stringname.html) = [NS_UNDEFINED](#const-ns-undefined)) → void**

Log the given `msg` with a [`WARN`](#enum-warn) level using an optional namespace `ns`.

### <a name="error"></a> error

> **error(msg: [String](https://docs.godotengine.org/en/4.6/classes/class_string.html), ns: [StringName](https://docs.godotengine.org/en/4.6/classes/class_stringname.html) = [NS_UNDEFINED](#const-ns-undefined)) → void**

Log the given `msg` with a [`ERROR`](#enum-error) level using an optional namespace `ns`.

### <a name="fatal"></a> fatal

> **fatal(msg: [String](https://docs.godotengine.org/en/4.6/classes/class_string.html), ns: [StringName](https://docs.godotengine.org/en/4.6/classes/class_stringname.html) = [NS_UNDEFINED](#const-ns-undefined)) → void**

Log the given `msg` with a [`FATAL`](#enum-fatal) level using an optional namespace `ns`.

### <a name="message"></a> message

> **message(level: [int](https://docs.godotengine.org/en/4.6/classes/class_int.html), msg: [String](https://docs.godotengine.org/en/4.6/classes/class_string.html), ns: [StringName](https://docs.godotengine.org/en/4.6/classes/class_stringname.html) = [NS_UNDEFINED](#const-ns-undefined)) → void**

Log the given `msg` with the given `level` using an optional namespace `ns`.
