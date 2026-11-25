extends GutTest

const TouchHelpers := preload("res://tests/helpers/touch_helpers.gd")

var _screen: DeathScreen


func before_each() -> void:
	_screen = load("res://scenes/ui/death_screen.tscn").instantiate() as DeathScreen
	add_child_autofree(_screen)
	_screen.input_delay_msec = 0


func _restart_action() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"restart"
	event.pressed = true
	return event


func test_hidden_until_shown() -> void:
	assert_false(_screen.visible)
	_screen.show_death()
	assert_true(_screen.visible)


func test_restart_ignored_while_hidden() -> void:
	watch_signals(_screen)
	_screen.handle_event(_restart_action())
	assert_signal_not_emitted(_screen, "restart_requested")


func test_restart_requested_on_action_and_on_touch_when_shown() -> void:
	watch_signals(_screen)
	_screen.show_death()
	_screen.handle_event(_restart_action())
	_screen.handle_event(TouchHelpers.press())
	assert_signal_emit_count(_screen, "restart_requested", 2)


func test_input_ignored_during_short_delay_after_death() -> void:
	_screen.input_delay_msec = 60000
	watch_signals(_screen)
	_screen.show_death()
	_screen.handle_event(TouchHelpers.press())
	assert_signal_not_emitted(_screen, "restart_requested")


func test_restart_with_missing_path_fails_safely_every_time() -> void:
	_screen.restart_scene_path = "res://nope.tscn"
	assert_eq(_screen.restart(), ERR_FILE_NOT_FOUND)
	assert_eq(_screen.restart(), ERR_FILE_NOT_FOUND)
	_screen.restart_scene_path = ""
	assert_eq(_screen.restart(), ERR_FILE_NOT_FOUND)


func _shop_button() -> Button:
	return _screen.get_node("ShopButton") as Button


func _touch_at(position: Vector2) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	event.position = position
	return event


func test_shop_button_is_hidden_until_death_and_then_focused() -> void:
	assert_false(_shop_button().visible)
	_screen.show_death()
	await wait_process_frames(2)
	assert_true(_shop_button().visible)
	assert_true(_shop_button().has_focus())


func test_pressing_the_shop_button_emits_shop_requested() -> void:
	_screen.show_death()
	watch_signals(_screen)
	_shop_button().pressed.emit()
	assert_signal_emit_count(_screen, "shop_requested", 1)


func test_the_shop_cannot_be_requested_before_death() -> void:
	watch_signals(_screen)
	_shop_button().pressed.emit()
	assert_signal_not_emitted(_screen, "shop_requested")


func test_restart_action_is_ignored_while_the_shop_is_open() -> void:
	_screen.show_death()
	_screen.set_shop_open(true)
	watch_signals(_screen)
	_screen.handle_event(_restart_action())
	assert_signal_not_emitted(_screen, "restart_requested")


func test_touch_outside_the_shop_button_still_restarts() -> void:
	_screen.show_death()
	await wait_process_frames(2)
	watch_signals(_screen)
	_screen.handle_event(_touch_at(Vector2(3, 3)))
	assert_signal_emit_count(_screen, "restart_requested", 1)
	assert_signal_not_emitted(_screen, "shop_requested")


func test_touch_inside_the_shop_button_opens_the_shop_and_does_not_restart() -> void:
	_screen.show_death()
	await wait_process_frames(2)
	watch_signals(_screen)
	_screen.handle_event(_touch_at(_shop_button().get_global_rect().get_center()))
	assert_signal_not_emitted(_screen, "restart_requested")
	assert_signal_emit_count(_screen, "shop_requested", 1)


func test_touch_anywhere_is_ignored_for_restart_while_the_shop_is_open() -> void:
	_screen.show_death()
	await wait_process_frames(2)
	_screen.set_shop_open(true)
	watch_signals(_screen)
	_screen.handle_event(_touch_at(Vector2(3, 3)))
	_screen.handle_event(_touch_at(_shop_button().get_global_rect().get_center()))
	assert_signal_not_emitted(_screen, "restart_requested")
	assert_signal_not_emitted(_screen, "shop_requested")


