class_name PotionSlotWidget
extends Control
## TEMPORARY (Sprint 10): one slot in the placeholder potion bar. Shows the potion's colour, how many
## are left, the key that drinks it, a cooldown overlay and, while a timed effect runs, a shrinking
## timer bar. A tap on a touchscreen drinks it (mouse clicks are ignored on purpose, so clicking here
## never casts). Build children in _ready, so add it to the tree before calling setup().

signal pressed(index: int)

const SIZE := Vector2(24, 16)
const SWATCH_SIZE := Vector2(22, 9)

var slot_index: int = 0
var key_text: String = ""
var swatch_color: Color = Color.WHITE
var count: int = 0
var dimmed: bool = true
var cooldown: float = 0.0
var effect: float = 0.0
var selected: bool = false

var _highlight: ColorRect
var _background: ColorRect
var _swatch: ColorRect
var _cooldown_overlay: ColorRect
var _effect_bar: ColorRect
var _count_label: Label
var _key_label: Label


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight = _add_rect(Vector2(-1, -1), SIZE + Vector2(2, 2), Color.WHITE)
	_background = _add_rect(Vector2.ZERO, SIZE, Color(0.1, 0.1, 0.12, 0.85))
	_swatch = _add_rect(Vector2(1, 1), SWATCH_SIZE, Color.WHITE)
	_cooldown_overlay = _add_rect(Vector2(1, 1), Vector2(SWATCH_SIZE.x, 0.0), Color(0, 0, 0, 0.65))
	_effect_bar = _add_rect(Vector2(1, SIZE.y - 5), Vector2(SIZE.x - 2.0, 2), Color(1.0, 1.0, 0.5))
	_count_label = _label(Vector2(10, 4))
	_key_label = _label(Vector2(1, -1))
	_refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if handle_touch(event.position):
			get_viewport().set_input_as_handled()


func handle_touch(screen_position: Vector2) -> bool:
	if not is_visible_in_tree() or not get_global_rect().has_point(screen_position):
		return false
	pressed.emit(slot_index)
	return true


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
	return _highlight.visible


func _refresh() -> void:
	if _background == null:
		return
	_highlight.visible = selected
	modulate.a = 0.35 if dimmed else 1.0
	_swatch.color = swatch_color
	_cooldown_overlay.size.y = SWATCH_SIZE.y * cooldown
	_effect_bar.visible = effect > 0.0
	_effect_bar.size.x = (SIZE.x - 2.0) * effect
	_count_label.text = count_text()
	_key_label.text = key_text


func _label(at: Vector2) -> Label:
	var label := Label.new()
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 8)
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
