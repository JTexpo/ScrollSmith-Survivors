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
	var spells: Array[SpellData] = [
		load("res://resources/spells/fire_missile.tres") as SpellData,
		load("res://resources/spells/thunder_cone.tres") as SpellData,
		load("res://resources/spells/land_area.tres") as SpellData,
	]
	var loadout := SpellLoadout.new()
	loadout.starting_spells = spells
	loadout.unlocked_slots = unlocked
	loadout.projectile_root = _root
	add_child_autofree(loadout)
	return loadout


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


func _request(base: ScrollData, area: ScrollData, option_index: int = 1, slot: int = 0) -> CraftingRequest:
	var request := CraftingRequest.new()
	if base != null:
		request.bases = [base] as Array[ScrollData]
	request.area = area
	request.option_index = option_index
	request.slot_index = slot
	return request


func _snapshot() -> Dictionary:
	var slots := []
	for slot in _loadout.slots:
		slots.append([slot, slot.current_mana if slot != null else -1.0])
	var counts := []
	for scroll in [_fire, _thunder, _missile, _wave, ScrollHelpers.scroll("base/sea"), ScrollHelpers.scroll("buff/damage"), ScrollHelpers.scroll("buff/additional_base"), ScrollHelpers.scroll("buff/duplicate_area"), ScrollHelpers.scroll("buff/ignore_resistance")]:
		counts.append(_inventory.count(scroll))
	return {"slots": slots, "counts": counts, "total": _inventory.total_count()}


func test_valid_craft_consumes_exactly_one_of_each_and_equips() -> void:
	_inventory.add(_fire, 2)
	_inventory.add(_missile)
	var result := CraftingSystem.craft(_request(_fire, _missile), _rules, _inventory, _loadout)
	assert_true(result.ok)
	assert_eq(result.reason, "")
	assert_eq(_inventory.count(_fire), 1)
	assert_eq(_inventory.count(_missile), 0)
	var crafted := _loadout.slots[0] as SpellInstance
	assert_eq(crafted.data, result.spell)
	assert_eq(crafted.data.id, &"fire_missile_normal")
	assert_eq(crafted.current_mana, crafted.data.max_mana)


func test_craft_replaces_the_target_slot_only() -> void:
	_loadout = _make_loadout(3)
	_inventory.add(_thunder)
	_inventory.add(_wave)
	var before_0 := _loadout.slots[0]
	var before_1 := _loadout.slots[1]
	var result := CraftingSystem.craft(_request(_thunder, _wave, 2, 2), _rules, _inventory, _loadout)
	assert_true(result.ok)
	assert_eq(_loadout.slots[0], before_0)
	assert_eq(_loadout.slots[1], before_1)
	assert_eq(_loadout.slots[2].data.display_name, "Thunder Wave (Long)")


## Own: 1 Fire, 1 Missile, 1 Increased Damage, plus Sea and Additional Base scrolls where a case needs them.
func _full(bases: Array, buffs: Array, area: ScrollData = null) -> CraftingRequest:
	var request := _request(null, area if area != null else _missile)
	request.bases.assign(bases)
	request.buffs.assign(buffs)
	return request


func _buff_cases() -> Array:
	var damage := ScrollHelpers.scroll("buff/damage")
	var extra := ScrollHelpers.scroll("buff/additional_base")
	var sea := ScrollHelpers.scroll("base/sea")
	var duplicate := ScrollHelpers.scroll("buff/duplicate_area")
	var ignore := ScrollHelpers.scroll("buff/ignore_resistance")
	var fire_copy := _fire.duplicate() as ScrollData
	var bad_buff := damage.duplicate() as ScrollData
	bad_buff.buff = null
	return [
		["one extra-base stack, one Base", _full([_fire], [extra]), CraftingSystem.need_bases_reason(1)],
		["two Bases without the buff", _full([_fire, sea], []), CraftingSystem.REASON_TOO_MANY_BASES],
		["two stacks, two Bases", _full([_fire, sea], [extra, extra]), CraftingSystem.need_bases_reason(1)],
		["same element twice", _full([_fire, _fire], [extra]), CraftingSystem.REASON_DUPLICATE_ELEMENT],
		["same element, two scrolls", _full([_fire, fire_copy], [extra]), CraftingSystem.REASON_DUPLICATE_ELEMENT],
		["five duplicate stacks", _full([_fire], [duplicate, duplicate, duplicate, duplicate, duplicate]), CraftingSystem.REASON_STACK_CAP],
		["two ignore stacks", _full([_fire], [ignore, ignore]), CraftingSystem.REASON_STACK_CAP],
		["damage not owned enough", _full([_fire], [damage, damage]), CraftingSystem.REASON_MISSING],
		["Base scroll as buff", _full([_fire], [_fire]), CraftingSystem.REASON_BAD_BUFF],
		["Area scroll as buff", _full([_fire], [_missile]), CraftingSystem.REASON_BAD_BUFF],
		["buff without data", _full([_fire], [bad_buff]), CraftingSystem.REASON_BAD_BUFF],
		["null buff", _full([_fire], [null]), CraftingSystem.REASON_BAD_BUFF],
		["Area scroll among the Bases", _full([_fire, _missile], [extra]), CraftingSystem.REASON_WRONG_BASE],
		["no Bases at all", _full([], []), CraftingSystem.REASON_NO_BASE],
	]


