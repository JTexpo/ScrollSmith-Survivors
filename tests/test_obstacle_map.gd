extends GutTest

var _player: Node2D


func before_each() -> void:
	_player = Node2D.new()
	add_child_autofree(_player)
	_player.add_to_group(&"player")
	_player.global_position = Vector2(280, 40)


func after_each() -> void:
	get_tree().paused = false


func _wall_map(clearance: float = 0.0) -> MapData:
	var map := MapData.new()
	map.id = &"test"
	map.size = Vector2(320, 160)
	map.player_start = Vector2(8, 8)
	map.nav_cell_size = 16.0
	map.body_clearance = clearance
	var wall := MapObstacle.new()
	wall.kind = MapObstacle.Kind.RECT
	wall.position = Vector2(160, 56)
	wall.size = Vector2(16, 112)
	map.obstacles = [wall] as Array[MapObstacle]
	return map


func _obstacle_map(map: MapData) -> ObstacleMap:
	var node := ObstacleMap.new()
	node.cells_per_frame = 100000
	add_child_autofree(node)
	node.setup(map)
	return node


func test_it_joins_the_obstacle_map_group() -> void:
	var node := _obstacle_map(_wall_map())
	assert_true(node.is_in_group(&"obstacle_map"))


func test_blocks_segment_and_is_blocked_follow_the_shapes() -> void:
	var node := _obstacle_map(_wall_map(8.0))
	assert_true(node.is_blocked(Vector2(160, 56)))
	assert_false(node.is_blocked(Vector2(40, 40)))
	assert_true(node.blocks_segment(Vector2(100, 40), Vector2(220, 40)))
	assert_false(node.blocks_segment(Vector2(100, 130), Vector2(220, 130)))
	# The grid is grown for the body, the segment test is exact against the shape.
	assert_true(node.is_blocked(Vector2(150, 40)))
	assert_false(node.blocks_segment(Vector2(100, 40), Vector2(150, 40)))


func test_push_out_returns_a_free_point() -> void:
	var node := _obstacle_map(_wall_map())
	assert_false(node.is_blocked(node.push_out(Vector2(160, 56))))
	assert_eq(node.push_out(Vector2(40, 40)), Vector2(40, 40))


func test_resolve_move_allows_free_moves_slides_along_a_wall_and_never_enters_a_blocked_cell() -> void:
	var node := _obstacle_map(_wall_map())
	assert_eq(node.resolve_move(Vector2(40, 40), Vector2(45, 45)), Vector2(45, 45))
	assert_eq(node.resolve_move(Vector2(140, 40), Vector2(156, 50)), Vector2(140, 50))
	var at := Vector2(140, 40)
	for step in 100:
		at = node.resolve_move(at, at + Vector2(4, 3))
		assert_false(node.is_blocked(at), "step %d at %s" % [step, at])
	assert_false(node.is_blocked(node.resolve_move(Vector2(156, 40), Vector2(158, 40))))


func test_direction_from_leads_around_a_wall_toward_the_player() -> void:
	var node := _obstacle_map(_wall_map())
	assert_gt(node.direction_from(Vector2(130, 40)).y, 0.2)
	assert_gt(node.rebuild_count, 0)


func test_the_field_rebuilds_only_when_the_player_changes_cell_and_the_interval_has_passed() -> void:
	var node := _obstacle_map(_wall_map())
	var first := node.rebuild_count
	node._physics_process(0.05)
	assert_eq(node.rebuild_count, first, "the player stayed in its cell")
	_player.global_position = Vector2(260, 40)
	node._physics_process(0.05)
	assert_eq(node.rebuild_count, first, "less than the interval has passed")
	node._physics_process(ObstacleMap.REBUILD_INTERVAL)
	assert_eq(node.rebuild_count, first + 1)


func test_nothing_rebuilds_while_the_tree_is_paused() -> void:
	var node := _obstacle_map(_wall_map())
	var first := node.rebuild_count
	_player.global_position = Vector2(100, 120)
	get_tree().paused = true
	await wait_physics_frames(8)
	assert_eq(node.rebuild_count, first)
	get_tree().paused = false


func test_a_slow_budget_finishes_a_rebuild_over_several_frames() -> void:
	var node := ObstacleMap.new()
	node.cells_per_frame = 20
	add_child_autofree(node)
	node.setup(_wall_map())
	var first := node.rebuild_count
	_player.global_position = Vector2(100, 120)
	node._physics_process(ObstacleMap.REBUILD_INTERVAL)
	assert_eq(node.rebuild_count, first, "not done after one small budget")
	for i in 100:
		node._physics_process(0.016)
	assert_eq(node.rebuild_count, first + 1)


func test_without_a_player_nothing_breaks() -> void:
	_player.remove_from_group(&"player")
	var node := _obstacle_map(_wall_map())
	node._physics_process(0.5)
	assert_eq(node.direction_from(Vector2(130, 40)), Vector2.ZERO)
	assert_true(node.is_blocked(Vector2(160, 56)))


func test_blocks_segment_agrees_with_testing_every_shape() -> void:
	var map := _wall_map(8.0)
	var circle := MapObstacle.new()
	circle.kind = MapObstacle.Kind.CIRCLE
	circle.position = Vector2(60, 100)
	circle.radius = 14.0
	map.obstacles.append(circle)
	var node := _obstacle_map(map)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var blocked := 0
	for i in 600:
		var from := Vector2(rng.randf_range(0, 320), rng.randf_range(0, 160))
		var to := from + Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(1.0, 40.0)
		var expected := false
		for obstacle in map.obstacles:
			expected = expected or obstacle.blocks_segment(from, to)
		assert_eq(node.blocks_segment(from, to), expected, "%s to %s" % [from, to])
		blocked += int(expected)
	assert_gt(blocked, 10, "the sample must include real hits")


func _maze_map(entrances: Array[MazeEntrance], extras: int = 0) -> MapData:
	var map := MapData.new()
	map.id = &"test"
	map.size = Vector2(700, 420)
	map.player_start = Vector2(8, 8)
	map.nav_cell_size = 16.0
	var maze := MapMaze.new()
	maze.area = Rect2(100, 52, 480, 320)
	maze.seed = 3
	maze.extra_openings = extras
	maze.entrances = entrances
	map.mazes = [maze] as Array[MapMaze]
	return map


func test_a_maze_wall_blocks_points_and_segments() -> void:
	var node := _obstacle_map(_maze_map([] as Array[MazeEntrance], 1000))
	assert_true(node.is_blocked(Vector2(100, 172)))
	assert_true(node.blocks_segment(Vector2(60, 172), Vector2(140, 172)), "across the outer wall")
	assert_false(node.blocks_segment(Vector2(140, 172), Vector2(220, 172)), "along an open corridor")


func test_the_flow_field_leads_through_a_maze() -> void:
	var entrance := MazeEntrance.new()
	entrance.cell = Vector2i(0, 1)
	entrance.side = MazeEntrance.Edge.WEST
	_player.global_position = Vector2(380, 252)
	var node := _obstacle_map(_maze_map([entrance] as Array[MazeEntrance]))
	var at := Vector2(60, 172)
	var reached := false
	for step in 900:
		if node.field.distance_at(at) == 0:
			reached = true
			break
		var direction := node.direction_from(at)
		if direction == Vector2.ZERO:
			break
		at += direction * 4.0
	assert_true(reached, "stopped at %s" % at)
