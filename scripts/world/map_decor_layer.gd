class_name MapDecorLayer
extends Node2D
## Draws every decoration, in chunks so the ones off screen cost nothing.

## Side of one chunk, in pixels (a little more than a screen).
const CHUNK_SIZE := 512.0

var _count: int = 0


func set_decor(items: Array[Dictionary]) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_count = items.size()
	var buckets := {}
	for item in items:
		var key := Vector2i((item["rect"] as Rect2).get_center() / CHUNK_SIZE)
		if not buckets.has(key):
			buckets[key] = [] as Array[Dictionary]
		(buckets[key] as Array[Dictionary]).append(item)
	for key in buckets:
		var chunk := DrawChunk.new()
		add_child(chunk)
		chunk.set_items(buckets[key], [] as Array[MapObstacle])


func item_count() -> int:
	return _count


func chunk_count() -> int:
	return get_child_count()
