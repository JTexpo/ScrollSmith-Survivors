extends GutTest
## The spell audit models how much damage a full mana pool does against a tight group of enemies, so every Base, Area and buff can be
## compared. It changes nothing; these tests pin its maths on known spells.

const MISSILE := "res://resources/spells/areas/missile_area.tres"
const ZONE := "res://resources/spells/areas/zone_area.tres"
const CONE := "res://resources/spells/areas/cone_area.tres"


func _spell(area_path: String, damage := 10.0, cost := 2.0, pool := 100.0, interval := 1.0) -> SpellData:
	var spell := SpellData.new()
	spell.id = &"test"
	spell.damage = damage
	spell.mana_cost = cost
	spell.max_mana = pool
	spell.cast_interval = interval
	spell.area_data = (load(area_path) as AreaData).duplicate() as AreaData
	return spell


func test_a_missile_without_a_burst_hits_one_target_per_cast() -> void:
	var spell := _spell(MISSILE)
	spell.area_data.burst_radius = 0.0
	assert_eq(SpellAudit.hits_per_cast(spell, 1), 1.0)
	assert_eq(SpellAudit.hits_per_cast(spell, 8), 1.0)


func test_a_burst_adds_its_share_on_every_target_in_range() -> void:
	var spell := _spell(MISSILE)
	assert_eq(spell.area_data.burst_radius, 18.0)
	assert_almost_eq(SpellAudit.hits_per_cast(spell, 1), 1.5, 0.0001, "one target is hit and also burst")
	assert_almost_eq(SpellAudit.hits_per_cast(spell, 8), 1.0 + 0.5 * 3.0, 0.0001, "a group of 8 puts about 3 inside 18 px")


func test_a_zone_hits_each_target_once_per_tick() -> void:
	var spell := _spell(ZONE)
	assert_eq(spell.area_data.duration, 3.0)
	assert_eq(spell.area_data.tick_interval, 0.5)
	assert_eq(SpellAudit.hits_per_cast(spell, 1), 6.0)
	assert_eq(SpellAudit.hits_per_cast(spell, 8), 48.0)


func test_a_cone_reaches_several_targets_but_never_more_than_there_are() -> void:
	var spell := _spell(CONE)
	assert_eq(SpellAudit.hits_per_cast(spell, 1), 1.0)
	assert_eq(SpellAudit.hits_per_cast(spell, 3), 3.0)
	assert_eq(SpellAudit.hits_per_cast(spell, 8), float(SpellAudit.CONE_TARGETS))


func test_damage_per_pool_scales_with_casts_in_the_pool() -> void:
	var spell := _spell(CONE, 10.0, 2.0, 100.0)
	assert_eq(SpellAudit.damage_per_pool(spell, 1), 50.0 * 10.0 * 1.0, "50 casts, 10 damage, one target")
	spell.copies = 2
	assert_eq(SpellAudit.damage_per_pool(spell, 1), 50.0 * 10.0 * 2.0, "each copy hits")
	spell.mana_cost = 4.0
	assert_eq(SpellAudit.damage_per_pool(spell, 1), 25.0 * 10.0 * 2.0)


func test_damage_per_second_uses_the_cast_interval() -> void:
	var spell := _spell(CONE, 10.0, 2.0, 100.0, 0.5)
	assert_eq(SpellAudit.damage_per_second(spell, 1), 20.0)


func test_rows_cover_every_base_and_area_pair_every_buff_and_the_starting_spells() -> void:
	var rows := SpellAudit.rows()
	var ids: Array = rows.map(func(row: Dictionary) -> String: return str(row["id"]))
	for base in ["fire", "thunder", "land", "sea"]:
		for area in ["missile", "cone", "line", "wave", "zone"]:
			assert_true(ids.has("%s_%s" % [base, area]), "%s %s" % [base, area])
	for buff in ["additional_base", "damage", "double_vulnerability", "duplicate_area", "ignore_resistance", "max_mana"]:
		assert_true(ids.has("fire_missile+%s" % buff), buff)
	for start in ["start_fire_missile", "start_sea_cone", "start_land_area"]:
		assert_true(ids.has(start), start)


func test_flagged_finds_a_known_outlier() -> void:
	var rows: Array[Dictionary] = []
	for i in 9:
		rows.append({"id": "row%d" % i, "per_pool_8": 100.0})
	rows.append({"id": "huge", "per_pool_8": 1000.0})
	rows.append({"id": "tiny", "per_pool_8": 10.0})
	var flagged := SpellAudit.flagged(rows)
	var ids: Array = flagged.map(func(row: Dictionary) -> String: return str(row["id"]))
	assert_eq(ids, ["huge", "tiny"])


func test_the_median_row_is_not_flagged() -> void:
	var rows: Array[Dictionary] = []
	for value in [90.0, 100.0, 110.0]:
		rows.append({"id": str(value), "per_pool_8": value})
	assert_eq(SpellAudit.flagged(rows).size(), 0)
