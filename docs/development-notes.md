# Development notes

Notes about development and technical decisions will be placed here.

## Getting started

### Using VS Code

Using the Godot extension for VS Code requires to specify the path to the godot binary. Since this depends on the local machine, the repository doesn't provide it.

Just add the following line to your `.vscode/settings.json`:

```
"godotTools.editorPath.godot4": "PATH\\TO\\GODOT\\Godot_v4.6-stable_win64.exe"
```

### godot

Running tests require the `godot` executable to be available. There are multiple ways to provide it:

- First, it will be checked if `$GODOT` is defined and pointing to a valid godot executable.
- Then, it will be checked if defined in `.vscode/settings.json` (`godotTools.editorPath.godot4`).
- Last, it will be checked if it's available in `$PATH`.

The first one that is executable and returns a Godot version is used.

Its version must match the one specified in `project.godot` (only `major.minor` is compared, so `4.6`, `4.6.0` and `4.6.1` are compatible). Otherwise, the scripts will fail, as a reminder to update `$GODOT` or `.vscode/settings.json` after upgrading Godot.

### gdlint and gdformat

The CI pipeline as well as the git pre-commit hook require linting for this project, which is provided by [godot-gdscript-toolkit](https://github.com/Scony/godot-gdscript-toolkit).

Make sure it's installed following its instructions.

The executables will be picked from `$PATH` if available. Otherwise, they will be auto-detected from the `gdtoolkit` package installed via `pip` (`pip3`, `pip` or `python3 -m pip`) or `pipx`, so there's no need to add them to `$PATH`.

## CI

When a PR is created, as well as when it's merged into the `main` branch, some checks will be performed via github actions:

- [linting](../.github/workflows/linting.yml): Checks that the code follows the style guidelines
- [test](../.github/workflows/tests.yml): Checks that the code is working as expected without regression

This tests are required before a PR can be merged, but they also run locally via githooks, so there's no need to wait until the jobs run in remote to know if there's something to be fixed.

To make sure that the git hooks are enabled, just run the [setup](../scripts//setup.sh) script once after cloning the repository

```sh
./scripts/setup.sh
```

It should work in Mac, Linux as well as in Windows using Git Bash.

## CD

When a commit is tagged with a semantic version, it will be [released](https://github.com/hanpeki/hanpeki-godot-logger/releases) and the built code will be attached as a downloable file in the release page.

The version is defined in `HanpekiLogger.VERSION` ([logger.gd](../addons/hanpeki_godot_logger/logger.gd)), and it needs to be the same in [plugin.cfg](../addons/hanpeki_godot_logger/plugin.cfg) (it can't be read from there at runtime, as `.cfg` files are not included in exported projects by default). Both [build](../scripts/build.sh) and the tests fail when they don't match, and the release also fails when the tag (i.e. `v1.0.0`) is not the same version.

## Class.create() vs Class.new()

Since Godot doesn't allow overriding the `.init()` method properly to provide constructors with required parameters (actually it's allowed because the original signature has no methods, but not standard), the preferred approach to create instances is by calling their static `.create()` method.

```gdscript
# Don't
var logger = HanpekiLogger.new()

# Do
var logger = HanpekiLogger.create()
```
