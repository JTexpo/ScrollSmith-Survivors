class_name SpellSlotWidget
extends Control
## One slot in the spell bar: a cream frame (yellow ring when selected), the spell's colour, its slot number and a mana
## fill. Taps on a touchscreen select it. Mouse clicks are ignored on purpose, so clicking here never casts. Build children
## in _ready, so add it to the tree before calling setup().

signal pressed(index: int)

const SIZE := Vector2(28, 18)
## The frame's outline, so everything inside sits 2 px from the edge.
const FRAME := 2.0
const SWATCH_HEIGHT := 9.0
const FILL_HEIGHT := 3.0
const FLASH_TIME := 0.25
const DEPLETED_TINT := Color(0.4, 0.4, 0.4, 1)
const MANA_COLOR := Color("6fd3ff")
const FLASH_COLOR := Color(0.88, 0.28, 0.24, 0.7)

var slot_index: int = 0
var empty: bool = true
var locked: bool = false
var element_color: Color = Color.WHITE
var ratio: float = 0.0
var depleted: bool = false
var selected: bool = false

var _flash_left: float = 0.0

var _frame: Panel
var _swatch: ColorRect
var _flash: ColorRect
var _fill: ColorRect
var _label: Label


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = Panel.new()
	_frame.size = SIZE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	var inner := SIZE.x - 2.0 * FRAME
	_swatch = _add_rect(Vector2(FRAME, FRAME), Vector2(inner, SWATCH_HEIGHT), Color.WHITE)
	_flash = _add_rect(Vector2(FRAME, FRAME), Vector2(inner, SIZE.y - 2.0 * FRAME), FLASH_COLOR)
	_fill = _add_rect(Vector2(FRAME, SIZE.y - FRAME - FILL_HEIGHT), Vector2(inner, FILL_HEIGHT), MANA_COLOR)
	_label = UiKit.label("", &"HudLabel")
	_label.position = Vector2(FRAME + 1.0, 0.0)
	add_child(_label)
	set_process(false)
	_refresh()


func _process(delta: float) -> void:
	_flash_left = maxf(_flash_left - delta, 0.0)
	if _flash_left <= 0.0:
		set_process(false)
	_refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if handle_touch(event.position):
			get_viewport().set_input_as_handled()


func handle_touch(screen_position: Vector2) -> bool:
	if locked or not is_visible_in_tree() or not get_global_rect().has_point(screen_position):
		return false
	pressed.emit(slot_index)
	return true


## A null spell means an empty slot.
func setup(index: int, spell: SpellData) -> void:
	slot_index = index
	empty = spell == null
	element_color = spell.color if spell != null else Color.WHITE
	ratio = 0.0 if spell == null else 1.0
	_label.text = str(index + 1)
	_refresh()


## A locked slot is dimmed, marked "x", and ignores taps.
func set_locked(value: bool) -> void:
	locked = value
	_refresh()


func set_mana(current: float, maximum: float) -> void:
	ratio = current / maximum if maximum > 0.0 else 0.0
	# The widget only knows ratios, so "depleted" means nothing is left at all.
	depleted = current <= 0.0
	_refresh()


func set_selected(value: bool) -> void:
	selected = value
	_refresh()


func flash_dry() -> void:
	_flash_left = FLASH_TIME
	set_process(true)
	_refresh()


func is_flashing() -> bool:
	return _flash_left > 0.0


## The theme variation the frame uses now: the selected frame has a yellow ring.
func frame_variation() -> StringName:
	return _frame.theme_type_variation


func number_variation() -> StringName:
	return _label.theme_type_variation


func mana_fill_width() -> float:
	return _fill.size.x


func _refresh() -> void:
	if _frame == null:
		return
	_frame.theme_type_variation = &"PanelSlotSelected" if selected else &"PanelSlot"
	modulate.a = 0.2 if locked else (0.35 if empty else 1.0)
	_label.text = "x" if locked else str(slot_index + 1)
	_swatch.color = DEPLETED_TINT if depleted else element_color
	_fill.size.x = (SIZE.x - 2.0 * FRAME) * ratio
	_flash.visible = is_flashing()


func _add_rect(rect_position: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = rect_position
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect
