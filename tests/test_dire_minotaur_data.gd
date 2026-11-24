extends GutTest
## The Dire Minotaur: the maze's Land boss. The Titan's weight (health, rewards, size) with its own pattern: charges that chain into a stampede
## (more dashes each phase), and every chained dash can be sidestepped at the player's base speed.

const K := BossAttack.Kind
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const BOSS_SCENE := "res://scenes/enemies/boss.tscn"
const REACTION_SECONDS := 0.25

var _boss: BossData
var _titan: BossData


func before_each() -> void:
	_boss = load("res://resources/bosses/dire_minotaur.tres") as BossData
	_titan = load("res://resources/bosses/ember_titan.tres") as BossData


func _attacks(phase: int, kind: BossAttack.Kind) -> Array[BossAttack]:
	var found: Array[BossAttack] = []
	for attack in _boss.phases[phase].attacks:
		if attack.kind == kind:
			found.append(attack)
	return found


func test_the_minotaur_matches_the_spec() -> void:
	assert_eq(_boss.id, &"dire_minotaur")
	assert_eq(_boss.display_name, "Dire Minotaur")
	assert_eq(_boss.max_health, 1500.0)
	assert_eq(_boss.contact_damage, 20.0)
	assert_eq(_boss.speed, 32.0)
	assert_eq(_boss.body_scale, 3.0)


func test_it_has_the_titans_health_rewards_and_table() -> void:
	assert_eq(_boss.max_health, _titan.max_health)
	assert_eq(_boss.contact_damage, _titan.contact_damage)
	assert_eq(_boss.body_scale, _titan.body_scale)
	assert_eq(_boss.reward_xp, _titan.reward_xp)
	assert_eq(_boss.reward_gold, _titan.reward_gold)
	assert_eq(_boss.reward_scroll_count, _titan.reward_scroll_count)
	assert_eq(_boss.reward_drop_table, _titan.reward_drop_table)


func test_it_is_land() -> void:
	assert_eq(_boss.element, 2)


func test_three_phases_fall_in_threshold_order_and_speed_up() -> void:
	assert_eq(_boss.phases.size(), 3)
	assert_eq([_boss.phases[0].health_threshold, _boss.phases[1].health_threshold, _boss.phases[2].health_threshold], [1.0, 0.6, 0.25])
	for i in 2:
		assert_lt(_boss.phases[i + 1].attack_interval, _boss.phases[i].attack_interval, "each phase attacks sooner")
		assert_gt(_boss.phases[i + 1].speed_multiplier, _boss.phases[i].speed_multiplier, "each phase moves faster")


func test_every_phase_has_attacks_and_every_attack_has_a_warning() -> void:
	for phase in _boss.phases:
		assert_false(phase.attacks.is_empty())
		assert_gt(phase.attack_interval, 0.0)
		for attack in phase.attacks:
			assert_gte(attack.telegraph_time, 0.6, "every attack has a warning of at least 0.6 s")
			if attack.kind == K.CHARGE:
				assert_gte(attack.chain_warning, 0.6, "and every chained dash too")


func test_every_phase_has_a_chained_charge_and_the_chains_do_not_shrink() -> void:
	var repeats: Array[int] = []
	for phase in 3:
		var charges := _attacks(phase, K.CHARGE)
		assert_eq(charges.size(), 1, "phase %d has a charge" % phase)
		repeats.append(charges[0].repeats)
	assert_eq(repeats, [1, 2, 2] as Array[int])


func test_every_chained_charge_can_be_sidestepped_at_the_players_base_speed() -> void:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate()
	var speed: float = (player.get_node("MoveComponent") as Node).speed
	player.free()
	assert_eq(speed, 90.0)
	var boss := (load(BOSS_SCENE) as PackedScene).instantiate()
	var shape := (boss.get_node("ContactHitbox/CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var half_width := shape.size.x * _boss.body_scale / 2.0
	boss.free()
	var needed := half_width + 6.0
	assert_eq(half_width, 18.0)
	for phase in _boss.phases.size():
		for attack in _attacks(phase, K.CHARGE):
			if attack.repeats > 0:
				assert_gte((attack.chain_warning - REACTION_SECONDS) * speed, needed, "phase %d: a player can leave the dash line after reacting" % phase)


func test_the_summon_uses_swarmers() -> void:
	var summons := _attacks(0, K.SUMMON)
	assert_eq(summons.size(), 1)
	assert_eq(summons[0].summon_archetype.id, &"swarmer")


func test_a_hit_that_skips_a_phase_lands_in_the_last_one() -> void:
	assert_eq(_boss.phase_index(0.9), 0)
	assert_eq(_boss.phase_index(0.5), 1)
	assert_eq(_boss.phase_index(0.2), 2)
	assert_eq(_boss.phase_index(0.01), 2)
