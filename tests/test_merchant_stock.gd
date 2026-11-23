extends GutTest


func _catalog() -> PotionCatalog:
	var catalog := PotionCatalog.new()
	var list: Array[PotionData] = []
	for id in [&"a", &"b", &"c"]:
		var potion := PotionData.new()
		potion.id = id
		potion.price = 10
		list.append(potion)
	catalog.potions = list
	return catalog


func _stock(per_potion: int = 2) -> MerchantStock:
	var stock := MerchantStock.new()
	stock.setup(_catalog(), per_potion)
	return stock


func test_setup_fills_every_potion_to_the_count() -> void:
	var stock := _stock(2)
	for id in [&"a", &"b", &"c"]:
		assert_eq(stock.count(id), 2)
	assert_eq(stock.count(&"nothing"), 0, "an unknown potion has none")
	assert_true(stock.is_full())


func test_take_lowers_the_count_and_refuses_at_zero() -> void:
	var stock := _stock(2)
	assert_true(stock.take(&"a"))
	assert_true(stock.take(&"a"))
	assert_eq(stock.count(&"a"), 0)
	assert_false(stock.take(&"a"), "nothing left")
	assert_eq(stock.count(&"a"), 0, "never below zero")
	assert_false(stock.take(&"nothing"))
	assert_eq(stock.count(&"b"), 2, "other potions are untouched")


func test_the_restock_timer_starts_on_the_first_take_and_refills_everything() -> void:
	var stock := _stock(2)
	assert_eq(stock.restock_left(), 0.0)
	stock.take(&"a")
	stock.take(&"b")
	assert_false(stock.is_full())
	assert_eq(stock.restock_left(), 0.0, "the timer starts counting on the first tick after a take")
	stock.tick(100.0, 300.0)
	assert_almost_eq(stock.restock_left(), 200.0, 0.01)
	assert_eq(stock.count(&"a"), 1, "not yet")
	stock.tick(200.0, 300.0)
	assert_true(stock.is_full())
	assert_eq(stock.count(&"a"), 2)
	assert_eq(stock.count(&"b"), 2)
	assert_eq(stock.restock_left(), 0.0)


func test_the_timer_does_not_run_while_stock_is_full() -> void:
	var stock := _stock(2)
	stock.tick(1000.0, 300.0)
	assert_true(stock.is_full())
	stock.take(&"c")
	stock.tick(10.0, 300.0)
	assert_almost_eq(stock.restock_left(), 290.0, 0.01, "it counted from the take, not from the idle time")


func test_two_stocks_never_share_state() -> void:
	var first := _stock(2)
	var second := _stock(2)
	first.take(&"a")
	assert_eq(first.count(&"a"), 1)
	assert_eq(second.count(&"a"), 2)
	first.tick(50.0, 300.0)
	assert_eq(second.restock_left(), 0.0)
