class_name MapMaze
extends Resource
## A maze generated from data: the same data always gives the same walls. It fills `area` with a grid of
## cells `cell_size` apart (wall centre to wall centre). `shapes()` returns the walls as rectangle obstacles,
## so everything that handles obstacles (the grid, the flow field, the physics walls, shots) handles a maze.

## Where the maze sits. Its cells are `floori(size / cell_size)` columns and rows, from the top-left corner.
@export var area: Rect2 = Rect2()
## Distance between wall centres. A wall of 16 px at 80 leaves a 64 px gap.
@export var cell_size: float = 80.0
@export var wall_thickness: float = 16.0
@export var maze_seed: int = 0
## Gaps in the outer wall.
@export var entrances: Array[MazeEntrance] = []
## Walls removed after generating, so the maze has loops (never more than remain).
@export var extra_openings: int = 0
## Opens the middle 2 by 2 cells into one room.
@export var clear_center: bool = false
## Turns the whole generated maze half a turn (entrances included). A second maze with the same data and this set is
## an exact mirror image of the first, for the opposite corner of the map.
@export var rotated: bool = false
## What the walls are made of (`hedge` ...), stamped on every wall it generates.
@export var material: StringName = &""

const MIN_CELLS := 3
## North, east, south, west.
const STEPS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


## Which walls stand. `vertical[x * rows + y]` is the wall on the vertical line left of column x (x from 0 to
## columns) in row y. `horizontal[y * columns + x]` is the wall on the horizontal line above row y (y from 0
## to rows) in column x. 1 means a wall.
class Layout:
	extends RefCounted
	var columns: int
	var rows: int
	var vertical := PackedByteArray()
	var horizontal := PackedByteArray()

	func _init(column_count: int, row_count: int) -> void:
		columns = column_count
		rows = row_count
		vertical.resize((columns + 1) * rows)
		vertical.fill(1)
		horizontal.resize(columns * (rows + 1))
		horizontal.fill(1)

	## Removes the wall between `cell` and its neighbour `step` away.
	func carve(cell: Vector2i, step: Vector2i) -> void:
		if step.x == 1:
			vertical[(cell.x + 1) * rows + cell.y] = 0
		elif step.x == -1:
			vertical[cell.x * rows + cell.y] = 0
		elif step.y == 1:
			horizontal[(cell.y + 1) * columns + cell.x] = 0
		else:
			horizontal[cell.y * columns + cell.x] = 0


## The world position of the middle of the cleared room (where the room's centre is, after any half turn). It is
## the point where the four middle cells meet. Meaningful when `clear_center` is on.
func center_room_center() -> Vector2:
	var column := floori(columns() / 2.0)
	var row := floori(rows() / 2.0)
	if rotated:
		column = columns() - column
		row = rows() - row
	return area.position + Vector2(column, row) * cell_size


## The world positions of the centres of every cell with exactly one opening, row by row (after the extra openings, the cleared
## centre, the entrances and any half turn). The places to put things a player has to go into and come back out of.
func dead_end_cells() -> Array[Vector2]:
	var found: Array[Vector2] = []
	if columns() < MIN_CELLS or rows() < MIN_CELLS:
		return found
	var layout := _generate()
	for y in layout.rows:
		for x in layout.columns:
			var walls := layout.vertical[x * layout.rows + y] + layout.vertical[(x + 1) * layout.rows + y]
			walls += layout.horizontal[y * layout.columns + x] + layout.horizontal[(y + 1) * layout.columns + x]
			if walls == 3:
				found.append(area.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * cell_size)
	return found


func columns() -> int:
	return floori(area.size.x / cell_size) if cell_size > 0.0 else 0


func rows() -> int:
	return floori(area.size.y / cell_size) if cell_size > 0.0 else 0


## One line per fault. Empty means the maze can be built.
func problems(bounds: Rect2) -> PackedStringArray:
	var found := PackedStringArray()
	if cell_size <= 0.0 or wall_thickness <= 0.0:
		found.append("the cell size and wall thickness must be positive")
		return found
	if not bounds.encloses(area):
		found.append("the maze area %s is outside the map" % area)
	if columns() < MIN_CELLS or rows() < MIN_CELLS:
		found.append("the maze needs at least %d columns and rows, it has %d by %d" % [MIN_CELLS, columns(), rows()])
		return found
	for i in entrances.size():
		var entrance := entrances[i]
		if entrance == null or not _faces_out(entrance):
			found.append("entrance %d is not on the maze's outer wall facing out" % i)
	return found


