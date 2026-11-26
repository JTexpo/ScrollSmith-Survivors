extends GutTest
## The Achievements screen: every achievement as a card, earned in colour and unearned greyed, read-only, closed by Close, Esc or a tap
## outside the page. It decides touches by where they land (nothing is bridged) and runs while the game is paused.

var _catalog: AchievementCatalog
var _profile: PlayerProfile
var _track: LevelTrack
var _screen: AchievementsScreen
var _closed: int = 0


func before_each() -> void:
	_catalog = AchievementCatalog.default_catalog()
	_profile = PlayerProfile.new()
	_track = LevelTrack.default_track()
	_screen = (load("res://scenes/ui/achievements_screen.tscn") as PackedScene).instantiate() as AchievementsScreen
	add_child_autofree(_screen)
	_screen.input_guard_msec = 0
	_closed = 0
	_screen.closed.connect(func() -> void: _closed += 1)


func after_each() -> void:
	get_tree().paused = false


func _touch(at: Vector2, pressed: bool = true) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.pressed = pressed
	return event


func _click(at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	return event


func test_it_shows_twelve_cards_in_catalog_order() -> void:
	_screen.open(_catalog, _profile, _track)
	assert_eq(_screen.card_count(), 12)
	assert_string_contains(_screen.card_text(0), "Stormbreaker")
	assert_string_contains(_screen.card_text(0), "Defeat the Tempest Dragon")
	assert_string_contains(_screen.card_text(11), "Survive 20 minutes")


func test_earned_and_unearned_cards_differ() -> void:
	_profile.grant_achievement(&"reach_level_5")
	_screen.open(_catalog, _profile, _track)
	assert_true(_screen.card_earned(3), "reach_level_5 is the fourth card")
	assert_false(_screen.card_earned(0))
	assert_false(_screen.icon_is_grey(3), "an earned icon keeps its colours")
	assert_true(_screen.icon_is_grey(0), "an unearned icon is greyed out")
	assert_ne(_screen.card_panel_variation(3), _screen.card_panel_variation(0))


func test_the_greyed_icon_uses_a_greyscale_material_and_an_earned_one_none() -> void:
	_profile.grant_achievement(&"reach_level_5")
	_screen.open(_catalog, _profile, _track)
	var material := _screen.icon_material(0) as ShaderMaterial
	assert_not_null(material, "an unearned icon has a material")
	assert_string_contains(material.shader.code, "dot(", "it averages the colours into one grey")
	assert_null(_screen.icon_material(3), "an earned icon has none")


func test_the_count_line_follows_the_profile() -> void:
	_screen.open(_catalog, _profile, _track)
	assert_eq(_screen.count_text(), "0 of 12")
	_profile.grant_achievement(&"reach_level_5")
	_profile.grant_achievement(&"reach_level_10")
	_profile.grant_achievement(&"earn_gold_1000")
	_screen.open(_catalog, _profile, _track)
	assert_eq(_screen.count_text(), "3 of 12")
	for data in _catalog.achievements:
		_profile.grant_achievement(data.id)
	_screen.open(_catalog, _profile, _track)
	assert_eq(_screen.count_text(), "12 of 12")


func test_an_unknown_earned_id_is_not_counted() -> void:
	_profile.grant_achievement(&"removed_in_a_later_version")
	_screen.open(_catalog, _profile, _track)
	assert_eq(_screen.count_text(), "0 of 12")


func test_a_boss_card_shows_its_reward_line_and_others_do_not() -> void:
	_screen.open(_catalog, _profile, _track)
	assert_string_contains(_screen.card_text(0), "Thunder Zone")
	assert_string_contains(_screen.card_text(0), "slot 3")
	assert_string_contains(_screen.card_text(0), "level 10")
	assert_string_contains(_screen.card_text(2), "Land Line")
	assert_false(_screen.card_text(3).contains("Reward"))
	assert_false(_screen.card_text(8).contains("slot"))


func test_a_new_data_entry_appears_with_no_code_change() -> void:
	var extra := AchievementData.new()
	extra.id = &"extra"
	extra.display_name = "Extra"
	extra.description = "reach level 3"
	extra.kind = AchievementData.Kind.LEVEL
	extra.threshold = 3
	extra.icon = &"icon_ach_star"
	var bigger := AchievementCatalog.new()
	bigger.achievements = _catalog.achievements.duplicate()
	bigger.achievements.append(extra)
	_screen.open(bigger, _profile, _track)
	assert_eq(_screen.card_count(), 13)
	assert_string_contains(_screen.card_text(12), "Extra")


func test_every_card_fits_inside_the_screen() -> void:
	_screen.open(_catalog, _profile, _track)
	for i in _screen.card_count():
		var rect := _screen.card_rect(i)
		assert_true(Rect2(0, 0, 480, 270).encloses(rect), "card %d at %s" % [i, str(rect)])
	assert_false(_screen.card_rect(0).intersects(_screen.close_button().get_global_rect()), "no card under the Close button")


func test_close_esc_back_and_a_tap_outside_close_it() -> void:
	_screen.open(_catalog, _profile, _track)
	_screen.close_button().pressed.emit()
	assert_false(_screen.is_open())
	assert_eq(_closed, 1)
	_screen.open(_catalog, _profile, _track)
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	_screen._input(esc)
	assert_false(_screen.is_open())
	_screen.open(_catalog, _profile, _track)
	assert_true(_screen.handle_event(_touch(Vector2(1, 1))), "outside the page (the sky margin) closes")
	assert_false(_screen.is_open())
	_screen.open(_catalog, _profile, _track)
	assert_true(_screen.handle_event(_touch(_screen.close_button().get_global_rect().get_center())))
	assert_false(_screen.is_open())
	assert_eq(_closed, 4)


func test_a_tap_on_a_card_does_not_close_it() -> void:
	_screen.open(_catalog, _profile, _track)
	assert_true(_screen.handle_event(_touch(_screen.card_rect(4).get_center())), "consumed")
	assert_true(_screen.is_open())
	assert_eq(_closed, 0)


func test_a_touch_acts_exactly_once() -> void:
	_screen.open(_catalog, _profile, _track)
	var at := _screen.close_button().get_global_rect().get_center()
	assert_true(_screen.handle_event(_touch(at, true)))
	assert_eq(_closed, 1)
	assert_false(_screen.handle_event(_touch(at, false)), "the release of a closed screen is ignored")
	assert_eq(_closed, 1)


func test_a_click_on_a_card_does_nothing_and_a_click_outside_closes() -> void:
	_screen.open(_catalog, _profile, _track)
	assert_true(_screen.handle_event(_click(_screen.card_rect(4).get_center())))
	assert_true(_screen.is_open())
	assert_true(_screen.handle_event(_click(Vector2(1, 1))))
	assert_false(_screen.is_open())


func test_the_opening_press_is_ignored_for_the_guard_time() -> void:
	_screen.input_guard_msec = 60000
	_screen.open(_catalog, _profile, _track)
	assert_true(_screen.handle_event(_touch(Vector2(1, 1))), "consumed, never acted on")
	assert_true(_screen.is_open())


func test_it_ignores_everything_while_closed() -> void:
	assert_false(_screen.handle_event(_touch(Vector2(1, 1))))
	assert_false(_screen.is_open())


func test_it_runs_while_the_tree_is_paused() -> void:
	assert_eq(_screen.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_the_close_button_is_big_enough_for_a_thumb() -> void:
	_screen.open(_catalog, _profile, _track)
	var size := _screen.close_button().get_global_rect().size
	assert_gte(size.x, UiKit.ACTION_SIZE.x)
	assert_gte(size.y, UiKit.ACTION_SIZE.y)


func test_focus_starts_on_close() -> void:
	_screen.open(_catalog, _profile, _track)
	assert_true(_screen.close_button().has_focus())
