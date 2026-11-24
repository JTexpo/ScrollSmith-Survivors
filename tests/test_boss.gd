extends GutTest

const BOUNDS := Rect2(0, 0, 960, 540)
const K := BossAttack.Kind
const STEP := 0.05

var _root: Node2D
var _player: Player
var _rng: RandomNumberGenerator


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_player.global_position = Vector2(400, 300)
	_player.health.set_max_health(1.0e9)
	_rng = RandomNumberGenerator.new()
	_rng.seed = 11


func _attack(kind: BossAttack.Kind, telegraph: float = 1.0) -> BossAttack:
	var attack := BossAttack.new()
	attack.kind = kind
	attack.telegraph_time = telegraph
	match kind:
		K.SLAM:
			attack.radius = 48.0
			attack.damage = 30.0
		K.CHARGE:
			attack.damage = 25.0
			attack.dash_speed = 260.0
			attack.dash_time = 0.6
			attack.recover_time = 2.0
			attack.vulnerability_bonus = 0.5
		K.BURST:
			attack.damage = 12.0
			attack.count = 12
			attack.projectile_speed = 100.0
			attack.projectile_range = 260.0
		K.SUMMON:
			attack.count = 4
			attack.summon_archetype = load("res://resources/enemies/archetypes/swarmer.tres") as EnemyArchetype
		K.LIGHTNING:
			attack.count = 5
			attack.spread = 70.0
			attack.radius = 28.0
			attack.damage = 22.0
			attack.recover_time = 0.3
	return attack


## A one-phase test boss that stands still, so nothing but its own attacks happens.
func _data(attacks: Array[BossAttack], interval: float = 0.5, speed: float = 0.0, contact: float = 5.0, health: float = 1000.0, element: int = -1) -> BossData:
	var phase := BossPhase.new()
	phase.health_threshold = 1.0
	phase.attacks = attacks
	phase.attack_interval = interval
	var data := BossData.new()
	data.id = &"test_boss"
	data.display_name = "Test Boss"
	data.element = element
	data.max_health = health
	data.contact_damage = contact
	data.speed = speed
	data.body_scale = 1.0
	data.phases = [phase] as Array[BossPhase]
	return data


func _boss(data: BossData, at: Vector2 = Vector2(100, 300), number: int = 1, curve: DifficultyCurve = null) -> Boss:
	var boss := (load("res://scenes/enemies/boss.tscn") as PackedScene).instantiate() as Boss
	boss.setup(data, number, curve, BOUNDS, _rng)
	_root.add_child(boss)
	boss.global_position = at
	boss.set_physics_process(false)
	return boss


func _step(boss: Boss, seconds: float) -> void:
	for i in maxi(roundi(seconds / STEP), 1):
		boss._physics_process(STEP)


func _health(boss: Boss) -> HealthComponent:
	return boss.get_node("HealthComponent") as HealthComponent


func _hitbox(boss: Boss) -> HitboxComponent:
	return boss.get_node("ContactHitbox") as HitboxComponent


