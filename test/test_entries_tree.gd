extends GutTest

const EntriesTree = preload("res://addons/hanpeki_godot_logger/editor/entries_tree.gd")

const HOVERED_COLOR = Color.BLUE

var _tree: EntriesTree


func before_each() -> void:
	_tree = EntriesTree.new()
	_tree.columns = 3
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_SINGLE
	_tree.size = Vector2(300, 200)
	_tree.create_item()
	var style = StyleBoxFlat.new()
	style.bg_color = HOVERED_COLOR
	_tree.add_theme_stylebox_override("hovered", style)
	add_child_autofree(_tree)


##
## Test that the whole hovered row is highlighted, and restored when not hovered anymore
##
func test_hovered_row() -> void:
	var a = _tree.create_item(_tree.get_root())
	var b = _tree.create_item(_tree.get_root())
	var none = a.get_custom_bg_color(0)

	_tree._set_hovered_row(a)
	for column in _tree.columns:
		assert_eq(a.get_custom_bg_color(column), HOVERED_COLOR)

	_tree._set_hovered_row(b)
	for column in _tree.columns:
		assert_eq(a.get_custom_bg_color(column), none)
		assert_eq(b.get_custom_bg_color(column), HOVERED_COLOR)

	_tree._set_hovered_row(null)
	for column in _tree.columns:
		assert_eq(b.get_custom_bg_color(column), none)


##
## Test that clicked cells don't stay selected, while the click is still notified
##
func test_no_selection() -> void:
	var a = _tree.create_item(_tree.get_root())
	a.set_text(0, "a")
	await wait_process_frames(2)
	watch_signals(_tree)

	var position = _tree.get_global_rect().position + _tree.get_item_area_rect(a).get_center()
	for pressed in [true, false]:
		var click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = position
		click.global_position = position
		_tree.get_viewport().push_input(click)
	await wait_process_frames(1)

	assert_signal_emitted(_tree, "item_mouse_selected")
	# the tree selected the cell, but it's deselected afterwards
	assert_signal_emitted(_tree, "cell_selected")
	assert_null(_tree.get_selected())
	for column in _tree.columns:
		assert_false(a.is_selected(column))


##
## Test the keys blocked to avoid navigating the cells with the keyboard
##
func test_navigation_keys() -> void:
	var down = InputEventKey.new()
	down.keycode = KEY_DOWN
	assert_true(_tree._is_navigation_key(down))

	var letter = InputEventKey.new()
	letter.keycode = KEY_A
	letter.unicode = "a".unicode_at(0)
	assert_true(_tree._is_navigation_key(letter))

	var copy = InputEventKey.new()
	copy.keycode = KEY_C
	copy.unicode = "c".unicode_at(0)
	copy.ctrl_pressed = true
	assert_false(_tree._is_navigation_key(copy))


##
## Test that removing the hovered row doesn't break the highlight of the next one
##
func test_hovered_row_removed() -> void:
	var a = _tree.create_item(_tree.get_root())
	var b = _tree.create_item(_tree.get_root())
	_tree._set_hovered_row(a)
	a.free()

	_tree._set_hovered_row(b)
	assert_eq(b.get_custom_bg_color(0), HOVERED_COLOR)


##
## Test the fixed, resizable and collapsed columns
##
func test_column_widths() -> void:
	_tree.set_fixed_column_width(0, 100)
	_tree.set_fixed_column_width(1, 10, true)
	assert_false(_tree.is_column_resizable(0))
	assert_true(_tree.is_column_resizable(1))
	assert_false(_tree.is_column_resizable(2))
	# resizable columns keep a minimum width
	assert_eq(_tree.get_fixed_column_widths(), {0: 100, 1: EntriesTree.MIN_COLUMN_WIDTH})

	_tree.set_column_collapsed(1, true)
	assert_eq(_tree.get_column_width(1), 0)
	# the width is kept for when it's restored
	assert_eq(_tree.get_fixed_column_widths()[1], EntriesTree.MIN_COLUMN_WIDTH)
	_tree.set_column_collapsed(1, false)
	assert_eq(_tree.get_column_width(1), EntriesTree.MIN_COLUMN_WIDTH)
