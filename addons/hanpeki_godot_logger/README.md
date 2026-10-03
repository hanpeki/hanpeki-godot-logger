# <img src="https://raw.githubusercontent.com/hanpeki/hanpeki-godot-logger/main/icon.svg" height="24" /> Hanpeki Godot Logger

> A customizable logging system for Godot with transports and namespaces.

Full documentation, examples and source code: https://github.com/hanpeki/hanpeki-godot-logger

## Features

- Configurable logging system
- Console and file transports provided by default
- Customizable and extensible transports
- Support for custom log levels
- Flexible, non-linear log levels
- Dedicated namespaces
- Per-level, per-namespace and per-transport configuration
- Configurable stack traces per level and transport
- Editor `Logs` dock with real-time filters and log breakpoints

## Quick start

1. Enable the plugin in `Project > Project Settings > Plugins`.
2. Create a logger and add the transports you want to use:

```gdscript
class_name Log

static var instance: HanpekiLogger
static var ui: HanpekiLogger.WithBoundNs


# Call it once when the game starts (i.e. from the main scene or an autoload)
static func init() -> void:
	var options = HanpekiLogger.Options.new()
	options.levels = ["fatal", "error", "warn", "info"]
	instance = HanpekiLogger.create(options)

	# Log to the console and to a file (by default in "user://logs/")
	instance.add_transport(HanpekiLoggerConsoleTransport.create())
	instance.add_transport(HanpekiLoggerFileTransport.create())

	# Logger bound to the "UI" namespace
	ui = instance.bind_ns(&"UI")
```

3. Log from anywhere:

```gdscript
Log.instance.info("Message without namespace")
Log.ui.error("Oh no! Something bad happened")
```

When running from the editor, every message is also shown in the `Logs` dock of the bottom panel, where it can be filtered by level, namespace and text.

## Documentation

- [README](https://github.com/hanpeki/hanpeki-godot-logger/blob/main/README.md)
- [API documentation](https://github.com/hanpeki/hanpeki-godot-logger/blob/main/docs/README.md)
- [Examples](https://github.com/hanpeki/hanpeki-godot-logger/blob/main/examples/README.md)

## License

MIT. See the [LICENSE](./LICENSE) file in this folder.
