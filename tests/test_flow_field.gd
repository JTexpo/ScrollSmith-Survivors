extends GutTest


func _map(size: Vector2) -> MapData:
	var map := MapData.new()
	map.id = &"test"
	map.size = size
	map.player_start = Vector2(8, 8)
	map.nav_cell_size = 16.0
	map.body_clearance = 0.0
	return map


func _rect(position: Vector2, size: Vector2) -> MapObstacle:
	var obstacle := MapObstacle.new()
	obstacle.kind = MapObstacle.Kind.RECT
	obstacle.position = position
	obstacle.size = size
	return obstacle


func _field(map: MapData, target: Vector2) -> FlowField:
	var field := FlowField.new()
	field.rebuild(ObstacleGrid.build(map), target)
	return field


## Walks the field from `start` in 4 px steps. True when it reaches the target's own cell.
func _reaches(field: FlowField, start: Vector2, target: Vector2, max_steps: int) -> bool:
	var at := start
	for step in max_steps:
		if field.distance_at(at) == 0:
			return true
		var direction := field.direction_at(at)
		if direction == Vector2.ZERO:
			return false
		at += direction * 4.0
	return false


func test_the_target_cell_has_distance_zero_and_distances_grow_away_from_it() -> void:
	var field := _field(_map(Vector2(160, 160)), Vector2(80, 80))
	assert_eq(field.distance_at(Vector2(80, 80)), 0)
	var previous := 0
	for x in range(96, 160, 16):
		var distance := field.distance_at(Vector2(x + 8, 88))
		assert_gt(distance, previous)
		previous = distance


func test_in_open_ground_the_direction_is_within_15_degrees_of_the_straight_line() -> void:
	var target := Vector2(200, 200)
	var field := _field(_map(Vector2(400, 400)), target)
	for x in range(8, 400, 16):
		for y in range(8, 400, 16):
			var point := Vector2(x, y)
			if point.distance_to(target) < 40.0:
				continue
			var angle := rad_to_deg(field.direction_at(point).angle_to((target - point).normalized()))
			assert_lt(absf(angle), 15.0, "at %s" % point)


func test_a_wall_between_makes_the_direction_go_around_it() -> void:
	var map := _map(Vector2(320, 160))
	map.obstacles = [_rect(Vector2(160, 56), Vector2(16, 112))] as Array[MapObstacle]
	var field := _field(map, Vector2(280, 40))
	assert_gt(field.direction_at(Vector2(130, 40)).y, 0.2)
	assert_true(_reaches(field, Vector2(40, 40), Vector2(280, 40), 400))


func test_a_u_shaped_dead_end_is_escaped() -> void:
	var map := _map(Vector2(320, 320))
	map.obstacles = [
		_rect(Vector2(160, 112), Vector2(128, 16)),
		_rect(Vector2(104, 176), Vector2(16, 128)),
		_rect(Vector2(216, 176), Vector2(16, 128)),
	] as Array[MapObstacle]
	var field := _field(map, Vector2(160, 170))
	assert_true(_reaches(field, Vector2(160, 40), Vector2(160, 170), 700))


func test_blocked_and_sealed_cells_have_no_direction() -> void:
	var map := _map(Vector2(160, 160))
	map.obstacles = [
		_rect(Vector2(80, 56), Vector2(64, 8)),
		_rect(Vector2(80, 104), Vector2(64, 8)),
		_rect(Vector2(56, 80), Vector2(8, 64)),
		_rect(Vector2(104, 80), Vector2(8, 64)),
	] as Array[MapObstacle]
	var field := _field(map, Vector2(20, 20))
	assert_eq(field.distance_at(Vector2(80, 80)), -1)
	assert_eq(field.direction_at(Vector2(80, 80)), Vector2.ZERO)
	assert_eq(field.distance_at(Vector2(56, 56)), -1)
	assert_eq(field.direction_at(Vector2(56, 56)), Vector2.ZERO)


func test_the_sweep_never_crosses_a_blocked_corner() -> void:
	var map := _map(Vector2(48, 48))
	map.obstacles = [_rect(Vector2(24, 8), Vector2(14, 14)), _rect(Vector2(8, 24), Vector2(14, 14))] as Array[MapObstacle]
	var field := _field(map, Vector2(24, 24))
	assert_eq(field.distance_at(Vector2(8, 8)), -1)


