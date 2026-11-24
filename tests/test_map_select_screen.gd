extends GutTest
## Sprint 16a: the map select. One card per catalog entry (a schematic preview, the name, the theme line, the boss and the best on that map),
## Back and Play. A tap on a card starts that map. Touches are handled here, not bridged (mouse emulation is off).

var _screen: MapSelectScreen
var _catalog: MapCatalog


func before_each() -> void:
	_catalog = MapCatalog.default_catalog()
	_screen = (load("res://scenes/ui/map_select_screen.tscn") as PackedScene).instantiate() as MapSelectScreen
	add_child_autofree(_screen)
	_screen.input_guard_msec = 0


func _open(profile: PlayerProfile = PlayerProfile.new(), last_map: StringName = &"forest") -> void:
	_screen.open(profile, _catalog, last_map)


func _touch_at(position: Vector2) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	event.position = position
	return event


func _button(text: String) -> Button:
	for button in _screen.find_children("*", "Button", true, false):
		if (button as Button).text == text:
			return button as Button
	return null


func _card(index: int) -> Button:
	return _screen.card_button(index)


func test_it_builds_one_card_per_catalog_entry_in_order() -> void:
	_open()
	assert_eq(_screen.card_count(), 3)
	assert_string_contains(_screen.card_text(0), "The Forest")
	assert_string_contains(_screen.card_text(1), "The Ruins")
	assert_string_contains(_screen.card_text(2), "The Maze")


func test_each_card_shows_name_theme_boss_and_best() -> void:
	var profile := PlayerProfile.new()
	profile.set_best(&"forest", 125, 40)
	_open(profile)
	var forest := _screen.card_text(0)
	assert_string_contains(forest, "Open woods. Somewhere, a dragon.")
	assert_string_contains(forest, "Boss: Ember Titan")
	assert_string_contains(forest, "Best: 2:05")
	assert_string_contains(_screen.card_text(1), "No best yet")
	assert_string_contains(_screen.card_text(2), "No best yet")


func test_focus_starts_on_the_last_played_map() -> void:
	_open(PlayerProfile.new(), &"first_map")
	assert_eq(_screen.focused_index(), 1)
	_screen.close()
	_open(PlayerProfile.new(), &"maze")
	assert_eq(_screen.focused_index(), 2)


func test_an_unknown_last_map_focuses_the_first_card() -> void:
	_open(PlayerProfile.new(), &"nowhere")
	assert_eq(_screen.focused_index(), 0)


func test_choosing_a_card_emits_map_chosen_once_with_its_entry() -> void:
	_open()
	watch_signals(_screen)
	_screen.choose(2)
	assert_signal_emit_count(_screen, "map_chosen", 1)
	assert_eq(get_signal_parameters(_screen, "map_chosen")[0], _catalog.entries[2])


func test_a_bad_index_is_ignored() -> void:
	_open()
	watch_signals(_screen)
	_screen.choose(-1)
	_screen.choose(3)
	assert_signal_not_emitted(_screen, "map_chosen")


func test_a_choice_inside_the_input_guard_does_nothing() -> void:
	_screen.input_guard_msec = 60000
	_open()
	watch_signals(_screen)
	_screen.choose(0)
	_screen.handle_event(_touch_at(_card(0).get_global_rect().get_center()))
	assert_signal_not_emitted(_screen, "map_chosen")
	assert_true(_screen.is_open())


func test_back_and_escape_close_it_and_emit_closed() -> void:
	_open()
	watch_signals(_screen)
	_button("Back").pressed.emit()
	assert_false(_screen.is_open())
	_open()
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	_screen._input(escape)
	assert_false(_screen.is_open())
	assert_signal_emit_count(_screen, "closed", 2)


func test_a_tap_on_a_card_chooses_it_and_a_tap_outside_closes() -> void:
	_open()
	await wait_process_frames(2)
	watch_signals(_screen)
	assert_true(_screen.handle_event(_touch_at(_card(1).get_global_rect().get_center())))
	assert_signal_emit_count(_screen, "map_chosen", 1)
	assert_eq(get_signal_parameters(_screen, "map_chosen")[0], _catalog.entries[1])
	assert_true(_screen.handle_event(_touch_at(Vector2(2, 2))))
	assert_false(_screen.is_open())
	assert_signal_emit_count(_screen, "closed", 1)


func test_a_tap_on_play_starts_the_focused_map_and_on_back_closes() -> void:
	_open(PlayerProfile.new(), &"maze")
	await wait_process_frames(2)
	watch_signals(_screen)
	_screen.handle_event(_touch_at(_button("Play").get_global_rect().get_center()))
	assert_eq(get_signal_parameters(_screen, "map_chosen")[0], _catalog.entries[2])
	_screen.handle_event(_touch_at(_button("Back").get_global_rect().get_center()))
	assert_false(_screen.is_open())


func test_a_touch_while_closed_is_not_handled() -> void:
	assert_false(_screen.handle_event(_touch_at(Vector2(100, 100))))


