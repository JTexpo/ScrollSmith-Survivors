extends GutTest

const E := SpellData.Element
const T := AreaData.AreaType
# path, element, area type, damage, interval, cost, max mana, knockback
const SPELLS := [
	["res://resources/spells/fire_missile.tres", E.FIRE, T.MISSILE, 10.0, 0.6, 1.0, 1000.0, 120.0],
	["res://resources/spells/thunder_cone.tres", E.THUNDER, T.CONE, 8.0, 0.4, 2.0, 60.0, 80.0],
	["res://resources/spells/land_area.tres", E.LAND, T.AREA, 12.0, 1.0, 4.0, 60.0, 40.0],
	["res://resources/spells/sea_line.tres", E.SEA, T.LINE, 14.0, 0.6, 2.0, 50.0, 60.0],
	["res://resources/spells/sea_wave.tres", E.SEA, T.WAVE, 12.0, 0.8, 3.0, 60.0, 100.0],
]
const AREAS := [
	"res://resources/spells/areas/missile_area.tres",
	"res://resources/spells/areas/line_area.tres",
	"res://resources/spells/areas/cone_area.tres",
	"res://resources/spells/areas/zone_area.tres",
	"res://resources/spells/areas/wave_area.tres",
]


func test_spells_match_starting_values() -> void:
	for row in SPELLS:
		var spell := load(row[0]) as SpellData
		assert_not_null(spell, row[0])
		assert_eq(spell.elements, [row[1]], row[0])
		assert_eq(spell.primary_element(), row[1], row[0])
		assert_eq(spell.area_type(), row[2], row[0])
		assert_eq(spell.damage, row[3], row[0])
		assert_eq(spell.cast_interval, row[4], row[0])
		assert_eq(spell.mana_cost, row[5], row[0])
		assert_eq(spell.max_mana, row[6], row[0])
		assert_eq(spell.knockback, row[7], row[0])
		assert_eq(spell.max_hits, 1, row[0])
		assert_eq(spell.range_scale, 1.0, row[0])
		assert_eq(spell.size_scale, 1.0, row[0])
		assert_true(spell.mana_cost <= spell.max_mana, row[0])


func test_missile_and_wave_speeds() -> void:
	assert_eq((load(SPELLS[0][0]) as SpellData).projectile_speed, 220.0)
	assert_eq((load(SPELLS[4][0]) as SpellData).projectile_speed, 140.0)


func test_the_two_sea_spells_are_separate_resources_with_one_colour() -> void:
	var line := load(SPELLS[3][0]) as SpellData
	var wave := load(SPELLS[4][0]) as SpellData
	assert_ne(line, wave)
	assert_eq(line.color, wave.color)


func test_each_area_has_its_own_type_and_role() -> void:
	var types := []
	for path in AREAS:
		var area := load(path) as AreaData
		assert_not_null(area.scene, path)
		types.append(area.type)
	assert_eq(types.size(), 5)
	for type in [T.LINE, T.CONE, T.AREA, T.MISSILE, T.WAVE]:
		assert_eq(types.count(type), 1)
	var cone := load(AREAS[2]) as AreaData
	var line := load(AREAS[1]) as AreaData
	assert_lt(cone.default_range, line.default_range)
	assert_true((load(AREAS[3]) as AreaData).needs_ground_target)
	assert_false((load(AREAS[0]) as AreaData).needs_ground_target)


func test_empty_spell_has_no_primary_element() -> void:
	assert_eq(SpellData.new().primary_element(), SpellData.NO_ELEMENT)
