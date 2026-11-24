extends GutTest
## The saved bests per map (longest survival, most enemies) and the rule for "New best!": only a beaten NON-zero best is a new best,
## so the first run on a map records its bests without shouting about them.

const MAP := &"first_map"


func _profile(seconds: int = 0, enemies: int = 0) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.set_best(MAP, seconds, enemies)
	return profile


func test_a_first_run_sets_the_bests_and_flags_nothing() -> void:
	var profile := _profile()
	var flags := RunRecords.update(profile, MAP, 40, 190.0)
	assert_eq(profile.best_seconds(MAP), 190)
	assert_eq(profile.best_enemies(MAP), 40)
	assert_eq(flags, {"seconds": false, "enemies": false})


func test_a_better_run_flags_exactly_the_beaten_stats() -> void:
	var profile := _profile(100, 30)
	var flags := RunRecords.update(profile, MAP, 30, 150.0)
	assert_eq(flags, {"seconds": true, "enemies": false})
	assert_eq(profile.best_seconds(MAP), 150)
	assert_eq(profile.best_enemies(MAP), 30)


func test_a_tie_flags_nothing_and_keeps_the_best() -> void:
	var profile := _profile(100, 30)
	var flags := RunRecords.update(profile, MAP, 30, 100.0)
	assert_eq(flags, {"seconds": false, "enemies": false})
	assert_eq(profile.best_seconds(MAP), 100)


func test_a_worse_run_changes_nothing() -> void:
	var profile := _profile(100, 30)
	RunRecords.update(profile, MAP, 3, 20.0)
	assert_eq(profile.best_seconds(MAP), 100)
	assert_eq(profile.best_enemies(MAP), 30)


func test_seconds_are_floored_to_whole_seconds() -> void:
	var profile := _profile()
	RunRecords.update(profile, MAP, 1, 59.99)
	assert_eq(profile.best_seconds(MAP), 59)


func test_each_stat_is_judged_on_its_own() -> void:
	var profile := _profile(100, 30)
	var flags := RunRecords.update(profile, MAP, 10, 400.0)
	assert_eq(flags, {"seconds": true, "enemies": false})
	assert_eq(profile.best_seconds(MAP), 400)
	assert_eq(profile.best_enemies(MAP), 30)


func test_a_record_on_one_map_never_touches_another_map() -> void:
	var profile := _profile(100, 30)
	RunRecords.update(profile, &"forest", 500, 900.0)
	assert_eq(profile.best_seconds(MAP), 100)
	assert_eq(profile.best_enemies(MAP), 30)
	assert_eq(profile.best_seconds(&"forest"), 900)


func test_a_first_run_on_a_new_map_flags_nothing_even_when_another_map_has_bests() -> void:
	var profile := _profile(100, 30)
	var flags := RunRecords.update(profile, &"maze", 2, 20.0)
	assert_eq(flags, {"seconds": false, "enemies": false})
