extends GutTest

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


func _touch() -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
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
	_screen.handle_event(_touch())
	assert_signal_emit_count(_screen, "restart_requested", 2)


func test_input_ignored_during_short_delay_after_death() -> void:
	_screen.input_delay_msec = 60000
	watch_signals(_screen)
	_screen.show_death()
	_screen.handle_event(_touch())
	assert_signal_not_emitted(_screen, "restart_requested")


func test_restart_with_missing_path_fails_safely_every_time() -> void:
	_screen.restart_scene_path = "res://nope.tscn"
	assert_eq(_screen.restart(), ERR_FILE_NOT_FOUND)
	assert_eq(_screen.restart(), ERR_FILE_NOT_FOUND)
	_screen.restart_scene_path = ""
	assert_eq(_screen.restart(), ERR_FILE_NOT_FOUND)


func test_run_summary_text_shows_xp_and_level() -> void:
	_screen.set_run_summary(120, 7)
	assert_eq(_screen.summary_text(), "+120 XP, +0 Gold this run, level 7")


func test_death_screen_without_a_summary_shows_no_extra_line() -> void:
	_screen.show_death()
	assert_eq(_screen.summary_text(), "")


func test_restart_still_works_with_a_summary() -> void:
	_screen.set_run_summary(5, 1)
	_screen.show_death()
	watch_signals(_screen)
	_screen.handle_event(_restart_action())
	assert_signal_emitted(_screen, "restart_requested")


func test_summary_includes_gold() -> void:
	_screen.set_run_summary(120, 7, 45)
	assert_eq(_screen.summary_text(), "+120 XP, +45 Gold this run, level 7")


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


func test_summary_includes_time_survived() -> void:
	_screen.set_run_summary(120, 7, 45, 307.0)
	assert_eq(_screen.summary_text(), "+120 XP, +45 Gold this run, level 7, survived 5:07")


func test_summary_without_seconds_is_unchanged() -> void:
	_screen.set_run_summary(120, 7, 45)
	assert_eq(_screen.summary_text(), "+120 XP, +45 Gold this run, level 7")
	_screen.set_run_summary(1, 1, 0, -1.0)
	assert_eq(_screen.summary_text(), "+1 XP, +0 Gold this run, level 1")


func test_zero_seconds_still_shows_the_time() -> void:
	_screen.set_run_summary(0, 1, 0, 0.0)
	assert_eq(_screen.summary_text(), "+0 XP, +0 Gold this run, level 1, survived 0:00")
