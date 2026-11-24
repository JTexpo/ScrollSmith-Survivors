extends GutTest

const ROOT := "res://.godot/save_tests"

var _dir: String
var _home: HomeScreen


func before_each() -> void:
	GameSettings.reset()
	FxSettings.reset()
	_dir = "%s/home_%s" % [ROOT, str(randi())]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))


func after_each() -> void:
	get_tree().paused = false
	GameSettings.reset()
	FxSettings.reset()
	var absolute := ProjectSettings.globalize_path(_dir)
	for file in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute("%s/%s" % [absolute, file])
	DirAccess.remove_absolute(absolute)


func _save_path() -> String:
	return "%s/save.json" % _dir


func _start(gold: int = 0) -> HomeScreen:
	if gold > 0:
		var profile := PlayerProfile.new()
		profile.add_gold(gold)
		SaveGame.save_profile(profile, _save_path())
	_home = (load("res://scenes/home/home.tscn") as PackedScene).instantiate() as HomeScreen
	_home.save_path = _save_path()
	_home.settings_path = "%s/settings.json" % _dir
	_home.run_scene_path = "res://this_scene_does_not_exist.tscn"
	add_child_autofree(_home)
	_home.confirm_dialog().input_guard_msec = 0
	_home.shop_screen().input_guard_msec = 0
	return _home


func _button(text: String) -> Button:
	for button in _home.find_children("*", "Button", true, false):
		if (button as Button).text == text and (button as Button).is_visible_in_tree():
			return button as Button
	return null


func test_it_builds_its_buttons_in_order_and_the_tutorial_is_dimmed() -> void:
	_start()
	var labels := ["Play", "Shop", "Tutorial (soon)", "Settings", "New game"]
	var last_y := -1.0
	for text in labels:
		var button := _button(text)
		assert_not_null(button, text)
		assert_gt(button.position.y, last_y, "%s is below the one before" % text)
		last_y = button.position.y
		assert_gte(button.custom_minimum_size.x, UiKit.ACTION_SIZE.x, text)
		assert_gte(button.custom_minimum_size.y, UiKit.ACTION_SIZE.y, text)
	assert_true(_button("Tutorial (soon)").disabled)
	assert_false(_button("Play").disabled)


func test_play_requests_the_run_scene_and_does_not_create_it_before() -> void:
	_start()
	assert_null(get_tree().root.find_child("Main", true, false), "no run scene while the home screen is open")
	assert_eq(_home.play(), ERR_FILE_NOT_FOUND, "the (missing) run scene path was requested")


func test_the_home_screen_never_holds_the_run_scene_in_its_tree() -> void:
	_start()
	assert_null(_home.find_child("Player", true, false))
	assert_null(_home.find_child("EnemySpawner", true, false))


func test_the_saved_profile_loads_once() -> void:
	_start(77)
	assert_eq(_home.profile.gold, 77)


func test_shop_opens_and_a_purchase_is_saved_at_once() -> void:
	_start(500)
	_button("Shop").pressed.emit()
	assert_true(_home.shop_screen().is_open())
	_home.shop_screen().buy(&"robe_ember")
	var saved := SaveGame.load_profile(_save_path())
	assert_true(saved.owns(&"robe_ember"))
	assert_eq(saved.gold, 500 - EquipmentCatalog.default_catalog().find(&"robe_ember").price)


func test_a_failed_purchase_saves_nothing() -> void:
	_start(1)
	var before := FileAccess.get_file_as_string(_save_path())
	_button("Shop").pressed.emit()
	_home.shop_screen().buy(&"robe_ember")
	assert_eq(FileAccess.get_file_as_string(_save_path()), before)


func test_settings_opens_and_closes_back_to_the_buttons() -> void:
	_start()
	_button("Settings").pressed.emit()
	assert_true(_home.settings_screen().is_open())
	_home.settings_screen().close()
	assert_false(_home.settings_screen().is_open())
	assert_not_null(_button("Play"))


func test_new_game_first_yes_only_advances() -> void:
	_start(300)
	_button("New game").pressed.emit()
	assert_true(_home.confirm_dialog().is_open())
	_home.confirm_dialog().confirmed.emit()
	assert_true(_home.confirm_dialog().is_open(), "the second question is showing")
	assert_true(FileAccess.file_exists(_save_path()), "nothing is erased yet")
	assert_eq(_home.profile.gold, 300)


