extends GutTest

var _map: MapData
var _grid: ObstacleGrid


func before_each() -> void:
	_map = load("res://resources/maps/first_map.tres") as MapData
	_grid = ObstacleGrid.build(_map)


## Widths of every run of free cells that has a blocked cell at both ends, along rows and then along columns.
func _bounded_runs() -> Array[int]:
	var widths: Array[int] = []
	for along_rows in [true, false]:
		var lines: int = _grid.rows if along_rows else _grid.columns
		var length: int = _grid.columns if along_rows else _grid.rows
		for line in lines:
			var i := 0
			while i < length:
				if _blocked_at(line, i, along_rows):
					i += 1
					continue
				var start := i
				while i < length and not _blocked_at(line, i, along_rows):
					i += 1
				# The cell before a run is blocked (unless the run starts at the edge), and the one at `i` is too.
				if start > 0 and i < length:
					widths.append(i - start)
	return widths


func _blocked_at(line: int, i: int, along_rows: bool) -> bool:
	return _grid.is_blocked_cell(Vector2i(i, line) if along_rows else Vector2i(line, i))


func test_the_first_map_has_between_50_and_220_solid_shapes() -> void:
	assert_between(_map.solid_shapes().size(), 50, 220)


func test_the_first_map_has_no_problems_and_every_placement_is_reachable() -> void:
	assert_true(_map.problems().is_empty(), str(_map.problems()))
	assert_true(ObstacleGrid.reachability_problems(_map).is_empty(), str(ObstacleGrid.reachability_problems(_map)))


func test_the_outer_48px_band_has_no_obstacles() -> void:
	var inner := Rect2(Vector2(48, 48), _map.size - Vector2(96, 96))
	for obstacle in _map.solid_shapes():
		assert_true(inner.encloses(obstacle.bounds()), "obstacle at %s is too close to the edge" % obstacle.position)


func test_the_central_area_is_open() -> void:
	for obstacle in _map.solid_shapes():
		assert_false(obstacle.contains(_map.player_start, 150.0), "obstacle at %s is inside the central area" % obstacle.position)


func test_most_of_the_map_is_still_walkable() -> void:
	var blocked := 0
	for value in _grid.blocked:
		blocked += value
	var share := float(blocked) / float(_grid.columns * _grid.rows)
	assert_between(share, 0.03, 0.40)


func test_no_gap_is_narrower_than_two_cells() -> void:
	for width in _bounded_runs():
		assert_gte(width, 2, "a gap only one cell wide would trap bigger enemies")


func test_the_map_has_narrow_paths_and_open_ground() -> void:
	var narrow := 0
	for width in _bounded_runs():
		if width <= 3:
			narrow += 1
	assert_gte(narrow, 8, "corridors: rows or columns with a 2 to 3 cell wide bounded run")
	assert_true(_has_free_square(10, 400.0), "an open square away from the start where small loops fit")


## True when some square of `size` by `size` free cells has its centre at least `distance` from the start.
func _has_free_square(size: int, distance: float) -> bool:
	for y in range(0, _grid.rows - size + 1):
		for x in range(0, _grid.columns - size + 1):
			var centre := _grid.cell_center(Vector2i(x, y)) + Vector2(size - 1, size - 1) * _grid.cell_size / 2.0
			if centre.distance_to(_map.player_start) < distance:
				continue
			var free := true
			for dy in size:
				for dx in size:
					if _grid.is_blocked_cell(Vector2i(x + dx, y + dy)):
						free = false
						break
				if not free:
					break
			if free:
				return true
	return false


func test_every_free_cell_is_reachable_from_the_start() -> void:
	var start := _grid.cell_of(_map.player_start)
	var seen := PackedByteArray()
	seen.resize(_grid.columns * _grid.rows)
	var queue: Array[Vector2i] = [start]
	seen[start.y * _grid.columns + start.x] = 1
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + step
			if _grid.is_blocked_cell(next) or seen[next.y * _grid.columns + next.x] == 1:
				continue
			seen[next.y * _grid.columns + next.x] = 1
			queue.append(next)
	var sealed: Array[Vector2i] = []
	for y in _grid.rows:
		for x in _grid.columns:
			if not _grid.is_blocked_cell(Vector2i(x, y)) and seen[y * _grid.columns + x] == 0:
				sealed.append(Vector2i(x, y))
	assert_eq(sealed.size(), 0, "free cells nobody can walk to, for example %s" % str(sealed.slice(0, 4)))
