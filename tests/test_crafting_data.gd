extends GutTest

const AREAS := {
	"missile": [10.0, 0.6, 1.0, 100.0, 220.0, 120.0],
	"cone": [10.0, 0.8, 2.0, 100.0, 220.0, 100.0],
	"line": [12.0, 0.7, 2.0, 100.0, 220.0, 70.0],
	"zone": [12.0, 1.2, 4.0, 100.0, 220.0, 40.0],
	"wave": [11.0, 0.9, 3.0, 100.0, 140.0, 100.0],
}
const BASES := {
	"fire": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
	"thunder": [0.7, 0.5, 1.0, 1.5, 1.35, 0.65],
	"land": [1.8, 2.0, 2.0, 1.0, 0.75, 1.8],
	"sea": [0.9, 0.85, 1.0, 1.1, 0.9, 0.5],
}
const OPTIONS := [
	["Short", 0.6, 0.7], ["Normal", 1.0, 1.0], ["Long", 1.5, 1.4], ["Very long", 2.0, 1.8],
]


func test_area_baselines_match_the_table() -> void:
	for area in AREAS:
		var data := load("res://resources/spells/areas/%s_area.tres" % area) as AreaData
		var stats := data.base_stats
		assert_not_null(stats, area)
		var want: Array = AREAS[area]
		assert_eq(stats.damage, want[0], area)
		assert_eq(stats.cast_interval, want[1], area)
		assert_eq(stats.mana_cost, want[2], area)
		assert_eq(stats.max_mana, want[3], area)
		assert_eq(stats.projectile_speed, want[4], area)
		assert_eq(stats.knockback, want[5], area)


func test_base_scrolls_carry_the_multipliers() -> void:
	for base in BASES:
		var scroll := load("res://resources/scrolls/base/%s.tres" % base) as ScrollData
		var mods := scroll.modifiers
		assert_not_null(mods, base)
		var want: Array = BASES[base]
		assert_eq(mods.damage, want[0], base)
		assert_eq(mods.cast_interval, want[1], base)
		assert_eq(mods.mana_cost, want[2], base)
		assert_eq(mods.max_mana, want[3], base)
		assert_eq(mods.projectile_speed, want[4], base)
		assert_eq(mods.knockback, want[5], base)
	for path in ["area/line", "area/cone", "area/area", "area/missile", "area/wave", "buff/damage", "buff/max_mana"]:
		assert_null((load("res://resources/scrolls/%s.tres" % path) as ScrollData).modifiers, path)


func test_rules_have_the_four_range_options_in_order() -> void:
	var rules := CraftingRules.default_rules()
	assert_eq(rules.range_options.size(), 4)
	for i in OPTIONS.size():
		var option := rules.option(i)
		assert_eq(option.label, OPTIONS[i][0])
		assert_eq(option.range_scale, OPTIONS[i][1])
		assert_eq(option.cost_multiplier, OPTIONS[i][2])
	assert_eq(rules.normal_index(), 1)
	assert_null(rules.option(9))
	assert_null(rules.option(-1))
	for i in range(1, OPTIONS.size()):
		assert_gt(rules.option(i).cost_multiplier, rules.option(i - 1).cost_multiplier)
		assert_gt(rules.option(i).range_scale, rules.option(i - 1).range_scale)


func test_default_rules_loads() -> void:
	assert_not_null(CraftingRules.default_rules())
