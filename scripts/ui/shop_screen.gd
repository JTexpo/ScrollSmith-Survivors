class_name ShopScreen
extends CanvasLayer
## The equipment shop, opened from the death screen. Items are listed by
## slot (Robe, Weapon, Headwear), and pressing an item buys it, equips it or takes it off, depending on
## what the player has. It is a thin layer over ShopSystem and holds no rules. It works with mouse,
## keyboard or controller focus, and touch (bridged, because mouse emulation is off).

signal changed
signal closed

const COLUMN_X := [8.0, 164.0, 320.0]
const BUTTON_SIZE := Vector2(152, 15)
const SLOT_NAMES := ["Robes", "Wands and Staffs", "Hats and Hoods"]

## Item presses are ignored for this long after the shop opens, so the press that opened it (or one
## mashed right after) cannot also buy something.
var input_guard_msec: int = 300

var _open: bool = false
var _opened_at_msec: int = 0
var _profile: PlayerProfile
var _catalog: EquipmentCatalog
var _potion_catalog: PotionCatalog
var _message: String = ""

var _buttons: Dictionary = {}
var _potion_buttons: Dictionary = {}
var _gold_label: Label
var _detail_label: Label
var _message_label: Label
var _close_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12
	visible = false
	_build()


func _input(event: InputEvent) -> void:
	if handle_input(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _open and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		close()
		get_viewport().set_input_as_handled()


## Turns a touch into a left mouse press so the buttons react (see CraftingScreen.handle_input).
func handle_input(event: InputEvent) -> bool:
	if not _open or not event is InputEventScreenTouch:
		return false
	get_viewport().push_input(TouchBridge.to_mouse_button(event), true)
	return true


## `potion_catalog` is the potions on sale (the default catalog when it is null).
func open(profile: PlayerProfile, catalog: EquipmentCatalog, potion_catalog: PotionCatalog = null) -> void:
	if _open:
		return
	_profile = profile
	_catalog = catalog
	_potion_catalog = potion_catalog if potion_catalog != null else PotionCatalog.default_catalog()
	_message = ""
	_open = true
	_opened_at_msec = Time.get_ticks_msec()
	visible = true
	_fill()
	_refresh()
	_first_button().grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func is_open() -> bool:
	return _open


func item_button_count() -> int:
	return _buttons.size()


func potion_button_count() -> int:
	return _potion_buttons.size()


func potion_button_text(id: StringName) -> String:
	return (_potion_buttons[id] as Button).text


## The theme variation of an item's button: yellow for the worn one, the plain cream button otherwise.
func item_button_variation(id: StringName) -> StringName:
	return (_buttons[id] as Button).theme_type_variation


func gold_text() -> String:
	return "Gold %d" % (_profile.gold if _profile != null else 0)


func message_text() -> String:
	return _message


func button_text(id: StringName) -> String:
	return (_buttons[id] as Button).text


## What pressing an item does: buy it, put it on, or take it off.
func activate(id: StringName) -> void:
	var item := _catalog.find(id)
	if item == null:
		return
	if not _profile.owns(id):
		buy(id)
	elif _profile.equipped_id(int(item.slot())) == id:
		unequip(int(item.slot()))
	else:
		equip(id)


func buy(id: StringName) -> void:
	var result := ShopSystem.buy(_profile, _catalog, id)
	_finish(result.ok, result.reason, "Bought and equipped %s." % (result.item.display_name if result.item != null else ""))


func equip(id: StringName) -> void:
	var result := ShopSystem.equip(_profile, _catalog, id)
	_finish(result.ok, result.reason, "Equipped %s." % (result.item.display_name if result.item != null else ""))


func unequip(slot: int) -> void:
	var worn := _catalog.find(_profile.equipped_id(slot))
	if ShopSystem.unequip(_profile, slot):
		_finish(true, "", "Took off %s." % (worn.display_name if worn != null else "it"))


## Buys one potion (it is not drunk: the stock is carried into the run).
func buy_potion(id: StringName) -> void:
	var result := ShopSystem.buy_potion(_profile, _potion_catalog, id)
	_finish(result.ok, result.reason, "Bought %s." % (result.potion.display_name if result.potion != null else ""))


func _finish(ok: bool, reason: String, success_message: String) -> void:
	_message = success_message if ok else reason
	_refresh()
	if ok:
		changed.emit()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var content := UiKit.window(root)
	content.add_child(_label("Shop", Vector2(8, 3), Vector2(100, 12), &"Heading"))
	var coin := UiKit.icon(&"icon_coin")
	coin.position = Vector2(366, 2)
	content.add_child(coin)
	_gold_label = _label("", Vector2(380, 3), Vector2(92, 12))
	content.add_child(_gold_label)
	for i in SLOT_NAMES.size():
		content.add_child(_label(SLOT_NAMES[i], Vector2(COLUMN_X[i], 18), Vector2(152, 12), &"Heading"))
		var column := VBoxContainer.new()
		column.name = "Column%d" % i
		column.position = Vector2(COLUMN_X[i], 30)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 1)
		content.add_child(column)
	content.add_child(_label("Potions", Vector2(8, 127), Vector2(152, 10), &"Heading"))
	var grid := GridContainer.new()
	grid.name = "PotionGrid"
	grid.columns = 3
	grid.position = Vector2(8, 138)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 1)
	content.add_child(grid)
	_detail_label = _label("", Vector2(8, 174), Vector2(464, 30))
	content.add_child(_detail_label)
	_message_label = _label("", Vector2(8, 208), Vector2(464, 24))
	content.add_child(_message_label)
	_close_button = _button("Close", Vector2(402, 244), Vector2(70, 18), &"ButtonGreen")
	_close_button.pressed.connect(close)
	content.add_child(_close_button)


