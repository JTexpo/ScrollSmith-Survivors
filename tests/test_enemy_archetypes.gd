extends GutTest

const K := EnemyBehaviorData.Kind
const DIR := "res://resources/enemies/archetypes/"

## id: [name, health, speed, damage, scale, xp, gold, weight, unlock, cluster, drop scale, shade, kind]
const TABLE := {
	&"standard": ["Standard", 20.0, 40.0, 10.0, 1.0, 5, 1, 4.0, 0.0, 1, 1.0, 0.00, K.CHASE],
	&"swarmer": ["Swarmer", 8.0, 46.0, 5.0, 0.7, 2, 1, 2.0, 30.0, 5, 1.0, 0.00, K.CHASE],
	&"chaser": ["Chaser", 14.0, 80.0, 9.0, 0.9, 5, 1, 2.0, 60.0, 1, 1.0, 0.30, K.CHASE],
	&"tank": ["Tank", 80.0, 26.0, 16.0, 1.5, 12, 3, 1.0, 120.0, 1, 1.5, -0.30, K.CHASE],
	&"ranged": ["Ranged", 14.0, 34.0, 6.0, 1.0, 7, 2, 1.5, 180.0, 1, 1.0, -0.15, K.KEEP_DISTANCE],
	&"exploder": ["Exploder", 12.0, 58.0, 4.0, 1.0, 6, 1, 1.5, 240.0, 1, 1.0, 0.15, K.EXPLODE],
	&"support": ["Support", 22.0, 30.0, 4.0, 1.0, 8, 2, 1.0, 300.0, 1, 1.5, -0.05, K.SUPPORT],
}

## id: [display name, element, colour, drop table file, weight]
const ELEMENTS := {
	&"none": ["", -1, Color(0.75, 0.75, 0.75), "basic_drops", 1.0],
	&"fire": ["Fire", 0, Color(1, 0.45, 0.1), "fire_drops", 2.0],
	&"thunder": ["Thunder", 1, Color(1, 0.9, 0.2), "thunder_drops", 2.0],
	&"land": ["Land", 2, Color(0.6, 0.4, 0.2), "land_drops", 2.0],
	&"sea": ["Sea", 3, Color(0.2, 0.55, 1), "sea_drops", 2.0],
}


func _archetype(id: StringName) -> EnemyArchetype:
	return load("%s%s.tres" % [DIR, id]) as EnemyArchetype


func _element(id: StringName) -> EnemyElement:
	return load("res://resources/enemies/elements/%s.tres" % id) as EnemyElement


func test_archetype_table_matches_the_spec() -> void:
	for id in TABLE:
		var a := _archetype(id)
		var row: Array = TABLE[id]
		assert_not_null(a, str(id))
		assert_eq(a.id, id)
		assert_eq(a.display_name, row[0], str(id))
		assert_almost_eq(a.max_health, row[1], 0.0001, "%s health" % id)
		assert_almost_eq(a.speed, row[2], 0.0001, "%s speed" % id)
		assert_almost_eq(a.contact_damage, row[3], 0.0001, "%s damage" % id)
		assert_almost_eq(a.body_scale, row[4], 0.0001, "%s scale" % id)
		assert_eq(a.xp_reward, row[5], "%s xp" % id)
		assert_eq(a.gold_reward, row[6], "%s gold" % id)
		assert_almost_eq(a.spawn_weight, row[7], 0.0001, "%s weight" % id)
		assert_almost_eq(a.unlock_seconds, row[8], 0.0001, "%s unlock" % id)
		assert_eq(a.cluster_size, row[9], "%s cluster" % id)
		assert_almost_eq(a.drop_chance_scale, row[10], 0.0001, "%s drop scale" % id)
		assert_almost_eq(a.shade, row[11], 0.0001, "%s shade" % id)
		assert_eq(a.behavior.kind, row[12], "%s behaviour" % id)


func test_every_archetype_keeps_the_old_movement_and_contact_numbers() -> void:
	for id in TABLE:
		var a := _archetype(id)
		assert_almost_eq(a.speed_variation, 0.15, 0.0001, str(id))
		assert_almost_eq(a.offset_radius, 24.0, 0.0001, str(id))
		assert_almost_eq(a.contact_cooldown, 1.0, 0.0001, str(id))
		assert_almost_eq(a.contact_knockback, 80.0, 0.0001, str(id))


func test_behaviour_numbers_match_the_spec() -> void:
	var ranged := _archetype(&"ranged").behavior
	assert_almost_eq(ranged.preferred_distance, 90.0, 0.0001)
	assert_almost_eq(ranged.shoot_interval, 2.0, 0.0001)
	assert_almost_eq(ranged.projectile_speed, 110.0, 0.0001)
	assert_almost_eq(ranged.projectile_damage, 8.0, 0.0001)
	assert_almost_eq(ranged.projectile_range, 220.0, 0.0001)
	var exploder := _archetype(&"exploder").behavior
	assert_almost_eq(exploder.trigger_distance, 28.0, 0.0001)
	assert_almost_eq(exploder.fuse_time, 0.8, 0.0001)
	assert_almost_eq(exploder.blast_radius, 36.0, 0.0001)
	assert_almost_eq(exploder.blast_damage, 24.0, 0.0001)
	var support := _archetype(&"support").behavior
	assert_almost_eq(support.support_radius, 70.0, 0.0001)
	assert_almost_eq(support.heal_per_second, 6.0, 0.0001)


func test_unlock_times_and_weights() -> void:
	var unlocks := []
	for id in TABLE:
		unlocks.append(_archetype(id).unlock_seconds)
		assert_gt(_archetype(id).spawn_weight, 0.0, str(id))
	assert_eq(unlocks, [0.0, 30.0, 60.0, 120.0, 180.0, 240.0, 300.0])


func test_only_ranged_exploder_and_support_have_special_behaviour() -> void:
	for id in TABLE:
		var special := _archetype(id).behavior.kind != K.CHASE
		assert_eq(special, id in [&"ranged", &"exploder", &"support"], str(id))


func test_ids_are_unique() -> void:
	var seen := {}
	for id in TABLE:
		var a := _archetype(id)
		assert_false(seen.has(a.id))
		seen[a.id] = true


func test_element_table_matches_the_spec() -> void:
	for id in ELEMENTS:
		var e := _element(id)
		var row: Array = ELEMENTS[id]
		assert_not_null(e, str(id))
		assert_eq(e.id, id)
		assert_eq(e.display_name, row[0], str(id))
		assert_eq(e.element, row[1], "%s element" % id)
		assert_eq(e.color, row[2], "%s colour" % id)
		assert_eq(e.drop_table.resource_path, "res://resources/drops/%s.tres" % row[3], "%s drops" % id)
		assert_almost_eq(e.spawn_weight, row[4], 0.0001, "%s weight" % id)


func test_every_element_has_a_drop_table() -> void:
	for id in ELEMENTS:
		assert_not_null(_element(id).drop_table, str(id))
		assert_gt(_element(id).drop_table.entries.size(), 0, str(id))
