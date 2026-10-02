@tool
##
## Content of the [code]Logs[/code] editor dock: the list of entries received from the running game
## (left), the search input (below the list) and the level and namespace filters (right)
##
extends HSplitContainer

## Emitted when any state to be saved changes (see [method get_state])
signal state_changed
## Emitted when the breakpoints configuration changes (see [method get_breakpoints_payload])
signal breakpoints_changed

## Columns of the entries tree
enum Column { TIME, LEVEL, NS, MSG }

const FilterList = preload("res://addons/hanpeki_godot_logger/editor/filter_list.gd")

## Maximum number of entries to keep (the oldest ones are removed)
const MAX_ENTRIES = 10000
## Text displayed for messages without namespace
const NS_NONE_TEXT = "(none)"
## Color (dimmed) of the item for messages without namespace in the namespaces filter
const NS_NONE_COLOR = Color(0.5, 0.5, 0.5)
## Default width of the columns that can be resized (the message column takes the rest)
const DEFAULT_COLUMN_WIDTHS: Dictionary[int, int] = {
	Column.TIME: 100,
	Column.LEVEL: 60,
	Column.NS: 120,
}
## Minimum width of a column (when restoring the saved widths)
const MIN_COLUMN_WIDTH = 30
## Id of the copy button displayed when hovering an entry
const COPY_BUTTON_ID = 0
## Color used for the stack lines
const STACK_COLOR = Color(0.6, 0.6, 0.7)
## Background color of the separators between game sessions
const SEPARATOR_BG_COLOR = Color(0.5, 0.5, 0.6, 0.15)

## Tree with the received entries (one top-level item per entry, with the stack as children)
var _tree: Tree
## Input to filter the entries by text
var _search: LineEdit
## List with the level filters
var _levels_list: FilterList
## List with the namespace filters
var _ns_list: FilterList
## Split between the namespace and level filters
var _filters_split: HSplitContainer
## Toggle to show or hide the namespace filters
var _ns_toggle: Button
## Toggle to show or hide the level filters
var _levels_toggle: Button
## Toggle to preserve the entries when a new game session starts (instead of clearing them)
var _preserve_toggle: Button
## Button to remove every entry
var _clear_button: Button
## Toggle to switch between stopping on messages matching both the level and namespace
## breakpoints (AND) or any of them (OR)
var _break_on_both_toggle: Button
## Toggle to ignore every breakpoint
var _ignore_breakpoints_toggle: Button

## Received entries, as
## [code]{ level, level_name, ns, msg, unix_ms, stack, item: TreeItem }[/code]
var _entries: Array[Dictionary] = []
## Known levels, as [code]level -> { name, enabled, count }[/code]
var _levels: Dictionary[int, Dictionary] = {}
## Known namespaces, as [code]ns -> { enabled, count }[/code]
var _namespaces: Dictionary[String, Dictionary] = {}
## Timezone offset in secs
var _time_bias: int
## Entry item currently showing the copy button (when hovered)
var _hovered_item: TreeItem = null
## Icon of the copy button, scaled to fit in the rows so they don't grow when it's
## displayed (see [method _get_copy_icon])
var _copy_icon: Texture2D = null
## Separators between game sessions (when preserving the logs), as
## [code]{ item: TreeItem, next_id: int }[/code] where [code]next_id[/code] is the id of the
## first entry after the separator
var _separators: Array[Dictionary] = []
## Id for the next received entry (incremental)
var _next_id: int = 0
## Number of entries with a namespace, to only show the namespace column when needed
var _ns_entries: int = 0
## Width of the columns that can be resized (see [constant DEFAULT_COLUMN_WIDTHS])
var _column_widths: Dictionary[int, int] = DEFAULT_COLUMN_WIDTHS.duplicate()
## Colors of each level, received from the game (see [method set_colors]).
## The defaults shared by the transports are used until then
var _level_colors: Dictionary[int, Color] = HanpekiLogger.Transport.DEFAULT_LEVEL_COLORS.duplicate()
## Color of the levels without a specific one
var _level_default_color: Color = HanpekiLogger.Transport.DEFAULT_CUSTOM_LEVEL_COLOR
## Colors of each namespace, received from the game
var _ns_colors: Dictionary[String, Color] = {}
## Color of the namespaces without a specific one
var _ns_default_color: Color = HanpekiLogger.Transport.DEFAULT_NS_COLOR
## Union of the levels stopping the execution when logged
var _break_levels: int = HanpekiLogger.ERROR | HanpekiLogger.FATAL
## Namespaces stopping the execution when logged
var _break_namespaces: Dictionary[String, bool] = {}
## Union of the levels disabled in the filters. It also keeps the ones not known yet (i.e. custom
## levels from a previous session), so they are disabled when they are registered
var _disabled_levels: int = 0
## Namespaces disabled in the filters (including the ones not known yet, like the levels)
var _disabled_namespaces: Dictionary[String, bool] = {}