## One button per catalog item, in its slot's column. Built once per open.
func _fill() -> void:
	_buttons.clear()
	for i in SLOT_NAMES.size():
		var column := find_child("Column%d" % i, true, false) as VBoxContainer
		for child in column.get_children():
			column.remove_child(child)
			child.queue_free()
		for item in _catalog.items_for_slot(i as EquipmentData.Slot):
			var button := _button("", Vector2.ZERO, BUTTON_SIZE)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(_on_item_pressed.bind(item.id))
			button.focus_entered.connect(_show_detail.bind(item))
			button.mouse_entered.connect(_show_detail.bind(item))
			column.add_child(button)
			_buttons[item.id] = button
	_potion_buttons.clear()
	var grid := find_child("PotionGrid", true, false) as GridContainer
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for potion in _potion_catalog.potions:
		var button := _button("", Vector2.ZERO, BUTTON_SIZE, &"ButtonRed")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_potion_pressed.bind(potion.id))
		button.focus_entered.connect(_show_potion_detail.bind(potion))
		button.mouse_entered.connect(_show_potion_detail.bind(potion))
		grid.add_child(button)
		_potion_buttons[potion.id] = button


func _refresh() -> void:
	for id in _buttons:
		var item := _catalog.find(id)
		var button := _buttons[id] as Button
		var worn: bool = _profile.equipped_id(int(item.slot())) == id
		button.theme_type_variation = &"ButtonYellow" if worn else &""
		if worn:
			button.text = "%s (equipped)" % item.display_name
		elif _profile.owns(id):
			button.text = "%s (owned)" % item.display_name
		else:
			button.text = "%s  %dg" % [item.display_name, item.price]
	for id in _potion_buttons:
		var potion := _potion_catalog.find(id)
		(_potion_buttons[id] as Button).text = "%s %dg x%d" % [potion.display_name.trim_suffix(" Potion"), potion.price, _profile.potion_count(id)]
	_gold_label.text = gold_text()
	_message_label.text = _message


func _on_item_pressed(id: StringName) -> void:
	if Time.get_ticks_msec() - _opened_at_msec < input_guard_msec:
		return
	_show_detail(_catalog.find(id))
	activate(id)


func _on_potion_pressed(id: StringName) -> void:
	if Time.get_ticks_msec() - _opened_at_msec < input_guard_msec:
		return
	_show_potion_detail(_potion_catalog.find(id))
	buy_potion(id)


func _show_potion_detail(potion: PotionData) -> void:
	_detail_label.text = "%s  (%d Gold)\n%s" % [potion.display_name, potion.price, potion.description]


func _show_detail(item: EquipmentData) -> void:
	_detail_label.text = "%s  (%d Gold)\n%s" % [item.display_name, item.price, item.description]


func _first_button() -> Button:
	for id in _buttons:
		return _buttons[id] as Button
	return _close_button


func _label(text: String, at: Vector2, minimum: Vector2, variation: StringName = &"") -> Label:
	var label := UiKit.label(text, variation)
	label.position = at
	label.custom_minimum_size = minimum
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, at: Vector2, minimum: Vector2, variation: StringName = &"") -> Button:
	var button := UiKit.button(text, variation)
	button.position = at
	button.custom_minimum_size = minimum
	return button
