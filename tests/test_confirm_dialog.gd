extends GutTest

var _dialog: ConfirmDialog


func before_each() -> void:
	_dialog = (load("res://scenes/ui/confirm_dialog.tscn") as PackedScene).instantiate() as ConfirmDialog
	_dialog.input_guard_msec = 0
	add_child_autofree(_dialog)


func after_each() -> void:
	get_tree().paused = false


func _button(text: String) -> Button:
	for button in _dialog.find_children("*", "Button", true, false):
		if (button as Button).text == text:
			return button as Button
	return null


func _action(name: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func test_ask_shows_and_focuses_cancel() -> void:
	assert_false(_dialog.is_open())
	_dialog.ask("Erase?", "Everything goes.", "Erase")
	assert_true(_dialog.is_open())
	assert_true(_button("Cancel").has_focus(), "the safe choice has focus")
	assert_not_null(_button("Erase"))


func test_confirm_emits_confirmed_once_and_closes() -> void:
	_dialog.ask("Erase?", "Everything goes.", "Erase")
	watch_signals(_dialog)
	_button("Erase").pressed.emit()
	_button("Erase").pressed.emit()
	assert_signal_emit_count(_dialog, "confirmed", 1)
	assert_false(_dialog.is_open())


func test_cancel_button_escape_and_a_click_outside_all_cancel() -> void:
	for how in ["button", "escape", "pause", "outside"]:
		_dialog.ask("Erase?", "Everything goes.", "Erase")
		clear_signal_watcher()
		watch_signals(_dialog)
		match how:
			"button":
				_button("Cancel").pressed.emit()
			"escape":
				_dialog._input(_action(&"ui_cancel"))
			"pause":
				_dialog._input(_action(&"pause"))
			"outside":
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = true
				click.position = Vector2(2, 2)
				_dialog._input(click)
		assert_signal_emit_count(_dialog, "cancelled", 1, how)
		assert_signal_not_emitted(_dialog, "confirmed", how)
		assert_false(_dialog.is_open(), how)


func test_a_touch_outside_the_card_cancels_and_one_inside_is_taken() -> void:
	_dialog.ask("Erase?", "Everything goes.", "Erase")
	watch_signals(_dialog)
	var inside := InputEventScreenTouch.new()
	inside.pressed = true
	inside.position = Vector2(240, 135)
	assert_true(_dialog.handle_input(inside), "a touch on the card is bridged to a click")
	assert_signal_not_emitted(_dialog, "cancelled")
	var outside := InputEventScreenTouch.new()
	outside.pressed = true
	outside.position = Vector2(3, 3)
	assert_true(_dialog.handle_input(outside))
	assert_signal_emit_count(_dialog, "cancelled", 1)


func test_a_press_inside_the_input_guard_does_nothing() -> void:
	_dialog.input_guard_msec = 400
	_dialog.ask("Erase?", "Everything goes.", "Erase")
	watch_signals(_dialog)
	_button("Erase").pressed.emit()
	assert_signal_not_emitted(_dialog, "confirmed")
	assert_true(_dialog.is_open())
	_dialog.input_guard_msec = 0
	_button("Erase").pressed.emit()
	assert_signal_emit_count(_dialog, "confirmed", 1)


func test_buttons_meet_the_touch_size_and_colours() -> void:
	_dialog.ask("Erase?", "Everything goes.", "Erase")
	for text in ["Cancel", "Erase"]:
		var button := _button(text)
		assert_gte(button.custom_minimum_size.x, UiKit.ACTION_SIZE.x, text)
		assert_gte(button.custom_minimum_size.y, UiKit.ACTION_SIZE.y, text)
	assert_eq(_button("Cancel").theme_type_variation, &"ButtonRed")
	assert_eq(_button("Erase").theme_type_variation, &"ButtonGreen")


func test_it_works_while_the_tree_is_paused() -> void:
	assert_eq(_dialog.process_mode, Node.PROCESS_MODE_ALWAYS)
	get_tree().paused = true
	_dialog.ask("Erase?", "Everything goes.", "Erase")
	watch_signals(_dialog)
	_dialog._input(_action(&"ui_cancel"))
	assert_signal_emit_count(_dialog, "cancelled", 1)
