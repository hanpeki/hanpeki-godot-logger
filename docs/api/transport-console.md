# <a name="class-hanpeki-logger-console-transport"></a>[HanpekiLogger.Transport](./hanpeki-logger-transport.md) > HanpekiLoggerConsoleTransport

Pre-defined [HanpekiLogger.Transport](./hanpeki-logger-transport.md) to log messages in the console in plain or formatted text.

## Static methods

### <a name="static-create"></a> static create

>**static func create(options: [Options](./transport-console-options.md) = null) → [HanpekiLoggerConsoleTransport](#class-hanpeki-logger-console-transport)**

Returns a new instance of [`HanpekiLoggerConsoleTransport`](#class-hanpeki-logger-console-transport) created with the provided (optional) `options`.

## Instance methods

### set_level_format

> **set_level_format(level:  [int](https://docs.godotengine.org/en/4.5/classes/class_int.html), format: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html)) -> void**

Set the format to use when printing the level name, as a template string accepting [BBTags](https://docs.godotengine.org/en/latest/tutorials/ui/bbcode_in_richtextlabel.html), with the `{level}` placeholder.


### set_level_default_format

> **set_level_default_format(format: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html)) -> void**

Set the format to use when printing a namespace name without an explicit format configured, as a template string accepting [BBTags](https://docs.godotengine.org/en/latest/tutorials/ui/bbcode_in_richtextlabel.html), with the `{level}` placeholder.


### set_ns_format

> **set_ns_format(ns: [StringName](https://docs.godotengine.org/en/4.5/classes/class_stringname.html), format: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html)) -> void**

Set the format to use when printing a namespace name, as a template string accepting [BBTags](https://docs.godotengine.org/en/latest/tutorials/ui/bbcode_in_richtextlabel.html), with the `{ns}` placeholder.



### set_ns_default_format

> **set_ns_default_format(format: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html)) -> void**

Set the format to use when printing a level name without a format configured, (usually custom levels), as a template string accepting [BBTags](https://docs.godotengine.org/en/latest/tutorials/ui/bbcode_in_richtextlabel.html), with the `{ns}` placeholder.



### set_stack_format

> **set_stack_format(format: [String](https://docs.godotengine.org/en/4.5/classes/class_string.html)) -> void**

Set the format to use when printing a stack (if configured to do so and available), as a template string accepting [BBTags](https://docs.godotengine.org/en/latest/tutorials/ui/bbcode_in_richtextlabel.html), with the `{stack}` placeholder.

