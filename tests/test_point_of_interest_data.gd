extends GutTest

const DIR := "res://resources/points_of_interest/"
const KINDS := ["health_shrine", "mana_shrine", "treasure_chest", "rare_scroll_spot", "merchant"]


func _load(file: String) -> PointOfInterestData:
	return load(DIR + file + ".tres") as PointOfInterestData


func test_there_are_five_kinds_with_distinct_ids_and_colors() -> void:
	var ids := {}
	var colors := {}
	for file in KINDS:
		var data := _load(file)
		assert_not_null(data, file)
		assert_ne(data.id, &"", file)
		assert_ne(data.display_name, "", file)
		ids[data.id] = true
		colors[data.color] = true
	assert_eq(ids.size(), 5)
	assert_eq(colors.size(), 5)


func test_each_kind_has_the_numbers_it_needs() -> void:
	for file in KINDS:
		var data := _load(file)
		assert_gt(data.refresh_seconds, 0.0, "%s refreshes" % file)
		match data.kind:
			PointOfInterestData.Kind.HEAL, PointOfInterestData.Kind.RESTORE_MANA:
				assert_between(data.amount, 0.01, 1.0, file)
			PointOfInterestData.Kind.LOOT:
				assert_gte(data.gold_min, 0, file)
				assert_gte(data.gold_max, data.gold_min, file)
				assert_gte(data.scroll_count, 0, file)
				if data.scroll_count > 0:
					assert_not_null(data.scroll_table, "%s needs a scroll table" % file)
			PointOfInterestData.Kind.MERCHANT:
				assert_gte(data.stock_per_potion, 1, file)
				assert_gte(data.price_multiplier, 1.0, file)


func test_the_numbers_are_the_designed_ones() -> void:
	var health := _load("health_shrine")
	assert_eq(health.kind, PointOfInterestData.Kind.HEAL)
	assert_eq(health.amount, 0.5)
	assert_eq(health.refresh_seconds, 180.0)
	var mana := _load("mana_shrine")
	assert_eq(mana.kind, PointOfInterestData.Kind.RESTORE_MANA)
	assert_eq(mana.amount, 0.5)
	assert_eq(mana.refresh_seconds, 240.0)
	var chest := _load("treasure_chest")
	assert_eq(chest.kind, PointOfInterestData.Kind.LOOT)
	assert_eq([chest.gold_min, chest.gold_max, chest.scroll_count], [20, 40, 1])
	assert_eq(chest.refresh_seconds, 300.0)
	var rare := _load("rare_scroll_spot")
	assert_eq(rare.kind, PointOfInterestData.Kind.LOOT)
	assert_eq([rare.gold_min, rare.gold_max, rare.scroll_count], [0, 0, 1])
	assert_eq(rare.refresh_seconds, 300.0)
	var merchant := _load("merchant")
	assert_eq(merchant.kind, PointOfInterestData.Kind.MERCHANT)
	assert_eq(merchant.price_multiplier, 1.5)
	assert_eq(merchant.stock_per_potion, 2)
	assert_eq(merchant.refresh_seconds, 300.0)


func test_the_rare_scroll_spot_uses_the_rare_only_table() -> void:
	var rare := _load("rare_scroll_spot")
	assert_eq(rare.scroll_table.drop_chance, 1.0, "it always gives its scroll")
	assert_gt(rare.scroll_table.entries.size(), 0)
	for entry in rare.scroll_table.entries:
		assert_eq(entry.scroll.rarity, ScrollData.Rarity.RARE, entry.scroll.display_name)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 30:
		assert_eq(rare.scroll_table.roll(rng).rarity, ScrollData.Rarity.RARE)


func test_the_chest_table_has_all_15_scrolls_weighted_by_rarity() -> void:
	var table := load("res://resources/drops/chest_drops.tres") as DropTable
	assert_eq(table.drop_chance, 1.0)
	assert_eq(table.entries.size(), 15)
	var seen := {}
	var weights := {ScrollData.Rarity.COMMON: 6.0, ScrollData.Rarity.UNCOMMON: 3.0, ScrollData.Rarity.RARE: 1.0}
	for entry in table.entries:
		seen[entry.scroll.id] = true
		assert_eq(entry.weight, weights[entry.scroll.rarity], entry.scroll.display_name)
	assert_eq(seen.size(), 15)
	assert_eq(_load("treasure_chest").scroll_table, table)