func _init() -> void:
	name = "Logs"
	_time_bias = Time.get_time_zone_from_system().bias * 60
	_build_ui()
	for level in HanpekiLogger.PREDEFINED_LEVEL_NAMES:
		_ensure_level(level, HanpekiLogger.PREDEFINED_LEVEL_NAMES[level])
	_ensure_namespace(String(HanpekiLogger.NS_UNDEFINED))
	_update_namespaces_visibility()


##
## Add an entry received from the game, as sent by [method HanpekiLoggerEditorTransport._to_payload]
##
func add_entry(data: Array) -> void:
	var entry = {
		"level": data[0],
		"level_name": data[1],
		"ns": data[2],
		"msg": data[3],
		"unix_ms": data[4],
		"stack": data[5],
		"id": _next_id,
	}
	_next_id += 1
	_ensure_level(entry.level, entry.level_name)
	_ensure_namespace(entry.ns)

	var item = _tree.create_item(_tree.get_root())
	item.set_text(Column.TIME, _format_time(entry.unix_ms))
	item.set_text(Column.LEVEL, entry.level_name)
	item.set_custom_color(Column.LEVEL, _get_level_color(entry.level))
	item.set_text(Column.NS, entry.ns)
	item.set_custom_color(Column.NS, _get_ns_color(entry.ns))
	item.set_text(Column.MSG, entry.msg)
	item.set_tooltip_text(Column.MSG, entry.msg)
	item.set_metadata(Column.TIME, entry)
	for frame in entry.stack:
		var child = item.create_child()
		child.set_text(Column.MSG, "at %s (%s:%d)" % [frame[2], frame[0], frame[1]])
		child.set_custom_color(Column.MSG, STACK_COLOR)
		child.set_metadata(Column.MSG, frame)
	item.collapsed = true
	entry.item = item
	_entries.append(entry)

	_update_level_count(entry.level, 1)
	_update_ns_count(entry.ns, 1)
	if entry.ns:
		_ns_entries += 1
		if _ns_entries == 1:
			_update_namespaces_visibility()

	item.visible = _matches(entry)
	if item.visible:
		_tree.scroll_to_item(item)

	if _entries.size() > MAX_ENTRIES:
		_remove_entry(_entries.pop_front())


##
## Set the list of levels registered in the game, as [code][[level, name], ...][/code]
##
func set_levels(levels: Array) -> void:
	for level_data in levels:
		_ensure_level(level_data[0], level_data[1])


##
## Add a namespace bound in the game, so it appears in the filters even without entries
##
func add_namespace(ns: String) -> void:
	_ensure_namespace(ns)


##
## Set the colors configured in the game, as sent by
## [method HanpekiLoggerEditorTransport._get_colors_payload], and apply them to the filters and
## the existing entries
##
func set_colors(data: Array) -> void:
	_level_colors.clear()
	for level_color in data[0]:
		_level_colors[level_color[0]] = level_color[1]
	_level_default_color = data[1]
	_ns_colors.clear()
	for ns_color in data[2]:
		_ns_colors[ns_color[0]] = ns_color[1]
	_ns_default_color = data[3]

	for level in _levels:
		_refresh_level_row(level)
	for ns in _namespaces:
		_refresh_ns_row(ns)
	for entry in _entries:
		entry.item.set_custom_color(Column.LEVEL, _get_level_color(entry.level))
		entry.item.set_custom_color(Column.NS, _get_ns_color(entry.ns))


##
## Remove every entry
##
func clear() -> void:
	_hovered_item = null
	for entry in _entries:
		entry.item.free()
	_entries.clear()
	for separator in _separators:
		separator.item.free()
	_separators.clear()
	for level in _levels:
		_update_level_count(level, -_levels[level].count)
	for ns in _namespaces:
		_update_ns_count(ns, -_namespaces[ns].count)
	_ns_entries = 0
	_update_namespaces_visibility()


