extends GutTest

var _board: SoundBoard
var _now: int = 0


func before_each() -> void:
	SoundLibrary.reset_warnings()
	_board = _make()


func after_each() -> void:
	_board.set_muted(false)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), 0.0)
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


func _key() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_A
	return event


func _touch() -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	return event


func _click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	return event


func test_music_does_not_start_before_the_first_input() -> void:
	_board.start_music()
	assert_eq(_board.music_state(), &"off")
	assert_eq(_board.music_starts(), 0)


func test_the_first_key_touch_or_click_unlocks_and_starts_the_run_loop() -> void:
	for event in [_key(), _touch(), _click()]:
		var board := _make()
		board._input(event)
		assert_true(board.is_unlocked(), str(event))
		assert_eq(board.music_state(), &"run", str(event))


func test_releasing_a_key_or_moving_the_mouse_does_not_unlock() -> void:
	var release := InputEventKey.new()
	release.pressed = false
	_board._input(release)
	_board._input(InputEventMouseMotion.new())
	assert_false(_board.is_unlocked())


func test_a_second_input_does_not_restart_the_music() -> void:
	_board._input(_key())
	_board._input(_key())
	_board._input(_click())
	assert_eq(_board.music_starts(), 1)


func test_boss_music_fades_in_and_out_and_the_run_loop_returns() -> void:
	_board._input(_key())
	var run_db := _board.music_target_db(&"run")
	_board.set_boss_music(true)
	assert_eq(_board.music_state(), &"boss")
	_board.advance_music(SoundBoard.CROSSFADE + 0.1)
	assert_almost_eq(_board.music_volume_db(&"boss"), _board.music_target_db(&"boss"), 0.01)
	assert_lt(_board.music_volume_db(&"run"), run_db - 30.0, "the run loop is faded under the boss loop")
	_board.set_boss_music(false)
	assert_eq(_board.music_state(), &"run")
	_board.advance_music(SoundBoard.CROSSFADE + 0.1)
	assert_almost_eq(_board.music_volume_db(&"run"), run_db, 0.01)
	assert_lt(_board.music_volume_db(&"boss"), -40.0)
	assert_false(_board.music_playing(&"boss"), "the boss loop is stopped once faded out, so the next boss starts it from the top")
	assert_true(_board.music_playing(&"run"))


func test_boss_music_twice_in_a_row_does_not_restart_it() -> void:
	_board._input(_key())
	_board.set_boss_music(true)
	_board.set_boss_music(true)
	assert_eq(_board.music_starts(), 2, "one start for the run loop and one for the boss loop")


func test_the_run_loop_keeps_playing_under_the_boss_loop_so_it_does_not_restart() -> void:
	_board._input(_key())
	_board.set_boss_music(true)
	assert_true(_board.music_playing(&"run"))
	_board.set_boss_music(false)
	assert_eq(_board.music_starts(), 2, "the run loop was not started again")


func test_pausing_lowers_the_music_and_unpausing_restores_it_without_restarting_it() -> void:
	_board._input(_key())
	_board.advance_music(0.1)
	assert_almost_eq(_board.music_bus_db(), 0.0, 0.01)
	get_tree().paused = true
	_board.advance_music(0.1)
	assert_almost_eq(_board.music_bus_db(), SoundBoard.PAUSED_MUSIC_DB, 0.01)
	get_tree().paused = false
	_board.advance_music(0.1)
	assert_almost_eq(_board.music_bus_db(), 0.0, 0.01)
	assert_eq(_board.music_starts(), 1, "no restart")
	assert_true(_board.music_playing(&"run"))


func test_muting_while_music_plays_and_unmuting_resumes_it() -> void:
	_board._input(_key())
	_board.set_muted(true)
	assert_eq(_board.music_state(), &"run")
	assert_true(_board.music_playing(&"run"), "the music runs silently, so it is where it should be on unmute")
	_board.set_muted(false)
	assert_eq(_board.music_starts(), 1)
	assert_true(_board.music_playing(&"run"))


func test_duck_lowers_then_restores_the_music() -> void:
	_board._input(_key())
	_board.duck(1.0, 12.0)
	assert_almost_eq(_board.music_bus_db(), -12.0, 0.01)
	_board.advance_music(0.5)
	assert_between(_board.music_bus_db(), -12.0, 0.0)
	_board.advance_music(0.6)
	assert_almost_eq(_board.music_bus_db(), 0.0, 0.01)


