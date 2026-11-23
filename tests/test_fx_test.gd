extends GutTest
## The effects-test scene is a developer tool: its buttons fire the same announcements the game does, so these tests press them
## through the scene's own methods and look at what the effects nodes did.

const SCENE := preload("res://scenes/world/fx_test.tscn")


func before_each() -> void:
	FxSettings.reset()


func after_each() -> void:
	FxSettings.reset()


func _tool() -> FxTest:
	var made := SCENE.instantiate() as FxTest
	add_child(made)
	await wait_frames(2)
	return made


func test_the_scene_loads_and_builds_its_buttons() -> void:
	var tool := await _tool()
	assert_eq(tool.impact_button_count(), 12, "light, medium and heavy for each of the four elements")
	assert_true(tool.director().is_bound(), "the director is wired to the scene's own parts")
	var too_small := 0
	for button in tool.find_children("*", "Button", true, false):
		if (button as Button).custom_minimum_size.y < 22.0:
			too_small += 1
	assert_eq(too_small, 0, "every button is at least 22 px tall")
	tool.queue_free()


func test_a_heavy_impact_button_makes_particles_and_shakes() -> void:
	var tool := await _tool()
	tool.press_impact(&"fire", FxTest.HEAVY)
	assert_gt(tool.burst_layer().active_count(), 0, "a heavy hit throws a burst")
	assert_eq(tool.director().camera_shake().shakes_made(), 1, "and shakes the camera")
	assert_almost_eq(tool.last_weight(), 1.0, 0.001)
	tool.queue_free()


func test_a_light_impact_button_throws_a_few_sparks_and_no_shake() -> void:
	var tool := await _tool()
	tool.press_impact(&"sea", FxTest.LIGHT)
	assert_gt(tool.burst_layer().active_count(), 0)
	assert_eq(tool.director().camera_shake().shakes_made(), 0)
	tool.queue_free()


func test_the_health_slider_drives_the_warning_level() -> void:
	var tool := await _tool()
	tool.set_health_percent(100.0)
	assert_eq(tool.warning().level(), 0)
	tool.set_health_percent(45.0)
	assert_eq(tool.warning().level(), 1)
	tool.set_health_percent(25.0)
	assert_eq(tool.warning().level(), 2)
	tool.set_health_percent(0.0)
	assert_eq(tool.warning().level(), 0, "dead shows no warning")
	tool.set_health_percent(60.0)
	assert_eq(tool.warning().level(), 0, "the slider can bring the wizard back")
	tool.queue_free()


func test_a_hit_button_shows_an_arc() -> void:
	var tool := await _tool()
	tool.hit_from(FxTest.LEFT)
	assert_eq(tool.indicator().visible_arcs().size(), 1)
	assert_true(tool.director().hurt_active(), "the wizard stand-in flashes")
	tool.queue_free()


func test_the_action_buttons_make_effects() -> void:
	var tool := await _tool()
	var before := tool.director().bursts_made()
	for action in [&"pickup", &"level_up", &"rare_drop", &"blast"]:
		tool.director().begin_frame()
		tool.press_action(action)
	assert_gt(tool.director().bursts_made(), before + 3, "each action makes at least one burst")
	tool.queue_free()


func test_the_scale_sliders_set_fx_settings_and_exit_restores_them() -> void:
	FxSettings.shake_scale = 0.7
	var tool := await _tool()
	tool.set_shake_scale(0.2)
	tool.set_flash_scale(0.0)
	assert_almost_eq(FxSettings.shake_scale, 0.2, 0.001)
	assert_almost_eq(FxSettings.flash_scale, 0.0, 0.001)
	tool.queue_free()
	await wait_frames(2)
	assert_almost_eq(FxSettings.shake_scale, 0.7, 0.001, "leaving the scene puts the settings back")
	assert_almost_eq(FxSettings.flash_scale, 1.0, 0.001)


func test_every_switch_button_sets_its_fx_setting() -> void:
	var tool := await _tool()
	assert_eq(tool.switch_count(), FxSettings.SWITCH_KEYS.size(), "one switch per effect")
	for key in FxSettings.SWITCH_KEYS:
		tool.set_switch(key, false)
		assert_false(FxSettings.get_switch(key), "%s is off" % key)
		tool.set_switch(key, true)
		assert_true(FxSettings.get_switch(key), "%s is on" % key)
	tool.queue_free()
