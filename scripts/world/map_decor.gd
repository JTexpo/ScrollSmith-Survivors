class_name MapDecor
extends RefCounted
## Scatters a map's decorations from its seed: the same map always gives the same result. A decoration
## never sits on a solid shape, the player start or a placement.

## How far from the player start and from every placement a decoration's centre must be.
const CLEAR_RADIUS := 40.0
## How far a decoration's centre must be from any solid shape's edge.
const SHAPE_MARGIN := 2.0
const ATTEMPTS_PER_ITEM := 10
## The square a decoration falls back to when only styles are set and its sprite is missing.
const FALLBACK_COLOR := Color(0.3, 0.3, 0.3, 1)
## `frame` is below this, so any sprite with up to this many variants is covered by a modulo.
const FRAME_RANGE := 1000
## How many valid spots are tried for each decoration with styles, keeping the one farthest from the rest (a "best
## candidate" scatter), so they spread evenly instead of clumping with bare pockets between.
const CANDIDATES := 10


## Each item is {"rect": Rect2, "color": Color, "style": StringName, "frame": int}. `style` is empty without
## `decoration_styles` (the item stays a coloured square), and otherwise one name from the list, with `frame` a
## seeded whole number the drawing reduces to one of that sprite's variants. Fewer than `decoration_count` come
## back when the map has no room, and it always ends. Decorations with styles are spread evenly (see `CANDIDATES`), and
## the map's own never land in a zone that has a floor style, because that zone scatters its own.
static func scatter(map: MapData) -> Array[Dictionary]:
	var claimed: Array[Rect2] = []
	for zone in map.zones:
		if zone != null and zone.floor_style != &"":
			claimed.append(zone.area)
	return _scatter(map, map.bounds(), map.decoration_count, map.decoration_colors, map.decoration_styles, map.decoration_seed, claimed)


## The same for one zone: inside its area, with its own colours and count.
static func scatter_zone(map: MapData, zone_index: int) -> Array[Dictionary]:
	if zone_index < 0 or zone_index >= map.zones.size() or map.zones[zone_index] == null:
		return [] as Array[Dictionary]
	var zone := map.zones[zone_index]
	return _scatter(map, zone.area.intersection(map.bounds()), zone.decoration_count, zone.decoration_colors, zone.decoration_styles, map.decoration_seed + 1 + zone_index, [] as Array[Rect2])


static func _scatter(map: MapData, region: Rect2, count: int, colors: PackedColorArray, styles: PackedStringArray, seed_value: int, claimed: Array[Rect2]) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if count <= 0 or (colors.is_empty() and styles.is_empty()) or region.size.x <= 0.0 or region.size.y <= 0.0:
		return items
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var keep_clear: Array[Vector2] = [map.player_start]
	for placement in map.placements:
		if placement != null:
			keep_clear.append(placement.position)
	var shapes := map.solid_shapes()
	if not styles.is_empty():
		return _spread(map, region, count, colors, styles, rng, keep_clear, shapes, claimed)
	for attempt in count * ATTEMPTS_PER_ITEM:
		if items.size() >= count:
			break
		var item := _random_item(map, region, colors, styles, rng)
		if _is_blocked(item["rect"], region, keep_clear, shapes, claimed):
			continue
		items.append(item)
	return items


## A decoration at a random spot, with a random colour, style and frame.
static func _random_item(map: MapData, region: Rect2, colors: PackedColorArray, styles: PackedStringArray, rng: RandomNumberGenerator) -> Dictionary:
	var side := rng.randf_range(minf(map.decoration_size.x, map.decoration_size.y), maxf(map.decoration_size.x, map.decoration_size.y))
	var rect := Rect2(region.position + Vector2(rng.randf_range(0.0, region.size.x), rng.randf_range(0.0, region.size.y)), Vector2(side, side))
	var color := colors[rng.randi() % colors.size()] if not colors.is_empty() else FALLBACK_COLOR
	var style := &""
	var frame := 0
	if not styles.is_empty():
		style = StringName(styles[rng.randi() % styles.size()])
		frame = rng.randi() % FRAME_RANGE
	return {"rect": rect, "color": color, "style": style, "frame": frame}


static func _is_blocked(rect: Rect2, region: Rect2, keep_clear: Array[Vector2], shapes: Array[MapObstacle], claimed: Array[Rect2]) -> bool:
	if not region.encloses(rect) or _too_close(rect.get_center(), keep_clear) or _on_a_shape(rect.get_center(), shapes):
		return true
	for area in claimed:
		if area.has_point(rect.get_center()):
			return true
	return false


## An even scatter: for each decoration, `CANDIDATES` valid spots are tried and the one farthest from every decoration
## placed so far is kept. It always ends, and places fewer than `count` only when there is no room.
static func _spread(map: MapData, region: Rect2, count: int, colors: PackedColorArray, styles: PackedStringArray, rng: RandomNumberGenerator, keep_clear: Array[Vector2], shapes: Array[MapObstacle], claimed: Array[Rect2]) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	while items.size() < count:
		var best := {}
		var best_gap := -1.0
		var found := 0
		var tries := 0
		while found < CANDIDATES and tries < CANDIDATES * ATTEMPTS_PER_ITEM:
			tries += 1
			var item := _random_item(map, region, colors, styles, rng)
			if _is_blocked(item["rect"], region, keep_clear, shapes, claimed):
				continue
			found += 1
			var gap := _nearest_distance((item["rect"] as Rect2).get_center(), items)
			if gap > best_gap:
				best_gap = gap
				best = item
		if best.is_empty():
			break
		items.append(best)
	return items


static func _nearest_distance(point: Vector2, items: Array[Dictionary]) -> float:
	var nearest := INF
	for item in items:
		nearest = minf(nearest, point.distance_to((item["rect"] as Rect2).get_center()))
	return nearest


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
