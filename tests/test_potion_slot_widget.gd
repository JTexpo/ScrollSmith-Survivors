extends GutTest

var _widget: PotionSlotWidget
var _potion: PotionData


func before_each() -> void:
	_potion = PotionCatalog.default_catalog().find(&"potion_speed")
	_widget = PotionSlotWidget.new()
	add_child_autofree(_widget)
	_widget.setup(2, _potion, "C")


func _touch(position: Vector2) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	event.position = position
	return event


func test_setup_shows_the_key_and_colour() -> void:
	assert_eq(_widget.slot_index, 2)
	assert_eq(_widget.key_text, "C")
	assert_eq(_widget.swatch_color, _potion.color)


func test_count_zero_dims_the_slot() -> void:
	_widget.set_count(3)
	assert_eq(_widget.count, 3)
	assert_false(_widget.dimmed)
	assert_eq(_widget.count_text(), "3")
	_widget.set_count(0)
	assert_true(_widget.dimmed)
	assert_eq(_widget.count_text(), "0")


func test_cooldown_overlay_follows_the_ratio() -> void:
	_widget.set_cooldown(0.5)
	assert_almost_eq(_widget.cooldown, 0.5, 0.0001)
	assert_almost_eq(_widget.cooldown_overlay_height(), PotionSlotWidget.SWATCH_SIZE.y * 0.5, 0.0001)
	_widget.set_cooldown(0.0)
	assert_eq(_widget.cooldown_overlay_height(), 0.0)
	_widget.set_cooldown(7.0)
	assert_eq(_widget.cooldown, 1.0, "the ratio is clamped")


func test_effect_bar_shows_only_while_running() -> void:
	assert_false(_widget.effect_bar_visible())
	_widget.set_effect(0.75)
	assert_true(_widget.effect_bar_visible())
	assert_almost_eq(_widget.effect_bar_width(), (PotionSlotWidget.SIZE.x - 2.0) * 0.75, 0.0001)
	_widget.set_effect(0.0)
	assert_false(_widget.effect_bar_visible())


func test_selection_highlight() -> void:
	assert_false(_widget.selected)
	_widget.set_selected(true)
	assert_true(_widget.selected)
	assert_true(_widget.highlight_visible())


func test_a_touch_on_the_widget_emits_pressed_and_is_handled() -> void:
	watch_signals(_widget)
	var inside := _widget.get_global_rect().get_center()
	assert_true(_widget.handle_touch(inside))
	assert_signal_emitted_with_parameters(_widget, "pressed", [2])


func test_a_touch_elsewhere_is_ignored() -> void:
	watch_signals(_widget)
	var outside := _widget.get_global_rect().end + Vector2(40, 40)
	assert_false(_widget.handle_touch(outside))
	assert_signal_not_emitted(_widget, "pressed")


func test_a_touch_while_the_widget_is_hidden_is_ignored() -> void:
	watch_signals(_widget)
	_widget.hide()
	assert_false(_widget.handle_touch(_widget.get_global_rect().get_center()))
	assert_signal_not_emitted(_widget, "pressed")


func test_ignores_the_mouse() -> void:
	assert_eq(_widget.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for child in _widget.find_children("*", "Control", true, false):
		assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, str(child.name))


func _click(position: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT, pressed: bool = true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = position
	return event


func test_a_left_click_on_the_widget_emits_pressed() -> void:
	watch_signals(_widget)
	assert_true(_widget.handle_mouse_click(_click(_widget.get_global_rect().get_center())))
	assert_signal_emitted_with_parameters(_widget, "pressed", [2])


func test_a_right_click_a_release_and_a_click_elsewhere_are_ignored() -> void:
	watch_signals(_widget)
	var inside := _widget.get_global_rect().get_center()
	assert_false(_widget.handle_mouse_click(_click(inside, MOUSE_BUTTON_RIGHT)))
	assert_false(_widget.handle_mouse_click(_click(inside, MOUSE_BUTTON_LEFT, false)))
	assert_false(_widget.handle_mouse_click(_click(_widget.get_global_rect().end + Vector2(40, 40))))
	assert_signal_not_emitted(_widget, "pressed")


func test_a_click_while_hidden_is_ignored() -> void:
	watch_signals(_widget)
	_widget.hide()
	assert_false(_widget.handle_mouse_click(_click(_widget.get_global_rect().get_center())))
	assert_signal_not_emitted(_widget, "pressed")
