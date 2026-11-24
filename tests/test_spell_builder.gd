extends GutTest

const BASES := ["fire", "thunder", "land", "sea"]
const AREAS := ["line", "cone", "area", "missile", "wave"]

var _rules: CraftingRules


func before_each() -> void:
	_rules = CraftingRules.default_rules()


func _base(name: String) -> ScrollData:
	return load("res://resources/scrolls/base/%s.tres" % name) as ScrollData


func _area(name: String) -> ScrollData:
	return load("res://resources/scrolls/area/%s.tres" % name) as ScrollData


func _normal() -> RangeOption:
	return _rules.option(_rules.normal_index())


func test_fire_missile_at_normal_equals_the_starting_spell_except_its_bigger_pool() -> void:
	var built := SpellBuilder.build([_base("fire")], _area("missile"), _normal())
	var starting := load("res://resources/spells/fire_missile.tres") as SpellData
	assert_not_null(built)
	assert_eq(built.damage, starting.damage)
	assert_eq(built.cast_interval, starting.cast_interval)
	assert_eq(built.mana_cost, starting.mana_cost)
	# The player's first spell has a generous pool (1000) so a run has time to find scrolls.
	# Crafted spells use the Area baseline (100).
	assert_eq(starting.max_mana, 1000.0)
	assert_eq(built.max_mana, 100.0)
	assert_eq(built.projectile_speed, starting.projectile_speed)
	assert_eq(built.knockback, starting.knockback)
	assert_eq(built.max_hits, starting.max_hits)
	assert_eq(built.elements, starting.elements)
	assert_eq(built.color, starting.color)
	assert_eq(built.area_type(), starting.area_type())
	assert_eq(built.range_scale, 1.0)
	assert_eq(built.size_scale, 1.0)


func test_every_base_and_area_pair_builds() -> void:
	for base_name in BASES:
		for area_name in AREAS:
			var base := _base(base_name)
			var area := _area(area_name)
			var built := SpellBuilder.build([base], area, _normal())
			assert_not_null(built, "%s %s" % [base_name, area_name])
			assert_eq(built.primary_element(), base.element)
			assert_eq(built.area_data, area.area_data)
			assert_gt(built.damage, 0.0)
			assert_gt(built.mana_cost, 0.0)
			assert_gte(built.max_mana, built.mana_cost)


func test_longer_range_costs_more_and_gives_fewer_casts() -> void:
	var base := _base("thunder")
	var area := _area("wave")
	var previous: SpellData = null
	for i in _rules.range_options.size():
		var built := SpellBuilder.build([base], area, _rules.option(i))
		assert_eq(built.range_scale, _rules.option(i).range_scale)
		if previous != null:
			assert_gt(built.mana_cost, previous.mana_cost)
			assert_eq(built.max_mana, previous.max_mana)
			assert_lt(built.max_mana / built.mana_cost, previous.max_mana / previous.mana_cost)
		previous = built


func test_land_is_slower_and_heavier_than_thunder() -> void:
	for area_name in AREAS:
		var land := SpellBuilder.build([_base("land")], _area(area_name), _normal())
		var thunder := SpellBuilder.build([_base("thunder")], _area(area_name), _normal())
		assert_gt(land.damage, thunder.damage, area_name)
		assert_gt(land.cast_interval, thunder.cast_interval, area_name)
		assert_gt(thunder.max_mana, land.max_mana, area_name)


func test_name_and_id() -> void:
	var normal := SpellBuilder.build([_base("fire")], _area("missile"), _normal())
	assert_eq(normal.display_name, "Fire Missile")
	assert_eq(normal.id, &"fire_missile_normal")
	var long := SpellBuilder.build([_base("fire")], _area("missile"), _rules.option(2))
	assert_eq(long.display_name, "Fire Missile (Long)")
	assert_eq(long.id, &"fire_missile_long")
	var very_long := SpellBuilder.build([_base("sea")], _area("line"), _rules.option(3))
	assert_eq(very_long.display_name, "Sea Line (Very long)")
	assert_eq(very_long.id, &"sea_line_very_long")
	assert_eq(SpellBuilder.display_name([_base("land")], _area("area"), _normal()), "Land Area")


