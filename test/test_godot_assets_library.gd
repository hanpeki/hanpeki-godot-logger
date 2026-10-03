extends GutTest

##
## Checks required to publish the plugin in the Godot Asset Library
## (see the "Godot Asset Library" section in docs/development-notes.md)
##

## Path of the plugin, relative to the repository root
const ADDON_PATH = "addons/hanpeki_godot_logger/"
## First year of the copyright in the LICENSE
const LICENSE_FIRST_YEAR = "2025"
## Icon used in the Asset Library (its raw.githubusercontent.com URL is set in the asset page)
## https://raw.githubusercontent.com/hanpeki/hanpeki-godot-logger/main/icon.png
const ICON_PATH = "icon.png"
## Minimum size (in pixels) of the icon, required by the Asset Library
const ICON_MIN_SIZE = 128
## Prefix of the project settings for the GDScript warnings
const WARNINGS_SETTINGS = "debug/gdscript/warnings/"
## Values of the GDScript warning levels in the project settings
const WARNING_LEVEL_WARN = 1
const WARNING_LEVEL_ERROR = 2
## Value of the directory rules in the project settings to include warnings in a folder
const WARNING_DIRECTORY_INCLUDE = 1

## Files in the repository (tracked or not ignored), relative to its root
var _repo_files: PackedStringArray
## Files included in the archive downloaded by the Asset Library, relative to the repository root
var _shipped_files: PackedStringArray


##
## Ensures that the LICENSE shipped inside the addon is the same as the root one
##
func test_addon_license_matches_root() -> void:
	var root := FileAccess.get_file_as_string("res://LICENSE")
	var addon := FileAccess.get_file_as_string("res://%sLICENSE" % ADDON_PATH)
	assert_ne(root, "")
	assert_eq(addon, root)


##
## Ensures that the copyright of the LICENSE includes the first year of the project and the
## current one (i.e. "2025-2026")
##
func test_license_copyright_years() -> void:
	var license := FileAccess.get_file_as_string("res://LICENSE")
	var copyright := RegEx.create_from_string("(?m)^Copyright .*$").search(license)
	assert_not_null(copyright, "The LICENSE should have a copyright line")
	if !copyright:
		return

	var line := copyright.get_string()
	var current_year := str(Time.get_date_dict_from_system().year)
	for year in [LICENSE_FIRST_YEAR, current_year]:
		assert_string_contains(line, year, false)


##
## Ensures that the archive downloaded by the Asset Library (filtered by the export-ignore rules
## in .gitattributes) contains the whole plugin folder, and nothing else
##
func test_archive_contains_only_the_addon() -> void:
	var shipped := _get_shipped_files()

	var unexpected := []
	for file in shipped:
		if !file.begins_with(ADDON_PATH):
			unexpected.append(file)
	assert_eq(unexpected, [], "Files outside the addon should be export-ignored")

	var missing := []
	for file in _get_repo_files():
		if file.begins_with(ADDON_PATH) && !shipped.has(file):
			missing.append(file)
	assert_eq(missing, [], "Files of the addon shouldn't be export-ignored")

	for file in ["plugin.cfg", "LICENSE", "README.md"]:
		assert_has(shipped, ADDON_PATH + file)


##
## Ensures that the default GDScript warnings are treated as errors in the addon, so any warning
## makes its scripts fail to load (and the tests to fail)
##
func test_addon_warnings_are_errors() -> void:
	assert_true(ProjectSettings.get_setting(WARNINGS_SETTINGS + "enable"))

	var rules: Dictionary = ProjectSettings.get_setting(WARNINGS_SETTINGS + "directory_rules")
	assert_eq(rules.get("res://" + ADDON_PATH.trim_suffix("/")), WARNING_DIRECTORY_INCLUDE)

	var not_errors := []
	for property in ProjectSettings.get_property_list():
		var setting: String = property.name
		if (
			setting.begins_with(WARNINGS_SETTINGS)
			&& property.type == TYPE_INT
			&& ProjectSettings.property_get_revert(setting) == WARNING_LEVEL_WARN
			&& ProjectSettings.get_setting(setting) != WARNING_LEVEL_ERROR
		):
			not_errors.append(setting)
	assert_eq(not_errors, [], "Warnings enabled by default should be treated as errors")


##
## Ensures that every script of the addon (including the editor ones, not used by other tests)
## loads without warnings (which are errors, see [method test_addon_warnings_are_errors])
##
func test_addon_scripts_have_no_warnings() -> void:
	var scripts := 0
	for file in _get_repo_files():
		if !file.begins_with(ADDON_PATH) || file.get_extension() != "gd":
			continue
		scripts += 1
		var script = ResourceLoader.load("res://" + file, "", ResourceLoader.CACHE_MODE_IGNORE)
		assert_not_null(script, file)
		if script:
			assert_true((script as GDScript).can_instantiate(), file)
	assert_gt(scripts, 0)


