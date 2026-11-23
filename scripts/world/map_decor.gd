class_name MapDecor
extends RefCounted
## Scatters a map's decorations from its seed: the same map always gives the same result. A decoration
## never sits on a solid shape, the player start or a placement.

## How far from the player start and from every placement a decoration's centre must be.
const CLEAR_RADIUS := 40.0
## How far a decoration's centre must be from any solid shape's edge.
const SHAPE_MARGIN := 2.0
const ATTEMPTS_PER_ITEM := 10


## Each item is {"rect": Rect2, "color": Color}. Fewer than `decoration_count` come back when the
## map has no room, and it always ends.
static func scatter(map: MapData) -> Array[Dictionary]:
	return _scatter(map, map.bounds(), map.decoration_count, map.decoration_colors, map.decoration_seed)


## The same for one zone: inside its area, with its own colours and count.
static func scatter_zone(map: MapData, zone_index: int) -> Array[Dictionary]:
	if zone_index < 0 or zone_index >= map.zones.size() or map.zones[zone_index] == null:
		return [] as Array[Dictionary]
	var zone := map.zones[zone_index]
	return _scatter(map, zone.area.intersection(map.bounds()), zone.decoration_count, zone.decoration_colors, map.decoration_seed + 1 + zone_index)


static func _scatter(map: MapData, region: Rect2, count: int, colors: PackedColorArray, seed_value: int) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if count <= 0 or colors.is_empty() or region.size.x <= 0.0 or region.size.y <= 0.0:
		return items
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var keep_clear: Array[Vector2] = [map.player_start]
	for placement in map.placements:
		if placement != null:
			keep_clear.append(placement.position)
	var shapes := map.solid_shapes()
	for attempt in count * ATTEMPTS_PER_ITEM:
		if items.size() >= count:
			break
		var side := rng.randf_range(minf(map.decoration_size.x, map.decoration_size.y), maxf(map.decoration_size.x, map.decoration_size.y))
		var rect := Rect2(region.position + Vector2(rng.randf_range(0.0, region.size.x), rng.randf_range(0.0, region.size.y)), Vector2(side, side))
		var color := colors[rng.randi() % colors.size()]
		if not region.encloses(rect) or _too_close(rect.get_center(), keep_clear) or _on_a_shape(rect.get_center(), shapes):
			continue
		items.append({"rect": rect, "color": color})
	return items


static func _too_close(center: Vector2, keep_clear: Array[Vector2]) -> bool:
	for point in keep_clear:
		if center.distance_to(point) < CLEAR_RADIUS:
			return true
	return false


static func _on_a_shape(center: Vector2, shapes: Array[MapObstacle]) -> bool:
	for shape in shapes:
		if shape.contains(center, SHAPE_MARGIN):
			return true
	return false
