class_name MapDebugOverlay
extends Node2D
## DEBUG: draws the map's bounds, the player start, a labelled marker per placement, every obstacle's outline,
## the blocked grid cells and the flow field's arrows near the player, so a layout and the routing can be seen
## while tuning. Hidden until `GameMap.toggle_debug` (F7). Delete when no longer needed.

const LINE_COLOR := Color(1.0, 0.2, 0.8, 0.9)
const ZONE_COLOR := Color(1.0, 0.9, 0.2, 0.6)
const BLOCKED_COLOR := Color(1.0, 0.2, 0.2, 0.18)
const ARROW_COLOR := Color(0.2, 1.0, 0.9, 0.9)
const MARKER_RADIUS := 6.0
## Arrows are drawn within this distance of the player, on every second cell.
const ARROW_RANGE := 160.0
const REDRAW_INTERVAL := 0.2

var _data: MapData
var _shapes: Array[MapObstacle] = []
var _obstacle_map: ObstacleMap
var _since_redraw: float = 0.0


func _ready() -> void:
	visibility_changed.connect(func() -> void: set_process(visible))
	set_process(visible)


func setup(data: MapData) -> void:
	_data = data
	_shapes = data.solid_shapes()
	queue_redraw()


## Lets the overlay draw the blocked cells and the field.
func bind(obstacle_map: ObstacleMap) -> void:
	_obstacle_map = obstacle_map
	queue_redraw()


## The player start plus one marker per placement.
func marker_count() -> int:
	return 0 if _data == null else 1 + _data.placements.size()


func _process(delta: float) -> void:
	_since_redraw += delta
	if _since_redraw >= REDRAW_INTERVAL:
		_since_redraw = 0.0
		queue_redraw()


func _draw() -> void:
	if _data == null:
		return
	draw_rect(_data.bounds(), LINE_COLOR, false, 2.0)
	_draw_marker(_data.player_start, "start")
	for placement in _data.placements:
		if placement != null and placement.scene != null:
			_draw_marker(placement.position, placement.scene.resource_path.get_file().get_basename())
	for obstacle in _shapes:
		if obstacle != null and obstacle.is_valid():
			draw_rect(obstacle.bounds(), LINE_COLOR, false, 1.0)
	for zone in _data.zones:
		if zone != null:
			draw_rect(zone.area, ZONE_COLOR, false, 1.0)
	if _obstacle_map != null and _obstacle_map.grid != null:
		_draw_grid(_obstacle_map.grid)


func _draw_marker(at: Vector2, label: String) -> void:
	draw_line(at - Vector2(MARKER_RADIUS, 0), at + Vector2(MARKER_RADIUS, 0), LINE_COLOR, 1.0)
	draw_line(at - Vector2(0, MARKER_RADIUS), at + Vector2(0, MARKER_RADIUS), LINE_COLOR, 1.0)
	draw_string(UiFont.outlined(), at + Vector2(MARKER_RADIUS + 2.0, -MARKER_RADIUS), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiFont.SIZE, LINE_COLOR)


func _draw_grid(grid: ObstacleGrid) -> void:
	var size := Vector2(grid.cell_size, grid.cell_size)
	for y in grid.rows:
		for x in grid.columns:
			if grid.is_blocked_cell(Vector2i(x, y)):
				draw_rect(Rect2(Vector2(x, y) * grid.cell_size, size), BLOCKED_COLOR)
	var player := get_tree().get_first_node_in_group(&"player") as Node2D if is_inside_tree() else null
	if player == null:
		return
	var around := grid.cell_of(player.global_position)
	var reach := int(ARROW_RANGE / grid.cell_size)
	for y in range(around.y - reach, around.y + reach + 1, 2):
		for x in range(around.x - reach, around.x + reach + 1, 2):
			var center := grid.cell_center(Vector2i(x, y))
			if grid.is_blocked_cell(Vector2i(x, y)) or center.distance_to(player.global_position) > ARROW_RANGE:
				continue
			var direction := _obstacle_map.direction_from(center)
			if direction != Vector2.ZERO:
				draw_line(center, center + direction * 10.0, ARROW_COLOR, 1.0)
