extends GutTest
## Sprint 16a: the maze. One seeded maze over almost the whole map with the start in its cleared centre, the same points of interest as the
## ruins in its dead ends, nothing unreachable. Unlike the ruins the start has walls fairly near (the centre room is 160 px across), so the
## start area rule is "the cleared room", not 150 px.

const Checks := preload("res://tests/map_layout_checks.gd")
const PATH := "res://resources/maps/maze_map.tres"

var _map: MapData
var _grid: ObstacleGrid
var _shapes: Array[MapObstacle]


func before_each() -> void:
	_map = load(PATH) as MapData
	_grid = ObstacleGrid.build(_map)
	_shapes = _map.solid_shapes()


func test_the_maze_has_no_problems_and_every_placement_is_reachable() -> void:
	assert_true(_map.problems().is_empty(), str(_map.problems()))
	assert_true(ObstacleGrid.reachability_problems(_map).is_empty(), str(ObstacleGrid.reachability_problems(_map)))


func test_it_is_named_1920_by_1080_with_the_default_spawn_config() -> void:
	assert_eq(_map.id, &"maze")
	assert_eq(_map.display_name, "The Maze")
	assert_eq(_map.enemy_art_set, &"maze")
	assert_false(_map.description.is_empty())
	assert_eq(_map.size, Vector2(1920, 1080))
	assert_eq(_map.player_start, Vector2(960, 540))
	assert_eq(_map.spawn_config.resource_path, (load("res://resources/maps/first_map.tres") as MapData).spawn_config.resource_path)
	assert_eq(_map.mazes.size(), 1)
	assert_true(_map.obstacles.is_empty())


func test_the_maze_is_deterministic_from_its_seed() -> void:
	var again := (load(PATH) as MapData).solid_shapes()
	assert_eq(_shapes.size(), again.size())
	for i in _shapes.size():
		assert_eq(_shapes[i].position, again[i].position)
		assert_eq(_shapes[i].size, again[i].size)


func test_it_has_a_bounded_number_of_solid_shapes() -> void:
	assert_between(_shapes.size(), 80, 400)


func test_the_outer_band_is_free() -> void:
	var inner := Rect2(Vector2(48, 48), _map.size - Vector2(96, 96))
	for shape in _shapes:
		assert_true(inner.encloses(shape.bounds()), "wall at %s is too close to the edge" % shape.position)


func test_the_start_stands_in_the_cleared_centre_room() -> void:
	var room: Vector2 = _map.mazes[0].center_room_center()
	assert_lt(room.distance_to(_map.player_start), 24.0)
	assert_gte(Checks.clearance(_shapes, _map.player_start), 48.0)
	assert_false(_grid.is_blocked(_map.player_start))


func test_no_gap_is_narrower_than_two_cells() -> void:
	Checks.no_narrow_gaps(self, _grid)


func test_every_free_cell_is_reachable_from_the_start() -> void:
	Checks.every_free_cell_reachable(self, _grid, _map)


func test_the_same_points_of_interest_as_the_ruins() -> void:
	Checks.same_points_of_interest_as_the_ruins(self, _map)


func test_spacing_rules() -> void:
	Checks.spacing_rules(self, _map)


func test_every_point_of_interest_and_lectern_is_in_a_dead_end() -> void:
	var dead: Array[Vector2] = _map.mazes[0].dead_end_cells()
	for placement in _map.placements:
		var nearest := INF
		for centre in dead:
			nearest = minf(nearest, centre.distance_to(placement.position))
		assert_lt(nearest, 40.0, "the placement at %s is not in a dead end" % placement.position)


func test_it_has_dead_ends_and_the_centre_is_never_one() -> void:
	var dead: Array[Vector2] = _map.mazes[0].dead_end_cells()
	assert_gte(dead.size(), 12)
	for centre in dead:
		assert_gt(centre.distance_to(_map.player_start), 120.0)


func test_the_maze_has_loops_so_a_chase_can_circle() -> void:
	assert_gte(_map.mazes[0].extra_openings, 6)


func test_the_maze_lists_the_minotaur_as_its_boss() -> void:
	assert_eq(_map.bosses.size(), 1)
	assert_eq(_map.bosses[0].id, &"dire_minotaur")
	assert_true((load("res://resources/maps/first_map.tres") as MapData).bosses.is_empty(), "the ruins keep the shared roster")
