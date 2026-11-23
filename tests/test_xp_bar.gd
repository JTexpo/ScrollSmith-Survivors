extends GutTest

var _root: Node2D
var _player: Player
var _progress: RunProgress
var _bar: XpBar
var _track: LevelTrack


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_track = LevelTrack.default_track()
	_progress = _player.progress
	_progress.bind(_player, PlayerProfile.new(), _track)
	_bar = load("res://scenes/ui/xp_bar.tscn").instantiate() as XpBar
	add_child_autofree(_bar)


func test_fresh_profile_shows_level_one_and_empty_bar() -> void:
	_bar.bind(_progress)
	assert_eq(_bar.level_text(), "Lv 1")
	assert_eq(_bar.fill_ratio(), 0.0)


func test_halfway_to_level_two_fills_half() -> void:
	_progress.profile.total_xp = 15
	_bar.bind(_progress)
	assert_eq(_bar.level_text(), "Lv 1")
	assert_almost_eq(_bar.fill_ratio(), 0.5, 0.0001)


func test_level_twenty_shows_max_and_full_bar() -> void:
	_progress.profile.total_xp = 3990
	_bar.bind(_progress)
	assert_eq(_bar.level_text(), "Lv 20 MAX")
	assert_eq(_bar.fill_ratio(), 1.0)


func test_follows_xp_changed_from_a_run_progress() -> void:
	_bar.bind(_progress)
	_progress.add_xp(30)
	assert_eq(_bar.level_text(), "Lv 2")
	assert_eq(_bar.fill_ratio(), 0.0)
	_progress.add_xp(25)
	assert_almost_eq(_bar.fill_ratio(), 0.5, 0.0001)


func test_every_child_ignores_the_mouse() -> void:
	_bar.bind(_progress)
	assert_eq(_bar.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for child in _bar.find_children("*", "Control", true, false):
		assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, child.name)


func test_the_bar_is_a_themed_progress_bar_that_follows_the_ratio() -> void:
	_progress.profile.total_xp = 15
	_bar.bind(_progress)
	var themed := _bar.get_node("Bar") as ProgressBar
	assert_eq(themed.theme_type_variation, &"BarXp")
	assert_almost_eq(themed.value, 0.5, 0.0001)


func test_the_level_text_uses_the_outlined_hud_label() -> void:
	_bar.bind(_progress)
	var label := _bar.get_node("Level") as Label
	assert_eq(label.theme_type_variation, &"HudLabel")
	assert_eq(label.text, "Lv 1")
