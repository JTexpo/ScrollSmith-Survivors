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
	return stats


const MAP := &"first_map"


func _profile(seconds: int = 0, enemies: int = 0) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.set_best(MAP, seconds, enemies)
	return profile


func _row(rows: Array[Dictionary], label: String) -> Dictionary:
	for row in rows:
		if row["label"] == label:
			return row
	return {}


func test_rows_are_the_eight_stats_in_order() -> void:
	var rows := RunRecap.rows(_stats(), 307.0, _profile(), {}, true, MAP)
	var labels: Array = rows.map(func(row: Dictionary) -> String: return row["label"])
	assert_eq(labels, ["Time survived", "Enemies defeated", "Bosses defeated", "XP earned", "Gold earned", "Scrolls collected", "Spells crafted", "Potions drunk"])
	assert_eq(_row(rows, "Enemies defeated")["value"], "31")
	assert_eq(_row(rows, "Gold earned")["value"], "88")


func test_time_is_formatted_as_minutes_and_seconds() -> void:
	assert_eq(_row(RunRecap.rows(_stats(), 307.0, _profile(), {}, true, MAP), "Time survived")["value"], "5:07")


func test_a_saved_best_shows_as_best_text_for_the_three_that_have_one() -> void:
	var rows := RunRecap.rows(_stats(), 100.0, _profile(430, 60), {}, true, MAP)
	assert_eq(_row(rows, "Time survived")["best"], "best 7:10")
	assert_eq(_row(rows, "Enemies defeated")["best"], "best 60")
	assert_eq(_row(rows, "XP earned")["best"], "", "only two stats have a best")
	assert_eq(_row(rows, "Potions drunk")["best"], "")


func test_a_new_best_shows_the_mark_instead_of_the_best_text() -> void:
	var rows := RunRecap.rows(_stats(), 500.0, _profile(500, 31), {"seconds": true, "enemies": false}, true, MAP)
	var time := _row(rows, "Time survived")
	assert_true(time["new_best"])
	assert_eq(time["best"], "")
	assert_false(_row(rows, "Enemies defeated")["new_best"])


func test_no_new_best_mark_when_the_save_failed() -> void:
	var rows := RunRecap.rows(_stats(), 500.0, _profile(500, 31), {"seconds": true, "enemies": true}, false, MAP)
	for row in rows:
		assert_false(row["new_best"], row["label"])


func test_a_first_run_shows_its_best_without_the_mark() -> void:
	var rows := RunRecap.rows(_stats(), 120.0, _profile(120, 31), {"seconds": false, "enemies": false}, true, MAP)
	assert_eq(_row(rows, "Time survived")["best"], "best 2:00")
	assert_false(_row(rows, "Time survived")["new_best"])


func test_there_are_eight_rows_and_none_is_a_level_row() -> void:
	var rows := RunRecap.rows(_stats(), 10.0, _profile(), {}, true, MAP)
	assert_eq(rows.size(), 8)
	assert_true(_row(rows, "Level reached").is_empty())


func test_bests_come_from_the_given_map() -> void:
	var profile := _profile(430, 60)
	profile.set_best(&"maze", 70, 5)
	var maze := RunRecap.rows(_stats(), 10.0, profile, {}, true, &"maze")
	assert_eq(_row(maze, "Time survived")["best"], "best 1:10")
	assert_eq(_row(maze, "Enemies defeated")["best"], "best 5")
	var forest := RunRecap.rows(_stats(), 10.0, profile, {}, true, &"forest")
	assert_eq(_row(forest, "Time survived")["best"], "")
