extends GutTest

var _menu: PauseMenu
var _open_flag: bool = true


func before_each() -> void:
	_open_flag = true
	_menu = (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate() as PauseMenu
	_menu.available = func() -> bool: return _open_flag
	add_child_autofree(_menu)
	_menu.confirm_dialog().input_guard_msec = 0
	_menu.settings_screen().settings_path = "res://.godot/save_tests/pause_menu_settings_unused.json"


func after_each() -> void:
	get_tree().paused = false
	GameTime.unfreeze()


func _action(name: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func _button(text: String) -> Button:
	for button in _menu.find_children("*", "Button", true, false):
		if (button as Button).text == text and (button as Button).is_visible_in_tree():
			return button as Button
	return null


func test_open_pauses_the_tree_and_freezes_game_time() -> void:
	_menu.open()
	assert_true(_menu.is_open())
	assert_true(get_tree().paused)
	assert_true(GameTime.is_frozen())


func test_resume_unpauses_and_unfreezes() -> void:
	_menu.open()
	watch_signals(_menu)
	_button("Resume").pressed.emit()
	assert_false(_menu.is_open())
	assert_false(get_tree().paused)
	assert_false(GameTime.is_frozen())
	assert_signal_emit_count(_menu, "resumed", 1)


func test_pause_key_opens_only_when_available() -> void:
	_open_flag = false
	_menu._unhandled_input(_action(&"pause"))
	assert_false(_menu.is_open(), "refused while something else is open or the player is dead")
	assert_false(get_tree().paused)
	_open_flag = true
	_menu._unhandled_input(_action(&"pause"))
	assert_true(_menu.is_open())


func test_pause_or_cancel_closes_it_when_nothing_inside_is_open() -> void:
	_menu.open()
	_menu._unhandled_input(_action(&"pause"))
	assert_false(_menu.is_open())
	_menu.open()
	_menu._unhandled_input(_action(&"ui_cancel"))
	assert_false(_menu.is_open())
	assert_false(get_tree().paused)


func test_settings_opens_and_closing_it_returns_to_the_menu() -> void:
	_menu.open()
	_button("Settings").pressed.emit()
	assert_true(_menu.settings_screen().is_open())
	assert_true(_menu.is_open(), "the menu stays open behind Settings")
	_menu.settings_screen().close()
	assert_true(_menu.is_open())
	assert_true(get_tree().paused)
	assert_not_null(_button("Resume"), "the menu buttons are showing again")


func test_the_pause_key_does_not_close_the_menu_while_settings_is_open() -> void:
	_menu.open()
	_menu.open_settings()
	_menu._unhandled_input(_action(&"pause"))
	assert_true(_menu.is_open(), "Settings handles that key itself")


func test_quit_asks_first_and_cancel_changes_nothing() -> void:
	_menu.open()
	_button("Quit to home").pressed.emit()
	assert_true(_menu.confirm_dialog().is_open())
	assert_true(get_tree().paused)
	watch_signals(_menu)
	_menu.confirm_dialog().cancelled.emit()
	assert_true(_menu.is_open())
	assert_signal_not_emitted(_menu, "quit_requested")


func test_quit_unpauses_then_changes_to_the_home_scene() -> void:
	_menu.home_scene_path = "res://this_scene_does_not_exist.tscn"
	_menu.open()
	watch_signals(_menu)
	_button("Quit to home").pressed.emit()
	_menu.confirm_dialog().confirmed.emit()
	assert_signal_emit_count(_menu, "quit_requested", 1)
	assert_false(get_tree().paused, "unpaused before the scene changes")
	assert_false(GameTime.is_frozen())


func test_buttons_meet_the_touch_size_and_it_works_while_paused() -> void:
	_menu.open()
	for text in ["Resume", "Settings", "Quit to home"]:
		var button := _button(text)
		assert_not_null(button, text)
		assert_gte(button.custom_minimum_size.x, UiKit.ACTION_SIZE.x, text)
		assert_gte(button.custom_minimum_size.y, UiKit.ACTION_SIZE.y, text)
	assert_eq(_menu.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_eq(_button("Quit to home").theme_type_variation, &"ButtonRed")
	assert_eq(_button("Resume").theme_type_variation, &"ButtonGreen")


func test_a_touch_while_open_is_bridged_and_one_while_closed_is_not() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(240, 135)
	assert_false(_menu.handle_input(touch))
	_menu.open()
	assert_true(_menu.handle_input(touch))
