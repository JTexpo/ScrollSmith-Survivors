class_name MerchantScreen
extends CanvasLayer
## A merchant's potion stall, opened from a Merchant point of interest. One button
## per potion shows its price (the merchant's multiplier already applied), what the merchant has left and how many
## you own. It is a thin layer over ShopSystem and the merchant's MerchantStock and holds no rules. A purchase is
## all or nothing: Gold, the potion count and the stock change together or not at all. It pauses the world while
## open, like the crafting screen, and works with mouse, keyboard or controller focus, and touch (bridged,
## because mouse emulation is off).

signal changed
signal closed
## A purchase that failed (sold out, too little Gold, a full stack), with the reason shown.
signal refused(reason: String)

const BUTTON_SIZE := Vector2(152, 32)
const GRID_POSITION := Vector2(8, 40)
const DETAIL_TOP := 112.0

## Tests turn this off so the test runner itself is not paused.
@export var pause_tree: bool = true
## Button presses are ignored for this long after it opens, so the press that opened it cannot also buy.
var input_guard_msec: int = 300

var _open: bool = false
var _opened_at_msec: int = 0
var _profile: PlayerProfile
var _catalog: PotionCatalog
var _merchant: PointOfInterest
var _message: String = ""

var _buttons: Dictionary = {}
var _title_label: Label
var _gold_label: Label
var _detail_label: Label
var _message_label: Label
var _close_button: Button
var _grid: GridContainer


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


## `catalog` is the potions on sale (the default catalog when it is null). Pauses the world when `pause_tree`.
func open(profile: PlayerProfile, catalog: PotionCatalog, merchant: PointOfInterest) -> void:
	if _open:
		return
	_profile = profile
	_catalog = catalog if catalog != null else PotionCatalog.default_catalog()
	_merchant = merchant
	_message = ""
	_open = true
	_opened_at_msec = Time.get_ticks_msec()
	visible = true
	_title_label.text = merchant.data.display_name
	_fill()
	_refresh()
	if pause_tree:
		GamePause.set_paused(get_tree(), true)
	_first_button().grab_focus()


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


func potion_button_count() -> int:
	return _buttons.size()


func button_text(id: StringName) -> String:
	return (_buttons[id] as Button).text


## Where a button is on screen, for tests that touch it.
func potion_button_center(id: StringName) -> Vector2:
	return (_buttons[id] as Button).get_global_rect().get_center()


func gold_text() -> String:
	return "Gold %d" % (_profile.gold if _profile != null else 0)


func message_text() -> String:
	return _message


## What pressing a potion's button does after the guard: show it and try to buy it.
func press(id: StringName) -> void:
	if Time.get_ticks_msec() - _opened_at_msec < input_guard_msec:
		return
	_show_detail(_catalog.find(id))
	activate(id)


## Tries to buy one potion. Sold out, too little Gold and a full stack all refuse and change nothing.
func activate(id: StringName) -> void:
	var potion := _catalog.find(id)
	if potion == null or _merchant == null or _merchant.stock == null:
		return
	if _merchant.stock.count(id) <= 0:
		_message = "Sold out."
		_refresh()
		refused.emit(_message)
		return
	var result := ShopSystem.buy_potion(_profile, _catalog, id, _merchant.data.price_multiplier)
	if result.ok:
		_merchant.stock.take(id)
		_message = "Bought %s." % potion.display_name
	else:
		_message = result.reason
	_refresh()
	if result.ok:
		changed.emit()
	else:
		refused.emit(_message)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var content := UiKit.window(root)
	_title_label = _label("Merchant", Vector2(8, 3), Vector2(200, 12), &"Heading")
	content.add_child(_title_label)
	content.add_child(_label("Potions", Vector2(8, 28), Vector2(152, 10), &"Heading"))
	var coin := UiKit.icon(&"icon_coin")
	coin.position = Vector2(366, 2)
	content.add_child(coin)
	_gold_label = _label("", Vector2(380, 3), Vector2(92, 12))
	content.add_child(_gold_label)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.position = GRID_POSITION
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 1)
	content.add_child(_grid)
	_detail_label = _label("", Vector2(8, DETAIL_TOP), Vector2(464, 30))
	content.add_child(_detail_label)
	_message_label = _label("", Vector2(8, 208), Vector2(464, 24))
	content.add_child(_message_label)
	_close_button = _button("Close", Vector2(392, 236), UiKit.ACTION_SIZE, &"ButtonRed")
	_close_button.pressed.connect(close)
	content.add_child(_close_button)


## One button per potion. Built once per open.
func _fill() -> void:
	_buttons.clear()
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for potion in _catalog.potions:
		var button := _button("", Vector2.ZERO, BUTTON_SIZE, &"ButtonGreen")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(press.bind(potion.id))
		button.focus_entered.connect(_show_detail.bind(potion))
		button.mouse_entered.connect(_show_detail.bind(potion))
		_grid.add_child(button)
		_buttons[potion.id] = button


func _refresh() -> void:
	for id in _buttons:
		var potion := _catalog.find(id)
		var title := potion.display_name.trim_suffix(" Potion")
		var left := _merchant.stock.count(id)
		var button := _buttons[id] as Button
		if left <= 0:
			button.text = "%s\nsold out  own %d" % [title, _profile.potion_count(id)]
		else:
			button.text = "%s\n%dg  x%d  own %d" % [title, ShopSystem.potion_price(potion, _merchant.data.price_multiplier), left, _profile.potion_count(id)]
	_gold_label.text = gold_text()
	_message_label.text = _message


func _show_detail(potion: PotionData) -> void:
	_detail_label.text = "%s  (%d Gold)\n%s" % [potion.display_name, ShopSystem.potion_price(potion, _merchant.data.price_multiplier), potion.description]


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
