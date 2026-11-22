extends GutTest

const BOUNDS := Rect2(0, 0, 960, 540)

var _root: Node2D
var _player: Player
var _composer: EnemyComposer
var _rng: RandomNumberGenerator


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_player.global_position = Vector2(400, 300)
	_composer = EnemyComposer.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 9


func _enemy(archetype: StringName, at: Vector2, element: StringName = &"none") -> Enemy:
	var data := _composer.compose(
		load("res://resources/enemies/archetypes/%s.tres" % archetype) as EnemyArchetype,
		load("res://resources/enemies/elements/%s.tres" % element) as EnemyElement,
	)
	var enemy := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.setup(data, BOUNDS, _rng)
	_root.add_child(enemy)
	enemy.global_position = at
	enemy.target_offset = Vector2.ZERO
	enemy.set_physics_process(false)
	return enemy


func _count(group: StringName) -> int:
	return get_tree().get_nodes_in_group(group).filter(func(n): return not n.is_queued_for_deletion()).size()


func _zone() -> BlastZone:
	var zones := get_tree().get_nodes_in_group(&"blast_zones").filter(func(n): return not n.is_queued_for_deletion())
	var zone := zones[0] as BlastZone
	zone.set_process(false)
	return zone


func _health(enemy: Enemy) -> HealthComponent:
	return enemy.get_node("HealthComponent") as HealthComponent


func test_chase_brain_matches_the_old_movement() -> void:
	var enemy := _enemy(&"standard", Vector2(100, 300))
	var brain := EnemyBrain.for_data(enemy.data)
	assert_eq(brain.step(enemy, 0.1), enemy.direction_to_target() * enemy.speed)
	assert_gt(brain.step(enemy, 0.1).x, 0.0)


func test_for_data_picks_the_brain_by_kind_and_defaults_to_chase() -> void:
	assert_true(EnemyBrain.for_data(null) is BrainChase)
	assert_true(EnemyBrain.for_data(_enemy(&"tank", Vector2(100, 100)).data) is BrainChase)
	assert_true(EnemyBrain.for_data(_enemy(&"ranged", Vector2(100, 100)).data) is BrainKeepDistance)
	assert_true(EnemyBrain.for_data(_enemy(&"exploder", Vector2(100, 100)).data) is BrainExplode)
	assert_true(EnemyBrain.for_data(_enemy(&"support", Vector2(100, 100)).data) is BrainSupport)


func test_enemies_join_the_enemies_group() -> void:
	assert_true(_enemy(&"standard", Vector2(100, 100)).is_in_group(&"enemies"))


func test_the_enemy_uses_its_brain_in_its_physics_step() -> void:
	var enemy := _enemy(&"ranged", Vector2(400 - 200, 300))
	var before := enemy.global_position
	enemy._physics_process(0.1)
	assert_gt(enemy.global_position.x, before.x, "a Ranged enemy far away still approaches")


# ---- Ranged ----

func test_ranged_approaches_until_its_preferred_distance_and_holds() -> void:
	var enemy := _enemy(&"ranged", Vector2(400 - 200, 300))
	var brain := EnemyBrain.for_data(enemy.data)
	assert_gt(brain.step(enemy, 0.01).x, 0.0, "far: approach")
	enemy.global_position = Vector2(400 - 90, 300)
	assert_eq(brain.step(enemy, 0.01), Vector2.ZERO, "at 90 px: hold")
	enemy.global_position = Vector2(400 - 95, 300)
	assert_eq(brain.step(enemy, 0.01), Vector2.ZERO, "inside the hold band")


func test_ranged_backs_away_when_the_player_is_too_close() -> void:
	var enemy := _enemy(&"ranged", Vector2(400 - 50, 300))
	var brain := EnemyBrain.for_data(enemy.data)
	var velocity := brain.step(enemy, 0.01)
	assert_lt(velocity.x, 0.0)
	assert_almost_eq(velocity.length(), enemy.speed, 0.001)


func test_ranged_fires_every_interval_with_the_first_after_half() -> void:
	var enemy := _enemy(&"ranged", Vector2(400 - 90, 300))
	var brain := EnemyBrain.for_data(enemy.data)
	brain.step(enemy, 0.99)
	assert_eq(_count(&"enemy_projectiles"), 0)
	brain.step(enemy, 0.02)
	assert_eq(_count(&"enemy_projectiles"), 1)
	brain.step(enemy, 1.9)
	assert_eq(_count(&"enemy_projectiles"), 1)
	brain.step(enemy, 0.2)
	assert_eq(_count(&"enemy_projectiles"), 2)


func test_ranged_does_not_fire_out_of_range() -> void:
	var enemy := _enemy(&"ranged", Vector2(50, 300))
	var brain := EnemyBrain.for_data(enemy.data)
	for i in 6:
		brain.step(enemy, 1.0)
	assert_eq(_count(&"enemy_projectiles"), 0)


