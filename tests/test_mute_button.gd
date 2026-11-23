extends GutTest

var _button: MuteButton


func _touch(screen_position: Vector2) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = screen_position
	return event


func _click(screen_position: Vector2, button_index: int = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = true
	event.position = screen_position
	return event


func before_each() -> void:
	_button = load("res://scenes/ui/mute_button.tscn").instantiate() as MuteButton
	add_child_autofree(_button)
	_button.position = Vector2(100, 50)


func test_the_button_is_at_least_32_by_32() -> void:
	assert_gte(MuteButton.SIZE.x, 32.0)
	assert_gte(MuteButton.SIZE.y, 32.0)


func test_a_touch_inside_emits_pressed_and_one_outside_does_not() -> void:
	watch_signals(_button)
	assert_true(_button.handle_touch(Vector2(110, 60)))
	assert_false(_button.handle_touch(Vector2(10, 10)))
	assert_signal_emit_count(_button, "pressed", 1)


func test_a_left_click_inside_acts_like_a_touch_and_other_clicks_do_not() -> void:
	watch_signals(_button)
	assert_true(_button.handle_mouse_click(_click(Vector2(110, 60))))
	assert_false(_button.handle_mouse_click(_click(Vector2(110, 60), MOUSE_BUTTON_RIGHT)))
	assert_false(_button.handle_mouse_click(_click(Vector2(1, 1))))
	var release := _click(Vector2(110, 60))
	release.pressed = false
	assert_false(_button.handle_mouse_click(release))
	assert_signal_emit_count(_button, "pressed", 1)


func test_the_face_takes_no_input_and_no_focus() -> void:
	var face := _button.get_node("Face") as Button
	assert_eq(face.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(face.focus_mode, Control.FOCUS_NONE)
	assert_eq(_button.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_set_muted_swaps_the_icon() -> void:
	var sound := (_button.get_node("Face") as Button).icon
	assert_eq(sound, SpriteLibrary.find(&"icon_sound").sheet)
	_button.set_muted(true)
	assert_eq((_button.get_node("Face") as Button).icon, SpriteLibrary.find(&"icon_muted").sheet)
	assert_true(_button.is_muted())
	_button.set_muted(false)
	assert_eq((_button.get_node("Face") as Button).icon, sound)


func test_a_hidden_button_ignores_touches_and_clicks() -> void:
	_button.hide()
	assert_false(_button.handle_touch(Vector2(110, 60)))
	assert_false(_button.handle_mouse_click(_click(Vector2(110, 60))))
