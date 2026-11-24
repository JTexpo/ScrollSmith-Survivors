class_name MuteButton
extends Control
## A small speaker button on the HUD that mutes and unmutes all sound. It shows a speaker with waves, or with red crosses while
## muted. Like the other HUD buttons it handles touches itself (mouse emulation is off); like the potion slots it also takes a
## left mouse click, so a desktop player can click it (Main blocks casting from the moment the press lands until it is released).

## A tap: the press was inside and let go inside in under HOLD_SECONDS.
signal pressed
## A press held for HOLD_SECONDS (a tester's long press; Main uses it to open the performance overlay). The release after it does nothing.
signal long_pressed
## A press landed on the button and a hold began. Main blocks casting from here until the cast input is released, because the click that
## began the hold is still down (it only becomes a tap or a long press later).
signal hold_started

const SIZE := Vector2(32, 32)
const HOLD_SECONDS := 1.0
## The index a mouse press is tracked under (touches use their own finger index).
const MOUSE_INDEX := -1

## Milliseconds now; tests replace it so time can be driven by hand.
var clock: Callable = func() -> int: return Time.get_ticks_msec()

var _face: Button
var _muted: bool = false
var _holding: bool = false
var _held_since: int = 0
var _hold_index: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	size = SIZE
	_face = UiKit.button("")
	_face.name = "Face"
	_face.focus_mode = Control.FOCUS_NONE
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_face.expand_icon = false
	_face.size = SIZE
	add_child(_face)
	_refresh()
	set_process(false)


func _process(_delta: float) -> void:
	check_hold()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if handle_touch(event.position, event.index):
				get_viewport().set_input_as_handled()
		elif handle_release(event.position, event.index):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.pressed:
			if handle_mouse_click(event):
				get_viewport().set_input_as_handled()
		elif handle_mouse_release(event):
			get_viewport().set_input_as_handled()


## A press inside the button starts the hold (nothing fires yet: a tap fires on release, a long press after HOLD_SECONDS).
## `index` is the finger (or MOUSE_INDEX); only that finger's release ends the hold.
func handle_touch(screen_position: Vector2, index: int = 0) -> bool:
	if not is_visible_in_tree() or not get_global_rect().has_point(screen_position):
		return false
	if not _holding:
		_holding = true
		_hold_index = index
		_held_since = clock.call()
		set_process(true)
		hold_started.emit()
	return true


## A left mouse press on the button. Other buttons, releases and clicks elsewhere are ignored.
func handle_mouse_click(event: InputEventMouseButton) -> bool:
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return false
	return handle_touch(event.position, MOUSE_INDEX)


## The release that ends a hold. It is a tap (`pressed`) when it lands inside the button before HOLD_SECONDS, and does nothing after
## a long press or when it lands outside. True when a hold was ended.
func handle_release(screen_position: Vector2, index: int = 0) -> bool:
	if not _holding or index != _hold_index:
		return false
	_holding = false
	set_process(false)
	var held_msec: int = int(clock.call()) - _held_since
	if get_global_rect().has_point(screen_position) and held_msec < int(HOLD_SECONDS * 1000.0):
		pressed.emit()
	return true


func handle_mouse_release(event: InputEventMouseButton) -> bool:
	if event.button_index != MOUSE_BUTTON_LEFT or event.pressed:
		return false
	return handle_release(event.position, MOUSE_INDEX)


## Emits `long_pressed` once when a press has been held long enough, and ends the hold (the release then does nothing).
func check_hold() -> void:
	if not _holding:
		return
	if int(clock.call()) - _held_since >= int(HOLD_SECONDS * 1000.0):
		_holding = false
		set_process(false)
		long_pressed.emit()


func set_muted(value: bool) -> void:
	_muted = value
	_refresh()


func is_muted() -> bool:
	return _muted


func _refresh() -> void:
	if _face == null:
		return
	var set_data := SpriteLibrary.find(&"icon_muted" if _muted else &"icon_sound")
	_face.icon = set_data.sheet if set_data != null else null
