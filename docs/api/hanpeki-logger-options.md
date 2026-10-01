# <a name="class-options"></a> HanpekiLogger.Options

`Options` class, internal to [HanpekiLogger](./hanpeki-logger.md)

Stores the options to create instances of the `HanpekiLogger` class.

## <a name="custom_levels"></a> custom_levels: Array[[Dictionary](https://docs.godotengine.org/en/4.6/classes/class_dictionary.html)]

List of custom levels to register (apart from the predefined ones) via [`HanpekiLogger.register_level`](./hanpeki-logger.md#register_level), as `{ level: int, name: String }`.

## <a name="level"></a> level: [int](https://docs.godotengine.org/en/4.6/classes/class_int.html) | [String](https://docs.godotengine.org/en/4.6/classes/class_string.html) | [StringName](https://docs.godotengine.org/en/4.6/classes/class_stringname.html)

Minimum level to set as enabled with [`HanpekiLogger.enable_levels_from`](./hanpeki-logger.md#enable_levels_from).

Can be provided as the [`int`](https://docs.godotengine.org/en/4.6/classes/class_int.html) value or the level name (case-insensitive). [`NONE`](./hanpeki-logger.md#enum-none) enables every level and [`MAX_LEVEL`](./hanpeki-logger.md#enum-max-level) disables every level.

Leave to `null` to use only [`levels`](#levels) or keep the current levels.

## <a name="levels"></a> levels: Array[[int](https://docs.godotengine.org/en/4.6/classes/class_int.html) | [String](https://docs.godotengine.org/en/4.6/classes/class_string.html) | [StringName](https://docs.godotengine.org/en/4.6/classes/class_stringname.html)]

List of active levels. Any other level will be disabled, unless [`level`](#level) is also provided, in which case these levels are enabled in addition to the ones enabled by it.

Each level can be provided as the [`int`](https://docs.godotengine.org/en/4.6/classes/class_int.html) value or the level name (case-insensitive). Unknown levels are ignored (triggering an `assert` in debug builds).

[`NONE`](./hanpeki-logger.md#enum-none) is accepted but doesn't enable any level, so `[HanpekiLogger.NONE]` can be used to disable every level.

Leave empty to use only [`level`](#level) or keep the current levels.

## <a name="stack_mode"></a> stack_mode: [`StackLevelConfig`](./hanpeki-logger.md#enum-stacklevelconfig) | Dictionary[[int](https://docs.godotengine.org/en/4.6/classes/class_int.html), [`StackLevelConfig`](./hanpeki-logger.md#enum-stacklevelconfig)]

Default stack mode for the transports inheriting it (which is their default), applied with [`HanpekiLogger.set_stack_mode`](./hanpeki-logger.md#set_stack_mode). Levels not included in a per-level configuration won't provide any stack for those transports.

Can be provided both as [`StackLevelConfig`](./hanpeki-logger.md#enum-stacklevelconfig) (same for all levels), or per-level via `Dictionary[int, StackLevelConfig]`.

Transports with their own stack mode override it, either displaying more or less stack information (see [`Transport.Options.stack_mode`](./hanpeki-logger-transport-options.md#stack_mode)). Note that this is different from levels, where the logger acts as a limit for the transports.

Leave to `null` to keep the current one. New instances use [`DEFAULT_STACK_LEVEL`](./hanpeki-logger.md#const-default-stack-level):

```
{
  HanpekiLogger.FATAL: StackLevelConfig.FULL,
  HanpekiLogger.ERROR: StackLevelConfig.ORIGIN,
  HanpekiLogger.WARN: StackLevelConfig.ORIGIN_IF_DEBUG,
}
```

Note that the stack is only available in release builds when the project setting `debug/settings/gdscript/always_track_call_stacks` is enabled. Otherwise, messages logged from release builds won't include any stack information, regardless of this configuration. _See [`get_stack`](https://docs.godotengine.org/en/4.6/classes/class_@gdscript.html#class-gdscript-method-get-stack) for details_.
