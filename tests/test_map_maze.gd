extends GutTest

const BOUNDS := Rect2(0, 0, 1920, 1080)


func _maze(seed_value: int = 1, extras: int = 0, center: bool = false, entrances: Array[MazeEntrance] = []) -> MapMaze:
	var maze := MapMaze.new()
	maze.area = Rect2(100, 52, 480, 320)
	maze.cell_size = 80.0
	maze.wall_thickness = 16.0
	maze.maze_seed = seed_value
	maze.extra_openings = extras
	maze.clear_center = center
	maze.entrances = entrances
	return maze


func _entrance(cell: Vector2i, side: MazeEntrance.Edge) -> MazeEntrance:
	var entrance := MazeEntrance.new()
	entrance.cell = cell
	entrance.side = side
	return entrance


func _blocked_at(maze: MapMaze, point: Vector2) -> bool:
	for shape in maze.shapes():
		if shape.contains(point):
			return true
	return false


func _center(maze: MapMaze, cell: Vector2i) -> Vector2:
	return maze.area.position + (Vector2(cell) + Vector2(0.5, 0.5)) * maze.cell_size


## True when nothing stands between two adjacent cells (no shape covers the midpoint of their shared edge).
func _open(maze: MapMaze, a: Vector2i, b: Vector2i) -> bool:
	return not _blocked_at(maze, (_center(maze, a) + _center(maze, b)) / 2.0)


func _passages(maze: MapMaze) -> int:
	var count := 0
	for y in maze.rows():
		for x in maze.columns():
			if x + 1 < maze.columns() and _open(maze, Vector2i(x, y), Vector2i(x + 1, y)):
				count += 1
			if y + 1 < maze.rows() and _open(maze, Vector2i(x, y), Vector2i(x, y + 1)):
				count += 1
	return count


func _reached(maze: MapMaze) -> int:
	var seen := {Vector2i(0, 0): true}
	var queue: Array[Vector2i] = [Vector2i(0, 0)]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + step
			if next.x < 0 or next.y < 0 or next.x >= maze.columns() or next.y >= maze.rows() or seen.has(next):
				continue
			if _open(maze, cell, next):
				seen[next] = true
				queue.append(next)
	return seen.size()


func test_columns_and_rows_come_from_the_area() -> void:
	assert_eq(_maze().columns(), 6)
	assert_eq(_maze().rows(), 4)


func test_every_shape_is_a_rect_inside_the_area_grown_by_a_wall() -> void:
	var maze := _maze()
	var allowed := maze.area.grow(maze.wall_thickness / 2.0 + 0.01)
	assert_gt(maze.shapes().size(), 10)
	for shape in maze.shapes():
		assert_eq(shape.kind, MapObstacle.Kind.RECT)
		assert_true(allowed.encloses(shape.bounds()), "%s" % shape.bounds())


func test_the_same_data_gives_the_same_shapes() -> void:
	var first := _maze(7, 2, true).shapes()
	var second := _maze(7, 2, true).shapes()
	assert_eq(first.size(), second.size())
	for i in first.size():
		assert_eq(first[i].position, second[i].position)
		assert_eq(first[i].size, second[i].size)


func test_a_different_seed_gives_a_different_maze() -> void:
	var first := _maze(1).shapes()
	var second := _maze(2).shapes()
	var same := first.size() == second.size()
	if same:
		for i in first.size():
			same = same and first[i].position == second[i].position and first[i].size == second[i].size
	assert_false(same)


func test_every_cell_is_connected() -> void:
	for seed_value in 12:
		assert_eq(_reached(_maze(seed_value)), 24, "seed %d" % seed_value)
	assert_eq(_reached(_maze(5, 3, true)), 24)
	assert_eq(_reached(_maze(5, 3, true, [_entrance(Vector2i(0, 1), MazeEntrance.Edge.WEST)] as Array[MazeEntrance])), 24)


func test_a_plain_maze_has_one_fewer_passage_than_cells() -> void:
	assert_eq(_passages(_maze(3)), 23)


func test_extra_openings_add_loops() -> void:
	assert_eq(_passages(_maze(3, 3)), 26)
	assert_eq(_passages(_maze(3, 1000)), 5 * 4 + 6 * 3, "capped at every wall removed")


func test_clear_center_opens_the_middle_cells() -> void:
	var maze := _maze(3, 0, true)
	assert_true(_open(maze, Vector2i(2, 1), Vector2i(3, 1)))
	assert_true(_open(maze, Vector2i(2, 2), Vector2i(3, 2)))
	assert_true(_open(maze, Vector2i(2, 1), Vector2i(2, 2)))
	assert_true(_open(maze, Vector2i(3, 1), Vector2i(3, 2)))


func test_the_boundary_is_closed_except_at_entrances() -> void:
	var closed := _maze(3)
	for y in 4:
		assert_true(_blocked_at(closed, Vector2(closed.area.position.x, closed.area.position.y + (y + 0.5) * 80.0)), "west edge row %d" % y)
		assert_true(_blocked_at(closed, Vector2(closed.area.end.x, closed.area.position.y + (y + 0.5) * 80.0)), "east edge row %d" % y)
	for x in 6:
		assert_true(_blocked_at(closed, Vector2(closed.area.position.x + (x + 0.5) * 80.0, closed.area.position.y)), "north edge column %d" % x)
		assert_true(_blocked_at(closed, Vector2(closed.area.position.x + (x + 0.5) * 80.0, closed.area.end.y)), "south edge column %d" % x)
	var entrances: Array[MazeEntrance] = [
		_entrance(Vector2i(2, 0), MazeEntrance.Edge.NORTH),
		_entrance(Vector2i(5, 1), MazeEntrance.Edge.EAST),
		_entrance(Vector2i(3, 3), MazeEntrance.Edge.SOUTH),
		_entrance(Vector2i(0, 2), MazeEntrance.Edge.WEST),
	]
	var opened := _maze(3, 0, false, entrances)
	assert_false(_blocked_at(opened, Vector2(opened.area.position.x + 2.5 * 80.0, opened.area.position.y)))
	assert_false(_blocked_at(opened, Vector2(opened.area.end.x, opened.area.position.y + 1.5 * 80.0)))
	assert_false(_blocked_at(opened, Vector2(opened.area.position.x + 3.5 * 80.0, opened.area.end.y)))
	assert_false(_blocked_at(opened, Vector2(opened.area.position.x, opened.area.position.y + 2.5 * 80.0)))
	assert_true(_blocked_at(opened, Vector2(opened.area.position.x + 1.5 * 80.0, opened.area.position.y)), "other edges stay closed")


