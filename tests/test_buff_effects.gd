extends GutTest

const ScrollHelpers := preload("res://tests/helpers/scroll_helpers.gd")

# file, damage x, pool x, cost x, vulnerability bonus, ignores resistance, extra copies, extra bases, max stacks
const BUFFS := [
	["damage", 1.5, 1.0, 1.5, 0.0, false, 0, 0, 0],
	["max_mana", 1.0, 1.5, 1.25, 0.0, false, 0, 0, 0],
	["double_vulnerability", 1.0, 1.0, 1.25, 1.0, false, 0, 0, 0],
	["ignore_resistance", 1.0, 1.0, 1.25, 0.0, true, 0, 0, 1],
	["duplicate_area", 1.0, 1.0, 2.0, 0.0, false, 1, 0, 4],
	["additional_base", 1.0, 1.0, 1.8, 0.0, false, 0, 1, 3],
]


func test_each_buff_scroll_references_its_effect_with_the_table_numbers() -> void:
	for row in BUFFS:
		var scroll := ScrollHelpers.buff_scroll(row[0])
		assert_not_null(scroll.buff, row[0])
		var effect := scroll.buff
		assert_eq(effect.damage_multiplier, row[1], row[0])
		assert_eq(effect.max_mana_multiplier, row[2], row[0])
		assert_eq(effect.cost_multiplier, row[3], row[0])
		assert_eq(effect.vulnerability_bonus, row[4], row[0])
		assert_eq(effect.ignores_resistance, row[5], row[0])
		assert_eq(effect.extra_copies, row[6], row[0])
		assert_eq(effect.extra_bases, row[7], row[0])
		assert_eq(effect.max_stacks, row[8], row[0])


func test_other_scrolls_have_no_buff_effect() -> void:
	for path in ["base/fire", "base/sea", "area/line", "area/missile", "area/wave"]:
		assert_null((load("res://resources/scrolls/%s.tres" % path) as ScrollData).buff, path)


func test_damage_and_copies_never_cost_less_than_what_they_buy() -> void:
	var damage := ScrollHelpers.buff_scroll("damage").buff
	assert_gte(damage.cost_multiplier, damage.damage_multiplier)
	var duplicate := ScrollHelpers.buff_scroll("duplicate_area").buff
	for stacks in range(1, duplicate.max_stacks + 1):
		assert_gte(pow(duplicate.cost_multiplier, stacks), float(stacks + 1), "%d stacks buy %d shots" % [stacks, stacks + 1])


func test_stack_caps() -> void:
	assert_eq(ScrollHelpers.buff_scroll("duplicate_area").buff.max_stacks, 4)
	assert_eq(ScrollHelpers.buff_scroll("additional_base").buff.max_stacks, 3)
	assert_eq(ScrollHelpers.buff_scroll("ignore_resistance").buff.max_stacks, 1)
	for file in ["damage", "max_mana", "double_vulnerability"]:
		assert_eq(ScrollHelpers.buff_scroll(file).buff.max_stacks, 0, file)


func test_spell_data_defaults() -> void:
	var spell := SpellData.new()
	assert_eq(spell.copies, 1)
	assert_eq(spell.vulnerability_scale, 1.0)
	assert_false(spell.ignores_resistance)
	assert_true(spell.buff_stacks.is_empty())


func test_attack_profile_is_built_once_per_spell_and_mirrors_it() -> void:
	var spell := SpellData.new()
	var elements: Array[SpellData.Element] = [SpellData.Element.LAND, SpellData.Element.SEA]
	spell.elements = elements
	spell.vulnerability_scale = 3.0
	spell.ignores_resistance = true
	var profile := spell.attack_profile()
	assert_eq(profile, spell.attack_profile(), "built once, so a cast allocates nothing")
	assert_eq(profile.elements, [SpellData.Element.LAND, SpellData.Element.SEA])
	assert_eq(profile.vulnerability_scale, 3.0)
	assert_true(profile.ignores_resistance)
	assert_eq(SpellData.new().attack_profile().elements, [])


func test_every_buff_has_its_own_accent_colour_and_an_icon_that_exists() -> void:
	var colors := {}
	for file in DirAccess.get_files_at("res://resources/crafting/buff_effects"):
		if not String(file).ends_with(".tres"):
			continue
		var effect := load("res://resources/crafting/buff_effects/%s" % file) as BuffEffect
		assert_ne(effect.color, Color.WHITE, "%s has a colour" % file)
		assert_false(colors.has(effect.color.to_html()), "%s repeats a colour" % file)
		colors[effect.color.to_html()] = true
		assert_ne(effect.icon, &"", "%s has an icon name" % file)
		assert_not_null(SpriteLibrary.find(effect.icon), "%s: the icon %s exists" % [file, effect.icon])
	assert_gte(colors.size(), 6)
