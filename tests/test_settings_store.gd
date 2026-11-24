extends GutTest

const ROOT := "res://.godot/save_tests"

var _dir: String


func before_each() -> void:
	_dir = "%s/settings_%s" % [ROOT, str(randi())]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	GameSettings.reset()
	FxSettings.reset()


func after_each() -> void:
	GameSettings.reset()
	FxSettings.reset()
	var absolute := ProjectSettings.globalize_path(_dir)
	for file in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute("%s/%s" % [absolute, file])
	DirAccess.remove_absolute(absolute)


func _path() -> String:
	return "%s/settings.json" % _dir


func _write(text: String) -> void:
	var file := FileAccess.open(_path(), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_a_missing_file_gives_defaults() -> void:
	GameSettings.music_volume = 0.1
	FxSettings.particles = false
	SettingsStore.load_file(_path())
	assert_eq(GameSettings.music_volume, 0.8)
	assert_true(FxSettings.particles)


func test_save_then_load_round_trips_volumes_and_every_fx_switch_including_the_overlay() -> void:
	GameSettings.music_volume = 0.25
	GameSettings.sfx_volume = 0.5
	FxSettings.shake_scale = 0.5
	FxSettings.particles = false
	FxSettings.perf_overlay = true
	assert_true(SettingsStore.save_file(_path()))
	GameSettings.reset()
	FxSettings.reset()
	SettingsStore.load_file(_path())
	assert_almost_eq(GameSettings.music_volume, 0.25, 0.0001)
	assert_almost_eq(GameSettings.sfx_volume, 0.5, 0.0001)
	assert_almost_eq(FxSettings.shake_scale, 0.5, 0.0001)
	assert_false(FxSettings.particles)
	assert_true(FxSettings.perf_overlay)


func test_a_bad_file_is_kept_as_bak_and_defaults_are_used() -> void:
	_write("this is not json")
	GameSettings.music_volume = 0.1
	SettingsStore.load_file(_path())
	assert_eq(GameSettings.music_volume, 0.8)
	assert_true(FileAccess.file_exists(_path() + ".bak"))
	assert_false(FileAccess.file_exists(_path()))


func test_unknown_and_mistyped_values_are_ignored() -> void:
	_write(JSON.stringify({"version": SettingsStore.VERSION, "audio": {"music": "x", "sfx": 0.4, "extra": 1}, "fx": {"particles": "no", "heart_beat": false}, "other": 5}))
	SettingsStore.load_file(_path())
	assert_eq(GameSettings.music_volume, 0.8)
	assert_almost_eq(GameSettings.sfx_volume, 0.4, 0.0001)
	assert_true(FxSettings.particles)
	assert_false(FxSettings.heart_beat)


func test_a_wrong_version_is_treated_as_bad() -> void:
	_write(JSON.stringify({"version": 99, "audio": {"music": 0.1}}))
	SettingsStore.load_file(_path())
	assert_eq(GameSettings.music_volume, 0.8)
	assert_true(FileAccess.file_exists(_path() + ".bak"))


func test_apply_saved_announces_once() -> void:
	var count := [0]
	var listener := func() -> void: count[0] += 1
	SettingsEvents.bus.changed.connect(listener)
	SettingsStore.apply_saved(_path())
	SettingsEvents.bus.changed.disconnect(listener)
	assert_eq(count[0], 1)


func test_the_save_is_atomic_no_tmp_file_is_left() -> void:
	assert_true(SettingsStore.save_file(_path()))
	assert_false(FileAccess.file_exists(_path() + ".tmp"))
	assert_true(FileAccess.file_exists(_path()))


func test_last_map_round_trips_through_the_file() -> void:
	GameSettings.last_map = &"maze"
	assert_true(SettingsStore.save_file(_path()))
	GameSettings.reset()
	SettingsStore.load_file(_path())
	assert_eq(GameSettings.last_map, &"maze")


func test_a_file_with_no_play_object_loads_the_default_map() -> void:
	_write(JSON.stringify({"version": SettingsStore.VERSION, "audio": {"music": 0.5}}))
	SettingsStore.load_file(_path())
	assert_eq(GameSettings.last_map, GameSettings.DEFAULT_MAP)
	assert_almost_eq(GameSettings.music_volume, 0.5, 0.0001, "an old settings file still loads its audio")


func test_a_play_object_of_the_wrong_type_is_ignored() -> void:
	_write(JSON.stringify({"version": SettingsStore.VERSION, "play": "maze"}))
	SettingsStore.load_file(_path())
	assert_eq(GameSettings.last_map, GameSettings.DEFAULT_MAP)
	_write(JSON.stringify({"version": SettingsStore.VERSION, "play": {"last_map": 7}}))
	SettingsStore.load_file(_path())
	assert_eq(GameSettings.last_map, GameSettings.DEFAULT_MAP)
