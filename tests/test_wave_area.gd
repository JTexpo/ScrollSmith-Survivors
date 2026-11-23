extends AreaTestBase

const WAVE := "res://resources/spells/areas/wave_area.tres"
## Enemies are clamped to the arena (no negative coordinates), so waves are cast from here.
const O := Vector2(300, 150)


func _damaged(enemy: Enemy) -> bool:
	return _health(enemy).current_health < _health(enemy).max_health


func _wave(spell: SpellData) -> WaveArea:
	return _launch(spell, O) as WaveArea


func test_wave_moves_at_spell_speed() -> void:
	var wave := _wave(_spell(WAVE))
	wave._physics_process(0.5)
	assert_almost_eq(wave.global_position.x, O.x + 70.0, 0.01)
	assert_almost_eq(wave.global_position.y, O.y, 0.01)


func test_wave_widens_while_travelling() -> void:
	var wave := _wave(_spell(WAVE))
	assert_almost_eq(wave.current_width(), 48.0, 0.01)
	wave._physics_process(0.5)
	assert_almost_eq(wave.current_width(), 60.0, 0.01)


func test_wave_ends_at_range() -> void:
	var wave := _wave(_spell(WAVE))
	wave._physics_process(120.0 / 140.0 - 0.05)
	assert_false(wave.is_queued_for_deletion())
	wave._physics_process(0.1)
	assert_true(wave.is_queued_for_deletion())


func test_shorter_range_ends_the_wave_sooner() -> void:
	var wave := _wave(_spell(WAVE, 10.0, 0.0, 0.5))
	wave._physics_process(60.0 / 140.0 + 0.05)
	assert_true(wave.is_queued_for_deletion())


func test_wave_hits_every_enemy_it_passes_once_and_keeps_going() -> void:
	var spell := _spell(WAVE)
	var enemies := [_enemy(O + Vector2(30, 0)), _enemy(O + Vector2(60, 0)), _enemy(O + Vector2(90, 0))]
	var wave := _wave(spell)
	await wait_physics_frames(40)
	for enemy in enemies:
		assert_eq(_health(enemy).current_health, _health(enemy).max_health - spell.damage)
	assert_true(is_instance_valid(wave))
	assert_false(wave.is_queued_for_deletion())


func test_wave_misses_enemies_outside_its_width() -> void:
	var outside := _enemy(O + Vector2(60, 60))
	_wave(_spell(WAVE))
	await wait_physics_frames(40)
	assert_false(_damaged(outside))


func test_wave_carries_damage_and_knockback() -> void:
	var spell := _spell(WAVE, 12.0, 100.0)
	var hitbox := _wave(spell).get_node("Hitbox") as HitboxComponent
	assert_eq(hitbox.damage, DamageSystem.calculate(spell.damage, spell.primary_element()))
	assert_eq(hitbox.knockback, 100.0)
	assert_eq(hitbox.max_hits, 0)


func after_each() -> void:
	SpriteLibrary.root = "res://assets/sprites"


func test_the_wave_is_a_row_of_orbs_along_its_front() -> void:
	var wave := _wave(_spell(WAVE))
	var orbs := wave.orbs()
	assert_gte(orbs.size(), 2)
	for orb in orbs:
		assert_true(orb.has_art())
		assert_eq(orb.current_animation(), &"fly")
		var local := wave.to_local(orb.global_position)
		assert_lte(absf(local.y), wave.current_width() / 2.0 + 0.6, "along the front")
		assert_gte(local.x, -0.6)
		assert_lte(local.x, wave.current_width() * WaveArea.BULGE_RATIO + 0.6, "never behind the origin or past the bulge")


func test_the_orbs_follow_the_widening_front_and_stay_one_to_one_and_upright() -> void:
	var spell := _spell(WAVE)
	var wave := _launch(spell, O, Vector2.DOWN) as WaveArea
	var before := wave.orbs().size()
	wave._physics_process(1.0)
	assert_gt(wave.orbs().size(), before, "a wider wave carries more orbs")
	assert_lte(wave.orbs().size(), WaveArea.MAX_ORBS)
	for orb in wave.orbs():
		assert_almost_eq(orb.global_transform.get_scale().x, 1.0, 0.001)
		assert_almost_eq(orb.global_transform.get_scale().y, 1.0, 0.001, "not stretched with the crescent")
		assert_almost_eq(orb.global_rotation, 0.0, 0.001, "upright though the wave faces down")


func test_the_wave_hitbox_and_crescent_are_unchanged() -> void:
	var spell := _spell(WAVE)
	var wave := _wave(spell)
	var expected := WaveArea._crescent(spell.effective_size())
	assert_eq((wave.get_node("Hitbox/Shape") as CollisionPolygon2D).polygon, expected)
	assert_eq((wave.get_node("Visual") as Polygon2D).polygon, expected)


func test_a_wave_without_art_keeps_the_flat_crescent() -> void:
	SpriteLibrary.root = "res://.godot/art_tests/no_such_folder"
	var wave := _wave(_spell(WAVE))
	assert_eq(wave.orbs().size(), 0)
	assert_gt((wave.get_node("Visual") as Polygon2D).polygon.size(), 0)


func test_the_crescent_is_a_faint_tint_with_an_edge_in_its_elements_colours() -> void:
	var wave := _wave(_spell(WAVE))
	var look := ElementLooks.for_element(SpellData.Element.FIRE)
	assert_eq((wave.get_node("Visual") as Polygon2D).color, look.tint)
	assert_eq(((wave.get_node("Visual") as Polygon2D).get_node("Edge") as Line2D).default_color, look.edge)


func test_the_orbs_never_drift_ahead_of_the_hit_area_as_the_wave_widens() -> void:
	var spell := _spell(WAVE)
	var wave := _wave(spell)
	var front := spell.effective_size() * WaveArea.BULGE_RATIO
	for step in 8:
		wave._physics_process(0.2)
		for orb in wave.orbs():
			assert_lte(wave.to_local(orb.global_position).x, front + 0.6, "only the crescent's height stretches, so its front stays at %s" % front)

