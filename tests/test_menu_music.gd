extends GutTest
## The home screen has its own sound board: the menu tune, the button sounds, the saved mute and the sliders. The run's board is unchanged.

const ROOT := "res://.godot/save_tests"

var _dir: String
var _board: SoundBoard


func before_each() -> void:
	SoundLibrary.reset_warnings()
	GameSettings.reset()
	GameSettings.music_volume = 1.0
	GameSettings.sfx_volume = 1.0
	_dir = "%s/menu_music_%s" % [ROOT, str(randi())]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))


func after_each() -> void:
	get_tree().paused = false
	GameSettings.reset()
	AudioServer.set_bus_mute(0, false)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), 0.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Sfx"), 0.0)
	SoundLibrary.reset_warnings()
	var absolute := ProjectSettings.globalize_path(_dir)
	for file in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute("%s/%s" % [absolute, file])
	DirAccess.remove_absolute(absolute)


func _make_board(profile: PlayerProfile = null) -> SoundBoard:
	var board := load("res://scenes/audio/sound_board.tscn").instantiate() as SoundBoard
	add_child_autofree(board)
	var host := Control.new()
	host.add_child(Button.new())
	add_child_autofree(host)
	board.bind_home(host, profile if profile != null else PlayerProfile.new())
	return board


func _home() -> HomeScreen:
	var home := (load("res://scenes/home/home.tscn") as PackedScene).instantiate() as HomeScreen
	home.scene_changer = func(_path: String) -> Error: return OK
	home.save_path = "%s/save.json" % _dir
	home.settings_path = "%s/settings.json" % _dir
	add_child_autofree(home)
	return home


func _menu_player(board: SoundBoard) -> AudioStreamPlayer:
	for child in board.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).stream != null and (child as AudioStreamPlayer).playing and (child as AudioStreamPlayer).bus == &"Music":
			return child as AudioStreamPlayer
	return null


func _m_key() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"mute"
	event.pressed = true
	return event


func test_the_menu_board_starts_the_tune_once_when_unlocked() -> void:
	_board = _make_board()
	_board.unlock()
	_board.start_menu_music()
	_board.start_menu_music()
	assert_eq(_board.music_starts(), 1, "the tune starts once")
	assert_eq(_board.music_state(), &"menu")
	assert_true(_board.music_playing(&"menu"))
	assert_false(_board.music_playing(&"run"), "never the run tune on the menu")
	assert_false(_board.music_playing(&"boss"))


func test_it_waits_for_the_first_press_on_the_web_path() -> void:
	_board = _make_board()
	assert_false(_board.is_unlocked(), "a headless run stands in for a browser: nothing unlocks it by itself")
	assert_eq(_board.music_state(), &"off")
	assert_eq(_board.music_starts(), 0)
	var press := InputEventKey.new()
	press.pressed = true
	press.keycode = KEY_SPACE
	_board._input(press)
	assert_true(_board.is_unlocked())
	assert_eq(_board.music_state(), &"menu", "the first press unlocks sound and starts the menu tune, not the run tune")
	assert_eq(_board.music_starts(), 1)


func test_it_plays_on_the_music_bus_and_follows_the_music_slider() -> void:
	_board = _make_board()
	_board.unlock()
	_board.start_menu_music()
	var player := _menu_player(_board)
	assert_not_null(player)
	assert_eq(player.bus, &"Music")
	GameSettings.music_volume = 0.25
	SettingsEvents.announce()
	assert_almost_eq(_board.music_bus_db(), linear_to_db(0.25), 0.01)
	GameSettings.music_volume = 0.0
	SettingsEvents.announce()
	assert_lte(_board.music_bus_db(), SoundBoard.SILENT_DB + 0.01, "a slider at 0 silences it")


func test_a_saved_mute_silences_it_and_a_saved_unmuted_state_unmutes_the_bus() -> void:
	var profile := PlayerProfile.new()
	profile.muted = true
	_board = _make_board(profile)
	assert_true(AudioServer.is_bus_mute(0))
	assert_true(_board.muted)
	var unmuted := PlayerProfile.new()
	var second := _make_board(unmuted)
	assert_false(AudioServer.is_bus_mute(0), "a profile that is not muted clears a mute an earlier scene left on the shared bus")
	assert_false(second.muted)