func test_ranged_fires_the_moment_it_comes_into_range() -> void:
	var enemy := _enemy(&"ranged", Vector2(50, 300))
	var brain := EnemyBrain.for_data(enemy.data)
	brain.step(enemy, 5.0)
	enemy.global_position = Vector2(400 - 150, 300)
	brain.step(enemy, 0.01)
	assert_eq(_count(&"enemy_projectiles"), 1)


func test_a_ranged_projectile_has_the_archetypes_speed_damage_and_range() -> void:
	var enemy := _enemy(&"ranged", Vector2(400 - 90, 300))
	var brain := EnemyBrain.for_data(enemy.data)
	brain.step(enemy, 1.0)
	var projectile := get_tree().get_nodes_in_group(&"enemy_projectiles")[0] as EnemyProjectile
	assert_eq(projectile.hitbox.damage, 8.0)
	assert_eq(projectile.global_position, enemy.global_position)
	projectile._physics_process(1.0)
	assert_almost_eq(projectile.global_position.x, enemy.global_position.x + 110.0, 0.01)
	projectile._physics_process(0.99)
	assert_false(projectile.is_queued_for_deletion())
	projectile._physics_process(0.02)
	assert_true(projectile.is_queued_for_deletion(), "range 220 at speed 110 is 2 seconds")


func test_ranged_damage_scales_with_the_difficulty_scale() -> void:
	var enemy := _enemy(&"ranged", Vector2(400 - 90, 300))
	enemy.apply_scales(1.0, 2.0, 1.0)
	EnemyBrain.for_data(enemy.data).step(enemy, 1.0)
	var projectile := get_tree().get_nodes_in_group(&"enemy_projectiles")[0] as EnemyProjectile
	assert_eq(projectile.hitbox.damage, 16.0)


func test_a_ranged_elite_keeps_its_behaviour() -> void:
	var enemy := _enemy(&"ranged", Vector2(400 - 200, 300), &"sea")
	enemy.make_elite(EliteModifier.default_modifier())
	assert_true(enemy._brain is BrainKeepDistance)
	assert_gt(enemy._brain.step(enemy, 0.01).x, 0.0)


func test_a_ranged_enemy_with_no_player_does_nothing() -> void:
	var enemy := _enemy(&"ranged", Vector2(100, 100))
	_player.remove_from_group(&"player")
	var brain := EnemyBrain.for_data(enemy.data)
	assert_eq(brain.step(enemy, 5.0), Vector2.ZERO)
	assert_eq(_count(&"enemy_projectiles"), 0)


# ---- Exploder ----

func test_exploder_chases_until_in_range_then_stops_and_fuses() -> void:
	var enemy := _enemy(&"exploder", Vector2(400 - 100, 300))
	var brain := EnemyBrain.for_data(enemy.data)
	assert_gt(brain.step(enemy, 0.01).x, 0.0)
	assert_eq(_count(&"blast_zones"), 0)
	enemy.global_position = Vector2(400 - 20, 300)
	assert_eq(brain.step(enemy, 0.01), Vector2.ZERO)
	assert_eq(_count(&"blast_zones"), 1)
	var zone := _zone()
	assert_eq(zone.radius, 36.0)
	assert_eq(zone.damage, 24.0)
	assert_eq(zone.fuse_time, 0.8)
	assert_eq(zone.global_position, enemy.global_position)
	assert_eq(brain.step(enemy, 0.5), Vector2.ZERO, "it stays put while fusing")
	assert_eq(_count(&"blast_zones"), 1, "one fuse only")


func test_exploder_is_harmless_until_the_fuse_ends() -> void:
	var enemy := _enemy(&"exploder", Vector2(400 - 20, 300))
	var brain := EnemyBrain.for_data(enemy.data)
	brain.step(enemy, 0.01)
	var zone := _zone()
	zone._process(0.79)
	assert_eq(_player.health.current_health, 100.0)
	assert_false(_health(enemy).is_dead())


func test_exploder_blasts_a_player_inside_and_dies_with_no_rewards() -> void:
	var enemy := _enemy(&"exploder", Vector2(400 - 20, 300))
	var brain := EnemyBrain.for_data(enemy.data)
	var died := []
	enemy.died.connect(func(e): died.append(e))
	brain.step(enemy, 0.01)
	var zone := _zone()
	zone._process(0.8)
	assert_eq(_player.health.current_health, 76.0)
	assert_true(_health(enemy).is_dead())
	assert_false(enemy.gives_rewards)
	assert_eq(died.size(), 1)


func test_exploder_blast_misses_a_player_who_moved_away_but_it_still_explodes() -> void:
	var enemy := _enemy(&"exploder", Vector2(400 - 20, 300))
	var brain := EnemyBrain.for_data(enemy.data)
	brain.step(enemy, 0.01)
	var zone := _zone()
	_player.global_position = Vector2(700, 300)
	zone._process(0.8)
	assert_eq(_player.health.current_health, 100.0)
	assert_true(_health(enemy).is_dead())


