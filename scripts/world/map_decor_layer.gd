class_name MapDecorLayer
extends Node2D
## Draws every decoration in one `_draw`, so hundreds of them cost one node. TEMPORARY look.

var _items: Array[Dictionary] = []


func set_decor(items: Array[Dictionary]) -> void:
	_items = items
	queue_redraw()


func item_count() -> int:
	return _items.size()


func _draw() -> void:
	for item in _items:
		draw_rect(item["rect"], item["color"])
