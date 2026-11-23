extends GutTest

const S := StatBonuses.Stat

var _catalog: EquipmentCatalog
var _profile: PlayerProfile


func before_each() -> void:
	_catalog = EquipmentCatalog.default_catalog()
	_profile = PlayerProfile.new()


func _snapshot() -> Dictionary:
	return _profile.to_dict().duplicate(true)


func test_buy_with_exactly_enough_gold_succeeds() -> void:
	_profile.add_gold(100)
	var result := ShopSystem.buy(_profile, _catalog, &"robe_ember")
	assert_true(result.ok)
	assert_eq(result.reason, "")
	assert_eq(result.item.id, &"robe_ember")
	assert_eq(_profile.gold, 0)
	assert_true(_profile.owns(&"robe_ember"))
	assert_eq(_profile.equipped_id(EquipmentData.Slot.ROBE), &"robe_ember")


func test_buy_with_one_gold_too_few_fails_and_changes_nothing() -> void:
	_profile.add_gold(99)
	var before := _snapshot()
	var result := ShopSystem.buy(_profile, _catalog, &"robe_ember")
	assert_false(result.ok)
	assert_eq(result.reason, ShopSystem.REASON_BROKE)
	assert_eq(_snapshot(), before)


func test_buying_twice_fails_and_charges_nothing_more() -> void:
	_profile.add_gold(300)
	ShopSystem.buy(_profile, _catalog, &"robe_ember")
	var before := _snapshot()
	var result := ShopSystem.buy(_profile, _catalog, &"robe_ember")
	assert_false(result.ok)
	assert_eq(result.reason, ShopSystem.REASON_OWNED)
	assert_eq(_snapshot(), before)
	assert_eq(_profile.gold, 200)


func test_buying_an_unknown_id_fails_and_changes_nothing() -> void:
	_profile.add_gold(500)
	var before := _snapshot()
	for id in [&"nothing", &""]:
		var result := ShopSystem.buy(_profile, _catalog, id)
		assert_false(result.ok)
		assert_eq(result.reason, ShopSystem.REASON_UNKNOWN)
		assert_null(result.item)
	assert_eq(_snapshot(), before)


func test_buy_equips_into_the_items_slot_and_keeps_the_replaced_item_owned() -> void:
	_profile.add_gold(500)
	ShopSystem.buy(_profile, _catalog, &"robe_ember")
	ShopSystem.buy(_profile, _catalog, &"robe_tide")
	assert_eq(_profile.equipped_id(EquipmentData.Slot.ROBE), &"robe_tide")
	assert_true(_profile.owns(&"robe_ember"))
	assert_eq(_profile.gold, 300)


func test_hat_and_hood_share_one_slot() -> void:
	_profile.add_gold(500)
	ShopSystem.buy(_profile, _catalog, &"hat_mana")
	ShopSystem.buy(_profile, _catalog, &"hood_swift")
	assert_eq(_profile.equipped_id(EquipmentData.Slot.HEADWEAR), &"hood_swift")
	assert_true(_profile.owns(&"hat_mana"))


func test_wand_and_staff_share_one_slot() -> void:
	_profile.add_gold(1000)
	ShopSystem.buy(_profile, _catalog, &"wand_quick")
	ShopSystem.buy(_profile, _catalog, &"staff_oak")
	assert_eq(_profile.equipped_id(EquipmentData.Slot.WEAPON), &"staff_oak")
	assert_true(_profile.owns(&"wand_quick"))


func test_equip_requires_ownership_and_costs_nothing() -> void:
	_profile.add_gold(500)
	ShopSystem.buy(_profile, _catalog, &"robe_ember")
	ShopSystem.buy(_profile, _catalog, &"robe_tide")
	var gold := _profile.gold
	var result := ShopSystem.equip(_profile, _catalog, &"robe_ember")
	assert_true(result.ok)
	assert_eq(_profile.equipped_id(EquipmentData.Slot.ROBE), &"robe_ember")
	assert_eq(_profile.gold, gold)
	var before := _snapshot()
	var not_owned := ShopSystem.equip(_profile, _catalog, &"robe_storm")
	assert_false(not_owned.ok)
	assert_eq(not_owned.reason, ShopSystem.REASON_NOT_OWNED)
	assert_eq(_snapshot(), before)


func test_equip_an_unknown_id_fails() -> void:
	var before := _snapshot()
	var result := ShopSystem.equip(_profile, _catalog, &"nothing")
	assert_false(result.ok)
	assert_eq(result.reason, ShopSystem.REASON_UNKNOWN)
	assert_eq(_snapshot(), before)


