class_name DrawChunk
extends Node2D
## One cell of a big layer's drawing. The engine skips a node whose drawing is off screen, so splitting a layer
## into chunks means only the few on screen are drawn each frame. TEMPORARY look.

const FILL := Color(0.36, 0.36, 0.4, 1)
const OUTLINE := Color(0.2, 0.2, 0.25, 1)

var _rects: Array[Dictionary] = []
var _obstacles: Array[MapObstacle] = []


## `rects` are {"rect": Rect2, "color": Color} decorations, `obstacles` are solid shapes.
func set_items(rects: Array[Dictionary], obstacles: Array[MapObstacle]) -> void:
	_rects = rects
	_obstacles = obstacles
	queue_redraw()


func _draw() -> void:
	for item in _rects:
		draw_rect(item["rect"], item["color"])
	for obstacle in _obstacles:
		if obstacle == null or not obstacle.is_valid():
			continue
		if obstacle.kind == MapObstacle.Kind.CIRCLE:
			draw_circle(obstacle.position, obstacle.radius, FILL)
			draw_arc(obstacle.position, obstacle.radius, 0.0, TAU, 24, OUTLINE, 1.0)
		else:
			draw_rect(obstacle.bounds(), FILL)
			draw_rect(obstacle.bounds(), OUTLINE, false, 1.0)