func test_describe_reports_the_numbers() -> void:
	var built := SpellBuilder.build([_base("land")], _area("area"), _rules.option(2))
	var info := SpellBuilder.describe(built)
	assert_eq(info["name"], "Land Area (Long)")
	assert_eq(info["damage"], built.damage)
	assert_eq(info["interval"], built.cast_interval)
	assert_eq(info["cost"], built.mana_cost)
	assert_eq(info["pool"], built.max_mana)
	assert_almost_eq(info["casts"], built.max_mana / built.mana_cost, 0.0001)
	assert_eq(info["range"], built.effective_range())
	assert_eq(info["area"], "Area")
	assert_eq(SpellBuilder.describe(SpellBuilder.build([_base("fire")], _area("missile"), _normal()))["area"], "Missile")


func test_bad_inputs_return_null() -> void:
	var fire := _base("fire")
	var missile := _area("missile")
	assert_null(SpellBuilder.build([null], missile, _normal()))
	assert_null(SpellBuilder.build([fire], null, _normal()))
	assert_null(SpellBuilder.build([fire], missile, null))
	assert_null(SpellBuilder.build([missile], missile, _normal()), "an Area scroll given as the Base")
	assert_null(SpellBuilder.build([fire], fire, _normal()), "a Base scroll given as the Area")
	var bare := fire.duplicate() as ScrollData
	bare.modifiers = null
	assert_null(SpellBuilder.build([bare], missile, _normal()), "a Base with no modifiers")
	var no_stats := missile.duplicate() as ScrollData
	no_stats.area_data = missile.area_data.duplicate() as AreaData
	no_stats.area_data.base_stats = null
	assert_null(SpellBuilder.build([fire], no_stats, _normal()), "an Area with no baseline")


func _buff(name: String) -> ScrollData:
	return load("res://resources/scrolls/buff/%s.tres" % name) as ScrollData


func _fire_missile(buffs: Array = []) -> SpellData:
	return SpellBuilder.build([_base("fire")], _area("missile"), _normal(), buffs)


func test_no_buffs_equals_the_sprint_6_result() -> void:
	for base_name in BASES:
		for area_name in AREAS:
			var plain := SpellBuilder.build([_base(base_name)], _area(area_name), _normal())
			var with_empty := SpellBuilder.build([_base(base_name)], _area(area_name), _normal(), [])
			assert_eq(plain.damage, with_empty.damage)
			assert_eq(plain.mana_cost, with_empty.mana_cost)
			assert_eq(plain.max_mana, with_empty.max_mana)
			assert_eq(plain.cast_interval, with_empty.cast_interval)
			assert_eq(plain.copies, 1)
			assert_eq(plain.vulnerability_scale, 1.0)
			assert_false(plain.ignores_resistance)
			assert_true(plain.buff_stacks.is_empty())


func test_each_buff_folds_alone() -> void:
	var damage := _fire_missile([_buff("damage")])
	assert_almost_eq(damage.damage, 15.0, 0.0001)
	assert_almost_eq(damage.mana_cost, 1.5, 0.0001)
	var pool := _fire_missile([_buff("max_mana")])
	assert_almost_eq(pool.max_mana, 150.0, 0.0001)
	assert_almost_eq(pool.mana_cost, 1.25, 0.0001)
	var vulnerable := _fire_missile([_buff("double_vulnerability")])
	assert_almost_eq(vulnerable.vulnerability_scale, 2.0, 0.0001)
	assert_almost_eq(vulnerable.mana_cost, 1.25, 0.0001)
	var ignoring := _fire_missile([_buff("ignore_resistance")])
	assert_true(ignoring.ignores_resistance)
	assert_almost_eq(ignoring.mana_cost, 1.25, 0.0001)
	var duplicated := _fire_missile([_buff("duplicate_area")])
	assert_eq(duplicated.copies, 2)
	assert_almost_eq(duplicated.mana_cost, 2.0, 0.0001)
	var extra_base := _fire_missile([_buff("additional_base")])
	assert_almost_eq(extra_base.mana_cost, 1.8, 0.0001)
	assert_eq(extra_base.elements.size(), 1, "the extra element comes from a second Base scroll, not the buff")


