class_name BurstLayer
extends Node2D
## Draws every spark, dust speck and twinkle in one `_draw` from a fixed pool (`CAPACITY`), so a fight makes no node per
## particle and can never grow. Particles are whole-pixel squares or small plus-shaped twinkles at rounded positions: nothing is
## scaled or rotated. It sits at the world origin (never moved or scaled) and processes only while a particle is alive.

const CAPACITY := 256
const FADE_POWER := 2.0

var _pool := ParticlePool.new(CAPACITY)
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	z_index = 9
	_rng.seed = 21


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_pool.step(delta)
	queue_redraw()
	if _pool.count() == 0:
		set_process(false)


## `style` is sparks, dust, stars or sparkle (anything else is ignored); each particle takes one of `colors` at random.
func burst(position: Vector2, style: StringName, colors: Array[Color], count: int) -> void:
	if colors.is_empty() or count <= 0:
		return
	for i in count:
		var color := colors[_rng.randi() % colors.size()]
		match style:
			&"sparks":
				_pool.emit(position, _spread(40.0, 110.0), _rng.randf_range(0.18, 0.35), color, _rng.randi_range(1, 2), 120.0, ParticlePool.SQUARE)
			&"dust":
				_pool.emit(position, _spread(10.0, 35.0), _rng.randf_range(0.3, 0.5), color, _rng.randi_range(2, 3), -20.0, ParticlePool.SQUARE)
			&"stars":
				_pool.emit(position, Vector2(_rng.randf_range(-15.0, 15.0), -_rng.randf_range(15.0, 40.0)), _rng.randf_range(0.4, 0.7), color, _rng.randi_range(1, 2), 0.0, ParticlePool.TWINKLE)
			&"sparkle":
				_pool.emit(position + _spread(0.0, 4.0), _spread(0.0, 5.0), _rng.randf_range(0.25, 0.5), color, 1, 0.0, ParticlePool.TWINKLE)
			_:
				return
	set_process(true)
	queue_redraw()


func active_count() -> int:
	return _pool.count()


func live_particles() -> Array[Dictionary]:
	return _pool.particles()


func _draw() -> void:
	for particle in _pool.particles():
		var color: Color = particle["color"]
		color.a *= 1.0 - pow(float(particle["age_ratio"]), FADE_POWER)
		var at: Vector2 = particle["position"]
		var size: int = particle["size"]
		if particle["kind"] == ParticlePool.SQUARE:
			var corner := at - Vector2(floori(size / 2.0), floori(size / 2.0))
			draw_rect(Rect2(corner, Vector2(size, size)), color)
		else:
			# A plus-shaped twinkle: a centre pixel and an arm of `size` pixels on each side.
			draw_rect(Rect2(at, Vector2.ONE), color)
			draw_rect(Rect2(at + Vector2(-size, 0), Vector2(size, 1)), color)
			draw_rect(Rect2(at + Vector2(1, 0), Vector2(size, 1)), color)
			draw_rect(Rect2(at + Vector2(0, -size), Vector2(1, size)), color)
			draw_rect(Rect2(at + Vector2(0, 1), Vector2(1, size)), color)


func _spread(low: float, high: float) -> Vector2:
	return Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(low, high)