func test_problems_name_a_bad_maze() -> void:
	assert_true(_maze().problems(BOUNDS).is_empty(), str(_maze().problems(BOUNDS)))
	var outside := _maze()
	outside.area = Rect2(1800, 1000, 480, 320)
	assert_eq(outside.problems(BOUNDS).size(), 1)
	var narrow := _maze()
	narrow.area = Rect2(100, 52, 160, 320)
	assert_eq(narrow.problems(BOUNDS).size(), 1)
	var interior := _maze(1, 0, false, [_entrance(Vector2i(2, 2), MazeEntrance.Edge.NORTH)] as Array[MazeEntrance])
	assert_eq(interior.problems(BOUNDS).size(), 1)
	var inward := _maze(1, 0, false, [_entrance(Vector2i(0, 1), MazeEntrance.Edge.EAST)] as Array[MazeEntrance])
	assert_eq(inward.problems(BOUNDS).size(), 1)


func _wide_maze(rotated: bool, center: bool = true) -> MapMaze:
	var maze := _maze(3, 2, center, [_entrance(Vector2i(0, 1), MazeEntrance.Edge.WEST), _entrance(Vector2i(2, 4), MazeEntrance.Edge.SOUTH)] as Array[MazeEntrance])
	maze.area = Rect2(100, 52, 560, 400)
	maze.rotated = rotated
	return maze


func test_a_rotated_maze_is_the_half_turn_image_of_the_same_maze() -> void:
	var plain := _wide_maze(false)
	var turned := _wide_maze(true)
	var middle := plain.area.get_center()
	var plain_shapes := plain.shapes()
	var turned_shapes := turned.shapes()
	assert_eq(plain_shapes.size(), turned_shapes.size())
	for shape in plain_shapes:
		var image := middle * 2.0 - shape.position
		var found := false
		for other in turned_shapes:
			if other.position.distance_to(image) < 0.01 and other.size == shape.size:
				found = true
				break
		assert_true(found, "no mirrored wall for %s" % shape.position)


func test_a_rotated_maze_is_still_connected_and_its_entrances_turn_with_it() -> void:
	var turned := _wide_maze(true)
	assert_eq(_reached(turned), turned.columns() * turned.rows())
	# The west entrance of row 1 becomes an east entrance of row rows-2, and the south one of column 2 a north one of column cols-3.
	var east_row := turned.area.position.y + (turned.rows() - 2 + 0.5) * 80.0
	assert_false(_blocked_at(turned, Vector2(turned.area.end.x, east_row)))
	assert_true(_blocked_at(turned, Vector2(turned.area.position.x, turned.area.position.y + 1.5 * 80.0)), "the old west gap is closed")
	var north_x := turned.area.position.x + (turned.columns() - 3 + 0.5) * 80.0
	assert_false(_blocked_at(turned, Vector2(north_x, turned.area.position.y)))


func test_the_centre_room_centre_follows_the_rotation_and_is_free() -> void:
	var plain := _wide_maze(false)
	var turned := _wide_maze(true)
	assert_eq(plain.center_room_center(), plain.area.position + Vector2(3, 2) * 80.0)
	assert_eq(turned.center_room_center(), turned.area.position + Vector2(4, 3) * 80.0)
	for maze in [plain, turned]:
		for offset in [Vector2.ZERO, Vector2(-40, 0), Vector2(40, 0), Vector2(0, -40), Vector2(0, 40)]:
			assert_false(_blocked_at(maze, maze.center_room_center() + offset), "centre room wall at %s" % offset)


func test_straight_runs_of_wall_are_one_long_shape() -> void:
	var maze := _maze(3)
	var longest_wide := 0.0
	var longest_tall := 0.0
	for shape in maze.shapes():
		longest_wide = maxf(longest_wide, shape.size.x)
		longest_tall = maxf(longest_tall, shape.size.y)
	# With no entrances the four outer sides are each a single run: 6 cells wide and 4 cells tall, plus a wall.
	assert_almost_eq(longest_wide, 6 * 80.0 + 16.0, 0.01)
	assert_almost_eq(longest_tall, 4 * 80.0 + 16.0, 0.01)


func test_merging_walls_does_not_change_what_is_solid() -> void:
	var maze := _maze(9, 2, true, [_entrance(Vector2i(0, 1), MazeEntrance.Edge.WEST)] as Array[MazeEntrance])
	assert_eq(_reached(maze), 24)
	assert_gte(_passages(maze), 23 + 2, "at least the spanning tree plus the extra openings")


func test_every_wall_carries_the_mazes_material() -> void:
	var maze := _maze(3, 1, true)
	maze.material = &"hedge"
	var walls := maze.shapes()
	assert_gt(walls.size(), 0)
	for wall in walls:
		assert_eq(wall.material, &"hedge")


func test_a_maze_without_a_material_gives_empty_materials() -> void:
	for wall in _maze().shapes():
		assert_eq(wall.material, &"")

