extends GutTest

const S := StatBonuses.Stat
const K := PotionData.Kind

## id: [name, kind, magnitude, duration, cooldown, price, [[stat, amount], ...]]
const TABLE := {
	&"potion_health": ["Health Potion", K.HEAL, 0.40, 0.0, 10.0, 40, []],
	&"potion_mana": ["Mana Potion", K.RESTORE_MANA, 0.50, 0.0, 15.0, 60, []],
	&"potion_speed": ["Speed Potion", K.TIMED_BONUS, 0.0, 15.0, 30.0, 30, [[S.SPEED, 0.40]]],
	&"potion_damage": ["Damage Potion", K.TIMED_BONUS, 0.0, 15.0, 30.0, 50, [[S.SPELL_DAMAGE, 0.50]]],
	&"potion_invulnerability": ["Invulnerability Potion", K.INVULNERABILITY, 0.0, 5.0, 60.0, 100, []],
	&"potion_luck": ["Luck Potion", K.TIMED_BONUS, 0.0, 60.0, 90.0, 40, [[S.LUCK, 1.00]]],
}

var _catalog: PotionCatalog


func before_each() -> void:
	_catalog = PotionCatalog.default_catalog()


func test_catalog_matches_the_spec_table() -> void:
	assert_eq(_catalog.potions.size(), 6)
	var order := TABLE.keys()
	for i in order.size():
		var potion := _catalog.potions[i]
		var id: StringName = order[i]
		var row: Array = TABLE[id]
		assert_eq(potion.id, id)
		assert_eq(potion.display_name, row[0], str(id))
		assert_eq(potion.kind, row[1], str(id))
		assert_almost_eq(potion.magnitude, row[2], 0.0001, str(id))
		assert_almost_eq(potion.duration, row[3], 0.0001, str(id))
		assert_almost_eq(potion.cooldown, row[4], 0.0001, str(id))
		assert_eq(potion.price, row[5], str(id))
		assert_eq(potion.modifiers.size(), row[6].size(), str(id))
		for m in row[6].size():
			assert_eq(potion.modifiers[m].stat, row[6][m][0], "%s stat %d" % [id, m])
			assert_almost_eq(potion.modifiers[m].amount, row[6][m][1], 0.0001, "%s amount %d" % [id, m])


func test_ids_are_unique_and_every_potion_has_a_description_and_a_price() -> void:
	var seen := {}
	for potion in _catalog.potions:
		assert_false(seen.has(potion.id), "duplicate %s" % potion.id)
		seen[potion.id] = true
		assert_false(potion.description.is_empty(), str(potion.id))
		assert_gt(potion.price, 0, str(potion.id))


func test_find_and_index_of() -> void:
	assert_eq(_catalog.find(&"potion_luck").display_name, "Luck Potion")
	assert_null(_catalog.find(&"nothing"))
	assert_null(_catalog.find(&""))
	assert_eq(_catalog.index_of(&"potion_health"), 0)
	assert_eq(_catalog.index_of(&"potion_luck"), 5)
	assert_eq(_catalog.index_of(&"nothing"), -1)


func test_every_potion_has_a_positive_cooldown_and_timed_ones_a_duration() -> void:
	for potion in _catalog.potions:
		assert_gt(potion.cooldown, 0.0, str(potion.id))
		if potion.kind == K.TIMED_BONUS or potion.kind == K.INVULNERABILITY:
			assert_gt(potion.duration, 0.0, str(potion.id))
		else:
			assert_eq(potion.duration, 0.0, str(potion.id))


func test_a_timed_potions_cooldown_is_longer_than_its_duration() -> void:
	for potion in _catalog.potions:
		if potion.duration > 0.0:
			assert_gt(potion.cooldown, potion.duration, str(potion.id))


func test_only_timed_bonus_potions_carry_modifiers() -> void:
	for potion in _catalog.potions:
		assert_eq(not potion.modifiers.is_empty(), potion.kind == K.TIMED_BONUS, str(potion.id))


func test_potions_have_distinct_colours() -> void:
	var colours := []
	for potion in _catalog.potions:
		assert_false(colours.has(potion.color), str(potion.id))
		colours.append(potion.color)
