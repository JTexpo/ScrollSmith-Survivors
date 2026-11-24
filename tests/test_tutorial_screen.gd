extends GutTest

var _screen: TutorialScreen


func before_each() -> void:
	_screen = (load("res://scenes/ui/tutorial_screen.tscn") as PackedScene).instantiate() as TutorialScreen
	add_child_autofree(_screen)


func after_each() -> void:
	get_tree().paused = false


func _button(text: String) -> Button:
	for button in _screen.find_children("*", "Button", true, false):
		if (button as Button).text == text and (button as Button).is_visible_in_tree():
			return button as Button
	return null


func _action(name: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func test_it_starts_closed_and_opens_on_the_first_page() -> void:
	assert_false(_screen.is_open())
	_screen.open()
	assert_true(_screen.is_open())
	assert_eq(_screen.page_index(), 0)
	assert_eq(_screen.page_count(), 4)


func test_next_and_back_move_and_stop_at_the_ends() -> void:
	_screen.open()
	_screen.back()
	assert_eq(_screen.page_index(), 0, "back stops at the first page")
	for i in 3:
		_screen.next()
	assert_eq(_screen.page_index(), 3)
	_screen.next()
	assert_false(_screen.is_open(), "next on the last page is Done and closes")


func test_back_is_disabled_on_the_first_page_and_next_says_done_on_the_last() -> void:
	_screen.open()
	assert_true(_button("Back").disabled)
	assert_not_null(_button("Next"))
	for i in 3:
		_screen.next()
	assert_false(_button("Back").disabled)
	assert_not_null(_button("Done"))
	assert_null(_button("Next"))


func test_done_closes_and_emits_closed() -> void:
	_screen.open()
	for i in 3:
		_screen.next()
	watch_signals(_screen)
	_button("Done").pressed.emit()
	assert_signal_emit_count(_screen, "closed", 1)
	assert_false(_screen.is_open())


func test_the_counter_shows_the_page() -> void:
	_screen.open()
	assert_eq(_screen.counter_text(), "1 of 4")
	_screen.next()
	assert_eq(_screen.counter_text(), "2 of 4")


func test_the_page_shows_its_title_lines_and_pictures() -> void:
	_screen.open()
	var page := TutorialPages.pages()[0]
	assert_eq(_screen.title_text(), page.title)
	assert_eq(_screen.lines_text(), "\n".join(page.lines))
	assert_eq(_screen.picture_count(), page.sprites.size())
	_screen.next()
	assert_eq(_screen.picture_count(), TutorialPages.pages()[1].sprites.size())


func test_left_and_right_page_and_escape_closes() -> void:
	_screen.open()
	_screen._input(_action(&"ui_right"))
	assert_eq(_screen.page_index(), 1)
	_screen._input(_action(&"ui_left"))
	assert_eq(_screen.page_index(), 0)
	_screen._input(_action(&"ui_cancel"))
	assert_false(_screen.is_open())
	_screen.open()
	_screen._input(_action(&"pause"))
	assert_false(_screen.is_open())


func test_every_button_is_reachable_by_focus() -> void:
	_screen.open()
	for i in 2:
		_screen.next()
	var back := _button("Back")
	var next := _button("Next")
	var close := _button("Close")
	assert_eq(back.find_valid_focus_neighbor(SIDE_RIGHT), next)
	assert_eq(next.find_valid_focus_neighbor(SIDE_LEFT), back)
	assert_not_null(next.find_next_valid_focus())
	assert_not_null(close.find_prev_valid_focus())


func test_buttons_meet_the_touch_size() -> void:
	_screen.open()
	for text in ["Back", "Next", "Close"]:
		var button := _button(text)
		assert_gte(button.custom_minimum_size.y, UiKit.ACTION_SIZE.y, text)
		assert_gte(button.custom_minimum_size.x, UiKit.ACTION_SIZE.x, text)


func test_a_touch_while_open_is_bridged_and_one_while_closed_is_not() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(100, 100)
	assert_false(_screen.handle_input(touch))
	_screen.open()
	assert_true(_screen.handle_input(touch))


func test_it_works_while_the_tree_is_paused() -> void:
	assert_eq(_screen.process_mode, Node.PROCESS_MODE_ALWAYS)
	get_tree().paused = true
	_screen.open()
	_screen._input(_action(&"ui_cancel"))
	assert_false(_screen.is_open())
