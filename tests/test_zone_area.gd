extends AreaTestBase

const ZONE := "res://resources/spells/areas/zone_area.tres"
## Enemies are clamped to the arena (no negative coordinates), so zones are cast from here.
const O := Vector2(300, 150)


func _zone(spell: SpellData, target: Vector2) -> ZoneArea:
	return _launch(spell, O, Vector2.RIGHT, target) as ZoneArea


func test_zone_lands_at_the_target_when_in_range() -> void:
	assert_eq(_zone(_spell(ZONE), O + Vector2(80, 0)).global_position, O + Vector2(80, 0))


func test_zone_target_is_clamped_to_range() -> void:
	assert_eq(_zone(_spell(ZONE), O + Vector2(500, 0)).global_position, O + Vector2(120, 0))


func test_zone_with_target_on_the_player_lands_on_the_player() -> void:
	assert_eq(_zone(_spell(ZONE), O).global_position, O)


func test_zone_range_scale_moves_the_clamp_in() -> void:
	var zone := _zone(_spell(ZONE, 10.0, 0.0, 0.5), O + Vector2(500, 0))
	assert_eq(zone.global_position, O + Vector2(60, 0))


func test_zone_hits_enemies_inside_not_outside() -> void:
	var inside := _enemy(O + Vector2(80, 0))
	var outside := _enemy(O + Vector2(80, 60))
	_zone(_spell(ZONE), O + Vector2(80, 0))
	await wait_physics_frames(8)
	assert_true(_damaged(inside))
	assert_false(_damaged(outside))


func test_zone_ticks_on_its_interval() -> void:
	var enemy := _enemy(O + Vector2(400, 300))
	var hitbox := _zone(_spell(ZONE), O + Vector2(80, 0)).get_node("Hitbox") as HitboxComponent
	var hurtbox := enemy.get_node("HurtboxComponent") as HurtboxComponent
	assert_eq(hitbox.hit_cooldown, 0.5)
	assert_true(hitbox.try_hit(hurtbox, 1000))
	assert_false(hitbox.try_hit(hurtbox, 1499))
	assert_true(hitbox.try_hit(hurtbox, 1500))


func test_zone_without_a_tick_interval_hits_each_enemy_once() -> void:
	var spell := _spell(ZONE)
	spell.area_data = spell.area_data.duplicate() as AreaData
	spell.area_data.tick_interval = 0.0
	var enemy := _enemy(O + Vector2(80, 0))
	_zone(spell, O + Vector2(80, 0))
	await wait_physics_frames(20)
	assert_eq(_health(enemy).current_health, _health(enemy).max_health - spell.damage)


func test_zone_ends_after_its_duration() -> void:
	var spell := _spell(ZONE)
	var zone := _zone(spell, O + Vector2(80, 0))
	zone._physics_process(spell.area_data.duration - 0.1)
	assert_false(zone.is_queued_for_deletion())
	zone._physics_process(0.2)
	assert_true(zone.is_queued_for_deletion())


func test_zone_carries_damage_and_knockback() -> void:
	var spell := _spell(ZONE, 12.0, 40.0)
	var hitbox := _zone(spell, O).get_node("Hitbox") as HitboxComponent
	assert_eq(hitbox.damage, DamageSystem.calculate(spell.damage, spell.primary_element()))
	assert_eq(hitbox.knockback, 40.0)

func test_the_zone_radius_and_hitbox_are_unchanged_by_the_skin() -> void:
	var spell := _spell(ZONE)
	var zone := _zone(spell, O + Vector2(80, 0))
	assert_eq(((zone.get_node("Hitbox/Shape") as CollisionShape2D).shape as CircleShape2D).radius, spell.effective_size())


func test_a_zone_spawns_a_fresh_set_at_each_tick_and_not_between() -> void:
	var zone := _zone(_spell(ZONE), O + Vector2(80, 0))
	var live := func() -> int: return get_tree().get_nodes_in_group(&"effect_sprites").filter(func(node: Node) -> bool: return not node.is_queued_for_deletion()).size()
	var first: int = live.call()
	assert_gt(first, 0, "the first set plays when it lands")
	zone._physics_process(0.2)
	assert_eq(live.call(), first, "nothing new between ticks")
	zone._physics_process(0.31)
	assert_gt(live.call(), first, "a fresh set at the tick")
