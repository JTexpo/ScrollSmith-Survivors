extends GutTest

const S := StatBonuses.Stat
const C := EquipmentData.Category

## id: [name, category, price, [[stat, amount], ...]]
const TABLE := {
	&"robe_ember": ["Ember Robe", C.ROBE, 100, [[S.DAMAGE_FIRE, 0.15]]],
	&"robe_storm": ["Storm Robe", C.ROBE, 100, [[S.DAMAGE_THUNDER, 0.15]]],
	&"robe_stone": ["Stone Robe", C.ROBE, 100, [[S.DAMAGE_LAND, 0.15]]],
	&"robe_tide": ["Tide Robe", C.ROBE, 100, [[S.DAMAGE_SEA, 0.15]]],
	&"robe_warded": ["Warded Robe", C.ROBE, 120, [[S.HEALTH, 0.30]]],
	&"hat_mana": ["Mana Hat", C.HAT, 80, [[S.SPELL_MANA, 0.10]]],
	&"hat_swift": ["Swift Hat", C.HAT, 80, [[S.SPEED, 0.10]]],
	&"hat_hardy": ["Hardy Hat", C.HAT, 80, [[S.HEALTH, 0.20]]],
	&"hood_mana": ["Mana Hood", C.HOOD, 80, [[S.SPELL_MANA, 0.10]]],
	&"hood_swift": ["Swift Hood", C.HOOD, 80, [[S.SPEED, 0.10]]],
	&"hood_hardy": ["Hardy Hood", C.HOOD, 80, [[S.HEALTH, 0.20]]],
	&"wand_quick": ["Quickwand", C.WAND, 200, [[S.CAST_SPEED, 0.25], [S.SPELL_DAMAGE, -0.15], [S.CAST_TWICE_CHANCE, 0.10]]],
	&"wand_flicker": ["Flickerwand", C.WAND, 350, [[S.CAST_SPEED, 0.40], [S.SPELL_DAMAGE, -0.30], [S.CAST_TWICE_CHANCE, 0.15]]],
	&"staff_oak": ["Oak Staff", C.STAFF, 200, [[S.SPELL_DAMAGE, 0.25], [S.CAST_SPEED, -0.15], [S.DOUBLE_DAMAGE_CHANCE, 0.10]]],
	&"staff_elder": ["Elder Staff", C.STAFF, 350, [[S.SPELL_DAMAGE, 0.45], [S.CAST_SPEED, -0.30], [S.DOUBLE_DAMAGE_CHANCE, 0.15]]],
}

var _catalog: EquipmentCatalog


func before_each() -> void:
	_catalog = EquipmentCatalog.default_catalog()


func test_catalog_matches_the_spec_table() -> void:
	assert_eq(_catalog.items.size(), 15)
	var order := TABLE.keys()
	for i in order.size():
		var item := _catalog.items[i]
		var id: StringName = order[i]
		var row: Array = TABLE[id]
		assert_eq(item.id, id)
		assert_eq(item.display_name, row[0], str(id))
		assert_eq(item.category, row[1], str(id))
		assert_eq(item.price, row[2], str(id))
		assert_eq(item.modifiers.size(), row[3].size(), str(id))
		for m in row[3].size():
			assert_eq(item.modifiers[m].stat, row[3][m][0], "%s stat %d" % [id, m])
			assert_almost_eq(item.modifiers[m].amount, row[3][m][1], 0.0001, "%s amount %d" % [id, m])


func test_ids_are_unique_and_every_item_has_a_description_and_a_price() -> void:
	var seen := {}
	for item in _catalog.items:
		assert_false(seen.has(item.id), "duplicate %s" % item.id)
		seen[item.id] = true
		assert_false(item.description.is_empty(), str(item.id))
		assert_gt(item.price, 0, str(item.id))


func test_slot_mapping() -> void:
	assert_eq(_catalog.find(&"robe_ember").slot(), EquipmentData.Slot.ROBE)
	assert_eq(_catalog.find(&"wand_quick").slot(), EquipmentData.Slot.WEAPON)
	assert_eq(_catalog.find(&"staff_oak").slot(), EquipmentData.Slot.WEAPON)
	assert_eq(_catalog.find(&"hat_mana").slot(), EquipmentData.Slot.HEADWEAR)
	assert_eq(_catalog.find(&"hood_mana").slot(), EquipmentData.Slot.HEADWEAR)