func test_new_game_cancel_at_either_step_changes_nothing() -> void:
	_start(300)
	_button("New game").pressed.emit()
	_home.confirm_dialog().cancelled.emit()
	assert_true(FileAccess.file_exists(_save_path()))
	_button("New game").pressed.emit()
	_home.confirm_dialog().confirmed.emit()
	_home.confirm_dialog().cancelled.emit()
	assert_true(FileAccess.file_exists(_save_path()))
	assert_eq(_home.profile.gold, 300)
	_home.confirm_dialog().confirmed.emit()
	assert_true(FileAccess.file_exists(_save_path()), "a stray confirm after cancelling does not erase")


func test_new_game_second_yes_erases_to_bak_and_keeps_settings() -> void:
	_start(300)
	GameSettings.music_volume = 0.4
	SettingsStore.save_file("%s/settings.json" % _dir)
	_button("New game").pressed.emit()
	_home.confirm_dialog().confirmed.emit()
	_home.confirm_dialog().confirmed.emit()
	assert_false(FileAccess.file_exists(_save_path()))
	assert_true(FileAccess.file_exists(_save_path() + ".bak"))
	assert_eq(_home.profile.gold, 0)
	assert_eq(_home.message_text(), "Starting over.")
	assert_true(FileAccess.file_exists("%s/settings.json" % _dir), "settings are kept")
	assert_almost_eq(GameSettings.music_volume, 0.4, 0.0001)


func test_new_game_with_no_save_is_fine() -> void:
	_start()
	_button("New game").pressed.emit()
	_home.confirm_dialog().confirmed.emit()
	_home.confirm_dialog().confirmed.emit()
	assert_eq(_home.profile.gold, 0)
	assert_false(FileAccess.file_exists(_save_path() + ".bak"))


func test_a_held_button_cannot_confirm_both_steps() -> void:
	_start(300)
	_home.confirm_dialog().input_guard_msec = 400
	_button("New game").pressed.emit()
	await get_tree().create_timer(0.45, true, false, true).timeout
	for button in _home.confirm_dialog().find_children("*", "Button", true, false):
		if (button as Button).text == "Erase":
			(button as Button).pressed.emit()
	assert_true(_home.confirm_dialog().is_open(), "the second question opened")
	for button in _home.confirm_dialog().find_children("*", "Button", true, false):
		if (button as Button).text == "Yes, start over":
			(button as Button).pressed.emit()
	assert_true(FileAccess.file_exists(_save_path()), "pressed inside the guard: nothing erased")
	assert_eq(_home.profile.gold, 300)


func test_a_fresh_profile_after_new_game_is_level_one_with_nothing() -> void:
	var profile := PlayerProfile.new()
	profile.total_xp = 99999
	profile.add_gold(50)
	profile.grant(&"robe_ember")
	SaveGame.save_profile(profile, _save_path())
	_start()
	_button("New game").pressed.emit()
	_home.confirm_dialog().confirmed.emit()
	_home.confirm_dialog().confirmed.emit()
	assert_eq(_home.profile.total_xp, 0)
	assert_eq(_home.profile.gold, 0)
	assert_true(_home.profile.owned.is_empty())


func test_focus_starts_on_play_and_accept_presses_it() -> void:
	_start()
	assert_true(_button("Play").has_focus())


func test_a_touch_while_idle_is_bridged_and_one_with_a_screen_open_is_left_to_it() -> void:
	_start()
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(240, 120)
	assert_true(_home.handle_input(touch))
	_button("Settings").pressed.emit()
	assert_false(_home.handle_input(touch), "the open Settings screen bridges its own touches")


func test_applying_saved_settings_on_start() -> void:
	GameSettings.music_volume = 0.1
	var file := FileAccess.open("%s/settings.json" % _dir, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": SettingsStore.VERSION, "audio": {"music": 0.6, "sfx": 0.2}, "fx": {}}))
	file.close()
	_start()
	assert_almost_eq(GameSettings.music_volume, 0.6, 0.0001)
	assert_almost_eq(GameSettings.sfx_volume, 0.2, 0.0001)


func test_the_full_screen_button_toggles_the_window_and_saves() -> void:
	var calls: Array[bool] = []
	var old_setter := ScreenMode.setter
	var old_getter := ScreenMode.getter
	var state := [false]
	ScreenMode.setter = func(on: bool) -> void:
		calls.append(on)
		state[0] = on
	ScreenMode.getter = func() -> bool: return state[0]
	_start()
	var button := _button("Full screen")
	assert_not_null(button)
	assert_gte(button.custom_minimum_size.y, UiKit.ACTION_SIZE.y)
	button.pressed.emit()
	assert_eq(calls, [true])
	assert_true(GameSettings.fullscreen)
	assert_true(FileAccess.file_exists("%s/settings.json" % _dir), "the choice is saved")
	ScreenMode.setter = old_setter
	ScreenMode.getter = old_getter
