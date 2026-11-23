class_name FlowField
extends RefCounted
## For every free cell of an `ObstacleGrid`, how far it is from a target and which way to walk to get there.
## One sweep outward from the target (Dial's algorithm), then each enemy just reads its own cell. Steps are the
## 16 moves of the 5x5 chamfer (cost 10 straight, 14 diagonal, 22 knight), which keeps open-ground directions
## close to the straight line, and a step never cuts across a blocked cell.
##
## A sweep over a whole map is too much for one frame, so it is done in pieces: `begin_rebuild` starts one,
## `advance` does a budget of cells, and the finished field replaces the old one all at once. Until then
## readers keep using the last finished field. `rebuild` does it all in one call (for tests and the first build).
##
## The work runs on flat arrays with a 2-cell blocked border, so the inner loop does no bounds checks, makes
## no `Vector2i` and calls no methods.

const STRAIGHT_COST := 10
const DIAGONAL_COST := 14
const KNIGHT_COST := 22
## One more than the largest step cost, so a bucket never receives a push while it is being read.
const BUCKETS := 23
## Border of blocked cells around the grid, wide enough for a knight move.
const PAD := 2
const MOVES: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1),
	Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2),
]

var _grid: ObstacleGrid
var _prepared: ObstacleGrid
var _stride: int = 0
## Blocked cells with the border, one byte each.
var _pad := PackedByteArray()
## Per move: the index step, its cost, the two cells it passes between (the cell itself for a straight
## move) and its unit direction.
var _step := PackedInt32Array()
var _cost := PackedInt32Array()
var _via_a := PackedInt32Array()
var _via_b := PackedInt32Array()
var _unit := PackedVector2Array()
## The last finished field, padded layout. -1 is unreached or blocked. Empty before the first one.
var _distance := PackedInt32Array()
var _building := PackedInt32Array()
var _buckets: Array[PackedInt32Array] = []
var _cursor: int = 0
var _level: int = 0
var _pending: int = 0
var _active: bool = false


## Sweeps to the end in one call.
func rebuild(grid: ObstacleGrid, target: Vector2) -> void:
	begin_rebuild(grid, target)
	advance(1 << 30)


## Starts a sweep from the cell holding `target` (or the nearest free cell when that one is blocked),
## dropping any sweep in progress. The finished field is not replaced until `advance` completes it.
func begin_rebuild(grid: ObstacleGrid, target: Vector2) -> void:
	_grid = grid
	_prepare(grid)
	_building = PackedInt32Array()
	_building.resize(_pad.size())
	_building.fill(-1)
	_active = false
	var goal := grid.cell_of(target)
	if grid.is_blocked_cell(goal):
		goal = grid.cell_of(grid.nearest_free(target))
	if grid.is_blocked_cell(goal):
		_distance = _building
		return
	_buckets.clear()
	for i in BUCKETS:
		_buckets.append(PackedInt32Array())
	var start := (goal.y + PAD) * _stride + goal.x + PAD
	_building[start] = 0
	_buckets[0].append(start)
	_pending = 1
	_level = 0
	_cursor = 0
	_active = true


func is_rebuilding() -> bool:
	return _active


## Processes up to `cell_budget` cells of the sweep in progress. True once nothing is left to do (the new
## field is then the readable one), and also when no sweep is in progress.
func advance(cell_budget: int) -> bool:
	if not _active:
		return true
	var pad := _pad
	var step := _step
	var cost := _cost
	var via_a := _via_a
	var via_b := _via_b
	var distance := _building
	var processed := 0
	while _pending > 0 and processed < cell_budget:
		var slot := _level % BUCKETS
		var bucket := _buckets[slot]
		while _cursor < bucket.size() and processed < cell_budget:
			var here := bucket[_cursor]
			_cursor += 1
			_pending -= 1
			if distance[here] != _level:
				continue
			processed += 1
			for k in 16:
				var next := here + step[k]
				if pad[next] != 0 or pad[here + via_a[k]] != 0 or pad[here + via_b[k]] != 0:
					continue
				var total := _level + cost[k]
				var old := distance[next]
				if old == -1 or total < old:
					distance[next] = total
					_buckets[total % BUCKETS].append(next)
					_pending += 1
		if _cursor >= bucket.size():
			_buckets[slot] = PackedInt32Array()
			_cursor = 0
			_level += 1
	if _pending > 0:
		return false
	_building = distance
	_distance = distance
	_active = false
	return true


## The cost from `point`'s cell to the target, or -1 when unreached or blocked (or before the first field).
func distance_at(point: Vector2) -> int:
	if _grid == null or _distance.is_empty():
		return -1
	return _distance[_index_of(point)]


## A unit vector toward the target along the field, or ZERO in a blocked or unreached cell and in the
## target's own cell. Each lower neighbour pulls in proportion to how much closer it is.
func direction_at(point: Vector2) -> Vector2:
	if _grid == null or _distance.is_empty():
		return Vector2.ZERO
	var here := _index_of(point)
	var level := _distance[here]
	if level <= 0:
		return Vector2.ZERO
	var pull := Vector2.ZERO
	var total_gain := 0
	var best := -1
	var best_gain := 0
	for k in 16:
		var next := here + _step[k]
		if _pad[next] != 0 or _pad[here + _via_a[k]] != 0 or _pad[here + _via_b[k]] != 0:
			continue
		var gain := level - _distance[next]
		if gain > 0:
			pull += _unit[k] * gain
			total_gain += gain
			if gain > best_gain:
				best_gain = gain
				best = k
	if best == -1:
		return Vector2.ZERO
	var blended := pull.normalized()
	# Equal routes on both sides cancel out, and a blend of two free neighbours can point at a blocked cell
	# between them. In either case the single best neighbour (the first on a tie) is the safe way.
	var cancelled := pull.length() < 0.5 * total_gain
	var cell := _grid.cell_of(point)
	if cancelled or _grid.is_blocked(_grid.cell_center(cell) + blended * _grid.cell_size):
		return _unit[best]
	return blended


func _index_of(point: Vector2) -> int:
	var cell := _grid.cell_of(point)
	return (cell.y + PAD) * _stride + cell.x + PAD


## Builds the padded blocked array and the move tables once per grid.
func _prepare(grid: ObstacleGrid) -> void:
	if _prepared == grid:
		return
	_prepared = grid
	_stride = grid.columns + PAD * 2
	_pad.resize(_stride * (grid.rows + PAD * 2))
	_pad.fill(1)
	for y in grid.rows:
		for x in grid.columns:
			_pad[(y + PAD) * _stride + x + PAD] = grid.blocked[y * grid.columns + x]
	_step.resize(MOVES.size())
	_cost.resize(MOVES.size())
	_via_a.resize(MOVES.size())
	_via_b.resize(MOVES.size())
	_unit.resize(MOVES.size())
	for k in MOVES.size():
		var move := MOVES[k]
		_step[k] = move.y * _stride + move.x
		_unit[k] = Vector2(move).normalized()
		if move.x == 0 or move.y == 0:
			_cost[k] = STRAIGHT_COST
			_via_a[k] = 0
			_via_b[k] = 0
		elif absi(move.x) == 2:
			_cost[k] = KNIGHT_COST
			_via_a[k] = signi(move.x)
			_via_b[k] = signi(move.x) + move.y * _stride
		elif absi(move.y) == 2:
			_cost[k] = KNIGHT_COST
			_via_a[k] = signi(move.y) * _stride
			_via_b[k] = signi(move.y) * _stride + move.x
		else:
			_cost[k] = DIAGONAL_COST
			_via_a[k] = move.x
			_via_b[k] = move.y * _stride
