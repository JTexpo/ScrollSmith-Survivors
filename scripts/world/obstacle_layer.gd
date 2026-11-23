class_name ObstacleLayer
extends Node2D
## Draws every obstacle, in chunks so the ones off screen cost nothing. Walls with art are drawn in two passes over the
## whole layer: the borders (and everything else) in the chunks, then the centres in a `Centres` node added after them, so
## where two walls cross the centre of one covers the border of the other even when they are in different chunks.

## Side of one chunk, in pixels (a little more than a screen).
const CHUNK_SIZE := 512.0

var _count: int = 0
var _chunk_count: int = 0


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
	_chunk_count = buckets.size()
	for key in buckets:
		var chunk := DrawChunk.new()
		add_child(chunk)
		chunk.set_items([] as Array[Dictionary], buckets[key])
	var centres := Node2D.new()
	centres.name = &"Centres"
	add_child(centres)
	for key in buckets:
		var chunk := DrawChunk.new()
		centres.add_child(chunk)
		chunk.set_items([] as Array[Dictionary], buckets[key], true)


func item_count() -> int:
	return _count


## The number of chunks (the centre pass has the same chunks again, under `Centres`).
func chunk_count() -> int:
	return _chunk_count


## The chunks that draw the borders, in tree order.
func chunks() -> Array[DrawChunk]:
	var result: Array[DrawChunk] = []
	for child in get_children():
		if child is DrawChunk:
			result.append(child)
	return result
