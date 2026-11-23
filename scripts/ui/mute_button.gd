class_name MuteButton
extends Control
## A small speaker button on the HUD that mutes and unmutes all sound. It shows a speaker with waves, or with red crosses while
## muted. Like the other HUD buttons it handles touches itself (mouse emulation is off); like the potion slots it also takes a
## left mouse click, so a desktop player can click it (Main blocks casting until the click is released).

signal pressed

const SIZE := Vector2(32, 32)

var _face: Button
var _muted: bool = false


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
	pressed.emit()
	return true


## A left mouse press on the button. Other buttons, releases and clicks elsewhere are ignored.
func handle_mouse_click(event: InputEventMouseButton) -> bool:
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return false
	return handle_touch(event.position)


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