func test_stacks_multiply_and_add() -> void:
	var two_damage := _fire_missile([_buff("damage"), _buff("damage")])
	assert_almost_eq(two_damage.damage, 22.5, 0.0001)
	assert_almost_eq(two_damage.mana_cost, 2.25, 0.0001)
	var two_vulnerable := _fire_missile([_buff("double_vulnerability"), _buff("double_vulnerability")])
	assert_almost_eq(two_vulnerable.vulnerability_scale, 3.0, 0.0001)
	var three_copies := _fire_missile([_buff("duplicate_area"), _buff("duplicate_area"), _buff("duplicate_area")])
	assert_eq(three_copies.copies, 4)
	assert_almost_eq(three_copies.mana_cost, 8.0, 0.0001)


func test_buffs_combine() -> void:
	var spell := _fire_missile([_buff("damage"), _buff("duplicate_area"), _buff("ignore_resistance")])
	assert_almost_eq(spell.damage, 15.0, 0.0001)
	assert_eq(spell.copies, 2)
	assert_true(spell.ignores_resistance)
	assert_almost_eq(spell.mana_cost, 1.0 * 1.5 * 2.0 * 1.25, 0.0001)


func test_damage_per_mana_never_improves_from_damage_or_copies() -> void:
	var plain := _fire_missile()
	var plain_ratio := plain.damage / plain.mana_cost
	var stacks: Array = []
	for count in range(1, 7):
		stacks.append(_buff("damage"))
		var spell := _fire_missile(stacks)
		assert_lte(spell.damage / spell.mana_cost, plain_ratio + 0.0001, "%d damage stacks" % count)
	var copies: Array = []
	for count in range(1, 5):
		copies.append(_buff("duplicate_area"))
		var spell := _fire_missile(copies)
		assert_gte(spell.mana_cost, spell.copies * plain.mana_cost - 0.0001, "%d duplicate stacks" % count)


func test_hybrid_uses_the_mean_of_the_bases() -> void:
	var hybrid := SpellBuilder.build([_base("fire"), _base("thunder")], _area("missile"), _normal())
	assert_almost_eq(hybrid.damage, 10.0 * (1.0 + 0.7) / 2.0, 0.0001)
	assert_almost_eq(hybrid.mana_cost, 1.0, 0.0001)
	assert_almost_eq(hybrid.max_mana, 100.0 * (1.0 + 1.5) / 2.0, 0.0001)
	assert_almost_eq(hybrid.cast_interval, 0.6 * (1.0 + 0.5) / 2.0, 0.0001)


func test_hybrid_elements_name_color_and_id() -> void:
	var fire_sea := SpellBuilder.build([_base("fire"), _base("sea")], _area("missile"), _normal())
	assert_eq(fire_sea.elements, [SpellData.Element.FIRE, SpellData.Element.SEA])
	assert_eq(fire_sea.display_name, "Fire+Sea Missile")
	assert_eq(fire_sea.color, _base("fire").color)
	var sea_fire := SpellBuilder.build([_base("sea"), _base("fire")], _area("missile"), _normal())
	assert_eq(sea_fire.display_name, "Sea+Fire Missile")
	assert_eq(sea_fire.color, _base("sea").color)
	assert_ne(fire_sea.id, sea_fire.id)
	assert_ne(_fire_missile().id, _fire_missile([_buff("damage")]).id)
	assert_ne(_fire_missile([_buff("damage")]).id, _fire_missile([_buff("damage"), _buff("damage")]).id)


