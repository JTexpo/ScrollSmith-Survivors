class_name MapDecor
extends RefCounted
## Scatters a map's decorations from its seed: the same map always gives the same result.

## How far from the player start and from every placement a decoration's centre must be.
const CLEAR_RADIUS := 40.0
const ATTEMPTS_PER_ITEM := 10


## Each item is {"rect": Rect2, "color": Color}. Fewer than `decoration_count` come back when the
## map has no room, and it always ends.
static func scatter(map: MapData) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if map.decoration_count <= 0 or map.decoration_colors.is_empty():
		return items
	var rng := RandomNumberGenerator.new()
	rng.seed = map.decoration_seed
	var area := map.bounds()
	var keep_clear: Array[Vector2] = [map.player_start]
	for placement in map.placements:
		if placement != null:
			keep_clear.append(placement.position)
	for attempt in map.decoration_count * ATTEMPTS_PER_ITEM:
		if items.size() >= map.decoration_count:
			break
		var side := rng.randf_range(minf(map.decoration_size.x, map.decoration_size.y), maxf(map.decoration_size.x, map.decoration_size.y))
		var rect := Rect2(Vector2(rng.randf_range(0.0, area.size.x), rng.randf_range(0.0, area.size.y)), Vector2(side, side))
		var color := map.decoration_colors[rng.randi() % map.decoration_colors.size()]
		if not area.encloses(rect) or _too_close(rect.get_center(), keep_clear):
			continue
		items.append({"rect": rect, "color": color})
	return items


static func _too_close(center: Vector2, keep_clear: Array[Vector2]) -> bool:
	for point in keep_clear:
		if center.distance_to(point) < CLEAR_RADIUS:
			return true
	return false
