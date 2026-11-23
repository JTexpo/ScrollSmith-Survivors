class_name EffectPlan
extends RefCounted
## Where and when the effect sprites of an area spell play. Pure: it never touches a node, so it is easy to test. The
## hit area itself is never changed by any of this, the sprites are only a skin on it.

## About one sprite for this much area, with a floor and a cap so a tiny spell still shows something and a huge or
## Duplicate one stays cheap.
const AREA_PER_SPRITE := 600.0
const MIN_SPRITES := 3
const MAX_SPRITES := 24
## How many random spots are tried for each sprite, keeping the one farthest from the others (an even, unclumped spread).
const CANDIDATES := 10
const ATTEMPTS_PER_CANDIDATE := 30


static func count_for(area: float) -> int:
	return clampi(roundi(area / AREA_PER_SPRITE), MIN_SPRITES, MAX_SPRITES)


## `count` points inside `polygon`, spread evenly. Fewer only when the polygon has no room, and none for a degenerate one.
static func spots(polygon: PackedVector2Array, count: int, rng: RandomNumberGenerator) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if count <= 0 or polygon.size() < 3 or absf(_signed_area(polygon)) < 0.001:
		return result
	var low := polygon[0]
	var high := polygon[0]
	for point in polygon:
		low = Vector2(minf(low.x, point.x), minf(low.y, point.y))
		high = Vector2(maxf(high.x, point.x), maxf(high.y, point.y))
	while result.size() < count:
		var best := Vector2.ZERO
		var best_gap := -1.0
		var found := 0
		var tries := 0
		while found < CANDIDATES and tries < CANDIDATES * ATTEMPTS_PER_CANDIDATE:
			tries += 1
			var candidate := Vector2(rng.randf_range(low.x, high.x), rng.randf_range(low.y, high.y))
			if not Geometry2D.is_point_in_polygon(candidate, polygon):
				continue
			found += 1
			var gap := INF
			for spot in result:
				gap = minf(gap, candidate.distance_to(spot))
			if gap > best_gap:
				best_gap = gap
				best = candidate
		if best_gap < 0.0:
			break
		result.append(best)
	return result


## One delay in seconds (0 to `window`) per spot. Rising effects start nearest `origin` and move outward; falling ones
## land in a random order.
static func delays(spot_list: Array[Vector2], rises: bool, origin: Vector2, window: float, rng: RandomNumberGenerator) -> Array[float]:
	var result: Array[float] = []
	var count := spot_list.size()
	if count == 0:
		return result
	if rises:
		var nearest := INF
		var farthest := 0.0
		for spot in spot_list:
			var distance := spot.distance_to(origin)
			nearest = minf(nearest, distance)
			farthest = maxf(farthest, distance)
		for spot in spot_list:
			var span := farthest - nearest
			result.append(window * (spot.distance_to(origin) - nearest) / span if span > 0.0 else 0.0)
		return result
	var ranks: Array = range(count)
	for i in range(count - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: int = ranks[i]
		ranks[i] = ranks[j]
		ranks[j] = swap
	for rank in ranks:
		result.append(window * float(rank) / maxf(float(count - 1), 1.0))
	return result


static func _signed_area(polygon: PackedVector2Array) -> float:
	var total := 0.0
	for i in polygon.size():
		var next := polygon[(i + 1) % polygon.size()]
		total += polygon[i].x * next.y - next.x * polygon[i].y
	return total * 0.5
