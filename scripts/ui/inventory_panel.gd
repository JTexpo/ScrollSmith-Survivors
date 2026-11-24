class_name InventoryPanel
extends Control
## A cream panel listing the collected scrolls under Base, Area and Buff headings,
## with name, rarity and count. It reads the inventory and never changes it. It does not pause the
## game. Starts closed.

const SIZE := Vector2(260, 214)
const HEADINGS := {
	ScrollData.Category.BASE: "Base",
	ScrollData.Category.AREA: "Area",
	ScrollData.Category.BUFF: "Buff",
}
const RARITY_NAMES := {
	ScrollData.Rarity.COMMON: "Common",
	ScrollData.Rarity.UNCOMMON: "Uncommon",
	ScrollData.Rarity.RARE: "Rare",
}

var _inventory: ScrollInventory
var _rows: VBoxContainer
var _row_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	size = SIZE
	var surface := Panel.new()
	surface.name = "Surface"
	surface.size = SIZE
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(surface)
	_rows = VBoxContainer.new()
	_rows.position = Vector2(6, 4)
	_rows.size = SIZE - Vector2(12, 8)
	_rows.add_theme_constant_override("separation", 1)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)
	visible = false


func bind(inventory: ScrollInventory) -> void:
	_inventory = inventory
	inventory.changed.connect(_on_changed)


func toggle() -> void:
	set_open(not visible)


## Opening pauses the game (and closing resumes it), so the player can read the list without being hit. The panel keeps running while
## paused so it can close itself; Main's own key handling does not run while the tree is paused.
func set_open(value: bool) -> void:
	if value == visible:
		return
	visible = value
	if value:
		_rebuild()
	GamePause.set_paused(get_tree(), value)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"toggle_inventory") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel")):
		set_open(false)
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return visible


## Headings and rows in display order, as text. A category with nothing in it shows "-".
func entries() -> Array[String]:
	var lines: Array[String] = []
	for category in HEADINGS:
		lines.append(HEADINGS[category])
		var scrolls := _inventory.by_category(category) if _inventory != null else ([] as Array[ScrollData])
		if scrolls.is_empty():
			lines.append("-")
		for scroll in scrolls:
			lines.append(_row_text(scroll))
	return lines


## How many scroll rows are drawn (not counting headings or dashes).
func row_count() -> int:
	return _row_count


func _row_text(scroll: ScrollData) -> String:
	return "%s (%s) x%d" % [scroll.display_name, RARITY_NAMES[scroll.rarity], _inventory.count(scroll)]


func _on_changed(_scroll: ScrollData) -> void:
	if visible:
		_rebuild()


func _rebuild() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_row_count = 0
	if _inventory == null:
		return
	for category in HEADINGS:
		_rows.add_child(UiKit.label(HEADINGS[category], &"Heading"))
		var scrolls := _inventory.by_category(category)
		if scrolls.is_empty():
			_rows.add_child(UiKit.label("-", &"Muted"))
		for scroll in scrolls:
			_rows.add_child(_scroll_row(scroll))
			_row_count += 1


func _scroll_row(scroll: ScrollData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(6, 6)
	swatch.color = scroll.color
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(swatch)
	row.add_child(UiKit.label(_row_text(scroll)))
	return row
