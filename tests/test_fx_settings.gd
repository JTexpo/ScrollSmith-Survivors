extends GutTest
## FxSettings is the one place a later settings screen flips every screen effect, so each switch must really turn its effect off,
## everything defaults on, and the whole set can be saved and restored as a plain dictionary.


func before_each() -> void:
	FxSettings.reset()


func after_each() -> void:
	FxSettings.reset()


func test_everything_is_on_by_default() -> void:
	assert_eq(FxSettings.shake_scale, 1.0)
	assert_eq(FxSettings.flash_scale, 1.0)
	assert_true(FxSettings.particles)
	assert_true(FxSettings.low_health_frame)
	assert_true(FxSettings.heart_beat)
	assert_true(FxSettings.hurt_feedback)
	assert_true(FxSettings.hit_indicators)
	assert_true(FxSettings.low_mana_pulse)


func test_reset_turns_everything_back_on() -> void:
	FxSettings.shake_scale = 0.0
	FxSettings.flash_scale = 0.0
	FxSettings.particles = false
	FxSettings.low_health_frame = false
	FxSettings.heart_beat = false
	FxSettings.hurt_feedback = false
	FxSettings.hit_indicators = false
	FxSettings.low_mana_pulse = false
	FxSettings.reset()
	assert_eq(FxSettings.to_dict(), {"shake_scale": 1.0, "flash_scale": 1.0, "particles": true, "low_health_frame": true, "heart_beat": true, "hurt_feedback": true, "hit_indicators": true, "low_mana_pulse": true})


func test_reduce_motion_turns_off_shake_flashes_and_the_hurt_jitter_but_keeps_the_information() -> void:
	FxSettings.reduce_motion()
	assert_eq(FxSettings.shake_scale, 0.0)
	assert_eq(FxSettings.flash_scale, 0.0)
	assert_false(FxSettings.hurt_feedback)
	assert_true(FxSettings.low_health_frame, "the warning is information, not decoration")
	assert_true(FxSettings.heart_beat)
	assert_true(FxSettings.hit_indicators)


func test_the_settings_round_trip_through_a_dictionary() -> void:
	FxSettings.shake_scale = 0.5
	FxSettings.particles = false
	FxSettings.hit_indicators = false
	var saved := FxSettings.to_dict()
	FxSettings.reset()
	FxSettings.apply(saved)
	assert_eq(FxSettings.shake_scale, 0.5)
	assert_false(FxSettings.particles)
	assert_false(FxSettings.hit_indicators)
	assert_true(FxSettings.low_health_frame)


func test_apply_ignores_unknown_keys_and_wrong_types_and_clamps_scales() -> void:
	FxSettings.apply({"shake_scale": "loud", "particles": 3, "nonsense": true, "flash_scale": 7.0, "low_health_frame": false})
	assert_eq(FxSettings.shake_scale, 1.0, "a wrongly typed value is ignored")
	assert_true(FxSettings.particles, "a wrongly typed value is ignored")
	assert_eq(FxSettings.flash_scale, 1.0, "a scale is held between 0 and 1 (the comfort maximum)")
	assert_false(FxSettings.low_health_frame)
	FxSettings.apply({"shake_scale": -2.0})
	assert_eq(FxSettings.shake_scale, 0.0)


func test_turning_particles_off_stops_the_bursts() -> void:
	var burst := BurstLayer.new()
	add_child_autofree(burst)
	var shake := CameraShake.new()
	add_child_autofree(shake)
	shake.bind(Camera2D.new())
	var flash := ScreenFlash.new()
	add_child_autofree(flash)
	var director := FxDirector.new()
	add_child_autofree(director)
	director.setup(burst, shake, flash)
	FxSettings.particles = false
	ImpactEvents.bus.hit.emit(Vector2(10, 10), 1.0, &"fire")
	EnemyAttackEvents.bus.blast_detonated.emit(Vector2(10, 10))
	assert_eq(burst.active_count(), 0)
	assert_eq(director.bursts_made(), 0)
	FxSettings.particles = true
	ImpactEvents.bus.hit.emit(Vector2(10, 10), 1.0, &"fire")
	assert_gt(burst.active_count(), 0)


func test_turning_the_low_health_frame_off_hides_it_but_the_beats_continue() -> void:
	var health := HealthComponent.new()
	health.max_health = 100.0
	add_child_autofree(health)
	health.current_health = 10.0
	var warning := LowHealthWarning.new()
	add_child_autofree(warning)
	warning.bind(health)
	var beats := [0]
	warning.beat.connect(func(_level: int) -> void: beats[0] += 1)
	FxSettings.low_health_frame = false
	for i in 80:
		warning.advance(0.025)
		assert_eq(warning.frame_alpha(), 0.0)
	assert_gt(beats[0], 0, "the heartbeat sound and the heart still follow the beats")
	FxSettings.low_health_frame = true
	var biggest := 0.0
	for i in 80:
		warning.advance(0.025)
		biggest = maxf(biggest, warning.frame_alpha())
	assert_gt(biggest, 0.05)


func test_turning_the_heart_beat_off_keeps_the_heart_still() -> void:
	var bar := load("res://scenes/ui/health_bar.tscn").instantiate() as HealthBar
	add_child_autofree(bar)
	var normal := bar.heart_texture()
	FxSettings.heart_beat = false
	bar.beat()
	assert_eq(bar.heart_texture(), normal)
	FxSettings.heart_beat = true
	bar.beat()
	assert_ne(bar.heart_texture(), normal)


func test_a_switch_can_be_read_and_set_by_its_key() -> void:
	for key in FxSettings.SWITCH_KEYS:
		FxSettings.set_switch(key, false)
		assert_false(FxSettings.get_switch(key), "%s is off" % key)
		FxSettings.set_switch(key, true)
		assert_true(FxSettings.get_switch(key), "%s is on" % key)
	FxSettings.set_switch("no_such_switch", false)
	assert_false(FxSettings.get_switch("no_such_switch"), "an unknown key is just false")
