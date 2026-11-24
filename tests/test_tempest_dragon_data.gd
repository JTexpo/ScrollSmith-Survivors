extends GutTest
## The Tempest Dragon: the forest's Thunder boss. It has the Ember Titan's weight (health, rewards, size) but its own pattern: lightning
## strikes in every phase, three phases, and every strike can be outrun at the player's base speed.

const K := BossAttack.Kind
const PLAYER_SCENE := "res://scenes/player/player.tscn"

var _dragon: BossData
var _titan: BossData


func before_each() -> void:
	_dragon = load("res://resources/bosses/tempest_dragon.tres") as BossData
	_titan = load("res://resources/bosses/ember_titan.tres") as BossData


func _attacks(phase: int, kind: BossAttack.Kind) -> Array[BossAttack]:
	var found: Array[BossAttack] = []
	for attack in _dragon.phases[phase].attacks:
		if attack.kind == kind:
			found.append(attack)
	return found


func test_the_dragon_matches_the_spec() -> void:
	assert_eq(_dragon.id, &"tempest_dragon")
	assert_eq(_dragon.display_name, "Tempest Dragon")
	assert_eq(_dragon.max_health, 1500.0)
	assert_eq(_dragon.contact_damage, 20.0)
	assert_eq(_dragon.speed, 36.0)
	assert_eq(_dragon.body_scale, 3.0)


func test_it_has_the_titans_health_rewards_and_table() -> void:
	assert_eq(_dragon.max_health, _titan.max_health)
	assert_eq(_dragon.contact_damage, _titan.contact_damage)
	assert_eq(_dragon.body_scale, _titan.body_scale)
	assert_eq(_dragon.reward_xp, _titan.reward_xp)
	assert_eq(_dragon.reward_gold, _titan.reward_gold)
	assert_eq(_dragon.reward_scroll_count, _titan.reward_scroll_count)
	assert_eq(_dragon.reward_drop_table, _titan.reward_drop_table)


func test_it_is_thunder() -> void:
	assert_eq(_dragon.element, 1)


func test_three_phases_fall_in_threshold_order_and_speed_up() -> void:
	assert_eq(_dragon.phases.size(), 3)
	assert_eq([_dragon.phases[0].health_threshold, _dragon.phases[1].health_threshold, _dragon.phases[2].health_threshold], [1.0, 0.6, 0.25])
	for i in 2:
		assert_lt(_dragon.phases[i + 1].attack_interval, _dragon.phases[i].attack_interval, "each phase attacks sooner")
		assert_gt(_dragon.phases[i + 1].speed_multiplier, _dragon.phases[i].speed_multiplier, "each phase moves faster")


func test_every_phase_has_attacks_and_every_attack_has_a_warning() -> void:
	for phase in _dragon.phases:
		assert_false(phase.attacks.is_empty())
		assert_gt(phase.attack_interval, 0.0)
		for attack in phase.attacks:
			assert_gte(attack.telegraph_time, 0.6, "every attack has a warning of at least 0.6 s")


func test_each_phase_has_a_lightning_attack_and_the_strikes_grow() -> void:
	var counts: Array[int] = []
	for phase in 3:
		var strikes := _attacks(phase, K.LIGHTNING)
		assert_eq(strikes.size(), 1, "phase %d has a lightning attack" % phase)
		counts.append(strikes[0].count)
	assert_eq(counts, [3, 5, 7] as Array[int])


func test_every_lightning_attack_can_be_outrun_at_the_players_base_speed() -> void:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate()
	var speed: float = (player.get_node("MoveComponent") as Node).speed
	player.free()
	assert_eq(speed, 90.0)
	for phase in _dragon.phases.size():
		for attack in _attacks(phase, K.LIGHTNING):
			assert_gt(attack.escape_margin(speed), 0.0, "phase %d: a player running straight away leaves every strike before it lands" % phase)


func test_the_summon_uses_swarmers() -> void:
	var summons := _attacks(0, K.SUMMON)
	assert_eq(summons.size(), 1)
	assert_eq(summons[0].summon_archetype.id, &"swarmer")


func test_a_hit_that_skips_a_phase_lands_in_the_last_one() -> void:
	assert_eq(_dragon.phase_index(0.9), 0)
	assert_eq(_dragon.phase_index(0.5), 1)
	assert_eq(_dragon.phase_index(0.2), 2)
	assert_eq(_dragon.phase_index(0.01), 2, "a hit that skips straight to nearly dead lands in the last phase")