func test_unequip_empties_the_slot_and_keeps_the_item() -> void:
	_profile.add_gold(100)
	ShopSystem.buy(_profile, _catalog, &"robe_ember")
	assert_true(ShopSystem.unequip(_profile, EquipmentData.Slot.ROBE))
	assert_eq(_profile.equipped_id(EquipmentData.Slot.ROBE), &"")
	assert_true(_profile.owns(&"robe_ember"))


func test_unequip_an_empty_slot_returns_false() -> void:
	assert_false(ShopSystem.unequip(_profile, EquipmentData.Slot.WEAPON))
	assert_false(ShopSystem.unequip(_profile, 9))


func test_bonuses_sum_the_equipped_items() -> void:
	_profile.add_gold(1000)
	ShopSystem.buy(_profile, _catalog, &"robe_ember")
	ShopSystem.buy(_profile, _catalog, &"wand_quick")
	ShopSystem.buy(_profile, _catalog, &"hat_swift")
	var bonuses := ShopSystem.bonuses(_profile, _catalog)
	assert_almost_eq(bonuses.fraction(S.DAMAGE_FIRE), 0.15, 0.0001)
	assert_almost_eq(bonuses.fraction(S.CAST_SPEED), 0.25, 0.0001)
	assert_almost_eq(bonuses.fraction(S.SPELL_DAMAGE), -0.15, 0.0001)
	assert_almost_eq(bonuses.fraction(S.CAST_TWICE_CHANCE), 0.10, 0.0001)
	assert_almost_eq(bonuses.fraction(S.SPEED), 0.10, 0.0001)
	assert_eq(bonuses.fraction(S.HEALTH), 0.0)


func test_bonuses_are_empty_with_nothing_equipped() -> void:
	_profile.grant(&"robe_ember")
	var bonuses := ShopSystem.bonuses(_profile, _catalog)
	assert_eq(bonuses.fraction(S.DAMAGE_FIRE), 0.0)


func test_bonuses_skip_unowned_unknown_and_misplaced_equipped_ids() -> void:
	_profile.equip(0, &"robe_ember")
	_profile.equip(1, &"no_such_item")
	_profile.grant(&"wand_quick")
	_profile.equip(2, &"wand_quick")
	var bonuses := ShopSystem.bonuses(_profile, _catalog)
	assert_eq(bonuses.fraction(S.DAMAGE_FIRE), 0.0, "not owned")
	assert_eq(bonuses.fraction(S.CAST_SPEED), 0.0, "a wand in the headwear slot is ignored")


func test_failed_actions_never_touch_the_profile() -> void:
	_profile.add_gold(50)
	_profile.grant(&"hat_mana")
	_profile.equip(2, &"hat_mana")
	var before := _snapshot()
	ShopSystem.buy(_profile, _catalog, &"staff_elder")
	ShopSystem.buy(_profile, _catalog, &"hat_mana")
	ShopSystem.buy(_profile, _catalog, &"nothing")
	ShopSystem.equip(_profile, _catalog, &"robe_tide")
	ShopSystem.equip(_profile, _catalog, &"nothing")
	ShopSystem.unequip(_profile, EquipmentData.Slot.ROBE)
	assert_eq(_snapshot(), before)


func test_can_afford() -> void:
	var item := _catalog.find(&"robe_ember")
	_profile.add_gold(99)
	assert_false(ShopSystem.can_afford(_profile, item))
	_profile.add_gold(1)
	assert_true(ShopSystem.can_afford(_profile, item))


func _potions() -> PotionCatalog:
	return PotionCatalog.default_catalog()


func test_buy_potion_spends_gold_and_adds_one() -> void:
	_profile.add_gold(100)
	var result := ShopSystem.buy_potion(_profile, _potions(), &"potion_health")
	assert_true(result.ok)
	assert_eq(result.reason, "")
	assert_eq(result.potion.id, &"potion_health")
	assert_null(result.item)
	assert_eq(_profile.gold, 60)
	assert_eq(_profile.potion_count(&"potion_health"), 1)


func test_buy_potion_with_exactly_enough_gold_succeeds() -> void:
	_profile.add_gold(40)
	assert_true(ShopSystem.buy_potion(_profile, _potions(), &"potion_health").ok)
	assert_eq(_profile.gold, 0)


func test_buy_potion_with_one_gold_too_few_fails_and_changes_nothing() -> void:
	_profile.add_gold(39)
	var before := _snapshot()
	var result := ShopSystem.buy_potion(_profile, _potions(), &"potion_health")
	assert_false(result.ok)
	assert_eq(result.reason, ShopSystem.REASON_BROKE)
	assert_eq(_snapshot(), before)