##
## Called when a new game session starts, to clear the entries unless they are preserved
## (in which case, a separator is added to know where the new session starts)
##
func on_session_started() -> void:
	if !_preserve_toggle.button_pressed:
		clear()
	elif !_entries.is_empty():
		_add_separator()


##
## Get the state of the panel to be saved (and restored with [method apply_state]):
## the visibility of the filters, the preserve toggle, the disabled levels (as the union of their
## values) and namespaces, and the position of the splits (between the entries and the filters,
## and between the namespace and level filters) and the width of the resizable columns
##
func get_state() -> Dictionary:
	return {
		"show_namespaces": _ns_toggle.button_pressed,
		"show_levels": _levels_toggle.button_pressed,
		"preserve_logs": _preserve_toggle.button_pressed,
		"disabled_levels": _disabled_levels,
		"disabled_namespaces": _disabled_namespaces.keys(),
		"split_offset": split_offset,
		"filters_split_offset": _filters_split.split_offset,
		"column_widths": _column_widths.duplicate(),
		"break_levels": _break_levels,
		"break_namespaces": _break_namespaces.keys(),
		"break_on_both": _break_on_both_toggle.button_pressed,
		"ignore_breakpoints": _ignore_breakpoints_toggle.button_pressed,
	}


##
## Restore a [param state] obtained with [method get_state].
## Missing or invalid values are ignored, keeping the current ones.
##
func apply_state(state: Dictionary) -> void:
	if typeof(state.get("show_namespaces")) == TYPE_BOOL:
		_ns_toggle.set_pressed_no_signal(state.show_namespaces)
		_update_namespaces_visibility()
	if typeof(state.get("show_levels")) == TYPE_BOOL:
		_levels_toggle.set_pressed_no_signal(state.show_levels)
		_levels_list.visible = state.show_levels
	if typeof(state.get("preserve_logs")) == TYPE_BOOL:
		_preserve_toggle.set_pressed_no_signal(state.preserve_logs)
	if typeof(state.get("disabled_levels")) == TYPE_INT:
		_disabled_levels = state.disabled_levels
		for level in _levels:
			_set_level_enabled(level, _disabled_levels & level == 0)
	if typeof(state.get("disabled_namespaces")) == TYPE_ARRAY:
		_disabled_namespaces.clear()
		for ns in state.disabled_namespaces:
			if typeof(ns) == TYPE_STRING:
				_disabled_namespaces[ns] = true
		for ns in _namespaces:
			_set_namespace_enabled(ns, !_disabled_namespaces.has(ns))
	if typeof(state.get("split_offset")) == TYPE_INT:
		split_offset = state.split_offset
	if typeof(state.get("filters_split_offset")) == TYPE_INT:
		_filters_split.split_offset = state.filters_split_offset
	if typeof(state.get("column_widths")) == TYPE_DICTIONARY:
		for column in state.column_widths:
			var width = state.column_widths[column]
			if _column_widths.has(column) && typeof(width) == TYPE_INT:
				_column_widths[column] = maxi(MIN_COLUMN_WIDTH, width)
		_apply_column_widths()
	if typeof(state.get("break_levels")) == TYPE_INT:
		_break_levels = state.break_levels
		for level in _levels:
			_set_level_break(level, _break_levels & level != 0)
	if typeof(state.get("break_namespaces")) == TYPE_ARRAY:
		_break_namespaces.clear()
		for ns in state.break_namespaces:
			if typeof(ns) == TYPE_STRING:
				_break_namespaces[ns] = true
		for ns in _namespaces:
			_set_namespace_break(ns, _break_namespaces.has(ns))
	if typeof(state.get("break_on_both")) == TYPE_BOOL:
		_break_on_both_toggle.set_pressed_no_signal(state.break_on_both)
		_update_break_on_both_toggle()
	if typeof(state.get("ignore_breakpoints")) == TYPE_BOOL:
		_ignore_breakpoints_toggle.set_pressed_no_signal(state.ignore_breakpoints)
		if is_inside_tree():
			_update_ignore_breakpoints_icon()
	breakpoints_changed.emit()
	_refilter()


