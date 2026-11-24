class_name MapPreview
extends Control
## The schematic on a map card, drawn from the map's own data: the floor colour, every solid shape as a filled block and each placement as a
## dot, at 1/15 scale (128 by 72 px). A diagram, not art; it never changes the map and takes no clicks.

const PREVIEW_SIZE := Vector2(128, 72)
const OUTLINE_COLOR := Color("2d1b3d")
const WALL_COLOR := Color("8e8aa3")
const TREE_COLOR := Color("2f8f4e")
const DOT_COLOR := Color("ffd84a")
const START_COLOR := Color("ffffff")

var _map: MapData
var _shapes: Array[MapObstacle] = []
var _has_floor: bool = false


func _init() -> void:
	custom_minimum_size = PREVIEW_SIZE
	size = PREVIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_map(map: MapData) -> void:
	_map = map
	_shapes = map.solid_shapes() if map != null else ([] as Array[MapObstacle])
	queue_redraw()


func scale_factor() -> float:
	return PREVIEW_SIZE.x / _map.size.x if _map != null and _map.size.x > 0.0 else 1.0


## How many blocks and dots are drawn on the floor.
func item_count() -> int:
	return _shapes.size() + dot_count()


func dot_count() -> int:
	return _map.placements.size() if _map != null else 0


## True once the floor has been drawn for a map (false with no map).
func has_floor() -> bool:
	return _has_floor


func _draw() -> void:
	_has_floor = _map != null
	if _map == null:
		return
	draw_rect(Rect2(Vector2.ZERO, PREVIEW_SIZE), _map.floor_color)
	var scale_by := scale_factor()
	for shape in _shapes:
		if shape.kind == MapObstacle.Kind.CIRCLE:
			var radius := maxf(1.0, roundf(shape.radius * scale_by))
			draw_rect(Rect2((shape.position * scale_by).round() - Vector2(radius, radius), Vector2(radius, radius) * 2.0), TREE_COLOR if shape.material == &"tree" else WALL_COLOR)
		else:
			var corner := (shape.position - shape.size / 2.0) * scale_by
			var extent := (shape.size * scale_by).max(Vector2.ONE)
			draw_rect(Rect2(corner.round(), extent.round().max(Vector2.ONE)), WALL_COLOR)
	for placement in _map.placements:
		draw_rect(Rect2((placement.position * scale_by).round() - Vector2.ONE, Vector2(3, 3)), DOT_COLOR)
	draw_rect(Rect2((_map.player_start * scale_by).round() - Vector2.ONE, Vector2(3, 3)), START_COLOR)
	draw_rect(Rect2(Vector2.ZERO, PREVIEW_SIZE), OUTLINE_COLOR, false, 1.0)
