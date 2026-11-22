extends GutTest

var _screen: ShopScreen
var _profile: PlayerProfile
var _catalog: EquipmentCatalog


func before_each() -> void:
	_screen = load("res://scenes/ui/shop_screen.tscn").instantiate() as ShopScreen
	add_child_autofree(_screen)
	_profile = PlayerProfile.new()
	_catalog = EquipmentCatalog.default_catalog()


func test_starts_closed_and_hidden() -> void:
	assert_false(_screen.is_open())
	assert_false(_screen.visible)


func test_open_lists_every_catalog_item() -> void:
	_screen.open(_profile, _catalog)
	assert_true(_screen.is_open())
	assert_true(_screen.visible)
	assert_eq(_screen.item_button_count(), 15)
	assert_eq(_screen.gold_text(), "Gold 0")


func test_buy_through_the_screen_spends_gold_and_emits_changed() -> void:
	_profile.add_gold(500)
	_screen.open(_profile, _catalog)
	watch_signals(_screen)
	_screen.buy(&"robe_ember")
	assert_eq(_profile.gold, 400)
	assert_true(_profile.owns(&"robe_ember"))
	assert_eq(_profile.equipped_id(EquipmentData.Slot.ROBE), &"robe_ember")
	assert_signal_emit_count(_screen, "changed", 1)
	assert_eq(_screen.gold_text(), "Gold 400")
	assert_string_contains(_screen.message_text(), "Ember Robe")


func test_failed_buy_shows_the_reason_and_emits_nothing() -> void:
	_profile.add_gold(99)
	_screen.open(_profile, _catalog)
	watch_signals(_screen)
	_screen.buy(&"robe_ember")
	assert_eq(_screen.message_text(), ShopSystem.REASON_BROKE)
	assert_signal_not_emitted(_screen, "changed")
	assert_eq(_profile.gold, 99)
	assert_false(_profile.owns(&"robe_ember"))


func test_equip_and_unequip_through_the_screen() -> void:
	_profile.add_gold(500)
	_screen.open(_profile, _catalog)
	_screen.buy(&"robe_ember")
	_screen.buy(&"robe_tide")
	watch_signals(_screen)
	_screen.equip(&"robe_ember")
	assert_eq(_profile.equipped_id(EquipmentData.Slot.ROBE), &"robe_ember")
	_screen.unequip(EquipmentData.Slot.ROBE)
	assert_eq(_profile.equipped_id(EquipmentData.Slot.ROBE), &"")
	assert_true(_profile.owns(&"robe_ember"))
	assert_signal_emit_count(_screen, "changed", 2)


func test_unequip_an_empty_slot_emits_nothing() -> void:
	_screen.open(_profile, _catalog)
	watch_signals(_screen)
	_screen.unequip(EquipmentData.Slot.WEAPON)
	assert_signal_not_emitted(_screen, "changed")


func test_activate_buys_then_equips_then_unequips() -> void:
	_profile.add_gold(500)
	_screen.open(_profile, _catalog)
	_screen.activate(&"robe_ember")
	assert_true(_profile.owns(&"robe_ember"))
	assert_eq(_profile.equipped_id(EquipmentData.Slot.ROBE), &"robe_ember")
	_screen.activate(&"robe_ember")
	assert_eq(_profile.equipped_id(EquipmentData.Slot.ROBE), &"")
	_screen.activate(&"robe_ember")
	assert_eq(_profile.equipped_id(EquipmentData.Slot.ROBE), &"robe_ember")
	assert_eq(_profile.gold, 400, "owning it again costs nothing")


func test_gold_text_follows_purchases() -> void:
	_profile.add_gold(250)
	_screen.open(_profile, _catalog)
	_screen.buy(&"wand_quick")
	assert_eq(_screen.gold_text(), "Gold 50")


func test_close_emits_closed_and_cancel_closes() -> void:
	_screen.open(_profile, _catalog)
	watch_signals(_screen)
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	_screen._unhandled_input(cancel)
	assert_false(_screen.is_open())
	assert_signal_emit_count(_screen, "closed", 1)
	_screen.close()
	assert_signal_emit_count(_screen, "closed", 1)


func test_touch_event_is_bridged_while_open() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(40, 40)
	assert_false(_screen.handle_input(touch), "closed")
	_screen.open(_profile, _catalog)
	assert_true(_screen.handle_input(touch), "open")
	assert_false(_screen.handle_input(InputEventScreenDrag.new()), "only touches are bridged")


func test_button_labels_show_price_owned_and_equipped() -> void:
	_profile.add_gold(500)
	_screen.open(_profile, _catalog)
	assert_string_contains(_screen.button_text(&"robe_ember"), "Ember Robe")
	assert_string_contains(_screen.button_text(&"robe_ember"), "100")
	_screen.buy(&"robe_ember")
	assert_string_contains(_screen.button_text(&"robe_ember"), "equipped")
	_screen.buy(&"robe_tide")
	assert_string_contains(_screen.button_text(&"robe_ember"), "owned")
	assert_string_contains(_screen.button_text(&"robe_tide"), "equipped")


func test_reopening_shows_the_current_profile() -> void:
	_profile.add_gold(120)
	_screen.open(_profile, _catalog)
	_screen.buy(&"robe_warded")
	_screen.close()
	_screen.open(_profile, _catalog)
	assert_string_contains(_screen.button_text(&"robe_warded"), "equipped")
	assert_eq(_screen.gold_text(), "Gold 0")


