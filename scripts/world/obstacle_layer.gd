class_name ObstacleLayer
extends Node2D
## Draws every obstacle in one `_draw`. TEMPORARY look.

const FILL := Color(0.36, 0.36, 0.4, 1)
const OUTLINE := Color(0.2, 0.2, 0.25, 1)

var _obstacles: Array[MapObstacle] = []


func set_obstacles(obstacles: Array[MapObstacle]) -> void:
	_obstacles = obstacles
	queue_redraw()


func item_count() -> int:
	return _obstacles.size()


func _draw() -> void:
	for obstacle in _obstacles:
		if obstacle == null or not obstacle.is_valid():
			continue
		if obstacle.kind == MapObstacle.Kind.CIRCLE:
			draw_circle(obstacle.position, obstacle.radius, FILL)
			draw_arc(obstacle.position, obstacle.radius, 0.0, TAU, 24, OUTLINE, 1.0)
		else:
			draw_rect(obstacle.bounds(), FILL)
			draw_rect(obstacle.bounds(), OUTLINE, false, 1.0)
