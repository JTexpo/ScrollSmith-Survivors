extends GutTest

const BOUNDS := Rect2(0, 0, 960, 540)
const VIEW := Vector2(480, 270)

var _root: Node2D
var _player: Player
var _spawner: EnemySpawner
var _director: RunDirector
var _xp: ValueDropper
var _gold: ValueDropper
var _scrolls: ScrollDropper


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_player.global_position = Vector2(480, 270)
	_player.health.set_max_health(1.0e9)
	var config := SpawnConfig.new()
	config.enemy_scene = load("res://scenes/enemies/base_enemy.tscn")
	config.archetypes = [load("res://resources/enemies/archetypes/standard.tres") as EnemyArchetype] as Array[EnemyArchetype]
	config.elements = [load("res://resources/enemies/elements/none.tres") as EnemyElement] as Array[EnemyElement]
	config.difficulty = DifficultyCurve.default_curve()
	config.elite_modifier = EliteModifier.default_modifier()
	config.boss_scene = load("res://scenes/enemies/boss.tscn")
	config.bosses = [load("res://resources/bosses/ember_titan.tres") as BossData] as Array[BossData]
	_spawner = EnemySpawner.new()
	_spawner.config = config
	_spawner.arena_bounds = BOUNDS
	_spawner.view_size = VIEW
	_spawner.elapsed_override = 0.0
	_spawner.set_process(false)
	_root.add_child(_spawner)
	_spawner.rng.seed = 5
	_xp = _value_dropper(ValueGem.Kind.XP, "res://scenes/progression/xp_gem.tscn")
	_gold = _value_dropper(ValueGem.Kind.GOLD, "res://scenes/progression/gold_coin.tscn")
	_scrolls = ScrollDropper.new()
	_scrolls.pickup_scene = load("res://scenes/scrolls/scroll_pickup.tscn") as PackedScene
	_scrolls.drop_root = _root
	_root.add_child(_scrolls)
	_director = RunDirector.new()
	_director.spawner = _spawner
	_director.xp_dropper = _xp
	_director.gold_dropper = _gold
	_director.scroll_dropper = _scrolls
	_director.rng.seed = 6
	_director.set_process(false)
	_root.add_child(_director)


func _value_dropper(kind: ValueGem.Kind, path: String) -> ValueDropper:
	var dropper := ValueDropper.new()
	dropper.kind = kind
	dropper.gem_scene = load(path) as PackedScene
	dropper.drop_root = _root
	_root.add_child(dropper)
	return dropper


func _kill(boss: Boss) -> void:
	(boss.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1.0e9, Vector2.ZERO)


func _hold(boss: Boss) -> Boss:
	boss.set_physics_process(false)
	return boss


func _gems() -> Array:
	return get_tree().get_nodes_in_group(&"xp_gems").filter(func(n): return not n.is_queued_for_deletion())


func _coins() -> Array:
	return get_tree().get_nodes_in_group(&"gold_coins").filter(func(n): return not n.is_queued_for_deletion())


func _pickups() -> Array:
	return get_tree().get_nodes_in_group(&"scroll_pickups").filter(func(n): return not n.is_queued_for_deletion())


func test_no_boss_before_300_seconds() -> void:
	_director.tick(0.0)
	_director.tick(299.9)
	assert_null(_director.current_boss())
	assert_eq(_director.boss_number, 0)


func test_the_first_boss_spawns_at_300_seconds() -> void:
	watch_signals(_director)
	_director.tick(300.0)
	var boss := _hold(_director.current_boss())
	assert_not_null(boss)
	assert_eq(_director.boss_number, 1)
	assert_eq(boss.data.id, &"ember_titan")
	assert_signal_emit_count(_director, "boss_spawned", 1)


func test_only_one_boss_is_alive_at_a_time() -> void:
	_director.tick(300.0)
	_hold(_director.current_boss())
	_director.tick(650.0)
	_director.tick(1000.0)
	assert_eq(_director.boss_number, 1)
	assert_eq(get_tree().get_nodes_in_group(&"enemies").filter(func(n): return n is Boss).size(), 0)
	var bosses := _root.get_children().filter(func(n): return n is Boss and not n.is_queued_for_deletion())
	assert_eq(bosses.size(), 1)


