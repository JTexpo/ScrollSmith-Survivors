extends GutTest

const ScrollHelpers := preload("res://tests/helpers/scroll_helpers.gd")

var _rules: CraftingRules
var _inventory: ScrollInventory
var _loadout: SpellLoadout
var _root: Node2D
var _fire: ScrollData
var _thunder: ScrollData
var _missile: ScrollData
var _wave: ScrollData


func _make_loadout(unlocked: int) -> SpellLoadout:
	var spells: Array[SpellData] = [load("res://resources/spells/fire_missile.tres") as SpellData]
	var loadout := SpellLoadout.new()
	loadout.starting_spells = spells
	loadout.unlocked_slots = unlocked
	loadout.projectile_root = _root
	add_child_autofree(loadout)
	return loadout


func _session() -> CraftingSession:
	return CraftingSession.new(_rules, _inventory, _loadout)


func before_each() -> void:
	_rules = CraftingRules.default_rules()
	_root = Node2D.new()
	add_child_autofree(_root)
	_inventory = ScrollInventory.new()
	add_child_autofree(_inventory)
	_loadout = _make_loadout(1)
	_fire = ScrollHelpers.scroll("base/fire")
	_thunder = ScrollHelpers.scroll("base/thunder")
	_missile = ScrollHelpers.scroll("area/missile")
	_wave = ScrollHelpers.scroll("area/wave")


func test_defaults() -> void:
	var session := _session()
	assert_eq(session.option_index, _rules.normal_index())
	assert_eq(session.slot_index, 0)
	assert_eq(session.bases, [])
	assert_null(session.area)
	assert_false(session.can_confirm())
	assert_eq(session.message(), CraftingSystem.REASON_NO_BASE)


func test_default_slot_is_the_selected_one_when_unlocked() -> void:
	_loadout = _make_loadout(3)
	_loadout.equip(2, load("res://resources/spells/thunder_cone.tres") as SpellData)
	_loadout.select(2)
	assert_eq(_session().slot_index, 2)


func test_empty_inventory_still_works() -> void:
	var session := _session()
	assert_eq(session.owned_bases(), [])
	assert_eq(session.owned_areas(), [])
	assert_eq(session.owned_buffs(), [])
	assert_null(session.preview())
	assert_eq(session.new_stats(), {})
	assert_false(session.message().is_empty())
	assert_false(session.confirm().ok)


func test_selecting_rules() -> void:
	_inventory.add(_fire)
	_inventory.add(_missile)
	var session := _session()
	watch_signals(session)
	assert_false(session.select_base(null))
	assert_false(session.select_base(_thunder), "not owned")
	assert_false(session.select_base(_missile), "wrong category")
	assert_false(session.select_area(_wave), "not owned")
	assert_false(session.select_area(_fire), "wrong category")
	assert_signal_not_emitted(session, "changed")
	assert_true(session.select_base(_fire))
	assert_eq(session.bases, [_fire])
	assert_true(session.select_base(_fire), "choosing it again clears it")
	assert_eq(session.bases, [])
	assert_true(session.select_area(_missile))
	assert_eq(session.area, _missile)
	assert_signal_emit_count(session, "changed", 3)


func test_select_range_and_slot_reject_bad_values() -> void:
	var session := _session()
	assert_false(session.select_range(-1))
	assert_false(session.select_range(9))
	assert_eq(session.option_index, _rules.normal_index())
	assert_true(session.select_range(2))
	assert_eq(session.option_index, 2)
	assert_false(session.select_slot(1), "locked")
	assert_false(session.select_slot(9))
	assert_false(session.select_slot(-1))
	assert_true(session.select_slot(0))


func test_preview_follows_the_choices() -> void:
	_inventory.add(_thunder)
	_inventory.add(_wave)
	var session := _session()
	session.select_base(_thunder)
	session.select_area(_wave)
	session.select_range(2)
	var built := SpellBuilder.build([_thunder], _wave, _rules.option(2))
	var preview := session.preview()
	assert_not_null(preview)
	assert_eq(preview.mana_cost, built.mana_cost)
	assert_eq(preview.max_mana, built.max_mana)
	assert_eq(preview.range_scale, built.range_scale)
	assert_eq(session.new_stats(), SpellBuilder.describe(built))
	assert_true(session.can_confirm())
	assert_eq(session.message(), "")


func test_current_stats_show_the_target_slot() -> void:
	var session := _session()
	assert_eq(session.current_stats()["name"], "Fire Missile")
	_loadout = _make_loadout(2)
	var other := _session()
	other.select_slot(1)
	assert_eq(other.current_stats(), {})


func test_replace_note_variants() -> void:
	var session := _session()
	assert_eq(session.replace_note(), "Replaces Fire Missile (1000 / 1000 mana left)")
	_loadout.slots[0].current_mana = 12.0
	assert_eq(session.replace_note(), "Replaces Fire Missile (12 / 1000 mana left)")
	_loadout.slots[0].current_mana = 0.0
	assert_eq(session.replace_note(), "Replaces Fire Missile (empty)")
	_loadout = _make_loadout(2)
	var other := _session()
	other.select_slot(1)
	assert_eq(other.replace_note(), "Empty slot")


