extends GutTest

const BOUNDS := Rect2(0, 0, 960, 540)
const VIEW := Vector2(480, 270)

var _player: Node2D
var _spawner: EnemySpawner


func before_each() -> void:
	_player = Node2D.new()
	add_child_autofree(_player)
	_player.add_to_group(&"player")
	_player.global_position = Vector2(480, 270)
	_spawner = _make_spawner(3)


func after_each() -> void:
	for child in get_children():
		if child is Enemy:
			child.free()


func _make_spawner(max_alive: int) -> EnemySpawner:
	var config := SpawnConfig.new()
	config.interval = 0.5
	config.max_alive = max_alive
	config.spawn_margin = 24.0
	config.enemy_scene = load("res://scenes/enemies/base_enemy.tscn")
	config.archetypes = [load("res://resources/enemies/archetypes/standard.tres") as EnemyArchetype] as Array[EnemyArchetype]
	config.elements = [load("res://resources/enemies/elements/none.tres") as EnemyElement] as Array[EnemyElement]
	var spawner := EnemySpawner.new()
	spawner.config = config
	spawner.arena_bounds = BOUNDS
	spawner.view_size = VIEW
	add_child_autofree(spawner)
	spawner.rng.seed = 7
	return spawner


func test_never_exceeds_max_alive() -> void:
	for i in 10:
		_spawner.try_spawn()
	assert_eq(_spawner.alive, 3)


