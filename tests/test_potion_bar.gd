extends GutTest

var _root: Node2D
var _player: Player
var _profile: PlayerProfile
var _catalog: PotionCatalog
var _bar: PotionBar


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_profile = PlayerProfile.new()
	_catalog = PotionCatalog.default_catalog()
	_player.belt.bind(_player, _profile, _catalog)
	_bar = load("res://scenes/ui/potion_bar.tscn").instantiate() as PotionBar
	add_child_autofree(_bar)
	_bar.bind(_player.belt, _player.effects, _catalog)


func test_six_widgets_in_catalog_order_with_key_hints() -> void:
	assert_eq(_bar.widgets.size(), 6)
	var keys := ["Z", "X", "C", "V", "B", "N"]
	for i in 6:
		assert_eq(_bar.widgets[i].slot_index, i)
		assert_eq(_bar.widgets[i].key_text, keys[i])
		assert_eq(_bar.widgets[i].swatch_color, _catalog.potions[i].color)


func test_counts_follow_the_profile() -> void:
	assert_true(_bar.widgets[0].dimmed)
	_profile.add_potion(&"potion_health", 4)
	_player.belt.refresh()
	assert_eq(_bar.widgets[0].count, 4)
	assert_false(_bar.widgets[0].dimmed)
	assert_true(_bar.widgets[1].dimmed)


func test_cooldown_and_effect_follow_the_belt_and_effects() -> void:
	_profile.add_potion(&"potion_speed")
	_player.belt.use(&"potion_speed")
	assert_almost_eq(_bar.widgets[2].cooldown, 1.0, 0.0001)
	assert_almost_eq(_bar.widgets[2].effect, 1.0, 0.0001)
	assert_eq(_bar.widgets[2].count, 0)
	_player.belt._process(7.5)
	_player.effects._process(7.5)
	_bar._process(0.0)
	assert_almost_eq(_bar.widgets[2].cooldown, 1.0 - 7.5 / 30.0, 0.0001)
	assert_almost_eq(_bar.widgets[2].effect, 0.5, 0.0001)


func test_a_tap_emits_slot_pressed_with_the_index() -> void:
	watch_signals(_bar)
	_bar.widgets[3].pressed.emit(3)
	assert_signal_emitted_with_parameters(_bar, "slot_pressed", [3])


func test_selection_highlight_follows_the_belt() -> void:
	assert_true(_bar.widgets[0].selected)
	_player.belt.select(1)
	assert_false(_bar.widgets[0].selected)
	assert_true(_bar.widgets[1].selected)
	_player.belt.select(-2)
	assert_true(_bar.widgets[5].selected)


func test_the_bar_only_processes_while_something_is_running() -> void:
	assert_false(_bar.is_processing())
	_profile.add_potion(&"potion_speed")
	_player.belt.use(&"potion_speed")
	assert_true(_bar.is_processing())
	_player.belt._process(31.0)
	_player.effects._process(31.0)
	_bar._process(0.0)
	assert_false(_bar.is_processing())


func test_every_control_ignores_the_mouse() -> void:
	assert_eq(_bar.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for child in _bar.find_children("*", "Control", true, false):
		assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, str(child.name))
