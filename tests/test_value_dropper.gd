extends GutTest

const GEM_SCENE := "res://scenes/progression/xp_gem.tscn"
const FIRE_ENEMY := "res://tests/fixtures/enemies/fire_enemy.tres"

var _root: Node2D
var _dropper: ValueDropper


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_dropper = ValueDropper.new()
	_dropper.gem_scene = load(GEM_SCENE) as PackedScene
	_dropper.drop_root = _root
	add_child_autofree(_dropper)


func _enemy(xp: int, at: Vector2 = Vector2(40, 50)) -> Enemy:
	var enemy := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	var data := (load(FIRE_ENEMY) as EnemyData).duplicate() as EnemyData
	data.xp_reward = xp
	enemy.setup(data, Rect2(0, 0, 960, 540), RandomNumberGenerator.new())
	_root.add_child(enemy)
	enemy.global_position = at
	return enemy


func _total_value() -> int:
	var total := 0
	for gem in get_tree().get_nodes_in_group(&"xp_gems"):
		total += (gem as ValueGem).value
	return total


func test_enemy_death_drops_a_gem_with_its_xp() -> void:
	var data := load(FIRE_ENEMY) as EnemyData
	assert_eq(data.xp_reward, 4)
	var enemy := _enemy(data.xp_reward, Vector2(60, 70))
	var gem := _dropper.on_enemy_died(enemy)
	assert_not_null(gem)
	assert_eq(gem.value, 4)
	assert_eq(gem.global_position, Vector2(60, 70))
	assert_eq(_dropper.gem_count(), 1)


func test_enemy_with_zero_or_missing_xp_drops_nothing() -> void:
	assert_null(_dropper.on_enemy_died(_enemy(0)))
	assert_null(_dropper.on_enemy_died(_enemy(-3)))
	assert_null(_dropper.on_enemy_died(null))
	var bare := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	autofree(bare)
	bare.data = null
	assert_null(_dropper.on_enemy_died(bare))
	assert_eq(_dropper.gem_count(), 0)


func test_cap_merges_the_value_into_the_oldest_gem() -> void:
	_dropper.max_gems = 3
	for amount in [2, 3, 4]:
		_dropper.place(amount, Vector2(10, 10))
	var merged := _dropper.place(5, Vector2(90, 90))
	assert_eq(_dropper.gem_count(), 3)
	assert_eq(merged.value, 7)
	_dropper.place(6, Vector2(50, 50))
	assert_eq(_dropper.gem_count(), 3)
	assert_eq(_total_value(), 20)


func test_total_xp_is_never_lost_at_the_cap() -> void:
	_dropper.max_gems = 150
	var dropped := 0
	for i in 400:
		var amount := 1 + i % 7
		dropped += amount
		_dropper.place(amount, Vector2(i % 90, i % 50))
	assert_eq(_dropper.gem_count(), 150)
	assert_eq(_total_value(), dropped)


func test_collected_gems_free_their_slot() -> void:
	_dropper.max_gems = 2
	var first := _dropper.place(1, Vector2.ZERO)
	_dropper.place(2, Vector2.ZERO)
	first.collect()
	await wait_frames(2)
	assert_eq(_dropper.gem_count(), 1)
	var third := _dropper.place(3, Vector2.ZERO)
	assert_eq(third.value, 3)
	assert_eq(_dropper.gem_count(), 2)


func _gold_dropper() -> ValueDropper:
	var dropper := ValueDropper.new()
	dropper.kind = ValueGem.Kind.GOLD
	dropper.gem_scene = load("res://scenes/progression/gold_coin.tscn") as PackedScene
	dropper.drop_root = _root
	add_child_autofree(dropper)
	return dropper


func _enemy_data(path: String) -> Enemy:
	var enemy := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.setup(load(path) as EnemyData, Rect2(0, 0, 960, 540), RandomNumberGenerator.new())
	_root.add_child(enemy)
	enemy.global_position = Vector2(40, 50)
	return enemy


func test_gold_dropper_uses_the_enemys_gold_reward() -> void:
	var gold := _gold_dropper()
	assert_eq(gold.on_enemy_died(_enemy_data("res://tests/fixtures/enemies/land_enemy.tres")).value, 3)
	assert_eq(gold.on_enemy_died(_enemy_data("res://tests/fixtures/enemies/sea_enemy.tres")).value, 2)
	assert_eq(gold.on_enemy_died(_enemy_data("res://tests/fixtures/enemies/basic_enemy.tres")).value, 1)


func test_xp_dropper_reads_xp_and_the_gold_dropper_reads_gold() -> void:
	var gold := _gold_dropper()
	var enemy := _enemy_data("res://tests/fixtures/enemies/land_enemy.tres")
	assert_eq(_dropper.on_enemy_died(enemy).value, 10)
	assert_eq(gold.on_enemy_died(enemy).value, 3)
	assert_eq(get_tree().get_nodes_in_group(&"xp_gems").size(), 1)
	assert_eq(get_tree().get_nodes_in_group(&"gold_coins").size(), 1)


func test_zero_gold_reward_drops_nothing() -> void:
	var gold := _gold_dropper()
	var data := (load("res://tests/fixtures/enemies/fire_enemy.tres") as EnemyData).duplicate() as EnemyData
	data.gold_reward = 0
	var enemy := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.setup(data, Rect2(0, 0, 960, 540), RandomNumberGenerator.new())
	_root.add_child(enemy)
	assert_null(gold.on_enemy_died(enemy))


func test_gold_cap_merges_and_loses_nothing() -> void:
	var gold := _gold_dropper()
	gold.max_gems = 5
	var dropped := 0
	for i in 60:
		var amount := 1 + i % 4
		dropped += amount
		gold.place(amount, Vector2(i % 90, i % 50))
	assert_eq(gold.gem_count(), 5)
	var total := 0
	for coin in get_tree().get_nodes_in_group(&"gold_coins"):
		total += (coin as ValueGem).value
	assert_eq(total, dropped)


func test_an_elite_drops_triple_xp_and_gold() -> void:
	var enemy := _enemy(5)
	enemy.make_elite(EliteModifier.default_modifier())
	assert_eq(_dropper.on_enemy_died(enemy).value, 15)
	var gold := _gold_dropper()
	assert_eq(gold.on_enemy_died(enemy).value, 3)


func test_an_enemy_that_gives_no_rewards_drops_nothing() -> void:
	var enemy := _enemy(5)
	enemy.gives_rewards = false
	assert_null(_dropper.on_enemy_died(enemy))
	assert_null(_gold_dropper().on_enemy_died(enemy))
	assert_eq(_dropper.gem_count(), 0)


func test_the_dropper_reads_the_enemys_own_reward_not_the_datas() -> void:
	var enemy := _enemy(4)
	var scaled := EliteModifier.new()
	scaled.reward_multiplier = 2.0
	enemy.make_elite(scaled)
	assert_eq(enemy.data.xp_reward, 4)
	assert_eq(_dropper.on_enemy_died(enemy).value, 8)


func test_a_drop_offset_puts_the_pickup_beside_the_death_spot() -> void:
	_dropper.drop_offset = Vector2(7, 3)
	var gem := _dropper.on_enemy_died(_enemy(4, Vector2(60, 70)))
	assert_eq(gem.global_position, Vector2(67, 73))
	_dropper.drop_offset = Vector2.ZERO
	assert_eq(_dropper.on_enemy_died(_enemy(4, Vector2(10, 10))).global_position, Vector2(10, 10), "no offset keeps the old place")
	assert_eq(_dropper.place(3, Vector2(5, 5)).global_position, Vector2(5, 5), "place() is exact and never offset")

