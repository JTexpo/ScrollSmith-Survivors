extends GutTest

const PICKUP_SCENE := "res://scenes/scrolls/scroll_pickup.tscn"
const FIRE_ENEMY := "res://resources/enemies/fire_enemy.tres"

var _root: Node2D
var _dropper: ScrollDropper
var _scroll: ScrollData


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_dropper = ScrollDropper.new()
	_dropper.pickup_scene = load(PICKUP_SCENE) as PackedScene
	_dropper.drop_root = _root
	_dropper.rng.seed = 5
	add_child_autofree(_dropper)
	_scroll = load("res://resources/scrolls/base/fire.tres") as ScrollData


func _table(chance: float, entries: Array[DropEntry]) -> DropTable:
	var table := DropTable.new()
	table.drop_chance = chance
	table.entries = entries
	return table


func _entry(scroll: ScrollData, weight: float) -> DropEntry:
	var entry := DropEntry.new()
	entry.scroll = scroll
	entry.weight = weight
	return entry


func _enemy(table: DropTable, at: Vector2 = Vector2(40, 50)) -> Enemy:
	var enemy := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	var data := (load(FIRE_ENEMY) as EnemyData).duplicate() as EnemyData
	data.drop_table = table
	enemy.setup(data, Rect2(0, 0, 960, 540), _dropper.rng)
	_root.add_child(enemy)
	enemy.global_position = at
	return enemy


func _sure_drop() -> DropTable:
	return _table(1.0, [_entry(_scroll, 1.0)] as Array[DropEntry])


func _live_pickups() -> Array[ScrollPickup]:
	var pickups: Array[ScrollPickup] = []
	for child in _root.get_children():
		if child is ScrollPickup and not child.is_queued_for_deletion():
			pickups.append(child)
	return pickups


func test_a_drop_places_one_pickup_at_the_enemys_position() -> void:
	var enemy := _enemy(_sure_drop(), Vector2(123, 45))
	var pickup := _dropper.on_enemy_died(enemy)
	assert_not_null(pickup)
	assert_eq(pickup.scroll, _scroll)
	assert_eq(pickup.global_position, Vector2(123, 45))
	assert_eq(_live_pickups().size(), 1)


func test_no_drop_places_nothing() -> void:
	assert_null(_dropper.on_enemy_died(_enemy(_table(0.0, [_entry(_scroll, 1.0)] as Array[DropEntry]))))
	assert_eq(_live_pickups().size(), 0)


func test_enemy_without_a_table_or_data_drops_nothing() -> void:
	assert_null(_dropper.on_enemy_died(_enemy(null)))
	var bare := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	bare.data = null
	_root.add_child(bare)
	assert_null(_dropper.on_enemy_died(bare))
	assert_eq(_live_pickups().size(), 0)


func test_unpickable_table_drops_nothing() -> void:
	var junk: Array[DropEntry] = [null, _entry(_scroll, 0.0), DropEntry.new()]
	assert_null(_dropper.on_enemy_died(_enemy(_table(1.0, junk))))
	assert_eq(_live_pickups().size(), 0)


func test_cap_removes_the_oldest_and_keeps_the_newest() -> void:
	_dropper.max_pickups = 3
	var made: Array[ScrollPickup] = []
	for i in 5:
		made.append(_dropper.on_enemy_died(_enemy(_sure_drop(), Vector2(10 * (i + 1), 0))))
	assert_eq(_live_pickups().size(), 3)
	for i in 2:
		assert_true(not is_instance_valid(made[i]) or made[i].is_queued_for_deletion(), "pickup %d evicted" % i)
	for i in range(2, 5):
		assert_false(made[i].is_queued_for_deletion(), "pickup %d kept" % i)


func test_pickup_count_never_exceeds_the_cap() -> void:
	_dropper.max_pickups = 5
	for i in 40:
		_dropper.on_enemy_died(_enemy(_sure_drop(), Vector2(i, 0)))
		assert_lte(_live_pickups().size(), 5)


func test_freed_pickups_do_not_count_against_the_cap() -> void:
	_dropper.max_pickups = 2
	var first := _dropper.on_enemy_died(_enemy(_sure_drop(), Vector2(10, 0)))
	var second := _dropper.on_enemy_died(_enemy(_sure_drop(), Vector2(20, 0)))
	first.collect()
	await wait_physics_frames(2)
	_dropper.on_enemy_died(_enemy(_sure_drop(), Vector2(30, 0)))
	assert_false(second.is_queued_for_deletion())
	assert_eq(_live_pickups().size(), 2)


func test_place_puts_a_pickup_down_and_counts_against_the_cap() -> void:
	_dropper.max_pickups = 2
	var first := _dropper.place(_scroll, Vector2(10, 10))
	var second := _dropper.place(_scroll, Vector2(20, 20))
	var third := _dropper.place(_scroll, Vector2(30, 30))
	assert_eq(third.global_position, Vector2(30, 30))
	assert_eq(third.scroll, _scroll)
	assert_true(first.is_queued_for_deletion())
	assert_false(second.is_queued_for_deletion())
	assert_eq(_live_pickups().size(), 2)
	assert_null(_dropper.place(null, Vector2.ZERO))


func test_the_dropper_rolls_with_its_luck() -> void:
	var common := _scroll_with_rarity(&"common", ScrollData.Rarity.COMMON)
	var rare := _scroll_with_rarity(&"rare", ScrollData.Rarity.RARE)
	var entries: Array[DropEntry] = [_entry(common, 1.0), _entry(rare, 1.0)]
	var table := _table(1.0, entries)
	_dropper.luck = 1000.0
	var rares := 0
	for i in 40:
		var pickup := _dropper.on_enemy_died(_enemy(table))
		if pickup != null and pickup.scroll == rare:
			rares += 1
	assert_gte(rares, 35)


func test_the_dropper_has_no_luck_by_default() -> void:
	assert_eq(_dropper.luck, 0.0)


func _scroll_with_rarity(id: StringName, rarity: ScrollData.Rarity) -> ScrollData:
	var scroll := ScrollData.new()
	scroll.id = id
	scroll.rarity = rarity
	return scroll


func test_an_elite_uses_its_drop_chance_scale() -> void:
	var table := _table(0.1, [_entry(_scroll, 1.0)] as Array[DropEntry])
	var elite := _enemy(table)
	var tiny := EliteModifier.new()
	tiny.drop_chance_multiplier = 1000.0
	elite.make_elite(tiny)
	for i in 20:
		assert_not_null(_dropper.on_enemy_died(elite), "an elite with a huge scale always drops")


func test_a_plain_enemy_keeps_the_tables_own_chance() -> void:
	var table := _table(0.0, [_entry(_scroll, 1.0)] as Array[DropEntry])
	var plain := _enemy(table)
	for i in 20:
		assert_null(_dropper.on_enemy_died(plain))


func test_an_enemy_that_gives_no_rewards_drops_no_scroll() -> void:
	var enemy := _enemy(_sure_drop())
	enemy.gives_rewards = false
	assert_null(_dropper.on_enemy_died(enemy))
	assert_eq(_live_pickups().size(), 0)
