extends GutTest

var _burst: BurstLayer
var _shake: CameraShake
var _flash: ScreenFlash
var _camera: Camera2D
var _director: FxDirector
var _now: int = 0


func before_each() -> void:
	FxSettings.reset()
	_now = 0
	_burst = BurstLayer.new()
	add_child_autofree(_burst)
	_camera = Camera2D.new()
	add_child_autofree(_camera)
	_shake = CameraShake.new()
	_shake.clock = func() -> int: return _now
	add_child_autofree(_shake)
	_shake.bind(_camera)
	_flash = ScreenFlash.new()
	_flash.clock = func() -> int: return _now
	add_child_autofree(_flash)
	_director = FxDirector.new()
	add_child_autofree(_director)
	_director.setup(_burst, _shake, _flash)


func after_each() -> void:
	FxSettings.reset()


func _hit(weight: float, element: StringName = &"fire", at: Vector2 = Vector2(50, 50)) -> void:
	ImpactEvents.bus.hit.emit(at, weight, element)


func test_a_heavy_hit_makes_a_big_burst_a_shake_and_a_flash() -> void:
	_hit(1.0)
	assert_gte(_burst.active_count(), 20)
	assert_eq(_shake.shakes_made(), 1)
	assert_eq(_flash.flashes_made(), 1)


func test_a_light_hit_only_makes_a_few_sparks() -> void:
	_hit(0.1)
	assert_gte(_burst.active_count(), 3)
	assert_lte(_burst.active_count(), 6)
	assert_eq(_shake.shakes_made(), 0)
	assert_eq(_flash.flashes_made(), 0)


func test_the_burst_uses_the_elements_colours() -> void:
	_hit(0.2, &"thunder")
	var look := ElementLooks.for_element(SpellData.Element.THUNDER)
	var allowed: Array[Color] = [look.edge, Color(look.tint.r, look.tint.g, look.tint.b, 1.0)]
	assert_gt(_burst.live_particles().size(), 0)
	for particle in _burst.live_particles():
		var color: Color = particle["color"]
		var match_found := false
		for wanted in allowed:
			if color.is_equal_approx(wanted):
				match_found = true
		assert_true(match_found, "an element's sparks wear its own colours")


func test_a_blast_detonation_gives_a_small_shake() -> void:
	EnemyAttackEvents.bus.blast_detonated.emit(Vector2(10, 10))
	assert_eq(_shake.shakes_made(), 1)
	assert_gt(_burst.active_count(), 0)


func test_a_boss_slam_gives_a_small_shake_and_a_summon_does_not() -> void:
	var slam := BossAttack.new()
	slam.kind = BossAttack.Kind.SLAM
	_director.on_boss_attack(slam)
	assert_eq(_shake.shakes_made(), 1)
	var summon := BossAttack.new()
	summon.kind = BossAttack.Kind.SUMMON
	_now += 1000
	_director.on_boss_attack(summon)
	assert_eq(_shake.shakes_made(), 1)


func test_twenty_simultaneous_hits_make_at_most_a_few_bursts_and_one_shake_and_one_flash() -> void:
	for i in 20:
		_hit(1.0, &"fire", Vector2(i * 7, i * 3))
	assert_lte(_director.bursts_made(), FxDirector.MAX_BURSTS_PER_FRAME)
	assert_gt(_director.bursts_made(), 0)
	assert_eq(_shake.shakes_made(), 1)
	assert_eq(_flash.flashes_made(), 1)


func test_the_burst_layer_stays_under_its_cap_in_a_flood() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for tick in 300:
		_now += 16
		_director.begin_frame()
		for i in 5:
			_hit(rng.randf(), &"fire", Vector2(rng.randf() * 400.0, rng.randf() * 300.0))
		assert_lte(_burst.active_count(), BurstLayer.CAPACITY)


func test_setup_twice_does_not_double_the_effects() -> void:
	_director.setup(_burst, _shake, _flash)
	_hit(1.0)
	assert_eq(_director.bursts_made(), 1)
	assert_eq(_shake.shakes_made(), 1)


func test_flash_is_soft_and_never_above_the_cap() -> void:
	_hit(1.0)
	var rect := _flash.get_node("Rect") as ColorRect
	var cap := ImpactConfig.default_config().flash_max_alpha
	assert_lte(rect.color.a, cap + 0.0001)
	assert_gt(rect.color.a, 0.0)
	assert_eq(rect.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	FxSettings.flash_scale = 9.0
	_flash.advance(1.0)
	_now += 1000
	_hit(1.0)
	assert_lte(rect.color.a, cap + 0.0001, "a scale above one never exceeds the designed opacity")


func test_the_flash_fades_out_and_is_refused_inside_its_gap() -> void:
	_hit(1.0)
	_flash.advance(0.2)
	assert_eq((_flash.get_node("Rect") as ColorRect).color.a, 0.0)
	_now += 100
	_hit(1.0)
	assert_eq(_flash.flashes_made(), 1, "a second flash inside the gap is refused")
	_now += 400
	_hit(1.0)
	assert_eq(_flash.flashes_made(), 2)


func test_flash_scale_zero_turns_the_flash_off() -> void:
	FxSettings.flash_scale = 0.0
	_hit(1.0)
	assert_eq(_flash.flashes_made(), 0)


func test_main_has_a_bound_director_with_its_parts() -> void:
	var main := load("res://scenes/main/main.tscn").instantiate() as Main
	main.save_path = ""
	for screen in ["BuffPickScreen", "CraftingScreen", "MerchantScreen"]:
		main.get_node(screen).pause_tree = false
	add_child_autofree(main)
	var director := main.get_node("FxDirector") as FxDirector
	assert_true(director.is_bound())
	var layer := main.get_node_or_null("BurstLayer") as BurstLayer
	assert_not_null(layer)
	var before := layer.active_count()
	ImpactEvents.bus.hit.emit(Vector2(100, 100), 1.0, &"sea")
	assert_gt(layer.active_count(), before)
