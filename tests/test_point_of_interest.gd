extends GutTest

const SCENES := {
	"health_shrine": PointOfInterestData.Kind.HEAL,
	"mana_shrine": PointOfInterestData.Kind.RESTORE_MANA,
	"treasure_chest": PointOfInterestData.Kind.LOOT,
	"rare_scroll_spot": PointOfInterestData.Kind.LOOT,
	"merchant": PointOfInterestData.Kind.MERCHANT,
}

var _root: Node2D


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)


func after_each() -> void:
	get_tree().paused = false


func _point(file: String, at: Vector2 = Vector2.ZERO) -> PointOfInterest:
	var point := (load("res://scenes/interactables/%s.tscn" % file) as PackedScene).instantiate() as PointOfInterest
	_root.add_child(point)
	point.global_position = at
	return point


func _prompt(point: PointOfInterest) -> Label:
	return point.get_node("Prompt") as Label


func test_interact_emits_used_with_the_point_and_the_actor() -> void:
	var point := _point("health_shrine")
	var seen: Array = []
	point.used.connect(func(who: PointOfInterest, actor: Node) -> void: seen.append([who, actor]))
	var actor := Node.new()
	add_child_autofree(actor)
	point.interact(actor)
	assert_eq(seen.size(), 1)
	assert_same(seen[0][0], point)
	assert_same(seen[0][1], actor)


func test_a_new_point_is_ready_and_start_cooldown_makes_it_refresh_then_ready() -> void:
	var point := _point("treasure_chest")
	assert_true(point.is_ready())
	assert_eq(point.refresh_progress(), 1.0)
	point.start_cooldown()
	assert_false(point.is_ready())
	assert_eq(point.cooldown_left, 300.0)
	assert_eq(point.refresh_progress(), 0.0)
	point._process(300.0)
	assert_true(point.is_ready())
	assert_eq(point.refresh_progress(), 1.0)


func test_the_timer_counts_down_with_process_and_stops_at_zero() -> void:
	var point := _point("health_shrine")
	point.start_cooldown()
	point._process(60.0)
	assert_almost_eq(point.cooldown_left, 120.0, 0.001)
	assert_almost_eq(point.refresh_progress(), 60.0 / 180.0, 0.001)
	point._process(500.0)
	assert_eq(point.cooldown_left, 0.0, "never below zero")


func test_the_timer_freezes_while_the_tree_is_paused() -> void:
	var point := _point("health_shrine")
	point.start_cooldown()
	get_tree().paused = true
	await wait_physics_frames(8)
	assert_eq(point.cooldown_left, 180.0)
	get_tree().paused = false


func test_two_points_from_one_data_never_share_a_timer_or_stock() -> void:
	var first := _point("health_shrine")
	var second := _point("health_shrine")
	first.start_cooldown()
	first._process(10.0)
	assert_eq(second.cooldown_left, 0.0)
	assert_true(second.is_ready())
	var shop_a := _point("merchant")
	var shop_b := _point("merchant")
	assert_true(shop_a.stock.take(&"potion_health"))
	assert_eq(shop_a.stock.count(&"potion_health"), shop_b.stock.count(&"potion_health") - 1)


func test_refresh_progress_and_the_prompt_text_follow_the_state() -> void:
	var shrine := _point("health_shrine")
	assert_eq(shrine.prompt_text(), "Health Shrine (E)")
	shrine.start_cooldown()
	assert_eq(shrine.prompt_text(), "Health Shrine 3:00")
	shrine._process(45.5)
	assert_eq(shrine.prompt_text(), "Health Shrine 2:15")
	var merchant := _point("merchant")
	assert_eq(merchant.prompt_text(), "Merchant (E)")
	merchant.stock.take(&"potion_health")
	merchant._process(30.0)
	assert_eq(merchant.prompt_text(), "Merchant (E)", "a merchant is always open")
	assert_between(merchant.refresh_progress(), 0.05, 0.15, "its ring shows the restock")


func test_a_merchant_has_stock_and_the_others_do_not() -> void:
	assert_not_null(_point("merchant").stock)
	for file in ["health_shrine", "mana_shrine", "treasure_chest", "rare_scroll_spot"]:
		assert_null(_point(file).stock, file)


func test_loot_spots_lie_on_the_ring_and_differ() -> void:
	var chest := _point("treasure_chest", Vector2(100, 100))
	var one := chest.loot_spot(0, 1)
	assert_almost_eq(one.distance_to(chest.global_position), 20.0, 0.001)
	var spots: Array[Vector2] = []
	for i in 3:
		spots.append(chest.loot_spot(i, 3))
		assert_almost_eq(spots[i].distance_to(chest.global_position), 20.0, 0.001)
	assert_ne(spots[0], spots[1])
	assert_ne(spots[1], spots[2])
	assert_ne(spots[0], spots[2])


func test_each_scene_loads_with_its_data_and_the_right_kind() -> void:
	for file in SCENES:
		var point := _point(file)
		assert_not_null(point.data, file)
		assert_eq(point.data.kind, SCENES[file], file)
		assert_true(point.is_in_group(&"points_of_interest"), file)
		assert_eq(point.collision_layer, PhysicsLayers.INTERACTABLE, file)
		assert_eq(point.collision_mask, 0, file)
	for entry in _point("rare_scroll_spot").data.scroll_table.entries:
		assert_eq(entry.scroll.rarity, ScrollData.Rarity.RARE)


func test_the_player_interaction_finds_a_point_like_a_lectern() -> void:
	var player := load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(player)
	player.global_position = Vector2(300, 300)
	var point := _point("mana_shrine", Vector2(310, 300))
	await wait_physics_frames(4)
	assert_eq(player.interaction.target(), point)
	assert_true(_prompt(point).visible)
	assert_eq(_prompt(point).text, point.prompt_text())
