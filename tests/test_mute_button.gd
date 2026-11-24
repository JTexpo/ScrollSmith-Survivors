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


var _now: int = 0


func before_each() -> void:
	_now = 0
	_button = load("res://scenes/ui/mute_button.tscn").instantiate() as MuteButton
	_button.clock = func() -> int: return _now
	add_child_autofree(_button)
	_button.position = Vector2(100, 50)


func _release(screen_position: Vector2) -> void:
	_button.handle_release(screen_position)


func test_the_button_is_at_least_32_by_32() -> void:
	assert_gte(MuteButton.SIZE.x, 32.0)
	assert_gte(MuteButton.SIZE.y, 32.0)


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
	assert_false(_button.is_processing())


func test_a_press_inside_is_handled_but_alone_emits_nothing() -> void:
	watch_signals(_button)
	assert_true(_button.handle_touch(Vector2(110, 60)))
	assert_false(_button.handle_touch(Vector2(10, 10)), "a press outside is not ours")
	assert_signal_not_emitted(_button, "pressed")
	assert_signal_not_emitted(_button, "long_pressed")


func test_a_tap_emits_pressed_on_release() -> void:
	watch_signals(_button)
	_button.handle_touch(Vector2(110, 60))
	_now = 200
	_release(Vector2(110, 60))
	assert_signal_emit_count(_button, "pressed", 1)
	assert_signal_not_emitted(_button, "long_pressed")


func test_a_left_click_press_then_release_emits_pressed_and_other_clicks_do_not() -> void:
	watch_signals(_button)
	assert_true(_button.handle_mouse_click(_click(Vector2(110, 60))))
	assert_false(_button.handle_mouse_click(_click(Vector2(110, 60), MOUSE_BUTTON_RIGHT)))
	assert_false(_button.handle_mouse_click(_click(Vector2(1, 1))))
	var release := _click(Vector2(110, 60))
	release.pressed = false
	assert_true(_button.handle_mouse_release(release))
	assert_signal_emit_count(_button, "pressed", 1)


func test_a_press_held_for_a_second_emits_long_pressed_and_not_pressed() -> void:
	watch_signals(_button)
	_button.handle_touch(Vector2(110, 60))
	_now = 900
	_button.check_hold()
	assert_signal_not_emitted(_button, "long_pressed", "not yet")
	_now = 1000
	_button.check_hold()
	assert_signal_emit_count(_button, "long_pressed", 1)
	_now = 1500
	_button.check_hold()
	assert_signal_emit_count(_button, "long_pressed", 1, "only once")
	_release(Vector2(110, 60))
	assert_signal_not_emitted(_button, "pressed", "the release after a long press mutes nothing")


func test_a_release_outside_the_button_cancels_the_press() -> void:
	watch_signals(_button)
	_button.handle_touch(Vector2(110, 60))
	_now = 200
	_release(Vector2(400, 400))
	assert_signal_not_emitted(_button, "pressed")
	_now = 5000
	_button.check_hold()
	assert_signal_not_emitted(_button, "long_pressed", "the hold ended with the release")


func test_a_second_press_while_holding_does_not_double_fire() -> void:
	watch_signals(_button)
	_button.handle_touch(Vector2(110, 60))
	_button.handle_touch(Vector2(112, 62))
	_now = 100
	_release(Vector2(110, 60))
	assert_signal_emit_count(_button, "pressed", 1)


func test_a_short_press_then_a_hold_each_act_once() -> void:
	watch_signals(_button)
	_button.handle_touch(Vector2(110, 60))
	_now = 100
	_release(Vector2(110, 60))
	_button.handle_touch(Vector2(110, 60))
	_now = 1200
	_button.check_hold()
	_release(Vector2(110, 60))
	assert_signal_emit_count(_button, "pressed", 1)
	assert_signal_emit_count(_button, "long_pressed", 1)


func test_it_only_processes_while_a_press_is_held() -> void:
	assert_false(_button.is_processing())
	_button.handle_touch(Vector2(110, 60))
	assert_true(_button.is_processing())
	_release(Vector2(110, 60))
	assert_false(_button.is_processing())


func test_a_press_inside_announces_that_a_hold_started() -> void:
	watch_signals(_button)
	_button.handle_touch(Vector2(110, 60))
	assert_signal_emit_count(_button, "hold_started", 1)
	_button.handle_touch(Vector2(112, 62))
	assert_signal_emit_count(_button, "hold_started", 1, "a second press while holding is not a new hold")


func test_another_fingers_release_is_ignored_and_not_swallowed() -> void:
	watch_signals(_button)
	_button.handle_touch(Vector2(110, 60), 0)
	assert_false(_button.handle_release(Vector2(110, 60), 1), "finger 1 never pressed the button")
	assert_signal_not_emitted(_button, "pressed")
	_now = 200
	assert_true(_button.handle_release(Vector2(110, 60), 0))
	assert_signal_emit_count(_button, "pressed", 1)


func test_a_mouse_release_does_not_end_a_touch_hold() -> void:
	watch_signals(_button)
	_button.handle_touch(Vector2(110, 60), 0)
	var release := _click(Vector2(110, 60))
	release.pressed = false
	assert_false(_button.handle_mouse_release(release))
	assert_signal_not_emitted(_button, "pressed")
