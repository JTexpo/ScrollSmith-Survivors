extends GutTest

var _root: Node2D
var _player: Player
var _bar: BossBar
var _data: BossData


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_player.health.set_max_health(1.0e9)
	_data = load("res://resources/bosses/ember_titan.tres") as BossData
	_bar = load("res://scenes/ui/boss_bar.tscn").instantiate() as BossBar
	add_child_autofree(_bar)


func _boss(at: Vector2 = Vector2(100, 100)) -> Boss:
	var boss := (load("res://scenes/enemies/boss.tscn") as PackedScene).instantiate() as Boss
	boss.setup(_data, 1, null, Rect2(0, 0, 960, 540), RandomNumberGenerator.new())
	_root.add_child(boss)
	boss.global_position = at
	boss.set_physics_process(false)
	return boss


func _hit(boss: Boss, damage: float) -> void:
	(boss.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(damage, Vector2.ZERO)


func test_hidden_until_a_boss_is_shown() -> void:
	assert_false(_bar.visible)
	assert_false(_bar.is_showing())


func test_show_boss_names_it_and_fills_the_bar() -> void:
	_bar.show_boss(_boss())
	assert_true(_bar.visible)
	assert_true(_bar.is_showing())
	assert_eq(_bar.title_text(), "Ember Titan")
	assert_eq(_bar.ratio(), 1.0)


func test_the_bar_follows_the_bosses_health() -> void:
	var boss := _boss()
	_bar.show_boss(boss)
	_hit(boss, 750.0)
	assert_almost_eq(_bar.ratio(), 0.5, 0.0001)
	_hit(boss, 375.0)
	assert_almost_eq(_bar.ratio(), 0.25, 0.0001)


func test_hide_boss_hides_it() -> void:
	var boss := _boss()
	_bar.show_boss(boss)
	_bar.hide_boss()
	assert_false(_bar.visible)
	_hit(boss, 300.0)
	assert_eq(_bar.ratio(), 1.0, "a hidden bar no longer follows the boss")


func test_a_new_boss_replaces_the_old_binding_and_never_double_connects() -> void:
	var first := _boss()
	var second := _boss(Vector2(300, 100))
	_bar.show_boss(first)
	_bar.show_boss(second)
	_hit(first, 750.0)
	assert_eq(_bar.ratio(), 1.0, "the first boss is no longer followed")
	_hit(second, 750.0)
	assert_almost_eq(_bar.ratio(), 0.5, 0.0001)
	_bar.show_boss(second)
	_bar.show_boss(second)
	_hit(second, 375.0)
	assert_almost_eq(_bar.ratio(), 0.25, 0.0001)


func test_the_bar_follows_a_boss_that_dies() -> void:
	var boss := _boss()
	_bar.show_boss(boss)
	_hit(boss, 100000.0)
	assert_false(_bar.is_showing(), "a dead boss's bar goes away")


func test_it_binds_to_the_director() -> void:
	var director := RunDirector.new()
	add_child_autofree(director)
	_bar.bind(director)
	var boss := _boss()
	director.boss_spawned.emit(boss, 1)
	assert_true(_bar.is_showing())
	director.boss_defeated.emit(1)
	assert_false(_bar.is_showing())


func test_show_boss_with_a_freed_boss_is_safe() -> void:
	var boss := _boss()
	_bar.show_boss(boss)
	boss.free()
	_bar.hide_boss()
	assert_false(_bar.visible)


func test_every_control_ignores_the_mouse() -> void:
	_bar.show_boss(_boss())
	assert_eq(_bar.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for child in _bar.find_children("*", "Control", true, false):
		assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, str(child.name))
