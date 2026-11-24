extends GutTest

const K := BossAttack.Kind

var _boss: BossData


func before_each() -> void:
	_boss = load("res://resources/bosses/ember_titan.tres") as BossData


func _attack(phase: int, kind: BossAttack.Kind) -> BossAttack:
	for attack in _boss.phases[phase].attacks:
		if attack.kind == kind:
			return attack
	return null


func test_ember_titan_matches_the_spec() -> void:
	assert_eq(_boss.id, &"ember_titan")
	assert_eq(_boss.display_name, "Ember Titan")
	assert_eq(_boss.element, SpellData.Element.FIRE)
	assert_eq(_boss.max_health, 1500.0)
	assert_eq(_boss.contact_damage, 20.0)
	assert_eq(_boss.speed, 30.0)
	assert_eq(_boss.body_scale, 3.0)
	assert_eq(_boss.reward_xp, 300)
	assert_eq(_boss.reward_gold, 150)
	assert_eq(_boss.reward_scroll_count, 2)
	assert_not_null(_boss.reward_drop_table)
	assert_eq(_boss.phases.size(), 2)


func test_phase_one_numbers_and_attack_order() -> void:
	var phase := _boss.phases[0]
	assert_eq(phase.health_threshold, 1.0)
	assert_eq(phase.attack_interval, 2.5)
	assert_eq(phase.speed_multiplier, 1.0)
	var kinds := []
	for attack in phase.attacks:
		kinds.append(attack.kind)
	assert_eq(kinds, [K.SLAM, K.CHARGE, K.SUMMON])


func test_phase_two_numbers_and_attack_order() -> void:
	var phase := _boss.phases[1]
	assert_eq(phase.health_threshold, 0.5)
	assert_eq(phase.attack_interval, 1.8)
	assert_eq(phase.speed_multiplier, 1.3)
	var kinds := []
	for attack in phase.attacks:
		kinds.append(attack.kind)
	assert_eq(kinds, [K.SLAM, K.CHARGE, K.BURST, K.SUMMON])


func test_attack_numbers() -> void:
	for phase in 2:
		var slam := _attack(phase, K.SLAM)
		assert_eq(slam.telegraph_time, 1.0)
		assert_eq(slam.radius, 48.0)
		assert_eq(slam.damage, 30.0)
		var charge := _attack(phase, K.CHARGE)
		assert_eq(charge.telegraph_time, 0.8)
		assert_eq(charge.dash_speed, 260.0)
		assert_eq(charge.dash_time, 0.6)
		assert_eq(charge.damage, 25.0)
		assert_eq(charge.recover_time, 2.0)
		assert_eq(charge.vulnerability_bonus, 0.5)
		var summon := _attack(phase, K.SUMMON)
		assert_eq(summon.telegraph_time, 0.8)
		assert_eq(summon.count, 4)
	var burst := _attack(1, K.BURST)
	assert_eq(burst.telegraph_time, 0.6)
	assert_eq(burst.count, 12)
	assert_eq(burst.projectile_speed, 100.0)
	assert_eq(burst.damage, 12.0)
	assert_eq(burst.projectile_range, 260.0)


func test_summon_uses_swarmers() -> void:
	for phase in 2:
		assert_eq(_attack(phase, K.SUMMON).summon_archetype.id, &"swarmer")


func test_phase_thresholds_fall() -> void:
	for i in range(1, _boss.phases.size()):
		assert_lt(_boss.phases[i].health_threshold, _boss.phases[i - 1].health_threshold)


func test_every_phase_has_attacks_and_a_positive_interval() -> void:
	for phase in _boss.phases:
		assert_gt(phase.attacks.size(), 0)
		assert_gt(phase.attack_interval, 0.0)
		assert_gt(phase.speed_multiplier, 0.0)


func test_every_attack_has_a_warning() -> void:
	for phase in _boss.phases:
		for attack in phase.attacks:
			assert_gt(attack.telegraph_time, 0.0, "a telegraph keeps every attack avoidable")


func test_phase_index_at_the_edges() -> void:
	assert_eq(_boss.phase_index(1.0), 0)
	assert_eq(_boss.phase_index(0.51), 0)
	assert_eq(_boss.phase_index(0.5), 1)
	assert_eq(_boss.phase_index(0.01), 1)
	assert_eq(_boss.phase_index(0.0), 1)
	assert_eq(_boss.phase_index(-5.0), 1)
	assert_eq(_boss.phase_index(3.0), 0)


func test_a_hit_that_skips_a_phase_lands_in_the_last_one() -> void:
	var boss := BossData.new()
	var thresholds := [1.0, 0.6, 0.3]
	var phases: Array[BossPhase] = []
	for threshold in thresholds:
		var phase := BossPhase.new()
		phase.health_threshold = threshold
		phases.append(phase)
	boss.phases = phases
	assert_eq(boss.phase_index(0.2), 2)
	assert_eq(boss.phase_index(0.45), 1)
	assert_eq(boss.phase_index(0.9), 0)


func test_phase_index_with_no_phases_is_zero() -> void:
	assert_eq(BossData.new().phase_index(0.5), 0)


func test_phase_two_is_faster_and_attacks_sooner() -> void:
	assert_gt(_boss.phases[1].speed_multiplier, _boss.phases[0].speed_multiplier)
	assert_lt(_boss.phases[1].attack_interval, _boss.phases[0].attack_interval)


func test_boss_scroll_table_holds_only_rare_scrolls_and_always_drops() -> void:
	var table := _boss.reward_drop_table
	assert_eq(table.drop_chance, 1.0)
	assert_eq(table.entries.size(), 4)
	for entry in table.entries:
		assert_eq(entry.scroll.rarity, ScrollData.Rarity.RARE, str(entry.scroll.id))
		assert_eq(entry.weight, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 50:
		assert_not_null(table.roll(rng))


func test_lightning_is_a_new_attack_kind_after_summon() -> void:
	assert_eq(int(K.LIGHTNING), int(K.SUMMON) + 1)


func test_escape_margin_is_the_distance_run_minus_the_danger() -> void:
	var attack := BossAttack.new()
	attack.kind = K.LIGHTNING
	attack.telegraph_time = 1.0
	attack.spread = 60.0
	attack.radius = 28.0
	assert_almost_eq(attack.escape_margin(90.0), 2.0, 0.0001)
	attack.telegraph_time = 0.5
	assert_lt(attack.escape_margin(90.0), 0.0, "too short a warning is not escapable")
	assert_eq(BossAttack.new().spread, 80.0, "the default spread")


func test_a_charge_has_no_repeats_by_default() -> void:
	var attack := BossAttack.new()
	attack.kind = K.CHARGE
	assert_eq(attack.repeats, 0)
	assert_eq(attack.chain_warning, 0.6)
	assert_eq(attack.dash_count(), 1)


func test_dash_count_is_one_plus_the_repeats_and_never_below_one() -> void:
	var attack := BossAttack.new()
	attack.repeats = 2
	assert_eq(attack.dash_count(), 3)
	attack.repeats = -4
	assert_eq(attack.dash_count(), 1)


func test_the_titan_and_the_dragon_never_chain() -> void:
	for path in ["res://resources/bosses/ember_titan.tres", "res://resources/bosses/tempest_dragon.tres"]:
		for phase in (load(path) as BossData).phases:
			for attack in phase.attacks:
				if attack.kind == K.CHARGE:
					assert_eq(attack.repeats, 0, "%s: a plain charge" % path)
