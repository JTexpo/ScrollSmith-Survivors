class_name ObstacleMap
extends Node
## What the world knows about its obstacles, for everything that moves: the blocked-cell grid, the flow field
## toward the player, and exact shape tests. It joins the group `obstacle_map`, so enemies, the boss, enemy
## projectiles and the spawner find it without wiring, and behave as before when there is none.
##
## The field is rebuilt a few hundred cells per physics frame (it never takes a whole frame), when the player
## has entered a new cell and at least REBUILD_INTERVAL has passed since the last rebuild began. Physics
## frames stop while the tree is paused, so nothing advances then.

## Shortest time between the starts of two rebuilds, in physics seconds.
const REBUILD_INTERVAL := 0.2

## How many cells of the sweep are done per physics frame.
@export var cells_per_frame: int = 400

## How many rebuilds have finished (the first, built in `setup`, counts).
var rebuild_count: int = 0

var data: MapData
var grid: ObstacleGrid
var field := FlowField.new()

var _since_start: float = REBUILD_INTERVAL
var _field_cell := Vector2i(-1, -1)


func _ready() -> void:
	add_to_group(&"obstacle_map")


## Builds the grid, and the first field at once when a player is already in the tree.
func setup(map: MapData) -> void:
	data = map
	grid = ObstacleGrid.build(map)
	var player := _player()
	if player != null:
		field.rebuild(grid, player.global_position)
		_field_cell = grid.cell_of(player.global_position)
		_since_start = 0.0
		rebuild_count += 1


func _physics_process(delta: float) -> void:
	if grid == null:
		return
	_since_start += delta
	if field.is_rebuilding():
		_advance()
		return
	var player := _player()
	if player == null:
		return
	var cell := grid.cell_of(player.global_position)
	if cell != _field_cell and _since_start >= REBUILD_INTERVAL:
		_field_cell = cell
		_since_start = 0.0
		field.begin_rebuild(grid, player.global_position)
		_advance()


## The way toward the player along the field, or ZERO when there is none for this point.
func direction_from(point: Vector2) -> Vector2:
	return field.direction_at(point)


## True when `point` is in a blocked cell (the grid is grown by the body clearance).
func is_blocked(point: Vector2) -> bool:
	return grid != null and grid.is_blocked(point)


## Exact: true when the segment touches any obstacle. Used for projectiles.
func blocks_segment(from: Vector2, to: Vector2) -> bool:
	if data == null:
		return false
	for obstacle in data.obstacles:
		if obstacle != null and obstacle.blocks_segment(from, to):
			return true
	return false


## `point` itself when free, otherwise the centre of the nearest free cell.
func push_out(point: Vector2) -> Vector2:
	return grid.nearest_free(point) if grid != null else point


## Where a body that wants to go from `from` to `to` ends up: `to` when it is free, otherwise the part of the
## move along one axis that is free, otherwise it stays (and is pushed out if it already stands in a blocked cell).
func resolve_move(from: Vector2, to: Vector2) -> Vector2:
	if grid == null or not grid.is_blocked(to):
		return to
	var slide_x := Vector2(to.x, from.y)
	if not grid.is_blocked(slide_x):
		return slide_x
	var slide_y := Vector2(from.x, to.y)
	if not grid.is_blocked(slide_y):
		return slide_y
	if grid.is_blocked(from):
		return grid.nearest_free(from)
	return from


func _advance() -> void:
	if field.advance(cells_per_frame):
		rebuild_count += 1


func _player() -> Node2D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(&"player") as Node2D
