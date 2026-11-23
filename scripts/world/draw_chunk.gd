class_name DrawChunk
extends Node2D
## One cell of a big layer's drawing. The engine skips a node whose drawing is off screen, so splitting a layer
## into chunks means only the few on screen are drawn each frame. An obstacle with art (its material names a wall or
## post set) is drawn from it, and one without keeps the flat fill, so a missing sprite never hides a wall.

const FILL := Color(0.36, 0.36, 0.4, 1)
const OUTLINE := Color(0.2, 0.2, 0.25, 1)

var _rects: Array[Dictionary] = []
var _obstacles: Array[MapObstacle] = []
## The art of each obstacle in `_obstacles`, null where it has none.
var _art: Array[SpriteSetData] = []
## The decoration sprites by style name, null for a style with no art.
var _decor_art: Dictionary = {}


## `rects` are {"rect": Rect2, "color": Color} decorations, `obstacles` are solid shapes.
func set_items(rects: Array[Dictionary], obstacles: Array[MapObstacle]) -> void:
	_rects = rects
	_obstacles = obstacles
	_art.clear()
	_decor_art.clear()
	for item in rects:
		var style: StringName = item.get("style", &"")
		if style != &"" and not _decor_art.has(style):
			_decor_art[style] = WorldArt.decor_set(style)
	for obstacle in obstacles:
		var set_data: SpriteSetData = null
		if obstacle != null:
			set_data = WorldArt.post_set(obstacle.material) if obstacle.kind == MapObstacle.Kind.CIRCLE else WorldArt.wall_set(obstacle.material)
		_art.append(set_data)
	queue_redraw()


## How many of this chunk's decorations are drawn from a sprite.
func art_decor_count() -> int:
	var count := 0
	for item in _rects:
		if _decor_set(item) != null:
			count += 1
	return count


func _decor_set(item: Dictionary) -> SpriteSetData:
	var style: StringName = item.get("style", &"")
	return _decor_art.get(style) if style != &"" else null


## How many of this chunk's obstacles are drawn from art.
func art_obstacle_count() -> int:
	var count := 0
	for set_data in _art:
		if set_data != null:
			count += 1
	return count


func _draw() -> void:
	for item in _rects:
		var set_data := _decor_set(item)
		if set_data == null:
			draw_rect(item["rect"], item["color"])
		else:
			var frame_size := Vector2(set_data.frame_size)
			var frames := maxi(set_data.frame_count(), 1)
			var origin := ((item["rect"] as Rect2).get_center() - frame_size / 2.0).floor()
			draw_texture_rect_region(set_data.sheet, Rect2(origin, frame_size), Rect2(Vector2(frame_size.x * (int(item["frame"]) % frames), 0.0), frame_size))
	for i in _obstacles.size():
		var obstacle := _obstacles[i]
		if obstacle == null or not obstacle.is_valid():
			continue
		var set_data := _art[i]
		if set_data == null:
			if obstacle.kind == MapObstacle.Kind.CIRCLE:
				draw_circle(obstacle.position, obstacle.radius, FILL)
				draw_arc(obstacle.position, obstacle.radius, 0.0, TAU, 24, OUTLINE, 1.0)
			else:
				draw_rect(obstacle.bounds(), FILL)
				draw_rect(obstacle.bounds(), OUTLINE, false, 1.0)
		elif obstacle.kind == MapObstacle.Kind.CIRCLE:
			var size := Vector2(set_data.frame_size)
			draw_texture_rect_region(set_data.sheet, Rect2(obstacle.position - size / 2.0, size), Rect2(Vector2.ZERO, size))
		else:
			NineSlice.draw(self, set_data.sheet, Vector2(set_data.frame_size), set_data.slice, obstacle.bounds(), false)
	# The centres come last, so where two walls cross the border of one never shows across the other.
	for i in _obstacles.size():
		var obstacle := _obstacles[i]
		if obstacle != null and obstacle.is_valid() and obstacle.kind == MapObstacle.Kind.RECT and _art[i] != null:
			var set_data := _art[i]
			NineSlice.draw(self, set_data.sheet, Vector2(set_data.frame_size), set_data.slice, obstacle.bounds(), true)
