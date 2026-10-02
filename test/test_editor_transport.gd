extends GutTest


##
## Restore the static color configuration of the editor transport after each test
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
