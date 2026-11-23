class_name MerchantScreen
extends CanvasLayer
## TEMPORARY look (Sprint 12d): a merchant's potion stall, opened from a Merchant point of interest. One button
## per potion shows its price (the merchant's multiplier already applied), what the merchant has left and how many
## you own. It is a thin layer over ShopSystem and the merchant's MerchantStock and holds no rules. A purchase is
## all or nothing: Gold, the potion count and the stock change together or not at all. It pauses the world while
## open, like the crafting screen, and works with mouse, keyboard or controller focus, and touch (bridged,
## because mouse emulation is off).

signal changed
signal closed

const FONT_SIZE := 8
const BUTTON_SIZE := Vector2(152, 15)
const GRID_POSITION := Vector2(8, 40)

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


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.08, 1.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	_title_label = _label("Merchant", Vector2(8, 3), Vector2(200, 12))
	root.add_child(_title_label)
	root.add_child(_label("Potions", Vector2(8, 28), Vector2(152, 10)))
	_gold_label = _label("", Vector2(380, 3), Vector2(92, 12))
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.1))
	root.add_child(_gold_label)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.position = GRID_POSITION
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 1)
	root.add_child(_grid)
	_detail_label = _label("", Vector2(8, 100), Vector2(464, 30))
	root.add_child(_detail_label)
	_message_label = _label("", Vector2(8, 208), Vector2(464, 24))
	root.add_child(_message_label)
	_close_button = _button("Close", Vector2(402, 244), Vector2(70, 18))
	_close_button.pressed.connect(close)
	root.add_child(_close_button)


## One button per potion. Built once per open.
func _fill() -> void:
	_buttons.clear()
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for potion in _catalog.potions:
		var button := _button("", Vector2.ZERO, BUTTON_SIZE)
		button.clip_text = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(press.bind(potion.id))
		button.focus_entered.connect(_show_detail.bind(potion))
		button.mouse_entered.connect(_show_detail.bind(potion))
		_grid.add_child(button)
		_buttons[potion.id] = button


func _refresh() -> void:
	for id in _buttons:
		var potion := _catalog.find(id)
		var name := potion.display_name.trim_suffix(" Potion")
		var left := _merchant.stock.count(id)
		var button := _buttons[id] as Button
		if left <= 0:
			button.text = "%s  sold out  own %d" % [name, _profile.potion_count(id)]
		else:
			button.text = "%s  %dg  x%d  own %d" % [name, ShopSystem.potion_price(potion, _merchant.data.price_multiplier), left, _profile.potion_count(id)]
	_gold_label.text = gold_text()
	_message_label.text = _message


func _show_detail(potion: PotionData) -> void:
	_detail_label.text = "%s  (%d Gold)\n%s" % [potion.display_name, ShopSystem.potion_price(potion, _merchant.data.price_multiplier), potion.description]


func _first_button() -> Button:
	for id in _buttons:
		return _buttons[id] as Button
	return _close_button


func _label(text: String, at: Vector2, minimum: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.custom_minimum_size = minimum
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	return label


func _button(text: String, at: Vector2, minimum: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.custom_minimum_size = minimum
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.add_theme_stylebox_override("normal", _style(Color(0.14, 0.13, 0.2)))
	button.add_theme_stylebox_override("hover", _style(Color(0.22, 0.2, 0.32)))
	button.add_theme_stylebox_override("pressed", _style(Color(0.3, 0.28, 0.42)))
	button.add_theme_stylebox_override("focus", _style(Color(0.14, 0.13, 0.2), Color.WHITE))
	return button


func _style(fill: Color, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_content_margin_all(2)
	return style
