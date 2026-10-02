# <a name="class-hanpeki-logger-editor-transport"></a> HanpekiLoggerEditorTransport

Pre-defined **special** transport that sends every message to the `Logs` dock of the Godot editor, through the debugger connection.

Unlike the other transports, it's fully **static** (it's never instantiated), as there's only one editor dock for every logger. It doesn't need to be added manually: every [`HanpekiLogger`](./hanpeki-logger.md) uses it automatically when the game is running from the editor with the plugin enabled. It's always the first to process the messages, and it receives **every** message (with its full stack), regardless of the levels enabled in the logger, the namespaces or the other transports, as the filtering is done in the editor dock.

When the game is not running from the editor (i.e. in exported builds), it's never used, so it doesn't have any performance impact.

## Static methods

The colors used in the editor dock are configured statically, as there's only one dock for every logger. They can be set at any time (even before creating any logger), and calling them when not running from the editor doesn't have any effect apart from storing the colors.

By default, the predefined levels use the same colors as the other pre-defined transports ([`DEFAULT_LEVEL_COLORS`](./hanpeki-logger-transport.md#const-default-level-colors)).

### <a name="set_level_color"></a> set_level_color

> **static set_level_color(level: [int](https://docs.godotengine.org/en/4.6/classes/class_int.html), color: [Color](https://docs.godotengine.org/en/4.6/classes/class_color.html)) → void**

Set the `color` to display the given `level` in the editor dock.

### <a name="set_level_default_color"></a> set_level_default_color

> **static set_level_default_color(color: [Color](https://docs.godotengine.org/en/4.6/classes/class_color.html)) → void**

Set the `color` to display levels without a specific one (usually custom levels). Defaults to [`DEFAULT_CUSTOM_LEVEL_COLOR`](./hanpeki-logger-transport.md#const-default-custom-level-color).

### <a name="set_ns_color"></a> set_ns_color

> **static set_ns_color(ns: [StringName](https://docs.godotengine.org/en/4.6/classes/class_stringname.html), color: [Color](https://docs.godotengine.org/en/4.6/classes/class_color.html)) → void**

Set the `color` to display the given namespace `ns` in the editor dock.

### <a name="set_ns_default_color"></a> set_ns_default_color

> **static set_ns_default_color(color: [Color](https://docs.godotengine.org/en/4.6/classes/class_color.html)) → void**

Set the `color` to display namespaces without a specific one. Defaults to [`DEFAULT_NS_COLOR`](./hanpeki-logger-transport.md#const-default-ns-color).

## Example

```gdscript
# Use the same colors as configured for the console transport
HanpekiLoggerEditorTransport.set_level_color(Log.IMPORTANT, Color.ORANGE)
HanpekiLoggerEditorTransport.set_ns_color(&"ScriptManager", Color(0.6, 0.9, 0.6))
```

## Breakpoints

The `Logs` dock can also stop the execution when certain messages are logged, like breakpoints set at runtime (using the GDScript [`breakpoint`](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/gdscript_basics.html#keywords) keyword, so no error is logged).

- The breakpoint icons (red dots) next to each level and namespace in the `Levels` and `Namespaces` lists select which messages stop the execution (click them to toggle them, like the breakpoints in the script editor). By default, `FATAL` and `ERROR` are set.
- The `OR` / `AND` toggle selects if any of them is enough (a checked level **or** a checked namespace), or if both are needed (a checked level **and** a checked namespace). When no level or no namespace is checked, `AND` behaves like `OR`.
- The skip breakpoints toggle ignores every log breakpoint.

The configuration is saved by the editor in `res://.godot/hanpeki_logger/breakpoints.cfg` (local to the project, not versioned nor exported), which the game reads when the first logger is created, so it applies from the very first message. Changes while the game is running are sent to it right away. Breakpoints are applied after every transport processed the message, so the message is already logged when the execution stops.

Note that the execution stops inside the logger: the line making the log call is a few frames below in the stack of the `Debugger` dock (the editor tries to show that line in the script editor automatically). Breakpoints are also ignored when the `Skip Breakpoints` option of the `Debugger` dock is enabled.