func _hit(boss: Boss, damage: float, knockback: float = 0.0, element: int = SpellData.NO_ELEMENT) -> void:
	(boss.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(damage, Vector2.ZERO, knockback, element)


func _zones() -> Array:
	return get_tree().get_nodes_in_group(&"blast_zones").filter(func(n): return not n.is_queued_for_deletion())


func _projectiles() -> Array:
	return get_tree().get_nodes_in_group(&"enemy_projectiles").filter(func(n): return not n.is_queued_for_deletion())


func test_setup_scales_health_and_damage_by_boss_number() -> void:
	var boss := _boss(load("res://resources/bosses/ember_titan.tres") as BossData, Vector2(100, 300), 3, DifficultyCurve.default_curve())
	assert_almost_eq(_health(boss).max_health, 3000.0, 0.001)
	assert_almost_eq(_hitbox(boss).damage, 28.0, 0.001)
	var first := _boss(load("res://resources/bosses/ember_titan.tres") as BossData, Vector2(100, 400), 1, DifficultyCurve.default_curve())
	assert_almost_eq(_health(first).max_health, 1500.0, 0.001)
	assert_almost_eq(_hitbox(first).damage, 20.0, 0.001)


func test_setup_takes_element_colour_and_size_from_the_data() -> void:
	var data := load("res://resources/bosses/ember_titan.tres") as BossData
	var boss := _boss(data)
	assert_eq((boss.get_node("HurtboxComponent") as HurtboxComponent).element, SpellData.Element.FIRE)
	assert_eq(boss.scale, Vector2.ONE * 3.0)
	assert_eq((boss.get_node("Body") as BodyView).fallback_color, data.color)
	assert_eq(boss.phase, 0)
	assert_eq(boss.state, Boss.State.IDLE)


func test_it_chases_the_player_in_idle() -> void:
	var boss := _boss(_data([_attack(K.SLAM)] as Array[BossAttack], 5.0, 30.0))
	boss._physics_process(0.1)
	assert_almost_eq(boss.global_position.x, 103.0, 0.001)
	assert_almost_eq(boss.global_position.y, 300.0, 0.001)


func test_it_attacks_in_the_phase_order_and_repeats() -> void:
	var boss := _boss(load("res://resources/bosses/ember_titan.tres") as BossData)
	var kinds := []
	boss.attack_started.connect(func(attack: BossAttack): kinds.append(attack.kind))
	_step(boss, 40.0)
	assert_gte(kinds.size(), 6)
	assert_eq(kinds.slice(0, 6), [K.SLAM, K.CHARGE, K.SUMMON, K.SLAM, K.CHARGE, K.SUMMON])


func test_a_slam_places_a_zone_at_the_players_position_at_telegraph_start_and_it_does_not_follow() -> void:
	var boss := _boss(_data([_attack(K.SLAM, 1.0)] as Array[BossAttack]))
	_step(boss, 0.5)
	assert_eq(boss.state, Boss.State.TELEGRAPH)
	assert_eq(_zones().size(), 1)
	var zone := _zones()[0] as BlastZone
	zone.set_process(false)
	assert_eq(zone.global_position, Vector2(400, 300))
	assert_eq(zone.radius, 48.0)
	assert_eq(zone.damage, 30.0)
	assert_eq(zone.fuse_time, 1.0)
	_player.global_position = Vector2(700, 300)
	_step(boss, 0.5)
	zone._process(0.5)
	assert_eq(zone.global_position, Vector2(400, 300))
	_step(boss, 0.6)
	zone._process(0.5)
	assert_true(zone.is_detonated())
	assert_eq(_player.health.current_health, 1.0e9, "the player walked away from the marked spot")


func test_the_slam_is_harmless_until_its_fuse_ends() -> void:
	var boss := _boss(_data([_attack(K.SLAM, 1.0)] as Array[BossAttack]))
	_step(boss, 0.5)
	var zone := _zones()[0] as BlastZone
	zone.set_process(false)
	_step(boss, 0.9)
	zone._process(0.99)
	assert_eq(_player.health.current_health, 1.0e9)
	zone._process(0.02)
	assert_almost_eq(_player.health.current_health, 1.0e9 - 30.0, 0.001)


func test_a_charge_dashes_toward_where_the_player_was_not_where_they_are() -> void:
	var boss := _boss(_data([_attack(K.CHARGE, 0.8)] as Array[BossAttack]))
	_step(boss, 0.5)
	assert_eq(boss.state, Boss.State.TELEGRAPH)
	_player.global_position = Vector2(400, 100)
	_step(boss, 0.8)
	assert_eq(boss.state, Boss.State.ACT)
	_step(boss, 0.6)
	assert_almost_eq(boss.global_position.y, 300.0, 0.001, "the dash line was fixed at the start of the warning")
	assert_almost_eq(boss.global_position.x, 100.0 + 156.0, 0.01)


func test_the_charge_telegraph_is_harmless_and_the_dash_only_hurts_during_the_dash() -> void:
	var boss := _boss(_data([_attack(K.CHARGE, 0.8)] as Array[BossAttack]))
	assert_eq(_hitbox(boss).damage, 5.0)
	_step(boss, 0.5)
	assert_eq(boss.state, Boss.State.TELEGRAPH)
	assert_eq(_hitbox(boss).damage, 5.0, "no extra damage while it is only warning")
	_step(boss, 0.8)
	assert_eq(boss.state, Boss.State.ACT)
	assert_eq(_hitbox(boss).damage, 25.0, "the dash hits hard")
	_step(boss, 0.6)
	assert_eq(boss.state, Boss.State.RECOVER)
	assert_eq(_hitbox(boss).damage, 5.0, "back to contact damage")


func test_a_charge_leaves_a_vulnerability_window_that_ends_on_time() -> void:
	var boss := _boss(_data([_attack(K.CHARGE, 0.8)] as Array[BossAttack]))
	_step(boss, 0.5)
	_step(boss, 0.8)
	_step(boss, 0.6)
	assert_true(boss.vulnerable)
	var before := _health(boss).current_health
	_hit(boss, 10.0)
	assert_almost_eq(before - _health(boss).current_health, 15.0, 0.001, "+50% damage while it is open")
	_step(boss, 1.9)
	assert_true(boss.vulnerable)
	_step(boss, 0.1)
	assert_false(boss.vulnerable)
	before = _health(boss).current_health
	_hit(boss, 10.0)
	assert_almost_eq(before - _health(boss).current_health, 10.0, 0.001)


func test_vulnerability_applies_once_per_hit_and_is_reported_in_damaged() -> void:
	var boss := _boss(_data([_attack(K.CHARGE, 0.8)] as Array[BossAttack]))
	_step(boss, 0.5)
	_step(boss, 0.8)
	_step(boss, 0.6)
	var reported := []
	boss.damaged.connect(func(position: Vector2, amount: float, effect: int): reported.append([position, amount, effect]))
	_hit(boss, 10.0)
	assert_eq(reported.size(), 1)
	assert_almost_eq(reported[0][1], 15.0, 0.001)
	assert_eq(reported[0][0], boss.global_position)


func test_a_burst_fires_twelve_projectiles_evenly_around_the_boss() -> void:
	var boss := _boss(_data([_attack(K.BURST, 0.6)] as Array[BossAttack], 0.5, 0.0, 5.0, 1000.0))
	_step(boss, 0.5)
	assert_eq(_projectiles().size(), 0, "nothing fires during the warning")
	_step(boss, 0.6)
	var shots := _projectiles()
	assert_eq(shots.size(), 12)
	var angles := []
	for shot in shots:
		assert_eq(shot.global_position, boss.global_position)
		assert_eq(shot.hitbox.damage, 12.0)
		shot._physics_process(0.1)
		angles.append((shot.global_position - boss.global_position).angle())
	angles.sort()
	for i in angles.size():
		var next: float = angles[(i + 1) % angles.size()]
		var gap := fposmod(next - angles[i], TAU)
		assert_almost_eq(gap, TAU / 12.0, 0.001)


func test_a_summon_emits_the_request_with_the_archetype_and_count() -> void:
	var boss := _boss(_data([_attack(K.SUMMON, 0.8)] as Array[BossAttack]))
	var requests := []
	boss.summon_requested.connect(func(archetype: EnemyArchetype, count: int): requests.append([archetype, count]))
	_step(boss, 0.5)
	_step(boss, 0.7)
	assert_eq(requests.size(), 0, "not before the warning ends")
	_step(boss, 0.1)
	assert_eq(requests.size(), 1)
	assert_eq(requests[0][0].id, &"swarmer")
	assert_eq(requests[0][1], 4)


func test_phase_two_starts_at_half_health_with_its_speed_and_interval_and_burst() -> void:
	var data := load("res://resources/bosses/ember_titan.tres") as BossData
	var boss := _boss(data)
	watch_signals(boss)
	_hit(boss, 749.0)
	assert_eq(boss.phase, 0)
	_hit(boss, 1.0)
	assert_eq(boss.phase, 1)
	assert_signal_emit_count(boss, "phase_changed", 1)
	assert_signal_emitted_with_parameters(boss, "phase_changed", [1])
	var before := boss.global_position.x
	boss._physics_process(0.1)
	assert_almost_eq(boss.global_position.x - before, 30.0 * 1.3 * 0.1, 0.001)
	var kinds := []
	boss.attack_started.connect(func(attack: BossAttack): kinds.append(attack.kind))
	_step(boss, 40.0)
	assert_true(kinds.has(K.BURST), "phase two adds the burst")
	assert_eq(kinds.slice(0, 4), [K.SLAM, K.CHARGE, K.BURST, K.SUMMON], "its attacks restart from the phase's first")


func test_a_hit_that_skips_a_phase_goes_to_the_last_phase_and_emits_once() -> void:
	var data := _data([_attack(K.SLAM)] as Array[BossAttack])
	var phases: Array[BossPhase] = []
	for threshold in [1.0, 0.6, 0.3]:
		var phase := BossPhase.new()
		phase.health_threshold = threshold
		phase.attacks = [_attack(K.SLAM)] as Array[BossAttack]
		phases.append(phase)
	data.phases = phases
	var boss := _boss(data)
	watch_signals(boss)
	_hit(boss, 800.0)
	assert_eq(boss.phase, 2)
	assert_signal_emit_count(boss, "phase_changed", 1)
	assert_signal_emitted_with_parameters(boss, "phase_changed", [2])
	_hit(boss, 10.0)
	assert_signal_emit_count(boss, "phase_changed", 1)


func test_the_boss_stays_inside_the_arena_even_when_charging_at_a_wall() -> void:
	var boss := _boss(_data([_attack(K.CHARGE, 0.8)] as Array[BossAttack]), Vector2(900, 300))
	_player.global_position = Vector2(950, 300)
	_step(boss, 0.5)
	_step(boss, 0.8)
	_step(boss, 0.6)
	assert_lte(boss.global_position.x, BOUNDS.end.x)
	assert_gte(boss.global_position.x, BOUNDS.position.x)
	assert_almost_eq(boss.global_position.x, 960.0, 0.01)


func test_the_boss_ignores_knockback() -> void:
	var boss := _boss(_data([_attack(K.SLAM)] as Array[BossAttack], 50.0))
	var at := boss.global_position
	_hit(boss, 5.0, 500.0)
	_step(boss, 1.0)
	assert_eq(boss.global_position, at)


func test_the_boss_does_nothing_while_the_player_is_dead_or_missing() -> void:
	var boss := _boss(_data([_attack(K.SLAM)] as Array[BossAttack], 0.5, 30.0))
	var at := boss.global_position
	_player.remove_from_group(&"player")
	var started := []
	boss.attack_started.connect(func(attack: BossAttack): started.append(attack))
	_step(boss, 10.0)
	assert_eq(boss.state, Boss.State.IDLE)
	assert_eq(boss.global_position, at)
	assert_eq(started.size(), 0)


func test_the_boss_does_nothing_when_dead() -> void:
	var boss := _boss(_data([_attack(K.SLAM)] as Array[BossAttack]))
	var started := []
	boss.attack_started.connect(func(attack: BossAttack): started.append(attack))
	_hit(boss, 100000.0)
	assert_true(boss.is_dead())
	_step(boss, 10.0)
	assert_eq(started.size(), 0)


func test_death_emits_died_once_and_cancels_a_pending_slam() -> void:
	var boss := _boss(_data([_attack(K.SLAM, 1.0)] as Array[BossAttack]))
	var died := []
	boss.died.connect(func(b): died.append(b))
	_step(boss, 0.5)
	var zone := _zones()[0] as BlastZone
	zone.set_process(false)
	_hit(boss, 100000.0)
	_hit(boss, 100000.0)
	assert_eq(died.size(), 1)
	assert_true(zone.is_queued_for_deletion(), "the pending slam is cancelled")
	zone._process(5.0)
	assert_eq(_player.health.current_health, 1.0e9)


func test_the_boss_takes_the_element_multiplier_like_any_enemy() -> void:
	var boss := _boss(load("res://resources/bosses/ember_titan.tres") as BossData)
	var before := _health(boss).current_health
	_hit(boss, 10.0, 0.0, SpellData.Element.SEA)
	assert_almost_eq(before - _health(boss).current_health, 15.0, 0.001, "Sea beats Fire")
	var reported := []
	boss.damaged.connect(func(position: Vector2, amount: float, effect: int): reported.append(effect))
	_hit(boss, 10.0, 0.0, SpellData.Element.SEA)
	assert_eq(reported[0], ElementTable.Effect.VULNERABLE)


func test_nothing_advances_without_a_real_step() -> void:
	var boss := _boss(_data([_attack(K.SLAM)] as Array[BossAttack], 0.5, 30.0))
	var at := boss.global_position
	for i in 1000:
		boss._physics_process(0.0)
	assert_eq(boss.state, Boss.State.IDLE)
	assert_eq(boss.global_position, at)


func test_attack_started_is_emitted_when_the_warning_begins() -> void:
	var boss := _boss(_data([_attack(K.SLAM, 1.0)] as Array[BossAttack]))
	watch_signals(boss)
	_step(boss, 0.45)
	assert_signal_not_emitted(boss, "attack_started")
	_step(boss, 0.1)
	assert_signal_emit_count(boss, "attack_started", 1)
	assert_eq(boss.state, Boss.State.TELEGRAPH)


func test_the_vulnerability_does_not_start_after_attacks_without_a_bonus() -> void:
	var boss := _boss(_data([_attack(K.SUMMON, 0.8)] as Array[BossAttack]))
	_step(boss, 0.5)
	_step(boss, 0.9)
	assert_eq(boss.state, Boss.State.RECOVER)
	assert_false(boss.vulnerable)


func test_every_control_in_the_boss_ignores_the_mouse() -> void:
	var boss := _boss(_data([_attack(K.SLAM)] as Array[BossAttack]))
	for child in boss.find_children("*", "Control", true, false):
		assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, str(child.name))