##
## Ensures that the CI runs the tests with the same Godot version used by the project
## (the one to specify in the Asset Library)
##
func test_ci_godot_version_matches_project() -> void:
	var project_version := ""
	for feature in ProjectSettings.get_setting("application/config/features"):
		if RegEx.create_from_string("^\\d+\\.\\d+$").search(feature):
			project_version = feature
	assert_ne(project_version, "")

	var regex := RegEx.create_from_string("setup-godot@[\\s\\S]*?version:\\s*([\\d.]+)")
	var checked := 0
	for file in _get_repo_files():
		if !file.begins_with(".github/workflows/"):
			continue
		var content := FileAccess.get_file_as_string("res://" + file)
		for found in regex.search_all(content):
			checked += 1
			var version := found.get_string(1)
			assert_true(
				version == project_version || version.begins_with(project_version + "."),
				"%s uses Godot %s instead of %s" % [file, version, project_version]
			)
	assert_gt(checked, 0)


##
## Ensures that the icon for the Asset Library is a square PNG/JPG of at least 128x128 pixels
##
func test_icon() -> void:
	assert_has(_get_repo_files(), ICON_PATH, "The Asset Library icon should exist")
	var extension := ICON_PATH.get_extension().to_lower()
	assert_has(["png", "jpg", "jpeg"], extension)

	# Loaded from the raw file, as it's imported by Godot (and loading it directly logs an error)
	var buffer := FileAccess.get_file_as_bytes("res://" + ICON_PATH)
	var image := Image.new()
	var error := (
		image.load_png_from_buffer(buffer)
		if extension == "png"
		else image.load_jpg_from_buffer(buffer)
	)
	assert_eq(error, OK)
	if error == OK:
		assert_eq(image.get_width(), image.get_height(), "The icon should be square")
		assert_gte(image.get_width(), ICON_MIN_SIZE)


##
## Ensures that the images used in the Markdown files exist and are in folders ignored by Godot
## (so they're not imported in the project, as they're only used in the repository).
## The icons in the root of the project (Asset Library and project ones) are excluded.
##
func test_markdown_images_are_gdignored() -> void:
	var regex := RegEx.create_from_string(
		"!\\[[^\\]]*\\]\\(\\s*([^)\\s]+)|<img\\s[^>]*src=\"([^\"]+)\""
	)
	var repo_files := _get_repo_files()
	var icons := [
		ICON_PATH,
		(ProjectSettings.get_setting("application/config/icon") as String).trim_prefix("res://"),
	]
	var images := 0
	var errors := []

	for file in repo_files:
		if file.get_extension() != "md" || _is_dev_addon(file):
			continue
		var content := FileAccess.get_file_as_string("res://" + file)
		var base_dir := file.get_base_dir()
		for found in regex.search_all(content):
			var src := found.get_string(1) if found.get_string(1) else found.get_string(2)
			if src.contains("://"):
				continue
			images += 1
			var image := ((base_dir + "/" if base_dir else "") + src).simplify_path()
			if !repo_files.has(image):
				errors.append("%s: %s doesn't exist" % [file, src])
			elif !icons.has(image) && !_is_gdignored(image):
				errors.append("%s: %s should be in a folder with .gdignore" % [file, src])

	assert_gt(images, 0)
	assert_eq(errors, [])


## Run git in the repository root, returning the lines of its output
func _git(args: PackedStringArray) -> PackedStringArray:
	var output := []
	var all_args := PackedStringArray(["-C", ProjectSettings.globalize_path("res://")])
	all_args.append_array(args)
	var code := OS.execute("git", all_args, output)
	assert_eq(code, 0, "git %s" % " ".join(args))
	if code != 0 || output.is_empty():
		return PackedStringArray()
	return (output[0] as String).replace("\r", "").split("\n", false)


## Files in the repository: tracked ones and new ones not ignored (that will probably be committed)
func _get_repo_files() -> PackedStringArray:
	if _repo_files.is_empty():
		_repo_files = _git(["ls-files", "--cached", "--others", "--exclude-standard"])
	return _repo_files


## Files included in the archive downloaded by the Asset Library (the ones not export-ignored)
func _get_shipped_files() -> PackedStringArray:
	if !_shipped_files.is_empty():
		return _shipped_files

	var files := _get_repo_files()
	# There's no stdin with OS.execute, so files are passed as arguments in chunks
	var chunk_size := 100
	for i in range(0, files.size(), chunk_size):
		var args := PackedStringArray(["check-attr", "export-ignore", "--"])
		args.append_array(files.slice(i, i + chunk_size))
		for line in _git(args):
			if !line.ends_with(": export-ignore: set"):
				_shipped_files.append(line.substr(0, line.rfind(": export-ignore: ")))
	return _shipped_files


## Whether the [param file] is inside a folder with a .gdignore file (in any of its ancestors)
func _is_gdignored(file: String) -> bool:
	var dir := file.get_base_dir()
	while dir:
		if FileAccess.file_exists("res://%s/.gdignore" % dir):
			return true
		dir = dir.get_base_dir()
	return false


## Whether the [param file] belongs to an addon only used for developing this plugin
func _is_dev_addon(file: String) -> bool:
	return file.begins_with("addons/") && !file.begins_with(ADDON_PATH)