func test_find_returns_the_item_or_null() -> void:
	assert_eq(_catalog.find(&"staff_elder").display_name, "Elder Staff")
	assert_null(_catalog.find(&"nothing"))
	assert_null(_catalog.find(&""))


func test_items_for_slot_in_catalog_order() -> void:
	assert_eq(_catalog.items_for_slot(EquipmentData.Slot.ROBE).size(), 5)
	assert_eq(_catalog.items_for_slot(EquipmentData.Slot.WEAPON).size(), 4)
	assert_eq(_catalog.items_for_slot(EquipmentData.Slot.HEADWEAR).size(), 6)
	assert_eq(_catalog.items_for_slot(EquipmentData.Slot.WEAPON)[0].id, &"wand_quick")
	assert_eq(_catalog.items_for_slot(EquipmentData.Slot.WEAPON)[3].id, &"staff_elder")


func test_hats_and_hoods_differ_only_in_name_id_and_colour() -> void:
	for kind in ["mana", "swift", "hardy"]:
		var hat := _catalog.find(StringName("hat_%s" % kind))
		var hood := _catalog.find(StringName("hood_%s" % kind))
		assert_eq(hat.price, hood.price)
		assert_eq(hat.modifiers.size(), hood.modifiers.size())
		for m in hat.modifiers.size():
			assert_eq(hat.modifiers[m].stat, hood.modifiers[m].stat)
			assert_eq(hat.modifiers[m].amount, hood.modifiers[m].amount)
		assert_ne(hat.display_name, hood.display_name)
		assert_ne(hat.color, hood.color)


func test_wands_trade_damage_for_speed_and_staffs_the_reverse() -> void:
	for id in [&"wand_quick", &"wand_flicker"]:
		var totals := _sum(_catalog.find(id))
		assert_gt(totals[S.CAST_SPEED], 0.0)
		assert_lt(totals[S.SPELL_DAMAGE], 0.0)
		assert_gt(totals[S.CAST_TWICE_CHANCE], 0.0)
	for id in [&"staff_oak", &"staff_elder"]:
		var totals := _sum(_catalog.find(id))
		assert_gt(totals[S.SPELL_DAMAGE], 0.0)
		assert_lt(totals[S.CAST_SPEED], 0.0)
		assert_gt(totals[S.DOUBLE_DAMAGE_CHANCE], 0.0)


func _sum(item: EquipmentData) -> Dictionary:
	var totals := {}
	for modifier in item.modifiers:
		totals[modifier.stat] = float(totals.get(modifier.stat, 0.0)) + modifier.amount
	return totals


func test_every_shipped_item_names_a_sprite_and_a_variant_that_exist() -> void:
	var catalog := EquipmentCatalog.default_catalog()
	assert_eq(catalog.items.size(), 15)
	for item in catalog.items:
		assert_ne(item.sprite_name, &"", "%s names a sprite" % item.id)
		assert_ne(item.sprite_variant, &"", "%s names a colourway" % item.id)
		var found := SpriteLibrary.find(item.sprite_name, item.sprite_variant)
		assert_not_null(found, "%s has art" % item.id)
		var base := SpriteLibrary.find(item.sprite_name, &"base")
		assert_true(base == null or found.sheet != base.sheet, "%s uses its own colourway, not a fallback" % item.id)


func test_each_family_shares_one_shape_with_its_own_colours() -> void:
	var catalog := EquipmentCatalog.default_catalog()
	var sprites := {}
	for item in catalog.items:
		if not sprites.has(item.sprite_name):
			sprites[item.sprite_name] = []
		sprites[item.sprite_name].append(item.sprite_variant)
	assert_eq(sprites.size(), 5, "robe, hat, hood, wand, staff")
	assert_eq(sprites[&"robe_wizard"].size(), 5)
	assert_eq(sprites[&"hat_pointed"].size(), 3)
	assert_eq(sprites[&"hood_soft"].size(), 3)
	assert_eq(sprites[&"wand_short"].size(), 2)
	assert_eq(sprites[&"staff_tall"].size(), 2)
	for sprite_name in sprites:
		var distinct := {}
		for variant in sprites[sprite_name]:
			distinct[variant] = true
		assert_eq(distinct.size(), sprites[sprite_name].size(), "%s: every item has its own colours" % sprite_name)