func test_left_and_right_move_focus_between_cards_and_down_reaches_play() -> void:
	_open()
	assert_eq(_card(0).find_valid_focus_neighbor(SIDE_RIGHT), _card(1))
	assert_eq(_card(1).find_valid_focus_neighbor(SIDE_RIGHT), _card(2))
	assert_eq(_card(2).find_valid_focus_neighbor(SIDE_LEFT), _card(1))
	assert_eq(_card(1).find_valid_focus_neighbor(SIDE_BOTTOM), _button("Play"))
	assert_eq(_button("Play").find_valid_focus_neighbor(SIDE_LEFT), _button("Back"))
	assert_eq(_button("Back").find_valid_focus_neighbor(SIDE_RIGHT), _button("Play"))


func test_card_text_fits_each_card() -> void:
	_open()
	for label in _screen.find_children("*", "Label", true, false):
		var lab := label as Label
		if lab.autowrap_mode != TextServer.AUTOWRAP_OFF:
			var lines := UiFont.plain().get_multiline_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, lab.size.x, UiFont.SIZE).y
			assert_lte(lines, lab.size.y + 0.5, "%s fits its box" % lab.text)
		else:
			var width := UiFont.plain().get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.SIZE).x
			assert_lte(width, lab.size.x, "%s fits its box" % lab.text)


func test_cards_and_buttons_meet_the_touch_sizes_and_sit_on_screen() -> void:
	_open()
	for text in ["Back", "Play"]:
		assert_gte(_button(text).custom_minimum_size.x, UiKit.ACTION_SIZE.x, text)
		assert_gte(_button(text).custom_minimum_size.y, UiKit.ACTION_SIZE.y, text)
	var screen_rect := Rect2(0, 0, 480, 270)
	for i in _screen.card_count():
		assert_gte(_card(i).size.y, 22.0)
		assert_true(screen_rect.encloses(_card(i).get_global_rect()), "card %d is on screen" % i)
		assert_false(_card(i).get_global_rect().intersects(_button("Play").get_global_rect()), "card %d does not cover Play" % i)
	assert_false(_card(0).get_global_rect().intersects(_card(1).get_global_rect()))


func test_it_runs_while_paused_and_does_not_pause_anything() -> void:
	assert_eq(_screen.process_mode, Node.PROCESS_MODE_ALWAYS)
	_open()
	assert_false(get_tree().paused)


func test_no_label_is_wider_than_its_card_so_theme_lines_really_wrap() -> void:
	_open()
	for i in _screen.card_count():
		for label in _card(i).find_children("*", "Label", true, false):
			var lab := label as Label
			assert_lte(lab.size.x, 128.0, "%s is no wider than the card's inner width" % lab.text)
			if lab.autowrap_mode != TextServer.AUTOWRAP_OFF:
				assert_gt(lab.get_line_count(), 0)
	var theme_label: Label = null
	for label in _card(2).find_children("*", "Label", true, false):
		if (label as Label).text.begins_with("A minotaur"):
			theme_label = label
	assert_not_null(theme_label)
	assert_gt(theme_label.get_line_count(), 1, "the long theme line wraps onto more than one line")


func test_every_label_and_the_whole_text_stay_inside_their_card() -> void:
	var profile := PlayerProfile.new()
	profile.set_best(&"forest", 5999, 1)
	profile.set_best(&"maze", 754, 1)
	_open(profile)
	await wait_process_frames(2)
	for i in _screen.card_count():
		var card_rect := _card(i).get_global_rect()
		for label in _card(i).find_children("*", "Label", true, false):
			var lab := label as Label
			assert_true(card_rect.encloses(lab.get_global_rect()), "%s: the label box is inside card %d" % [lab.text, i])
			var text_size := UiFont.plain().get_multiline_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, lab.size.x if lab.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0, UiFont.SIZE)
			assert_lte(text_size.x, lab.size.x + 0.5, "%s: the text is no wider than its box" % lab.text)
			assert_lte(text_size.y, lab.size.y + 0.5, "%s: the text is no taller than its box" % lab.text)


func test_play_starts_the_selected_card_even_after_play_took_focus() -> void:
	_open(PlayerProfile.new(), &"maze")
	await wait_process_frames(2)
	_button("Play").grab_focus()
	watch_signals(_screen)
	_button("Play").pressed.emit()
	assert_eq(get_signal_parameters(_screen, "map_chosen")[0], _catalog.entries[2], "a mouse click, key or controller press on Play starts the map that was selected, not the first")


func test_play_follows_the_card_that_was_focused_last() -> void:
	_open(PlayerProfile.new(), &"forest")
	await wait_process_frames(2)
	_card(1).grab_focus()
	_button("Play").grab_focus()
	watch_signals(_screen)
	_button("Play").pressed.emit()
	assert_eq(get_signal_parameters(_screen, "map_chosen")[0], _catalog.entries[1])
