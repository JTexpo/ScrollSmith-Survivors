class_name CraftingScreen
extends CanvasLayer
## The one-screen crafting workbench. Your spell slots across the top,
## lists of owned Base scrolls, Area scrolls and range options below, a live preview of the new
## spell beside the spell it would replace, and Confirm and Cancel. It is a thin layer over a
## CraftingSession: it shows the choices and calls into the session, and holds no crafting rules.
## It pauses the world while open. It works with mouse, keyboard or controller focus, and touch
## (bridged, because mouse emulation is off).

signal closed

const SLOT_SIZE := Vector2(88, 26)
const ROW_HEIGHT := 15.0
const CHOICE_WIDTH := 96.0
## The range column is a little wider: "Very long (cost x1.8)" does not fit 96 px.
const RANGE_WIDTH := 112.0
const BUFF_COLUMNS := 1
const BUFF_NAME_WIDTH := 138.0
## The preview on the right, and the message under it. The tests check the longest recipe against these.
const PREVIEW_SIZE := Vector2(152, 146)
const MESSAGE_SIZE := Vector2(152, 32)
const READY_MESSAGE := "Ready to craft."

## Tests turn this off so the test runner itself is not paused.
@export var pause_tree: bool = true

var session: CraftingSession

var _open: bool = false
var _inventory: ScrollInventory
var _loadout: SpellLoadout

var _slot_row: HBoxContainer
var _base_column: VBoxContainer
var _area_column: VBoxContainer
var _range_column: VBoxContainer
var _buffs_label: Label
var _buff_grid: GridContainer
var _preview_label: Label
var _message_label: Label
var _confirm_button: Button
var _cancel_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	visible = false
	_build()