func test_losing_focus_pauses_the_music_and_gaining_it_resumes() -> void:
	_board._input(_key())
	_board._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(_board.music_stream_paused())
	_board._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_false(_board.music_stream_paused())
	_board._notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert_true(_board.music_stream_paused())
	_board._notification(NOTIFICATION_WM_WINDOW_FOCUS_IN)
	assert_false(_board.music_stream_paused())


func test_a_missing_music_stream_is_skipped_and_reported_once() -> void:
	var nothing := SoundCatalog.new()
	var board := _make(nothing)
	board._input(_key())
	board.start_music()
	assert_eq(board.music_state(), &"off")
	assert_true(SoundLibrary.has_warned(SoundId.MUSIC_RUN))
	assert_eq(SoundLibrary.warnings_issued, 1)


func test_a_controller_button_press_unlocks_sound_too() -> void:
	var event := InputEventJoypadButton.new()
	event.pressed = true
	event.button_index = JOY_BUTTON_A
	_board._input(event)
	assert_true(_board.is_unlocked())
	assert_eq(_board.music_state(), &"run")


func test_a_desktop_game_starts_unlocked_but_the_web_and_a_headless_run_wait_for_input() -> void:
	assert_true(SoundBoard.starts_unlocked(false, "macOS"))
	assert_false(SoundBoard.starts_unlocked(true, "web"), "a browser needs a tap, click or key first")
	assert_false(SoundBoard.starts_unlocked(false, "headless"), "tests and servers stay quiet")


func test_on_the_web_a_board_made_by_a_restart_keeps_the_pages_permission() -> void:
	SoundBoard.page_unlocked = true
	assert_true(SoundBoard.inherits_page_unlock(true))
	assert_false(SoundBoard.inherits_page_unlock(false), "only a browser remembers it")
	SoundBoard.page_unlocked = false
	assert_false(SoundBoard.inherits_page_unlock(true))


func test_a_voice_whose_player_stopped_without_a_finished_signal_is_released() -> void:
	_board.unlock()
	_board.play(SoundId.CAST_FIRE)
	assert_eq(_board.voices_in_use(), 1)
	for child in _board.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing:
			(child as AudioStreamPlayer).stop()
	_tick()
	_board.play(SoundId.CAST_THUNDER)
	assert_eq(_board.voices_in_use(), 1, "the dead voice was freed, so it does not leak for the rest of the run")


func test_the_mute_key_is_handled_by_the_board_which_keeps_running_while_paused() -> void:
	assert_eq(_board.process_mode, Node.PROCESS_MODE_ALWAYS)
	var press := InputEventAction.new()
	press.action = &"mute"
	press.pressed = true
	_board._unhandled_input(press)
	assert_true(_board.muted)
	_board._unhandled_input(press)
	assert_false(_board.muted)


func test_a_heavy_impact_plays_the_hit_lower_and_louder() -> void:
	_board.unlock()
	_board.bind_impacts()
	var config := ImpactConfig.default_config()
	ImpactEvents.bus.hit.emit(Vector2.ZERO, 1.0, &"thunder")
	assert_lt(_board.last_pitch_scale(), 1.0, "a heavy hit sounds lower (the small wobble can not undo the drop)")
	assert_almost_eq(_board.last_pitch_scale(), 1.0 - config.sound_pitch_drop, 1.5 / 12.0 * 1.5)
	assert_almost_eq(_board.last_volume_offset_db(), config.sound_volume_up_db, 0.001)
	_tick()
	ImpactEvents.bus.hit.emit(Vector2.ZERO, 0.0, &"thunder")
	assert_almost_eq(_board.last_volume_offset_db(), 0.0, 0.001)


func test_the_hit_event_names_the_element_of_the_hit_sound() -> void:
	var heard: Array[StringName] = []
	_board.requested.connect(func(id: StringName) -> void: heard.append(id))
	_board.bind_impacts()
	ImpactEvents.bus.hit.emit(Vector2.ZERO, 0.5, &"land")
	assert_true(heard.has(&"hit_land"))
	heard.clear()
	_tick()
	ImpactEvents.bus.hit.emit(Vector2.ZERO, 0.5, &"none")
	assert_true(heard.has(&"hit_fire"), "an unknown element falls back to the fire hit")
