@tool
##
## List of filters (levels or namespaces) of the [code]Logs[/code] dock. Each row has a checkbox
## to show or hide its entries, the name (with its color) followed by the number of entries, and
## a breakpoint toggle.
## It uses plain controls (instead of a [Tree]) to display names and counts with different colors
## and to have full control of the layout.
##
extends VBoxContainer

## Emitted when the visibility filter of the row with the given [param key] is toggled
signal filter_toggled(key: Variant, enabled: bool)
## Emitted when the breakpoint of the row with the given [param key] is toggled
signal break_toggled(key: Variant, enabled: bool)

## Width of the breakpoint column (to center the icons, including the one in the header)
const BREAK_COLUMN_WIDTH = 24
## Modulate of the breakpoint icon when the breakpoint is not set
const BREAK_DISABLED_MODULATE = Color(1, 1, 1, 0.2)
## Tooltip of the breakpoint toggles
const BREAK_TOOLTIP = "Stop the execution (like a breakpoint) when logging these messages"

## Breakpoint icon in the header, identifying the column
var _header_break_icon: TextureRect
## Container of the header, with a right margin matching the vertical scroll bar of the rows (when
## visible), to keep the header aligned with them
var _header_margin: MarginContainer
## Scroll container of the rows
var _scroll: ScrollContainer
## Container of the rows
var _rows_container: VBoxContainer
## Rows by key, as [code]{ row, check, label, break_button, break_on }[/code]
var _rows: Dictionary = {}


func _init(title: String) -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	custom_minimum_size.x = 120

	_header_margin = MarginContainer.new()
	add_child(_header_margin)
	var header = HBoxContainer.new()
	_header_margin.add_child(header)
	var title_label = Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title_label)
	_header_break_icon = TextureRect.new()
	_header_break_icon.custom_minimum_size.x = BREAK_COLUMN_WIDTH
	_header_break_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_header_break_icon.tooltip_text = BREAK_TOOLTIP
	header.add_child(_header_break_icon)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_rows_container = VBoxContainer.new()
	_rows_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_rows_container.add_theme_constant_override("separation", 0)
	_scroll.add_child(_rows_container)
	_scroll.get_v_scroll_bar().visibility_changed.connect(_update_header_margin)


##
## Add a row for the given [param key] at the given [param index], enabled and without breakpoint
##
func add_row(key: Variant, index: int) -> void:
	var row = HBoxContainer.new()

	var check = CheckBox.new()
	check.button_pressed = true
	check.focus_mode = FOCUS_NONE
	check.toggled.connect(func(pressed): filter_toggled.emit(key, pressed))
	row.add_child(check)

	# clicking the name toggles the filter as well
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.size_flags_vertical = SIZE_SHRINK_CENTER
	label.gui_input.connect(
		func(event):
			if (
				event is InputEventMouseButton
				&& event.pressed
				&& event.button_index == MOUSE_BUTTON_LEFT
			):
				check.button_pressed = !check.button_pressed
	)
	row.add_child(label)

	var break_button = TextureButton.new()
	break_button.custom_minimum_size.x = BREAK_COLUMN_WIDTH
	break_button.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	break_button.ignore_texture_size = true
	break_button.tooltip_text = BREAK_TOOLTIP
	break_button.texture_normal = _get_break_icon()
	break_button.modulate = BREAK_DISABLED_MODULATE
	break_button.pressed.connect(func(): break_toggled.emit(key, !_rows[key].break_on))
	row.add_child(break_button)

	_rows_container.add_child(row)
	_rows_container.move_child(row, index)
	_rows[key] = {
		"row": row,
		"check": check,
		"label": label,
		"break_button": break_button,
		"break_on": false,
	}


##
## Set the [param text] (with its [param color]) and the [param count] of entries of a row
##
func set_row_text(key: Variant, text: String, color: Color, count: int) -> void:
	if !_rows.has(key):
		return
	# only the name is formatted, and "[" is escaped to avoid it being parsed as a BBTag
	_rows[key].label.text = (
		"[color=#%s]%s[/color] (%d)" % [color.to_html(), text.replace("[", "[lb]"), count]
	)


##
## Set the visibility filter of a row as [param enabled] (without emitting [signal filter_toggled])
##
func set_row_enabled(key: Variant, enabled: bool) -> void:
	if _rows.has(key):
		_rows[key].check.set_pressed_no_signal(enabled)


##
## Set the breakpoint of a row as [param enabled] (without emitting [signal break_toggled])
##
func set_row_break(key: Variant, enabled: bool) -> void:
	if !_rows.has(key):
		return
	_rows[key].break_on = enabled
	_rows[key].break_button.modulate = Color.WHITE if enabled else BREAK_DISABLED_MODULATE


##
## Leave space at the right of the header for the vertical scroll bar of the rows (when visible),
## as the rows get narrower, so the breakpoint icons stay aligned
##
func _update_header_margin() -> void:
	var scroll_bar = _scroll.get_v_scroll_bar()
	var margin = scroll_bar.get_combined_minimum_size().x if scroll_bar.visible else 0
	_header_margin.add_theme_constant_override("margin_right", int(margin))


func _notification(what: int) -> void:
	# the breakpoint icon is taken from the editor theme, available once in the tree
	if what == NOTIFICATION_THEME_CHANGED:
		var icon = _get_break_icon()
		_header_break_icon.texture = icon
		for key in _rows:
			_rows[key].break_button.texture_normal = icon


func _get_break_icon() -> Texture2D:
	return get_theme_icon("Breakpoint", "EditorIcons")
