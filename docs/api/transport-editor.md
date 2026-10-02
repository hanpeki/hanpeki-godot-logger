# <a name="class-hanpeki-logger-editor-transport"></a> HanpekiLoggerEditorTransport

Pre-defined **special** transport that sends every message to the `Logs` dock of the Godot editor, through the debugger connection.

Unlike the other transports, it's fully **static** (it's never instantiated), as there's only one editor dock for every logger. It doesn't need to be added manually: every [`HanpekiLogger`](./hanpeki-logger.md) uses it automatically when the game is running from the editor with the plugin enabled. It's always the first to process the messages, and it receives **every** message (with its full stack), regardless of the levels enabled in the logger, the namespaces or the other transports, as the filtering is done in the editor dock.

When the game is not running from the editor (i.e. in exported builds), it's never used, so it doesn't have any performance impact.

The messages are sent to the editor by the debugger connection in the background, so when the game is closing it waits a short time (100 ms) for the pending ones to be sent. This way, messages logged right before quitting are displayed in the dock as well.

## Static methods

### <a name="is_available"></a> is_available

> **static is_available() → [bool](https://docs.godotengine.org/en/4.6/classes/class_bool.html)**

Check if the messages are being sent to the editor dock: the game needs to be running from the editor (with the debugger connected) and the plugin needs to be enabled in the project. The result is cached, as it doesn't change while the game is running.

### Colors

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

## The `Logs` dock

The dock is added by the plugin (in the bottom panel by default, but it can be moved like any other dock). It shows the messages of the running game in a table, with the time, level, namespace and message of each one:

- Messages with stack can be expanded (clicking them) to show it, and clicking a line of the stack opens its script in that line.
- Hovering a message shows a button to copy it (with its stack) as text. `Ctrl+C` copies the hovered message too, while the dock has the keyboard focus.
- The `Level` and `Namespace` columns can be resized by dragging their right border (marked with a thin line). The `Namespace` column is only displayed when there are messages with a namespace.
- Only the latest 10,000 messages are kept.

Below the table:

- `Filter Messages` shows only the messages containing the given text (case-insensitive).
- Clear the messages.
- Preserve the messages when running the game again (instead of clearing them). A separator marks where each new run starts.
- Show or hide the `Namespaces` and `Levels` lists.
- The breakpoint controls (see [Breakpoints](#breakpoints)).

At the right of the table, the `Namespaces` and `Levels` lists show every namespace and level with the number of messages received for them. Their checkboxes show or hide their messages, and their breakpoint icons stop the execution when they are logged.

The state of the dock (filters, toggles, breakpoints, columns and sizes) is saved with the editor layout.

## Breakpoints

The `Logs` dock can also stop the execution when certain messages are logged, like breakpoints set at runtime (using the GDScript [`breakpoint`](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/gdscript_basics.html#keywords) keyword, so no error is logged).

- The breakpoint icons (red dots) next to each level and namespace in the `Levels` and `Namespaces` lists select which messages stop the execution (click them to toggle them, like the breakpoints in the script editor). By default, `FATAL` and `ERROR` are set.
- The `OR` / `AND` toggle selects if any of them is enough (a checked level **or** a checked namespace), or if both are needed (a checked level **and** a checked namespace). When no level or no namespace is checked, `AND` behaves like `OR`.
- The ignore breakpoints toggle (crossed red dot, grayed out when enabled) ignores every log breakpoint.

The configuration is saved by the editor in `res://.godot/hanpeki_logger/breakpoints.cfg` (local to the project, not versioned nor exported), which the game reads when the first logger is created, so it applies from the very first message. Changes while the game is running are sent to it right away. Breakpoints are applied after every transport processed the message, so the message is already logged when the execution stops.

Note that the execution stops inside the logger: the line making the log call is a few frames below in the stack of the `Debugger` dock (the editor tries to show that line in the script editor automatically). Breakpoints are also ignored when the `Skip Breakpoints` option of the `Debugger` dock is enabled.