##
## Add a separator row showing that a new game session started at the current time.
## Separators are not entries, so they are not affected by the filters nor copied.
##
func _add_separator() -> void:
	var item = _tree.create_item(_tree.get_root())
	var time = Time.get_time_dict_from_system()
	item.set_text(
		Column.MSG,
		"──── New session started at %02d:%02d:%02d ────" % [time.hour, time.minute, time.second]
	)
	for column in Column.size():
		item.set_selectable(column, false)
		item.set_custom_bg_color(column, SEPARATOR_BG_COLOR)
	item.set_custom_color(Column.MSG, STACK_COLOR)
	_separators.append({"item": item, "next_id": _next_id})
	_tree.scroll_to_item(item)


func _notification(what: int) -> void:
	# icons are taken from the editor theme, which is available once the panel is in the tree
	if what == NOTIFICATION_THEME_CHANGED:
		_ns_toggle.icon = get_theme_icon("TripleBar", "EditorIcons")
		_levels_toggle.icon = get_theme_icon("ProjectList", "EditorIcons")
		_preserve_toggle.icon = get_theme_icon("Pin", "EditorIcons")
		_clear_button.icon = get_theme_icon("Clear", "EditorIcons")
		_update_ignore_breakpoints_icon()
		# the copy icon depends on the theme, so it's recalculated when needed
		_copy_icon = null


##
## Get the icon for the copy button, scaled to fit in a row of the given [param row_height].
## Tree buttons are as tall as their icon plus the inner margins of the items, so the default
## icon would make the hovered row grow (causing a layout shift)
##
func _get_copy_icon(row_height: float) -> Texture2D:
	var max_height = floori(
		row_height
		- _tree.get_theme_constant("inner_item_margin_top")
		- _tree.get_theme_constant("inner_item_margin_bottom")
	)
	if _copy_icon && _copy_icon.get_height() <= max_height:
		return _copy_icon

	var icon = get_theme_icon("ActionCopy", "EditorIcons")
	var image = icon.get_image()
	if !image || max_height <= 0 || image.get_height() <= max_height:
		_copy_icon = icon
		return _copy_icon
	image = image.duplicate()
	image.resize(max_height, max_height, Image.INTERPOLATE_LANCZOS)
	_copy_icon = ImageTexture.create_from_image(image)
	return _copy_icon


func _build_ui() -> void:
	size_flags_vertical = SIZE_EXPAND_FILL
	dragged.connect(func(_offset): state_changed.emit())

	# Left side: entries and search
	var left = VBoxContainer.new()
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(left)

	_tree = Tree.new()
	_tree.hide_root = true
	_tree.columns = Column.size()
	_tree.select_mode = Tree.SELECT_MULTI
	_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_tree.create_item()
	for column in [Column.TIME, Column.LEVEL, Column.NS]:
		_tree.set_column_expand(column, false)
		_tree.set_column_clip_content(column, true)
	_tree.set_column_expand(Column.MSG, true)
	_apply_column_widths()
	_tree.item_mouse_selected.connect(_on_entry_clicked)
	_tree.button_clicked.connect(_on_entry_button_clicked)
	_tree.gui_input.connect(_on_tree_gui_input)
	_tree.mouse_exited.connect(func(): _set_hovered_item(null))
	left.add_child(_tree)

	var bottom = HBoxContainer.new()
	left.add_child(bottom)
	_search = LineEdit.new()
	_search.placeholder_text = "Filter Messages"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_text): _refilter())
	bottom.add_child(_search)
	_clear_button = _create_tool_button("Clear the logs")
	_clear_button.pressed.connect(clear)
	bottom.add_child(_clear_button)
	_preserve_toggle = _create_tool_button(
		"Preserve the logs when running the project again (instead of clearing them)", false
	)
	_preserve_toggle.toggled.connect(func(_pressed): state_changed.emit())
	bottom.add_child(_preserve_toggle)
	_ns_toggle = _create_tool_button("Show/hide the namespaces filter", true)
	_ns_toggle.toggled.connect(
		func(_pressed):
			_update_namespaces_visibility()
			state_changed.emit()
	)
	bottom.add_child(_ns_toggle)
	_levels_toggle = _create_tool_button("Show/hide the levels filter", true)
	_levels_toggle.toggled.connect(
		func(pressed):
			_levels_list.visible = pressed
			state_changed.emit()
	)
	bottom.add_child(_levels_toggle)
	_break_on_both_toggle = _create_tool_button("", false)
	_break_on_both_toggle.toggled.connect(
		func(_pressed):
			_update_break_on_both_toggle()
			breakpoints_changed.emit()
			state_changed.emit()
	)
	_update_break_on_both_toggle()
	bottom.add_child(_break_on_both_toggle)
	_ignore_breakpoints_toggle = _create_tool_button("Ignore the log breakpoints", false)
	_ignore_breakpoints_toggle.toggled.connect(
		func(_pressed):
			_update_ignore_breakpoints_icon()
			breakpoints_changed.emit()
			state_changed.emit()
	)
	bottom.add_child(_ignore_breakpoints_toggle)

	# Right side: filters (namespaces at the left of levels), resizable within the remaining space
	_filters_split = HSplitContainer.new()
	_filters_split.dragged.connect(func(_offset): state_changed.emit())
	add_child(_filters_split)
	_ns_list = FilterList.new("Namespaces")
	_ns_list.filter_toggled.connect(_on_namespace_filter_toggled)
	_ns_list.break_toggled.connect(_on_namespace_break_toggled)
	_filters_split.add_child(_ns_list)
	_levels_list = FilterList.new("Levels")
	_levels_list.filter_toggled.connect(_on_level_filter_toggled)
	_levels_list.break_toggled.connect(_on_level_break_toggled)
	_filters_split.add_child(_levels_list)