func test_buff_stacks_are_recorded() -> void:
	var damage := _buff("damage")
	var spell := _fire_missile([damage, damage, _buff("duplicate_area")])
	assert_eq(spell.buff_stacks.size(), 2)
	assert_eq(spell.buff_stacks[damage.id], 2)
	assert_eq(spell.buff_stacks[_buff("duplicate_area").id], 1)


func test_describe_reports_the_new_numbers() -> void:
	var buffs: Array = [_buff("double_vulnerability"), _buff("ignore_resistance"), _buff("duplicate_area")]
	var spell := SpellBuilder.build([_base("fire"), _base("sea")], _area("missile"), _normal(), buffs)
	var info := SpellBuilder.describe(spell)
	assert_eq(info["elements"], "Fire+Sea")
	assert_eq(info["copies"], 2)
	assert_eq(info["vulnerability"], 2.0)
	assert_true(info["ignores_resistance"])
	assert_eq(SpellBuilder.element_name(SpellData.Element.THUNDER), "Thunder")
	assert_eq(SpellBuilder.element_name(99), "None")


func test_can_cast() -> void:
	assert_true(SpellBuilder.can_cast(_fire_missile()))
	var stacks: Array = []
	for i in 40:
		stacks.append(_buff("damage"))
	assert_false(SpellBuilder.can_cast(_fire_missile(stacks)), "cost far above the pool")


func test_huge_stacks_stay_finite() -> void:
	var stacks: Array = []
	for i in 40:
		stacks.append(_buff("damage"))
	var spell := _fire_missile(stacks)
	for value in [spell.damage, spell.mana_cost, spell.max_mana]:
		assert_true(is_finite(value))


func test_bad_buffs_return_null() -> void:
	var no_effect := _buff("damage").duplicate() as ScrollData
	no_effect.buff = null
	for bad in [_base("fire"), _area("missile"), no_effect, null]:
		assert_null(_fire_missile([bad]), "buff entry %s" % [bad])
	assert_null(SpellBuilder.build([], _area("missile"), _normal()), "no Base scrolls")
	assert_null(SpellBuilder.build([_base("fire"), _area("missile")], _area("missile"), _normal()), "an Area scroll among the Bases")


func test_whole_casts_round_down() -> void:
	var spell := _fire_missile([_buff("damage")])
	assert_eq(SpellBuilder.describe(spell)["whole_casts"], 66)


func _starting_fire_missile() -> SpellData:
	return load("res://resources/spells/fire_missile.tres") as SpellData


func test_with_buffs_adds_copies_and_cost_without_changing_the_original() -> void:
	var original := _starting_fire_missile()
	var buffed := SpellBuilder.with_buffs(original, [_buff("duplicate_area")])
	assert_not_null(buffed)
	assert_eq(buffed.copies, 2)
	assert_almost_eq(buffed.mana_cost, original.mana_cost * 2.0, 0.0001)
	assert_eq(buffed.max_mana, original.max_mana)
	assert_eq(buffed.display_name, "Fire Missile")
	assert_eq(original.copies, 1)
	assert_eq(original.mana_cost, 1.0)
	assert_true(original.buff_stacks.is_empty())


func test_with_buffs_stacks_multiply_and_record_stacks() -> void:
	var damage := _buff("damage")
	var original := _starting_fire_missile()
	var buffed := SpellBuilder.with_buffs(original, [damage, damage])
	assert_almost_eq(buffed.damage, original.damage * 2.25, 0.0001)
	assert_eq(buffed.buff_stacks[damage.id], 2)
	assert_eq(original.damage, 10.0)


