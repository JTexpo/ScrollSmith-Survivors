extends AreaTestBase

const FIRE_PATH := "res://resources/spells/fire_missile.tres"


func _fire(max_hits: int = 1) -> SpellData:
	var spell := (load(FIRE_PATH) as SpellData).duplicate() as SpellData
	spell.max_hits = max_hits
	# These tests are about the flying projectile itself; the burst where it ends has its own file (test_missile_burst).
	spell.area_data = spell.area_data.duplicate() as AreaData
	spell.area_data.burst_radius = 0.0
	return spell


func _missile(spell: SpellData, at: Vector2 = Vector2.ZERO, direction: Vector2 = Vector2.RIGHT) -> MissileArea:
	return _launch(spell, at, direction) as MissileArea


func test_missile_moves_straight_at_spell_speed() -> void:
	var spell := _fire()
	var missile := _missile(spell)
	missile._physics_process(0.1)
	assert_almost_eq(missile.position.x, spell.projectile_speed * 0.1, 0.01)
	assert_almost_eq(missile.position.y, 0.0, 0.01)


func test_missile_freed_after_range_over_speed() -> void:
	var spell := _fire()
	var lifetime := spell.effective_range() / spell.projectile_speed
	var missile := _missile(spell)
	missile._physics_process(lifetime - 0.05)
	assert_false(missile.is_queued_for_deletion())
	missile._physics_process(0.1)
	assert_true(missile.is_queued_for_deletion())


func test_shorter_range_frees_the_missile_sooner() -> void:
	var spell := _fire()
	spell.range_scale = 0.5
	var missile := _missile(spell)
	missile._physics_process(spell.effective_range() / spell.projectile_speed + 0.05)
	assert_true(missile.is_queued_for_deletion())


func test_without_art_the_missile_size_scales_the_node() -> void:
	SpriteLibrary.root = "res://.godot/art_tests/no_such_folder"
	var spell := _fire()
	spell.size_scale = 2.0
	assert_eq(_missile(spell).scale, Vector2(2, 2))


func test_missile_starts_at_the_origin() -> void:
	assert_eq(_missile(_fire(), Vector2(30, 40)).global_position, Vector2(30, 40))


func test_missile_is_tinted_by_the_spell() -> void:
	var spell := _fire()
	assert_eq((_missile(spell).get_node("Body") as ColorRect).color, spell.color)


func test_hitbox_carries_spell_damage_and_knockback() -> void:
	var spell := _fire()
	var hitbox := _missile(spell).get_node("Hitbox") as HitboxComponent
	assert_eq(hitbox.damage, spell.damage)
	assert_eq(hitbox.element, SpellData.Element.FIRE)
	assert_eq(hitbox.knockback, spell.knockback)


func test_fire_missile_is_multiplied_when_it_lands() -> void:
	var strong := _enemy(Vector2(300, 100))
	var weak := _enemy(Vector2(300, 300))
	(strong.get_node("HurtboxComponent") as HurtboxComponent).element = SpellData.Element.LAND
	(weak.get_node("HurtboxComponent") as HurtboxComponent).element = SpellData.Element.SEA
	_missile(_fire(), Vector2(300, 100))
	_missile(_fire(), Vector2(300, 300))
	await wait_physics_frames(6)
	assert_eq(_health(strong).current_health, _health(strong).max_health - 15.0)
	assert_eq(_health(weak).current_health, _health(weak).max_health - 5.0)


func test_single_hit_spell_hits_one_of_two_and_is_freed() -> void:
	var first := _enemy(Vector2(0, 0))
	var second := _enemy(Vector2(2, 0))
	var missile := _missile(_fire(1), Vector2(1, 0))
	await wait_physics_frames(6)
	var damaged := 0
	for enemy in [first, second]:
		if _health(enemy).current_health < _health(enemy).max_health:
			damaged += 1
	assert_eq(damaged, 1)
	assert_false(is_instance_valid(missile))


func test_piercing_spell_hits_three_distinct_enemies_once_each() -> void:
	var spell := _fire(3)
	var enemies := [_enemy(Vector2(0, 0)), _enemy(Vector2(2, 0)), _enemy(Vector2(4, 0))]
	var missile := _missile(spell, Vector2(2, 0))
	await wait_physics_frames(8)
	for enemy in enemies:
		var health := _health(enemy)
		assert_eq(health.current_health, health.max_health - spell.damage)
	assert_false(is_instance_valid(missile))