func test_a_lightning_attack_places_count_zones_with_the_attacks_numbers_and_the_first_on_the_player() -> void:
	var boss := _boss(_data([_attack(K.LIGHTNING, 1.0)] as Array[BossAttack]))
	_step(boss, 0.5)
	assert_eq(boss.state, Boss.State.TELEGRAPH)
	var zones := _zones()
	assert_eq(zones.size(), 5)
	assert_eq(boss.lightning_zones().size(), 5)
	var on_player := 0
	for zone in zones:
		zone.set_process(false)
		assert_eq(zone.radius, 28.0)
		assert_eq(zone.damage, 22.0)
		assert_eq(zone.fuse_time, 1.0)
		if zone.global_position == Vector2(400, 300):
			on_player += 1
		assert_lte(zone.global_position.distance_to(Vector2(400, 300)), 70.0 + 0.001)
	assert_eq(on_player, 1, "exactly one strike lands on the player's spot")


func test_lightning_zones_are_harmless_until_their_fuse_ends() -> void:
	var boss := _boss(_data([_attack(K.LIGHTNING, 1.0)] as Array[BossAttack]))
	_step(boss, 0.5)
	for zone in _zones():
		zone.set_process(false)
	for zone in _zones():
		zone._process(0.5)
	assert_eq(_player.health.current_health, 1.0e9, "nothing happens before the fuse ends")
	for zone in _zones():
		zone._process(0.6)
	assert_lt(_player.health.current_health, 1.0e9, "the strike on the player's spot hurt")


