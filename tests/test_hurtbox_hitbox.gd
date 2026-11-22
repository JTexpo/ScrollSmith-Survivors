extends GutTest


func _add_circle(area: Area2D, radius: float) -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)


func _make_target(position: Vector2 = Vector2.ZERO, hp: float = 10.0, invulnerability: float = 0.0) -> HurtboxComponent:
	var holder := Node2D.new()
	holder.position = position
	var health := HealthComponent.new()
	health.max_health = hp
	holder.add_child(health)
	var hurtbox := HurtboxComponent.new()
	hurtbox.health = health
	hurtbox.invulnerability_time = invulnerability
	hurtbox.collision_layer = PhysicsLayers.ENEMY_HURTBOX
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	_add_circle(hurtbox, 6.0)
	holder.add_child(hurtbox)
	add_child_autofree(holder)
	return hurtbox


func _make_hitbox(damage: float = 10.0, cooldown: float = 0.0) -> HitboxComponent:
	var hitbox := HitboxComponent.new()
	hitbox.damage = damage
	hitbox.hit_cooldown = cooldown
	hitbox.monitoring = false
	add_child_autofree(hitbox)
	return hitbox


func test_receive_hit_damages_health_and_emits() -> void:
	var target := _make_target()
	watch_signals(target)
	assert_true(target.receive_hit(4.0, Vector2(-10, 0), 50.0))
	assert_eq(target.health.current_health, 6.0)
	assert_signal_emitted_with_parameters(target, "hit_received", [4.0, Vector2(-10, 0), 50.0, ElementTable.Effect.NEUTRAL])


func test_invulnerable_after_hit_rejects_second() -> void:
	var target := _make_target(Vector2.ZERO, 10.0, 0.5)
	assert_true(target.receive_hit(3.0, Vector2.ZERO))
	assert_true(target.is_invulnerable())
	assert_false(target.receive_hit(3.0, Vector2.ZERO))
	assert_eq(target.health.current_health, 7.0)


func test_invulnerability_expires() -> void:
	var target := _make_target(Vector2.ZERO, 10.0, 0.5)
	target.receive_hit(3.0, Vector2.ZERO)
	target._process(0.6)
	assert_false(target.is_invulnerable())
	assert_true(target.receive_hit(3.0, Vector2.ZERO))
	assert_eq(target.health.current_health, 4.0)


func test_hit_on_dead_target_rejected() -> void:
	var target := _make_target()
	assert_true(target.receive_hit(100.0, Vector2.ZERO))
	assert_false(target.receive_hit(1.0, Vector2.ZERO))


func test_cooldown_blocks_repeat_hits() -> void:
	var target := _make_target(Vector2.ZERO, 100.0)
	var hitbox := _make_hitbox(5.0, 1.0)
	assert_true(hitbox.try_hit(target, 0))
	assert_false(hitbox.try_hit(target, 500))
	assert_true(hitbox.try_hit(target, 1100))
	assert_eq(target.health.current_health, 90.0)


func test_rejected_hit_does_not_consume_cooldown() -> void:
	var target := _make_target(Vector2.ZERO, 100.0, 0.5)
	target.receive_hit(1.0, Vector2.ZERO)
	var hitbox := _make_hitbox(5.0, 1.0)
	assert_false(hitbox.try_hit(target, 0))
	target._process(0.6)
	assert_true(hitbox.try_hit(target, 10))


func test_one_shot_hits_only_one_of_two_overlapping() -> void:
	var near := _make_target(Vector2(5, 0))
	var also_near := _make_target(Vector2(-5, 0))
	var hitbox := HitboxComponent.new()
	hitbox.damage = 4.0
	hitbox.one_shot = true
	hitbox.collision_layer = PhysicsLayers.PLAYER_PROJECTILE
	hitbox.collision_mask = PhysicsLayers.ENEMY_HURTBOX
	hitbox.monitoring = true
	_add_circle(hitbox, 20.0)
	add_child_autofree(hitbox)
	await wait_physics_frames(4)
	var damaged := 0
	for target in [near, also_near]:
		if target.health.current_health < 10.0:
			damaged += 1
	assert_eq(damaged, 1)
	assert_false(hitbox.monitoring)


func _make_active_hitbox(max_hits: int, cooldown: float = 0.0) -> HitboxComponent:
	var hitbox := HitboxComponent.new()
	hitbox.damage = 4.0
	hitbox.max_hits = max_hits
	hitbox.hit_cooldown = cooldown
	hitbox.collision_layer = PhysicsLayers.PLAYER_PROJECTILE
	hitbox.collision_mask = PhysicsLayers.ENEMY_HURTBOX
	hitbox.monitoring = true
	_add_circle(hitbox, 30.0)
	add_child_autofree(hitbox)
	return hitbox


