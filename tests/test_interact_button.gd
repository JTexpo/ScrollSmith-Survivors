extends GutTest

const TouchHelpers := preload("res://tests/helpers/touch_helpers.gd")

var _button: InteractButton


func before_each() -> void:
	_button = load("res://scenes/ui/interact_button.tscn").instantiate() as InteractButton
	add_child_autofree(_button)
	_button.position = Vector2(100, 50)


func test_stays_hidden_without_a_touchscreen_unless_told_otherwise() -> void:
	_button.set_available(true)
	assert_false(_button.visible, "desktop test runs have no touchscreen")
	_button.require_touchscreen = false
	_button.set_available(true)
	assert_true(_button.visible)
	_button.set_available(false)
	assert_false(_button.visible)


func test_touch_inside_emits_pressed() -> void:
	_button.require_touchscreen = false
	_button.set_available(true)
	watch_signals(_button)
	_button._input(TouchHelpers.press_at(_button.get_global_rect().get_center()))
	assert_signal_emit_count(_button, "pressed", 1)


func test_touch_outside_and_hidden_do_nothing() -> void:
	_button.require_touchscreen = false
	_button.set_available(true)
	watch_signals(_button)
	_button._input(TouchHelpers.press_at(Vector2(0, 0)))
	_button.set_available(false)
	_button._input(TouchHelpers.press_at(_button.get_global_rect().get_center()))
	assert_signal_not_emitted(_button, "pressed")


func test_mouse_clicks_are_ignored() -> void:
	_button.require_touchscreen = false
	_button.set_available(true)
	watch_signals(_button)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = _button.get_global_rect().get_center()
	_button._input(click)
	assert_signal_not_emitted(_button, "pressed")


func test_the_touch_button_is_a_themed_yellow_button_that_takes_no_input() -> void:
	var themed := _button.get_node("Face") as Button
	assert_eq(themed.theme_type_variation, &"ButtonYellow")
	assert_eq(themed.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(themed.focus_mode, Control.FOCUS_NONE)
	assert_eq(themed.text, "Use")
