extends GutTest


##
## Restore the static configuration (colors and breakpoints) of the editor transport after each test
##
func after_each() -> void:
	HanpekiLoggerEditorTransport._level_colors = (
		HanpekiLogger.Transport.DEFAULT_LEVEL_COLORS.duplicate()
	)
	HanpekiLoggerEditorTransport._level_default_color = (
		HanpekiLogger.Transport.DEFAULT_CUSTOM_LEVEL_COLOR
	)
	HanpekiLoggerEditorTransport._ns_colors.clear()
	HanpekiLoggerEditorTransport._ns_default_color = HanpekiLogger.Transport.DEFAULT_NS_COLOR
	HanpekiLoggerEditorTransport._set_breakpoints(
		[HanpekiLogger.ERROR | HanpekiLogger.FATAL, [], false, false]
	)


##
## Test that the editor transport is not available when not running from the editor
##
func test_not_available() -> void:
	assert_false(HanpekiLoggerEditorTransport.is_available())
	assert_false(HanpekiLogger.create()._send_to_editor)


##
## Test the payload sent to the editor for each message
##
func test_to_payload() -> void:
	var data = HanpekiLogger.MsgData.new()
	data.level = HanpekiLogger.WARN
	data.level_name = "Warn"
	data.ns = &"UI"
	data.msg = "Message"
	data.utime = 1234
	data.stack = [{"source": "res://a.gd", "line": 10, "function": "f"}]

	assert_eq(
		HanpekiLoggerEditorTransport._to_payload(data),
		[
			HanpekiLogger.WARN,
			"Warn",
			"UI",
			"Message",
			HanpekiLogger._start_unix_ms + 1234,
			[["res://a.gd", 10, "f"]],
		]
	)

	# Without stack
	data.stack = null
	assert_eq(HanpekiLoggerEditorTransport._to_payload(data)[5], [])


##
## Test the default colors sent to the editor, shared with the other transports
##
func test_default_colors() -> void:
	var payload = HanpekiLoggerEditorTransport._get_colors_payload()
	var level_colors = {}
	for level_color in payload[0]:
		level_colors[level_color[0]] = level_color[1]

	assert_eq_deep(level_colors, HanpekiLogger.Transport.DEFAULT_LEVEL_COLORS)
	assert_eq(payload[1], HanpekiLogger.Transport.DEFAULT_CUSTOM_LEVEL_COLOR)
	assert_eq(payload[2], [])
	assert_eq(payload[3], HanpekiLogger.Transport.DEFAULT_NS_COLOR)


##
## Test customizing the colors used in the editor
##
func test_set_colors() -> void:
	var custom_level = HanpekiLogger.WARN << 1
	HanpekiLoggerEditorTransport.set_level_color(custom_level, Color.ORANGE)
	HanpekiLoggerEditorTransport.set_level_color(HanpekiLogger.DEBUG, Color.DIM_GRAY)
	HanpekiLoggerEditorTransport.set_level_default_color(Color.WHITE)
	HanpekiLoggerEditorTransport.set_ns_color(&"UI", Color.SKY_BLUE)
	HanpekiLoggerEditorTransport.set_ns_default_color(Color.LIGHT_GRAY)

	var payload = HanpekiLoggerEditorTransport._get_colors_payload()
	var level_colors = {}
	for level_color in payload[0]:
		level_colors[level_color[0]] = level_color[1]

	assert_eq(level_colors[custom_level], Color.ORANGE)
	assert_eq(level_colors[HanpekiLogger.DEBUG], Color.DIM_GRAY)
	# levels not customized keep their default color
	var defaults = HanpekiLogger.Transport.DEFAULT_LEVEL_COLORS
	assert_eq(level_colors[HanpekiLogger.ERROR], defaults[HanpekiLogger.ERROR])
	assert_eq(payload[1], Color.WHITE)
	assert_eq(payload[2], [["UI", Color.SKY_BLUE]])
	assert_eq(payload[3], Color.LIGHT_GRAY)


##
## Test that the console transport uses the shared colors for the predefined levels
##
func test_console_shared_colors() -> void:
	var transport = HanpekiLoggerConsoleTransport.create()
	for level in HanpekiLogger.Transport.DEFAULT_LEVEL_COLORS:
		var color = HanpekiLogger.Transport.DEFAULT_LEVEL_COLORS[level].to_html(false)
		assert_string_contains(transport._level_formats[level], color)
	assert_string_contains(
		transport._level_default_format,
		HanpekiLogger.Transport.DEFAULT_CUSTOM_LEVEL_COLOR.to_html(false)
	)


##
## Test the default breakpoints (before receiving the configuration from the editor)
##
func test_default_breakpoints() -> void:
	var should_break = HanpekiLoggerEditorTransport._should_break
	assert_true(should_break.call(HanpekiLogger.FATAL, &""))
	assert_true(should_break.call(HanpekiLogger.ERROR, &"UI"))
	assert_false(should_break.call(HanpekiLogger.WARN, &""))
	assert_false(should_break.call(HanpekiLogger.DEBUG, &"UI"))


