extends GutTest

const MULTIPLIER := 1.5

var _root: Node2D
var _screen: MerchantScreen
var _profile: PlayerProfile
var _catalog: PotionCatalog
var _merchant: PointOfInterest


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_merchant = (load("res://scenes/interactables/merchant.tscn") as PackedScene).instantiate() as PointOfInterest
	_root.add_child(_merchant)
	_screen = (load("res://scenes/ui/merchant_screen.tscn") as PackedScene).instantiate() as MerchantScreen
	_screen.pause_tree = false
	_screen.input_guard_msec = 0
	add_child_autofree(_screen)
	_profile = PlayerProfile.new()
	_profile.add_gold(1000)
	_catalog = PotionCatalog.default_catalog()


func after_each() -> void:
	get_tree().paused = false
	GameTime.unfreeze()


func _price(id: StringName) -> int:
	return ShopSystem.potion_price(_catalog.find(id), MULTIPLIER)


func test_it_lists_every_potion_with_the_multiplied_price_stock_and_owned_count() -> void:
	_profile.add_potion(&"potion_health", 3)
	_screen.open(_profile, _catalog, _merchant)
	assert_eq(_screen.potion_button_count(), _catalog.potions.size())
	var text := _screen.button_text(&"potion_health")
	assert_string_contains(text, "%dg" % _price(&"potion_health"))
	assert_string_contains(text, "x2")
	assert_string_contains(text, "own 3")
	assert_eq(_screen.gold_text(), "Gold 1000")


func test_a_purchase_spends_the_multiplied_gold_adds_the_potion_lowers_the_stock_and_emits_changed() -> void:
	_screen.open(_profile, _catalog, _merchant)
	watch_signals(_screen)
	_screen.activate(&"potion_health")
	assert_eq(_profile.gold, 1000 - _price(&"potion_health"))
	assert_eq(_profile.potion_count(&"potion_health"), 1)
	assert_eq(_merchant.stock.count(&"potion_health"), 1)
	assert_signal_emit_count(_screen, "changed", 1)
	assert_string_contains(_screen.message_text(), "Bought")
	assert_string_contains(_screen.button_text(&"potion_health"), "x1")


func test_a_sold_out_potion_refuses_and_changes_nothing() -> void:
	_screen.open(_profile, _catalog, _merchant)
	_screen.activate(&"potion_health")
	_screen.activate(&"potion_health")
	var gold := _profile.gold
	watch_signals(_screen)
	_screen.activate(&"potion_health")
	assert_string_contains(_screen.message_text(), "Sold out")
	assert_eq(_profile.gold, gold)
	assert_eq(_profile.potion_count(&"potion_health"), 2)
	assert_eq(_merchant.stock.count(&"potion_health"), 0)
	assert_signal_emit_count(_screen, "changed", 0)
	assert_string_contains(_screen.button_text(&"potion_health"), "sold out")


func test_not_enough_gold_refuses_and_changes_nothing() -> void:
	_profile.spend_gold(_profile.gold - (_price(&"potion_health") - 1))
	_screen.open(_profile, _catalog, _merchant)
	watch_signals(_screen)
	_screen.activate(&"potion_health")
	assert_eq(_screen.message_text(), ShopSystem.REASON_BROKE)
	assert_eq(_profile.gold, _price(&"potion_health") - 1)
	assert_eq(_profile.potion_count(&"potion_health"), 0)
	assert_eq(_merchant.stock.count(&"potion_health"), 2)
	assert_signal_emit_count(_screen, "changed", 0)


func test_a_full_potion_stack_refuses_without_taking_gold_or_stock() -> void:
	_profile.add_potion(&"potion_health", PlayerProfile.MAX_POTIONS)
	_screen.open(_profile, _catalog, _merchant)
	_screen.activate(&"potion_health")
	assert_eq(_screen.message_text(), ShopSystem.REASON_FULL)
	assert_eq(_profile.gold, 1000)
	assert_eq(_merchant.stock.count(&"potion_health"), 2)


func test_the_stock_restocks_while_the_screen_is_closed() -> void:
	_screen.open(_profile, _catalog, _merchant)
	_screen.activate(&"potion_health")
	_screen.activate(&"potion_health")
	_screen.close()
	_merchant._process(0.1)
	_merchant._process(_merchant.data.refresh_seconds)
	_screen.open(_profile, _catalog, _merchant)
	assert_eq(_merchant.stock.count(&"potion_health"), 2)
	assert_string_contains(_screen.button_text(&"potion_health"), "x2")


