extends GutTest
## The home screen's layout: a banner on top, the animated stage in the middle and the five buttons in one row, with the two corner
## buttons, and the stage plays only while nothing covers it.

const ROOT := "res://.godot/save_tests"
const SCREEN := Rect2(0, 0, 480, 270)
const ROW := ["Play", "Shop", "Tutorial", "Settings", "New game"]

var _dir: String
var _home: HomeScreen


func before_each() -> void:
	GameSettings.reset()
	FxSettings.reset()
	_dir = "%s/layout_%s" % [ROOT, str(randi())]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))


func after_each() -> void:
	get_tree().paused = false
	GameSettings.reset()
	FxSettings.reset()
	var absolute := ProjectSettings.globalize_path(_dir)
	for file in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute("%s/%s" % [absolute, file])
	DirAccess.remove_absolute(absolute)


func _start() -> HomeScreen:
	_home = _make()
	add_child_autofree(_home)
	_home.confirm_dialog().input_guard_msec = 0
	return _home


func _make() -> HomeScreen:
	var home := (load("res://scenes/home/home.tscn") as PackedScene).instantiate() as HomeScreen
	home.scene_changer = func(_path: String) -> Error: return OK
	home.save_path = "%s/save.json" % _dir
	home.settings_path = "%s/settings.json" % _dir
	return home


func _button(text: String) -> Button:
	for button in _home.find_children("*", "Button", true, false):
		if (button as Button).text == text and (button as Button).is_visible_in_tree():
			return button as Button
	return null


func test_the_five_buttons_are_one_row_in_order_and_big_enough() -> void:
	_start()
	var last_x := -1.0
	var row_y := _button("Play").position.y
	for text in ROW:
		var button := _button(text)
		assert_not_null(button, text)
		assert_almost_eq(button.position.y, row_y, 1.0, "%s is on the row" % text)
		assert_gt(button.position.x, last_x, "%s is right of the one before" % text)
		last_x = button.position.x
		assert_gte(button.custom_minimum_size.x, UiKit.ACTION_SIZE.x, text)
		assert_gte(button.custom_minimum_size.y, UiKit.ACTION_SIZE.y, text)
	assert_eq(_button("Play").theme_type_variation, &"ButtonGreen")
	assert_eq(_button("New game").theme_type_variation, &"ButtonRed")


func test_everything_fits_inside_the_screen_and_the_controls_do_not_overlap_each_other() -> void:
	_start()
	var rects := {"banner": HomeScreen.BANNER_RECT, "stage": _home.stage().get_global_rect(), "message": _home.message_rect()}
	for text in ROW + ["Achievements", "Full screen"]:
		rects[text] = _button(text).get_global_rect()
	for key in rects:
		assert_true(SCREEN.encloses(rects[key]), "%s %s is inside the screen" % [key, str(rects[key])])
	# The stage is the ground under everything below the banner, so the buttons and the message are meant to sit on it; everything else
	# must keep clear of everything else.
	var keys: Array = rects.keys().filter(func(k: String) -> bool: return k != "stage")
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			assert_false((rects[keys[i]] as Rect2).intersects(rects[keys[j]]), "%s and %s overlap" % [keys[i], keys[j]])
	assert_false((rects["stage"] as Rect2).intersects(rects["banner"]), "the stage starts below the banner")
	assert_false((rects["stage"] as Rect2).intersects(rects["Achievements"]) or (rects["stage"] as Rect2).intersects(rects["Full screen"]), "and below the corner buttons")


func test_the_grass_runs_to_the_bottom_of_the_screen_behind_the_buttons() -> void:
	_start()
	var stage_rect := _home.stage().get_global_rect()
	assert_eq(stage_rect.end.y, SCREEN.end.y, "no straight edge of grass above the buttons")
	assert_eq(stage_rect.size.x, SCREEN.size.x)
	for text in ROW:
		assert_true(stage_rect.encloses(_button(text).get_global_rect()), "%s sits on the grass" % text)
		assert_gt(_button(text).get_index(), _home.stage().get_index(), "%s draws over the stage" % text)
	assert_gt(_home.message_label().get_index(), _home.stage().get_index())


