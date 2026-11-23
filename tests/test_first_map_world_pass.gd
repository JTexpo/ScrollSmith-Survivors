extends GutTest
## Sprint 14a: the points of interest and Lecterns are spread out and each has something to get through (a ring of trees or a hedge
## yard with one opening), and the bottom-left is no longer bare.

const SCENE_DIR := "res://scenes/interactables/"
const RAYS := 16
## The player is a 12 px box, so a gap it could slip through is anything 12 px or wider; rays are grown by half of that.
const PLAYER_HALF_WIDTH := 6.0

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
		if shape.blocks_segment(point, target, PLAYER_HALF_WIDTH):
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


## The free rays as runs round the circle (a closed guard with one opening has exactly one run).
func _free_runs(point: Vector2, length: float) -> Array[int]:
	var free: Array[bool] = []
	for i in RAYS:
		free.append(not _ray_blocked(point, i, length))
	var start := -1
	for i in RAYS:
		if not free[i] and free[(i + 1) % RAYS]:
			start = (i + 1) % RAYS
			break
	var runs: Array[int] = []
	if start < 0:
		return runs
	var run := 0
	for k in RAYS:
		if free[(start + k) % RAYS]:
			run += 1
		elif run > 0:
			runs.append(run)
			run = 0
	if run > 0:
		runs.append(run)
	return runs


func test_each_new_guard_is_closed_on_all_but_one_side() -> void:
	for spot in _guarded():
		var runs := _free_runs(spot, 170.0)
		assert_eq(runs.size(), 1, "%s should have exactly one opening, runs %s" % [spot, str(runs)])
		if runs.size() == 1:
			assert_lte(runs[0], 5, "the opening at %s is too wide (%d rays)" % [spot, runs[0]])
		assert_true(_opens_to_open_ground(spot), "the opening at %s does not lead to open ground" % spot)


func test_no_gap_between_ring_trees_lets_the_player_through() -> void:
	for spot in _positions("treasure_chest") + _positions("lectern"):
		var ring: Array[MapObstacle] = []
		for shape in _shapes:
			if shape.material == &"tree" and shape.kind == MapObstacle.Kind.CIRCLE and absf(shape.position.distance_to(spot) - 62.0) < 1.0:
				ring.append(shape)
		if ring.size() < 5:
			continue
		for i in ring.size():
			for j in range(i + 1, ring.size()):
				var between := ring[i].position.distance_to(ring[j].position)
				if between < 62.0 * 1.2:
					assert_lt(between - ring[i].radius - ring[j].radius, 12.0, "trees at %s and %s leave a slit the player fits through" % [ring[i].position, ring[j].position])


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
