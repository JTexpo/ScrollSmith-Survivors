extends GutTest

const ARCHETYPE_IDS := [&"standard", &"swarmer", &"chaser", &"tank", &"ranged", &"exploder", &"support"]
const ELEMENT_IDS := [&"none", &"fire", &"thunder", &"land", &"sea"]

var _composer: EnemyComposer


func before_each() -> void:
	_composer = EnemyComposer.new()


func _a(id: StringName) -> EnemyArchetype:
	return load("res://resources/enemies/archetypes/%s.tres" % id) as EnemyArchetype


func _e(id: StringName) -> EnemyElement:
	return load("res://resources/enemies/elements/%s.tres" % id) as EnemyElement


func test_compose_builds_the_archetypes_stats() -> void:
	var tank := _a(&"tank")
	var data := _composer.compose(tank, _e(&"fire"))
	assert_eq(data.max_health, tank.max_health)
	assert_eq(data.speed, tank.speed)
	assert_eq(data.contact_damage, tank.contact_damage)
	assert_eq(data.body_scale, tank.body_scale)
	assert_eq(data.xp_reward, tank.xp_reward)
	assert_eq(data.gold_reward, tank.gold_reward)
	assert_eq(data.drop_chance_scale, tank.drop_chance_scale)
	assert_eq(data.behavior, tank.behavior)
	assert_eq(data.speed_variation, tank.speed_variation)
	assert_eq(data.offset_radius, tank.offset_radius)
	assert_eq(data.contact_cooldown, tank.contact_cooldown)
	assert_eq(data.contact_knockback, tank.contact_knockback)
	assert_eq(data.archetype_id, &"tank")


func test_the_element_supplies_only_affinity_colour_and_drops() -> void:
	var thunder := _composer.compose(_a(&"tank"), _e(&"thunder"))
	var land := _composer.compose(_a(&"tank"), _e(&"land"))
	for stat in ["max_health", "speed", "contact_damage", "body_scale", "xp_reward", "gold_reward",
			"drop_chance_scale", "speed_variation", "offset_radius", "contact_cooldown", "contact_knockback"]:
		assert_eq(thunder.get(stat), land.get(stat), stat)
	assert_eq(thunder.behavior, land.behavior)
	assert_eq(thunder.element, SpellData.Element.THUNDER)
	assert_eq(land.element, SpellData.Element.LAND)
	assert_ne(thunder.color, land.color)
	assert_ne(thunder.drop_table, land.drop_table)
	assert_ne(thunder.display_name, land.display_name)


func test_display_names() -> void:
	assert_eq(_composer.compose(_a(&"tank"), _e(&"thunder")).display_name, "Thunder Tank")
	assert_eq(_composer.compose(_a(&"tank"), _e(&"none")).display_name, "Tank")
	assert_eq(_composer.compose(_a(&"swarmer"), _e(&"fire")).display_name, "Fire Swarmer")


func test_weight_is_the_product_of_both_weights() -> void:
	assert_almost_eq(_composer.compose(_a(&"tank"), _e(&"fire")).spawn_weight, 2.0, 0.0001)
	assert_almost_eq(_composer.compose(_a(&"standard"), _e(&"none")).spawn_weight, 4.0, 0.0001)
	assert_almost_eq(_composer.compose(_a(&"standard"), _e(&"sea")).spawn_weight, 8.0, 0.0001)


func test_colour_is_the_element_colour_shaded_by_the_archetype() -> void:
	var fire := _e(&"fire")
	assert_eq(_composer.compose(_a(&"standard"), fire).color, fire.color)
	assert_eq(_composer.compose(_a(&"tank"), fire).color, fire.color.darkened(0.30))
	assert_eq(_composer.compose(_a(&"chaser"), fire).color, fire.color.lightened(0.30))
	var tank := _composer.compose(_a(&"tank"), fire).color
	var chaser := _composer.compose(_a(&"chaser"), fire).color
	assert_lt(tank.get_luminance(), chaser.get_luminance())


func test_compose_returns_the_same_instance_for_a_pair() -> void:
	var first := _composer.compose(_a(&"tank"), _e(&"fire"))
	assert_same(_composer.compose(_a(&"tank"), _e(&"fire")), first)


func test_different_pairs_are_different_instances() -> void:
	var tank := _composer.compose(_a(&"tank"), _e(&"fire"))
	assert_not_same(_composer.compose(_a(&"tank"), _e(&"sea")), tank)
	assert_not_same(_composer.compose(_a(&"chaser"), _e(&"fire")), tank)


func test_a_second_composer_has_its_own_cache() -> void:
	var other := EnemyComposer.new()
	assert_not_same(other.compose(_a(&"tank"), _e(&"fire")), _composer.compose(_a(&"tank"), _e(&"fire")))


func test_compose_never_edits_its_inputs() -> void:
	var archetype := _a(&"ranged")
	var element := _e(&"sea")
	var health := archetype.max_health
	var color := element.color
	var weight := archetype.spawn_weight
	var data := _composer.compose(archetype, element)
	data.max_health = 999.0
	data.color = Color.BLACK
	assert_eq(archetype.max_health, health)
	assert_eq(element.color, color)
	assert_eq(archetype.spawn_weight, weight)


func test_all_thirty_five_pairs_compose_with_distinct_names() -> void:
	var names := {}
	for archetype_id in ARCHETYPE_IDS:
		for element_id in ELEMENT_IDS:
			var data := _composer.compose(_a(archetype_id), _e(element_id))
			assert_not_null(data)
			assert_false(names.has(data.display_name), data.display_name)
			names[data.display_name] = true
	assert_eq(names.size(), 35)


func test_a_composed_enemy_can_be_set_up_on_the_enemy_scene() -> void:
	var data := _composer.compose(_a(&"tank"), _e(&"land"))
	var enemy := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.setup(data, Rect2(0, 0, 960, 540), RandomNumberGenerator.new())
	add_child_autofree(enemy)
	assert_eq(enemy.get_node("HealthComponent").max_health, 80.0)
	assert_eq(enemy.get_node("Body").color, data.color)
	assert_eq(enemy.get_node("HurtboxComponent").element, SpellData.Element.LAND)


func test_resources_without_an_id_are_still_cached_by_instance() -> void:
	var archetype := _a(&"standard").duplicate() as EnemyArchetype
	archetype.id = &""
	var other := _a(&"standard").duplicate() as EnemyArchetype
	other.id = &""
	var element := _e(&"fire")
	var first := _composer.compose(archetype, element)
	assert_same(_composer.compose(archetype, element), first)
	assert_not_same(_composer.compose(other, element), first)
