extends GutTest

var _root: Node2D
var _composer: EnemyComposer
var _rng: RandomNumberGenerator


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_composer = EnemyComposer.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 3


func _data(archetype: StringName, element: StringName = &"none") -> EnemyData:
	return _composer.compose(
		load("res://resources/enemies/archetypes/%s.tres" % archetype) as EnemyArchetype,
		load("res://resources/enemies/elements/%s.tres" % element) as EnemyElement,
	)


func _enemy(archetype: StringName = &"standard", element: StringName = &"none") -> Enemy:
	var enemy := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.setup(_data(archetype, element), Rect2(0, 0, 960, 540), _rng)
	_root.add_child(enemy)
	return enemy


func _health(enemy: Enemy) -> HealthComponent:
	return enemy.get_node("HealthComponent") as HealthComponent


func _hitbox(enemy: Enemy) -> HitboxComponent:
	return enemy.get_node("ContactHitbox") as HitboxComponent


func test_apply_scales_changes_health_damage_and_speed_of_that_enemy_only() -> void:
	var enemy := _enemy()
	var speed := enemy.speed
	enemy.apply_scales(2.0, 1.5, 1.2)
	assert_almost_eq(_health(enemy).max_health, 40.0, 0.001)
	assert_almost_eq(_health(enemy).current_health, 40.0, 0.001)
	assert_almost_eq(_hitbox(enemy).damage, 15.0, 0.001)
	assert_almost_eq(enemy.speed, speed * 1.2, 0.001)


func test_scales_of_one_change_nothing() -> void:
	var enemy := _enemy()
	var speed := enemy.speed
	enemy.apply_scales(1.0, 1.0, 1.0)
	assert_eq(_health(enemy).max_health, 20.0)
	assert_eq(_hitbox(enemy).damage, 10.0)
	assert_eq(enemy.speed, speed)


func test_apply_scales_twice_does_not_compound() -> void:
	var enemy := _enemy()
	var speed := enemy.speed
	enemy.apply_scales(2.0, 2.0, 1.1)
	enemy.apply_scales(2.0, 2.0, 1.1)
	assert_almost_eq(_health(enemy).max_health, 40.0, 0.001)
	assert_almost_eq(_hitbox(enemy).damage, 20.0, 0.001)
	assert_almost_eq(enemy.speed, speed * 1.1, 0.001)


func test_two_enemies_of_one_pair_never_share_scale_health_or_elite_flag() -> void:
	var first := _enemy(&"tank", &"fire")
	var second := _enemy(&"tank", &"fire")
	assert_same(first.data, second.data)
	first.apply_scales(3.0, 2.0, 1.0)
	first.make_elite(EliteModifier.default_modifier())
	assert_eq(_health(second).max_health, 80.0)
	assert_eq(_hitbox(second).damage, 16.0)
	assert_false(second.is_elite)
	assert_eq(second.scale, Vector2.ONE * 1.5)
	_health(first).take_damage(30.0)
	assert_eq(_health(second).current_health, 80.0)


func test_the_shared_enemy_data_is_never_edited() -> void:
	var enemy := _enemy(&"tank", &"fire")
	var data := enemy.data
	var health := data.max_health
	var damage := data.contact_damage
	var speed := data.speed
	var xp := data.xp_reward
	enemy.apply_scales(4.0, 4.0, 2.0)
	enemy.make_elite(EliteModifier.default_modifier())
	assert_eq(data.max_health, health)
	assert_eq(data.contact_damage, damage)
	assert_eq(data.speed, speed)
	assert_eq(data.xp_reward, xp)
	assert_eq(data.body_scale, 1.5)


func test_make_elite_multiplies_stats_size_and_rewards() -> void:
	var enemy := _enemy()
	var speed := enemy.speed
	enemy.make_elite(EliteModifier.default_modifier())
	assert_true(enemy.is_elite)
	assert_almost_eq(_health(enemy).max_health, 60.0, 0.001)
	assert_almost_eq(_hitbox(enemy).damage, 15.0, 0.001)
	assert_almost_eq(enemy.speed, speed * 1.15, 0.001)
	assert_eq(enemy.scale, Vector2.ONE * 1.4)
	assert_eq(enemy.xp_reward(), 15)
	assert_eq(enemy.gold_reward(), 3)
	assert_almost_eq(enemy.drop_chance_scale(), 2.0, 0.0001)


