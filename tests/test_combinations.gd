extends GutTest
## Sprint 14's test list, the parts the older tests left open: every Base and Area pair really casts and spends its cost, every buff at its
## stack limit (and all of them together) builds a coherent spell, five equipped spells keep separate mana, every equipment combination
## adds up, a save round-trips every field, and a restarted run starts clean.

const ROOT := "res://.godot/save_tests"
const BASES := ["fire", "thunder", "land", "sea"]
const AREAS := ["line", "cone", "area", "missile", "wave"]
const BUFFS := ["additional_base", "damage", "double_vulnerability", "duplicate_area", "ignore_resistance", "max_mana"]

var _rules: CraftingRules
var _root: Node2D
var _dir: String


func before_each() -> void:
	_rules = CraftingRules.default_rules()
	_root = Node2D.new()
	add_child_autofree(_root)
	_dir = "%s/combos_%s" % [ROOT, str(randi())]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))


func after_each() -> void:
	var absolute := ProjectSettings.globalize_path(_dir)
	for file in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute("%s/%s" % [absolute, file])
	DirAccess.remove_absolute(absolute)


func _base(name: String) -> ScrollData:
	return load("res://resources/scrolls/base/%s.tres" % name) as ScrollData


func _area(name: String) -> ScrollData:
	return load("res://resources/scrolls/area/%s.tres" % name) as ScrollData


func _buff(name: String) -> ScrollData:
	return load("res://resources/scrolls/buff/%s.tres" % name) as ScrollData


func _normal() -> RangeOption:
	return _rules.option(_rules.normal_index())


func _loadout(spells: Array[SpellData]) -> SpellLoadout:
	var loadout := SpellLoadout.new()
	loadout.starting_spells = spells
	loadout.projectile_root = _root
	add_child_autofree(loadout)
	return loadout


func test_every_base_and_area_pair_casts_and_spends_exactly_its_cost() -> void:
	for base_name in BASES:
		for area_name in AREAS:
			var spell := SpellBuilder.build([_base(base_name)], _area(area_name), _normal())
			var spells: Array[SpellData] = [spell]
			var loadout := _loadout(spells)
			var before := loadout.slots[0].current_mana
			assert_true(loadout.try_cast(Vector2(300, 200), Vector2.RIGHT, Vector2(380, 200)), "%s %s casts" % [base_name, area_name])
			assert_almost_eq(before - loadout.slots[0].current_mana, spell.mana_cost, 0.0001, "%s %s spends its cost" % [base_name, area_name])
			loadout.queue_free()


func test_every_buff_at_its_stack_limit_builds_and_agrees_with_can_cast() -> void:
	var base_names := ["fire", "sea", "land", "thunder"]
	for buff_name in BUFFS:
		var scroll := _buff(buff_name)
		var stacks := maxi(scroll.buff.max_stacks, 1)
		var bases: Array = []
		var base_count := 1 + (stacks if buff_name == "additional_base" else 0)
		for i in base_count:
			bases.append(_base(base_names[i]))
		var buffs: Array = []
		for i in stacks:
			buffs.append(scroll)
		var spell := SpellBuilder.build(bases, _area("missile"), _normal(), buffs)
		assert_not_null(spell, "%s x%d builds" % [buff_name, stacks])
		if spell != null:
			assert_gt(spell.mana_cost, 0.0, buff_name)
			assert_eq(SpellBuilder.can_cast(spell), spell.mana_cost <= spell.max_mana, buff_name)


func test_every_buff_together_at_its_limit_builds() -> void:
	var bases: Array = [_base("fire"), _base("sea"), _base("land"), _base("thunder")]
	var buffs: Array = []
	for i in 3:
		buffs.append(_buff("additional_base"))
	for i in 4:
		buffs.append(_buff("duplicate_area"))
	for name in ["ignore_resistance", "damage", "double_vulnerability", "max_mana"]:
		buffs.append(_buff(name))
	var spell := SpellBuilder.build(bases, _area("cone"), _normal(), buffs)
	assert_not_null(spell)
	assert_eq(spell.copies, 5, "four Duplicate Area stacks add four copies")
	assert_true(spell.ignores_resistance)
	assert_gt(spell.mana_cost, 0.0)