func test_the_next_boss_is_300_seconds_after_the_previous_spawned() -> void:
	_director.tick(300.0)
	_kill(_hold(_director.current_boss()))
	_director.tick(400.0)
	_director.tick(599.9)
	assert_eq(_director.boss_number, 1)
	_director.tick(600.0)
	assert_eq(_director.boss_number, 2)
	assert_not_null(_director.current_boss())


func test_a_late_kill_spawns_the_next_one_at_once() -> void:
	_director.tick(300.0)
	_hold(_director.current_boss())
	_director.tick(650.0)
	_kill(_director.current_boss())
	_director.tick(700.0)
	assert_eq(_director.boss_number, 2, "due at 600, so it comes the moment the boss is gone")


func test_boss_numbers_increment_and_scale_health() -> void:
	_director.tick(300.0)
	var first := _hold(_director.current_boss())
	assert_almost_eq((first.get_node("HealthComponent") as HealthComponent).max_health, 1500.0, 0.001)
	_kill(first)
	_director.tick(600.0)
	var second := _hold(_director.current_boss())
	assert_eq(second.boss_number, 2)
	assert_almost_eq((second.get_node("HealthComponent") as HealthComponent).max_health, 2250.0, 0.001)


func test_the_roster_cycles() -> void:
	var other := (load("res://resources/bosses/ember_titan.tres") as BossData).duplicate() as BossData
	other.id = &"second_boss"
	_spawner.config.bosses = [load("res://resources/bosses/ember_titan.tres") as BossData, other] as Array[BossData]
	_director.tick(300.0)
	assert_eq(_director.current_boss().data.id, &"ember_titan")
	_kill(_hold(_director.current_boss()))
	_director.tick(600.0)
	assert_eq(_director.current_boss().data.id, &"second_boss")
	_kill(_hold(_director.current_boss()))
	_director.tick(900.0)
	assert_eq(_director.current_boss().data.id, &"ember_titan")


func test_normal_spawning_runs_at_half_rate_while_a_boss_lives_and_returns_to_full() -> void:
	assert_eq(_spawner.spawn_rate_scale, 1.0)
	_director.tick(300.0)
	_hold(_director.current_boss())
	assert_eq(_spawner.spawn_rate_scale, 0.5)
	_kill(_director.current_boss())
	assert_eq(_spawner.spawn_rate_scale, 1.0)


func test_rewards_are_placed_where_the_boss_died() -> void:
	_director.tick(300.0)
	var boss := _hold(_director.current_boss())
	boss.global_position = Vector2(250, 220)
	_kill(boss)
	assert_eq(_gems().size(), 1)
	assert_eq((_gems()[0] as ValueGem).value, 300)
	assert_eq((_gems()[0] as ValueGem).global_position, Vector2(250, 220))
	assert_eq(_coins().size(), 1)
	assert_eq((_coins()[0] as ValueGem).value, 150)
	var scrolls := _pickups()
	assert_eq(scrolls.size(), 2)
	for pickup in scrolls:
		assert_eq(pickup.scroll.rarity, ScrollData.Rarity.RARE)
		assert_lte(pickup.global_position.distance_to(Vector2(250, 220)), 40.0)


func test_boss_rewards_scale_with_the_boss_number() -> void:
	_director.tick(300.0)
	_kill(_hold(_director.current_boss()))
	for gem in _gems():
		gem.collect()
	for coin in _coins():
		coin.collect()
	await wait_frames(2)
	_director.tick(600.0)
	_kill(_hold(_director.current_boss()))
	assert_eq((_gems()[0] as ValueGem).value, 600)
	assert_eq((_coins()[0] as ValueGem).value, 300)


func test_rewards_drop_once() -> void:
	_director.tick(300.0)
	var boss := _hold(_director.current_boss())
	_kill(boss)
	_spawner.boss_died.emit(boss, 1)
	_director.tick(301.0)
	assert_eq(_gems().size(), 1)
	assert_eq(_coins().size(), 1)
	assert_eq(_pickups().size(), 2)


func test_boss_defeated_is_emitted_with_the_number() -> void:
	watch_signals(_director)
	_director.tick(300.0)
	_kill(_hold(_director.current_boss()))
	assert_signal_emit_count(_director, "boss_defeated", 1)
	assert_signal_emitted_with_parameters(_director, "boss_defeated", [1])


