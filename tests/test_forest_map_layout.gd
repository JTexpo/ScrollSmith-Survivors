extends GutTest
## Sprint 16a: the forest. Open grass with groves and tree rings, the same points of interest as the ruins, nothing a player can be trapped
## by. These are the ruins' layout rules applied to the forest.

const Checks := preload("res://tests/map_layout_checks.gd")
const PATH := "res://resources/maps/forest_map.tres"

var _map: MapData
var _grid: ObstacleGrid
var _shapes: Array[MapObstacle]


func before_each() -> void:
	_map = load(PATH) as MapData
	_grid = ObstacleGrid.build(_map)
	_shapes = _map.solid_shapes()


func test_the_forest_has_no_problems_and_every_placement_is_reachable() -> void:
	assert_true(_map.problems().is_empty(), str(_map.problems()))
	assert_true(ObstacleGrid.reachability_problems(_map).is_empty(), str(ObstacleGrid.reachability_problems(_map)))


func test_it_is_named_1920_by_1080_with_the_default_spawn_config() -> void:
	assert_eq(_map.id, &"forest")
	assert_eq(_map.display_name, "The Forest")
	assert_eq(_map.enemy_art_set, &"forest")
	assert_false(_map.description.is_empty())
	assert_eq(_map.size, Vector2(1920, 1080))
	assert_eq(_map.player_start, Vector2(960, 540))
	assert_eq(_map.spawn_config.resource_path, (load("res://resources/maps/first_map.tres") as MapData).spawn_config.resource_path)


func test_it_has_between_20_and_90_solid_shapes_and_only_trees() -> void:
	assert_between(_shapes.size(), 20, 90)
	assert_true(_map.mazes.is_empty())
	assert_true(_map.zones.is_empty())
	for shape in _shapes:
		assert_eq(shape.kind, MapObstacle.Kind.CIRCLE, "the forest has no walls")
		assert_eq(shape.material, &"tree")


func test_the_outer_band_and_the_start_area_are_free() -> void:
	var inner := Rect2(Vector2(48, 48), _map.size - Vector2(96, 96))
	for shape in _shapes:
		assert_true(inner.encloses(shape.bounds()), "obstacle at %s is too close to the edge" % shape.position)
		assert_false(shape.contains(_map.player_start, 150.0), "obstacle at %s is inside the central area" % shape.position)


func test_most_of_it_is_walkable_but_it_has_trees() -> void:
	var blocked := 0
	for value in _grid.blocked:
		blocked += value
	assert_between(float(blocked) / float(_grid.columns * _grid.rows), 0.03, 0.15)


func test_no_gap_is_narrower_than_two_cells() -> void:
	for width in Checks.bounded_runs(_grid):
		assert_gte(width, 2, "a gap only one cell wide would trap bigger enemies")


func test_an_open_square_exists_away_from_the_start() -> void:
	assert_true(Checks.has_free_square(_grid, 10, 400.0, _map.player_start))


func test_every_free_cell_is_reachable_from_the_start() -> void:
	var sealed := Checks.sealed_cells(_grid, _map.player_start)
	assert_eq(sealed.size(), 0, "free cells nobody can walk to, for example %s" % str(sealed.slice(0, 4)))


func test_the_same_points_of_interest_as_the_ruins() -> void:
	var counts := {"lectern": 3, "rare_scroll_spot": 2, "treasure_chest": 1, "mana_shrine": 1, "health_shrine": 1, "merchant": 1}
	for scene_name in counts:
		assert_eq(Checks.positions(_map, scene_name).size(), counts[scene_name], scene_name)
	assert_eq(_map.placements.size(), 9)


func test_spacing_rules() -> void:
	var all := Checks.points(_map)
	for i in all.size():
		for j in range(i + 1, all.size()):
			assert_gte(all[i].distance_to(all[j]), 400.0, "%s and %s are too close" % [all[i], all[j]])
	var lecterns := Checks.positions(_map, "lectern")
	for i in lecterns.size():
		assert_gte(lecterns[i].distance_to(_map.player_start), 400.0)
		for j in range(i + 1, lecterns.size()):
			assert_gte(lecterns[i].distance_to(lecterns[j]), 700.0)


func test_each_lectern_chest_and_merchant_is_guarded_with_exactly_one_opening() -> void:
	var guarded: Array[Vector2] = []
	guarded.append_array(Checks.positions(_map, "treasure_chest"))
	guarded.append_array(Checks.positions(_map, "merchant"))
	guarded.append_array(Checks.positions(_map, "lectern"))
	assert_eq(guarded.size(), 5)
	for spot in guarded:
		var runs := Checks.free_runs(_shapes, spot, 170.0)
		assert_eq(runs.size(), 1, "%s should have exactly one opening, runs %s" % [spot, str(runs)])
		if runs.size() == 1:
			assert_lte(runs[0], 5, "the opening at %s is too wide (%d rays)" % [spot, runs[0]])
		assert_true(Checks.opens_to_open_ground(_shapes, spot), "the opening at %s does not lead to open ground" % spot)


func test_shrines_and_rare_spots_stand_in_clearings() -> void:
	var open: Array[Vector2] = []
	for scene_name in ["health_shrine", "mana_shrine", "rare_scroll_spot"]:
		open.append_array(Checks.positions(_map, scene_name))
	assert_eq(open.size(), 4)
	for spot in open:
		assert_gte(Checks.clearance(_shapes, spot), 80.0, "something stands within 80 px of the clearing at %s" % spot)


func test_no_gap_between_ring_trees_lets_the_player_through() -> void:
	var rings := 0
	for spot in Checks.positions(_map, "treasure_chest") + Checks.positions(_map, "merchant") + Checks.positions(_map, "lectern"):
		var ring: Array[MapObstacle] = []
		for shape in _shapes:
			if absf(shape.position.distance_to(spot) - 62.0) < 1.0:
				ring.append(shape)
		assert_eq(ring.size(), 7, "the ring at %s has seven trees" % spot)
		rings += 1
		for i in ring.size():
			for j in range(i + 1, ring.size()):
				var between := ring[i].position.distance_to(ring[j].position)
				if between < 62.0 * 1.2:
					assert_lt(between - ring[i].radius - ring[j].radius, 12.0, "trees at %s and %s leave a slit the player fits through" % [ring[i].position, ring[j].position])
	assert_eq(rings, 5)


func test_the_forest_lists_the_dragon_as_its_boss() -> void:
	assert_eq(_map.bosses.size(), 1)
	assert_eq(_map.bosses[0].id, &"tempest_dragon")
	assert_true((load("res://resources/maps/first_map.tres") as MapData).bosses.is_empty(), "the ruins keep the shared roster")
	var maze_bosses := (load("res://resources/maps/maze_map.tres") as MapData).bosses
	assert_eq(maze_bosses.size(), 1, "the maze names its own boss")
	assert_ne(maze_bosses[0].id, _map.bosses[0].id)