func test_killing_an_exploder_during_its_fuse_cancels_the_blast_and_pays_rewards() -> void:
	var enemy := _enemy(&"exploder", Vector2(400 - 20, 300))
	var brain := EnemyBrain.for_data(enemy.data)
	brain.step(enemy, 0.01)
	var zone := _zone()
	zone._process(0.4)
	(enemy.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	assert_true(_health(enemy).is_dead())
	assert_true(enemy.gives_rewards)
	assert_true(zone.is_queued_for_deletion(), "the blast is cancelled")
	zone._process(2.0)
	assert_eq(_player.health.current_health, 100.0)


func test_an_exploder_never_blasts_twice() -> void:
	var enemy := _enemy(&"exploder", Vector2(400 - 20, 300))
	var brain := EnemyBrain.for_data(enemy.data)
	brain.step(enemy, 0.01)
	var zone := _zone()
	zone._process(0.8)
	_player.hurtbox._process(2.0)
	zone._process(0.05)
	brain.step(enemy, 1.0)
	assert_eq(_player.health.current_health, 76.0)
	assert_eq(_count(&"blast_zones"), 1)


func test_exploder_blast_damage_scales_with_difficulty() -> void:
	var enemy := _enemy(&"exploder", Vector2(400 - 20, 300))
	enemy.apply_scales(1.0, 2.0, 1.0)
	EnemyBrain.for_data(enemy.data).step(enemy, 0.01)
	assert_eq(_zone().damage, 48.0)


func test_explode_and_die_emits_died_once() -> void:
	var enemy := _enemy(&"standard", Vector2(100, 100))
	var died := []
	enemy.died.connect(func(e): died.append(e))
	enemy.explode_and_die()
	enemy.explode_and_die()
	assert_eq(died.size(), 1)
	assert_false(enemy.gives_rewards)
	assert_true(enemy.is_dead())


# ---- Support ----

func test_support_heals_other_enemies_in_range_over_time() -> void:
	var support := _enemy(&"support", Vector2(100, 100))
	var hurt := _enemy(&"tank", Vector2(130, 100))
	_health(hurt).take_damage(40.0)
	var brain := EnemyBrain.for_data(support.data)
	for i in 4:
		brain.step(support, 0.25)
	assert_almost_eq(_health(hurt).current_health, 40.0 + 6.0, 0.001)


func test_support_never_heals_above_the_maximum() -> void:
	var support := _enemy(&"support", Vector2(100, 100))
	var hurt := _enemy(&"standard", Vector2(110, 100))
	_health(hurt).take_damage(2.0)
	var brain := EnemyBrain.for_data(support.data)
	for i in 20:
		brain.step(support, 0.25)
	assert_eq(_health(hurt).current_health, _health(hurt).max_health)


func test_support_does_not_heal_itself_or_dead_enemies_or_far_ones() -> void:
	var support := _enemy(&"support", Vector2(100, 100))
	_health(support).take_damage(10.0)
	var far := _enemy(&"standard", Vector2(100 + 200, 100))
	_health(far).take_damage(10.0)
	var dead := _enemy(&"standard", Vector2(120, 100))
	_health(dead).take_damage(1000.0)
	var brain := EnemyBrain.for_data(support.data)
	for i in 8:
		brain.step(support, 0.25)
	assert_eq(_health(support).current_health, _health(support).max_health - 10.0)
	assert_eq(_health(far).current_health, _health(far).max_health - 10.0)
	assert_eq(_health(dead).current_health, 0.0)


func test_support_heals_in_quarter_second_steps() -> void:
	var support := _enemy(&"support", Vector2(100, 100))
	var hurt := _enemy(&"tank", Vector2(130, 100))
	_health(hurt).take_damage(40.0)
	var brain := EnemyBrain.for_data(support.data)
	brain.step(support, 0.2)
	assert_eq(_health(hurt).current_health, 40.0)
	brain.step(support, 0.05)
	assert_almost_eq(_health(hurt).current_health, 41.5, 0.001)


func test_support_chases_like_any_enemy() -> void:
	var support := _enemy(&"support", Vector2(100, 300))
	var velocity := EnemyBrain.for_data(support.data).step(support, 0.01)
	assert_eq(velocity, support.direction_to_target() * support.speed)


func test_support_heals_a_support_but_each_one_only_heals_others() -> void:
	var first := _enemy(&"support", Vector2(100, 100))
	var second := _enemy(&"support", Vector2(120, 100))
	_health(second).take_damage(10.0)
	var brain := EnemyBrain.for_data(first.data)
	for i in 4:
		brain.step(first, 0.25)
	assert_almost_eq(_health(second).current_health, _health(second).max_health - 10.0 + 6.0, 0.001)
