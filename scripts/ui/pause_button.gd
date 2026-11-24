class_name PauseButton
extends Control
## A small HUD button that opens the pause menu (a phone has no Esc key). Like the mute and inventory buttons it handles touches itself
## (mouse emulation is off) and also takes a left mouse click. It fires on the press, so Main can block casting at once.

signal pressed

const SIZE := Vector2(32, 32)

var _face: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	size = SIZE
	_face = UiKit.button("II")
	_face.name = "Face"
	_face.focus_mode = Control.FOCUS_NONE
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.size = SIZE
	add_child(_face)


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


func handle_mouse_click(event: InputEventMouseButton) -> bool:
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return false
	return handle_touch(event.position)
