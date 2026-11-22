extends GutTest

const ELEMENT_DIR := "res://resources/enemies/elements/"
## The themed drop tables now belong to the enemy elements.
const ELEMENT_ENEMIES := {
	"fire": SpellData.Element.FIRE,
	"thunder": SpellData.Element.THUNDER,
	"land": SpellData.Element.LAND,
	"sea": SpellData.Element.SEA,
}
const ENEMY_FILES := ["none", "fire", "thunder", "land", "sea"]

var _rng: RandomNumberGenerator


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 11


func _scroll(id: StringName) -> ScrollData:
	var scroll := ScrollData.new()
	scroll.id = id
	return scroll


func _entry(scroll: ScrollData, weight: float) -> DropEntry:
	var entry := DropEntry.new()
	entry.scroll = scroll
	entry.weight = weight
	return entry


func _table(chance: float, entries: Array[DropEntry]) -> DropTable:
	var table := DropTable.new()
	table.drop_chance = chance
	table.entries = entries
	return table


func _full_chance_table(element_file: String) -> DropTable:
	var element := load(ELEMENT_DIR + element_file + ".tres") as EnemyElement
	var table := element.drop_table.duplicate() as DropTable
	table.drop_chance = 1.0
	return table


func test_chance_zero_never_drops_and_one_always_drops() -> void:
	var good := _scroll(&"a")
	var never := _table(0.0, [_entry(good, 1.0)] as Array[DropEntry])
	var always := _table(1.0, [_entry(good, 1.0)] as Array[DropEntry])
	for i in 200:
		assert_null(never.roll(_rng))
		assert_eq(always.roll(_rng), good)


func test_weights_are_respected() -> void:
	var light := _scroll(&"light")
	var heavy := _scroll(&"heavy")
	var table := _table(1.0, [_entry(light, 1.0), _entry(heavy, 3.0)] as Array[DropEntry])
	var counts := {light: 0, heavy: 0}
	for i in 2000:
		counts[table.roll(_rng)] += 1
	assert_gt(counts[heavy], counts[light] * 2)


func test_unpickable_entries_are_never_picked() -> void:
	var good := _scroll(&"good")
	var scroll_less := DropEntry.new()
	var entries: Array[DropEntry] = [
		null, scroll_less, _entry(_scroll(&"zero"), 0.0), _entry(_scroll(&"negative"), -2.0), _entry(good, 1.0),
	]
	var table := _table(1.0, entries)
	for i in 300:
		assert_eq(table.roll(_rng), good)


func test_empty_and_all_unpickable_tables_return_null() -> void:
	assert_null(_table(1.0, [] as Array[DropEntry]).roll(_rng))
	var junk: Array[DropEntry] = [null, DropEntry.new(), _entry(_scroll(&"zero"), 0.0)]
	assert_null(_table(1.0, junk).roll(_rng))


func test_every_element_has_a_themed_table() -> void:
	for file in ELEMENT_ENEMIES:
		var own: int = ELEMENT_ENEMIES[file]
		var table := _full_chance_table(file)
		var base_total := 0
		var own_total := 0
		var all_total := 6000
		for i in all_total:
			var scroll := table.roll(_rng)
			if scroll.category == ScrollData.Category.BASE:
				base_total += 1
				if scroll.element == own:
					own_total += 1
		var share := float(own_total) / base_total
		assert_between(share, 0.75, 0.85, "%s own share of Base drops" % file)
		assert_lt(own_total, base_total, "%s is never guaranteed" % file)
		assert_between(float(own_total) / all_total, 0.35, 0.55, "%s own share of all drops" % file)


func test_the_no_element_enemy_favours_no_element() -> void:
	var table := _full_chance_table("none")
	var counts := {}
	var base_total := 0
	for i in 6000:
		var scroll := table.roll(_rng)
		if scroll.category == ScrollData.Category.BASE:
			base_total += 1
			counts[scroll.element] = counts.get(scroll.element, 0) + 1
	assert_eq(counts.size(), 4)
	for element in counts:
		assert_between(float(counts[element]) / base_total, 0.20, 0.30)


func test_every_catalog_scroll_can_drop() -> void:
	var seen := {}
	for file in ENEMY_FILES:
		var element := load(ELEMENT_DIR + file + ".tres") as EnemyElement
		for entry in element.drop_table.entries:
			seen[entry.scroll.id] = true
	assert_eq(seen.size(), 15)


func test_drop_chance_is_ten_percent_everywhere() -> void:
	for file in ENEMY_FILES:
		var element := load(ELEMENT_DIR + file + ".tres") as EnemyElement
		assert_eq(element.drop_table.drop_chance, 0.1, file)


func _rarity_scroll(id: StringName, rarity: ScrollData.Rarity) -> ScrollData:
	var scroll := _scroll(id)
	scroll.rarity = rarity
	return scroll


## The roll as it was before luck existed, kept here so luck 0 can be proven identical to it.
func _old_roll(table: DropTable, rng: RandomNumberGenerator) -> ScrollData:
	if table.drop_chance <= 0.0:
		return null
	var total := 0.0
	var last_pickable: DropEntry = null
	for entry in table.entries:
		if entry != null and entry.scroll != null and entry.weight > 0.0:
			total += entry.weight
			last_pickable = entry
	if last_pickable == null:
		return null
	if table.drop_chance < 1.0 and rng.randf() >= table.drop_chance:
		return null
	var pick := rng.randf() * total
	for entry in table.entries:
		if entry == null or entry.scroll == null or entry.weight <= 0.0:
			continue
		pick -= entry.weight
		if pick < 0.0:
			return entry.scroll
	return last_pickable.scroll


