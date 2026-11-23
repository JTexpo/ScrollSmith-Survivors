class_name ObstacleGrid
extends RefCounted
## A coarse grid over a map: a cell is blocked when any obstacle, grown by the map's body clearance,
## touches it. The flow field sweeps over the free cells, and enemies are kept out of the blocked ones.

var cell_size: float = 16.0
var columns: int = 0
var rows: int = 0
## One byte per cell, row by row: 1 is blocked.
var blocked := PackedByteArray()


static func build(map: MapData) -> ObstacleGrid:
	var grid := ObstacleGrid.new()
	grid.cell_size = maxf(map.nav_cell_size, 1.0)
	grid.columns = maxi(ceili(map.size.x / grid.cell_size), 1)
	grid.rows = maxi(ceili(map.size.y / grid.cell_size), 1)
	grid.blocked.resize(grid.columns * grid.rows)
	for obstacle in map.obstacles:
		if obstacle == null or not obstacle.is_valid():
			continue
		var area := obstacle.bounds().grow(map.body_clearance)
		var first := grid.cell_of(area.position)
		var last := grid.cell_of(area.end)
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var cell_rect := Rect2(Vector2(x, y) * grid.cell_size, Vector2(grid.cell_size, grid.cell_size))
				if obstacle.overlaps_rect(cell_rect, map.body_clearance):
					grid.blocked[y * grid.columns + x] = 1
	return grid


## The cell holding `point`, clamped into the grid.
func cell_of(point: Vector2) -> Vector2i:
	return Vector2i(
		clampi(floori(point.x / cell_size), 0, columns - 1),
		clampi(floori(point.y / cell_size), 0, rows - 1),
	)


func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


## Cells outside the grid count as blocked.
func is_blocked_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows:
		return true
	return blocked[cell.y * columns + cell.x] == 1


func is_blocked(point: Vector2) -> bool:
	return is_blocked_cell(cell_of(point))


## `point` itself when it is free, otherwise the centre of the nearest free cell (ring by ring, the closest
## of each ring), or `point` again when nothing is free.
func nearest_free(point: Vector2) -> Vector2:
	if not is_blocked(point):
		return point
	var origin := cell_of(point)
	for ring in range(1, maxi(columns, rows)):
		var best := Vector2.INF
		var best_distance := INF
		for y in range(origin.y - ring, origin.y + ring + 1):
			for x in range(origin.x - ring, origin.x + ring + 1):
				if maxi(absi(x - origin.x), absi(y - origin.y)) != ring or is_blocked_cell(Vector2i(x, y)):
					continue
				var center := cell_center(Vector2i(x, y))
				var distance := center.distance_to(point)
				if distance < best_distance:
					best_distance = distance
					best = center
		if best != Vector2.INF:
			return best
	return point


## One line per fault: the start sits in a blocked cell, or a placement cannot be reached from it.
static func reachability_problems(map: MapData) -> PackedStringArray:
	var found := PackedStringArray()
	var grid := ObstacleGrid.build(map)
	var start := grid.cell_of(map.player_start)
	if grid.is_blocked_cell(start):
		found.append("the player start is inside an obstacle's reach")
		return found
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
	for i in map.placements.size():
		var placement := map.placements[i]
		if placement == null:
			continue
		var cell := grid.cell_of(placement.position)
		if grid.is_blocked_cell(cell) or seen[cell.y * grid.columns + cell.x] == 0:
			found.append("placement %d at %s is not reachable from the player start" % [i, placement.position])
	return found