func test_open_and_close_emit_closed_and_cancel_closes_it() -> void:
	watch_signals(_screen)
	assert_false(_screen.is_open())
	_screen.open(_profile, _catalog, _merchant)
	assert_true(_screen.is_open())
	assert_true(_screen.visible)
	_screen.close()
	assert_false(_screen.is_open())
	assert_signal_emit_count(_screen, "closed", 1)
	_screen.open(_profile, _catalog, _merchant)
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	_screen._unhandled_input(cancel)
	assert_false(_screen.is_open())
	assert_signal_emit_count(_screen, "closed", 2)


func test_it_pauses_the_world_while_open_and_resumes_on_close() -> void:
	_screen.pause_tree = true
	_screen.open(_profile, _catalog, _merchant)
	assert_true(get_tree().paused)
	assert_true(GameTime.is_frozen())
	_screen.close()
	assert_false(get_tree().paused)
	assert_false(GameTime.is_frozen())


func test_a_press_right_after_opening_is_ignored_by_the_guard() -> void:
	_screen.input_guard_msec = 60000
	_screen.open(_profile, _catalog, _merchant)
	_screen.press(&"potion_health")
	assert_eq(_profile.potion_count(&"potion_health"), 0, "the press that opened it cannot also buy")
	_screen.input_guard_msec = 0
	_screen.press(&"potion_health")
	assert_eq(_profile.potion_count(&"potion_health"), 1)


func test_touches_are_bridged_while_open_and_ignored_while_closed() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(40, 40)
	assert_false(_screen.handle_input(touch), "closed")
	_screen.open(_profile, _catalog, _merchant)
	assert_true(_screen.handle_input(touch), "open")
	assert_false(_screen.handle_input(InputEventScreenDrag.new()), "only touches are bridged")


func test_pressing_a_button_buys_exactly_one() -> void:
	_screen.open(_profile, _catalog, _merchant)
	(_screen._buttons[&"potion_health"] as Button).pressed.emit()
	assert_eq(_profile.potion_count(&"potion_health"), 1)
	assert_eq(_merchant.stock.count(&"potion_health"), 1)
	assert_eq(_profile.gold, 1000 - _price(&"potion_health"))


func test_the_screen_sits_on_a_window_panel_and_close_is_red() -> void:
	_screen.open(_profile, _catalog, _merchant)
	assert_not_null(_screen.find_child("Window", true, false))
	var found := false
	for button in _screen.find_children("*", "Button", true, false):
		if (button as Button).text == "Close":
			found = true
			assert_eq((button as Button).theme_type_variation, &"ButtonRed")
	assert_true(found, "a Close button")


func test_every_potion_button_line_fits_its_button() -> void:
	_profile.add_potion(&"potion_health", 99)
	_screen.open(_profile, _catalog, _merchant)
	for potion in _catalog.potions:
		for line in _screen.button_text(potion.id).split("\n"):
			var width := UiFont.plain().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.SIZE).x
			assert_lte(width, MerchantScreen.BUTTON_SIZE.x - 8.0, "%s: %s" % [potion.id, line])


func test_potion_buttons_are_the_green_buy_buttons_and_no_widget_sets_a_font_size() -> void:
	_screen.open(_profile, _catalog, _merchant)
	for node in _screen.find_children("*", "Control", true, false):
		assert_false((node as Control).has_theme_font_size_override("font_size"), str(node.name))
	var buttons := _screen.find_children("*", "Button", true, false)
	var green := 0
	for button in buttons:
		if (button as Button).theme_type_variation == &"ButtonGreen":
			green += 1
	assert_eq(green, _catalog.potions.size())


func test_potion_buttons_are_big_and_the_detail_text_clears_them() -> void:
	assert_gte(MerchantScreen.BUTTON_SIZE.y, 32.0)
	assert_gt(MerchantScreen.DETAIL_TOP, MerchantScreen.GRID_POSITION.y + 2.0 * (MerchantScreen.BUTTON_SIZE.y + 1.0) - 1.0, "the detail text starts below the two button rows")


func test_the_merchant_emits_refused_for_sold_out_and_too_little_gold() -> void:
	var broke := PlayerProfile.new()
	_screen.open(broke, _catalog, _merchant)
	watch_signals(_screen)
	_screen.activate(&"potion_health")
	assert_signal_emitted(_screen, "refused")
	assert_signal_not_emitted(_screen, "changed")
