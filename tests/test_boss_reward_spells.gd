extends GutTest
## The three spells a boss achievement gives: Thunder Zone (Tempest Dragon), Ember Wave (Ember Titan), Land Line (Dire Minotaur).

const SPELLS := {
	"thunder_zone": {"path": "res://resources/spells/thunder_zone.tres", "element": SpellData.Element.THUNDER, "area": "res://resources/spells/areas/zone_area.tres", "name": "Thunder Zone"},
	"ember_wave": {"path": "res://resources/spells/ember_wave.tres", "element": SpellData.Element.FIRE, "area": "res://resources/spells/areas/wave_area.tres", "name": "Ember Wave"},
	"land_line": {"path": "res://resources/spells/land_line.tres", "element": SpellData.Element.LAND, "area": "res://resources/spells/areas/line_area.tres", "name": "Land Line"},
}
const STARTING_IDS := ["fire_missile", "sea_cone", "land_area", "sea_line", "sea_wave", "thunder_cone"]
## The design's balance target: modelled output within this factor of the Sea Cone's, either way.
const RATIO_LIMIT := 1.5
const GROUP := 8


func _spell(id: String) -> SpellData:
	return load(SPELLS[id]["path"]) as SpellData


func test_the_three_spells_load_with_the_right_element_and_area() -> void:
	for id in SPELLS:
		var spell := _spell(id)
		assert_not_null(spell, id)
		if spell == null:
			continue
		assert_eq(spell.id, StringName(id))
		assert_eq(spell.display_name, SPELLS[id]["name"])
		assert_eq(spell.elements, [SPELLS[id]["element"]] as Array[int], "%s element" % id)
		assert_eq(spell.area_data.resource_path, SPELLS[id]["area"], "%s area" % id)


func test_each_spell_can_cast_and_has_its_own_pool() -> void:
	for id in SPELLS:
		var spell := _spell(id)
		assert_gt(spell.max_mana, 0.0, id)
		assert_gt(spell.mana_cost, 0.0, id)
		assert_lte(spell.mana_cost, spell.max_mana, id)
		assert_true(SpellBuilder.can_cast(spell), id)
		var first := SpellInstance.new(spell)
		var second := SpellInstance.new(spell)
		first.cast()
		assert_lt(first.current_mana, second.current_mana, "%s: two instances never share mana" % id)


func test_ids_and_names_are_unique_and_distinct_from_the_starting_spells() -> void:
	var ids := {}
	var names := {}
	for id in SPELLS:
		var spell := _spell(id)
		ids[spell.id] = true
		names[spell.display_name] = true
	assert_eq(ids.size(), 3)
	assert_eq(names.size(), 3)
	for starting in STARTING_IDS:
		var other := load("res://resources/spells/%s.tres" % starting) as SpellData
		assert_false(ids.has(other.id), "%s is a starting spell" % other.id)
		assert_false(names.has(other.display_name), other.display_name)


func test_the_spells_match_the_balance_target() -> void:
	var reference := load("res://resources/spells/sea_cone.tres") as SpellData
	var reference_dps := SpellAudit.damage_per_second(reference, GROUP)
	var reference_pool := SpellAudit.damage_per_pool(reference, GROUP)
	for id in SPELLS:
		var spell := _spell(id)
		var dps_ratio := SpellAudit.damage_per_second(spell, GROUP) / reference_dps
		var pool_ratio := SpellAudit.damage_per_pool(spell, GROUP) / reference_pool
		assert_between(dps_ratio, 1.0 / RATIO_LIMIT, RATIO_LIMIT, "%s damage per second against %d is %.2f times the Sea Cone's" % [id, GROUP, dps_ratio])
		assert_between(pool_ratio, 1.0 / RATIO_LIMIT, RATIO_LIMIT, "%s damage per pool against %d is %.2f times the Sea Cone's" % [id, GROUP, pool_ratio])
