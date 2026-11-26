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


func test_the_page_shows_its_title_lines_and_its_vignette_instead_of_the_sprite_row() -> void:
	_screen.open()
	var page := TutorialPages.pages()[0]
	assert_eq(_screen.title_text(), page.title)
	assert_eq(_screen.lines_text(), "\n".join(page.lines))
	assert_eq(_screen.picture_count(), 0, "a page with a vignette has no sprite row")
	assert_true(_screen.stage().visible)
	assert_eq(_screen.stage().stage_script(), page.vignette)


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


func _stick(value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	return event


func test_one_push_of_the_stick_turns_one_page_not_several() -> void:
	_screen.open()
	for value in [0.6, 0.8, 1.0, 1.0]:
		_screen._input(_stick(value))
	assert_eq(_screen.page_index(), 1, "a push of the stick sends several motion events but is one page")
	assert_true(_screen.is_open())


func test_the_stick_pages_again_after_it_returns_to_neutral_and_the_other_way_goes_back() -> void:
	_screen.open()
	_screen._input(_stick(1.0))
	_screen._input(_stick(0.0))
	_screen._input(_stick(1.0))
	assert_eq(_screen.page_index(), 2)
	_screen._input(_stick(0.0))
	_screen._input(_stick(-1.0))
	assert_eq(_screen.page_index(), 1, "left goes back one page")


func test_pushing_the_stick_right_on_the_last_page_does_not_close_it_by_accident_more_than_once() -> void:
	_screen.open()
	for i in 3:
		_screen._input(_stick(1.0))
		_screen._input(_stick(0.0))
	assert_eq(_screen.page_index(), 3)
	_screen._input(_stick(1.0))
	_screen._input(_stick(1.0))
	assert_false(_screen.is_open(), "one deliberate push on the last page is Done")


func test_each_page_shows_its_vignette_and_restarts_it() -> void:
	var pages := TutorialPages.pages()
	_screen.open()
	assert_true(_screen.stage().is_playing())
	assert_eq(_screen.stage().stage_script(), pages[0].vignette)
	_screen.stage().advance(2.0)
	assert_gt(_screen.stage().elapsed(), 1.9)
	_screen.next()
	assert_eq(_screen.stage().stage_script(), pages[1].vignette)
	assert_lt(_screen.stage().elapsed(), 0.1, "a new page starts its vignette from the beginning")
	_screen.stage().advance(2.0)
	_screen.back()
	assert_eq(_screen.stage().stage_script(), pages[0].vignette)
	assert_lt(_screen.stage().elapsed(), 0.1, "going back restarts the first vignette too")


func test_closing_stops_the_stage() -> void:
	_screen.open()
	assert_true(_screen.stage().is_playing())
	_screen.close()
	assert_false(_screen.stage().is_playing())
	assert_false(_screen.stage().is_processing())


func test_reopening_starts_the_first_vignette_again() -> void:
	_screen.open()
	_screen.next()
	_screen.close()
	_screen.open()
	assert_eq(_screen.page_index(), 0)
	assert_eq(_screen.stage().stage_script(), TutorialPages.pages()[0].vignette)
	assert_true(_screen.stage().is_playing())


func test_a_page_without_a_vignette_keeps_the_sprite_row() -> void:
	var plain := TutorialPage.make("Plain", ["one line"] as Array[String], [&"player", &"pickup_xp"] as Array[StringName])
	_screen._pages = [plain] as Array[TutorialPage]
	_screen.open()
	assert_eq(_screen.picture_count(), 2)
	assert_false(_screen.stage().visible)
	assert_false(_screen.stage().is_playing())


func test_the_stage_frame_the_lines_and_the_buttons_do_not_overlap_and_fit_the_screen() -> void:
	_screen.open()
	var screen := Rect2(0, 0, 480, 270)
	var frame := _screen.stage().get_global_rect()
	var lines := _screen.lines_rect()
	var rects := {"stage": frame, "lines": lines, "title": _screen.title_rect(), "counter": _screen.counter_rect()}
	for text in ["Back", "Next", "Close"]:
		rects[text] = _button(text).get_global_rect()
	for key in rects:
		assert_true(screen.encloses(rects[key]), "%s %s is inside the screen" % [key, str(rects[key])])
	var keys := rects.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			assert_false((rects[keys[i]] as Rect2).intersects(rects[keys[j]]), "%s and %s overlap" % [keys[i], keys[j]])


func test_the_stage_takes_no_touches() -> void:
	_screen.open()
	assert_eq(_screen.stage().mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for node in _screen.stage().find_children("*", "Control", true, false):
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, str(node.name))


func test_reduced_motion_shows_a_still_vignette() -> void:
	FxSettings.reduce_motion()
	_screen.open()
	assert_false(_screen.stage().is_playing())
	assert_false(_screen.stage().is_processing())
	FxSettings.reset()

