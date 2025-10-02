# Development notes

Notes about development and technical decisions will be placed here.

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

## Class.create() vs Class.new()

Since Godot doesn't allow overriding the `.init()` method properly to provide constructors with required parameters (actually it's allowed because the original signature has no methods, but not standard), the preferred approach to create instances is by calling their static `.create()` method.

```gdscript
# Don't
var logger = HanpekiLogger.new()

# Do
var logger = HanpekiLogger.create()
```