func test_piercing_spell_survives_a_single_hit() -> void:
	var spell := _fire(3)
	var enemy := _enemy(Vector2(0, 0))
	var missile := _missile(spell, Vector2(0, 0))
	await wait_physics_frames(4)
	assert_lt(_health(enemy).current_health, _health(enemy).max_health)
	assert_true(is_instance_valid(missile))
	assert_false(missile.is_queued_for_deletion())


func test_the_hitbox_carries_the_spells_profile() -> void:
	var spell := _fire()
	var elements: Array[SpellData.Element] = [SpellData.Element.FIRE, SpellData.Element.SEA]
	spell.elements = elements
	spell.vulnerability_scale = 2.0
	spell.ignores_resistance = true
	var hitbox := _missile(spell).get_node("Hitbox") as HitboxComponent
	assert_not_null(hitbox.profile)
	assert_eq(hitbox.profile.elements, [SpellData.Element.FIRE, SpellData.Element.SEA])
	assert_eq(hitbox.profile.vulnerability_scale, 2.0)
	assert_true(hitbox.profile.ignores_resistance)
	assert_eq(hitbox.element, SpellData.Element.FIRE, "the first element is still the hitbox's element")


func test_damage_scale_multiplies_the_hit_damage() -> void:
	var spell := _fire()
	var effect := spell.area_data.scene.instantiate() as AreaEffect
	effect.damage_scale = 2.5
	add_child_autofree(effect)
	effect.launch(spell, Vector2.ZERO, Vector2.RIGHT, Vector2(10000, 0))
	assert_almost_eq((effect.get_node("Hitbox") as HitboxComponent).damage, spell.damage * 2.5, 0.0001)


func test_default_damage_scale_leaves_the_damage_alone() -> void:
	var spell := _fire()
	var hitbox := _missile(spell).get_node("Hitbox") as HitboxComponent
	assert_eq(hitbox.damage, spell.damage)


func after_each() -> void:
	SpriteLibrary.root = "res://assets/sprites"


func test_orb_class_follows_the_size_in_three_steps() -> void:
	assert_eq(MissileArea.orb_class(0.5), 12)
	assert_eq(MissileArea.orb_class(1.0), 12)
	assert_eq(MissileArea.orb_class(1.2), 12)
	assert_eq(MissileArea.orb_class(1.5), 16)
	assert_eq(MissileArea.orb_class(2.0), 16)
	assert_eq(MissileArea.orb_class(2.5), 24)


func _orb(missile: MissileArea) -> BodyView:
	return missile.get_node("Orb") as BodyView


func test_the_missile_shows_its_elements_orb_one_to_one_whatever_its_size() -> void:
	var spell := _fire()
	spell.size_scale = 3.0
	var missile := _missile(spell)
	assert_eq(missile.scale, Vector2.ONE, "the node is never scaled, so no pixel is")
	assert_true(_orb(missile).has_art())
	assert_true(_orb(missile).visible)
	assert_eq(_orb(missile).current_animation(), &"fly")
	assert_almost_eq((_orb(missile).get_node("Sprite") as Node2D).global_transform.get_scale().x, 1.0, 0.001)
	assert_false((missile.get_node("Body") as ColorRect).visible, "the old square steps aside")
	var sea := _fire()
	sea.elements = [SpellData.Element.SEA]
	var sea_missile := _missile(sea)
	assert_ne((_orb(missile).get_node("Sprite") as AnimatedSprite2D).sprite_frames, (_orb(sea_missile).get_node("Sprite") as AnimatedSprite2D).sprite_frames, "each element has its own object")


func test_the_hit_shape_still_follows_the_exact_size() -> void:
	for size in [1.0, 1.5, 3.0]:
		var spell := _fire()
		spell.size_scale = size
		var missile := _missile(spell)
		var hitbox := missile.get_node("Hitbox") as Node2D
		var circle := (missile.get_node("Hitbox/CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
		assert_almost_eq(circle.radius * hitbox.global_transform.get_scale().x, 4.0 * spell.effective_size(), 0.01, "size %s" % size)


func test_a_missile_without_art_keeps_the_scaled_square() -> void:
	SpriteLibrary.root = "res://.godot/art_tests/no_such_folder"
	var spell := _fire()
	spell.size_scale = 2.0
	var missile := _missile(spell)
	assert_false(_orb(missile).has_art())
	assert_false(_orb(missile).visible)
	assert_true((missile.get_node("Body") as ColorRect).visible)
	assert_eq(missile.scale, Vector2(2, 2))

