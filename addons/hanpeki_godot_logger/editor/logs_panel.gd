@tool
##
## Content of the [code]Logs[/code] editor dock: the list of entries received from the running game
## (left), the search input (below the list) and the level and namespace filters (right)
##
extends HSplitContainer

## Emitted when any state to be saved changes (see [method get_state])
signal state_changed

## Columns of the entries tree
enum Column { TIME, LEVEL, NS, MSG }

## Maximum number of entries to keep (the oldest ones are removed)
const MAX_ENTRIES = 10000
## Text displayed for messages without namespace
const NS_NONE_TEXT = "(none)"
## Width of the namespace column (when there are namespaces to display)
const NS_COLUMN_WIDTH = 120
## Id of the copy button displayed when hovering an entry
const COPY_BUTTON_ID = 0
## Color used for each predefined level
const LEVEL_COLORS: Dictionary[int, Color] = {
	HanpekiLogger.DEBUG: Color(0.6, 0.6, 0.6),
	HanpekiLogger.INFO: Color(0.35, 0.8, 1.0),
	HanpekiLogger.CORE: Color(0.4, 0.85, 0.4),
	HanpekiLogger.WARN: Color(1.0, 0.85, 0.3),
	HanpekiLogger.ERROR: Color(1.0, 0.4, 0.4),
	HanpekiLogger.FATAL: Color(1.0, 0.2, 0.5),
}
## Color used for custom levels
const DEFAULT_LEVEL_COLOR = Color(0.85, 0.85, 0.85)
## Color used for the stack lines
const STACK_COLOR = Color(0.6, 0.6, 0.7)
## Background color of the separators between game sessions
const SEPARATOR_BG_COLOR = Color(0.5, 0.5, 0.6, 0.15)

## Tree with the received entries (one top-level item per entry, with the stack as children)
var _tree: Tree
## Input to filter the entries by text
var _search: LineEdit
## Tree with the level filters
var _levels_tree: Tree
## Tree with the namespace filters
var _ns_tree: Tree
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

## Received entries, as
## [code]{ level, level_name, ns, msg, unix_ms, stack, item: TreeItem }[/code]
var _entries: Array[Dictionary] = []
## Known levels, as [code]level -> { name, enabled, count, item: TreeItem }[/code]
var _levels: Dictionary[int, Dictionary] = {}
## Known namespaces, as [code]ns -> { enabled, count, item: TreeItem }[/code]
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
	var level_data = _ensure_level(entry.level, entry.level_name)
	var ns_data = _ensure_namespace(entry.ns)

	var item = _tree.create_item(_tree.get_root())
	item.set_text(Column.TIME, _format_time(entry.unix_ms))
	item.set_text(Column.LEVEL, entry.level_name)
	item.set_custom_color(Column.LEVEL, _get_level_color(entry.level))
	item.set_text(Column.NS, entry.ns)
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

	_update_count(level_data, 1)
	_update_count(ns_data, 1)
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
		_update_count(_levels[level], -_levels[level].count)
	for ns in _namespaces:
		_update_count(_namespaces[ns], -_namespaces[ns].count)
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
## and between the namespace and level filters)
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
		_levels_tree.visible = state.show_levels
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
	_tree.set_column_custom_minimum_width(Column.TIME, 100)
	_tree.set_column_custom_minimum_width(Column.LEVEL, 60)
	_tree.set_column_custom_minimum_width(Column.NS, NS_COLUMN_WIDTH)
	_tree.set_column_expand(Column.MSG, true)
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
			_levels_tree.visible = pressed
			state_changed.emit()
	)
	bottom.add_child(_levels_toggle)

	# Right side: filters (namespaces at the left of levels), resizable within the remaining space
	_filters_split = HSplitContainer.new()
	_filters_split.dragged.connect(func(_offset): state_changed.emit())
	add_child(_filters_split)
	_ns_tree = _create_filter_tree("Namespaces")
	_filters_split.add_child(_ns_tree)
	_levels_tree = _create_filter_tree("Levels")
	_filters_split.add_child(_levels_tree)


