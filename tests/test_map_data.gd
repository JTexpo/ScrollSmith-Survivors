extends GutTest

const LECTERN := "res://scenes/interactables/lectern.tscn"


func _map() -> MapData:
	var map := MapData.new()
	map.id = &"test"
	map.size = Vector2(400, 300)
	map.player_start = Vector2(200, 150)
	return map


func _placement(scene: PackedScene, position: Vector2) -> MapPlacement:
	var placement := MapPlacement.new()
	placement.scene = scene
	placement.position = position
	return placement


func test_bounds_start_at_the_origin() -> void:
	assert_eq(_map().bounds(), Rect2(0, 0, 400, 300))


func test_a_valid_map_has_no_problems() -> void:
	assert_true(_map().problems().is_empty())


func test_problems_name_an_empty_id() -> void:
	var map := _map()
	map.id = &""
	assert_eq(map.problems().size(), 1)


func test_problems_name_a_non_positive_size() -> void:
	var map := _map()
	map.size = Vector2(0, 300)
	map.player_start = Vector2(0, 0)
	assert_eq(map.problems().size(), 1)


func test_problems_name_a_start_outside_the_map() -> void:
	var map := _map()
	map.player_start = Vector2(500, 150)
	assert_eq(map.problems().size(), 1)


func test_problems_name_a_placement_without_a_scene_or_outside_the_map() -> void:
	var map := _map()
	map.placements = [
		_placement(null, Vector2(10, 10)),
		_placement(load(LECTERN), Vector2(-5, 10)),
	] as Array[MapPlacement]
	assert_eq(map.problems().size(), 2)


func test_first_map_is_1920_by_1080_and_valid() -> void:
	var map := load("res://resources/maps/first_map.tres") as MapData
	assert_eq(map.size, Vector2(1920, 1080))
	assert_eq(map.player_start, Vector2(960, 540))
	assert_true(map.problems().is_empty(), str(map.problems()))
	assert_not_null(map.spawn_config)


func test_first_map_places_three_lecterns_at_least_700_apart() -> void:
	var map := load("res://resources/maps/first_map.tres") as MapData
	var spots: Array[Vector2] = []
	for placement in map.placements:
		if placement.scene.resource_path == LECTERN:
			spots.append(placement.position)
	assert_eq(spots.size(), 3)
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			assert_gte(spots[i].distance_to(spots[j]), 700.0)
