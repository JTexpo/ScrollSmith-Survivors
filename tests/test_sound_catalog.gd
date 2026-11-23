extends GutTest

var _saved_root: String


func before_each() -> void:
	_saved_root = SoundLibrary.root
	SoundLibrary.reset_warnings()


func after_each() -> void:
	SoundLibrary.root = _saved_root
	SoundLibrary.reset_warnings()


func _ids() -> Array[StringName]:
	var found: Array[StringName] = []
	var constants := (load("res://scripts/audio/sound_id.gd") as GDScript).get_script_constant_map()
	for key in constants:
		if constants[key] is StringName:
			found.append(constants[key])
	return found


func test_find_returns_data_or_null() -> void:
	var catalog := SoundCatalog.default_catalog()
	assert_not_null(catalog.find(SoundId.UI_CLICK))
	assert_null(catalog.find(&"no_such_sound"))


func test_every_catalog_entry_has_a_wav_and_every_sound_id_a_catalog_entry() -> void:
	var catalog := SoundCatalog.default_catalog()
	for data in catalog.sounds:
		assert_true(FileAccess.file_exists("res://assets/audio/%s.wav" % data.id), "%s has a wav" % data.id)
	for id in _ids():
		assert_not_null(catalog.find(id), "SoundId %s has a catalog entry" % id)
	for data in catalog.sounds:
		assert_true(_ids().has(data.id), "catalog entry %s has a SoundId constant" % data.id)


func test_ids_are_unique() -> void:
	var seen := {}
	for data in SoundCatalog.default_catalog().sounds:
		assert_false(seen.has(data.id), "%s repeats" % data.id)
		seen[data.id] = true


func test_default_numbers_are_sane() -> void:
	for data in SoundCatalog.default_catalog().sounds:
		assert_gte(data.max_voices, 1, str(data.id))
		assert_gte(data.min_gap_msec, 0, str(data.id))
		assert_gte(data.wobble, 0.0, str(data.id))
		assert_between(data.volume_db, -30.0, 6.0, str(data.id))


func test_library_finds_a_real_sound_and_caches_it() -> void:
	var first := SoundLibrary.find(SoundId.UI_CLICK)
	assert_not_null(first)
	assert_same(SoundLibrary.find(SoundId.UI_CLICK), first)
	assert_eq(SoundLibrary.warnings_issued, 0)


func test_library_returns_null_for_a_missing_sound_and_warns_once() -> void:
	assert_null(SoundLibrary.find(&"no_such_sound"))
	assert_null(SoundLibrary.find(&"no_such_sound"))
	assert_eq(SoundLibrary.warnings_issued, 1, "one warning, however often it is asked for")
	assert_true(SoundLibrary.has_warned(&"no_such_sound"))


func test_library_with_another_root_finds_nothing_there() -> void:
	SoundLibrary.root = "res://assets/no_such_folder"
	assert_null(SoundLibrary.find(SoundId.UI_CLICK))


const DESIGN_IDS: Array[StringName] = [&"cast_fire", &"cast_thunder", &"cast_land", &"cast_sea", &"hit_fire", &"hit_thunder", &"hit_land", &"hit_sea", &"hit_strong", &"hit_resisted", &"enemy_shot", &"blast_warn", &"blast_boom", &"enemy_die", &"enemy_die_big", &"enemy_die_elite", &"boss_spawn", &"boss_slam", &"boss_charge", &"boss_burst", &"boss_die", &"player_hurt", &"player_die", &"level_up", &"step", &"pickup_scroll", &"pickup_xp", &"pickup_gold", &"potion_drink", &"potion_refused", &"ui_click", &"ui_back", &"ui_hover", &"lectern_open", &"craft_confirm", &"craft_fail", &"shop_buy", &"shop_fail", &"shop_equip", &"shrine_heal", &"shrine_mana", &"chest_open", &"merchant_open", &"music_run"]


func _data(id: StringName) -> SoundData:
	return SoundCatalog.default_catalog().find(id)


func test_the_catalog_lists_every_sound_in_the_design() -> void:
	var listed: Array[StringName] = []
	for data in SoundCatalog.default_catalog().sounds:
		listed.append(data.id)
	listed.sort()
	var wanted := DESIGN_IDS.duplicate()
	wanted.sort()
	assert_eq(listed, wanted)
	var constants := _ids()
	constants.sort()
	assert_eq(constants, wanted, "every sound has a SoundId constant")


func test_hits_deaths_and_steps_are_low_priority_and_capped() -> void:
	for id in [&"hit_fire", &"hit_thunder", &"hit_land", &"hit_sea", &"hit_strong", &"hit_resisted", &"enemy_die", &"step", &"pickup_xp"]:
		var data := _data(id)
		assert_eq(data.priority, SoundData.Priority.LOW, str(id))
		assert_lte(data.max_voices, 4, str(id))
		assert_gt(data.min_gap_msec, 0, "%s has a gap" % id)


func test_the_important_sounds_are_not_low_priority() -> void:
	for id in [&"boss_spawn", &"boss_slam", &"boss_charge", &"boss_burst", &"boss_die", &"player_hurt", &"player_die", &"level_up", &"blast_warn", &"blast_boom", &"potion_refused", &"craft_confirm", &"shrine_heal", &"shrine_mana", &"chest_open"]:
		assert_ne(_data(id).priority, SoundData.Priority.LOW, str(id))


func test_the_loud_events_are_louder_than_the_busy_ones() -> void:
	assert_gt(_data(&"level_up").volume_db, _data(&"hit_fire").volume_db + 4.0)
	assert_gt(_data(&"boss_spawn").volume_db, _data(&"enemy_die").volume_db + 4.0)
	assert_lt(_data(&"step").volume_db, _data(&"hit_fire").volume_db, "footsteps are the quietest thing")


func test_ui_sounds_do_not_stop_when_paused() -> void:
	for id in [&"ui_click", &"ui_back", &"ui_hover", &"lectern_open", &"craft_confirm", &"craft_fail", &"shop_buy", &"shop_fail", &"shop_equip", &"merchant_open"]:
		assert_false(_data(id).pausable, str(id))
	for id in [&"cast_fire", &"hit_fire", &"enemy_die", &"step"]:
		assert_true(_data(id).pausable, str(id))