func test_buy_potion_at_99_fails_and_changes_nothing() -> void:
	_profile.add_gold(10000)
	_profile.add_potion(&"potion_speed", 99)
	var before := _snapshot()
	var result := ShopSystem.buy_potion(_profile, _potions(), &"potion_speed")
	assert_false(result.ok)
	assert_eq(result.reason, ShopSystem.REASON_FULL)
	assert_eq(_snapshot(), before)


func test_buy_an_unknown_potion_fails_and_changes_nothing() -> void:
	_profile.add_gold(500)
	var before := _snapshot()
	for id in [&"nothing", &"", &"robe_ember"]:
		var result := ShopSystem.buy_potion(_profile, _potions(), id)
		assert_false(result.ok)
		assert_eq(result.reason, ShopSystem.REASON_UNKNOWN)
		assert_null(result.potion)
	assert_eq(_snapshot(), before)


func test_buying_a_potion_does_not_touch_equipment() -> void:
	_profile.add_gold(500)
	ShopSystem.buy(_profile, _catalog, &"robe_ember")
	var equipped := _profile.equipped.duplicate()
	var owned := _profile.owned.duplicate()
	ShopSystem.buy_potion(_profile, _potions(), &"potion_mana")
	assert_eq(_profile.equipped, equipped)
	assert_eq(_profile.owned, owned)


func test_buying_several_potions_stacks() -> void:
	_profile.add_gold(200)
	for i in 3:
		ShopSystem.buy_potion(_profile, _potions(), &"potion_speed")
	assert_eq(_profile.potion_count(&"potion_speed"), 3)
	assert_eq(_profile.gold, 110)


func test_can_afford_potion() -> void:
	var potion := _potions().find(&"potion_health")
	_profile.add_gold(39)
	assert_false(ShopSystem.can_afford_potion(_profile, potion))
	_profile.add_gold(1)
	assert_true(ShopSystem.can_afford_potion(_profile, potion))


func _priced_catalog(price: int) -> PotionCatalog:
	var catalog := PotionCatalog.new()
	var potion := PotionData.new()
	potion.id = &"priced"
	potion.price = price
	var list: Array[PotionData] = [potion]
	catalog.potions = list
	return catalog


func test_a_multiplied_price_is_rounded_up() -> void:
	var potion := PotionData.new()
	potion.price = 10
	assert_eq(ShopSystem.potion_price(potion, 1.5), 15)
	potion.price = 3
	assert_eq(ShopSystem.potion_price(potion, 1.5), 5)
	potion.price = 3
	assert_eq(ShopSystem.potion_price(potion, 1.0), 3)
	potion.price = 1
	assert_eq(ShopSystem.potion_price(potion, 1.0), 1, "a priced potion never becomes free")
	potion.price = 0
	assert_eq(ShopSystem.potion_price(potion, 1.5), 0, "a free potion stays free")


func test_buy_potion_with_a_multiplier_spends_the_multiplied_price_and_grants_one() -> void:
	_profile.add_gold(40)
	var result := ShopSystem.buy_potion(_profile, _priced_catalog(10), &"priced", 1.5)
	assert_true(result.ok)
	assert_eq(_profile.gold, 25)
	assert_eq(_profile.potion_count(&"priced"), 1)


func test_a_multiplied_purchase_refuses_when_the_gold_is_below_the_multiplied_price_and_changes_nothing() -> void:
	_profile.add_gold(14)
	var before := _snapshot()
	var result := ShopSystem.buy_potion(_profile, _priced_catalog(10), &"priced", 1.5)
	assert_false(result.ok)
	assert_eq(result.reason, ShopSystem.REASON_BROKE)
	assert_eq(_snapshot(), before)
	assert_false(ShopSystem.can_afford_potion(_profile, _priced_catalog(10).find(&"priced"), 1.5))
	_profile.add_gold(1)
	assert_true(ShopSystem.can_afford_potion(_profile, _priced_catalog(10).find(&"priced"), 1.5))


func test_a_full_potion_stack_refuses_without_taking_gold_at_any_multiplier() -> void:
	_profile.add_gold(500)
	_profile.add_potion(&"priced", PlayerProfile.MAX_POTIONS)
	var before := _snapshot()
	var result := ShopSystem.buy_potion(_profile, _priced_catalog(10), &"priced", 1.5)
	assert_false(result.ok)
	assert_eq(result.reason, ShopSystem.REASON_FULL)
	assert_eq(_snapshot(), before)


func test_the_default_multiplier_is_the_old_price() -> void:
	_profile.add_gold(10)
	var result := ShopSystem.buy_potion(_profile, _priced_catalog(10), &"priced")
	assert_true(result.ok)
	assert_eq(_profile.gold, 0)