func test_restart_works_again_after_the_shop_closes() -> void:
	_screen.show_death()
	_screen.set_shop_open(true)
	_screen.set_shop_open(false)
	watch_signals(_screen)
	_screen.handle_event(_restart_action())
	assert_signal_emit_count(_screen, "restart_requested", 1)


func test_requesting_the_shop_marks_it_open_until_closed() -> void:
	_screen.show_death()
	_shop_button().pressed.emit()
	watch_signals(_screen)
	_screen.handle_event(_restart_action())
	assert_signal_not_emitted(_screen, "restart_requested")
	_screen.set_shop_open(false)
	_screen.handle_event(_restart_action())
	assert_signal_emit_count(_screen, "restart_requested", 1)


func test_the_shop_button_is_not_requested_twice_while_open() -> void:
	_screen.show_death()
	watch_signals(_screen)
	_shop_button().pressed.emit()
	_shop_button().pressed.emit()
	assert_signal_emit_count(_screen, "shop_requested", 1)


func test_the_shop_button_is_ignored_inside_the_input_delay() -> void:
	_screen.input_delay_msec = 500
	_screen.show_death()
	watch_signals(_screen)
	_shop_button().pressed.emit()
	assert_signal_not_emitted(_screen, "shop_requested")
	_screen.input_delay_msec = 0
	_shop_button().pressed.emit()
	assert_signal_emit_count(_screen, "shop_requested", 1)


func test_a_tap_on_the_shop_button_inside_the_delay_does_nothing() -> void:
	_screen.input_delay_msec = 500
	_screen.show_death()
	await wait_process_frames(2)
	watch_signals(_screen)
	_screen.handle_event(_touch_at(_shop_button().get_global_rect().get_center()))
	assert_signal_not_emitted(_screen, "shop_requested")
	assert_signal_not_emitted(_screen, "restart_requested")


