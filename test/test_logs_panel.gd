extends GutTest

const LogsPanel = preload("res://addons/hanpeki_godot_logger/editor/logs_panel.gd")

var _panel: LogsPanel


func before_each() -> void:
	_panel = LogsPanel.new()
	add_child_autofree(_panel)


##
## Test that the focus is requested when a session starts, unless the auto focus is disabled
##
func test_auto_focus() -> void:
	assert_true(_panel.get_state().auto_focus, "enabled by default")
	watch_signals(_panel)
	_panel.on_session_started()
	await wait_frames(1)
	assert_signal_emit_count(_panel, "focus_requested", 1)

	_panel.apply_state({"auto_focus": false})
	assert_false(_panel.get_state().auto_focus)
	_panel.on_session_started()
	await wait_frames(1)
	assert_signal_emit_count(_panel, "focus_requested", 1)