func test_lightning_zones_stay_where_they_were_placed_and_do_not_follow() -> void:
	var boss := _boss(_data([_attack(K.LIGHTNING, 1.0)] as Array[BossAttack]))
	_step(boss, 0.5)
	var before: Array[Vector2] = []
	for zone in _zones():
		zone.set_process(false)
		before.append(zone.global_position)
	_player.global_position = Vector2(800, 100)
	_step(boss, 0.3)
	var after: Array[Vector2] = []
	for zone in _zones():
		after.append(zone.global_position)
	assert_eq(after, before)


func test_every_lightning_zone_is_inside_the_arena() -> void:
	_player.global_position = Vector2(5, 5)
	for seed_value in 12:
		_rng.seed = seed_value
		var boss := _boss(_data([_attack(K.LIGHTNING, 1.0)] as Array[BossAttack]), Vector2(500, 300))
		_step(boss, 0.5)
		for zone in _zones():
			zone.set_process(false)
			assert_true(BOUNDS.grow(0.001).has_point(zone.global_position), "%s is inside the arena" % zone.global_position)
		boss.free()
		for zone in _zones():
			zone.free()


func test_a_lightning_attack_ends_in_recover_and_the_next_attack_follows() -> void:
	var boss := _boss(_data([_attack(K.LIGHTNING, 1.0), _attack(K.SLAM, 1.0)] as Array[BossAttack]))
	_step(boss, 0.5)
	assert_eq(boss.state, Boss.State.TELEGRAPH)
	for zone in _zones():
		zone.set_process(false)
	_step(boss, 1.0)
	assert_eq(boss.state, Boss.State.RECOVER)
	_step(boss, 0.4)
	assert_eq(boss.state, Boss.State.IDLE)
	_step(boss, 0.6)
	assert_eq(boss.state, Boss.State.TELEGRAPH, "the next attack (the slam) began")


