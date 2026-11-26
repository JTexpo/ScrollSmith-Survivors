extends GutTest
## The tracker only listens: boss deaths, level-ups, Gold and the run clock decide unlocks, each unlock saves at once, and a
## held achievement never unlocks twice. Tests use a scratch save, never the real one.

const ROOT := "res://.godot/save_tests"

var _dir: String
var _catalog: AchievementCatalog
var _track: LevelTrack
var _profile: PlayerProfile
var _spawner: EnemySpawner
var _progress: RunProgress
var _saver: ProfileSaver
var _tracker: AchievementTracker
var _unlocked: Array[StringName] = []
var _seconds: float = 0.0


func before_each() -> void:
	_dir = "%s/ach_%s" % [ROOT, str(randi())]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_catalog = AchievementCatalog.default_catalog()
	_track = LevelTrack.default_track()
	_profile = PlayerProfile.new()
	_spawner = EnemySpawner.new()
	_progress = RunProgress.new()
	_saver = ProfileSaver.new()
	for node in [_spawner, _progress, _saver]:
		add_child_autofree(node)
	_saver.bind(_profile, _path())
	_unlocked = []
	_seconds = 0.0
	_tracker = _make_tracker(_profile)


func after_each() -> void:
	get_tree().paused = false
	var absolute := ProjectSettings.globalize_path(_dir)
	for file in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute("%s/%s" % [absolute, file])
	DirAccess.remove_absolute(absolute)


func _path() -> String:
	return _dir + "/save.json"


func _make_tracker(profile: PlayerProfile) -> AchievementTracker:
	var tracker := AchievementTracker.new()
	tracker.seconds_source = func() -> float: return _seconds
	add_child_autofree(tracker)
	tracker.bind(_catalog, profile, _track, _spawner, _progress, _saver)
	tracker.unlocked.connect(func(data: AchievementData) -> void: _unlocked.append(data.id))
	return tracker


func _boss(id: StringName) -> Boss:
	var boss := Boss.new()
	boss.data = BossData.new()
	boss.data.id = id
	autofree(boss)
	return boss


func _level_to(level: int) -> void:
	_profile.total_xp = _track.xp_for_level(level)
	_progress.leveled_up.emit(level, _track.reward_for_level(level))


func test_a_boss_death_unlocks_only_that_boss() -> void:
	_spawner.boss_died.emit(_boss(&"tempest_dragon"), 1)
	assert_eq(_unlocked, [&"defeat_tempest_dragon"] as Array[StringName])
	assert_true(_profile.has_achievement(&"defeat_tempest_dragon"))
	assert_false(_profile.has_achievement(&"defeat_ember_titan"))


func test_a_boss_death_with_no_data_unlocks_nothing() -> void:
	var bare := Boss.new()
	autofree(bare)
	_spawner.boss_died.emit(bare, 1)
	assert_eq(_unlocked.size(), 0)


func test_a_level_up_unlocks_each_threshold_it_crosses_in_order() -> void:
	_level_to(20)
	assert_eq(_unlocked, [&"reach_level_5", &"reach_level_10", &"reach_level_15", &"reach_level_20"] as Array[StringName])


func test_a_level_below_a_threshold_unlocks_nothing() -> void:
	_level_to(4)
	assert_eq(_unlocked.size(), 0)
	_level_to(5)
	assert_eq(_unlocked, [&"reach_level_5"] as Array[StringName])


func test_lifetime_gold_unlocks_at_1000_on_the_next_gold_event() -> void:
	_profile.earn_gold(999)
	_progress.gold_changed.emit(_profile.gold)
	assert_eq(_unlocked.size(), 0)
	_profile.earn_gold(1)
	_progress.gold_changed.emit(_profile.gold)
	assert_eq(_unlocked, [&"earn_gold_1000"] as Array[StringName])


func test_spending_gold_never_takes_the_progress_back() -> void:
	_profile.earn_gold(1000)
	_profile.spend_gold(1000)
	_progress.gold_changed.emit(_profile.gold)
	assert_eq(_unlocked, [&"earn_gold_1000"] as Array[StringName])


func test_survival_unlocks_as_the_clock_passes_each_threshold() -> void:
	_seconds = 299.0
	_tracker._process(1.0)
	assert_eq(_unlocked.size(), 0)
	_seconds = 300.0
	_tracker._process(1.0)
	assert_eq(_unlocked, [&"survive_5_minutes"] as Array[StringName])
	_seconds = 1250.0
	_tracker._process(1.0)
	assert_eq(_unlocked, [&"survive_5_minutes", &"survive_10_minutes", &"survive_15_minutes", &"survive_20_minutes"] as Array[StringName])


func test_the_clock_is_checked_once_a_second_not_every_frame() -> void:
	_seconds = 400.0
	_tracker._process(0.4)
	assert_eq(_unlocked.size(), 0)
	_tracker._process(0.4)
	assert_eq(_unlocked.size(), 0)
	_tracker._process(0.4)
	assert_eq(_unlocked.size(), 1)


func test_an_unlocked_achievement_never_unlocks_again() -> void:
	_spawner.boss_died.emit(_boss(&"ember_titan"), 1)
	_spawner.boss_died.emit(_boss(&"ember_titan"), 2)
	_level_to(5)
	_level_to(5)
	assert_eq(_unlocked.count(&"defeat_ember_titan"), 1)
	assert_eq(_unlocked.count(&"reach_level_5"), 1)
	assert_eq(_profile.achievements.count(&"defeat_ember_titan"), 1)


