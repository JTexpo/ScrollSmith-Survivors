extends GutTest

const ROOT := "res://.godot/save_tests"

var _screen: SettingsScreen
var _dir: String


func before_each() -> void:
	GameSettings.reset()
	FxSettings.reset()
	_dir = "%s/settingsscreen_%s" % [ROOT, str(randi())]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_screen = (load("res://scenes/ui/settings_screen.tscn") as PackedScene).instantiate() as SettingsScreen
	_screen.settings_path = "%s/settings.json" % _dir
	add_child_autofree(_screen)


func after_each() -> void:
	get_tree().paused = false
	GameSettings.reset()
	FxSettings.reset()
	var absolute := ProjectSettings.globalize_path(_dir)
	for file in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute("%s/%s" % [absolute, file])
	DirAccess.remove_absolute(absolute)


func _saved() -> Dictionary:
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string(_screen.settings_path))
	return json.data


func _action(name: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func test_open_and_close_toggle_visibility_and_emit_closed() -> void:
	watch_signals(_screen)
	assert_false(_screen.is_open())
	_screen.open()
	assert_true(_screen.is_open())
	_screen.close()
	assert_false(_screen.is_open())
	assert_signal_emit_count(_screen, "closed", 1)


func test_set_music_applies_announces_and_saves() -> void:
	var count := [0]
	var listener := func() -> void: count[0] += 1
	SettingsEvents.bus.changed.connect(listener)
	_screen.open()
	_screen.set_music(0.35)
	SettingsEvents.bus.changed.disconnect(listener)
	assert_almost_eq(GameSettings.music_volume, 0.35, 0.0001)
	assert_eq(count[0], 1)
	assert_almost_eq(float(_saved()["audio"]["music"]), 0.35, 0.0001)


func test_set_sfx_clamps_and_saves() -> void:
	_screen.open()
	_screen.set_sfx(7.0)
	assert_eq(GameSettings.sfx_volume, 1.0)
	assert_eq(float(_saved()["audio"]["sfx"]), 1.0)


func test_set_switch_flips_the_fx_switch_and_saves() -> void:
	_screen.open()
	_screen.set_switch("particles", false)
	assert_false(FxSettings.particles)
	assert_false(_saved()["fx"]["particles"])


func test_the_overlay_switch_shows_the_overlay_immediately() -> void:
	var overlay := (load("res://scenes/ui/perf_overlay.tscn") as PackedScene).instantiate() as PerfOverlay
	add_child_autofree(overlay)
	assert_false(overlay.visible)
	_screen.open()
	_screen.set_switch("perf_overlay", true)
	assert_true(overlay.visible)
	_screen.set_switch("perf_overlay", false)
	assert_false(overlay.visible)


func test_set_scale_clamps_and_saves() -> void:
	_screen.open()
	_screen.set_strength("shake_scale", 4.0)
	assert_eq(FxSettings.shake_scale, 1.0)
	_screen.set_strength("flash_scale", 0.25)
	assert_eq(FxSettings.flash_scale, 0.25)
	assert_eq(float(_saved()["fx"]["flash_scale"]), 0.25)


func test_reduce_motion_sets_the_comfort_values() -> void:
	_screen.open()
	_screen.reduce_motion()
	assert_eq(FxSettings.shake_scale, 0.0)
	assert_eq(FxSettings.flash_scale, 0.0)
	assert_false(FxSettings.hurt_feedback)
	assert_eq(float(_saved()["fx"]["shake_scale"]), 0.0)


func test_pages_switch_between_main_controls_and_credits_and_escape_goes_back() -> void:
	_screen.open()
	assert_eq(_screen.page(), &"main")
	_screen.show_page(&"controls")
	assert_eq(_screen.page(), &"controls")
	_screen._input(_action(&"ui_cancel"))
	assert_eq(_screen.page(), &"main", "escape goes back to the main page first")
	assert_true(_screen.is_open())
	_screen.show_page(&"credits")
	assert_eq(_screen.page(), &"credits")
	_screen._input(_action(&"pause"))
	_screen._input(_action(&"pause"))
	assert_false(_screen.is_open(), "escape on the main page closes it")


func test_every_switch_key_has_a_toggle_and_each_slider_exists() -> void:
	_screen.open()
	assert_eq(_screen.switch_count(), FxSettings.SWITCH_KEYS.size())
	for slider in ["music", "sfx", "shake_scale", "flash_scale"]:
		assert_not_null(_screen.slider(slider), slider)


func test_toggles_and_buttons_are_at_least_22_px_tall() -> void:
	_screen.open()
	for button in _screen.find_children("*", "Button", true, false):
		assert_gte((button as Button).custom_minimum_size.y, 22.0, (button as Button).text)
	for slider in ["music", "sfx", "shake_scale", "flash_scale"]:
		assert_gte(_screen.slider(slider).custom_minimum_size.y, 22.0, slider)


func test_a_toggle_press_flips_its_switch() -> void:
	_screen.open()
	_screen.toggle_button("heart_beat").pressed.emit()
	assert_false(FxSettings.heart_beat)
	_screen.toggle_button("heart_beat").pressed.emit()
	assert_true(FxSettings.heart_beat)


func test_a_touch_while_open_is_taken_for_bridging_and_one_while_closed_is_not() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(100, 100)
	assert_false(_screen.handle_input(touch), "closed: not ours")
	_screen.open()
	assert_true(_screen.handle_input(touch))


func test_it_works_while_the_tree_is_paused() -> void:
	assert_eq(_screen.process_mode, Node.PROCESS_MODE_ALWAYS)
	get_tree().paused = true
	_screen.open()
	_screen._input(_action(&"ui_cancel"))
	assert_false(_screen.is_open())


func test_opening_shows_the_current_values() -> void:
	GameSettings.music_volume = 0.3
	FxSettings.particles = false
	_screen.open()
	assert_almost_eq(_screen.slider("music").value, 0.3, 0.001)
	assert_false(_screen.toggle_button("particles").button_pressed, "an off switch shows as off")