func test_a_boss_that_dies_cancels_every_pending_lightning_zone() -> void:
	var boss := _boss(_data([_attack(K.LIGHTNING, 1.0)] as Array[BossAttack]))
	_step(boss, 0.5)
	var zones := _zones()
	for zone in zones:
		zone.set_process(false)
	_hit(boss, 100000.0)
	for zone in zones:
		assert_true(zone.is_queued_for_deletion(), "a pending strike is cancelled")
	assert_eq(boss.lightning_zones().size(), 0)


func test_lightning_respects_the_blast_zone_cap() -> void:
	for i in 38:
		BlastZone.place(_root, preload("res://scenes/enemies/blast_zone.tscn"), Vector2(50 + i * 4, 50), 10.0, 1.0, 30.0)
	var attack := _attack(K.LIGHTNING, 1.0)
	attack.count = 7
	var big := _boss(_data([attack] as Array[BossAttack]))
	_step(big, 0.5)
	assert_lte(_zones().size(), BlastZone.MAX_ALIVE, "the group never exceeds the cap")


func test_lightning_scales_damage_by_the_boss_number() -> void:
	var curve := DifficultyCurve.default_curve()
	var boss := _boss(_data([_attack(K.LIGHTNING, 1.0)] as Array[BossAttack]), Vector2(100, 300), 3, curve)
	_step(boss, 0.5)
	var expected := 22.0 * curve.boss_damage_scale(3)
	for zone in _zones():
		assert_almost_eq(zone.damage, expected, 0.001)