func test_confirm_crafts_and_clears_spent_choices() -> void:
	_inventory.add(_fire)
	_inventory.add(_missile, 2)
	var session := _session()
	session.select_base(_fire)
	session.select_area(_missile)
	var result := session.confirm()
	assert_true(result.ok)
	assert_eq(_loadout.slots[0].data, result.spell)
	assert_eq(session.bases, [], "the last Fire scroll was used up")
	assert_eq(session.area, _missile, "one Missile scroll is left")
	assert_eq(_inventory.count(_missile), 1)


func test_confirm_when_invalid_changes_nothing() -> void:
	_inventory.add(_fire)
	var session := _session()
	session.select_base(_fire)
	var before_slot := _loadout.slots[0]
	var result := session.confirm()
	assert_false(result.ok)
	assert_eq(result.reason, CraftingSystem.REASON_NO_AREA)
	assert_eq(_inventory.count(_fire), 1)
	assert_eq(_loadout.slots[0], before_slot)


func test_owned_buffs_are_listed_but_never_craftable() -> void:
	var buff := ScrollHelpers.scroll("buff/damage")
	_inventory.add(buff)
	_inventory.add(_fire)
	_inventory.add(_missile)
	var session := _session()
	assert_eq(session.owned_buffs(), [buff])
	assert_false(session.select_base(buff))
	assert_false(session.select_area(buff))
	session.select_base(_fire)
	session.select_area(_missile)
	assert_eq(session.request().buffs, [])
	assert_true(session.confirm().ok)
	assert_eq(_inventory.count(buff), 1, "the buff scroll is untouched")


func _own(scroll: ScrollData, amount: int = 1) -> void:
	_inventory.add(scroll, amount)


func test_bases_are_multi_select_up_to_the_limit() -> void:
	var extra := ScrollHelpers.scroll("buff/additional_base")
	var sea := ScrollHelpers.scroll("base/sea")
	var land := ScrollHelpers.scroll("base/land")
	for scroll in [_fire, sea, land]:
		_own(scroll)
	_own(extra)
	var session := _session()
	assert_true(session.add_buff(extra))
	assert_eq(session.max_bases(), 2)
	session.select_base(_fire)
	session.select_base(sea)
	assert_eq(session.bases, [_fire, sea])
	session.select_base(land)
	assert_eq(session.bases, [sea, land], "a third choice replaces the oldest")


func test_the_limit_is_one_without_additional_base() -> void:
	_own(_fire)
	_own(_thunder)
	var session := _session()
	assert_eq(session.max_bases(), 1)
	session.select_base(_fire)
	session.select_base(_thunder)
	assert_eq(session.bases, [_thunder])


func test_choosing_a_chosen_base_clears_it() -> void:
	var extra := ScrollHelpers.scroll("buff/additional_base")
	var sea := ScrollHelpers.scroll("base/sea")
	_own(_fire)
	_own(sea)
	_own(extra)
	var session := _session()
	session.add_buff(extra)
	session.select_base(_fire)
	session.select_base(sea)
	session.select_base(_fire)
	assert_eq(session.bases, [sea])


func test_buff_stacks_respect_ownership_and_caps() -> void:
	var damage := ScrollHelpers.scroll("buff/damage")
	var duplicate := ScrollHelpers.scroll("buff/duplicate_area")
	var ignore := ScrollHelpers.scroll("buff/ignore_resistance")
	_own(damage, 2)
	_own(duplicate, 5)
	_own(ignore, 2)
	var session := _session()
	assert_true(session.add_buff(damage))
	assert_true(session.add_buff(damage))
	assert_false(session.add_buff(damage), "only two owned")
	assert_eq(session.buff_stacks(damage), 2)
	for i in 4:
		assert_true(session.add_buff(duplicate), "stack %d" % (i + 1))
	assert_false(session.add_buff(duplicate), "the cap is four")
	assert_true(session.add_buff(ignore))
	assert_false(session.add_buff(ignore), "the cap is one")


func test_removing_additional_base_trims_the_extra_bases() -> void:
	var extra := ScrollHelpers.scroll("buff/additional_base")
	var sea := ScrollHelpers.scroll("base/sea")
	_own(_fire)
	_own(sea)
	_own(extra)
	var session := _session()
	session.add_buff(extra)
	session.select_base(_fire)
	session.select_base(sea)
	assert_true(session.remove_buff(extra))
	assert_eq(session.bases, [_fire])
	assert_false(session.remove_buff(extra), "no stack left to remove")


func test_bad_buff_choices_are_rejected() -> void:
	var no_effect := ScrollHelpers.scroll("buff/damage").duplicate() as ScrollData
	no_effect.buff = null
	_own(_fire)
	_own(_missile)
	_own(no_effect)
	var session := _session()
	assert_false(session.add_buff(_fire))
	assert_false(session.add_buff(_missile))
	assert_false(session.add_buff(no_effect))
	assert_false(session.add_buff(null))
	assert_eq(session.buffs, [])


