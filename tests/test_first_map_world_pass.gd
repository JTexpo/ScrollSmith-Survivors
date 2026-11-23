extends GutTest
## Sprint 14a: the points of interest and Lecterns are spread out and each has something to get through (a ring of trees or a hedge
## yard with one opening), and the bottom-left is no longer bare.

const SCENE_DIR := "res://scenes/interactables/"
const RAYS := 16

var _map: MapData
var _shapes: Array[MapObstacle]


func before_each() -> void:
	_map = load("res://resources/maps/first_map.tres") as MapData
	_shapes = _map.solid_shapes()


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


func _ray_blocked(point: Vector2, index: int, length: float) -> bool:
	var target := point + Vector2.from_angle(TAU * index / RAYS) * length
	for shape in _shapes:
		if shape.blocks_segment(point, target, 0.0):
			return true
	return false


func _rays_blocked(point: Vector2, length: float) -> int:
	var blocked := 0
	for i in RAYS:
		if _ray_blocked(point, i, length):
			blocked += 1
	return blocked


## True when some ray from the point is free for 200 px (the opening leads to open ground).
func _opens_to_open_ground(point: Vector2) -> bool:
	for i in RAYS:
		if not _ray_blocked(point, i, 200.0):
			return true
	return false


func _guarded() -> Array[Vector2]:
	var found: Array[Vector2] = []
	found.append_array(_positions("treasure_chest"))
	found.append_array(_positions("merchant"))
	found.append_array(_positions("lectern"))
	return found


func test_the_chest_is_in_the_bottom_left() -> void:
	var chest := _positions("treasure_chest")[0]
	assert_lt(chest.x, 400.0)
	assert_gt(chest.y, 800.0)


func test_the_points_of_interest_are_spread_out() -> void:
	var all := _points()
	for i in all.size():
		for j in range(i + 1, all.size()):
			assert_gte(all[i].distance_to(all[j]), 400.0, "%s and %s are too close" % [all[i], all[j]])


func test_the_lecterns_are_spread_and_away_from_the_start() -> void:
	var lecterns := _positions("lectern")
	assert_eq(lecterns.size(), 3)
	for i in lecterns.size():
		assert_gte(lecterns[i].distance_to(_map.player_start), 400.0)
		for j in range(i + 1, lecterns.size()):
			assert_gte(lecterns[i].distance_to(lecterns[j]), 700.0)


func test_each_new_guard_is_closed_on_all_but_one_side() -> void:
	for spot in _guarded():
		var blocked := _rays_blocked(spot, 100.0)
		assert_gte(blocked, 10, "%s is not enclosed (%d of %d rays blocked)" % [spot, blocked, RAYS])
		assert_lte(blocked, 14, "%s has no opening (%d of %d rays blocked)" % [spot, blocked, RAYS])
		assert_true(_opens_to_open_ground(spot), "the opening at %s does not lead to open ground" % spot)


func test_the_map_is_still_valid_and_reachable() -> void:
	assert_true(_map.problems().is_empty(), str(_map.problems()))
	assert_true(ObstacleGrid.reachability_problems(_map).is_empty(), str(ObstacleGrid.reachability_problems(_map)))


func test_the_bottom_left_has_trees_beyond_the_chest_ring() -> void:
	var others := _points()
	others.append_array(_positions("lectern"))
	var trees := 0
	for shape in _shapes:
		if shape.material != &"tree" or shape.kind != MapObstacle.Kind.CIRCLE:
			continue
		if shape.position.x >= 600.0 or shape.position.y <= 700.0:
			continue
		var clear := true
		for spot in others:
			if shape.position.distance_to(spot) <= 100.0:
				clear = false
		if clear:
			trees += 1
	assert_gte(trees, 4, "a grove away from every guard")


func test_no_two_tree_circles_overlap_unless_they_are_one_ring() -> void:
	var guards := _guarded()
	var circles: Array[MapObstacle] = []
	for shape in _shapes:
		if shape.kind == MapObstacle.Kind.CIRCLE:
			circles.append(shape)
	for i in circles.size():
		for j in range(i + 1, circles.size()):
			var gap := circles[i].position.distance_to(circles[j].position) - circles[i].radius - circles[j].radius
			if gap >= -1.0:
				continue
			var same_ring := false
			for spot in guards:
				if circles[i].position.distance_to(spot) <= 80.0 and circles[j].position.distance_to(spot) <= 80.0:
					same_ring = true
			assert_true(same_ring, "trees at %s and %s overlap" % [circles[i].position, circles[j].position])