##
## Get the data of the given [param level], adding it to the filters if it's not known yet
## (or updating its name)
##
func _ensure_level(level: int, level_name: String) -> Dictionary:
	if _levels.has(level):
		var existing = _levels[level]
		if existing.name != level_name:
			existing.name = level_name
			_refresh_level_row(level)
		return existing

	# sorted by level value, with the most important ones on top
	var index = 0
	for known in _levels:
		if known > level:
			index += 1
	var enabled = _disabled_levels & level == 0
	_levels[level] = {"name": level_name, "enabled": enabled, "count": 0}
	_levels_list.add_row(level, index)
	_levels_list.set_row_enabled(level, enabled)
	_levels_list.set_row_break(level, _break_levels & level != 0)
	_refresh_level_row(level)
	return _levels[level]


##
## Get the data of the given namespace [param ns], adding it to the filters if it's not known yet
##
func _ensure_namespace(ns: String) -> Dictionary:
	if _namespaces.has(ns):
		return _namespaces[ns]

	# sorted alphabetically (case-insensitive), with the empty namespace first
	var index = 0
	for known in _namespaces:
		if known.naturalnocasecmp_to(ns) < 0:
			index += 1
	var enabled = !_disabled_namespaces.has(ns)
	_namespaces[ns] = {"enabled": enabled, "count": 0}
	_ns_list.add_row(ns, index)
	_ns_list.set_row_enabled(ns, enabled)
	_ns_list.set_row_break(ns, _break_namespaces.has(ns))
	_refresh_ns_row(ns)
	_update_namespaces_visibility()
	return _namespaces[ns]


##
## Update the text (name with its color, and count) of the row of a [param level] in the filters
##
func _refresh_level_row(level: int) -> void:
	var data = _levels[level]
	_levels_list.set_row_text(level, data.name, _get_level_color(level), data.count)


##
## Update the text (name with its color, and count) of the row of a namespace [param ns]
## in the filters. The one for messages without namespace is dimmed, as it's not a real namespace
##
func _refresh_ns_row(ns: String) -> void:
	var text = ns if ns else NS_NONE_TEXT
	var color = _get_ns_color(ns) if ns else NS_NONE_COLOR
	_ns_list.set_row_text(ns, text, color, _namespaces[ns].count)


##
## Update the visibility of the namespaces filter (based on its toggle) and the namespace column
## (only when there are entries with a namespace)
##
func _update_namespaces_visibility() -> void:
	# the list is always available (even if empty), only controlled by its toggle
	_ns_list.visible = _ns_toggle.button_pressed
	# the column is only displayed when there are entries using any namespace
	_apply_column_widths()


##
## Apply the widths of the resizable columns (the namespace one is collapsed when there are no
## entries with namespace)
##
func _apply_column_widths() -> void:
	var show_ns = _ns_entries > 0
	for column in _column_widths:
		var width = 0 if column == Column.NS && !show_ns else _column_widths[column]
		_tree.set_column_custom_minimum_width(column, width)



##
## Create a flat button with an icon (set when the theme is available) and a [param tooltip].
## If [param pressed] is provided, it's created as a toggle button with that initial state.
##
func _create_tool_button(tooltip: String, pressed: Variant = null) -> Button:
	var button = Button.new()
	button.flat = true
	button.tooltip_text = tooltip
	if pressed != null:
		button.toggle_mode = true
		button.button_pressed = pressed
	return button


