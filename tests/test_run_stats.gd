extends GutTest
## The run tally only listens: each announcement adds exactly one to the right counter, and it stops counting at death.

var _spawner: EnemySpawner
var _director: RunDirector
var _collector: PickupCollector
var _crafting: CraftingScreen
var _belt: PotionBelt
var _progress: RunProgress
var _stats: RunStats


func before_each() -> void:
	_spawner = EnemySpawner.new()
	_director = RunDirector.new()
	_collector = PickupCollector.new()
	_crafting = (load("res://scenes/ui/crafting_screen.tscn") as PackedScene).instantiate() as CraftingScreen
	_belt = PotionBelt.new()
	_progress = RunProgress.new()
	for node in [_spawner, _director, _collector, _crafting, _belt, _progress]:
		add_child_autofree(node)
	_stats = RunStats.new()
	_stats.bind(_spawner, _director, _collector, _crafting, _belt, _progress)


func _enemy(rewards: bool = true) -> Enemy:
	var enemy := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.gives_rewards = rewards
	add_child_autofree(enemy)
	return enemy


func test_a_new_tally_is_empty() -> void:
	for counter in ["enemies", "bosses", "scrolls", "crafts", "potions", "xp", "gold"]:
		assert_eq(_stats.get(counter), 0, counter)


func test_each_event_adds_exactly_one_to_the_right_counter() -> void:
	_spawner.enemy_died.emit(_enemy())
	_director.boss_defeated.emit(1)
	_collector.collected.emit(ScrollData.new())
	_crafting.crafted.emit()
	_belt.used.emit(PotionData.new())
	assert_eq(_stats.enemies, 1)
	assert_eq(_stats.bosses, 1)
	assert_eq(_stats.scrolls, 1)
	assert_eq(_stats.crafts, 1)
	assert_eq(_stats.potions, 1)


func test_an_enemy_that_gives_no_rewards_is_not_a_defeat() -> void:
	_spawner.enemy_died.emit(_enemy(false))
	assert_eq(_stats.enemies, 0, "an Exploder that blasted itself was not defeated")


func test_a_boss_counts_as_a_boss_and_not_as_an_enemy() -> void:
	_director.boss_defeated.emit(2)
	assert_eq(_stats.bosses, 1)
	assert_eq(_stats.enemies, 0)


func test_xp_and_gold_add_the_announced_amounts() -> void:
	_collector.xp_collected.emit(5)
	_collector.xp_collected.emit(7)
	_collector.gold_collected.emit(3)
	assert_eq(_stats.xp, 12)
	assert_eq(_stats.gold, 3)


func test_nothing_counts_before_bind_and_after_freeze() -> void:
	var unbound := RunStats.new()
	_spawner.enemy_died.emit(_enemy())
	assert_eq(unbound.enemies, 0, "a tally that was never bound hears nothing")
	_stats.freeze()
	assert_true(_stats.is_frozen())
	_spawner.enemy_died.emit(_enemy())
	_collector.xp_collected.emit(9)
	assert_eq(_stats.enemies, 1)
	assert_eq(_stats.xp, 0)


func test_binding_twice_does_not_double_count() -> void:
	_stats.bind(_spawner, _director, _collector, _crafting, _belt, _progress)
	_spawner.enemy_died.emit(_enemy())
	assert_eq(_stats.enemies, 1)


func test_two_tallies_never_share_state() -> void:
	var other := RunStats.new()
	other.bind(_spawner, _director, _collector, _crafting, _belt, _progress)
	_spawner.enemy_died.emit(_enemy())
	other.freeze()
	_spawner.enemy_died.emit(_enemy())
	assert_eq(_stats.enemies, 2)
	assert_eq(other.enemies, 1)
