extends GutTest
## A boss achievement's spell fills its own slot at run start, only when that slot is unlocked and empty, with no starting buffs.

var _root: Node2D
var _player: Player
var _track: LevelTrack
var _profile: PlayerProfile
var _catalog: AchievementCatalog


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_track = LevelTrack.default_track()
	_profile = PlayerProfile.new()
	_catalog = AchievementCatalog.default_catalog()


func _unlock_slots_for(level: int) -> void:
	_player.loadout.set_unlocked_slots(_track.slot_count(level))


func _spell_id(slot: int) -> StringName:
	var instance := _player.loadout.slots[slot]
	return instance.data.id if instance != null else &""


func test_a_reward_fills_its_slot_when_unlocked_and_empty() -> void:
	_profile.grant_achievement(&"defeat_tempest_dragon")
	_unlock_slots_for(10)
	AchievementRewards.apply(_player.loadout, _profile, _catalog)
	assert_eq(_spell_id(2), &"thunder_zone")
	assert_eq(_spell_id(3), &"")
	assert_eq(_spell_id(4), &"")


func test_a_locked_slot_gets_nothing_and_the_spell_waits() -> void:
	_profile.grant_achievement(&"defeat_tempest_dragon")
	_unlock_slots_for(9)
	AchievementRewards.apply(_player.loadout, _profile, _catalog)
	assert_eq(_spell_id(2), &"", "level 9 has not unlocked slot 3")
	var later := load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(later)
	later.loadout.set_unlocked_slots(_track.slot_count(10))
	AchievementRewards.apply(later.loadout, _profile, _catalog)
	assert_eq(later.loadout.slots[2].data.id, &"thunder_zone", "the same profile at level 10 gets it")


func test_a_slot_already_holding_a_spell_is_never_replaced() -> void:
	_profile.grant_achievement(&"defeat_ember_titan")
	_unlock_slots_for(15)
	var crafted := load("res://resources/spells/sea_line.tres") as SpellData
	_player.loadout.equip(3, crafted)
	AchievementRewards.apply(_player.loadout, _profile, _catalog)
	assert_eq(_spell_id(3), crafted.id, "a crafted spell is not replaced")


func test_no_starting_buffs_are_applied() -> void:
	_profile.grant_achievement(&"defeat_dire_minotaur")
	_unlock_slots_for(20)
	AchievementRewards.apply(_player.loadout, _profile, _catalog)
	var reward := load("res://resources/spells/land_line.tres") as SpellData
	var equipped := _player.loadout.slots[4].data
	assert_eq(equipped.damage, reward.damage)
	assert_eq(equipped.mana_cost, reward.mana_cost)
	assert_eq(equipped.max_mana, reward.max_mana)
	assert_eq(equipped.buff_stacks, reward.buff_stacks)


func test_two_runs_get_separate_mana_pools() -> void:
	_profile.grant_achievement(&"defeat_tempest_dragon")
	_unlock_slots_for(10)
	AchievementRewards.apply(_player.loadout, _profile, _catalog)
	var first: SpellInstance = _player.loadout.slots[2]
	first.cast()
	var second_player := load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(second_player)
	second_player.loadout.set_unlocked_slots(_track.slot_count(10))
	AchievementRewards.apply(second_player.loadout, _profile, _catalog)
	var second: SpellInstance = second_player.loadout.slots[2]
	assert_lt(first.current_mana, second.current_mana)
	assert_eq(second.current_mana, second.max_mana(), "a fresh full pool")


func test_an_unearned_achievement_gives_nothing() -> void:
	_unlock_slots_for(20)
	AchievementRewards.apply(_player.loadout, _profile, _catalog)
	for slot in [2, 3, 4]:
		assert_eq(_spell_id(slot), &"")


func test_a_badge_only_achievement_gives_nothing() -> void:
	_profile.grant_achievement(&"reach_level_20")
	_unlock_slots_for(20)
	AchievementRewards.apply(_player.loadout, _profile, _catalog)
	for slot in [2, 3, 4]:
		assert_eq(_spell_id(slot), &"")


func test_all_three_bosses_fill_slots_three_four_five_at_level_twenty() -> void:
	for id in [&"defeat_tempest_dragon", &"defeat_ember_titan", &"defeat_dire_minotaur"]:
		_profile.grant_achievement(id)
	_unlock_slots_for(20)
	AchievementRewards.apply(_player.loadout, _profile, _catalog)
	assert_eq(_spell_id(2), &"thunder_zone")
	assert_eq(_spell_id(3), &"ember_wave")
	assert_eq(_spell_id(4), &"land_line")