## The maze's walls as RECT obstacles, vertical lines first, then horizontal ones, each in a fixed order. Walls that continue along one line are merged into one rectangle.
func shapes() -> Array[MapObstacle]:
	var result: Array[MapObstacle] = []
	if columns() < MIN_CELLS or rows() < MIN_CELLS:
		return result
	var layout := _generate()
	# Walls that continue along one line are one long rectangle (the same area, far fewer shapes).
	for x in layout.columns + 1:
		var y := 0
		while y < layout.rows:
			if layout.vertical[x * layout.rows + y] == 0:
				y += 1
				continue
			var start := y
			while y < layout.rows and layout.vertical[x * layout.rows + y] == 1:
				y += 1
			result.append(_wall(area.position + Vector2(x, (start + y) / 2.0) * cell_size, Vector2(wall_thickness, (y - start) * cell_size + wall_thickness)))
	for y in layout.rows + 1:
		var x := 0
		while x < layout.columns:
			if layout.horizontal[y * layout.columns + x] == 0:
				x += 1
				continue
			var start := x
			while x < layout.columns and layout.horizontal[y * layout.columns + x] == 1:
				x += 1
			result.append(_wall(area.position + Vector2((start + x) / 2.0, y) * cell_size, Vector2((x - start) * cell_size + wall_thickness, wall_thickness)))
	return result


func _wall(center: Vector2, size: Vector2) -> MapObstacle:
	var wall := MapObstacle.new()
	wall.kind = MapObstacle.Kind.RECT
	wall.position = center
	wall.size = size
	wall.material = material
	return wall


func _faces_out(entrance: MazeEntrance) -> bool:
	var cell := entrance.cell
	if cell.x < 0 or cell.y < 0 or cell.x >= columns() or cell.y >= rows():
		return false
	match entrance.side:
		MazeEntrance.Edge.NORTH:
			return cell.y == 0
		MazeEntrance.Edge.SOUTH:
			return cell.y == rows() - 1
		MazeEntrance.Edge.WEST:
			return cell.x == 0
	return cell.x == columns() - 1


func _generate() -> Layout:
	var layout := Layout.new(columns(), rows())
	var rng := RandomNumberGenerator.new()
	rng.seed = maze_seed
	# A recursive backtracker (iterative depth-first search) from the top-left cell.
	var visited := PackedByteArray()
	visited.resize(layout.columns * layout.rows)
	visited[0] = 1
	var stack: Array[Vector2i] = [Vector2i.ZERO]
	while not stack.is_empty():
		var cell: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for step in STEPS:
			var next := cell + step
			if next.x >= 0 and next.y >= 0 and next.x < layout.columns and next.y < layout.rows and visited[next.y * layout.columns + next.x] == 0:
				options.append(step)
		if options.is_empty():
			stack.pop_back()
			continue
		var chosen := options[rng.randi_range(0, options.size() - 1)]
		layout.carve(cell, chosen)
		var neighbour := cell + chosen
		visited[neighbour.y * layout.columns + neighbour.x] = 1
		stack.append(neighbour)
	_open_extras(layout, rng)
	if clear_center:
		_open_center(layout)
	for entrance in entrances:
		if entrance != null and _faces_out(entrance):
			layout.carve(entrance.cell, STEPS[entrance.side])
	return _half_turn(layout) if rotated else layout


## The same walls turned half a turn about the maze's middle.
func _half_turn(layout: Layout) -> Layout:
	var turned := Layout.new(layout.columns, layout.rows)
	for x in layout.columns + 1:
		for y in layout.rows:
			turned.vertical[(layout.columns - x) * layout.rows + (layout.rows - 1 - y)] = layout.vertical[x * layout.rows + y]
	for y in layout.rows + 1:
		for x in layout.columns:
			turned.horizontal[(layout.rows - y) * layout.columns + (layout.columns - 1 - x)] = layout.horizontal[y * layout.columns + x]
	return turned


## Removes `extra_openings` of the walls still standing between two cells, picked at random.
func _open_extras(layout: Layout, rng: RandomNumberGenerator) -> void:
	var standing: Array[Vector3i] = []
	for x in range(1, layout.columns):
		for y in layout.rows:
			if layout.vertical[x * layout.rows + y] == 1:
				standing.append(Vector3i(x, y, 0))
	for y in range(1, layout.rows):
		for x in layout.columns:
			if layout.horizontal[y * layout.columns + x] == 1:
				standing.append(Vector3i(x, y, 1))
	for i in mini(extra_openings, standing.size()):
		var pick := rng.randi_range(0, standing.size() - 1)
		var wall := standing[pick]
		standing.remove_at(pick)
		if wall.z == 0:
			layout.vertical[wall.x * layout.rows + wall.y] = 0
		else:
			layout.horizontal[wall.y * layout.columns + wall.x] = 0


func _open_center(layout: Layout) -> void:
	var left := floori(layout.columns / 2.0) - 1
	var top := floori(layout.rows / 2.0) - 1
	layout.carve(Vector2i(left, top), Vector2i(1, 0))
	layout.carve(Vector2i(left, top + 1), Vector2i(1, 0))
	layout.carve(Vector2i(left, top), Vector2i(0, 1))
	layout.carve(Vector2i(left + 1, top), Vector2i(0, 1))
