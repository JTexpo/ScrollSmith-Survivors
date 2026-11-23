extends GutTest

var _board: SoundBoard
var _now: int = 0


func before_each() -> void:
	SoundLibrary.reset_warnings()
	_board = _make()


func after_each() -> void:
	_board.set_muted(false)
	AudioServer.set_bus_mute(0, false)
	get_tree().paused = false
	SoundLibrary.reset_warnings()


func _make(catalog: SoundCatalog = null) -> SoundBoard:
	var board := load("res://scenes/audio/sound_board.tscn").instantiate() as SoundBoard
	if catalog != null:
		board.catalog = catalog
	board.clock = func() -> int: return _now
	add_child_autofree(board)
	return board


func _tick(msec: int = 1000) -> void:
	_now += msec


func test_the_board_builds_a_fixed_pool_and_the_three_buses() -> void:
	assert_eq(_board.voice_count(), SoundBoard.VOICES)
	for bus_name in ["Master", "Music", "Sfx"]:
		assert_gte(AudioServer.get_bus_index(bus_name), 0, bus_name)
	var players := 0
	for child in _board.get_children():
		if child is AudioStreamPlayer:
			players += 1
	assert_gte(players, SoundBoard.VOICES)


func test_nothing_plays_before_unlock_and_nothing_errors() -> void:
	assert_false(_board.is_unlocked())
	_board.play(SoundId.CAST_FIRE)
	assert_eq(_board.voices_in_use(), 0)
	assert_eq(_board.calls_dropped(), 0, "a request before the unlock is ignored, not counted as a dropped crowd sound")


func test_play_takes_a_voice_after_unlock() -> void:
	_board.unlock()
	assert_true(_board.is_unlocked())
	_board.play(SoundId.CAST_FIRE)
	assert_eq(_board.voices_in_use(), 1)


func test_an_unknown_id_or_missing_stream_is_skipped_and_warns_once() -> void:
	_board.unlock()
	_board.play(&"no_such_sound")
	_board.play(&"no_such_sound")
	assert_eq(_board.voices_in_use(), 0)
	assert_eq(SoundLibrary.warnings_issued, 1)
	var ghost := SoundData.new()
	ghost.id = &"ghost"
	var catalog := SoundCatalog.new()
	catalog.sounds = [ghost] as Array[SoundData]
	var other := _make(catalog)
	other.unlock()
	other.play(&"ghost")
	other.play(&"ghost")
	assert_eq(other.voices_in_use(), 0)
	assert_true(SoundLibrary.has_warned(&"ghost"))
	assert_eq(SoundLibrary.warnings_issued, 2, "one warning per missing sound")


func test_muting_silences_play_and_mutes_the_master_bus_and_emits_mute_changed() -> void:
	_board.unlock()
	watch_signals(_board)
	_board.set_muted(true)
	assert_true(_board.muted)
	assert_true(AudioServer.is_bus_mute(0))
	assert_signal_emitted_with_parameters(_board, "mute_changed", [true])
	_board.play(SoundId.CAST_FIRE)
	assert_eq(_board.voices_in_use(), 0)
	_board.set_muted(false)
	assert_false(AudioServer.is_bus_mute(0))
	_board.play(SoundId.CAST_FIRE)
	assert_eq(_board.voices_in_use(), 1)


func test_a_pausable_sound_is_skipped_while_paused_and_a_ui_sound_is_not() -> void:
	_board.unlock()
	get_tree().paused = true
	_board.play(SoundId.CAST_FIRE)
	assert_eq(_board.voices_in_use(), 0)
	_board.play(SoundId.UI_CLICK)
	assert_eq(_board.voices_in_use(), 1)


func test_wobble_stays_inside_its_semitones_and_actually_varies() -> void:
	_board.unlock()
	var data := SoundCatalog.default_catalog().find(SoundId.HIT_FIRE)
	var low := pow(2.0, -data.wobble / 12.0)
	var high := pow(2.0, data.wobble / 12.0)
	var seen := {}
	for i in 60:
		_tick()
		_board.stop_all()
		_board.play(SoundId.HIT_FIRE)
		var pitch := _board.last_pitch_scale()
		assert_between(pitch, low - 0.0001, high + 0.0001)
		seen[snappedf(pitch, 0.001)] = true
	assert_gt(seen.size(), 10, "the pitch wobbles")


func test_the_pool_never_grows_under_a_flood_of_requests() -> void:
	_board.unlock()
	var before := _board.get_child_count()
	for i in 500:
		_board.play(SoundCatalog.default_catalog().sounds[i % 40].id)
	assert_eq(_board.get_child_count(), before)
	assert_lte(_board.voices_in_use(), SoundBoard.VOICES)
	assert_gt(_board.calls_dropped(), 0)


func test_a_music_entry_is_not_played_as_an_effect() -> void:
	_board.unlock()
	_board.play(SoundId.MUSIC_RUN)
	assert_eq(_board.voices_in_use(), 0)


func test_stop_all_frees_every_voice() -> void:
	_board.unlock()
	_board.play(SoundId.CAST_FIRE)
	_board.play(SoundId.UI_CLICK)
	assert_gt(_board.voices_in_use(), 0)
	_board.stop_all()
	assert_eq(_board.voices_in_use(), 0)

