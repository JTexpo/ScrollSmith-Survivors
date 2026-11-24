extends GutTest


func test_summarize_average_and_fps() -> void:
	var report := StressReport.summarize([16.0, 16.0, 16.0, 16.0] as Array[float])
	assert_eq(report["avg_ms"], 16.0)
	assert_almost_eq(report["avg_fps"] as float, 62.5, 0.01)


func test_summarize_p99_picks_worst_tail() -> void:
	var frames: Array[float] = []
	for i in 99:
		frames.append(10.0)
	frames.append(100.0)
	var report := StressReport.summarize(frames)
	assert_eq(report["p99_ms"], 100.0)


func test_summarize_empty_is_safe() -> void:
	var report := StressReport.summarize([] as Array[float])
	assert_eq(report["avg_ms"], 0.0)
	assert_eq(report["avg_fps"], 0.0)
	assert_eq(report["p99_ms"], 0.0)


func test_stress_scene_spawns_requested_enemies() -> void:
	var scene := load("res://scenes/world/stress_test.tscn").instantiate() as StressTest
	scene.enemy_count = 20
	add_child_autofree(scene)
	await wait_physics_frames(3)
	var count := 0
	for child in scene.get_children():
		if child is Enemy:
			count += 1
	assert_eq(count, 20)


func test_a_known_map_id_gives_that_map() -> void:
	for id in [&"forest", &"first_map", &"maze"]:
		var found := StressTest.map_for_id(String(id))
		assert_eq(found["map"].id, id)
		assert_eq(found["problem"], "")


func test_an_unknown_map_id_is_reported_and_the_default_kept() -> void:
	var found := StressTest.map_for_id("nowhere")
	assert_eq(found["map"].id, &"first_map", "the ruins stay the default stress map")
	assert_string_contains(found["problem"], "nowhere")
	assert_string_contains(found["problem"], "forest, first_map, maze", "the valid ids are listed")
	assert_eq(StressTest.map_for_id("")["problem"], "", "no --map is not a problem")


func test_the_stress_scene_sends_the_maps_own_boss() -> void:
	var scene := load("res://scenes/world/stress_test.tscn").instantiate() as StressTest
	scene.enemy_count = 5
	scene.map_id = "forest"
	scene.obstacles = true
	scene.boss = true
	add_child_autofree(scene)
	await wait_physics_frames(3)
	var found: Boss = null
	for child in scene.get_children():
		if child is Boss:
			found = child
	assert_not_null(found, "a boss was spawned")
	if found != null:
		assert_eq(found.data.id, &"tempest_dragon", "the forest's boss, not the shared roster's")
