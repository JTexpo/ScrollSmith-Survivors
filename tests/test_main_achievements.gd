extends GutTest
## Achievements inside a real run: unlocks toast, chime and save; earned boss spells appear at run start; old saves sync silently.
## Every test uses a scratch save, never the real one.

const ROOT := "res://.godot/save_tests"

var _dir: String
var _track: LevelTrack


func before_each() -> void:
	_dir = "%s/main_ach_%s" % [ROOT, str(randi())]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_track = LevelTrack.default_track()


func after_each() -> void:
	get_tree().paused = false
	GameTime.unfreeze()
	var absolute := ProjectSettings.globalize_path(_dir)
	for file in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute("%s/%s" % [absolute, file])
	DirAccess.remove_absolute(absolute)


func _path() -> String:
	return _dir + "/save.json"


func _new_main(save_path: String) -> Main:
	var main := load("res://scenes/main/main.tscn").instantiate() as Main
	main.save_path = save_path
	(main.get_node("BuffPickScreen") as BuffPickScreen).pause_tree = false
	add_child_autofree(main)
	return main


func _save(profile: PlayerProfile) -> void:
	assert_true(SaveGame.save_profile(profile, _path()))


func _kill_the_first_boss(main: Main) -> void:
	var director := main.get_node("RunDirector") as RunDirector
	director.tick(300.0)
	var boss := director.current_boss()
	boss.set_physics_process(false)
	(boss.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1.0e9, Vector2.ZERO)


func _toast(main: Main) -> AchievementToast:
	return main.get_node("Hud/AchievementToast") as AchievementToast


func _spell_id(main: Main, slot: int) -> StringName:
	var instance := (main.get_node("Player") as Player).loadout.slots[slot]
	return instance.data.id if instance != null else &""


func test_a_boss_defeat_in_main_unlocks_toasts_and_saves() -> void:
	var main := _new_main(_path())
	_kill_the_first_boss(main)
	assert_true(main.profile.has_achievement(&"defeat_ember_titan"), "the ruins send the Ember Titan first")
	assert_true(_toast(main).is_showing())
	assert_eq(_toast(main).text, "Achievement unlocked: defeat the Ember Titan")
	assert_true(SaveGame.load_profile(_path()).has_achievement(&"defeat_ember_titan"), "saved at once, not at the next autosave")


func test_a_run_without_a_save_path_keeps_the_unlock_in_memory_only() -> void:
	var main := _new_main("")
	_kill_the_first_boss(main)
	assert_true(main.profile.has_achievement(&"defeat_ember_titan"))
	assert_false(FileAccess.file_exists(_path()))


func test_the_chime_plays_when_an_achievement_unlocks() -> void:
	var main := _new_main(_path())
	var board := main.get_node("SoundBoard") as SoundBoard
	var heard: Array[StringName] = []
	board.requested.connect(func(id: StringName) -> void: heard.append(id))
	_kill_the_first_boss(main)
	assert_true(heard.has(SoundId.ACHIEVEMENT), "the board found the tracker (it is made before the board binds)")


func test_a_run_applies_earned_boss_spells_at_the_start() -> void:
	var profile := PlayerProfile.new()
	profile.total_xp = _track.xp_for_level(10)
	profile.grant_achievement(&"defeat_tempest_dragon")
	_save(profile)
	var main := _new_main(_path())
	assert_eq(_spell_id(main, 2), &"thunder_zone")
	assert_eq(_spell_id(main, 0), &"fire_missile")


func test_a_level_nine_run_does_not_get_it() -> void:
	var profile := PlayerProfile.new()
	profile.total_xp = _track.xp_for_level(9)
	profile.grant_achievement(&"defeat_tempest_dragon")
	_save(profile)
	var main := _new_main(_path())
	assert_eq(_spell_id(main, 2), &"", "slot 3 unlocks at level 10")


func test_an_old_save_is_synced_silently_at_load() -> void:
	var profile := PlayerProfile.new()
	profile.total_xp = _track.xp_for_level(10)
	profile.set_best(&"first_map", 700, 30)
	profile.add_gold(1500)
	var data := profile.to_dict()
	data.erase("lifetime_gold")
	var file := FileAccess.open(_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var main := _new_main(_path())
	for id in [&"reach_level_5", &"reach_level_10", &"survive_5_minutes", &"survive_10_minutes", &"earn_gold_1000"]:
		assert_true(main.profile.has_achievement(id), String(id))
	assert_false(main.profile.has_achievement(&"reach_level_15"))
	assert_false(_toast(main).is_showing(), "an old save's unlocks never toast")


func test_dying_stops_further_unlocks() -> void:
	var main := _new_main(_path())
	(main.get_node("Player") as Player).health.take_damage(1.0e9)
	var boss := Boss.new()
	boss.data = load("res://resources/bosses/ember_titan.tres") as BossData
	autofree(boss)
	(main.get_node("EnemySpawner") as EnemySpawner).boss_died.emit(boss, 1)
	assert_false(main.profile.has_achievement(&"defeat_ember_titan"))


func test_two_runs_in_a_row_do_not_unlock_twice() -> void:
	var first := _new_main(_path())
	_kill_the_first_boss(first)
	assert_true(SaveGame.load_profile(_path()).has_achievement(&"defeat_ember_titan"))
	var second := _new_main(_path())
	assert_true(second.profile.has_achievement(&"defeat_ember_titan"), "loaded from the save")
	var unlocks := [0]
	second.achievement_tracker.unlocked.connect(func(_data: AchievementData) -> void: unlocks[0] += 1)
	_kill_the_first_boss(second)
	assert_eq(unlocks[0], 0)
	assert_eq(SaveGame.load_profile(_path()).achievements.count(&"defeat_ember_titan"), 1)


func test_lifetime_gold_counts_what_a_run_collects() -> void:
	var main := _new_main(_path())
	(main.get_node("Player") as Player).progress.add_gold(250)
	assert_eq(main.profile.lifetime_gold, 250)
	(main.get_node("Player") as Player).progress.add_gold(800)
	assert_true(main.profile.has_achievement(&"earn_gold_1000"))
	assert_true(_toast(main).is_showing())
