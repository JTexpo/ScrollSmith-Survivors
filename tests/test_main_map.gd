extends GutTest

const MAP_SIZE := Vector2(1920, 1080)


func _new_main(map_data: MapData = null) -> Main:
	var main := load("res://scenes/main/main.tscn").instantiate() as Main
	main.save_path = ""
	(main.get_node("BuffPickScreen") as BuffPickScreen).pause_tree = false
	if map_data != null:
		(main.get_node("GameMap") as GameMap).map_data = map_data
	add_child_autofree(main)
	return main


func test_the_spawner_and_camera_use_the_map_bounds() -> void:
	var main := _new_main()
	assert_eq((main.get_node("EnemySpawner") as EnemySpawner).arena_bounds, Rect2(Vector2.ZERO, MAP_SIZE))
	var camera := main.get_node("Player/Camera2D") as Camera2D
	assert_eq([camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom], [0, 0, 1920, 1080])


func test_the_player_starts_at_the_map_start() -> void:
	assert_eq((_new_main().get_node("Player") as Player).global_position, Vector2(960, 540))


func test_the_three_lecterns_come_from_the_map() -> void:
	var main := _new_main()
	var lecterns := get_tree().get_nodes_in_group(&"lecterns").filter(func(node: Node) -> bool: return main.is_ancestor_of(node))
	assert_eq(lecterns.size(), 3)
	var placements := main.get_node("GameMap/Placements")
	for lectern in lecterns:
		assert_eq(lectern.get_parent(), placements)
		assert_false(lectern.get_signal_connection_list(&"interacted").is_empty())


func test_a_map_config_replaces_the_scene_config_and_a_null_one_keeps_it() -> void:
	var data := (load("res://resources/maps/first_map.tres") as MapData).duplicate() as MapData
	var own := SpawnConfig.new()
	data.spawn_config = own
	assert_eq((_new_main(data).get_node("EnemySpawner") as EnemySpawner).config, own)
	var plain := data.duplicate() as MapData
	plain.spawn_config = null
	var main := _new_main(plain)
	var scene_root := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	var scene_config: SpawnConfig = scene_root.get_node("EnemySpawner").config
	scene_root.free()
	assert_eq((main.get_node("EnemySpawner") as EnemySpawner).config, scene_config)


func test_the_spawn_ring_works_at_every_corner() -> void:
	var main := _new_main()
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var bounds := spawner.arena_bounds
	var half := spawner.view_size / 2.0
	for corner: Vector2 in [Vector2.ZERO, Vector2(MAP_SIZE.x, 0), Vector2(0, MAP_SIZE.y), MAP_SIZE]:
		(main.get_node("Player") as Player).global_position = corner
		var center: Vector2 = corner.clamp(bounds.position + half, bounds.end - half)
		# The spawner clamps to the far edge inclusively, which Rect2.has_point does not count as inside.
		for attempt in 30:
			var at := spawner.spawn_position(corner)
			assert_ne(at, Vector2.INF, "no spawn point at %s" % corner)
			assert_true(bounds.grow(0.001).has_point(at), "outside the map at %s" % corner)
			assert_false(Rect2(center - half, spawner.view_size).grow(-0.5).has_point(at), "inside the view at %s" % corner)


func test_the_camera_starts_on_the_player_with_no_glide() -> void:
	var main := _new_main()
	await wait_frames(1)
	var camera := main.get_node("Player/Camera2D") as Camera2D
	assert_almost_eq(camera.get_screen_center_position(), Vector2(960, 540), Vector2(1, 1))


func test_a_deaths_drops_fan_out_xp_to_the_left_and_gold_to_the_right() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.save_path = ""
	main.get_node("BuffPickScreen").pause_tree = false
	add_child_autofree(main)
	var xp := main.get_node("XpDropper") as ValueDropper
	var gold := main.get_node("GoldDropper") as ValueDropper
	assert_lt(xp.drop_offset.x, 0.0, "XP lands to the left of the scroll")
	assert_gt(gold.drop_offset.x, 0.0, "Gold lands to the right of the scroll")
	assert_eq(absf(xp.drop_offset.x), absf(gold.drop_offset.x))
	assert_gte(absf(xp.drop_offset.x), 6.0, "far enough apart that a 12 px scroll does not cover them")



func test_apply_map_hands_the_art_set_to_the_spawner() -> void:
	var data := (load("res://resources/maps/first_map.tres") as MapData).duplicate() as MapData
	data.enemy_art_set = &"forest"
	assert_eq((_new_main(data).get_node("EnemySpawner") as EnemySpawner).enemy_art_set, &"forest")
	assert_eq((_new_main().get_node("EnemySpawner") as EnemySpawner).enemy_art_set, &"ruins", "the ruins name their set")


func test_every_spawned_enemy_gets_the_spawners_art_set() -> void:
	var data := (load("res://resources/maps/first_map.tres") as MapData).duplicate() as MapData
	data.enemy_art_set = &"maze"
	var main := _new_main(data)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	assert_eq(spawner.spawn_at(Vector2(300, 300), 1).art_set, &"maze")


func test_apply_map_hands_the_roster_to_the_spawner() -> void:
	var data := (load("res://resources/maps/first_map.tres") as MapData).duplicate() as MapData
	var own := (load("res://resources/bosses/ember_titan.tres") as BossData).duplicate() as BossData
	own.id = &"own_boss"
	data.bosses = [own] as Array[BossData]
	assert_eq((_new_main(data).get_node("EnemySpawner") as EnemySpawner).boss_roster, [own] as Array[BossData])
	assert_true((_new_main().get_node("EnemySpawner") as EnemySpawner).boss_roster.is_empty(), "the ruins name none")


func test_the_ruins_still_use_the_config_roster() -> void:
	var bosses := (_new_main().get_node("EnemySpawner") as EnemySpawner).bosses()
	assert_eq(bosses.size(), 1)
	assert_eq(bosses[0].id, &"ember_titan")