func _give_for_buff_cases() -> void:
	_inventory.add(_fire)
	_inventory.add(ScrollHelpers.scroll("base/sea"))
	_inventory.add(_missile)
	_inventory.add(ScrollHelpers.scroll("buff/damage"))
	_inventory.add(ScrollHelpers.scroll("buff/additional_base"), 2)
	_inventory.add(ScrollHelpers.scroll("buff/duplicate_area"), 5)
	_inventory.add(ScrollHelpers.scroll("buff/ignore_resistance"), 2)


func test_a_buff_craft_consumes_every_scroll_used() -> void:
	var damage := ScrollHelpers.scroll("buff/damage")
	_inventory.add(_fire, 2)
	_inventory.add(_missile)
	_inventory.add(damage, 3)
	var result := CraftingSystem.craft(_full([_fire], [damage, damage]), _rules, _inventory, _loadout)
	assert_true(result.ok, result.reason)
	assert_eq(_inventory.count(_fire), 1)
	assert_eq(_inventory.count(_missile), 0)
	assert_eq(_inventory.count(damage), 1)
	assert_eq((_loadout.slots[0] as SpellInstance).data.buff_stacks, {&"buff_damage": 2})


func test_a_hybrid_craft_consumes_both_bases_and_the_additional_base_scroll() -> void:
	var sea := ScrollHelpers.scroll("base/sea")
	var extra := ScrollHelpers.scroll("buff/additional_base")
	for scroll in [_fire, sea, extra, _missile]:
		_inventory.add(scroll)
	var result := CraftingSystem.craft(_full([_fire, sea], [extra]), _rules, _inventory, _loadout)
	assert_true(result.ok, result.reason)
	assert_eq(_inventory.total_count(), 0)
	assert_eq((_loadout.slots[0] as SpellInstance).data.elements, [SpellData.Element.FIRE, SpellData.Element.SEA])


func test_a_spell_that_could_never_cast_is_refused() -> void:
	var damage := ScrollHelpers.scroll("buff/damage")
	_inventory.add(_fire)
	_inventory.add(_missile)
	_inventory.add(damage, 40)
	var stacks: Array = []
	for i in 40:
		stacks.append(damage)
	var result := CraftingSystem.craft(_full([_fire], stacks), _rules, _inventory, _loadout)
	assert_false(result.ok)
	assert_eq(result.reason, CraftingSystem.REASON_TOO_COSTLY)
	assert_eq(_inventory.count(damage), 40)


func test_need_bases_reason_plural() -> void:
	assert_eq(CraftingSystem.need_bases_reason(1), "Pick 1 more Base scroll for your Additional Base.")
	assert_eq(CraftingSystem.need_bases_reason(2), "Pick 2 more Base scrolls for your Additional Base.")


func test_every_invalid_buff_case_changes_nothing() -> void:
	_give_for_buff_cases()
	watch_signals(_inventory)
	watch_signals(_loadout)
	for case in _buff_cases():
		var before := _snapshot()
		var result := CraftingSystem.craft(case[1], _rules, _inventory, _loadout)
		assert_false(result.ok, case[0])
		assert_eq(result.reason, case[2], case[0])
		assert_eq(_snapshot(), before, "%s changed something" % case[0])
	assert_signal_not_emitted(_inventory, "changed")
	assert_signal_not_emitted(_loadout, "slot_changed")


func test_validate_never_consumes_with_buffs() -> void:
	var damage := ScrollHelpers.scroll("buff/damage")
	_inventory.add(_fire)
	_inventory.add(_missile)
	_inventory.add(damage)
	var before := _snapshot()
	var request := _full([_fire], [damage])
	for i in 3:
		var result := CraftingSystem.validate(request, _rules, _inventory, _loadout)
		assert_true(result.ok, result.reason)
	assert_eq(_snapshot(), before)
	assert_eq(_inventory.count(damage), 1)