func test_the_banner_is_the_title_sprite_and_fits_its_rect() -> void:
	_start()
	var banner := SpriteLibrary.find(&"banner_title", &"base")
	assert_not_null(banner)
	assert_lte(Vector2(banner.frame_size).x, HomeScreen.BANNER_RECT.size.x)
	assert_lte(Vector2(banner.frame_size).y, HomeScreen.BANNER_RECT.size.y)


func test_the_stage_plays_the_home_fight_on_open() -> void:
	_start()
	assert_true(_home.stage().is_playing())
	assert_eq(_home.stage().stage_script().resource_path, "res://resources/stage/home_fight.tres")


func test_the_stage_stops_while_a_full_screen_is_open_and_resumes_after() -> void:
	_start()
	var openers := {
		"shop": [func() -> void: _home.open_shop(), func() -> void: _home.shop_screen().close()],
		"settings": [func() -> void: _home.open_settings(), func() -> void: _home.settings_screen().close()],
		"tutorial": [func() -> void: _home.open_tutorial(), func() -> void: _home.tutorial_screen().close()],
		"achievements": [func() -> void: _home.open_achievements(), func() -> void: _home.achievements_screen().close()],
		"map select": [func() -> void: _home.open_map_select(), func() -> void: _home.map_select_screen().close()],
		"new game": [func() -> void: _home.new_game(), func() -> void: _home.confirm_dialog()._cancel_now()],
	}
	for key in openers:
		openers[key][0].call()
		_home.sync_stage()
		assert_false(_home.stage().is_playing(), "%s covers the stage" % key)
		assert_false(_home.stage().is_processing(), key)
		openers[key][1].call()
		_home.sync_stage()
		assert_true(_home.stage().is_playing(), "the stage runs again after %s" % key)


func test_reduce_motion_shows_the_still_frame() -> void:
	# The home screen loads the saved settings when it opens, so the preset has to be in the settings file.
	FxSettings.reduce_motion()
	SettingsStore.save_file("%s/settings.json" % _dir)
	_start()
	assert_false(_home.stage().is_playing())
	assert_false(_home.stage().is_processing())
	_home.open_shop()
	_home.shop_screen().close()
	_home.sync_stage()
	assert_false(_home.stage().is_playing(), "closing a screen does not start motion the player turned off")


func _robe() -> EquipmentData:
	for item in EquipmentCatalog.default_catalog().items:
		if item.slot() == EquipmentData.Slot.ROBE and item.sprite_name != &"":
			return item
	return null


func test_the_wizard_wears_the_saved_equipment() -> void:
	var robe := _robe()
	var profile := PlayerProfile.new()
	profile.grant(robe.id)
	profile.equip(int(EquipmentData.Slot.ROBE), robe.id)
	SaveGame.save_profile(profile, "%s/save.json" % _dir)
	_start()
	var layer: AnimatedSprite2D = _home.stage().actor(&"wizard")._layers[&"robe"]
	var expected := SpriteLibrary.find(robe.sprite_name, robe.sprite_variant if robe.sprite_variant != &"" else &"base")
	var shown := (layer.sprite_frames.get_frame_texture(&"idle", 0) as AtlasTexture).atlas
	assert_eq(shown.resource_path, expected.sheet.resource_path, "the equipped robe's own sheet is on the wizard")


func test_a_change_in_the_shop_dresses_the_wizard_again() -> void:
	_start()
	var before: SpriteFrames = _home.stage().actor(&"wizard")._layers[&"robe"].sprite_frames
	var robe := _robe()
	_home.profile.grant(robe.id)
	_home.profile.equip(int(EquipmentData.Slot.ROBE), robe.id)
	_home.shop_screen().changed.emit()
	assert_ne(_home.stage().actor(&"wizard")._layers[&"robe"].sprite_frames, before)


func test_the_stage_and_banner_do_not_take_touches() -> void:
	_start()
	assert_eq(_home.stage().mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(240, 130)
	assert_true(_home.handle_input(touch), "a touch on the stage is bridged like any other and finds no button")


func test_opening_and_freeing_the_home_screen_repeatedly_leaves_no_orphans() -> void:
	var home := _make()
	add_child(home)
	await get_tree().process_frame
	home.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for i in 10:
		var again := _make()
		add_child(again)
		await get_tree().process_frame
		again.queue_free()
		await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), nodes_before, "ten rounds leave the same number of nodes")
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), orphans_before)
