class_name MapObstacle
extends Resource
## One solid shape on a map: a rectangle or a circle. It blocks movement and enemy projectiles (never the
## player's spells). The grid and the physics walls are both built from these exact shapes.

enum Kind { RECT, CIRCLE }

@export var kind: Kind = Kind.RECT
## The centre of the shape.
@export var position: Vector2 = Vector2.ZERO
## Full width and height (RECT).
@export var size: Vector2 = Vector2.ZERO
## CIRCLE.
@export var radius: float = 0.0


func is_valid() -> bool:
	if kind == Kind.CIRCLE:
		return radius > 0.0
	return size.x > 0.0 and size.y > 0.0


func bounds() -> Rect2:
	if kind == Kind.CIRCLE:
		return Rect2(position - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	return Rect2(position - size / 2.0, size)


## True when `point` is inside the shape grown by `grow` pixels on every side.
func contains(point: Vector2, grow: float = 0.0) -> bool:
	if kind == Kind.CIRCLE:
		return point.distance_to(position) <= radius + grow
	return bounds().grow(grow).has_point(point)


## True when the shape, grown by `grow`, overlaps `rect`.
func overlaps_rect(rect: Rect2, grow: float = 0.0) -> bool:
	if kind == Kind.CIRCLE:
		var nearest := Vector2(
			clampf(position.x, rect.position.x, rect.end.x),
			clampf(position.y, rect.position.y, rect.end.y),
		)
		return nearest.distance_to(position) <= radius + grow
	return bounds().grow(grow).intersects(rect, true)


## Exact: true when the segment touches the shape grown by `grow` pixels, including one that starts or ends inside
## it. A body of half-width `grow` can walk a segment only if this is false.
func blocks_segment(from: Vector2, to: Vector2, grow: float = 0.0) -> bool:
	if kind == Kind.CIRCLE:
		return Geometry2D.get_closest_point_to_segment(position, from, to).distance_to(position) <= radius + grow
	var area := bounds().grow(grow)
	if area.has_point(from) or area.has_point(to):
		return true
	# Slab clipping of the segment against the rectangle.
	var direction := to - from
	var enter := 0.0
	var leave := 1.0
	for axis in 2:
		var low := area.position[axis]
		var high := area.end[axis]
		if absf(direction[axis]) < 0.000001:
			if from[axis] < low or from[axis] > high:
				return false
			continue
		var t1 := (low - from[axis]) / direction[axis]
		var t2 := (high - from[axis]) / direction[axis]
		enter = maxf(enter, minf(t1, t2))
		leave = minf(leave, maxf(t1, t2))
		if enter > leave:
			return false
	return true
