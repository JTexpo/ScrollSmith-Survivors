extends GutTest

var _root: Node2D
var _player: Player
var _track: LevelTrack
var _profile: PlayerProfile
var _buffs: RunBuffs
var _catalog: EquipmentCatalog


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_track = LevelTrack.default_track()
	_profile = PlayerProfile.new()
	_buffs = RunBuffs.new()
	_catalog = EquipmentCatalog.default_catalog()


func _at_level(level: int) -> void:
	_profile.total_xp = _track.xp_for_level(level)


func _speed() -> float:
	return (_player.get_node("MoveComponent") as MoveComponent).speed


func _spell(slot: int) -> SpellData:
	return _player.loadout.slots[slot].data if _player.loadout.slots[slot] != null else null


func test_fresh_profile_leaves_fire_missile_unmodified_in_one_slot() -> void:
	RunStart.prepare(_player, _profile, _track, _buffs, _catalog)
	var fire := load("res://resources/spells/fire_missile.tres") as SpellData
	assert_eq(_player.loadout.unlocked_slots, 1)
	assert_null(_spell(1))
	assert_eq(_spell(0).damage, fire.damage)
	assert_eq(_spell(0).mana_cost, fire.mana_cost)
	assert_eq(_spell(0).max_mana, fire.max_mana)
	assert_eq(_spell(0).copies, 1)
	assert_eq(_speed(), 90.0)
	assert_eq(_player.health.max_health, 100.0)
	assert_eq(_player.loadout.slots[0].max_mana(), 1000.0)


func test_level_20_profile_gives_five_slots_and_all_stat_bonuses() -> void:
	_at_level(20)
	RunStart.prepare(_player, _profile, _track, _buffs, _catalog)
	assert_eq(_player.loadout.unlocked_slots, 5)
	assert_almost_eq(_speed(), 118.8, 0.001)
	assert_almost_eq(_player.health.max_health, 180.0, 0.001)
	assert_almost_eq(_player.health.current_health, 180.0, 0.001)
	assert_almost_eq(_player.loadout.slots[0].max_mana(), 1300.0, 0.001)
	assert_almost_eq(_player.loadout.slots[0].current_mana, 1300.0, 0.001)


func test_level_7_pick_is_applied_to_the_first_spell() -> void:
	_at_level(7)
	_buffs.set_pick(7, &"buff_duplicate_area")
	RunStart.prepare(_player, _profile, _track, _buffs, _catalog)
	assert_eq(_spell(0).copies, 2)
	assert_almost_eq(_spell(0).mana_cost, 2.0, 0.0001)
	assert_eq((load("res://resources/spells/fire_missile.tres") as SpellData).copies, 1)


func test_second_spell_appears_at_level_14_with_its_buffs() -> void:
	_at_level(13)
	RunStart.prepare(_player, _profile, _track, _buffs, _catalog)
	assert_null(_spell(1))
	_at_level(14)
	RunStart.prepare(_player, _profile, _track, _buffs, _catalog)
	assert_eq(_spell(1).display_name, "Sea Cone")
	assert_eq(_spell(1).copies, 1)
	_at_level(17)
	_buffs.set_pick(7, &"buff_damage")
	_buffs.set_pick(17, &"buff_duplicate_area")
	RunStart.prepare(_player, _profile, _track, _buffs, _catalog)
	assert_eq(_spell(1).copies, 2)
	assert_almost_eq(_spell(0).damage, 15.0, 0.0001)
	assert_eq(_spell(0).copies, 1)
	assert_eq((load("res://resources/spells/sea_cone.tres") as SpellData).copies, 1)


func test_prepare_twice_equals_once() -> void:
	_at_level(17)
	_buffs.set_pick(7, &"buff_damage")
	_buffs.set_pick(12, &"buff_max_mana")
	_buffs.set_pick(17, &"buff_duplicate_area")
	RunStart.prepare(_player, _profile, _track, _buffs, _catalog)
	var state := _state()
	RunStart.prepare(_player, _profile, _track, _buffs, _catalog)
	assert_eq(_state(), state)


func _state() -> Array:
	var out: Array = [_speed(), _player.health.max_health, _player.health.current_health, _player.loadout.unlocked_slots]
	for slot in 2:
		var data := _spell(slot)
		out.append([data.damage, data.mana_cost, data.max_mana, data.copies, _player.loadout.slots[slot].max_mana()])
	return out


