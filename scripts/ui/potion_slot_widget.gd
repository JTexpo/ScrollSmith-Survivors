class_name PotionSlotWidget
extends Control
## One slot in the potion bar: a cream frame (yellow ring when selected). Shows the potion's colour, how many
## are left, the key that drinks it, a cooldown overlay and, while a timed effect runs, a shrinking
## timer bar. A tap on a touchscreen or a left click drinks it (Main also blocks casting until the cast
## input is released, so a click here never fires a spell). Build children in _ready, so add it to the
## tree before calling setup().

signal pressed(index: int)

const SIZE := Vector2(24, 16)
## The frame's outline, so everything inside sits 2 px from the edge.
const FRAME := 2.0
const SWATCH_SIZE := Vector2(20, 8)
const EFFECT_COLOR := Color("ffd24a")

var slot_index: int = 0
var key_text: String = ""
var swatch_color: Color = Color.WHITE
var count: int = 0
var dimmed: bool = true
var cooldown: float = 0.0
var effect: float = 0.0
var selected: bool = false

var _frame: Panel
var _swatch: ColorRect
var _cooldown_overlay: ColorRect
var _effect_bar: ColorRect
var _count_label: Label
var _key_label: Label


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = Panel.new()
	_frame.size = SIZE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_swatch = _add_rect(Vector2(FRAME, FRAME), SWATCH_SIZE, Color.WHITE)
	_cooldown_overlay = _add_rect(Vector2(FRAME, FRAME), Vector2(SWATCH_SIZE.x, 0.0), Color(0, 0, 0, 0.65))
	_effect_bar = _add_rect(Vector2(FRAME, SIZE.y - FRAME - 2.0), Vector2(effect_bar_full_width(), 2), EFFECT_COLOR)
	_count_label = _label(Vector2(11, 3))
	_key_label = _label(Vector2(FRAME + 1.0, 0.0))
	_refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if handle_touch(event.position):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if handle_mouse_click(event):
			get_viewport().set_input_as_handled()


func handle_touch(screen_position: Vector2) -> bool:
	if not is_visible_in_tree() or not get_global_rect().has_point(screen_position):
		return false
	pressed.emit(slot_index)
	return true


## A left mouse press on the slot. Other buttons, releases and clicks elsewhere are ignored.
func handle_mouse_click(event: InputEventMouseButton) -> bool:
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return false
	return handle_touch(event.position)


func setup(index: int, potion: PotionData, key: String) -> void:
	slot_index = index
	key_text = key
	swatch_color = potion.color
	_refresh()


func set_count(value: int) -> void:
	count = value
	dimmed = value <= 0
	_refresh()


## 1 just drunk, 0 ready.
func set_cooldown(ratio: float) -> void:
	cooldown = clampf(ratio, 0.0, 1.0)
	_refresh()


## 1 just started, 0 not running.
func set_effect(ratio: float) -> void:
	effect = clampf(ratio, 0.0, 1.0)
	_refresh()


func set_selected(value: bool) -> void:
	selected = value
	_refresh()


func count_text() -> String:
	return str(count)


func cooldown_overlay_height() -> float:
	return _cooldown_overlay.size.y


func effect_bar_visible() -> bool:
	return _effect_bar.visible


func effect_bar_width() -> float:
	return _effect_bar.size.x


func highlight_visible() -> bool:
	return frame_variation() == &"PanelSlotSelected"


## The theme variation the frame uses now: the selected frame has a yellow ring.
func frame_variation() -> StringName:
	return _frame.theme_type_variation


func text_variation() -> StringName:
	return _count_label.theme_type_variation


## The effect timer's width when a timed effect has just started.
static func effect_bar_full_width() -> float:
	return SIZE.x - 2.0 * FRAME


func _refresh() -> void:
	if _frame == null:
		return
	_frame.theme_type_variation = &"PanelSlotSelected" if selected else &"PanelSlot"
	modulate.a = 0.35 if dimmed else 1.0
	_swatch.color = swatch_color
	_cooldown_overlay.size.y = SWATCH_SIZE.y * cooldown
	_effect_bar.visible = effect > 0.0
	_effect_bar.size.x = effect_bar_full_width() * effect
	_count_label.text = count_text()
	_key_label.text = key_text


func _label(at: Vector2) -> Label:
	var label := UiKit.label("", &"HudLabel")
	label.position = at
	add_child(label)
	return label


func _add_rect(rect_position: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = rect_position
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect
