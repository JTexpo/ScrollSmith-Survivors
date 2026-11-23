extends GutTest

var _screen: BuffPickScreen
var _options: Array[ScrollData]


func _scroll(name: String) -> ScrollData:
	return load("res://resources/scrolls/buff/%s.tres" % name) as ScrollData


func before_each() -> void:
	_screen = load("res://scenes/ui/buff_pick_screen.tscn").instantiate() as BuffPickScreen
	_screen.pause_tree = false
	add_child_autofree(_screen)
	_options = [_scroll("damage"), _scroll("max_mana"), _scroll("duplicate_area")]


func test_starts_closed_and_hidden() -> void:
	assert_false(_screen.is_open())
	assert_false(_screen.visible)


func test_open_builds_one_button_per_option() -> void:
	_screen.open(_options, "Choose a buff")
	assert_true(_screen.is_open())
	assert_true(_screen.visible)
	assert_eq(_screen.option_count(), 3)
	assert_eq(_screen.button_text(0).split("\n")[0], "Increased Damage")


func test_open_pauses_the_tree_and_choose_resumes_it() -> void:
	_screen.pause_tree = true
	_screen.open(_options, "Choose a buff")
	assert_true(get_tree().paused)
	_screen.choose(1)
	assert_false(get_tree().paused)
	assert_false(_screen.is_open())


func test_choose_emits_the_scroll_and_closes() -> void:
	watch_signals(_screen)
	_screen.open(_options, "Choose a buff")
	_screen.choose(2)
	assert_signal_emitted_with_parameters(_screen, "chosen", [_options[2]])
	assert_false(_screen.is_open())
	assert_false(_screen.visible)


func test_choose_out_of_range_is_ignored() -> void:
	watch_signals(_screen)
	_screen.open(_options, "Choose a buff")
	_screen.choose(3)
	_screen.choose(-1)
	assert_signal_not_emitted(_screen, "chosen")
	assert_true(_screen.is_open())


func test_choose_while_closed_does_nothing() -> void:
	watch_signals(_screen)
	_screen.choose(0)
	assert_signal_not_emitted(_screen, "chosen")


func test_cancel_does_nothing() -> void:
	_screen.open(_options, "Choose a buff")
	for action in [&"ui_cancel", &"pause"]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = true
		_screen._unhandled_input(event)
	assert_true(_screen.is_open())


func test_empty_options_do_not_open_or_pause() -> void:
	_screen.pause_tree = true
	_screen.open([] as Array[ScrollData], "Choose a buff")
	assert_false(_screen.is_open())
	assert_false(get_tree().paused)


func test_first_option_has_focus_for_keyboard_and_controller() -> void:
	_screen.open(_options, "Choose a buff")
	await wait_process_frames(1)
	assert_true(_screen.first_button_has_focus())


func test_reopening_replaces_the_old_buttons() -> void:
	_screen.open(_options, "Choose a buff")
	_screen.choose(0)
	_screen.open([_options[0]] as Array[ScrollData], "Choose a buff")
	assert_eq(_screen.option_count(), 1)


func test_effect_text_names_the_buff_numbers() -> void:
	var damage := BuffPickScreen.effect_text(_scroll("damage"))
	assert_string_contains(damage, "damage x1.5")
	assert_string_contains(damage, "cost x1.5")
	var copies := BuffPickScreen.effect_text(_scroll("duplicate_area"))
	assert_string_contains(copies, "+1 copy")
	assert_string_contains(copies, "cost x2")
	assert_string_contains(BuffPickScreen.effect_text(_scroll("max_mana")), "mana pool x1.5")
	assert_string_contains(BuffPickScreen.effect_text(_scroll("ignore_resistance")), "ignores resistance")
	assert_string_contains(BuffPickScreen.effect_text(_scroll("double_vulnerability")), "strong-hit bonus")


func test_touch_event_is_bridged_while_open() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(40, 40)
	assert_false(_screen.handle_input(touch), "closed")
	_screen.open(_options, "Choose a buff")
	assert_true(_screen.handle_input(touch), "open")
	assert_false(_screen.handle_input(InputEventScreenDrag.new()), "only touches are bridged")


func test_the_screen_sits_on_a_window_panel() -> void:
	_screen.open(_options, "Choose a buff")
	assert_not_null(_screen.find_child("Window", true, false))
	assert_not_null(_screen.find_child("Backdrop", true, false))


func test_every_buff_text_wraps_inside_its_button() -> void:
	for scroll in LevelTrack.default_track().buff_pool:
		_screen.open([scroll] as Array[ScrollData], "Choose a buff")
		var button := _screen.find_children("*", "Button", true, false)[0] as Button
		assert_ne(button.autowrap_mode, TextServer.AUTOWRAP_OFF, "buttons wrap long text")
		var wrapped := UiFont.plain().get_multiline_string_size(_screen.button_text(0), HORIZONTAL_ALIGNMENT_LEFT, BuffPickScreen.BUTTON_SIZE.x - 8.0, UiFont.SIZE, -1, TextServer.BREAK_WORD_BOUND | TextServer.BREAK_MANDATORY)
		assert_lte(wrapped.y, 3.0 * UiFont.SIZE, "%s fits in three lines" % scroll.display_name)
		_screen.choose(0)


func test_no_buff_pick_widget_sets_a_font_size() -> void:
	_screen.open(_options, "Choose a buff")
	for node in _screen.find_children("*", "Control", true, false):
		assert_false((node as Control).has_theme_font_size_override("font_size"), str(node.name))


func test_every_option_is_a_tall_tinted_button_with_an_icon() -> void:
	_screen.open(_options, "Choose a buff")
	for button in _screen.find_children("*", "Button", true, false):
		assert_gte((button as Button).custom_minimum_size.y, 38.0, "tall enough to hit")
		assert_not_null((button as Button).icon, "each option shows its buff's icon")
		assert_ne((button as Button).self_modulate, Color.WHITE, "each option is tinted by its buff")


func test_options_get_their_buffs_own_colour() -> void:
	_screen.open(_options, "Choose a buff")
	var tints := {}
	for button in _screen.find_children("*", "Button", true, false):
		tints[(button as Button).self_modulate.to_html()] = true
	assert_eq(tints.size(), 3, "three different buffs, three different colours")


func test_the_header_is_a_bright_banner_with_the_title() -> void:
	_screen.open(_options, "Choose a buff")
	var banner := _screen.find_child("Banner", true, false) as ColorRect
	assert_not_null(banner)
	assert_ne(banner.color, Color.WHITE)
	assert_eq(banner.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_all_the_options_fit_on_the_screen() -> void:
	var all: Array[ScrollData] = []
	for scroll in LevelTrack.default_track().buff_pool:
		all.append(scroll)
	_screen.open(all, "Choose a buff")
	var box := _screen.find_child("Options", true, false) as VBoxContainer
	assert_lte(box.position.y + box.get_combined_minimum_size().y, 264.0, "every option is inside the page")
