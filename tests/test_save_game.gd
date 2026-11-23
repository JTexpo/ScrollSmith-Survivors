extends GutTest

const ROOT := "res://.godot/save_tests"

var _dir: String


func before_each() -> void:
	_dir = "%s/%s" % [ROOT, str(randi())]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))


func after_each() -> void:
	var absolute := ProjectSettings.globalize_path(_dir)
	for file in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute("%s/%s" % [absolute, file])
	DirAccess.remove_absolute(absolute)


func _path() -> String:
	return "%s/save.json" % _dir


func _write(text: String) -> void:
	var file := FileAccess.open(_path(), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func test_missing_file_gives_a_fresh_profile() -> void:
	var profile := SaveGame.load_profile(_path())
	assert_not_null(profile)
	assert_eq(profile.total_xp, 0)
	assert_false(FileAccess.file_exists(_path()))


func test_save_then_load_round_trips_xp() -> void:
	var profile := PlayerProfile.new()
	profile.add_xp(321)
	assert_true(SaveGame.save_profile(profile, _path()))
	assert_eq(SaveGame.load_profile(_path()).total_xp, 321)


func test_saved_file_has_no_buff_picks() -> void:
	SaveGame.save_profile(PlayerProfile.new(), _path())
	assert_false(_read(_path()).contains("buff_picks"))


func test_an_old_file_with_buff_picks_loads_and_loses_the_field_when_saved_again() -> void:
	_write('{"version": 1, "total_xp": 90, "buff_picks": {"7": "buff_damage"}}')
	var profile := SaveGame.load_profile(_path())
	assert_eq(profile.total_xp, 90)
	assert_false(FileAccess.file_exists(_path() + ".bak"))
	SaveGame.save_profile(profile, _path())
	assert_false(_read(_path()).contains("buff_picks"))


func test_large_xp_survives_exactly() -> void:
	var profile := PlayerProfile.new()
	profile.add_xp(3990000)
	SaveGame.save_profile(profile, _path())
	assert_eq(SaveGame.load_profile(_path()).total_xp, 3990000)


func test_save_leaves_no_temp_file() -> void:
	SaveGame.save_profile(PlayerProfile.new(), _path())
	assert_true(FileAccess.file_exists(_path()))
	assert_false(FileAccess.file_exists(_path() + ".tmp"))


func test_saving_again_replaces_the_old_file() -> void:
	var profile := PlayerProfile.new()
	profile.add_xp(10)
	SaveGame.save_profile(profile, _path())
	profile.add_xp(5)
	assert_true(SaveGame.save_profile(profile, _path()))
	assert_eq(SaveGame.load_profile(_path()).total_xp, 15)


func test_garbage_text_is_moved_to_bak_and_gives_fresh() -> void:
	_write("this is not json {{{")
	var profile := SaveGame.load_profile(_path())
	assert_eq(profile.total_xp, 0)
	assert_false(FileAccess.file_exists(_path()))
	assert_eq(_read(_path() + ".bak"), "this is not json {{{")


func test_empty_file_and_wrong_shape_and_newer_version_are_moved_to_bak() -> void:
	var bad := ["", "[1, 2, 3]", '{"version": 2, "total_xp": 5, "buff_picks": {}}',
		'{"version": 1, "total_xp": "5", "buff_picks": {}}', "null"]
	for text in bad:
		_write(text)
		var profile := SaveGame.load_profile(_path())
		assert_eq(profile.total_xp, 0, text)
		assert_false(FileAccess.file_exists(_path()), "moved: %s" % text)
		assert_eq(_read(_path() + ".bak"), text, "kept: %s" % text)


func test_failed_save_keeps_the_old_file_and_does_not_crash() -> void:
	var profile := PlayerProfile.new()
	profile.add_xp(40)
	SaveGame.save_profile(profile, _path())
	assert_false(SaveGame.save_profile(profile, "%s/missing_folder/save.json" % _dir))
	assert_eq(SaveGame.load_profile(_path()).total_xp, 40)


func test_a_second_bad_file_replaces_the_old_bak_without_error() -> void:
	_write("first bad")
	SaveGame.load_profile(_path())
	_write("second bad")
	SaveGame.load_profile(_path())
	assert_eq(_read(_path() + ".bak"), "second bad")


func test_gold_and_equipment_survive_save_and_load() -> void:
	var profile := PlayerProfile.new()
	profile.add_gold(321)
	profile.grant(&"robe_tide")
	profile.equip(0, &"robe_tide")
	assert_true(SaveGame.save_profile(profile, _path()))
	var loaded := SaveGame.load_profile(_path())
	assert_eq(loaded.gold, 321)
	assert_true(loaded.owns(&"robe_tide"))
	assert_eq(loaded.equipped_id(0), &"robe_tide")


func test_large_gold_survives_exactly() -> void:
	var profile := PlayerProfile.new()
	profile.add_gold(PlayerProfile.MAX_VALUE - 7)
	SaveGame.save_profile(profile, _path())
	assert_eq(SaveGame.load_profile(_path()).gold, PlayerProfile.MAX_VALUE - 7)


func test_a_save_with_a_bad_gold_field_is_kept_as_bak() -> void:
	_write('{"version": 1, "total_xp": 5, "gold": "lots"}')
	var profile := SaveGame.load_profile(_path())
	assert_eq(profile.gold, 0)
	assert_true(FileAccess.file_exists(_path() + ".bak"))


func test_potions_survive_save_and_load() -> void:
	var profile := PlayerProfile.new()
	profile.add_gold(10)
	profile.add_potion(&"potion_mana", 7)
	assert_true(SaveGame.save_profile(profile, _path()))
	var loaded := SaveGame.load_profile(_path())
	assert_eq(loaded.potion_count(&"potion_mana"), 7)
	assert_eq(loaded.gold, 10)


func test_a_save_with_a_bad_potions_field_is_kept_as_bak() -> void:
	_write('{"version": 1, "total_xp": 5, "gold": 9, "potions": {"potion_health": "lots"}}')
	var profile := SaveGame.load_profile(_path())
	assert_eq(profile.gold, 0)
	assert_true(FileAccess.file_exists(_path() + ".bak"))


func test_muted_survives_a_save_and_load() -> void:
	var profile := PlayerProfile.new()
	profile.muted = true
	assert_true(SaveGame.save_profile(profile, _path()))
	assert_true(SaveGame.load_profile(_path()).muted)
