extends GutTest
## Sprint 16a: the catalog of maps (forest, ruins, maze in that order), each with a run scene. The scene path carries the choice, so a
## restart reloads the same map and nothing is stored anywhere.

var _catalog: MapCatalog


func before_each() -> void:
	_catalog = MapCatalog.default_catalog()


func _new_main(path: String) -> Main:
	var main := load(path).instantiate() as Main
	main.save_path = ""
	(main.get_node("BuffPickScreen") as BuffPickScreen).pause_tree = false
	add_child_autofree(main)
	return main


func test_the_catalog_lists_forest_ruins_maze_in_order() -> void:
	assert_eq(_catalog.ids(), [&"forest", &"first_map", &"maze"] as Array[StringName])
	assert_eq(_catalog.default_id(), &"forest")


func test_each_entry_scene_exists_and_holds_the_entry_s_map() -> void:
	for entry in _catalog.entries:
		assert_true(ResourceLoader.exists(entry.scene_path), entry.scene_path)
		var main := load(entry.scene_path).instantiate() as Main
		assert_eq((main.get_node("GameMap") as GameMap).map_data.id, entry.map.id, entry.scene_path)
		main.free()


func test_the_ruins_entry_is_the_existing_main_scene_and_map() -> void:
	var entry := _catalog.find(&"first_map")
	assert_eq(entry.scene_path, Scenes.RUN)
	assert_eq(entry.map.resource_path, "res://resources/maps/first_map.tres")


func test_find_and_entry_for_scene_round_trip() -> void:
	for entry in _catalog.entries:
		assert_eq(_catalog.find(entry.map.id), entry)
		assert_eq(_catalog.entry_for_scene(entry.scene_path), entry)


func test_unknown_ids_and_paths_give_null() -> void:
	assert_null(_catalog.find(&"nowhere"))
	assert_null(_catalog.entry_for_scene("res://nope.tscn"))
	assert_null(_catalog.entry_for_scene(""))


func test_every_map_has_a_name_description_art_set_and_unique_id() -> void:
	var seen := {}
	for entry in _catalog.entries:
		assert_false(entry.map.display_name.is_empty())
		assert_false(entry.map.description.is_empty())
		assert_false(entry.map.enemy_art_set == &"")
		assert_false(seen.has(entry.map.id), "duplicate id")
		seen[entry.map.id] = true


func test_every_map_validates_and_shares_the_default_spawn_config() -> void:
	var config := load("res://resources/spawning/default_spawn_config.tres")
	for entry in _catalog.entries:
		assert_true(entry.map.problems().is_empty(), "%s: %s" % [entry.map.id, str(entry.map.problems())])
		assert_eq(entry.map.spawn_config, config, "%s uses the shared spawn config" % entry.map.id)
		assert_eq(entry.map.size, Vector2(1920, 1080))


func test_the_boss_name_comes_from_the_maps_roster_then_the_config() -> void:
	assert_eq(MapEntry.new().boss_name(), "")
	var entry := MapEntry.new()
	entry.map = (load("res://resources/maps/first_map.tres") as MapData).duplicate() as MapData
	var own := (load("res://resources/bosses/ember_titan.tres") as BossData).duplicate() as BossData
	own.display_name = "Roster Boss"
	entry.map.bosses = [own] as Array[BossData]
	assert_eq(entry.boss_name(), "Roster Boss", "a map's own roster wins over the spawn config's")


func test_each_scene_builds_a_main_that_starts_a_run() -> void:
	for entry in _catalog.entries:
		var main := _new_main(entry.scene_path)
		await wait_process_frames(2)
		var spawner := main.get_node("EnemySpawner") as EnemySpawner
		assert_eq(spawner.arena_bounds, Rect2(Vector2.ZERO, entry.map.size), entry.map.id)
		assert_eq(spawner.enemy_art_set, entry.map.enemy_art_set)
		assert_lt((main.get_node("Player") as Player).global_position.distance_to(entry.map.player_start), 40.0, "the player starts at the map's start (a first physics frame may nudge it)")
		assert_eq(main.map_id(), entry.map.id)


func test_restart_reloads_the_same_scene() -> void:
	for entry in _catalog.entries:
		var main := _new_main(entry.scene_path)
		var death := main.get_node("DeathScreen") as DeathScreen
		assert_true(death.restart_scene_path.is_empty() or death.restart_scene_path == entry.scene_path)
		# The screen falls back to the current scene's own file; the inherited scene's path is the entry's.
		assert_eq(main.scene_file_path, entry.scene_path)


func test_the_forest_names_the_dragon_and_the_others_keep_the_titan() -> void:
	assert_eq(_catalog.find(&"forest").boss_name(), "Tempest Dragon")
	assert_eq(_catalog.find(&"first_map").boss_name(), "Ember Titan")
	assert_eq(_catalog.find(&"maze").boss_name(), "Ember Titan")
