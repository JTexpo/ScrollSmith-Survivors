extends GutTest

var _layer: BurstLayer


func before_each() -> void:
	_layer = BurstLayer.new()
	add_child_autofree(_layer)


func _kinds() -> Dictionary:
	var kinds := {}
	for particle in _layer.live_particles():
		kinds[particle["kind"]] = true
	return kinds


func test_a_burst_adds_up_to_the_requested_count_and_it_is_capped() -> void:
	_layer.burst(Vector2(10, 10), &"sparks", [Color.RED], 5)
	assert_eq(_layer.active_count(), 5)
	for i in 100:
		_layer.burst(Vector2(10, 10), &"sparks", [Color.RED], 24)
	assert_eq(_layer.active_count(), BurstLayer.CAPACITY)


func test_each_style_makes_its_particles() -> void:
	_layer.burst(Vector2.ZERO, &"sparks", [Color.RED], 4)
	assert_eq(_kinds().keys(), [ParticlePool.SQUARE])
	_layer.burst(Vector2.ZERO, &"dust", [Color.GRAY], 4)
	assert_eq(_kinds().keys(), [ParticlePool.SQUARE])
	var other := BurstLayer.new()
	add_child_autofree(other)
	other.burst(Vector2.ZERO, &"stars", [Color.YELLOW], 4)
	other.burst(Vector2.ZERO, &"sparkle", [Color.WHITE], 4)
	var kinds := {}
	for particle in other.live_particles():
		kinds[particle["kind"]] = true
	assert_eq(kinds.keys(), [ParticlePool.TWINKLE])


func test_the_layer_only_processes_while_particles_live() -> void:
	assert_false(_layer.is_processing())
	_layer.burst(Vector2.ZERO, &"sparks", [Color.RED], 3)
	assert_true(_layer.is_processing())
	for i in 40:
		_layer._process(0.1)
	assert_eq(_layer.active_count(), 0)
	assert_false(_layer.is_processing())


func test_particles_expire() -> void:
	_layer.burst(Vector2.ZERO, &"dust", [Color.GRAY], 6)
	_layer._process(5.0)
	assert_eq(_layer.active_count(), 0)


func test_no_child_nodes_are_made_for_particles() -> void:
	for i in 20:
		_layer.burst(Vector2.ZERO, &"sparks", [Color.RED], 24)
	assert_eq(_layer.get_child_count(), 0)


func test_a_burst_uses_the_colours_it_is_given() -> void:
	_layer.burst(Vector2.ZERO, &"sparks", [Color.RED, Color.BLUE], 12)
	for particle in _layer.live_particles():
		assert_true(particle["color"] == Color.RED or particle["color"] == Color.BLUE)


func test_the_layer_is_never_scaled_or_rotated() -> void:
	for i in 5:
		_layer.burst(Vector2(30, 40), &"stars", [Color.YELLOW], 10)
		_layer._process(0.05)
	assert_eq(_layer.transform, Transform2D.IDENTITY)


func test_a_burst_with_no_colours_or_zero_count_is_harmless() -> void:
	_layer.burst(Vector2.ZERO, &"sparks", [] as Array[Color], 5)
	_layer.burst(Vector2.ZERO, &"sparks", [Color.RED], 0)
	_layer.burst(Vector2.ZERO, &"no_such_style", [Color.RED], 3)
	assert_gte(_layer.active_count(), 0)


func test_particle_positions_start_where_the_burst_is() -> void:
	_layer.burst(Vector2(100, 200), &"sparkle", [Color.WHITE], 6)
	for particle in _layer.live_particles():
		assert_lt(particle["position"].distance_to(Vector2(100, 200)), 6.0)
