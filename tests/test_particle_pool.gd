extends GutTest

const SQUARE := ParticlePool.SQUARE


func _emit(pool: ParticlePool, at: Vector2 = Vector2.ZERO, velocity: Vector2 = Vector2.ZERO, life: float = 1.0, gravity: float = 0.0) -> void:
	pool.emit(at, velocity, life, Color.WHITE, 2, gravity, SQUARE)


func test_emit_adds_a_particle_and_step_ages_and_removes_it() -> void:
	var pool := ParticlePool.new(8)
	_emit(pool, Vector2.ZERO, Vector2.ZERO, 0.5)
	assert_eq(pool.count(), 1)
	pool.step(0.3)
	assert_eq(pool.count(), 1)
	pool.step(0.3)
	assert_eq(pool.count(), 0)


func test_the_pool_never_exceeds_its_capacity_and_recycles_the_oldest() -> void:
	var pool := ParticlePool.new(4)
	for i in 10:
		_emit(pool, Vector2(i, 0))
	assert_eq(pool.count(), 4)
	var xs: Array[float] = []
	for particle in pool.particles():
		xs.append(particle["position"].x)
	xs.sort()
	assert_eq(xs, [6.0, 7.0, 8.0, 9.0] as Array[float], "the newest four survive")


func test_velocity_and_gravity_move_a_particle() -> void:
	var pool := ParticlePool.new(4)
	_emit(pool, Vector2.ZERO, Vector2(100, 0), 2.0, 100.0)
	pool.step(1.0)
	var particle: Dictionary = pool.particles()[0]
	assert_almost_eq(particle["position"].x, 100.0, 1.0)
	assert_gt(particle["position"].y, 90.0, "gravity pulled it down")


func test_reported_positions_are_whole_pixels() -> void:
	var pool := ParticlePool.new(4)
	_emit(pool, Vector2(1.37, 2.62), Vector2(13.3, 7.7), 2.0)
	pool.step(0.123)
	for particle in pool.particles():
		var at: Vector2 = particle["position"]
		assert_eq(at, at.round(), "a particle is only ever drawn on a whole pixel")


func test_age_ratio_goes_from_zero_to_one() -> void:
	var pool := ParticlePool.new(4)
	_emit(pool, Vector2.ZERO, Vector2.ZERO, 1.0)
	assert_eq(pool.particles()[0]["age_ratio"], 0.0)
	pool.step(0.5)
	assert_almost_eq(pool.particles()[0]["age_ratio"], 0.5, 0.001)


func test_a_thousand_emits_stay_at_the_cap() -> void:
	var pool := ParticlePool.new(256)
	for i in 1000:
		_emit(pool, Vector2(i, i))
	assert_eq(pool.count(), 256)


func test_a_zero_or_negative_life_is_gone_on_the_next_step() -> void:
	var pool := ParticlePool.new(4)
	_emit(pool, Vector2.ZERO, Vector2.ZERO, 0.0)
	pool.step(0.01)
	assert_eq(pool.count(), 0)