func test_every_non_button_control_ignores_the_mouse() -> void:
	_screen.open(_profile, _catalog)
	for child in _screen.find_children("*", "Control", true, false):
		if child is Button:
			continue
		if child.get_parent() == _screen:
			continue
		assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, str(child.name))


func test_item_presses_inside_the_input_guard_do_nothing() -> void:
	_profile.add_gold(500)
	_screen.input_guard_msec = 300
	_screen.open(_profile, _catalog)
	watch_signals(_screen)
	_screen._on_item_pressed(&"robe_ember")
	assert_false(_profile.owns(&"robe_ember"))
	assert_eq(_profile.gold, 500)
	assert_signal_not_emitted(_screen, "changed")
	_screen.input_guard_msec = 0
	_screen._on_item_pressed(&"robe_ember")
	assert_true(_profile.owns(&"robe_ember"))
	assert_eq(_profile.gold, 400)


func test_the_close_button_works_inside_the_input_guard() -> void:
	_screen.input_guard_msec = 300
	_screen.open(_profile, _catalog)
	var close := _screen.find_children("*", "Button", true, false).filter(func(b): return b.text == "Close")[0] as Button
	close.pressed.emit()
	assert_false(_screen.is_open())


func test_open_lists_the_six_potions() -> void:
	_screen.open(_profile, _catalog)
	assert_eq(_screen.potion_button_count(), 6)
	assert_eq(_screen.item_button_count(), 15, "the equipment list is unchanged")
	assert_string_contains(_screen.potion_button_text(&"potion_health"), "Health")
	assert_string_contains(_screen.potion_button_text(&"potion_health"), "40g")
	assert_string_contains(_screen.potion_button_text(&"potion_health"), "x0")


func test_buy_potion_through_the_screen_spends_gold_adds_one_and_emits_changed() -> void:
	_profile.add_gold(100)
	_screen.open(_profile, _catalog)
	watch_signals(_screen)
	_screen.buy_potion(&"potion_health")
	assert_eq(_profile.gold, 60)
	assert_eq(_profile.potion_count(&"potion_health"), 1)
	assert_signal_emit_count(_screen, "changed", 1)
	assert_eq(_screen.gold_text(), "Gold 60")
	assert_string_contains(_screen.message_text(), "Health")


func test_failed_potion_buy_shows_the_reason_and_emits_nothing() -> void:
	_profile.add_gold(39)
	_screen.open(_profile, _catalog)
	watch_signals(_screen)
	_screen.buy_potion(&"potion_health")
	assert_eq(_screen.message_text(), ShopSystem.REASON_BROKE)
	assert_signal_not_emitted(_screen, "changed")
	assert_eq(_profile.potion_count(&"potion_health"), 0)
	assert_eq(_profile.gold, 39)


func test_potion_labels_show_the_count_and_update() -> void:
	_profile.add_gold(500)
	_screen.open(_profile, _catalog)
	_screen.buy_potion(&"potion_speed")
	_screen.buy_potion(&"potion_speed")
	assert_string_contains(_screen.potion_button_text(&"potion_speed"), "x2")
	assert_string_contains(_screen.potion_button_text(&"potion_luck"), "x0")


func test_buying_a_potion_does_not_change_equipment() -> void:
	_profile.add_gold(500)
	_screen.open(_profile, _catalog)
	_screen.buy(&"robe_ember")
	var equipped := _profile.equipped.duplicate()
	_screen.buy_potion(&"potion_mana")
	assert_eq(_profile.equipped, equipped)
	assert_eq(_profile.owned, [&"robe_ember"] as Array[StringName])


func test_potion_presses_inside_the_input_guard_do_nothing() -> void:
	_profile.add_gold(500)
	_screen.input_guard_msec = 300
	_screen.open(_profile, _catalog)
	watch_signals(_screen)
	_screen._on_potion_pressed(&"potion_health")
	assert_eq(_profile.potion_count(&"potion_health"), 0)
	assert_eq(_profile.gold, 500)
	assert_signal_not_emitted(_screen, "changed")
	_screen.input_guard_msec = 0
	_screen._on_potion_pressed(&"potion_health")
	assert_eq(_profile.potion_count(&"potion_health"), 1)


func test_potion_buy_stops_at_99() -> void:
	_profile.add_gold(100000)
	_profile.add_potion(&"potion_health", 98)
	_screen.open(_profile, _catalog)
	_screen.buy_potion(&"potion_health")
	assert_eq(_profile.potion_count(&"potion_health"), 99)
	var gold := _profile.gold
	_screen.buy_potion(&"potion_health")
	assert_eq(_profile.potion_count(&"potion_health"), 99)
	assert_eq(_profile.gold, gold)
	assert_eq(_screen.message_text(), ShopSystem.REASON_FULL)


func test_a_custom_potion_catalog_can_be_passed() -> void:
	var small := PotionCatalog.new()
	small.potions = [PotionCatalog.default_catalog().potions[0]] as Array[PotionData]
	_screen.open(_profile, _catalog, small)
	assert_eq(_screen.potion_button_count(), 1)


func test_reopening_shows_the_current_potion_counts() -> void:
	_profile.add_gold(200)
	_screen.open(_profile, _catalog)
	_screen.buy_potion(&"potion_damage")
	_screen.close()
	_screen.open(_profile, _catalog)
	assert_string_contains(_screen.potion_button_text(&"potion_damage"), "x1")