func test_the_request_carries_bases_and_buff_stacks_as_copies() -> void:
	var damage := ScrollHelpers.scroll("buff/damage")
	_own(_fire)
	_own(_thunder)
	_own(damage, 2)
	var session := _session()
	session.select_base(_fire)
	session.add_buff(damage)
	var earlier := session.request()
	session.select_base(_thunder)
	session.add_buff(damage)
	assert_eq(earlier.bases, [_fire])
	assert_eq(earlier.buffs, [damage])
	assert_eq(session.request().buffs, [damage, damage])


func test_confirm_with_buffs_uses_the_scrolls_and_trims_choices() -> void:
	var damage := ScrollHelpers.scroll("buff/damage")
	_own(_fire)
	_own(_missile)
	_own(damage)
	var session := _session()
	session.select_base(_fire)
	session.select_area(_missile)
	session.add_buff(damage)
	var result := session.confirm()
	assert_true(result.ok, result.reason)
	assert_eq(session.buffs, [])
	assert_eq(session.bases, [])
	assert_null(session.area)


func test_drawbacks_describe_the_cost() -> void:
	var damage := ScrollHelpers.scroll("buff/damage")
	_own(_fire)
	_own(_missile)
	_own(damage, 2)
	var session := _session()
	session.select_base(_fire)
	session.select_area(_missile)
	assert_eq(session.drawbacks(), [])
	session.add_buff(damage)
	session.add_buff(damage)
	assert_eq(session.drawbacks(), ["Buffs: costs 2.3x per cast, 100 casts become 44."])


func test_drawbacks_flag_a_spell_that_could_never_cast() -> void:
	var damage := ScrollHelpers.scroll("buff/damage")
	_own(_fire)
	_own(_missile)
	_own(damage, 40)
	var session := _session()
	session.select_base(_fire)
	session.select_area(_missile)
	for i in 40:
		session.add_buff(damage)
	assert_true(session.drawbacks().has("Too costly: this spell could never cast."))


func test_message_asks_for_the_missing_base() -> void:
	var extra := ScrollHelpers.scroll("buff/additional_base")
	_own(_fire)
	_own(_missile)
	_own(extra)
	var session := _session()
	session.select_base(_fire)
	session.select_area(_missile)
	session.add_buff(extra)
	assert_eq(session.message(), CraftingSystem.need_bases_reason(1))


func test_huge_stacks_keep_the_numbers_finite() -> void:
	var damage := ScrollHelpers.scroll("buff/damage")
	_own(_fire)
	_own(_missile)
	_own(damage, 40)
	var session := _session()
	session.select_base(_fire)
	session.select_area(_missile)
	for i in 40:
		session.add_buff(damage)
	var stats := session.new_stats()
	for key in ["damage", "cost", "pool", "casts"]:
		assert_true(is_finite(stats[key]), key)


func test_drawbacks_count_whole_casts_only() -> void:
	var damage := ScrollHelpers.scroll("buff/damage")
	_own(_fire)
	_own(_missile)
	_own(damage)
	var session := _session()
	session.select_base(_fire)
	session.select_area(_missile)
	session.add_buff(damage)
	assert_eq(session.drawbacks()[0], "Buffs: costs 1.5x per cast, 100 casts become 66.", "a 67th cast would not have the mana")


func test_new_and_current_stats_include_the_loadouts_bonuses() -> void:
	_inventory.add(_fire)
	_inventory.add(_missile)
	var bonuses := StatBonuses.new()
	bonuses.add(StatBonuses.Stat.SPELL_MANA, 0.5)
	bonuses.add(StatBonuses.Stat.CAST_SPEED, 0.25)
	_loadout.set_bonuses(bonuses)
	var session := _session()
	session.select_base(_fire)
	session.select_area(_missile)
	var fresh := session.new_stats()
	assert_almost_eq(fresh["pool"], 150.0, 0.001)
	assert_almost_eq(fresh["interval"], 0.6 / 1.25, 0.0001)
	var current := session.current_stats()
	assert_almost_eq(current["pool"], 1500.0, 0.001)
	assert_almost_eq(current["interval"], 0.6 / 1.25, 0.0001)


func test_stats_without_bonuses_are_the_plain_numbers() -> void:
	_inventory.add(_fire)
	_inventory.add(_missile)
	var session := _session()
	session.select_base(_fire)
	session.select_area(_missile)
	assert_almost_eq(session.new_stats()["pool"], 100.0, 0.001)
	assert_almost_eq(session.current_stats()["pool"], 1000.0, 0.001)


func test_drawbacks_count_casts_with_the_loadouts_mana_bonus() -> void:
	var damage := ScrollHelpers.scroll("buff/damage")
	_own(_fire)
	_own(_missile)
	_own(damage)
	var bonuses := StatBonuses.new()
	bonuses.add(StatBonuses.Stat.SPELL_MANA, 0.5)
	_loadout.set_bonuses(bonuses)
	var session := _session()
	session.select_base(_fire)
	session.select_area(_missile)
	session.add_buff(damage)
	assert_eq(session.drawbacks(), ["Buffs: costs 1.5x per cast, 150 casts become 100."])
	assert_almost_eq(session.new_stats()["whole_casts"], 100, 0)
