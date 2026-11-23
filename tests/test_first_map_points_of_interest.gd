extends GutTest

const SCENE_DIR := "res://scenes/interactables/"
## The island's gates, from the layout: west at x 1388 (y 210 to 290) and south at y 340 (x 1530 to 1610).
const WEST_GATE := Vector2(1388, 250)
const SOUTH_GATE := Vector2(1570, 340)

var _map: MapData


func before_each() -> void:
	_map = load("res://resources/maps/first_map.tres") as MapData


func _positions(scene_name: String) -> Array[Vector2]:
	var found: Array[Vector2] = []
	for placement in _map.placements:
		if placement.scene.resource_path == "%s%s.tscn" % [SCENE_DIR, scene_name]:
			found.append(placement.position)
	return found


func _points() -> Array[Vector2]:
	var found: Array[Vector2] = []
	for scene_name in ["health_shrine", "mana_shrine", "treasure_chest", "rare_scroll_spot", "merchant"]:
		found.append_array(_positions(scene_name))
	return found


func _zone(zone_name: String) -> MapZone:
	for zone in _map.zones:
		if zone.display_name == zone_name:
			return zone
	return null


func test_every_kind_appears_on_the_first_map() -> void:
	assert_eq(_positions("rare_scroll_spot").size(), 2)
	assert_eq(_positions("treasure_chest").size(), 1)
	assert_eq(_positions("mana_shrine").size(), 1)
	assert_eq(_positions("health_shrine").size(), 1)
	assert_eq(_positions("merchant").size(), 1)
	assert_eq(_positions("lectern").size(), 3)


func test_the_map_has_no_problems_and_every_placement_is_reachable() -> void:
	assert_true(_map.problems().is_empty(), str(_map.problems()))
	assert_true(ObstacleGrid.reachability_problems(_map).is_empty(), str(ObstacleGrid.reachability_problems(_map)))


func test_the_rare_scroll_spots_are_at_the_maze_centres() -> void:
	var spots := _positions("rare_scroll_spot")
	for maze in _map.mazes:
		var found := false
		for spot in spots:
			if spot.distance_to(maze.center_room_center()) <= 4.0:
				found = true
		assert_true(found, "no Rare scroll spot at %s" % maze.center_room_center())


func test_the_island_points_are_inside_the_island_and_clear_of_both_gates() -> void:
	var island := _zone("Island").area
	for spot in _positions("mana_shrine"):
		assert_true(island.grow(-24.0).has_point(spot), "%s is not inside the island" % spot)
		assert_gte(spot.distance_to(WEST_GATE), 60.0, "%s blocks the west gate" % spot)
		assert_gte(spot.distance_to(SOUTH_GATE), 60.0, "%s blocks the south gate" % spot)


func test_the_corridor_shrine_is_between_the_corridor_walls_and_does_not_block_it() -> void:
	var shrine := _positions("health_shrine")[0]
	# The corridor's walls are at y 930 and y 1010 and run from x 480 to x 1040.
	assert_between(shrine.x, 520.0, 1000.0)
	assert_lte(absf(shrine.y - 970.0), 16.0, "in the middle of the corridor")


func test_the_merchant_is_north_of_the_plaza_and_far_from_the_health_shrine() -> void:
	var merchant := _positions("merchant")[0]
	assert_lt(merchant.y, _map.player_start.y)
	assert_gte(merchant.distance_to(_positions("health_shrine")[0]), 450.0)
	for lectern in _positions("lectern"):
		assert_gte(merchant.distance_to(lectern), 250.0, "too near the Lectern at %s" % lectern)


func test_no_two_points_of_interest_are_closer_than_80_px() -> void:
	var all := _points()
	for lectern in _positions("lectern"):
		all.append(lectern)
	for i in all.size():
		for j in range(i + 1, all.size()):
			assert_gte(all[i].distance_to(all[j]), 80.0, "%s and %s are too close" % [all[i], all[j]])
