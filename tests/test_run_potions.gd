extends GutTest

const HEAL := &"potion_health"
const MANA := &"potion_mana"


func test_a_new_stock_is_empty() -> void:
	var stock := RunPotions.new()
	assert_true(stock.is_empty())
	assert_eq(stock.potion_count(HEAL), 0)


func test_add_and_use_one_potion() -> void:
	var stock := RunPotions.new()
	assert_eq(stock.add_potion(HEAL), 1)
	assert_eq(stock.potion_count(HEAL), 1)
	assert_true(stock.use_potion(HEAL))
	assert_eq(stock.potion_count(HEAL), 0)
	assert_true(stock.is_empty(), "a zero count is removed")


func test_the_cap_is_three_per_type() -> void:
	var stock := RunPotions.new()
	for i in 3:
		stock.add_potion(HEAL)
	assert_eq(stock.add_potion(HEAL), 0)
	assert_eq(stock.potion_count(HEAL), 3)
	assert_eq(RunPotions.MAX_POTIONS, 3)


func test_add_returns_how_many_were_added() -> void:
	var stock := RunPotions.new()
	assert_eq(stock.add_potion(HEAL, 5), 3)
	assert_eq(stock.add_potion(HEAL, 2), 0)


func test_using_a_missing_potion_changes_nothing() -> void:
	var stock := RunPotions.new()
	stock.add_potion(MANA)
	assert_false(stock.use_potion(HEAL))
	assert_eq(stock.potion_count(MANA), 1)


func test_amounts_at_or_below_zero_are_ignored() -> void:
	var stock := RunPotions.new()
	assert_eq(stock.add_potion(HEAL, 0), 0)
	assert_eq(stock.add_potion(HEAL, -2), 0)
	assert_true(stock.is_empty())


func test_types_are_counted_separately() -> void:
	var stock := RunPotions.new()
	stock.add_potion(HEAL, 3)
	stock.add_potion(MANA, 2)
	assert_eq(stock.potion_count(HEAL), 3)
	assert_eq(stock.potion_count(MANA), 2)


func test_clear_empties_everything() -> void:
	var stock := RunPotions.new()
	stock.add_potion(HEAL, 2)
	stock.add_potion(MANA, 1)
	stock.clear()
	assert_true(stock.is_empty())


func test_counts_is_a_copy() -> void:
	var stock := RunPotions.new()
	stock.add_potion(HEAL, 2)
	var counts := stock.counts()
	assert_eq(counts, {HEAL: 2})
	counts[HEAL] = 99
	assert_eq(stock.potion_count(HEAL), 2)