##
## Show the current mode (AND / OR) in the toggle to combine the level and namespace breakpoints
##
func _update_break_on_both_toggle() -> void:
	if _break_on_both_toggle.button_pressed:
		_break_on_both_toggle.text = "AND"
		_break_on_both_toggle.tooltip_text = (
			"Breakpoints: stop only when both the level and the namespace are checked"
			+ " (or any of them, if no level or no namespace is checked)"
		)
	else:
		_break_on_both_toggle.text = "OR"
		_break_on_both_toggle.tooltip_text = (
			"Breakpoints: stop when either the level or the namespace are checked"
		)


##
## Show if the breakpoints are ignored in the icon of its toggle (same icons as the debugger)
##
func _update_ignore_breakpoints_icon() -> void:
	var icon_name = (
		"DebugSkipBreakpointsOn"
		if _ignore_breakpoints_toggle.button_pressed
		else "DebugSkipBreakpointsOff"
	)
	_ignore_breakpoints_toggle.icon = get_theme_icon(icon_name, "EditorIcons")


##
## Get the breakpoints configuration to send to the running game, as
## [code][levels, namespaces, on_both, ignored][/code]
## (see [method HanpekiLoggerEditorTransport._set_breakpoints])
##
func get_breakpoints_payload() -> Array:
	return [
		_break_levels,
		_break_namespaces.keys(),
		_break_on_both_toggle.button_pressed,
		_ignore_breakpoints_toggle.button_pressed,
	]


##
## Update the count of entries of the given [param level] by [param delta]
##
func _update_level_count(level: int, delta: int) -> void:
	_levels[level].count += delta
	_refresh_level_row(level)


##
## Update the count of entries of the given namespace [param ns] by [param delta]
##
func _update_ns_count(ns: String, delta: int) -> void:
	_namespaces[ns].count += delta
	_refresh_ns_row(ns)



##
## Remove the given [param entry] (already removed from [member _entries])
##
func _remove_entry(entry: Dictionary) -> void:
	_update_level_count(entry.level, -1)
	_update_ns_count(entry.ns, -1)
	if entry.ns:
		_ns_entries -= 1
		if _ns_entries == 0:
			_update_namespaces_visibility()
	if entry.item == _hovered_item:
		_hovered_item = null
	entry.item.free()
	# separators left on top (before the oldest entry) are removed as well
	while !_separators.is_empty() && _separators[0].next_id <= entry.id + 1:
		_separators.pop_front().item.free()


##
## Check if the given [param entry] needs to be visible with the current filters
##
func _matches(entry: Dictionary) -> bool:
	if !_levels[entry.level].enabled || !_namespaces[entry.ns].enabled:
		return false
	var text = _search.text
	return text.is_empty() || entry.msg.containsn(text)


##
## Update the visibility of every entry based on the current filters
##
func _refilter() -> void:
	for entry in _entries:
		entry.item.visible = _matches(entry)


func _on_level_filter_toggled(level: int, enabled: bool) -> void:
	_set_level_enabled(level, enabled)
	_refilter()
	state_changed.emit()


func _on_namespace_filter_toggled(ns: String, enabled: bool) -> void:
	_set_namespace_enabled(ns, enabled)
	_refilter()
	state_changed.emit()


func _on_level_break_toggled(level: int, enabled: bool) -> void:
	_set_level_break(level, enabled)
	breakpoints_changed.emit()
	state_changed.emit()


func _on_namespace_break_toggled(ns: String, enabled: bool) -> void:
	_set_namespace_break(ns, enabled)
	breakpoints_changed.emit()
	state_changed.emit()


func _set_level_break(level: int, enabled: bool) -> void:
	if enabled:
		_break_levels |= level
	else:
		_break_levels &= ~level
	_levels_list.set_row_break(level, enabled)


func _set_namespace_break(ns: String, enabled: bool) -> void:
	if enabled:
		_break_namespaces[ns] = true
	else:
		_break_namespaces.erase(ns)
	_ns_list.set_row_break(ns, enabled)


func _set_level_enabled(level: int, enabled: bool) -> void:
	if enabled:
		_disabled_levels &= ~level
	else:
		_disabled_levels |= level
	if _levels.has(level):
		_levels[level].enabled = enabled
		_levels_list.set_row_enabled(level, enabled)


