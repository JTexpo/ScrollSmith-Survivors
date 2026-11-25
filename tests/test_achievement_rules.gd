extends GutTest
## When an achievement is met: pure rules over a few facts.


func _data(kind: AchievementData.Kind, threshold: int = 0, boss_id: StringName = &"") -> AchievementData:
	var data := AchievementData.new()
	data.id = &"x"
	data.kind = kind
	data.threshold = threshold
	data.boss_id = boss_id
	return data


func _facts(level: int = 1, gold: int = 0, seconds: float = 0.0, boss_id: StringName = &"") -> AchievementFacts:
	var facts := AchievementFacts.new()
	facts.level = level
	facts.lifetime_gold = gold
	facts.seconds = seconds
	facts.boss_id = boss_id
	return facts


func test_a_level_is_met_at_its_threshold_and_not_one_below() -> void:
	var data := _data(AchievementData.Kind.LEVEL, 10)
	assert_false(AchievementRules.is_met(data, _facts(9)))
	assert_true(AchievementRules.is_met(data, _facts(10)))
	assert_true(AchievementRules.is_met(data, _facts(20)))


func test_lifetime_gold_is_met_at_its_threshold_and_not_one_below() -> void:
	var data := _data(AchievementData.Kind.GOLD_TOTAL, 1000)
	assert_false(AchievementRules.is_met(data, _facts(1, 999)))
	assert_true(AchievementRules.is_met(data, _facts(1, 1000)))


func test_survival_is_met_at_its_threshold_and_not_one_second_below() -> void:
	var data := _data(AchievementData.Kind.SURVIVE_SECONDS, 300)
	assert_false(AchievementRules.is_met(data, _facts(1, 0, 299.9)))
	assert_true(AchievementRules.is_met(data, _facts(1, 0, 300.0)))


func test_a_boss_is_met_only_for_its_own_id_and_never_for_an_empty_id() -> void:
	var data := _data(AchievementData.Kind.BOSS, 0, &"tempest_dragon")
	assert_true(AchievementRules.is_met(data, _facts(1, 0, 0.0, &"tempest_dragon")))
	assert_false(AchievementRules.is_met(data, _facts(1, 0, 0.0, &"ember_titan")))
	assert_false(AchievementRules.is_met(data, _facts(20, 5000, 2000.0)), "no boss, however far the player got")
	var blank := _data(AchievementData.Kind.BOSS, 0, &"")
	assert_false(AchievementRules.is_met(blank, _facts()), "a boss achievement with no boss id is never met by nothing")


func test_other_facts_do_not_meet_the_wrong_kind() -> void:
	assert_false(AchievementRules.is_met(_data(AchievementData.Kind.LEVEL, 5), _facts(1, 9999, 9999.0, &"tempest_dragon")))
	assert_false(AchievementRules.is_met(_data(AchievementData.Kind.SURVIVE_SECONDS, 300), _facts(20, 9999, 0.0)))
