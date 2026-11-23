extends GutTest

const LECTERN := "res://scenes/interactables/lectern.tscn"


func _map(clearance: float = 0.0) -> MapData:
	var map := MapData.new()
	map.id = &"test"
	map.size = Vector2(160, 160)
	map.player_start = Vector2(20, 20)
	map.nav_cell_size = 16.0
	map.body_clearance = clearance
	return map


func _rect(position: Vector2, size: Vector2) -> MapObstacle:
	var obstacle := MapObstacle.new()
	obstacle.kind = MapObstacle.Kind.RECT
	obstacle.position = position
	obstacle.size = size
	return obstacle


func _circle(position: Vector2, radius: float) -> MapObstacle:
	var obstacle := MapObstacle.new()
	obstacle.kind = MapObstacle.Kind.CIRCLE
	obstacle.position = position
	obstacle.radius = radius
	return obstacle


func _blocked_count(grid: ObstacleGrid) -> int:
	var count := 0
	for value in grid.blocked:
		count += value
	return count


func _placement(position: Vector2) -> MapPlacement:
	var placement := MapPlacement.new()
	placement.scene = load(LECTERN)
	placement.position = position
	return placement


func _walled_in_map() -> MapData:
	var map := _map()
	map.placements = [_placement(Vector2(80, 80))] as Array[MapPlacement]
	map.obstacles = [
		_rect(Vector2(80, 56), Vector2(64, 8)),
		_rect(Vector2(80, 104), Vector2(64, 8)),
		_rect(Vector2(56, 80), Vector2(8, 64)),
		_rect(Vector2(104, 80), Vector2(8, 64)),
	] as Array[MapObstacle]
	return map


func test_no_obstacles_means_no_blocked_cells() -> void:
	var grid := ObstacleGrid.build(_map())
	assert_eq(grid.columns, 10)
	assert_eq(grid.rows, 10)
	assert_eq(_blocked_count(grid), 0)


func test_a_rect_blocks_the_cells_it_overlaps_and_no_others() -> void:
	var map := _map()
	map.obstacles = [_rect(Vector2(72, 72), Vector2(20, 20))] as Array[MapObstacle]
	var grid := ObstacleGrid.build(map)
	assert_eq(_blocked_count(grid), 9)
	for x in range(3, 6):
		for y in range(3, 6):
			assert_true(grid.is_blocked_cell(Vector2i(x, y)))


func test_a_circle_blocks_by_its_radius() -> void:
	var map := _map()
	map.obstacles = [_circle(Vector2(80, 80), 10.0)] as Array[MapObstacle]
	var grid := ObstacleGrid.build(map)
	assert_eq(_blocked_count(grid), 4)
	assert_true(grid.is_blocked_cell(Vector2i(4, 4)))
	assert_false(grid.is_blocked_cell(Vector2i(3, 3)))


func test_body_clearance_blocks_cells_around_an_obstacle() -> void:
	var map := _map(8.0)
	map.obstacles = [_circle(Vector2(80, 80), 10.0)] as Array[MapObstacle]
	var grid := ObstacleGrid.build(map)
	assert_eq(_blocked_count(grid), 12)
	assert_true(grid.is_blocked_cell(Vector2i(3, 4)))
	assert_false(grid.is_blocked_cell(Vector2i(3, 3)))


func test_cell_of_and_cell_center_round_trip() -> void:
	var grid := ObstacleGrid.build(_map())
	assert_eq(grid.cell_of(Vector2(40, 40)), Vector2i(2, 2))
	assert_eq(grid.cell_center(Vector2i(2, 2)), Vector2(40, 40))
	for x in grid.columns:
		for y in grid.rows:
			assert_eq(grid.cell_of(grid.cell_center(Vector2i(x, y))), Vector2i(x, y))


func test_cell_of_clamps_outside_points() -> void:
	var grid := ObstacleGrid.build(_map())
	assert_eq(grid.cell_of(Vector2(-50, 500)), Vector2i(0, 9))


func test_out_of_range_cells_are_blocked() -> void:
	var grid := ObstacleGrid.build(_map())
	assert_true(grid.is_blocked_cell(Vector2i(-1, 0)))
	assert_true(grid.is_blocked_cell(Vector2i(10, 0)))
	assert_true(grid.is_blocked_cell(Vector2i(0, 10)))


func test_nearest_free_returns_a_free_point_and_leaves_a_free_point_alone() -> void:
	var map := _map()
	map.obstacles = [_rect(Vector2(80, 80), Vector2(40, 40))] as Array[MapObstacle]
	var grid := ObstacleGrid.build(map)
	var moved := grid.nearest_free(Vector2(80, 80))
	assert_false(grid.is_blocked(moved))
	assert_lte(moved.distance_to(Vector2(80, 80)), 48.0)
	assert_eq(grid.nearest_free(Vector2(10, 10)), Vector2(10, 10))


func test_reachability_flags_a_placement_walled_in() -> void:
	assert_eq(ObstacleGrid.reachability_problems(_walled_in_map()).size(), 1)


func test_reachability_passes_an_open_map() -> void:
	var map := _map()
	map.placements = [_placement(Vector2(80, 80))] as Array[MapPlacement]
	assert_true(ObstacleGrid.reachability_problems(map).is_empty())


func test_reachability_flags_a_blocked_start() -> void:
	var map := _map()
	map.obstacles = [_rect(Vector2(20, 20), Vector2(10, 10))] as Array[MapObstacle]
	assert_eq(ObstacleGrid.reachability_problems(map).size(), 1)


func test_a_maze_blocks_cells() -> void:
	var map := _map()
	map.size = Vector2(700, 420)
	var maze := MapMaze.new()
	maze.area = Rect2(100, 52, 480, 320)
	maze.seed = 3
	maze.extra_openings = 1000
	map.mazes = [maze] as Array[MapMaze]
	var grid := ObstacleGrid.build(map)
	assert_true(grid.is_blocked(Vector2(100, 52 + 120)), "the outer wall blocks")
	assert_false(grid.is_blocked(Vector2(100 + 120, 52 + 120)), "a corridor with every inner wall removed is open")
