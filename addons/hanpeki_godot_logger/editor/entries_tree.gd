@tool
##
## [Tree] used for the entries of the [code]Logs[/code] dock, adding:
## - Columns with a fixed width, some of them resizable by dragging their right border (anywhere
##   in the tree, as there's no title row), marked with a subtle line
## - Highlight of the whole hovered row, as the [Tree] only highlights the hovered cell
##   (unless whole rows are selected)
## - No selection: cells are deselected right after being clicked, and they can't be navigated
##   with the keyboard (clicks are still notified with [signal Tree.item_mouse_selected])
##
extends Tree

## Emitted when a column has been resized by the user (when releasing its border)
signal column_resized

## Minimum width of a resizable column
const MIN_COLUMN_WIDTH = 30
## Distance (in pixels) to the border of a resizable column to start resizing it
const RESIZE_GRAB_DISTANCE = 4
## Background color of the hovered row, when the theme doesn't provide one
const HOVERED_ROW_FALLBACK_COLOR = Color(1, 1, 1, 0.07)
## Actions used by the [Tree] to move the cursor between cells or select them with the keyboard
const NAVIGATION_ACTIONS: Array[StringName] = [
	&"ui_up",
	&"ui_down",
	&"ui_left",
	&"ui_right",
	&"ui_page_up",
	&"ui_page_down",
	&"ui_home",
	&"ui_end",
	&"ui_select",
	&"ui_accept",
]

## Width of the columns with a fixed width (the rest expand to take the remaining space)
var _column_widths: Dictionary[int, int] = {}
## Columns that can be resized by the user
var _resizable_columns: Array[int] = []
## Columns collapsed (with no width), regardless of their width
var _collapsed_columns: Dictionary[int, bool] = {}
## Column being resized by dragging its border ([code]-1[/code] if none)
var _resizing_column: int = -1
## Row currently highlighted as hovered
var _hovered_row: TreeItem = null


func _init() -> void:
	draw.connect(_draw_column_guides)
	mouse_exited.connect(func(): _set_hovered_row(null))
	# deferred, so it's done after the tree finishes processing the click
	cell_selected.connect(deselect_all.call_deferred)
	# the cell under the cursor is not marked either
	add_theme_stylebox_override("cursor", StyleBoxEmpty.new())
	add_theme_stylebox_override("cursor_unfocused", StyleBoxEmpty.new())


##
## Set a fixed [param width] for the given [param column], which can be changed by the user if
## [param resizable] (keeping at least [constant MIN_COLUMN_WIDTH])
##
func set_fixed_column_width(column: int, width: int, resizable: bool = false) -> void:
	set_column_expand(column, false)
	set_column_clip_content(column, true)
	if resizable:
		width = maxi(MIN_COLUMN_WIDTH, width)
		if column not in _resizable_columns:
			_resizable_columns.append(column)
	_column_widths[column] = width
	_apply_column_widths()


##
## Get the width of the columns with a fixed width, as [code]{ column: width }[/code]
## (including the collapsed ones)
##
func get_fixed_column_widths() -> Dictionary[int, int]:
	return _column_widths.duplicate()


##
## Check if the given [param column] can be resized by the user
##
func is_column_resizable(column: int) -> bool:
	return column in _resizable_columns


##
## Collapse the given [param column] (no width) or restore its width
##
func set_column_collapsed(column: int, collapsed: bool) -> void:
	if collapsed:
		_collapsed_columns[column] = true
	else:
		_collapsed_columns.erase(column)
	_apply_column_widths()


func _gui_input(event: InputEvent) -> void:
	if _handle_column_resize(event):
		accept_event()
		return
	if event is InputEventMouseMotion:
		var item = get_item_at_position(event.position)
		# rows that can't be selected (like separators) are not highlighted
		_set_hovered_row(item if item && item.is_selectable(0) else null)
	elif event is InputEventKey && event.pressed && _is_navigation_key(event):
		# not handled by the tree, so cells can't be navigated nor selected with the keyboard
		accept_event()


##
## Check if the key [param event] is used by the [Tree] to navigate or select the cells,
## including the search when typing (but not shortcuts like copying, handled elsewhere)
##
func _is_navigation_key(event: InputEventKey) -> bool:
	for action in NAVIGATION_ACTIONS:
		if event.is_action(action, true):
			return true
	var has_modifiers = event.ctrl_pressed || event.alt_pressed || event.meta_pressed
	return !has_modifiers && event.unicode >= KEY_SPACE


func _apply_column_widths() -> void:
	for column in _column_widths:
		var width = 0 if _collapsed_columns.has(column) else _column_widths[column]
		set_column_custom_minimum_width(column, width)


##
## Get the x position of the right border of the given [param column]
##
func _get_column_border_x(column: int) -> float:
	var x = get_theme_stylebox("panel").get_margin(SIDE_LEFT)
	for i in range(column + 1):
		x += get_column_width(i)
	return x


##
## Get the resizable column whose right border is at the given [param x]
## ([code]-1[/code] if none)
##
func _get_resizable_column_at(x: float) -> int:
	for column in _resizable_columns:
		if (
			get_column_width(column) > 0
			&& absf(x - _get_column_border_x(column)) <= RESIZE_GRAB_DISTANCE
		):
			return column
	return -1


##
## Resize the columns by dragging their right border. Returns [code]true[/code] if the
## [param event] was handled.
##
func _handle_column_resize(event: InputEvent) -> bool:
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_resizing_column = _get_resizable_column_at(event.position.x)
			return _resizing_column != -1
		if _resizing_column != -1:
			_resizing_column = -1
			column_resized.emit()
			return true
	elif event is InputEventMouseMotion:
		if _resizing_column != -1:
			var start = _get_column_border_x(_resizing_column) - get_column_width(_resizing_column)
			var width = maxi(MIN_COLUMN_WIDTH, roundi(event.position.x - start))
			_column_widths[_resizing_column] = width
			_apply_column_widths()
			return true
		var on_border = _get_resizable_column_at(event.position.x) != -1
		mouse_default_cursor_shape = CURSOR_HSIZE if on_border else CURSOR_ARROW
	return false


##
## Draw a subtle line at the right border of the resizable columns, so they can be found
## without a title row
##
func _draw_column_guides() -> void:
	var panel = get_theme_stylebox("panel")
	var top = panel.get_margin(SIDE_TOP)
	var bottom = size.y - panel.get_margin(SIDE_BOTTOM)
	var color = get_theme_color("guide_color")
	for column in _resizable_columns:
		if get_column_width(column) > 0:
			var x = _get_column_border_x(column)
			draw_line(Vector2(x, top), Vector2(x, bottom), color)


##
## Highlight the whole hovered row [param item] (or none if [code]null[/code])
##
func _set_hovered_row(item: TreeItem) -> void:
	if item == _hovered_row:
		return
	# the previous row could have been removed already
	if is_instance_valid(_hovered_row):
		for column in columns:
			_hovered_row.clear_custom_bg_color(column)
	_hovered_row = item
	_update_hovered_row_bg()


##
## Set the background of the hovered row with the color of the theme
##
func _update_hovered_row_bg() -> void:
	if !is_instance_valid(_hovered_row):
		return
	var style = get_theme_stylebox("hovered")
	var color = style.bg_color if style is StyleBoxFlat else HOVERED_ROW_FALLBACK_COLOR
	for column in columns:
		_hovered_row.set_custom_bg_color(column, color)