func _mixed_table(chance: float = 1.0) -> DropTable:
	var entries: Array[DropEntry] = [
		_entry(_rarity_scroll(&"common", ScrollData.Rarity.COMMON), 1.0),
		_entry(_rarity_scroll(&"uncommon", ScrollData.Rarity.UNCOMMON), 1.0),
		_entry(_rarity_scroll(&"rare", ScrollData.Rarity.RARE), 1.0),
	]
	return _table(chance, entries)


func test_rarity_factor_per_rarity() -> void:
	assert_eq(DropTable.rarity_factor(ScrollData.Rarity.COMMON, 1.0), 1.0)
	assert_eq(DropTable.rarity_factor(ScrollData.Rarity.UNCOMMON, 1.0), 2.0)
	assert_eq(DropTable.rarity_factor(ScrollData.Rarity.RARE, 1.0), 3.0)
	assert_eq(DropTable.rarity_factor(ScrollData.Rarity.RARE, 0.0), 1.0)


func test_rarity_factor_is_never_negative() -> void:
	assert_eq(DropTable.rarity_factor(ScrollData.Rarity.COMMON, -5.0), 1.0)
	assert_eq(DropTable.rarity_factor(ScrollData.Rarity.UNCOMMON, -5.0), 0.0)
	assert_eq(DropTable.rarity_factor(ScrollData.Rarity.RARE, -5.0), 0.0)


func test_luck_zero_gives_exactly_the_old_rolls() -> void:
	var table := _mixed_table(0.7)
	var fresh := RandomNumberGenerator.new()
	var legacy := RandomNumberGenerator.new()
	var explicit := RandomNumberGenerator.new()
	fresh.seed = 99
	legacy.seed = 99
	explicit.seed = 99
	for i in 200:
		var expected := _old_roll(table, legacy)
		assert_eq(table.roll(fresh), expected, "default luck, roll %d" % i)
		assert_eq(table.roll(explicit, 0.0), expected, "explicit luck 0, roll %d" % i)


func test_luck_raises_uncommon_and_rare_drops() -> void:
	var table := _mixed_table()
	_rng.seed = 5
	var counts := {&"common": 0, &"uncommon": 0, &"rare": 0}
	for i in 6000:
		counts[table.roll(_rng, 1.0).id] += 1
	assert_almost_eq(float(counts[&"common"]), 1000.0, 100.0)
	assert_almost_eq(float(counts[&"uncommon"]), 2000.0, 200.0)
	assert_almost_eq(float(counts[&"rare"]), 3000.0, 300.0)


func test_huge_luck_still_rolls_a_scroll() -> void:
	var table := _mixed_table()
	for i in 50:
		assert_not_null(table.roll(_rng, 1.0e9))


func test_negative_luck_never_makes_every_weight_zero() -> void:
	var entries: Array[DropEntry] = [
		_entry(_rarity_scroll(&"rare_a", ScrollData.Rarity.RARE), 1.0),
		_entry(_rarity_scroll(&"rare_b", ScrollData.Rarity.RARE), 1.0),
	]
	var table := _table(1.0, entries)
	for i in 30:
		assert_not_null(table.roll(_rng, -1.0))


func test_negative_luck_makes_rarer_scrolls_less_likely() -> void:
	var table := _mixed_table()
	var counts := {&"common": 0, &"uncommon": 0, &"rare": 0}
	for i in 3000:
		counts[table.roll(_rng, -0.5).id] += 1
	assert_gt(counts[&"common"], counts[&"uncommon"])
	assert_gt(counts[&"uncommon"], counts[&"rare"])


func test_drop_chance_is_unchanged_by_luck() -> void:
	var table := _mixed_table(0.3)
	var plain := RandomNumberGenerator.new()
	var lucky := RandomNumberGenerator.new()
	plain.seed = 17
	lucky.seed = 17
	for i in 500:
		assert_eq(table.roll(plain) == null, table.roll(lucky, 3.0) == null, "roll %d" % i)


func test_chance_scale_one_gives_exactly_the_old_rolls() -> void:
	var table := _mixed_table(0.7)
	var fresh := RandomNumberGenerator.new()
	var legacy := RandomNumberGenerator.new()
	fresh.seed = 41
	legacy.seed = 41
	for i in 200:
		assert_eq(table.roll(fresh, 0.0, 1.0), _old_roll(table, legacy), "roll %d" % i)


func test_chance_scale_raises_and_lowers_the_drop_chance() -> void:
	var table := _mixed_table(0.2)
	var counts := {}
	for scale in [0.5, 1.0, 2.0]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 8
		var drops := 0
		for i in 4000:
			if table.roll(rng, 0.0, scale) != null:
				drops += 1
		counts[scale] = drops / 4000.0
	assert_almost_eq(counts[0.5], 0.1, 0.03)
	assert_almost_eq(counts[1.0], 0.2, 0.03)
	assert_almost_eq(counts[2.0], 0.4, 0.03)


func test_chance_scale_is_clamped() -> void:
	var table := _mixed_table(0.1)
	for i in 100:
		assert_not_null(table.roll(_rng, 0.0, 100.0))
	for i in 100:
		assert_null(table.roll(_rng, 0.0, 0.0))
		assert_null(table.roll(_rng, 0.0, -3.0))


func test_chance_scale_and_luck_work_together() -> void:
	var table := _mixed_table(0.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var rares := 0
	var drops := 0
	for i in 4000:
		var scroll := table.roll(rng, 1.0, 2.0)
		if scroll != null:
			drops += 1
			if scroll.id == &"rare":
				rares += 1
	assert_almost_eq(drops / 4000.0, 0.4, 0.03)
	assert_almost_eq(float(rares) / drops, 0.5, 0.05)
