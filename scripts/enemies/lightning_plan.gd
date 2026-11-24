class_name LightningPlan
extends RefCounted
## Where a boss's lightning strikes land. The first strike is on the centre (the player's spot when the warning begins, clamped into the
## arena); each other is the best of a few seeded candidates inside the arena and within `spread` of that spot, preferring the one farthest
## from the strikes already placed, so they fan out instead of stacking. Pure: the same seed gives the same points.

const CANDIDATES := 20


static func points(center: Vector2, count: int, spread: float, min_gap: float, bounds: Rect2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var found: Array[Vector2] = []
	if count <= 0:
		return found
	var anchor := center.clamp(bounds.position, bounds.end)
	found.append(anchor)
	for i in count - 1:
		var best := anchor
		var best_score := -1.0
		for k in CANDIDATES:
			var candidate := anchor + Vector2.from_angle(rng.randf_range(0.0, TAU)) * spread * sqrt(rng.randf())
			candidate = candidate.clamp(bounds.position, bounds.end)
			var nearest := INF
			for other in found:
				nearest = minf(nearest, candidate.distance_to(other))
			# Beyond twice the gap every candidate is as good as another, so the first such one is kept (the strikes stay random, not a ring).
			var score := minf(nearest, min_gap * 2.0)
			if score > best_score:
				best = candidate
				best_score = score
		found.append(best)
	return found
