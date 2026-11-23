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
