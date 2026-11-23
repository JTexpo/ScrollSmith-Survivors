extends GutTest

var _root: Node2D
var _player: Player
var _progress: RunProgress
var _counter: GoldCounter


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_progress = _player.progress
	_progress.bind(_player, PlayerProfile.new(), LevelTrack.default_track())
	_counter = load("res://scenes/ui/gold_counter.tscn").instantiate() as GoldCounter
	add_child_autofree(_counter)


func test_fresh_profile_shows_gold_zero() -> void:
	_counter.bind(_progress)
	assert_eq(_counter.gold_text(), "Gold 0")
	assert_eq(_counter.text, "Gold 0")


func test_shows_the_saved_gold_when_bound() -> void:
	_progress.profile.add_gold(250)
	_counter.bind(_progress)
	assert_eq(_counter.gold_text(), "Gold 250")


func test_follows_gold_changed() -> void:
	_counter.bind(_progress)
	_progress.add_gold(30)
	assert_eq(_counter.gold_text(), "Gold 30")
	_progress.add_gold(12)
	assert_eq(_counter.text, "Gold 42")


func test_ignores_the_mouse() -> void:
	assert_eq(_counter.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_the_counter_uses_the_outlined_gold_label() -> void:
	assert_eq(_counter.theme_type_variation, &"HudGold")