func test_alive_decrements_on_enemy_death() -> void:
	var enemy := _spawner.try_spawn()
	assert_eq(_spawner.alive, 1)
	(enemy.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	assert_eq(_spawner.alive, 0)


func _inside_inclusive(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x and point.y >= rect.position.y \
		and point.x <= rect.end.x and point.y <= rect.end.y


func test_spawn_position_inside_bounds_and_outside_the_camera_view() -> void:
	var spots: Array[Vector2] = [
		Vector2(480, 270), Vector2(0, 0), Vector2(960, 0), Vector2(0, 540), Vector2(960, 540),
		Vector2(200, 270), Vector2(480, 30), Vector2(940, 520), Vector2(100, 100),
	]
	for spot in spots:
		# The camera stops scrolling at the arena edge, so the visible area is the player-centred view
		# pushed back inside the arena.
		var view_center := spot.clamp(BOUNDS.position + VIEW / 2.0, BOUNDS.end - VIEW / 2.0)
		var view_rect := Rect2(view_center - VIEW / 2.0, VIEW)
		for seed_value in 200:
			_spawner.rng.seed = seed_value
			var position := _spawner.spawn_position(spot)
			if position == Vector2.INF:
				continue
			assert_true(_inside_inclusive(BOUNDS, position), "%s outside arena (player at %s)" % [position, spot])
			assert_false(view_rect.has_point(position), "%s inside view (player at %s)" % [position, spot])


func test_no_spawn_without_player() -> void:
	_player.remove_from_group(&"player")
	assert_null(_spawner.try_spawn())


func test_no_spawn_after_player_leaves_group_mid_run() -> void:
	assert_not_null(_spawner.try_spawn())
	_player.remove_from_group(&"player")
	_spawner.tick(5.0)
	assert_eq(_spawner.alive, 1)


func test_tick_respects_interval() -> void:
	_spawner.tick(0.4)
	assert_eq(_spawner.alive, 0)
	_spawner.tick(0.2)
	assert_eq(_spawner.alive, 1)


func test_enemy_damaged_is_re_emitted() -> void:
	var enemy := _spawner.try_spawn()
	watch_signals(_spawner)
	watch_signals(enemy)
	(enemy.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(10.0, Vector2.ZERO, 0.0, SpellData.Element.FIRE)
	assert_signal_emit_count(_spawner, "enemy_damaged", 1)
	assert_signal_emit_count(enemy, "damaged", 1)
	var params = get_signal_parameters(enemy, "damaged")
	assert_signal_emitted_with_parameters(_spawner, "enemy_damaged", params)





func test_enemy_died_is_re_emitted() -> void:
	var enemy := _spawner.try_spawn()
	watch_signals(_spawner)
	(enemy.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	assert_signal_emit_count(_spawner, "enemy_died", 1)
	assert_signal_emitted_with_parameters(_spawner, "enemy_died", [enemy])


# ---- composed enemies (archetype + element), difficulty and elites ----

const ALL_ARCHETYPES := [&"standard", &"swarmer", &"chaser", &"tank", &"ranged", &"exploder", &"support"]
const ALL_ELEMENTS := [&"none", &"fire", &"thunder", &"land", &"sea"]


func _archetype(id: StringName) -> EnemyArchetype:
	return load("res://resources/enemies/archetypes/%s.tres" % id) as EnemyArchetype


func _element(id: StringName) -> EnemyElement:
	return load("res://resources/enemies/elements/%s.tres" % id) as EnemyElement


func _composed_spawner(archetype_ids: Array, element_ids: Array, curve: DifficultyCurve = null, elapsed: float = 0.0) -> EnemySpawner:
	var config := SpawnConfig.new()
	config.interval = 0.5
	config.max_alive = 150
	config.spawn_margin = 24.0
	config.enemy_scene = load("res://scenes/enemies/base_enemy.tscn")
	var archetypes: Array[EnemyArchetype] = []
	for id in archetype_ids:
		archetypes.append(_archetype(id))
	config.archetypes = archetypes
	var elements: Array[EnemyElement] = []
	for id in element_ids:
		elements.append(_element(id))
	config.elements = elements
	config.difficulty = curve if curve != null else DifficultyCurve.default_curve()
	config.elite_modifier = EliteModifier.default_modifier()
	var spawner := EnemySpawner.new()
	spawner.config = config
	spawner.arena_bounds = BOUNDS
	spawner.view_size = VIEW
	spawner.elapsed_override = elapsed
	add_child_autofree(spawner)
	spawner.rng.seed = 21
	return spawner


func _no_elites() -> DifficultyCurve:
	var curve := DifficultyCurve.default_curve().duplicate() as DifficultyCurve
	curve.elite_cap = 0.0
	return curve


func _all_elites() -> DifficultyCurve:
	var curve := DifficultyCurve.default_curve().duplicate() as DifficultyCurve
	curve.elite_start_seconds = 0.0
	curve.elite_per_minute = 1000.0
	curve.elite_cap = 1.0
	return curve


func test_pick_archetype_only_offers_unlocked_ones() -> void:
	var spawner := _composed_spawner(ALL_ARCHETYPES, ALL_ELEMENTS)
	var seen := {}
	for i in 100:
		seen[spawner.pick_archetype(0.0).id] = true
	assert_eq(seen.keys(), [&"standard"])
	seen.clear()
	for i in 300:
		seen[spawner.pick_archetype(30.0).id] = true
	assert_true(seen.has(&"standard") and seen.has(&"swarmer"))
	assert_eq(seen.size(), 2)
	seen.clear()
	for i in 1000:
		seen[spawner.pick_archetype(300.0).id] = true
	assert_eq(seen.size(), 7)


func test_pick_archetype_follows_the_weights() -> void:
	var spawner := _composed_spawner(ALL_ARCHETYPES, ALL_ELEMENTS)
	var counts := {}
	for i in 4000:
		var id := spawner.pick_archetype(300.0).id
		counts[id] = int(counts.get(id, 0)) + 1
	var weights := {&"standard": 4.0, &"swarmer": 2.0, &"chaser": 2.0, &"tank": 1.0, &"ranged": 1.5, &"exploder": 1.5, &"support": 1.0}
	for id in weights:
		assert_almost_eq(counts[id] / 4000.0, weights[id] / 13.0, 0.03, str(id))


func test_pick_archetype_ignores_zero_weights_and_empty_slots() -> void:
	var spawner := _composed_spawner([&"standard"], [&"none"])
	var dead := _archetype(&"tank").duplicate() as EnemyArchetype
	dead.spawn_weight = 0.0
	dead.unlock_seconds = 0.0
	var pool: Array[EnemyArchetype] = [null, dead, _archetype(&"standard")]
	spawner.config.archetypes = pool
	for i in 100:
		assert_eq(spawner.pick_archetype(0.0).id, &"standard")
	var only_dead: Array[EnemyArchetype] = [dead, null]
	spawner.config.archetypes = only_dead
	assert_null(spawner.pick_archetype(0.0))


func test_pick_element_follows_the_weights() -> void:
	var spawner := _composed_spawner(ALL_ARCHETYPES, ALL_ELEMENTS)
	var counts := {}
	for i in 4000:
		var id := spawner.pick_element().id
		counts[id] = int(counts.get(id, 0)) + 1
	assert_almost_eq(counts[&"none"] / 4000.0, 1.0 / 9.0, 0.03)
	for id in [&"fire", &"thunder", &"land", &"sea"]:
		assert_almost_eq(counts[id] / 4000.0, 2.0 / 9.0, 0.03, str(id))


func test_pick_returns_null_without_a_pool() -> void:
	var spawner := _composed_spawner([&"standard"], [&"none"])
	spawner.config.archetypes = [] as Array[EnemyArchetype]
	spawner.config.elements = [] as Array[EnemyElement]
	assert_null(spawner.pick_archetype(500.0))
	assert_null(spawner.pick_element())


func test_roll_elite_is_never_before_120_seconds() -> void:
	var spawner := _composed_spawner(ALL_ARCHETYPES, ALL_ELEMENTS)
	for i in 4000:
		assert_false(spawner.roll_elite(119.0))


func test_roll_elite_chance_rises_and_is_capped() -> void:
	var spawner := _composed_spawner(ALL_ARCHETYPES, ALL_ELEMENTS)
	var elites := 0
	for i in 4000:
		if spawner.roll_elite(3600.0):
			elites += 1
	assert_almost_eq(elites / 4000.0, 0.2, 0.03)


func test_roll_elite_is_false_without_a_curve_or_modifier() -> void:
	var spawner := _composed_spawner(ALL_ARCHETYPES, ALL_ELEMENTS, _all_elites())
	spawner.config.elite_modifier = null
	assert_false(spawner.roll_elite(600.0))
	spawner.config.elite_modifier = EliteModifier.default_modifier()
	spawner.config.difficulty = null
	assert_false(spawner.roll_elite(600.0))


func test_a_spawned_enemy_is_a_composed_pair() -> void:
	var spawner := _composed_spawner([&"tank"], [&"fire"], _no_elites(), 200.0)
	var enemy := spawner.spawn_at(Vector2(200, 200))
	assert_eq(enemy.data.display_name, "Fire Tank")
	assert_eq(enemy.data.element, SpellData.Element.FIRE)
	assert_eq(enemy.data.archetype_id, &"tank")
	assert_eq((enemy.get_node("Body") as BodyView).fallback_color, enemy.data.color)
	assert_eq(enemy.scale, Vector2.ONE * 1.5)


func test_spawned_enemies_get_the_difficulty_scales() -> void:
	var spawner := _composed_spawner([&"standard"], [&"none"], _no_elites(), 600.0)
	var enemy := spawner.spawn_at(Vector2(200, 200))
	assert_almost_eq((enemy.get_node("HealthComponent") as HealthComponent).max_health, 44.0, 0.001)
	assert_almost_eq((enemy.get_node("ContactHitbox") as HitboxComponent).damage, 16.0, 0.001)
	assert_gte(enemy.speed, enemy.data.speed * 0.85 * 1.2 - 0.001)
	assert_lte(enemy.speed, enemy.data.speed * 1.15 * 1.2 + 0.001)
	assert_false(enemy.is_elite)


func test_an_elite_roll_makes_an_elite_with_its_multipliers() -> void:
	var spawner := _composed_spawner([&"standard"], [&"none"], _all_elites(), 600.0)
	var enemy := spawner.spawn_at(Vector2(200, 200))
	assert_true(enemy.is_elite)
	assert_almost_eq((enemy.get_node("HealthComponent") as HealthComponent).max_health, 20.0 * 2.2 * 3.0, 0.001)
	assert_eq(enemy.scale, Vector2.ONE * 1.4)


func test_a_swarmer_spawns_a_cluster_of_five_within_24_px() -> void:
	var spawner := _composed_spawner([&"swarmer"], [&"none"], _no_elites(), 60.0)
	var first := spawner.spawn_at(Vector2(300, 300))
	assert_eq(first.global_position, Vector2(300, 300))
	assert_eq(spawner.alive, 5)
	var count := 0
	for child in get_children():
		if child is Enemy:
			count += 1
			assert_lte(child.global_position.distance_to(Vector2(300, 300)), 24.01)
	assert_eq(count, 5)


func test_clusters_never_exceed_max_alive() -> void:
	var curve := _no_elites()
	curve.base_max_alive = 7
	curve.max_alive_per_minute = 0.0
	curve.max_alive_cap = 7
	var spawner := _composed_spawner([&"swarmer"], [&"none"], curve, 60.0)
	for i in 6:
		spawner.try_spawn()
		assert_lte(spawner.alive, 7)
	assert_eq(spawner.alive, 7)
	assert_null(spawner.try_spawn())


func test_alive_counts_every_cluster_member_and_falls_when_they_die() -> void:
	var spawner := _composed_spawner([&"swarmer"], [&"none"], _no_elites(), 60.0)
	spawner.spawn_at(Vector2(300, 300))
	assert_eq(spawner.alive, 5)
	for child in get_children():
		if child is Enemy and not child.is_queued_for_deletion():
			(child.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	assert_eq(spawner.alive, 0)


func test_the_interval_shrinks_with_time_and_the_rate_scale_halves_it() -> void:
	var spawner := _composed_spawner([&"standard"], [&"none"], _no_elites())
	spawner.elapsed_override = 0.0
	assert_almost_eq(spawner.current_interval(), 0.5, 0.0001)
	spawner.elapsed_override = 600.0
	assert_almost_eq(spawner.current_interval(), 0.2, 0.0001)
	spawner.spawn_rate_scale = 0.5
	assert_almost_eq(spawner.current_interval(), 0.4, 0.0001)


func test_ticks_spawn_faster_later_in_the_run() -> void:
	var early := _composed_spawner([&"standard"], [&"none"], _no_elites(), 0.0)
	early.tick(0.45)
	assert_eq(early.alive, 0)
	var late := _composed_spawner([&"standard"], [&"none"], _no_elites(), 600.0)
	late.tick(0.45)
	assert_eq(late.alive, 2)


func test_max_alive_follows_the_curve() -> void:
	var spawner := _composed_spawner([&"standard"], [&"none"], _no_elites())
	spawner.elapsed_override = 0.0
	assert_eq(spawner.current_max_alive(), 150)
	spawner.elapsed_override = 60.0
	assert_eq(spawner.current_max_alive(), 170)
	spawner.elapsed_override = 600.0
	assert_eq(spawner.current_max_alive(), 300)


func test_two_spawns_of_one_pair_do_not_share_state() -> void:
	var spawner := _composed_spawner([&"standard"], [&"fire"], _no_elites(), 600.0)
	var first := spawner.spawn_at(Vector2(200, 200))
	var second := spawner.spawn_at(Vector2(220, 200))
	assert_same(first.data, second.data)
	var data_health := first.data.max_health
	(first.get_node("HealthComponent") as HealthComponent).take_damage(10.0)
	first.make_elite(EliteModifier.default_modifier())
	assert_false(second.is_elite)
	assert_eq(second.scale, Vector2.ONE)
	assert_almost_eq((second.get_node("HealthComponent") as HealthComponent).current_health, 44.0, 0.001)
	assert_eq(first.data.max_health, data_health)


func test_elapsed_override_replaces_the_run_clock() -> void:
	var spawner := _composed_spawner([&"standard"], [&"none"])
	spawner.elapsed_override = 123.0
	assert_eq(spawner.elapsed_seconds(), 123.0)
	spawner.elapsed_override = 0.0
	assert_eq(spawner.elapsed_seconds(), 0.0)


func test_the_run_clock_is_used_without_an_override() -> void:
	var spawner := _composed_spawner([&"standard"], [&"none"])
	spawner.elapsed_override = -1.0
	RunClock.reset()
	assert_almost_eq(spawner.elapsed_seconds(), RunClock.seconds(), 0.05)
	assert_lt(spawner.elapsed_seconds(), 0.2)



func test_every_pair_can_spawn_and_is_named() -> void:
	var spawner := _composed_spawner(ALL_ARCHETYPES, ALL_ELEMENTS, _no_elites(), 1000.0)
	var names := {}
	for archetype_id in ALL_ARCHETYPES:
		for element_id in ALL_ELEMENTS:
			spawner.config.archetypes = [_archetype(archetype_id)] as Array[EnemyArchetype]
			spawner.config.elements = [_element(element_id)] as Array[EnemyElement]
			var enemy := spawner.spawn_at(Vector2(400, 300))
			assert_not_null(enemy, "%s %s" % [element_id, archetype_id])
			names[enemy.data.display_name] = true
	assert_eq(names.size(), 35)



func test_the_default_spawn_config_composes_every_pair() -> void:
	var config := load("res://resources/spawning/default_spawn_config.tres") as SpawnConfig
	assert_eq(config.archetypes.size(), 7)
	assert_eq(config.elements.size(), 5)
	var composer := EnemyComposer.new()
	var names := {}
	for archetype in config.archetypes:
		for element in config.elements:
			names[composer.compose(archetype, element).display_name] = true
	assert_eq(names.size(), 35)
	assert_not_null(config.difficulty)
	assert_not_null(config.elite_modifier)
	assert_not_null(config.enemy_scene)


func test_the_default_config_has_no_legacy_pool() -> void:
	var config := load("res://resources/spawning/default_spawn_config.tres") as SpawnConfig
	assert_false("enemy_pool" in config)
	assert_false(_spawner.has_method("pick_enemy_data"))


func test_a_default_run_spawns_standard_enemies_first() -> void:
	var spawner := EnemySpawner.new()
	spawner.config = load("res://resources/spawning/default_spawn_config.tres") as SpawnConfig
	spawner.arena_bounds = BOUNDS
	spawner.view_size = VIEW
	spawner.elapsed_override = 0.0
	add_child_autofree(spawner)
	spawner.rng.seed = 5
	for i in 60:
		assert_eq(spawner.pick_archetype(0.0).id, &"standard")
	var enemy := spawner.spawn_at(Vector2(300, 300))
	assert_eq(enemy.data.archetype_id, &"standard")


func test_the_default_config_unlocks_every_archetype_by_five_minutes() -> void:
	var config := load("res://resources/spawning/default_spawn_config.tres") as SpawnConfig
	for archetype in config.archetypes:
		assert_lte(archetype.unlock_seconds, 300.0, str(archetype.id))


func test_a_cluster_limit_caps_the_members_of_one_spawn() -> void:
	var spawner := _composed_spawner([&"swarmer"], [&"none"], _no_elites(), 60.0)
	spawner.spawn_at(Vector2(300, 300), 2)
	assert_eq(spawner.alive, 2)
	spawner.spawn_at(Vector2(300, 300), 1)
	assert_eq(spawner.alive, 3)


func test_a_cluster_limit_of_zero_or_less_means_no_limit() -> void:
	var spawner := _composed_spawner([&"swarmer"], [&"none"], _no_elites(), 60.0)
	spawner.spawn_at(Vector2(300, 300), 0)
	assert_eq(spawner.alive, 5)
	spawner.spawn_at(Vector2(300, 300), -3)
	assert_eq(spawner.alive, 10)


func _boss_spawner() -> EnemySpawner:
	var spawner := _composed_spawner([&"standard"], [&"none"], _no_elites())
	spawner.config.boss_scene = load("res://scenes/enemies/boss.tscn")
	spawner.config.bosses = [load("res://resources/bosses/ember_titan.tres") as BossData] as Array[BossData]
	return spawner


func test_spawn_boss_adds_it_outside_the_view_and_forwards_damage() -> void:
	var spawner := _boss_spawner()
	var boss := spawner.spawn_boss(spawner.config.bosses[0], 1)
	boss.set_physics_process(false)
	assert_not_null(boss)
	assert_eq(spawner.boss, boss)
	assert_eq(boss.get_parent(), spawner.get_parent())
	var view_center := _player.global_position.clamp(BOUNDS.position + VIEW / 2.0, BOUNDS.end - VIEW / 2.0)
	assert_false(Rect2(view_center - VIEW / 2.0, VIEW).has_point(boss.global_position))
	assert_true(BOUNDS.has_point(boss.global_position))
	watch_signals(spawner)
	(boss.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(10.0, Vector2.ZERO)
	assert_signal_emit_count(spawner, "enemy_damaged", 1)


func test_a_boss_does_not_count_toward_alive() -> void:
	var spawner := _boss_spawner()
	spawner.spawn_boss(spawner.config.bosses[0], 1).set_physics_process(false)
	assert_eq(spawner.alive, 0)


func test_boss_signals_and_clearing_the_boss_on_death() -> void:
	var spawner := _boss_spawner()
	watch_signals(spawner)
	var boss := spawner.spawn_boss(spawner.config.bosses[0], 2)
	boss.set_physics_process(false)
	assert_signal_emitted_with_parameters(spawner, "boss_spawned", [boss, 2])
	(boss.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1.0e9, Vector2.ZERO)
	assert_signal_emitted_with_parameters(spawner, "boss_died", [boss, 2])
	assert_null(spawner.boss)


func test_spawn_boss_without_a_player_or_scene_returns_null() -> void:
	var spawner := _boss_spawner()
	spawner.config.boss_scene = null
	assert_null(spawner.spawn_boss(spawner.config.bosses[0], 1))