##
## Test breaking when either the level or the namespace are set (OR)
##
func test_breakpoints_any() -> void:
	var should_break = HanpekiLoggerEditorTransport._should_break
	HanpekiLoggerEditorTransport._set_breakpoints([HanpekiLogger.WARN, ["UI"], false, false])

	assert_true(should_break.call(HanpekiLogger.WARN, &""))
	assert_true(should_break.call(HanpekiLogger.DEBUG, &"UI"))
	assert_true(should_break.call(HanpekiLogger.WARN, &"UI"))
	assert_false(should_break.call(HanpekiLogger.ERROR, &"Other"))


##
## Test breaking only when both the level and the namespace are set (AND)
##
func test_breakpoints_both() -> void:
	var should_break = HanpekiLoggerEditorTransport._should_break
	HanpekiLoggerEditorTransport._set_breakpoints([HanpekiLogger.WARN, ["UI"], true, false])

	assert_true(should_break.call(HanpekiLogger.WARN, &"UI"))
	assert_false(should_break.call(HanpekiLogger.WARN, &""))
	assert_false(should_break.call(HanpekiLogger.DEBUG, &"UI"))


##
## Test ignoring every breakpoint
##
func test_breakpoints_ignored() -> void:
	var should_break = HanpekiLoggerEditorTransport._should_break
	HanpekiLoggerEditorTransport._set_breakpoints([HanpekiLogger.FATAL, ["UI"], false, true])

	assert_false(should_break.call(HanpekiLogger.FATAL, &""))
	assert_false(should_break.call(HanpekiLogger.DEBUG, &"UI"))


##
## Test receiving the breakpoints from the editor (with or without the capture prefix)
##
func test_breakpoints_message() -> void:
	var on_message = HanpekiLoggerEditorTransport._on_editor_message
	assert_true(on_message.call("breakpoints", [HanpekiLogger.INFO, [], false, false]))
	assert_true(HanpekiLoggerEditorTransport._should_break(HanpekiLogger.INFO, &""))

	var message = HanpekiLoggerEditorTransport.MSG_BREAKPOINTS
	assert_true(on_message.call(message, [HanpekiLogger.CORE, [], false, false]))
	assert_true(HanpekiLoggerEditorTransport._should_break(HanpekiLogger.CORE, &""))
	assert_false(HanpekiLoggerEditorTransport._should_break(HanpekiLogger.INFO, &""))

	assert_false(on_message.call("unknown", []))


##
## Test that AND behaves like OR when no level or no namespace is set
##
func test_breakpoints_both_fallback() -> void:
	var should_break = HanpekiLoggerEditorTransport._should_break

	# No namespace set: only the levels are used
	HanpekiLoggerEditorTransport._set_breakpoints([HanpekiLogger.WARN, [], true, false])
	assert_true(should_break.call(HanpekiLogger.WARN, &""))
	assert_true(should_break.call(HanpekiLogger.WARN, &"UI"))
	assert_false(should_break.call(HanpekiLogger.DEBUG, &"UI"))

	# No level set: only the namespaces are used
	HanpekiLoggerEditorTransport._set_breakpoints([0, ["UI"], true, false])
	assert_true(should_break.call(HanpekiLogger.DEBUG, &"UI"))
	assert_true(should_break.call(HanpekiLogger.FATAL, &"UI"))
	assert_false(should_break.call(HanpekiLogger.FATAL, &""))

	# Nothing set: never breaks
	HanpekiLoggerEditorTransport._set_breakpoints([0, [], true, false])
	assert_false(should_break.call(HanpekiLogger.FATAL, &"UI"))


##
## Test saving and loading the breakpoints file (used to have the breakpoints when the game starts)
##
func test_breakpoints_file() -> void:
	var path = HanpekiLoggerEditorTransport.BREAKPOINTS_FILE
	# keep the file of the project (if any) to restore it after the test
	var original = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null

	HanpekiLoggerEditorTransport._save_breakpoints_file([HanpekiLogger.CORE, ["UI"], true, false])
	HanpekiLoggerEditorTransport._set_breakpoints([0, [], false, true])
	HanpekiLoggerEditorTransport._load_breakpoints_file()

	var should_break = HanpekiLoggerEditorTransport._should_break
	assert_true(should_break.call(HanpekiLogger.CORE, &"UI"))
	assert_false(should_break.call(HanpekiLogger.CORE, &"Other"))
	assert_false(should_break.call(HanpekiLogger.FATAL, &"UI"))

	# invalid files keep the current configuration
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[breakpoints]\nlevels=\"invalid\"\n")
	file.close()
	HanpekiLoggerEditorTransport._load_breakpoints_file()
	assert_true(should_break.call(HanpekiLogger.CORE, &"UI"))

	if original == null:
		DirAccess.remove_absolute(path)
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(original)
		file.close()


func test_game_exiting_flushes_messages() -> void:
	# waits for the debugger connection to send the queued messages, and unregisters the capture
	HanpekiLoggerEditorTransport._capture_registered = true
	var start = Time.get_ticks_msec()
	HanpekiLoggerEditorTransport._on_game_exiting()
	var elapsed = Time.get_ticks_msec() - start
	assert_gte(elapsed, HanpekiLoggerEditorTransport.EXIT_FLUSH_DELAY_MS)
	assert_false(HanpekiLoggerEditorTransport._capture_registered)