func test_the_death_screen_sits_on_a_card_and_the_shop_button_is_green() -> void:
	assert_true(_screen.get_node("Card") is Panel)
	assert_eq((_screen.get_node("Card") as Panel).mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq((_screen.get_node("ShopButton") as Button).theme_type_variation, &"ButtonGreen")


func test_the_death_message_is_a_heading_with_no_font_size_override() -> void:
	var message := _screen.get_node("Message") as Label
	assert_eq(message.theme_type_variation, &"Heading")
	assert_false(message.has_theme_font_size_override("font_size"))
	assert_false((_screen.get_node("Hint") as Label).has_theme_font_size_override("font_size"))


func test_the_widest_recap_values_fit_their_columns() -> void:
	var rows: Array[Dictionary] = []
	for label in ["Time survived", "Enemies defeated", "Bosses defeated", "XP earned", "Gold earned", "Scrolls collected", "Spells crafted", "Potions drunk"]:
		rows.append({"label": label, "value": "999999", "best": "best 999:59", "new_best": false})
	_screen.set_recap(rows)
	for label in _screen.get_node("Recap").find_children("*", "Label", true, false):
		var width := UiFont.plain().get_string_size((label as Label).text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.SIZE).x
		assert_lte(width, (label as Label).size.x, "%s fits its column" % (label as Label).text)

func test_the_home_button_exists_beside_shop_and_is_big_enough() -> void:
	_screen.show_death()
	var home := _screen.get_node("HomeButton") as Button
	var shop := _screen.get_node("ShopButton") as Button
	assert_true(home.visible)
	assert_gte(home.size.x, 96.0)
	assert_gte(home.size.y, 32.0)
	assert_false(home.get_global_rect().intersects(shop.get_global_rect()), "they sit side by side")


func test_home_button_tap_goes_home_and_never_restarts() -> void:
	_screen.home_scene_path = "res://this_scene_does_not_exist.tscn"
	_screen.show_death()
	watch_signals(_screen)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = (_screen.get_node("HomeButton") as Button).get_global_rect().get_center()
	_screen.handle_event(touch)
	assert_signal_emit_count(_screen, "home_requested", 1)
	assert_signal_not_emitted(_screen, "restart_requested")


func test_home_button_is_ignored_inside_the_input_delay_and_while_the_shop_is_open() -> void:
	_screen.home_scene_path = "res://this_scene_does_not_exist.tscn"
	_screen.input_delay_msec = 5000
	_screen.show_death()
	watch_signals(_screen)
	(_screen.get_node("HomeButton") as Button).pressed.emit()
	assert_signal_not_emitted(_screen, "home_requested")
	_screen.input_delay_msec = 0
	_screen.set_shop_open(true)
	(_screen.get_node("HomeButton") as Button).pressed.emit()
	assert_signal_not_emitted(_screen, "home_requested")


func test_a_tap_elsewhere_still_restarts() -> void:
	_screen.restart_scene_path = "res://this_scene_does_not_exist.tscn"
	_screen.show_death()
	watch_signals(_screen)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(5, 5)
	_screen.handle_event(touch)
	assert_signal_emit_count(_screen, "restart_requested", 1)
	assert_signal_not_emitted(_screen, "home_requested")


func test_focus_moves_between_shop_and_home_by_keyboard_and_controller() -> void:
	_screen.show_death()
	var shop := _screen.get_node("ShopButton") as Button
	var home := _screen.get_node("HomeButton") as Button
	assert_eq(shop.find_valid_focus_neighbor(SIDE_RIGHT), home)
	assert_eq(home.find_valid_focus_neighbor(SIDE_LEFT), shop)
	assert_eq(shop.find_next_valid_focus(), home)


func _rows(new_best: bool = false) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for i in 8:
		rows.append({"label": "Stat %d" % i, "value": str(i * 10), "best": "best %d" % (i * 12) if i < 3 else "", "new_best": new_best and i == 1})
	return rows


func test_the_recap_is_hidden_until_set() -> void:
	_screen.show_death()
	assert_eq(_screen.recap_text(), "")


func test_set_recap_shows_every_row_with_its_best_or_new_best_mark() -> void:
	_screen.set_recap(_rows(true))
	var lines := _screen.recap_text().split("\n")
	assert_eq(lines.size(), 8)
	assert_eq(lines[0], "Stat 0: 0  best 0")
	assert_eq(lines[1], "Stat 1: 10  New best!", "a new best shows the mark instead of the best")
	assert_eq(lines[7], "Stat 7: 70")


func test_the_recap_card_fits_the_screen() -> void:
	_screen.set_recap(_rows(true))
	_screen.show_death()
	var screen_rect := Rect2(0, 0, 480, 270)
	for label in _screen.get_node("Recap").find_children("*", "Label", true, false):
		var label_rect := Rect2((label as Label).global_position, (label as Label).size)
		assert_true(screen_rect.encloses(label_rect), "%s inside the screen" % (label as Label).text)
		var width := UiFont.plain().get_string_size((label as Label).text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.SIZE).x
		assert_lte(width, (label as Label).size.x, "%s fits its column" % (label as Label).text)


func test_the_recap_sits_above_the_buttons() -> void:
	_screen.set_recap(_rows(true))
	_screen.show_death()
	var lowest := 0.0
	for label in _screen.get_node("Recap").find_children("*", "Label", true, false):
		lowest = maxf(lowest, (label as Label).global_position.y + (label as Label).size.y)
	assert_lt(lowest, (_screen.get_node("ShopButton") as Button).global_position.y, "no row touches the buttons")


func test_shop_home_and_restart_still_work_with_the_recap() -> void:
	_screen.set_recap(_rows())
	_screen.show_death()
	watch_signals(_screen)
	_screen.handle_event(_restart_action())
	assert_signal_emit_count(_screen, "restart_requested", 1)
