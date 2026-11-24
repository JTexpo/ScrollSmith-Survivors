extends GutTest


func _stats() -> RunStats:
	var stats := RunStats.new()
	stats.enemies = 31
	stats.bosses = 1
	stats.scrolls = 12
	stats.crafts = 3
	stats.potions = 4
	stats.xp = 250
	stats.gold = 88
	stats.level = 7
	return stats


func _profile(seconds: int = 0, enemies: int = 0, level: int = 0) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.best_seconds = seconds
	profile.best_enemies = enemies
	profile.best_level = level
	return profile


func _row(rows: Array[Dictionary], label: String) -> Dictionary:
	for row in rows:
		if row["label"] == label:
			return row
	return {}


func test_rows_are_the_nine_stats_in_order() -> void:
	var rows := RunRecap.rows(_stats(), 307.0, _profile(), {}, true)
	var labels: Array = rows.map(func(row: Dictionary) -> String: return row["label"])
	assert_eq(labels, ["Time survived", "Enemies defeated", "Bosses defeated", "Level reached", "XP earned", "Gold earned", "Scrolls collected", "Spells crafted", "Potions drunk"])
	assert_eq(_row(rows, "Enemies defeated")["value"], "31")
	assert_eq(_row(rows, "Gold earned")["value"], "88")


func test_time_is_formatted_as_minutes_and_seconds() -> void:
	assert_eq(_row(RunRecap.rows(_stats(), 307.0, _profile(), {}, true), "Time survived")["value"], "5:07")


func test_a_saved_best_shows_as_best_text_for_the_three_that_have_one() -> void:
	var rows := RunRecap.rows(_stats(), 100.0, _profile(430, 60, 9), {}, true)
	assert_eq(_row(rows, "Time survived")["best"], "best 7:10")
	assert_eq(_row(rows, "Enemies defeated")["best"], "best 60")
	assert_eq(_row(rows, "Level reached")["best"], "best 9")
	assert_eq(_row(rows, "XP earned")["best"], "", "only three stats have a best")
	assert_eq(_row(rows, "Potions drunk")["best"], "")


func test_a_new_best_shows_the_mark_instead_of_the_best_text() -> void:
	var rows := RunRecap.rows(_stats(), 500.0, _profile(500, 31, 7), {"seconds": true, "enemies": false, "level": false}, true)
	var time := _row(rows, "Time survived")
	assert_true(time["new_best"])
	assert_eq(time["best"], "")
	assert_false(_row(rows, "Enemies defeated")["new_best"])


func test_no_new_best_mark_when_the_save_failed() -> void:
	var rows := RunRecap.rows(_stats(), 500.0, _profile(500, 31, 7), {"seconds": true, "enemies": true, "level": true}, false)
	for row in rows:
		assert_false(row["new_best"], row["label"])


func test_a_first_run_shows_its_best_without_the_mark() -> void:
	var rows := RunRecap.rows(_stats(), 120.0, _profile(120, 31, 7), {"seconds": false, "enemies": false, "level": false}, true)
	assert_eq(_row(rows, "Time survived")["best"], "best 2:00")
	assert_false(_row(rows, "Time survived")["new_best"])