func test_rebuilding_for_a_new_target_replaces_the_old_field() -> void:
	var grid := ObstacleGrid.build(_map(Vector2(160, 160)))
	var field := FlowField.new()
	field.rebuild(grid, Vector2(24, 24))
	field.rebuild(grid, Vector2(136, 136))
	assert_eq(field.distance_at(Vector2(136, 136)), 0)
	assert_gt(field.distance_at(Vector2(24, 24)), 0)


func test_a_target_in_a_blocked_cell_still_gets_a_field() -> void:
	var map := _map(Vector2(160, 160))
	map.obstacles = [_rect(Vector2(80, 80), Vector2(40, 40))] as Array[MapObstacle]
	var field := _field(map, Vector2(80, 80))
	assert_gte(field.distance_at(Vector2(20, 20)), 0)
	assert_ne(field.direction_at(Vector2(20, 20)), Vector2.ZERO)


func test_an_incremental_build_matches_the_synchronous_one() -> void:
	var map := _map(Vector2(320, 160))
	map.obstacles = [_rect(Vector2(160, 56), Vector2(16, 112))] as Array[MapObstacle]
	var grid := ObstacleGrid.build(map)
	var whole := FlowField.new()
	whole.rebuild(grid, Vector2(280, 40))
	var parts := FlowField.new()
	parts.begin_rebuild(grid, Vector2(280, 40))
	assert_true(parts.is_rebuilding())
	var calls := 0
	while not parts.advance(7):
		calls += 1
		assert_lt(calls, 1000)
	assert_gt(calls, 3)
	assert_false(parts.is_rebuilding())
	for x in range(8, 320, 16):
		for y in range(8, 160, 16):
			assert_eq(parts.distance_at(Vector2(x, y)), whole.distance_at(Vector2(x, y)), "at %s" % Vector2(x, y))


func test_the_last_finished_field_stays_readable_while_a_new_one_builds() -> void:
	var grid := ObstacleGrid.build(_map(Vector2(160, 160)))
	var field := FlowField.new()
	field.rebuild(grid, Vector2(24, 24))
	var before := field.distance_at(Vector2(136, 136))
	field.begin_rebuild(grid, Vector2(136, 136))
	field.advance(3)
	assert_true(field.is_rebuilding())
	assert_eq(field.distance_at(Vector2(136, 136)), before)
	while not field.advance(50):
		pass
	assert_eq(field.distance_at(Vector2(136, 136)), 0)


func test_cached_directions_are_dropped_when_a_new_field_is_swapped_in() -> void:
	var grid := ObstacleGrid.build(_map(Vector2(160, 160)))
	var field := FlowField.new()
	field.rebuild(grid, Vector2(24, 88))
	assert_lt(field.direction_at(Vector2(136, 88)).x, -0.9, "toward the first target (west), now cached")
	field.rebuild(grid, Vector2(136, 136))
	assert_gt(field.direction_at(Vector2(136, 88)).y, 0.9, "toward the second target (south), not the cached one")
	field.begin_rebuild(grid, Vector2(24, 88))
	assert_gt(field.direction_at(Vector2(136, 88)).y, 0.9, "the old field stays readable while a new one builds")


func test_goal_cell_is_the_targets_cell_or_the_nearest_free_one() -> void:
	var map := _map(Vector2(160, 160))
	map.obstacles = [_rect(Vector2(80, 80), Vector2(40, 40))] as Array[MapObstacle]
	var grid := ObstacleGrid.build(map)
	var field := FlowField.new()
	assert_eq(field.goal_cell(), Vector2i(-1, -1), "none before the first field")
	field.rebuild(grid, Vector2(20, 20))
	assert_eq(field.goal_cell(), grid.cell_of(Vector2(20, 20)))
	field.rebuild(grid, Vector2(80, 80))
	assert_false(grid.is_blocked_cell(field.goal_cell()), "a blocked target uses the nearest free cell")
	assert_eq(field.goal_cell(), grid.cell_of(grid.nearest_free(Vector2(80, 80))))