func _input(event: InputEvent) -> void:
	if handle_input(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		cancel()
		get_viewport().set_input_as_handled()


## Turns a touch into a left mouse press so the buttons react. Returns true if it did.
## The touch position is already in game coordinates, so the click goes straight into this
## viewport (`push_input`). `Input.parse_input_event` would scale it a second time at any window
## size above the base resolution, and it would also press the global `cast` action, which is
## bound to the left mouse button.
func handle_input(event: InputEvent) -> bool:
	if not _open or not event is InputEventScreenTouch:
		return false
	get_viewport().push_input(TouchBridge.to_mouse_button(event), true)
	return true


func open(inventory: ScrollInventory, loadout: SpellLoadout) -> void:
	if _open:
		return
	_inventory = inventory
	_loadout = loadout
	session = CraftingSession.new(CraftingRules.default_rules(), inventory, loadout)
	session.changed.connect(_rebuild)
	_open = true
	visible = true
	if pause_tree:
		GamePause.set_paused(get_tree(), true)
	_rebuild()
	_focus_first()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	if pause_tree:
		GamePause.set_paused(get_tree(), false)
	closed.emit()


func is_open() -> bool:
	return _open


func choose_base(scroll: ScrollData) -> bool:
	return session.select_base(scroll)


func choose_area(scroll: ScrollData) -> bool:
	return session.select_area(scroll)


func choose_range(index: int) -> bool:
	return session.select_range(index)


func add_buff(scroll: ScrollData) -> bool:
	return session.add_buff(scroll)


func remove_buff(scroll: ScrollData) -> bool:
	return session.remove_buff(scroll)


func choose_slot(index: int) -> bool:
	return session.select_slot(index)


## Crafts and closes if it worked. Otherwise the reason stays on screen.
func confirm() -> void:
	if session.confirm().ok:
		close()
	else:
		_rebuild()


func cancel() -> void:
	close()


func confirm_enabled() -> bool:
	return session.can_confirm()


func message_text() -> String:
	var reason := session.message()
	return READY_MESSAGE if reason.is_empty() else reason


func preview_text() -> String:
	var lines: Array[String] = []
	var fresh := session.new_stats()
	if fresh.is_empty():
		lines.append("New: pick a Base and an Area")
	else:
		lines.append("New: %s" % fresh["name"])
		lines.append_array(_stat_lines(fresh))
		lines.append_array(session.drawbacks())
	var current := session.current_stats()
	if not current.is_empty():
		lines.append("Now: %s  (casts %d)" % [current["name"], current["whole_casts"]])
	lines.append(session.replace_note())
	return "\n".join(lines)


## How tall the preview text really is once the label has wrapped it at its width.
func preview_height() -> float:
	return _preview_label.get_minimum_size().y


func buffs_text() -> String:
	var names: Array[String] = []
	for scroll in session.owned_buffs():
		var stacks := session.buff_stacks(scroll)
		if stacks > 0:
			names.append("%s x%d" % [scroll.display_name, stacks])
	return "Buffs: %s" % (", ".join(names) if not names.is_empty() else "none")


func base_heading_text() -> String:
	return "Base (%d of %d)" % [session.bases.size(), session.max_bases()]


func buff_button_count() -> int:
	return _buff_grid.get_child_count()


func base_button_count() -> int:
	return _count_buttons(_base_column)


func area_button_count() -> int:
	return _count_buttons(_area_column)


func range_button_count() -> int:
	return _count_buttons(_range_column)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var content := UiKit.window(root)
	content.add_child(_label("Arcane Lectern", Vector2(8, 3), Vector2(200, 12), &"Heading"))
	_slot_row = _add_box(content, HBoxContainer.new(), Vector2(8, 16))
	_slot_row.add_theme_constant_override("separation", 2)
	_base_column = _add_box(content, VBoxContainer.new(), Vector2(8, 46))
	_area_column = _add_box(content, VBoxContainer.new(), Vector2(108, 46))
	_range_column = _add_box(content, VBoxContainer.new(), Vector2(208, 46))
	for column in [_base_column, _area_column, _range_column]:
		column.add_theme_constant_override("separation", 1)
	_buffs_label = _label("", Vector2(8, 145), Vector2(300, 10), &"Muted")
	_buffs_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_buffs_label.clip_text = true
	content.add_child(_buffs_label)
	_buff_grid = GridContainer.new()
	_buff_grid.columns = BUFF_COLUMNS
	_buff_grid.position = Vector2(8, 156)
	_buff_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buff_grid.add_theme_constant_override("h_separation", 6)
	_buff_grid.add_theme_constant_override("v_separation", 1)
	content.add_child(_buff_grid)
	_preview_label = _label("", Vector2(322, 46), PREVIEW_SIZE)
	content.add_child(_preview_label)
	_message_label = _label("", Vector2(322, 196), MESSAGE_SIZE)
	content.add_child(_message_label)
	_confirm_button = _button("Confirm", Vector2(322, 232), Vector2(70, 22), &"ButtonRed")
	_confirm_button.pressed.connect(confirm)
	content.add_child(_confirm_button)
	_cancel_button = _button("Cancel", Vector2(398, 232), Vector2(70, 22), &"ButtonGreen")
	_cancel_button.pressed.connect(cancel)
	content.add_child(_cancel_button)


func _rebuild() -> void:
	var focused := _focus_key()
	for container in [_slot_row, _base_column, _area_column, _range_column, _buff_grid]:
		_clear(container)
	for i in SpellLoadout.SLOT_COUNT:
		_slot_row.add_child(_slot_button(i))
	_fill_scrolls(_base_column, base_heading_text(), session.owned_bases(), session.bases, _on_base_pressed)
	_fill_scrolls(_area_column, "Area", session.owned_areas(), [session.area], _on_area_pressed)
	_range_column.add_child(_label("Range", Vector2.ZERO, Vector2(100, ROW_HEIGHT), &"Heading"))
	for i in session.rules.range_options.size():
		var option := session.rules.option(i)
		var text := "%s (cost x%.1f)" % [option.label, option.cost_multiplier]
		_range_column.add_child(_selectable(text, "range:%d" % i, i == session.option_index, _on_range_pressed.bind(i), RANGE_WIDTH))
	for scroll in session.owned_buffs():
		_buff_grid.add_child(_buff_cell(scroll))
	_buffs_label.text = buffs_text()
	_preview_label.text = preview_text()
	_message_label.text = message_text()
	_message_label.theme_type_variation = &"Muted" if session.message().is_empty() else &"Warning"
	_confirm_button.disabled = not session.can_confirm()
	_restore_focus(focused)


func _slot_button(index: int) -> Button:
	var text: String
	if not _loadout.is_unlocked(index):
		text = "%d  locked" % (index + 1)
	elif _loadout.slots[index] == null:
		text = "%d  empty" % (index + 1)
	else:
		var instance := _loadout.slots[index]
		text = "%d %s\n%d / %d" % [index + 1, instance.data.display_name, roundi(instance.current_mana), roundi(instance.max_mana())]
	var button := _selectable(text, "slot:%d" % index, index == session.slot_index, _on_slot_pressed.bind(index))
	button.custom_minimum_size = SLOT_SIZE
	button.disabled = not _loadout.is_unlocked(index)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return button


## One buff: a minus button, the name, chosen over owned stacks, and a plus button.
func _buff_cell(scroll: ScrollData) -> HBoxContainer:
	var cell := HBoxContainer.new()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_constant_override("separation", 2)
	var minus := _button("-", Vector2.ZERO, Vector2(14, ROW_HEIGHT))
	minus.set_meta(&"key", "buff-:%s" % scroll.id)
	minus.disabled = session.buff_stacks(scroll) == 0
	minus.pressed.connect(session.remove_buff.bind(scroll))
	cell.add_child(minus)
	var name_label := _label(scroll.display_name, Vector2.ZERO, Vector2(BUFF_NAME_WIDTH, ROW_HEIGHT))
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.add_child(name_label)
	var count_label := _label("%d/%d" % [session.buff_stacks(scroll), _inventory.count(scroll)], Vector2.ZERO, Vector2(24, ROW_HEIGHT))
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.add_child(count_label)
	var plus := _button("+", Vector2.ZERO, Vector2(14, ROW_HEIGHT))
	plus.set_meta(&"key", "buff+:%s" % scroll.id)
	plus.disabled = not session.can_add_buff(scroll)
	plus.pressed.connect(session.add_buff.bind(scroll))
	cell.add_child(plus)
	return cell


func _fill_scrolls(column: VBoxContainer, heading: String, scrolls: Array[ScrollData], chosen: Array, callback: Callable) -> void:
	column.add_child(_label(heading, Vector2.ZERO, Vector2(100, ROW_HEIGHT), &"Heading"))
	if scrolls.is_empty():
		column.add_child(_label("(none)", Vector2.ZERO, Vector2(100, ROW_HEIGHT), &"Muted"))
	for scroll in scrolls:
		var text := "%s x%d" % [scroll.display_name, _inventory.count(scroll)]
		column.add_child(_selectable(text, "scroll:%s" % scroll.id, chosen.has(scroll), callback.bind(scroll)))


func _selectable(text: String, key: String, selected: bool, callback: Callable, width: float = CHOICE_WIDTH) -> Button:
	var button := _button(("> " + text) if selected else text, Vector2.ZERO, Vector2(width, ROW_HEIGHT), &"ButtonYellow" if selected else &"")
	button.set_meta(&"key", key)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(callback)
	return button


func _button(text: String, at: Vector2, minimum: Vector2, variation: StringName = &"") -> Button:
	var button := UiKit.button(text, variation)
	button.position = at
	button.custom_minimum_size = minimum
	return button


func _label(text: String, at: Vector2, minimum: Vector2, variation: StringName = &"") -> Label:
	var label := UiKit.label(text, variation)
	label.position = at
	label.custom_minimum_size = minimum
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _add_box(root: Control, box: BoxContainer, at: Vector2) -> BoxContainer:
	box.position = at
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	return box


func _stat_lines(stats: Dictionary) -> Array[String]:
	var lines: Array[String] = [
		"  Damage %.1f  Every %.2fs" % [stats["damage"], stats["interval"]],
		"  Mana/cast %.1f  Pool %d" % [stats["cost"], roundi(stats["pool"])],
		"  Casts %d  Range %d" % [stats["whole_casts"], roundi(stats["range"])],
		"  Elements %s  Shots %d" % [stats["elements"], stats["copies"]],
	]
	if stats["vulnerability"] > 1.0:
		lines.append("  Vulnerable bonus x%.1f" % stats["vulnerability"])
	if stats["ignores_resistance"]:
		lines.append("  Ignores resistance")
	return lines


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _count_buttons(container: Container) -> int:
	var count := 0
	for child in container.get_children():
		if child is Button:
			count += 1
	return count


func _focus_key() -> String:
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return str(focused.get_meta(&"key", "")) if focused != null else ""


func _restore_focus(key: String) -> void:
	if key.is_empty():
		return
	var keys := [key]
	# A stepper that just went disabled (the last owned stack, or zero stacks) hands focus to its pair.
	if key.begins_with("buff+:") or key.begins_with("buff-:"):
		keys.append(("buff-:" if key.begins_with("buff+:") else "buff+:") + key.get_slice(":", 1))
	for wanted in keys:
		for container in [_slot_row, _base_column, _area_column, _range_column, _buff_grid]:
			for child in container.find_children("*", "Button", true, false):
				if str(child.get_meta(&"key", "")) == wanted and not child.disabled:
					child.grab_focus()
					return
	_focus_first()


func _focus_first() -> void:
	for container in [_base_column, _area_column, _range_column]:
		for child in container.get_children():
			if child is Button and not child.disabled:
				child.grab_focus()
				return
	_cancel_button.grab_focus()


func _on_slot_pressed(index: int) -> void:
	session.select_slot(index)


func _on_base_pressed(scroll: ScrollData) -> void:
	session.select_base(scroll)


func _on_area_pressed(scroll: ScrollData) -> void:
	session.select_area(scroll)


func _on_range_pressed(index: int) -> void:
	session.select_range(index)