func test_the_home_scene_has_a_board_that_plays_the_menu_tune_and_the_buttons_click() -> void:
	var home := _home()
	var board := home.sound_board()
	assert_not_null(board)
	board.unlock()
	board.start_menu_music()
	assert_eq(board.music_state(), &"menu")
	var heard: Array[StringName] = []
	board.requested.connect(func(id: StringName) -> void: heard.append(id))
	for button in home.find_children("*", "Button", true, false):
		if (button as Button).text == "Shop":
			(button as Button).pressed.emit()
	assert_true(heard.has(SoundId.UI_CLICK), "a home button clicks")
	var red: Button = null
	for button in home.find_children("*", "Button", true, false):
		if (button as Button).text == "New game":
			red = button as Button
	red.pressed.emit()
	assert_true(heard.has(SoundId.UI_BACK), "a red button sounds like back")


func test_pressing_m_on_the_home_screen_saves_the_mute_and_a_run_then_starts_in_the_same_state() -> void:
	var home := _home()
	home.sound_board()._unhandled_input(_m_key())
	assert_true(AudioServer.is_bus_mute(0))
	assert_true(SaveGame.load_profile("%s/save.json" % _dir).muted, "the home screen saved the mute")
	var main := load("res://scenes/main/main.tscn").instantiate() as Main
	main.save_path = "%s/save.json" % _dir
	(main.get_node("BuffPickScreen") as BuffPickScreen).pause_tree = false
	add_child_autofree(main)
	var run_board := main.get_node("SoundBoard") as SoundBoard
	assert_true(run_board.muted, "the run starts muted too")
	assert_true(AudioServer.is_bus_mute(0))
	run_board.set_muted(false)
	assert_false(SaveGame.load_profile("%s/save.json" % _dir).muted, "and unmuting in the run saves as before")


func test_freeing_the_home_screen_stops_the_music() -> void:
	var home := _home()
	var board := home.sound_board()
	board.unlock()
	board.start_menu_music()
	var player := _menu_player(board)
	assert_not_null(player)
	home.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(player), "the player went with the board, so nothing plays after leaving the menu")


func test_the_run_board_never_plays_the_menu_tune() -> void:
	var main := load("res://scenes/main/main.tscn").instantiate() as Main
	main.save_path = ""
	(main.get_node("BuffPickScreen") as BuffPickScreen).pause_tree = false
	add_child_autofree(main)
	var board := main.get_node("SoundBoard") as SoundBoard
	board.unlock()
	board.start_music()
	assert_eq(board.music_state(), &"run")
	assert_false(board.music_playing(&"menu"))


func test_the_menu_tune_is_a_little_quieter_than_the_run_tune_and_in_the_catalog() -> void:
	var catalog := SoundCatalog.default_catalog()
	var menu := catalog.find(SoundId.MUSIC_MENU)
	var run := catalog.find(SoundId.MUSIC_RUN)
	assert_not_null(menu)
	assert_true(menu.music)
	assert_false(menu.pausable)
	assert_lt(menu.volume_db, run.volume_db)
	assert_gt(menu.volume_db, run.volume_db - 8.0)


func test_the_home_screen_is_the_only_other_scene_with_a_board() -> void:
	var count := 0
	for path in ["res://scenes/home/home.tscn", "res://scenes/main/main.tscn", "res://scenes/main/main_forest.tscn", "res://scenes/main/main_maze.tscn"]:
		var scene := load(path) as PackedScene
		var state := scene.get_state()
		var has_board := false
		for i in state.get_node_count():
			if state.get_node_name(i) == &"SoundBoard":
				has_board = true
		if has_board:
			count += 1
	assert_gte(count, 2, "the home scene and the run scene each have a board (the forest and maze scenes inherit the run's)")
