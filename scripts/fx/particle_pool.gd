class_name ParticlePool
extends RefCounted
## A fixed-size pool of short-lived particles, pure so its rules are testable. A particle has a position, a velocity, gravity, a
## life and a colour. At the cap the oldest particle is recycled, so a crowd fight can never grow it. Positions are reported rounded
## to whole pixels, so a particle is only ever drawn on the pixel grid (the game has one pixel size and nothing shimmers).

const SQUARE := 0
const TWINKLE := 1

var _capacity: int
var _list: Array[Dictionary] = []


func _init(capacity: int) -> void:
	_capacity = maxi(capacity, 1)


func emit(position: Vector2, velocity: Vector2, life: float, color: Color, size: int, gravity: float, kind: int) -> void:
	if _list.size() >= _capacity:
		_list.pop_front()
	_list.append({"position": position, "velocity": velocity, "life": life, "age": 0.0, "color": color, "size": size, "gravity": gravity, "kind": kind})


func step(delta: float) -> void:
	for i in range(_list.size() - 1, -1, -1):
		var particle := _list[i]
		particle["age"] += delta
		if particle["age"] >= particle["life"]:
			_list.remove_at(i)
			continue
		particle["velocity"] = (particle["velocity"] as Vector2) + Vector2(0.0, float(particle["gravity"]) * delta)
		particle["position"] = (particle["position"] as Vector2) + (particle["velocity"] as Vector2) * delta


func count() -> int:
	return _list.size()


## Each live particle as {position (whole pixels), color, size, kind, age_ratio (0 new, 1 gone)}.
func particles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for particle in _list:
		out.append({
			"position": (particle["position"] as Vector2).round(),
			"color": particle["color"],
			"size": particle["size"],
			"kind": particle["kind"],
			"age_ratio": clampf(float(particle["age"]) / maxf(float(particle["life"]), 0.0001), 0.0, 1.0),
		})
	return out