func test_a_plain_enemy_reports_its_datas_rewards() -> void:
	var tank := _enemy(&"tank")
	assert_eq(tank.xp_reward(), 12)
	assert_eq(tank.gold_reward(), 3)
	assert_almost_eq(tank.drop_chance_scale(), 1.5, 0.0001)


func test_an_elite_keeps_its_archetypes_behaviour_data() -> void:
	var enemy := _enemy(&"ranged", &"sea")
	enemy.make_elite(EliteModifier.default_modifier())
	assert_eq(enemy.data.behavior.kind, EnemyBehaviorData.Kind.KEEP_DISTANCE)


func test_elite_and_difficulty_scales_stack_in_either_order() -> void:
	var one := _enemy()
	one.apply_scales(2.0, 2.0, 1.0)
	one.make_elite(EliteModifier.default_modifier())
	var two := _enemy()
	two.make_elite(EliteModifier.default_modifier())
	two.apply_scales(2.0, 2.0, 1.0)
	assert_almost_eq(_health(one).max_health, 120.0, 0.001)
	assert_almost_eq(_health(two).max_health, 120.0, 0.001)
	assert_almost_eq(_hitbox(one).damage, _hitbox(two).damage, 0.001)
	assert_almost_eq(_hitbox(one).damage, 10.0 * 2.0 * 1.5, 0.001)


func test_make_elite_twice_does_not_compound() -> void:
	var enemy := _enemy()
	enemy.make_elite(EliteModifier.default_modifier())
	enemy.make_elite(EliteModifier.default_modifier())
	assert_almost_eq(_health(enemy).max_health, 60.0, 0.001)
	assert_eq(enemy.scale, Vector2.ONE * 1.4)


func test_body_scale_comes_from_the_archetype() -> void:
	assert_eq(_enemy(&"tank").scale, Vector2.ONE * 1.5)
	assert_eq(_enemy(&"swarmer").scale, Vector2.ONE * 0.7)
	assert_eq(_enemy(&"standard").scale, Vector2.ONE)


func test_an_elite_has_an_outline_and_a_plain_enemy_does_not() -> void:
	var elite := _enemy()
	elite.make_elite(EliteModifier.default_modifier())
	assert_true(elite.has_node("EliteOutline"))
	assert_false(_enemy().has_node("EliteOutline"))
	assert_eq((elite.get_node("EliteOutline") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_the_death_shrink_still_frees_a_scaled_enemy() -> void:
	var enemy := _enemy(&"tank")
	enemy.make_elite(EliteModifier.default_modifier())
	_health(enemy).take_damage(100000.0)
	await wait_seconds(0.5)
	assert_false(is_instance_valid(enemy))


func test_display_name_of_an_elite() -> void:
	var enemy := _enemy(&"tank", &"thunder")
	assert_eq(enemy.display_name(), "Thunder Tank")
	enemy.make_elite(EliteModifier.default_modifier())
	assert_eq(enemy.display_name(), "Elite Thunder Tank")


func test_rewards_round_to_whole_numbers_and_never_below_one_for_a_rewarding_enemy() -> void:
	var enemy := _enemy(&"swarmer")
	var tiny := EliteModifier.new()
	tiny.reward_multiplier = 0.1
	enemy.make_elite(tiny)
	assert_eq(enemy.xp_reward(), 1)
	assert_eq(enemy.gold_reward(), 1)
	var odd := EliteModifier.new()
	odd.reward_multiplier = 1.4
	var other := _enemy(&"swarmer")
	other.make_elite(odd)
	assert_eq(other.xp_reward(), 3)


func test_an_enemy_with_no_data_reports_nothing() -> void:
	var bare := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	bare.data = null
	autofree(bare)
	assert_eq(bare.xp_reward(), 0)
	assert_eq(bare.gold_reward(), 0)
	assert_eq(bare.drop_chance_scale(), 1.0)
	assert_eq(bare.display_name(), "")


func test_gives_rewards_defaults_to_true() -> void:
	assert_true(_enemy().gives_rewards)


func test_the_default_elite_modifier_matches_the_spec() -> void:
	var elite := EliteModifier.default_modifier()
	assert_eq(elite.health_multiplier, 3.0)
	assert_eq(elite.damage_multiplier, 1.5)
	assert_eq(elite.speed_multiplier, 1.15)
	assert_eq(elite.size_multiplier, 1.4)
	assert_eq(elite.reward_multiplier, 3.0)
	assert_eq(elite.drop_chance_multiplier, 2.0)
