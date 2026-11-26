extends GutTest
## The twelve achievements and the catalog that lists them. Adding one is a new `.tres` and a catalog entry, with no code.

const EXPECTED := [
	["defeat_tempest_dragon", AchievementData.Kind.BOSS, 0, &"tempest_dragon"],
	["defeat_ember_titan", AchievementData.Kind.BOSS, 0, &"ember_titan"],
	["defeat_dire_minotaur", AchievementData.Kind.BOSS, 0, &"dire_minotaur"],
	["reach_level_5", AchievementData.Kind.LEVEL, 5, &""],
	["reach_level_10", AchievementData.Kind.LEVEL, 10, &""],
	["reach_level_15", AchievementData.Kind.LEVEL, 15, &""],
	["reach_level_20", AchievementData.Kind.LEVEL, 20, &""],
	["earn_gold_1000", AchievementData.Kind.GOLD_TOTAL, 1000, &""],
	["survive_5_minutes", AchievementData.Kind.SURVIVE_SECONDS, 300, &""],
	["survive_10_minutes", AchievementData.Kind.SURVIVE_SECONDS, 600, &""],
	["survive_15_minutes", AchievementData.Kind.SURVIVE_SECONDS, 900, &""],
	["survive_20_minutes", AchievementData.Kind.SURVIVE_SECONDS, 1200, &""],
]

var _catalog: AchievementCatalog
var _track: LevelTrack


func before_each() -> void:
	_catalog = AchievementCatalog.default_catalog()
	_track = load("res://resources/progression/level_track.tres") as LevelTrack


func _entry(kind: AchievementData.Kind = AchievementData.Kind.LEVEL) -> AchievementData:
	var data := AchievementData.new()
	data.id = &"throwaway"
	data.display_name = "Throwaway"
	data.description = "reach level 3"
	data.kind = kind
	data.threshold = 3
	data.icon = &"icon_ach_star"
	return data


func test_the_shipped_catalog_has_twelve_valid_achievements() -> void:
	assert_not_null(_catalog)
	assert_eq(_catalog.problems(), PackedStringArray(), str(_catalog.problems()))
	assert_eq(_catalog.achievements.size(), 12)
	for i in EXPECTED.size():
		var data := _catalog.achievements[i]
		assert_eq(data.id, StringName(EXPECTED[i][0]), "entry %d id" % i)
		assert_eq(data.kind, EXPECTED[i][1], "%s kind" % data.id)
		assert_eq(data.threshold, EXPECTED[i][2], "%s threshold" % data.id)
		assert_eq(data.boss_id, EXPECTED[i][3], "%s boss" % data.id)


func test_ids_and_names_are_unique_and_found_by_id() -> void:
	var names := {}
	for data in _catalog.achievements:
		assert_false(names.has(data.display_name), "%s is used twice" % data.display_name)
		names[data.display_name] = true
		assert_eq(_catalog.find(data.id), data)
	assert_null(_catalog.find(&"nothing_like_this"))
	assert_eq(_catalog.ids().size(), 12)


func test_every_boss_id_names_a_real_boss() -> void:
	var boss_ids := {}
	for file in DirAccess.get_files_at("res://resources/bosses"):
		if file.ends_with(".tres"):
			var boss := load("res://resources/bosses/%s" % file) as BossData
			if boss != null:
				boss_ids[boss.id] = true
	for data in _catalog.achievements:
		if data.kind == AchievementData.Kind.BOSS:
			assert_true(boss_ids.has(data.boss_id), "%s names no boss" % data.id)


func test_boss_rewards_use_slots_three_to_five_once_each() -> void:
	var expected := {&"defeat_tempest_dragon": [3, &"thunder_zone"], &"defeat_ember_titan": [4, &"ember_wave"], &"defeat_dire_minotaur": [5, &"land_line"]}
	var rewarded := 0
	for data in _catalog.achievements:
		if expected.has(data.id):
			assert_true(data.has_reward(), String(data.id))
			assert_eq(data.reward_slot, expected[data.id][0])
			assert_eq(data.reward_spell.id, expected[data.id][1])
		else:
			assert_false(data.has_reward(), "%s is a badge only" % data.id)
		if data.has_reward():
			rewarded += 1
	assert_eq(rewarded, 3)


func test_every_boss_slot_unlocks_at_the_level_the_text_says() -> void:
	var dragon := _catalog.find(&"defeat_tempest_dragon")
	assert_eq(dragon.reward_text(_track), "Reward: Thunder Zone in slot 3 (level 10)")
	assert_eq(_catalog.find(&"defeat_ember_titan").reward_text(_track), "Reward: Ember Wave in slot 4 (level 15)")
	assert_eq(_catalog.find(&"defeat_dire_minotaur").reward_text(_track), "Reward: Land Line in slot 5 (level 20)")
	assert_eq(_catalog.find(&"reach_level_5").reward_text(_track), "")


func test_text_helpers() -> void:
	var dragon := _catalog.find(&"defeat_tempest_dragon")
	assert_eq(dragon.toast_text(), "Achievement unlocked: defeat the Tempest Dragon")
	assert_eq(dragon.goal_text(), "Defeat the Tempest Dragon")
	assert_eq(_catalog.find(&"survive_10_minutes").toast_text(), "Achievement unlocked: survive 10 minutes")
	assert_eq(_catalog.find(&"earn_gold_1000").goal_text(), "Earn 1000 Gold")


func test_problems_catch_each_kind_of_fault() -> void:
	assert_eq(_entry().problems(), PackedStringArray(), "a good entry has none")
	var no_id := _entry()
	no_id.id = &""
	assert_gt(no_id.problems().size(), 0, "empty id")
	var no_threshold := _entry()
	no_threshold.threshold = 0
	assert_gt(no_threshold.problems().size(), 0, "a level at 0")
	var no_boss := _entry(AchievementData.Kind.BOSS)
	assert_gt(no_boss.problems().size(), 0, "a boss entry with no boss id")
	var no_icon := _entry()
	no_icon.icon = &""
	assert_gt(no_icon.problems().size(), 0, "no icon")
	var bad_slot := _entry()
	bad_slot.reward_spell = load("res://resources/spells/thunder_zone.tres") as SpellData
	bad_slot.reward_slot = 2
	assert_gt(bad_slot.problems().size(), 0, "a reward slot outside 3 to 5")
	var no_slot := _entry()
	no_slot.reward_spell = load("res://resources/spells/thunder_zone.tres") as SpellData
	assert_gt(no_slot.problems().size(), 0, "a reward spell with no slot")
	var uncastable := SpellData.new()
	uncastable.mana_cost = 10.0
	uncastable.max_mana = 1.0
	var bad_spell := _entry()
	bad_spell.reward_spell = uncastable
	bad_spell.reward_slot = 3
	assert_gt(bad_spell.problems().size(), 0, "a spell that can never cast")


func test_the_catalog_reports_duplicates_and_reused_slots() -> void:
	var first := _entry()
	var second := _entry()
	var catalog := AchievementCatalog.new()
	catalog.achievements = [first, second] as Array[AchievementData]
	assert_gt(catalog.problems().size(), 0, "a duplicate id")
	second.id = &"another"
	first.reward_spell = load("res://resources/spells/thunder_zone.tres") as SpellData
	first.reward_slot = 3
	second.reward_spell = load("res://resources/spells/ember_wave.tres") as SpellData
	second.reward_slot = 3
	assert_gt(catalog.problems().size(), 0, "a reward slot used twice")
