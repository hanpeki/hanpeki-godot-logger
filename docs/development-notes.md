# Development notes

WIP.

Notes about development and technical decisions will be placed here.

## Class.create() vs Class.new()

Since Godot doesn't allow overriding the `.init()` method properly to provide constructors with required parameters (actually it's allowed because the original signature has no methods, but not standard), the preferred approach to create instances is by calling their static `.create()` method.

```gdscript
# Don't
var logger = HanpekiLogger.new()

# Do
var logger = HanpekiLogger.create()
```
