extends GutTest
## Old saves held potions between runs. Potions last one run now, so those are cashed in for Gold at list price, once.

var _catalog: PotionCatalog


func before_each() -> void:
	_catalog = PotionCatalog.default_catalog()


func test_legacy_potions_are_cashed_in_at_list_price_once() -> void:
	var profile := PlayerProfile.new()
	profile.legacy_potions = {&"potion_health": 2, &"potion_mana": 1}
	var expected := 2 * _catalog.find(&"potion_health").price + _catalog.find(&"potion_mana").price
	assert_eq(ShopSystem.cash_in_legacy_potions(profile, _catalog), expected)
	assert_eq(profile.gold, expected)
	assert_true(profile.legacy_potions.is_empty())
	assert_eq(ShopSystem.cash_in_legacy_potions(profile, _catalog), 0, "a second call adds nothing")
	assert_eq(profile.gold, expected)


func test_unknown_potion_ids_are_ignored_but_still_cleared() -> void:
	var profile := PlayerProfile.new()
	profile.legacy_potions = {&"potion_removed": 5}
	assert_eq(ShopSystem.cash_in_legacy_potions(profile, _catalog), 0)
	assert_eq(profile.gold, 0)
	assert_true(profile.legacy_potions.is_empty())


func test_a_profile_with_none_gets_nothing() -> void:
	var profile := PlayerProfile.new()
	profile.add_gold(7)
	assert_eq(ShopSystem.cash_in_legacy_potions(profile, _catalog), 0)
	assert_eq(profile.gold, 7)