func test_lightning_zones_freeze_while_paused() -> void:
	var boss := _boss(_data([_attack(K.LIGHTNING, 1.0)] as Array[BossAttack]))
	_step(boss, 0.5)
	for zone in _zones():
		assert_ne(zone.process_mode, Node.PROCESS_MODE_ALWAYS, "a strike's fuse is counted in a pausable _process")


func test_a_boss_can_use_lightning_in_every_phase() -> void:
	var first := BossPhase.new()
	first.health_threshold = 1.0
	first.attacks = [_attack(K.LIGHTNING, 0.6)] as Array[BossAttack]
	first.attack_interval = 0.3
	var second := BossPhase.new()
	second.health_threshold = 0.5
	second.attacks = [_attack(K.LIGHTNING, 0.6)] as Array[BossAttack]
	second.attack_interval = 0.3
	var data := _data([] as Array[BossAttack])
	data.phases = [first, second] as Array[BossPhase]
	var boss := _boss(data)
	_step(boss, 3.0)
	_hit(boss, 600.0)
	_step(boss, 3.0)
	assert_eq(boss.phase, 1)
	assert_gt(_zones().size(), 0)


## A charge that chains: `repeats` extra dashes, each warned for `warning` seconds (the first for `telegraph`).
func _chain(repeats: int, telegraph: float = 0.8, warning: float = 0.6) -> BossAttack:
	var attack := _attack(K.CHARGE, telegraph)
	attack.repeats = repeats
	attack.chain_warning = warning
	return attack


