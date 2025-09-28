# hanpeki-godot-logger

> A customizable logging system for Godot with transports and namespaces.

[![Tests](https://github.com/hanpeki/hanpeki-godot-logger/actions/workflows/tests.yml/badge.svg)](https://github.com/hanpeki/hanpeki-godot-logger/actions/workflows/tests.yml) [![Linting](https://github.com/hanpeki/hanpeki-godot-logger/actions/workflows/linting.yml/badge.svg)](https://github.com/hanpeki/hanpeki-godot-logger/actions/workflows/linting.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- ☑ Configurable logging system
- ☑ Console and file transports provided by default
- ☑ Customizable and extensible transports
- ☑ Support for custom log levels
- ☑ Flexible, non-linear log levels
- ☑ Dedicated namespaces
- ☑ Per-level and per-namespace configuration

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

### Example

The provided class is named `HanpekiLogger` to avoid conflicts with common class names such as `Log` or `Logger`, providing full freedom to choose any name when creating an instance.

Because of this design choice, a small configuration step is required. In return, it provides greater customization and flexibility, making it a solid option for projects of any size.

In the following example, `Log` is used for simplicity and readability.

```gdscript
#
# log.gd
#

class_name Log

# Logger bound to the "UI" namespace
static var ui: HanpekiLogger.WithBindedNs
# Logger bound to the "ScriptManager" namespace
static var scriptManager: HanpekiLogger.WithBindedNs

static func init() -> void:
  var options = HanpekiLogger.Options.new()
  # Don't log debug and info messages by default
  options.levels = ["fatal", "error", "warn"]
  var instance = HanpekiLogger.create(options)

  # Enable logging to the console
  instance.add_transport(HanpekiLoggerConsoleTransport.create())

  # Enable logging to a file
  instance.add_transport(HanpekiLoggerFileTransport.create())

  # Initialize the logger with namespaces
  ui = instance.bind_ns(&"UI")
  scriptManager = instance.bind_ns(&"ScriptManager")

  # Enable the "info" level only for the ScriptManager namespace
  scriptManager.enable_level(HanpekiLogger.INFO, true)

```

```gdscript
#
# From some UI menu
#

# The "info" message won't appear with the given options
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

# But "info" messages will do just for this namespace!
Log.scriptManager.info("States initialized")
```

## API Reference

Coming soon...

## Development notes

### Class.create() vs Class.new()

Since Godot doesn't allow overriding the `.init()` method properly to provide constructors with required parameters (actually it's allowed because the original signature has no methods, but not standard), the preferred approach to create instances is by calling their static `.create()` method.

```gdscript
# Don't
var logger = HanpekiLogger.new()

# Do
var logger = HanpekiLogger.create()
```