func test_unresolved_chosen_buff_changes_nothing_yet() -> void:
	_at_level(12)
	_buffs.set_pick(7, &"buff_damage")
	RunStart.prepare(_player, _profile, _track, _buffs, _catalog)
	assert_almost_eq(_spell(0).damage, 15.0, 0.0001)
	assert_eq(_spell(0).copies, 1)


func test_unresolved_random_buff_changes_nothing_either() -> void:
	_at_level(7)
	RunStart.prepare(_player, _profile, _track, _buffs, _catalog)
	assert_eq(_spell(0).damage, 10.0)


func _wear(id: StringName) -> void:
	var item := _catalog.find(id)
	_profile.grant(id)
	_profile.equip(int(item.slot()), id)


func test_equipped_robe_adds_its_bonus_at_run_start() -> void:
	_wear(&"robe_ember")
	RunStart.prepare(_player, _profile, _track, _buffs, _catalog)
	assert_almost_eq(_player.loadout.bonuses.fraction(StatBonuses.Stat.DAMAGE_FIRE), 0.15, 0.0001)


func test_level_and_equipment_bonuses_add_together() -> void:
	_at_level(20)
	_wear(&"hat_hardy")
	RunStart.prepare(_player, _profile, _track, _buffs, _catalog)
	assert_almost_eq(_player.health.max_health, 200.0, 0.001)
	assert_almost_eq(_player.health.current_health, 200.0, 0.001)


func test_equipment_applies_before_the_starting_spells_are_equipped() -> void:
	_wear(&"hat_mana")
	RunStart.prepare(_player, _profile, _track, _buffs, _catalog)
	assert_almost_eq(_player.loadout.slots[0].max_mana(), 1100.0, 0.001)
	assert_almost_eq(_player.loadout.slots[0].current_mana, 1100.0, 0.001)


func test_wand_speed_reaches_the_starting_spell() -> void:
	_wear(&"wand_quick")
	RunStart.prepare(_player, _profile, _track, _buffs, _catalog)
	assert_almost_eq(_player.loadout.slots[0].cast_speed_bonus, 0.25, 0.0001)


func test_prepare_twice_with_equipment_equals_once() -> void:
	_at_level(17)
	_buffs.set_pick(7, &"buff_damage")
	_wear(&"robe_tide")
	_wear(&"wand_flicker")
	_wear(&"hood_swift")
	RunStart.prepare(_player, _profile, _track, _buffs, _catalog)
	var state := _state()
	var bonuses := _player.loadout.bonuses.fraction(StatBonuses.Stat.CAST_SPEED)
	RunStart.prepare(_player, _profile, _track, _buffs, _catalog)
	assert_eq(_state(), state)
	assert_eq(_player.loadout.bonuses.fraction(StatBonuses.Stat.CAST_SPEED), bonuses)


func test_nothing_equipped_changes_nothing() -> void:
	RunStart.prepare(_player, _profile, _track, _buffs, _catalog)
	assert_eq(_speed(), 90.0)
	assert_eq(_player.health.max_health, 100.0)
	assert_eq(_player.loadout.bonuses.fraction(StatBonuses.Stat.CAST_SPEED), 0.0)
	assert_eq(_player.loadout.slots[0].max_mana(), 1000.0)


func test_run_start_sets_the_level_and_equipment_layers_and_leaves_the_temporary_one() -> void:
	_at_level(5)
	_wear(&"hat_swift")
	var temporary := StatBonuses.new()
	temporary.add(StatBonuses.Stat.CAST_SPEED, 0.25)
	_player.temporary_bonuses = temporary
	RunStart.prepare(_player, _profile, _track, _buffs, _catalog)
	assert_almost_eq(_player.level_bonuses.fraction(StatBonuses.Stat.SPEED), 0.08, 0.0001)
	assert_almost_eq(_player.equipment_bonuses.fraction(StatBonuses.Stat.SPEED), 0.10, 0.0001)
	assert_almost_eq(_player.temporary_bonuses.fraction(StatBonuses.Stat.CAST_SPEED), 0.25, 0.0001)
	assert_almost_eq(_player.loadout.bonuses.fraction(StatBonuses.Stat.CAST_SPEED), 0.25, 0.0001)