func test_the_director_reads_the_pausable_run_clock() -> void:
	GameTime.reset()
	RunClock.reset()
	GameTime.freeze()
	_director._process(0.0)
	assert_eq(_director.last_seconds, RunClock.seconds())
	var frozen := _director.last_seconds
	await wait_seconds(0.1)
	_director._process(0.0)
	assert_eq(_director.last_seconds, frozen)
	GameTime.reset()


func test_summoned_enemies_are_composed_and_inside_the_arena() -> void:
	_director.tick(300.0)
	var boss := _hold(_director.current_boss())
	boss.global_position = Vector2(950, 530)
	var swarmer := load("res://resources/enemies/archetypes/swarmer.tres") as EnemyArchetype
	boss.summon_requested.emit(swarmer, 4)
	assert_eq(_spawner.alive, 4)
	for child in _root.get_children():
		if child is Enemy:
			var at: Vector2 = child.global_position
			assert_true(at.x >= BOUNDS.position.x and at.y >= BOUNDS.position.y and at.x <= BOUNDS.end.x and at.y <= BOUNDS.end.y, str(at))
			assert_eq(child.data.archetype_id, &"swarmer")
			assert_false(child.data.display_name.is_empty())


func test_summons_never_exceed_twice_the_max_alive_but_still_happen() -> void:
	var curve := _spawner.config.difficulty.duplicate() as DifficultyCurve
	curve.base_max_alive = 3
	curve.max_alive_per_minute = 0.0
	curve.max_alive_cap = 3
	_spawner.config.difficulty = curve
	_director.tick(300.0)
	var boss := _hold(_director.current_boss())
	var swarmer := load("res://resources/enemies/archetypes/swarmer.tres") as EnemyArchetype
	boss.summon_requested.emit(swarmer, 4)
	assert_eq(_spawner.alive, 4, "summons ignore the plain cap")
	boss.summon_requested.emit(swarmer, 4)
	assert_eq(_spawner.alive, 6, "but never go past twice it")


func test_a_player_death_stops_the_director_from_spawning_more() -> void:
	_player.remove_from_group(&"player")
	_director.tick(300.0)
	assert_null(_director.current_boss())
	assert_eq(_director.boss_number, 0)


func test_no_boss_without_a_boss_roster_or_a_curve() -> void:
	_spawner.config.bosses = [] as Array[BossData]
	_director.tick(1000.0)
	assert_eq(_director.boss_number, 0)
	_spawner.config.bosses = [load("res://resources/bosses/ember_titan.tres") as BossData] as Array[BossData]
	_spawner.config.difficulty = null
	_director.tick(1000.0)
	assert_eq(_director.boss_number, 0)


func _other_boss(id: StringName) -> BossData:
	var data := (load("res://resources/bosses/ember_titan.tres") as BossData).duplicate() as BossData
	data.id = id
	return data


func test_the_director_spawns_from_the_spawners_roster_not_the_config() -> void:
	_spawner.boss_roster = [_other_boss(&"map_boss")] as Array[BossData]
	_director.tick(300.0)
	assert_eq(_director.current_boss().data.id, &"map_boss")


func test_a_roster_overrides_but_the_clock_and_interval_are_unchanged() -> void:
	_spawner.boss_roster = [_other_boss(&"map_boss")] as Array[BossData]
	_director.tick(299.9)
	assert_null(_director.current_boss(), "still nothing before 300 s")
	_director.tick(300.0)
	assert_not_null(_director.current_boss())
	_kill(_hold(_director.current_boss()))
	_director.tick(599.0)
	assert_null(_director.current_boss(), "the next one is 300 s after the previous spawned")
	_director.tick(600.0)
	assert_not_null(_director.current_boss())


func test_an_empty_roster_and_empty_config_spawn_nothing() -> void:
	_spawner.config.bosses = [] as Array[BossData]
	_spawner.boss_roster = [] as Array[BossData]
	_director.tick(300.0)
	assert_null(_director.current_boss())
	assert_eq(_director.boss_number, 0)


func test_the_map_roster_cycles() -> void:
	_spawner.boss_roster = [_other_boss(&"first"), _other_boss(&"second")] as Array[BossData]
	_director.tick(300.0)
	assert_eq(_director.current_boss().data.id, &"first")
	_kill(_hold(_director.current_boss()))
	_director.tick(600.0)
	assert_eq(_director.current_boss().data.id, &"second")
	_kill(_hold(_director.current_boss()))
	_director.tick(900.0)
	assert_eq(_director.current_boss().data.id, &"first")