func test_five_equipped_spells_keep_separate_mana() -> void:
	var spells: Array[SpellData] = []
	for i in 5:
		spells.append(SpellBuilder.build([_base(BASES[i % 4])], _area(AREAS[i]), _normal()))
	var loadout := _loadout(spells)
	assert_true(loadout.select(2))
	assert_true(loadout.try_cast(Vector2(300, 200), Vector2.RIGHT, Vector2(380, 200)))
	for i in 5:
		var slot: SpellInstance = loadout.slots[i]
		if i == 2:
			assert_lt(slot.current_mana, slot.max_mana(), "the cast slot paid")
		else:
			assert_eq(slot.current_mana, slot.max_mana(), "slot %d is untouched" % i)


func test_every_equipment_combination_adds_up() -> void:
	var catalog := EquipmentCatalog.default_catalog()
	var robes := catalog.items_for_slot(EquipmentData.Slot.ROBE)
	var weapons := catalog.items_for_slot(EquipmentData.Slot.WEAPON)
	var headwear := catalog.items_for_slot(EquipmentData.Slot.HEADWEAR)
	for robe in robes:
		for weapon in weapons:
			for hat in headwear:
				var profile := PlayerProfile.new()
				for item in [robe, weapon, hat]:
					profile.grant(item.id)
					profile.equipped[int(item.slot())] = item.id
				var total := ShopSystem.bonuses(profile, catalog)
				for stat in StatBonuses.Stat.values():
					var expected := 0.0
					for item in [robe, weapon, hat]:
						for modifier in item.modifiers:
							if modifier.stat == stat:
								expected += modifier.amount
					assert_almost_eq(total.fraction(stat), expected, 0.0001, "%s + %s + %s, stat %d" % [robe.id, weapon.id, hat.id, stat])


func test_save_round_trips_every_field() -> void:
	var profile := PlayerProfile.new()
	profile.total_xp = 12345
	profile.add_gold(678)
	profile.grant(&"robe_tide")
	profile.grant(&"staff_elder")
	profile.equipped[0] = &"robe_tide"
	profile.equipped[1] = &"staff_elder"
	profile.muted = true
	var path := "%s/save.json" % _dir
	assert_true(SaveGame.save_profile(profile, path))
	var loaded := SaveGame.load_profile(path)
	assert_eq(loaded.to_dict(), profile.to_dict())
	assert_true(loaded.muted)
	assert_eq(loaded.equipped_id(1), &"staff_elder")


func test_a_restarted_run_starts_clean() -> void:
	var first := (load("res://scenes/main/main.tscn") as PackedScene).instantiate() as Main
	first.save_path = ""
	(first.get_node("BuffPickScreen") as BuffPickScreen).pause_tree = false
	add_child_autofree(first)
	var player := first.get_node("Player") as Player
	player.loadout.slots[0].current_mana = 1.0
	first.run_potions.add_potion(&"potion_health", 2)
	player.health.take_damage(5.0)
	first.free()
	var second := (load("res://scenes/main/main.tscn") as PackedScene).instantiate() as Main
	second.save_path = ""
	(second.get_node("BuffPickScreen") as BuffPickScreen).pause_tree = false
	add_child_autofree(second)
	var fresh := second.get_node("Player") as Player
	assert_true(second.run_potions.is_empty(), "no potions carry over")
	assert_eq(fresh.loadout.slots[0].current_mana, fresh.loadout.slots[0].max_mana(), "the starting spell is full")
	assert_eq(fresh.health.current_health, fresh.health.max_health, "full health")
	assert_eq((second.get_node("EnemySpawner") as EnemySpawner).alive, 0, "no leftover crowd")
