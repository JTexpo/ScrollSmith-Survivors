class_name FloorPatch
extends Node2D
## A floor tile repeated over a rectangle (a zone, the whole map or the world's edge). It is only a drawing, so it
## never catches a touch, and the flat colour under it stays as the fallback.

## The covered rectangle, in the parent's coordinates.
var area: Rect2 = Rect2()

var _texture: Texture2D


func setup(covered: Rect2, set_data: SpriteSetData) -> void:
	area = covered
	_texture = set_data.sheet
	position = covered.position
	queue_redraw()


func _draw() -> void:
	if _texture != null:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, area.size), true)
