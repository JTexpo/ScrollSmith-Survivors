extends RefCounted
## Shared layout checks for the maps made in Sprint 16a (the forest and the maze), the same rules the ruins' tests pin: gaps, open squares,
## reachability, the guard test of the world pass. Static helpers over a `MapData` and its `ObstacleGrid`; the tests call them and assert.

const SCENE_DIR := "res://scenes/interactables/"
const RAYS := 16
## The player is a 12 px box, so a gap it could slip through is anything 12 px or wider; rays are grown by half of that.
const PLAYER_HALF_WIDTH := 6.0


static func positions(map: MapData, scene_name: String) -> Array[Vector2]:
	var found: Array[Vector2] = []
	for placement in map.placements:
		if placement.scene.resource_path == "%s%s.tscn" % [SCENE_DIR, scene_name]:
			found.append(placement.position)
	return found


## Every point of interest that is not a Lectern, in a fixed order.
static func points(map: MapData) -> Array[Vector2]:
	var found: Array[Vector2] = []
	for scene_name in ["health_shrine", "mana_shrine", "treasure_chest", "rare_scroll_spot", "merchant"]:
		found.append_array(positions(map, scene_name))
	return found


## Widths of every run of free cells that has a blocked cell at both ends, along rows and then along columns.
static func bounded_runs(grid: ObstacleGrid) -> Array[int]:
	var widths: Array[int] = []
	for along_rows in [true, false]:
		var lines: int = grid.rows if along_rows else grid.columns
		var length: int = grid.columns if along_rows else grid.rows
		for line in lines:
			var i := 0
			while i < length:
				if _blocked(grid, line, i, along_rows):
					i += 1
					continue
				var start := i
				while i < length and not _blocked(grid, line, i, along_rows):
					i += 1
				if start > 0 and i < length:
					widths.append(i - start)
	return widths


static func _blocked(grid: ObstacleGrid, line: int, i: int, along_rows: bool) -> bool:
	return grid.is_blocked_cell(Vector2i(i, line) if along_rows else Vector2i(line, i))


## True when some square of `size` by `size` free cells has its centre at least `distance` from `from`.
static func has_free_square(grid: ObstacleGrid, size: int, distance: float, from: Vector2) -> bool:
	for y in range(0, grid.rows - size + 1):
		for x in range(0, grid.columns - size + 1):
			var centre := grid.cell_center(Vector2i(x, y)) + Vector2(size - 1, size - 1) * grid.cell_size / 2.0
			if centre.distance_to(from) < distance:
				continue
			var free := true
			for dy in size:
				for dx in size:
					if grid.is_blocked_cell(Vector2i(x + dx, y + dy)):
						free = false
						break
				if not free:
					break
			if free:
				return true
	return false


## Free cells nobody can walk to from the start (empty when every free cell is reachable).
static func sealed_cells(grid: ObstacleGrid, start_point: Vector2) -> Array[Vector2i]:
	var start := grid.cell_of(start_point)
	var seen := PackedByteArray()
	seen.resize(grid.columns * grid.rows)
	var queue: Array[Vector2i] = [start]
	seen[start.y * grid.columns + start.x] = 1
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + step
			if grid.is_blocked_cell(next) or seen[next.y * grid.columns + next.x] == 1:
				continue
			seen[next.y * grid.columns + next.x] = 1
			queue.append(next)
	var sealed: Array[Vector2i] = []
	for y in grid.rows:
		for x in grid.columns:
			if not grid.is_blocked_cell(Vector2i(x, y)) and seen[y * grid.columns + x] == 0:
				sealed.append(Vector2i(x, y))
	return sealed


static func ray_blocked(shapes: Array[MapObstacle], point: Vector2, index: int, length: float) -> bool:
	var target := point + Vector2.from_angle(TAU * index / RAYS) * length
	for shape in shapes:
		if shape.blocks_segment(point, target, PLAYER_HALF_WIDTH):
			return true
	return false


## The free rays as runs round the circle (a closed guard with one opening has exactly one run).
static func free_runs(shapes: Array[MapObstacle], point: Vector2, length: float) -> Array[int]:
	var free: Array[bool] = []
	for i in RAYS:
		free.append(not ray_blocked(shapes, point, i, length))
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


## True when some ray from the point is free for 200 px (the opening leads to open ground).
static func opens_to_open_ground(shapes: Array[MapObstacle], point: Vector2) -> bool:
	for i in RAYS:
		if not ray_blocked(shapes, point, i, 200.0):
			return true
	return false


## The nearest solid shape's distance from the point (its outline, not its centre).
static func clearance(shapes: Array[MapObstacle], point: Vector2) -> float:
	var nearest := INF
	for shape in shapes:
		if shape.kind == MapObstacle.Kind.CIRCLE:
			nearest = minf(nearest, point.distance_to(shape.position) - shape.radius)
		else:
			var half := shape.size / 2.0
			var d := (point - shape.position).abs() - half
			nearest = minf(nearest, Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length() + minf(maxf(d.x, d.y), 0.0))
	return nearest


## The checks the forest and the maze tests share word for word (each takes the test, to assert on).
static func no_narrow_gaps(test: GutTest, grid: ObstacleGrid) -> void:
	for width in bounded_runs(grid):
		test.assert_gte(width, 2, "a gap only one cell wide would trap bigger enemies")


static func every_free_cell_reachable(test: GutTest, grid: ObstacleGrid, map: MapData) -> void:
	var sealed := sealed_cells(grid, map.player_start)
	test.assert_eq(sealed.size(), 0, "free cells nobody can walk to, for example %s" % str(sealed.slice(0, 4)))


static func same_points_of_interest_as_the_ruins(test: GutTest, map: MapData) -> void:
	var counts := {"lectern": 3, "rare_scroll_spot": 2, "treasure_chest": 1, "mana_shrine": 1, "health_shrine": 1, "merchant": 1}
	for scene_name in counts:
		test.assert_eq(positions(map, scene_name).size(), counts[scene_name], scene_name)
	test.assert_eq(map.placements.size(), 9)


static func spacing_rules(test: GutTest, map: MapData) -> void:
	var all := points(map)
	for i in all.size():
		for j in range(i + 1, all.size()):
			test.assert_gte(all[i].distance_to(all[j]), 400.0, "%s and %s are too close" % [all[i], all[j]])
	var lecterns := positions(map, "lectern")
	for i in lecterns.size():
		test.assert_gte(lecterns[i].distance_to(map.player_start), 400.0)
		for j in range(i + 1, lecterns.size()):
			test.assert_gte(lecterns[i].distance_to(lecterns[j]), 700.0)
