class_name ObstacleLayer
extends Node2D
## Draws every obstacle, in chunks so the ones off screen cost nothing. TEMPORARY look.

## Side of one chunk, in pixels (a little more than a screen).
const CHUNK_SIZE := 512.0

var _count: int = 0


func set_obstacles(obstacles: Array[MapObstacle]) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_count = obstacles.size()
	var buckets := {}
	for obstacle in obstacles:
		if obstacle == null:
			continue
		var key := Vector2i(obstacle.position / CHUNK_SIZE)
		if not buckets.has(key):
			buckets[key] = [] as Array[MapObstacle]
		(buckets[key] as Array[MapObstacle]).append(obstacle)
	for key in buckets:
		var chunk := DrawChunk.new()
		add_child(chunk)
		chunk.set_items([] as Array[Dictionary], buckets[key])


func item_count() -> int:
	return _count


func chunk_count() -> int:
	return get_child_count()