## Steps until the state is `wanted`, up to `limit` seconds; true when it got there.
func _until(boss: Boss, wanted: Boss.State, limit: float = 5.0) -> bool:
	for i in roundi(limit / STEP):
		if boss.state == wanted:
			return true
		boss._physics_process(STEP)
	return boss.state == wanted


func test_a_chained_charge_dashes_repeats_plus_one_times() -> void:
	var boss := _boss(_data([_chain(2)] as Array[BossAttack]))
	var dashes := 0
	var was_acting := false
	for i in roundi(6.0 / STEP):
		boss._physics_process(STEP)
		var acting := boss.state == Boss.State.ACT
		if acting and not was_acting:
			dashes += 1
		was_acting = acting
		if boss.state == Boss.State.RECOVER:
			break
	assert_eq(dashes, 3, "repeats 2 means three dashes")
	assert_eq(boss.state, Boss.State.RECOVER)


func test_each_chained_dash_is_warned_and_shows_the_dash_marks() -> void:
	var boss := _boss(_data([_chain(1)] as Array[BossAttack]))
	assert_true(_until(boss, Boss.State.ACT))
	assert_true(_until(boss, Boss.State.TELEGRAPH), "after the first dash it warns again")
	assert_gt(boss.charge_marks().size(), 0, "with the dash-line marks")
	var at := boss.global_position
	_step(boss, 0.5)
	assert_eq(boss.state, Boss.State.TELEGRAPH, "the chain warning is 0.6 s")
	assert_eq(boss.global_position, at, "it does not move while it warns")
	_step(boss, 0.15)
	assert_eq(boss.state, Boss.State.ACT)


func test_each_chained_dash_re_aims_at_the_players_new_position() -> void:
	var boss := _boss(_data([_chain(1)] as Array[BossAttack]))
	assert_true(_until(boss, Boss.State.ACT))
	# The player moves during the first dash; the next dash is aimed when its own warning begins, at the spot they are on then.
	_player.global_position = Vector2(256, 100)
	assert_true(_until(boss, Boss.State.TELEGRAPH))
	var start := boss.global_position
	assert_true(_until(boss, Boss.State.ACT))
	_step(boss, 0.6)
	assert_lt(absf(boss.global_position.x - start.x), 120.0, "the second dash did not continue along the first line")
	assert_lt(boss.global_position.y, start.y - 60.0, "it turned toward the player's new spot")


func test_contact_damage_applies_only_during_a_dash_in_a_chain() -> void:
	var boss := _boss(_data([_chain(1)] as Array[BossAttack]))
	assert_eq(_hitbox(boss).damage, 5.0)
	assert_true(_until(boss, Boss.State.ACT))
	assert_eq(_hitbox(boss).damage, 25.0, "the first dash hits hard")
	assert_true(_until(boss, Boss.State.TELEGRAPH))
	assert_eq(_hitbox(boss).damage, 5.0, "only contact damage while it warns between dashes")
	assert_true(_until(boss, Boss.State.ACT))
	assert_eq(_hitbox(boss).damage, 25.0, "the second dash hits hard")
	assert_true(_until(boss, Boss.State.RECOVER))
	assert_eq(_hitbox(boss).damage, 5.0)