func _set_namespace_enabled(ns: String, enabled: bool) -> void:
	if enabled:
		_disabled_namespaces.erase(ns)
	else:
		_disabled_namespaces[ns] = true
	if _namespaces.has(ns):
		_namespaces[ns].enabled = enabled
		_ns_list.set_row_enabled(ns, enabled)



##
## Clicking on an entry expands or collapses it (if it has a stack),
## and clicking on a stack line opens the script at that line
##
func _on_entry_clicked(click_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	# clicks with modifiers are used to select multiple entries
	if Input.is_key_pressed(KEY_CTRL) || Input.is_key_pressed(KEY_SHIFT):
		return
	var item = _tree.get_item_at_position(click_position)
	if !item:
		return
	var frame = item.get_metadata(Column.MSG)
	if frame:
		_open_script(frame[0], frame[1])
	elif item.get_child_count() > 0:
		item.collapsed = !item.collapsed


##
## Show the copy button on the hovered entry, and copy the selected entries with Ctrl+C
##
func _on_tree_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var item = _tree.get_item_at_position(event.position)
		# the button is shown in the entry, even when hovering its stack lines
		if item && item.get_parent() != _tree.get_root():
			item = item.get_parent()
		# separators have no entry data and can't be copied
		if item && !item.get_metadata(Column.TIME):
			item = null
		_set_hovered_item(item)
	elif (
		event is InputEventKey
		&& event.pressed
		&& event.keycode == KEY_C
		&& event.is_command_or_control_pressed()
	):
		_copy_selected()
		_tree.accept_event()


##
## Move the copy button to the given [param item] (or remove it if [code]null[/code])
##
func _set_hovered_item(item: TreeItem) -> void:
	if item == _hovered_item:
		return
	if _hovered_item:
		_hovered_item.clear_buttons()
	_hovered_item = item
	if item:
		# measured before adding the button, so it's the height of the text row
		var row_height = _tree.get_item_area_rect(item).size.y
		item.add_button(Column.MSG, _get_copy_icon(row_height), COPY_BUTTON_ID, false, "Copy")


func _on_entry_button_clicked(
	item: TreeItem, _column: int, id: int, _mouse_button_index: int
) -> void:
	if id == COPY_BUTTON_ID:
		DisplayServer.clipboard_set(_entry_to_text(item.get_metadata(Column.TIME)))


##
## Copy the selected entries (selecting a stack line copies its entry)
##
func _copy_selected() -> void:
	var lines: Array[String] = []
	var copied: Dictionary[TreeItem, bool] = {}
	var item = _tree.get_next_selected(null)
	while item:
		var entry_item = item if item.get_parent() == _tree.get_root() else item.get_parent()
		if !copied.has(entry_item):
			copied[entry_item] = true
			lines.append(_entry_to_text(entry_item.get_metadata(Column.TIME)))
		item = _tree.get_next_selected(item)
	if lines:
		DisplayServer.clipboard_set("\n".join(lines))


##
## Get the given [param entry] as plain text, including its stack
##
func _entry_to_text(entry: Dictionary) -> String:
	var ns = " [%s]" % entry.ns if entry.ns else ""
	var text = "%s [%s]%s %s" % [_format_time(entry.unix_ms), entry.level_name, ns, entry.msg]
	for frame in entry.stack:
		text += "\n    at %s (%s:%d)" % [frame[2], frame[0], frame[1]]
	return text


##
## Open the script at [param source] in the script editor at the given [param line]
##
func _open_script(source: String, line: int) -> void:
	if !ResourceLoader.exists(source):
		return
	var script = load(source)
	if script is Script:
		EditorInterface.edit_script(script, line)
		EditorInterface.set_main_screen_editor("Script")


##
## Format the given unix time in milliseconds as the local time [code]hh:mm:ss.mmm[/code]
##
func _format_time(unix_ms: int) -> String:
	@warning_ignore("integer_division")
	var time = Time.get_time_dict_from_unix_time(unix_ms / 1000 + _time_bias)
	return "%02d:%02d:%02d.%03d" % [time.hour, time.minute, time.second, unix_ms % 1000]


func _get_level_color(level: int) -> Color:
	return _level_colors.get(level, _level_default_color)


func _get_ns_color(ns: String) -> Color:
	return _ns_colors.get(ns, _ns_default_color)
