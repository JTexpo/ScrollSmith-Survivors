extends GutTest

var _button: PauseButton


func before_each() -> void:
	_button = (load("res://scenes/ui/pause_button.tscn") as PackedScene).instantiate() as PauseButton
	add_child_autofree(_button)
	_button.position = Vector2(100, 50)


func _click(position: Vector2, pressed: bool = true, button_index: int = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = position
	return event


func test_it_is_at_least_32_by_32() -> void:
	assert_gte(PauseButton.SIZE.x, 32.0)
	assert_gte(PauseButton.SIZE.y, 32.0)


func test_a_touch_and_a_left_click_inside_emit_pressed_once_each() -> void:
	watch_signals(_button)
	assert_true(_button.handle_touch(Vector2(110, 60)))
	assert_true(_button.handle_mouse_click(_click(Vector2(110, 60))))
	assert_signal_emit_count(_button, "pressed", 2)


func test_outside_presses_and_other_buttons_are_ignored() -> void:
	watch_signals(_button)
	assert_false(_button.handle_touch(Vector2(5, 5)))
	assert_false(_button.handle_mouse_click(_click(Vector2(110, 60), true, MOUSE_BUTTON_RIGHT)))
	assert_false(_button.handle_mouse_click(_click(Vector2(110, 60), false)))
	assert_signal_not_emitted(_button, "pressed")


func test_a_hidden_button_ignores_touches() -> void:
	_button.hide()
	assert_false(_button.handle_touch(Vector2(110, 60)))
	assert_false(_button.handle_mouse_click(_click(Vector2(110, 60))))


func test_the_face_takes_no_input() -> void:
	assert_eq(_button.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq((_button.get_node("Face") as Button).mouse_filter, Control.MOUSE_FILTER_IGNORE)