func test_each_invalid_case_changes_nothing() -> void:
	_inventory.add(_fire)
	_inventory.add(_missile)
	var area_scroll := _missile
	var cases := [
		["no base", _request(null, _missile), CraftingSystem.REASON_NO_BASE],
		["no area", _request(_fire, null), CraftingSystem.REASON_NO_AREA],
		["area as base", _request(_missile, _missile), CraftingSystem.REASON_WRONG_BASE],
		["base as area", _request(_fire, _fire), CraftingSystem.REASON_WRONG_AREA],
		["range -1", _request(_fire, _missile, -1), CraftingSystem.REASON_BAD_RANGE],
		["range 9", _request(_fire, _missile, 9), CraftingSystem.REASON_BAD_RANGE],
		["locked slot", _request(_fire, _missile, 1, 1), CraftingSystem.REASON_LOCKED_SLOT],
		["slot out of range", _request(_fire, _missile, 1, 9), CraftingSystem.REASON_LOCKED_SLOT],
		["negative slot", _request(_fire, _missile, 1, -1), CraftingSystem.REASON_LOCKED_SLOT],
		["base not owned", _request(_thunder, _missile), CraftingSystem.REASON_MISSING],
		["area not owned", _request(_fire, _wave), CraftingSystem.REASON_MISSING],
	]
	for case in _buff_cases():
		cases.append(case)
	watch_signals(_inventory)
	watch_signals(_loadout)
	for case in cases:
		var before := _snapshot()
		var result := CraftingSystem.craft(case[1], _rules, _inventory, _loadout)
		assert_false(result.ok, case[0])
		assert_eq(result.reason, case[2], case[0])
		assert_eq(_snapshot(), before, "%s changed something" % case[0])
	assert_signal_not_emitted(_inventory, "changed")
	assert_signal_not_emitted(_loadout, "slot_changed")
	assert_not_null(area_scroll)


func test_preview_ignores_the_inventory_and_slot() -> void:
	var spell := CraftingSystem.preview(_request(_fire, _missile, 1, 9), _rules)
	assert_not_null(spell)
	assert_eq(spell.display_name, "Fire Missile")
	assert_null(CraftingSystem.preview(_request(null, _missile), _rules))
	assert_null(CraftingSystem.preview(_request(_fire, _missile, 9), _rules))


func test_validate_never_consumes_and_carries_the_spell() -> void:
	_inventory.add(_fire)
	_inventory.add(_missile)
	var before := _snapshot()
	for i in 3:
		var result := CraftingSystem.validate(_request(_fire, _missile), _rules, _inventory, _loadout)
		assert_true(result.ok)
		assert_not_null(result.spell)
	assert_eq(_snapshot(), before)
	var missing := CraftingSystem.validate(_request(_thunder, _missile), _rules, _inventory, _loadout)
	assert_false(missing.ok)
	assert_not_null(missing.spell, "the preview spell is still carried for the screen")


func test_a_second_craft_needs_new_scrolls() -> void:
	_inventory.add(_fire)
	_inventory.add(_missile)
	assert_true(CraftingSystem.craft(_request(_fire, _missile), _rules, _inventory, _loadout).ok)
	var again := CraftingSystem.craft(_request(_fire, _missile), _rules, _inventory, _loadout)
	assert_false(again.ok)
	assert_eq(again.reason, CraftingSystem.REASON_MISSING)


func test_crafted_spell_works_in_the_loadout() -> void:
	_inventory.add(_thunder)
	_inventory.add(_missile)
	var result := CraftingSystem.craft(_request(_thunder, _missile), _rules, _inventory, _loadout)
	assert_true(result.ok)
	var crafted := _loadout.selected()
	assert_eq(crafted.data, result.spell)
	assert_true(_loadout.try_cast(Vector2.ZERO, Vector2.RIGHT))
	assert_eq(crafted.current_mana, crafted.data.max_mana - crafted.data.mana_cost)
	var effects := 0
	for child in _root.get_children():
		if child is AreaEffect:
			effects += 1
	assert_eq(effects, 1)


func test_a_recipe_that_cannot_be_built_changes_nothing() -> void:
	var bare_base := _fire.duplicate() as ScrollData
	bare_base.modifiers = null
	var bare_area := _missile.duplicate() as ScrollData
	bare_area.area_data = _missile.area_data.duplicate() as AreaData
	bare_area.area_data.base_stats = null
	_inventory.add(bare_base)
	_inventory.add(_fire)
	_inventory.add(_missile)
	_inventory.add(bare_area)
	for case in [[bare_base, _missile], [_fire, bare_area]]:
		var before := _snapshot()
		var before_counts := [_inventory.count(case[0]), _inventory.count(case[1])]
		var validated := CraftingSystem.validate(_request(case[0], case[1]), _rules, _inventory, _loadout)
		assert_false(validated.ok)
		assert_eq(validated.reason, CraftingSystem.REASON_CANNOT_BUILD)
		var crafted := CraftingSystem.craft(_request(case[0], case[1]), _rules, _inventory, _loadout)
		assert_false(crafted.ok)
		assert_eq(_snapshot(), before, "nothing was consumed or equipped")
		assert_eq([_inventory.count(case[0]), _inventory.count(case[1])], before_counts)