func test_a_second_tracker_over_a_reloaded_profile_does_not_unlock_it_again() -> void:
	_spawner.boss_died.emit(_boss(&"dire_minotaur"), 1)
	var reloaded := SaveGame.load_profile(_path())
	assert_true(reloaded.has_achievement(&"defeat_dire_minotaur"))
	var second_spawner := EnemySpawner.new()
	add_child_autofree(second_spawner)
	var again := AchievementTracker.new()
	add_child_autofree(again)
	again.bind(_catalog, reloaded, _track, second_spawner, _progress, _saver)
	var repeats: Array[StringName] = []
	again.unlocked.connect(func(data: AchievementData) -> void: repeats.append(data.id))
	second_spawner.boss_died.emit(_boss(&"dire_minotaur"), 1)
	assert_eq(repeats.size(), 0)


func test_every_unlock_is_saved_at_once() -> void:
	_spawner.boss_died.emit(_boss(&"tempest_dragon"), 1)
	var on_disk := SaveGame.load_profile(_path())
	assert_not_null(on_disk)
	assert_true(on_disk.has_achievement(&"defeat_tempest_dragon"), "the file holds it before the next frame")


func test_the_survival_clock_freezes_while_paused() -> void:
	var asked := [0]
	_tracker.seconds_source = func() -> float:
		asked[0] += 1
		return 400.0
	_tracker._since_check = AchievementTracker.CLOCK_STEP - 0.001
	get_tree().paused = true
	await get_tree().create_timer(0.2, true, false, true).timeout
	assert_eq(asked[0], 0, "a paused tree never runs the tracker's clock check")
	get_tree().paused = false
	await get_tree().create_timer(0.2, true, false, true).timeout
	assert_gt(asked[0], 0, "the same setup does check the clock once the tree runs again")


func test_stop_prevents_further_unlocks() -> void:
	_tracker.stop()
	_spawner.boss_died.emit(_boss(&"tempest_dragon"), 1)
	_level_to(20)
	_seconds = 2000.0
	_tracker._process(1.0)
	_profile.earn_gold(5000)
	_progress.gold_changed.emit(_profile.gold)
	assert_eq(_unlocked.size(), 0)
	assert_eq(_profile.achievements.size(), 0)


func test_sync_grants_level_survival_and_gold_silently() -> void:
	_profile.total_xp = _track.xp_for_level(10)
	_profile.set_best(&"first_map", 700, 30)
	_profile.lifetime_gold = 1500
	_tracker.sync()
	assert_eq(_unlocked.size(), 0, "no toast and no signal")
	for id in [&"reach_level_5", &"reach_level_10", &"survive_5_minutes", &"survive_10_minutes", &"earn_gold_1000"]:
		assert_true(_profile.has_achievement(id), String(id))
	assert_false(_profile.has_achievement(&"reach_level_15"))
	assert_false(_profile.has_achievement(&"survive_15_minutes"))
	assert_true(SaveGame.load_profile(_path()).has_achievement(&"reach_level_10"), "one save after a sync that granted something")


func test_sync_grants_no_boss_achievement_and_nothing_for_a_fresh_profile() -> void:
	_tracker.sync()
	assert_eq(_profile.achievements.size(), 0)
	_profile.total_xp = _track.xp_for_level(20)
	_profile.set_best(&"maze_map", 5000, 99)
	_tracker.sync()
	for id in [&"defeat_tempest_dragon", &"defeat_ember_titan", &"defeat_dire_minotaur"]:
		assert_false(_profile.has_achievement(id), String(id))


func test_earned_count_follows_the_profile() -> void:
	assert_eq(_tracker.earned_count(), 0)
	_level_to(5)
	assert_eq(_tracker.earned_count(), 1)


class CountingSaver extends ProfileSaver:
	var saves: int = 0

	func save_now() -> bool:
		saves += 1
		return super.save_now()


func test_a_jump_across_several_thresholds_saves_once_and_before_announcing() -> void:
	var counting := CountingSaver.new()
	add_child_autofree(counting)
	counting.bind(_profile, _path())
	var own_progress := RunProgress.new()
	var own_spawner := EnemySpawner.new()
	add_child_autofree(own_progress)
	add_child_autofree(own_spawner)
	var tracker := AchievementTracker.new()
	add_child_autofree(tracker)
	tracker.bind(_catalog, _profile, _track, own_spawner, own_progress, counting)
	var on_disk_when_announced: Array[bool] = []
	tracker.unlocked.connect(func(data: AchievementData) -> void: on_disk_when_announced.append(SaveGame.load_profile(_path()).has_achievement(data.id)))
	_profile.total_xp = _track.xp_for_level(20)
	own_progress.leveled_up.emit(20, _track.reward_for_level(20))
	assert_eq(counting.saves, 1, "four unlocks from one level-up write the file once")
	assert_eq(on_disk_when_announced, [true, true, true, true] as Array[bool], "saved before any announcement")


func test_stop_still_grants_a_survival_threshold_crossed_since_the_last_check() -> void:
	_seconds = 300.4
	_tracker.stop()
	assert_eq(_unlocked, [&"survive_5_minutes"] as Array[StringName], "surviving 5 minutes counts even if the player dies before the next check")
	_seconds = 1300.0
	_tracker._process(1.0)
	assert_eq(_unlocked.size(), 1, "and nothing more after stop")


func test_earned_count_ignores_ids_the_catalog_no_longer_has() -> void:
	_profile.grant_achievement(&"removed_in_a_later_version")
	assert_eq(_tracker.earned_count(), 0)
	_level_to(5)
	assert_eq(_tracker.earned_count(), 1)

