extends GutTest

const DIR := "res://resources/points_of_interest/"

var _root: Node2D
var _player: Player
var _rng: RandomNumberGenerator


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_rng = RandomNumberGenerator.new()
	_rng.seed = 5


func _data(file: String) -> PointOfInterestData:
	return load(DIR + file + ".tres") as PointOfInterestData


func _hurt(fraction: float) -> void:
	_player.health.take_damage(_player.health.max_health * fraction)


func _drain_mana() -> void:
	for spell in _player.loadout.slots:
		if spell != null:
			spell.current_mana = 0.0


func _mixed_table(chance: float = 1.0) -> DropTable:
	var table := DropTable.new()
	table.drop_chance = chance
	var entries: Array[DropEntry] = []
	for rarity in [ScrollData.Rarity.COMMON, ScrollData.Rarity.UNCOMMON, ScrollData.Rarity.RARE]:
		var scroll := ScrollData.new()
		scroll.id = StringName("rarity_%d" % rarity)
		scroll.display_name = "Scroll %d" % rarity
		scroll.rarity = rarity
		var entry := DropEntry.new()
		entry.scroll = scroll
		entry.weight = 1.0
		entries.append(entry)
	table.entries = entries
	return table


func _loot(table: DropTable, gold_min: int = 0, gold_max: int = 0, count: int = 1) -> PointOfInterestData:
	var data := PointOfInterestData.new()
	data.kind = PointOfInterestData.Kind.LOOT
	data.gold_min = gold_min
	data.gold_max = gold_max
	data.scroll_count = count
	data.scroll_table = table
	return data


func test_refusal_when_dead_or_refreshing_and_never_for_a_merchant_that_is_refreshing() -> void:
	var shrine := _data("health_shrine")
	_hurt(0.5)
	assert_eq(PointOfInterestSystem.refusal(shrine, _player, 0.0), "")
	assert_eq(PointOfInterestSystem.refusal(shrine, _player, 10.0), PointOfInterestSystem.REASON_REFRESHING)
	var merchant := _data("merchant")
	assert_eq(PointOfInterestSystem.refusal(merchant, _player, 10.0), "", "a merchant is always open")
	_hurt(10.0)
	assert_true(_player.health.is_dead())
	assert_eq(PointOfInterestSystem.refusal(shrine, _player, 0.0), PointOfInterestSystem.REASON_DEAD)
	assert_eq(PointOfInterestSystem.refusal(merchant, _player, 0.0), PointOfInterestSystem.REASON_DEAD)


func test_a_health_shrine_refuses_at_full_health_and_allows_when_hurt() -> void:
	var shrine := _data("health_shrine")
	assert_eq(PointOfInterestSystem.refusal(shrine, _player, 0.0), PointOfInterestSystem.REASON_FULL_HEALTH)
	_hurt(0.2)
	assert_eq(PointOfInterestSystem.refusal(shrine, _player, 0.0), "")


func test_a_mana_shrine_refuses_when_every_spell_is_full_and_allows_when_one_is_not() -> void:
	var shrine := _data("mana_shrine")
	assert_eq(PointOfInterestSystem.refusal(shrine, _player, 0.0), PointOfInterestSystem.REASON_FULL_MANA)
	_drain_mana()
	assert_eq(PointOfInterestSystem.refusal(shrine, _player, 0.0), "")


func test_a_chest_is_never_refused_by_health_or_mana() -> void:
	assert_eq(PointOfInterestSystem.refusal(_data("treasure_chest"), _player, 0.0), "")
	assert_eq(PointOfInterestSystem.refusal(_data("rare_scroll_spot"), _player, 0.0), "")


func test_heal_restores_the_fraction_of_maximum_health_and_never_above_it() -> void:
	var shrine := _data("health_shrine")
	_hurt(0.8)
	var before := _player.health.current_health
	var result := PointOfInterestSystem.apply(shrine, _player, _rng)
	assert_almost_eq(_player.health.current_health, before + 0.5 * _player.health.max_health, 0.01)
	assert_ne(result.message, "")
	_player.health.current_health = _player.health.max_health - 5.0
	PointOfInterestSystem.apply(shrine, _player, _rng)
	assert_eq(_player.health.current_health, _player.health.max_health)


func test_restore_mana_fills_the_fraction_on_every_filled_slot() -> void:
	var crafted := SpellData.new()
	crafted.max_mana = 100.0
	crafted.mana_cost = 1.0
	_player.loadout.unlocked_slots = 2
	_player.loadout.equip(1, crafted)
	_drain_mana()
	PointOfInterestSystem.apply(_data("mana_shrine"), _player, _rng)
	for spell in _player.loadout.slots:
		if spell != null:
			assert_almost_eq(spell.current_mana, 0.5 * spell.max_mana(), 0.01)


func test_loot_rolls_gold_in_range_and_the_scroll_count() -> void:
	var chest := _data("treasure_chest")
	var allowed := {}
	for entry in chest.scroll_table.entries:
		allowed[entry.scroll.id] = true
	for i in 40:
		var result := PointOfInterestSystem.apply(chest, _player, _rng)
		assert_between(result.gold, 20, 40)
		assert_eq(result.scrolls.size(), 1)
		assert_true(allowed.has(result.scrolls[0].id))
		assert_true(result.message.contains("Gold"))
		assert_true(result.message.contains(result.scrolls[0].display_name))


func test_a_rare_spot_gives_only_rare_scrolls_and_no_gold() -> void:
	for i in 30:
		var result := PointOfInterestSystem.apply(_data("rare_scroll_spot"), _player, _rng)
		assert_eq(result.gold, 0)
		assert_eq(result.scrolls.size(), 1)
		assert_eq(result.scrolls[0].rarity, ScrollData.Rarity.RARE)
		assert_false(result.message.contains("Gold"))


func test_luck_is_passed_to_the_table() -> void:
	var data := _loot(_mixed_table())
	var plain := RandomNumberGenerator.new()
	var lucky := RandomNumberGenerator.new()
	plain.seed = 9
	lucky.seed = 9
	var rare_plain := 0
	var rare_lucky := 0
	for i in 300:
		if PointOfInterestSystem.apply(data, _player, plain, 0.0).scrolls[0].rarity == ScrollData.Rarity.RARE:
			rare_plain += 1
		if PointOfInterestSystem.apply(data, _player, lucky, 4.0).scrolls[0].rarity == ScrollData.Rarity.RARE:
			rare_lucky += 1
	assert_gt(rare_lucky, rare_plain)


func test_a_table_that_rolls_nothing_gives_an_empty_loot_without_error() -> void:
	var result := PointOfInterestSystem.apply(_loot(_mixed_table(0.0), 5, 5, 2), _player, _rng)
	assert_eq(result.scrolls.size(), 0)
	assert_eq(result.gold, 5)
	var none := PointOfInterestSystem.apply(_loot(null, 0, 0, 1), _player, _rng)
	assert_eq(none.scrolls.size(), 0)
	assert_eq(none.gold, 0)


func test_asking_for_a_refusal_changes_nothing() -> void:
	_hurt(0.4)
	_drain_mana()
	var health := _player.health.current_health
	var mana: Array[float] = []
	for spell in _player.loadout.slots:
		if spell != null:
			mana.append(spell.current_mana)
	for file in ["health_shrine", "mana_shrine", "treasure_chest", "merchant"]:
		PointOfInterestSystem.refusal(_data(file), _player, 5.0)
	assert_eq(_player.health.current_health, health)
	var i := 0
	for spell in _player.loadout.slots:
		if spell != null:
			assert_eq(spell.current_mana, mana[i])
			i += 1