##
## Create a tree to be used as a list of filters, with a checkbox and the count of entries
##
func _create_filter_tree(title: String) -> Tree:
	var tree = Tree.new()
	tree.hide_root = true
	tree.columns = 2
	tree.column_titles_visible = true
	tree.set_column_title(0, title)
	tree.set_column_title_alignment(0, HORIZONTAL_ALIGNMENT_LEFT)
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 50)
	# minimum width only, as both filters share the space left by the entries (resizable)
	tree.custom_minimum_size.x = 120
	tree.size_flags_horizontal = SIZE_EXPAND_FILL
	tree.size_flags_vertical = SIZE_EXPAND_FILL
	tree.create_item()
	tree.item_edited.connect(_on_filter_edited.bind(tree))
	return tree


##
## Get the data of the given [param level], adding it to the filters if it's not known yet
## (or updating its name)
##
func _ensure_level(level: int, level_name: String) -> Dictionary:
	if _levels.has(level):
		var existing = _levels[level]
		if existing.name != level_name:
			existing.name = level_name
			existing.item.set_text(0, level_name)
		return existing

	# sorted by level value, with the most important ones on top
	var index = 0
	for known in _levels:
		if known > level:
			index += 1
	var item = _create_filter_item(_levels_tree, level_name, index)
	item.set_custom_color(0, _get_level_color(level))
	var enabled = _disabled_levels & level == 0
	item.set_checked(0, enabled)
	_levels[level] = {"name": level_name, "enabled": enabled, "count": 0, "item": item}
	item.set_metadata(0, level)
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
	var item = _create_filter_item(_ns_tree, ns if ns else NS_NONE_TEXT, index)
	var enabled = !_disabled_namespaces.has(ns)
	item.set_checked(0, enabled)
	_namespaces[ns] = {"enabled": enabled, "count": 0, "item": item}
	item.set_metadata(0, ns)
	_update_namespaces_visibility()
	return _namespaces[ns]


##
## Update the visibility of the namespaces filter (based on its toggle) and the namespace column
## (only when there are entries with a namespace)
##
func _update_namespaces_visibility() -> void:
	# the list is always available (even if empty), only controlled by its toggle
	_ns_tree.visible = _ns_toggle.button_pressed
	# the column is only displayed when there are entries using any namespace
	var column_width = NS_COLUMN_WIDTH if _ns_entries > 0 else 0
	_tree.set_column_custom_minimum_width(Column.NS, column_width)


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
## Create a checkable item in the filter [param tree] with the given [param text] at [param index]
##
func _create_filter_item(tree: Tree, text: String, index: int) -> TreeItem:
	var item = tree.create_item(tree.get_root(), index)
	item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	item.set_checked(0, true)
	item.set_editable(0, true)
	item.set_text(0, text)
	item.set_text(1, "0")
	item.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
	return item


##
## Update the count of entries of a level or namespace [param filter_data] by [param delta]
##
func _update_count(filter_data: Dictionary, delta: int) -> void:
	filter_data.count += delta
	filter_data.item.set_text(1, str(filter_data.count))


##
## Remove the given [param entry] (already removed from [member _entries])
##
func _remove_entry(entry: Dictionary) -> void:
	_update_count(_levels[entry.level], -1)
	_update_count(_namespaces[entry.ns], -1)
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


func _on_filter_edited(tree: Tree) -> void:
	var item = tree.get_edited()
	var key = item.get_metadata(0)
	var enabled = item.is_checked(0)
	if tree == _levels_tree:
		_set_level_enabled(key, enabled)
	else:
		_set_namespace_enabled(key, enabled)
	_refilter()
	state_changed.emit()


func _set_level_enabled(level: int, enabled: bool) -> void:
	if enabled:
		_disabled_levels &= ~level
	else:
		_disabled_levels |= level
	if _levels.has(level):
		_levels[level].enabled = enabled
		_levels[level].item.set_checked(0, enabled)


func _set_namespace_enabled(ns: String, enabled: bool) -> void:
	if enabled:
		_disabled_namespaces.erase(ns)
	else:
		_disabled_namespaces[ns] = true
	if _namespaces.has(ns):
		_namespaces[ns].enabled = enabled
		_namespaces[ns].item.set_checked(0, enabled)


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
	return LEVEL_COLORS.get(level, DEFAULT_LEVEL_COLOR)
