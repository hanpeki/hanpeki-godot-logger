# <a name="class-options"></a> HanpekiLogger.Options

`Options` class, internal to [HanpekiLogger](./hanpeki-logger.md)

Stores the options to create instances of the `HanpekiLogger` class.


## <a name="custom_levels"></a> custom_levels: Array[Dictionary[[int](https://docs.godotengine.org/en/4.5/classes/class_int.html), [String](https://docs.godotengine.org/en/4.5/classes/class_string.html)]]

List of custom levels to add (apart from the default ones) as `{ level: int, name: string }`


## <a name="level"></a> level: [int](https://docs.godotengine.org/en/4.5/classes/class_int.html) | [String](https://docs.godotengine.org/en/4.5/classes/class_string.html)

Minimum level to set as enabled with [`HanpekiLogger.enable_levels_from`](./hanpeki-logger.md#enable_levels_from).

Can be provided as the [`int`](https://docs.godotengine.org/en/4.5/classes/class_int.html) value or the level name (case-insensitive).

Leave to `null` to use only [`levels`](#levels) or the default levels.


## <a name="levels"></a> levels: Array[[int](https://docs.godotengine.org/en/4.5/classes/class_int.html) | [String](https://docs.godotengine.org/en/4.5/classes/class_string.html)]

List of active levels. Any other level will be disabled.

Each level can be provided as the [`int`](https://docs.godotengine.org/en/4.5/classes/class_int.html) value or the level name (case-insensitive).

Leave empty to use only [`levels`](#levels) or the default levels.


## <a name="disable_stack"></a> disable_stack: [`StackLevelConfig`](./hanpeki-logger.md#enum-stacklevelconfig) | Dictionary[[int](https://docs.godotengine.org/en/4.5/classes/class_int.html), [`StackLevelConfig`](./hanpeki-logger.md#enum-stacklevelconfig)]

Whether to include the stack of the log call in the data passed to the transports.

This can be configured the same for all levels by providing a [`StackLevelConfig`](./hanpeki-logger.md#enum-stacklevelconfig) or
per level with a `Dictionary[level, StackLevelConfig]` (being undefined levels
the same as providing [`StackLevelConfig.NONE`](./hanpeki-logger.md#enum-stacklevelconfig-none).
Note that it will be always disabled on non-build builds. _See [`get_stack`](https://docs.godotengine.org/en/4.5/classes/class_@gdscript.html#class-gdscript-method-get-stack) for
limitations and how to enable it on production builds_.