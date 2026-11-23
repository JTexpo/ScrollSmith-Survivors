extends GutTest

var _scene: SoundTest


func before_each() -> void:
	_scene = load("res://scenes/world/sound_test.tscn").instantiate() as SoundTest
	add_child_autofree(_scene)


func after_each() -> void:
	_scene.stop_all()


func test_there_is_a_button_for_every_catalog_entry() -> void:
	assert_eq(_scene.sound_count(), SoundCatalog.default_catalog().sounds.size())


func test_playing_a_sound_starts_it_and_stop_stops_it() -> void:
	_scene.play(SoundId.CAST_FIRE)
	assert_true(_scene.is_playing())
	_scene.stop_all()
	assert_false(_scene.is_playing())


func test_a_tune_toggles_off_when_played_again() -> void:
	_scene.play(SoundId.MUSIC_RUN)
	assert_true(_scene.is_playing())
	_scene.play(SoundId.MUSIC_RUN)
	assert_false(_scene.is_playing())


func test_an_unknown_sound_is_reported_not_a_crash() -> void:
	_scene.play(&"no_such_sound")
	assert_false(_scene.is_playing())


func test_every_catalog_sound_plays() -> void:
	for data in SoundCatalog.default_catalog().sounds:
		_scene.play(data.id)
		assert_true(_scene.is_playing(), str(data.id))
		_scene.stop_all()
