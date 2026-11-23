class_name InteractButton
extends Control
## An on-screen "use" button for touch screens. It appears only while the
## player is next to something to interact with. Handles touches itself (mouse emulation is off)
## and ignores mouse clicks, like the other touch widgets.

signal pressed

const SIZE := Vector2(64, 30)

## Desktop players press E, so the button normally only shows on a touchscreen.
@export var require_touchscreen: bool = true

var _label: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	size = SIZE
	_label = _face("Use", &"ButtonYellow", SIZE)
	visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if handle_touch(event.position):
			get_viewport().set_input_as_handled()


func handle_touch(screen_position: Vector2) -> bool:
	if not is_visible_in_tree() or not get_global_rect().has_point(screen_position):
		return false
	pressed.emit()
	return true


## The themed button face: it only draws, since the widget handles the touch itself.
func _face(text: String, variation: StringName, face_size: Vector2) -> Button:
	var face := UiKit.button(text, variation)
	face.name = "Face"
	face.focus_mode = Control.FOCUS_NONE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size = face_size
	add_child(face)
	return face


func set_available(available: bool) -> void:
	visible = available and (not require_touchscreen or TouchJoystick.should_show())
