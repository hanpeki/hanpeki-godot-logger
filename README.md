# hanpeki-godot-logger

[![Tests](https://github.com/hanpeki/hanpeki-godot-logger/actions/workflows/tests.yml/badge.svg)](https://github.com/hanpeki/hanpeki-godot-logger/actions/workflows/tests.yml) [![Linting](https://github.com/hanpeki/hanpeki-godot-logger/actions/workflows/linting.yml/badge.svg)](https://github.com/hanpeki/hanpeki-godot-logger/actions/workflows/linting.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> A customizable logging system for Godot with transports and namespaces.

![Logs dock](./examples/img/v1_0_0-editor.png)

## Features

- ☑ Configurable logging system
- ☑ Console and file transports provided by default
- ☑ Customizable and extensible transports
- ☑ Support for custom log levels
- ☑ Flexible, non-linear log levels
- ☑ Dedicated namespaces
- ☑ Per-level, per-namespace and per-transport configuration
- ☑ Configurable stack traces per level and transport
- ☑ Editor `Logs` dock with real-time filters and log breakpoints

Check the [API documentation here](./docs/README.md), see [example code here](./examples/README.md), or keep reading for an introduction.

### What is a transport?

A transport is a way to handle a log event — it "transports" the event from its origin to an output.

For example:

- When a log event is triggered, `HanpekiLoggerConsoleTransport` decides how to display it in the console.
- `HanpekiLoggerFileTransport` writes the log event to a file.

`HanpekiLogger` lets you customize these transports or define new ones with custom formats and outputs (e.g. sending logs to a remote service like Sentry).

### What is a namespace?

A namespace is a way to group and categorize logs. How you use them is up to you.

For example:

- UI nodes could log using the `"UI"` namespace.
- A `ScriptManager` could log with its own namespace.

This makes it easy to enable or disable logs, format them differently, and manage them efficiently. The system has no built-in limit on how you define namespaces.

## Usage

This plugin provides a class called `HanpekiLogger` without creating any singleton, giving you freedom in how you organize your code.

Since this is a utility, there’s no need to attach a `Node` as in some other libraries. You can simply use a static class, or create a singleton instance if that fits your project.

### Quick Example

Because this addon puts first flexibility and freedom over opinionated code, a small configuration step is required. In return, it provides greater customization and flexibility, making it a solid option for projects of any size.

In the following example, `Log` is used for simplicity and readability.

```gdscript
#
# log.gd
#

class_name Log

# Raw logger instance
# Usually wouldn't be used if all the code is properly organized in categories
# but it depends on the project, and it's done here to show usage examples
static var instance: HanpekiLogger

# Logger bound to the "UI" namespace
static var ui: HanpekiLogger.WithBoundNs
# Logger bound to the "ScriptManager" namespace
static var scriptManager: HanpekiLogger.WithBoundNs


# Call it once when the game starts (i.e. from the main scene or an autoload)
static func init() -> void:
	var options = HanpekiLogger.Options.new()
	# Don't log debug messages
	# Levels can be provided by their names (case-insensitive) or values (HanpekiLogger.INFO)
	options.levels = ["fatal", "error", "warn", "info"]
	instance = HanpekiLogger.create(options)

	# Enable logging to the console
	instance.add_transport(HanpekiLoggerConsoleTransport.create())

	# Enable logging to a file (by default in "user://logs/")
	instance.add_transport(HanpekiLoggerFileTransport.create())

	# Initialize the logger with namespaces
	ui = instance.bind_ns(&"UI")
	scriptManager = instance.bind_ns(&"ScriptManager")

	# Disable the "info" level only for the UI namespace
	# Note that namespaces can only disable levels enabled in the logger, not enable new ones
	ui.set_level(HanpekiLogger.INFO, false)

```

```gdscript
#
# From the main scene
#

# Simple messages without namespace can be logged like this
Log.instance.info("Message without namespace")
# Or providing namespaces manually
Log.instance.info("Message with namespace", &"Namespace")
# "debug" messages won't appear with the given options
Log.instance.debug("Debug message")


#
# From some UI menu
#

# The "info" message won't appear, as it's disabled for this namespace
Log.ui.info("Options menu opened")

if (something_bad_happened):
	Log.ui.error("Oh no! Something bad happened")
```

```gdscript
#
# From the Script Manager
#
Log.scriptManager.warn("There's no previous state!")

# The "debug" message won't appear either
Log.scriptManager.debug("Initializing default states")

# But "info" messages will, as they are only disabled for the UI namespace
Log.scriptManager.info("States initialized")
```

### More configuration

- **Custom levels** can be registered with `register_level` (or `Options.custom_levels`). Since the predefined levels are not consecutive powers of two, custom ones can be placed between them.
- **Transports** have their own options (levels, time format, stack traces...) and can be added or removed at any time with `add_transport` / `remove_transport`.
- **Stack traces** are configured per level in the logger (`Options.stack_mode`), and each transport inherits it by default or overrides it with its own `stack_mode`.
- **Editor integration**: when running from the editor, every message (regardless of the configured levels) is shown in the `Logs` dock (in the bottom panel of the editor by default), where it can be filtered by level, namespace and text. Its breakpoint icons stop the execution (like a breakpoint) when logging certain levels or namespaces (`FATAL` and `ERROR` by default).
- **File logs** are flushed periodically (`flush_interval_ms`) and right away for errors (`flush_levels`) to balance performance and safety. Their path accepts `{DATETIME}` and `{N}` placeholders, and only the latest `max_files` (15 by default) are kept.

Check the [API documentation](./docs/README.md) for the details.
