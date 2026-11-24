extends GutTest
## The three saved bests (longest survival, most enemies, highest level) and the rule for "New best!": only a beaten NON-zero best is a
## new best, so the first run records its bests without shouting about them.


func _profile(seconds: int = 0, enemies: int = 0, level: int = 0) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.best_seconds = seconds
	profile.best_enemies = enemies
	profile.best_level = level
	return profile


func test_a_first_run_sets_the_bests_and_flags_nothing() -> void:
	var profile := _profile()
	var flags := RunRecords.update(profile, 40, 6, 190.0)
	assert_eq(profile.best_seconds, 190)
	assert_eq(profile.best_enemies, 40)
	assert_eq(profile.best_level, 6)
	assert_eq(flags, {"seconds": false, "enemies": false, "level": false})


func test_a_better_run_flags_exactly_the_beaten_stats() -> void:
	var profile := _profile(100, 30, 5)
	var flags := RunRecords.update(profile, 50, 5, 150.0)
	assert_eq(flags, {"seconds": true, "enemies": true, "level": false})
	assert_eq(profile.best_seconds, 150)
	assert_eq(profile.best_enemies, 50)
	assert_eq(profile.best_level, 5)


func test_a_tie_flags_nothing_and_keeps_the_best() -> void:
	var profile := _profile(100, 30, 5)
	var flags := RunRecords.update(profile, 30, 5, 100.0)
	assert_eq(flags, {"seconds": false, "enemies": false, "level": false})
	assert_eq(profile.best_seconds, 100)


func test_a_worse_run_changes_nothing() -> void:
	var profile := _profile(100, 30, 5)
	RunRecords.update(profile, 3, 1, 20.0)
	assert_eq(profile.best_seconds, 100)
	assert_eq(profile.best_enemies, 30)
	assert_eq(profile.best_level, 5)


func test_seconds_are_floored_to_whole_seconds() -> void:
	var profile := _profile()
	RunRecords.update(profile, 1, 1, 59.99)
	assert_eq(profile.best_seconds, 59)


func test_each_stat_is_judged_on_its_own() -> void:
	var profile := _profile(100, 30, 5)
	var flags := RunRecords.update(profile, 10, 2, 400.0)
	assert_eq(flags, {"seconds": true, "enemies": false, "level": false})
	assert_eq(profile.best_seconds, 400)
	assert_eq(profile.best_enemies, 30)