func test_with_buffs_builds_on_the_spells_own_buffs() -> void:
	var once := SpellBuilder.with_buffs(_starting_fire_missile(), [_buff("duplicate_area"), _buff("double_vulnerability")])
	var twice := SpellBuilder.with_buffs(once, [_buff("duplicate_area")])
	assert_eq(twice.copies, 3)
	assert_almost_eq(twice.vulnerability_scale, 2.0, 0.0001)
	assert_eq(twice.buff_stacks[_buff("duplicate_area").id], 2)
	assert_eq(once.copies, 2)


func test_with_buffs_gives_each_copy_its_own_profile() -> void:
	var buffed := SpellBuilder.with_buffs(_starting_fire_missile(), [_buff("ignore_resistance")])
	assert_true(buffed.attack_profile().ignores_resistance)
	assert_false(_starting_fire_missile().attack_profile().ignores_resistance)


func test_with_buffs_rejects_null_and_non_buff_scrolls() -> void:
	assert_null(SpellBuilder.with_buffs(null, [_buff("damage")]))
	assert_null(SpellBuilder.with_buffs(_starting_fire_missile(), [_base("fire")]))
	assert_null(SpellBuilder.with_buffs(_starting_fire_missile(), [null]))
	assert_null(SpellBuilder.with_buffs(_starting_fire_missile(), [_area("missile")]))


func test_with_buffs_empty_list_equals_the_original_numbers() -> void:
	var original := _starting_fire_missile()
	var copy := SpellBuilder.with_buffs(original, [])
	assert_not_null(copy)
	assert_eq(copy.damage, original.damage)
	assert_eq(copy.mana_cost, original.mana_cost)
	assert_eq(copy.max_mana, original.max_mana)
	assert_eq(copy.copies, 1)
	assert_eq(copy.elements, original.elements)
	assert_ne(copy, original)


func test_describe_without_bonuses_is_unchanged() -> void:
	var spell := _fire_missile()
	assert_eq(SpellBuilder.describe(spell), SpellBuilder.describe(spell, null))
	assert_eq(SpellBuilder.describe(spell, StatBonuses.new()), SpellBuilder.describe(spell))


func test_describe_with_bonuses_scales_damage_interval_pool_and_casts() -> void:
	var spell := _fire_missile()
	var bonuses := StatBonuses.new()
	bonuses.add(StatBonuses.Stat.SPELL_DAMAGE, 0.25)
	bonuses.add(StatBonuses.Stat.DAMAGE_FIRE, 0.2)
	bonuses.add(StatBonuses.Stat.CAST_SPEED, 0.25)
	bonuses.add(StatBonuses.Stat.SPELL_MANA, 0.3)
	var info := SpellBuilder.describe(spell, bonuses)
	assert_almost_eq(info["damage"], spell.damage * 1.5, 0.0001)
	assert_almost_eq(info["interval"], spell.cast_interval / 1.25, 0.0001)
	assert_almost_eq(info["pool"], spell.max_mana * 1.3, 0.0001)
	assert_almost_eq(info["casts"], spell.max_mana * 1.3 / spell.mana_cost, 0.0001)
	assert_eq(info["cost"], spell.mana_cost, "the cost per cast is not changed")


func test_describe_whole_casts_use_the_bonus_pool() -> void:
	var spell := _fire_missile()
	spell.max_mana = 10.0
	spell.mana_cost = 3.0
	var bonuses := StatBonuses.new()
	bonuses.add(StatBonuses.Stat.SPELL_MANA, 0.2)
	assert_eq(SpellBuilder.describe(spell)["whole_casts"], 3)
	assert_eq(SpellBuilder.describe(spell, bonuses)["whole_casts"], 4)


func test_describe_does_not_change_the_spell() -> void:
	var spell := _fire_missile()
	var damage := spell.damage
	var bonuses := StatBonuses.new()
	bonuses.add(StatBonuses.Stat.SPELL_DAMAGE, 1.0)
	SpellBuilder.describe(spell, bonuses)
	assert_eq(spell.damage, damage)