func _damaged_count(targets: Array) -> int:
	var damaged := 0
	for target in targets:
		if target.health.current_health < 10.0:
			damaged += 1
	return damaged


func test_max_hits_two_lands_exactly_two_of_three() -> void:
	var targets := [_make_target(Vector2(5, 0)), _make_target(Vector2(-5, 0)), _make_target(Vector2(0, 5))]
	var hitbox := _make_active_hitbox(2)
	await wait_physics_frames(4)
	assert_eq(_damaged_count(targets), 2)
	assert_true(hitbox.is_finished())
	assert_false(hitbox.monitoring)


func test_max_hits_one_behaves_like_one_shot() -> void:
	var targets := [_make_target(Vector2(5, 0)), _make_target(Vector2(-5, 0))]
	var hitbox := _make_active_hitbox(1)
	await wait_physics_frames(4)
	assert_eq(_damaged_count(targets), 1)
	assert_true(hitbox.is_finished())


func test_max_hits_zero_is_unlimited() -> void:
	var targets := [_make_target(Vector2(5, 0)), _make_target(Vector2(-5, 0)), _make_target(Vector2(0, 5))]
	var hitbox := _make_active_hitbox(0)
	await wait_physics_frames(4)
	assert_eq(_damaged_count(targets), 3)
	assert_false(hitbox.is_finished())


func test_piercing_hitbox_never_double_hits_one_target() -> void:
	var target := _make_target(Vector2.ZERO, 100.0)
	var hitbox := _make_hitbox(4.0, 1000.0)
	hitbox.max_hits = 3
	assert_true(hitbox.try_hit(target, 0))
	assert_false(hitbox.try_hit(target, 10))
	assert_eq(target.health.current_health, 96.0)
	assert_false(hitbox.is_finished())


func test_one_shot_still_finishes_after_one_hit() -> void:
	var target := _make_target(Vector2.ZERO, 100.0)
	var hitbox := _make_hitbox(4.0)
	hitbox.one_shot = true
	assert_true(hitbox.try_hit(target, 0))
	assert_true(hitbox.is_finished())


func test_hit_applies_the_multiplier_at_impact() -> void:
	var cases := [
		[SpellData.Element.LAND, 15.0, ElementTable.Effect.VULNERABLE],
		[SpellData.Element.SEA, 5.0, ElementTable.Effect.RESISTED],
		[SpellData.Element.FIRE, 10.0, ElementTable.Effect.NEUTRAL],
		[SpellData.NO_ELEMENT, 10.0, ElementTable.Effect.NEUTRAL],
	]
	for case in cases:
		var target := _make_target(Vector2.ZERO, 30.0)
		target.element = case[0]
		watch_signals(target)
		target.receive_hit(10.0, Vector2.ZERO, 0.0, SpellData.Element.FIRE)
		assert_eq(target.health.current_health, 30.0 - case[1], "defender %d" % case[0])
		assert_signal_emitted_with_parameters(target, "hit_received", [case[1], Vector2.ZERO, 0.0, case[2]])


func test_hitbox_passes_its_element_to_the_hurtbox() -> void:
	var target := _make_target(Vector2.ZERO, 30.0)
	target.element = SpellData.Element.LAND
	var hitbox := _make_hitbox(10.0)
	hitbox.element = SpellData.Element.FIRE
	assert_true(hitbox.try_hit(target))
	assert_eq(target.health.current_health, 15.0)


func test_hit_cooldown_survives_a_pause() -> void:
	GameTime.reset()
	var target := _make_target(Vector2.ZERO, 100.0)
	var hitbox := _make_hitbox(10.0, 0.05)
	assert_true(hitbox.try_hit(target))
	GameTime.freeze()
	OS.delay_msec(80)
	assert_false(hitbox.try_hit(target), "still inside the cooldown, because the clock is frozen")
	GameTime.unfreeze()
	OS.delay_msec(60)
	assert_true(hitbox.try_hit(target), "the cooldown ran out in game time")
	GameTime.reset()


func test_receive_hit_with_a_profile_uses_the_best_match() -> void:
	var target := _make_target(Vector2.ZERO, 30.0)
	target.element = SpellData.Element.FIRE
	var profile := AttackProfile.new()
	profile.elements = [SpellData.Element.FIRE, SpellData.Element.SEA]
	watch_signals(target)
	target.receive_hit(10.0, Vector2.ZERO, 0.0, SpellData.Element.FIRE, profile)
	assert_eq(target.health.current_health, 15.0)
	assert_signal_emitted_with_parameters(target, "hit_received", [15.0, Vector2.ZERO, 0.0, ElementTable.Effect.VULNERABLE])