func test_the_vulnerability_window_starts_after_the_last_dash_only() -> void:
	var boss := _boss(_data([_chain(1)] as Array[BossAttack]))
	assert_true(_until(boss, Boss.State.ACT))
	assert_true(_until(boss, Boss.State.TELEGRAPH))
	assert_false(boss.vulnerable, "not open between dashes")
	assert_true(_until(boss, Boss.State.ACT))
	assert_false(boss.vulnerable)
	assert_true(_until(boss, Boss.State.RECOVER))
	assert_true(boss.vulnerable, "open after the last dash")
	_step(boss, 1.9)
	assert_true(boss.vulnerable)
	_step(boss, 0.2)
	assert_false(boss.vulnerable, "for recover_time")


func test_a_wall_ends_the_chain_at_once_and_opens_the_boss() -> void:
	var data := MapData.new()
	data.id = &"wall_test"
	data.size = Vector2(960, 540)
	data.player_start = Vector2(8, 8)
	var wall := MapObstacle.new()
	wall.kind = MapObstacle.Kind.RECT
	wall.position = Vector2(190, 300)
	wall.size = Vector2(16, 200)
	data.obstacles = [wall] as Array[MapObstacle]
	var map := ObstacleMap.new()
	map.cells_per_frame = 100000
	_root.add_child(map)
	map.setup(data)
	var boss := _boss(_data([_chain(2)] as Array[BossAttack]))
	assert_true(_until(boss, Boss.State.ACT))
	assert_true(_until(boss, Boss.State.RECOVER), "the dash hit the wall")
	assert_true(boss.vulnerable, "the crash opens it")
	var seen_warning := false
	for i in roundi(1.0 / STEP):
		boss._physics_process(STEP)
		if boss.state == Boss.State.TELEGRAPH:
			seen_warning = true
	assert_false(seen_warning, "no further dash of the chain follows a crash")


func test_attack_started_is_emitted_once_per_chained_attack() -> void:
	var boss := _boss(_data([_chain(2)] as Array[BossAttack]))
	var started := []
	boss.attack_started.connect(func(a: BossAttack) -> void: started.append(a))
	assert_true(_until(boss, Boss.State.RECOVER))
	assert_eq(started.size(), 1)


func test_a_boss_killed_mid_chain_clears_its_marks_and_stops() -> void:
	var boss := _boss(_data([_chain(2)] as Array[BossAttack]))
	assert_true(_until(boss, Boss.State.ACT))
	assert_true(_until(boss, Boss.State.TELEGRAPH))
	assert_gt(boss.charge_marks().size(), 0)
	_hit(boss, 100000.0)
	assert_eq(boss.charge_marks().size(), 0, "the warning marks are gone")
	var state := boss.state
	var at := boss.global_position
	_step(boss, 2.0)
	assert_eq(boss.state, state, "a dead boss goes no further")
	assert_eq(boss.global_position, at)


func test_a_charge_with_no_repeats_is_exactly_the_old_charge() -> void:
	var boss := _boss(_data([_chain(0)] as Array[BossAttack]))
	_step(boss, 0.5)
	assert_eq(boss.state, Boss.State.TELEGRAPH)
	_step(boss, 0.8)
	assert_eq(boss.state, Boss.State.ACT)
	_step(boss, 0.6)
	assert_eq(boss.state, Boss.State.RECOVER, "no second warning")
	assert_true(boss.vulnerable)
	assert_almost_eq(boss.global_position.x, 100.0 + 156.0, 0.01)


func test_a_chain_does_nothing_without_a_real_step() -> void:
	var boss := _boss(_data([_chain(2)] as Array[BossAttack]))
	assert_true(_until(boss, Boss.State.ACT))
	var state := boss.state
	var at := boss.global_position
	get_tree().paused = true
	await wait_process_frames(2)
	get_tree().paused = false
	assert_eq(boss.state, state, "the chain moves only on physics steps")
	assert_eq(boss.global_position, at)