func test_receive_hit_without_a_profile_is_unchanged() -> void:
	var target := _make_target(Vector2.ZERO, 30.0)
	target.element = SpellData.Element.LAND
	target.receive_hit(10.0, Vector2.ZERO, 0.0, SpellData.Element.FIRE)
	assert_eq(target.health.current_health, 15.0)


func test_the_hitbox_hands_its_profile_to_the_hurtbox() -> void:
	var target := _make_target(Vector2.ZERO, 30.0)
	target.element = SpellData.Element.FIRE
	var hitbox := _make_hitbox(10.0)
	hitbox.element = SpellData.Element.FIRE
	var profile := AttackProfile.new()
	profile.elements = [SpellData.Element.FIRE, SpellData.Element.SEA]
	hitbox.profile = profile
	assert_true(hitbox.try_hit(target))
	assert_eq(target.health.current_health, 15.0)


func test_granted_invulnerability_blocks_hits() -> void:
	var target := _make_target(Vector2.ZERO, 10.0, 0.0)
	target.grant_invulnerability(5.0)
	assert_true(target.is_invulnerable())
	assert_false(target.receive_hit(4.0, Vector2.ZERO))
	assert_eq(target.health.current_health, 10.0)


func test_a_blocked_hit_starts_no_per_hit_window() -> void:
	var target := _make_target(Vector2.ZERO, 10.0, 0.5)
	target.grant_invulnerability(2.0)
	target.receive_hit(4.0, Vector2.ZERO)
	target._process(2.01)
	assert_false(target.is_invulnerable(), "no leftover per-hit window after the grant ends")
	assert_true(target.receive_hit(4.0, Vector2.ZERO))


func test_the_window_ends_on_time() -> void:
	var target := _make_target(Vector2.ZERO, 10.0, 0.0)
	target.grant_invulnerability(5.0)
	target._process(4.99)
	assert_true(target.is_invulnerable())
	assert_false(target.receive_hit(3.0, Vector2.ZERO))
	target._process(0.02)
	assert_false(target.is_invulnerable())
	assert_true(target.receive_hit(3.0, Vector2.ZERO))
	assert_eq(target.health.current_health, 7.0)


func test_the_per_hit_window_does_not_shorten_the_granted_one() -> void:
	var target := _make_target(Vector2.ZERO, 10.0, 0.5)
	assert_true(target.receive_hit(1.0, Vector2.ZERO), "a normal hit starts the 0.5 s window")
	target.grant_invulnerability(5.0)
	target._process(0.6)
	assert_true(target.is_invulnerable(), "the per-hit window ended but the grant has not")
	assert_false(target.receive_hit(1.0, Vector2.ZERO))
	target._process(4.5)
	assert_false(target.is_invulnerable())


func test_a_grant_does_not_cancel_a_running_per_hit_window_early() -> void:
	var target := _make_target(Vector2.ZERO, 10.0, 3.0)
	target.receive_hit(1.0, Vector2.ZERO)
	target.grant_invulnerability(1.0)
	target._process(1.5)
	assert_true(target.is_invulnerable(), "the 3 s per-hit window is still running")
	target._process(1.6)
	assert_false(target.is_invulnerable())


func test_a_longer_grant_replaces_a_shorter_one_and_a_shorter_never_replaces_a_longer() -> void:
	var target := _make_target(Vector2.ZERO, 10.0, 0.0)
	target.grant_invulnerability(2.0)
	target.grant_invulnerability(5.0)
	target._process(3.0)
	assert_true(target.is_invulnerable())
	target.grant_invulnerability(0.5)
	target._process(1.9)
	assert_true(target.is_invulnerable(), "the longer remaining window was kept")
	target._process(0.2)
	assert_false(target.is_invulnerable())


func test_grant_invulnerability_ignores_zero_and_negative_seconds() -> void:
	var target := _make_target(Vector2.ZERO, 10.0, 0.0)
	target.grant_invulnerability(0.0)
	target.grant_invulnerability(-3.0)
	assert_false(target.is_invulnerable())
	assert_true(target.receive_hit(1.0, Vector2.ZERO))


func test_both_windows_expire_independently() -> void:
	var target := _make_target(Vector2.ZERO, 10.0, 1.0)
	target.receive_hit(1.0, Vector2.ZERO)
	target.grant_invulnerability(3.0)
	target._process(1.1)
	assert_true(target.is_invulnerable(), "the grant is still running")
	target._process(2.0)
	assert_false(target.is_invulnerable())
