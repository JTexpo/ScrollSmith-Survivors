extends GutTest

const SCENE := "res://scenes/enemies/blast_zone.tscn"

var _root: Node2D
var _player: Player
var _scene: PackedScene


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_scene = load(SCENE) as PackedScene
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_player.global_position = Vector2(300, 300)


func _zone(at: Vector2, radius: float = 40.0, damage: float = 20.0, fuse: float = 1.0) -> BlastZone:
	var zone := BlastZone.place(_root, _scene, at, radius, damage, fuse)
	zone.set_process(false)
	return zone


func _live() -> Array:
	return get_tree().get_nodes_in_group(&"blast_zones").filter(func(z): return not z.is_queued_for_deletion())


func test_it_is_harmless_before_the_fuse_ends() -> void:
	var zone := _zone(_player.global_position)
	zone._process(0.99)
	assert_eq(_player.health.current_health, 100.0)
	assert_false(zone.is_detonated())


func test_it_damages_a_player_inside_once_when_the_fuse_ends() -> void:
	var zone := _zone(_player.global_position)
	zone._process(1.0)
	assert_true(zone.is_detonated())
	assert_eq(_player.health.current_health, 80.0)


func test_it_does_not_damage_a_player_outside_the_radius() -> void:
	var zone := _zone(_player.global_position + Vector2(60, 0), 40.0)
	zone._process(1.0)
	assert_true(zone.is_detonated())
	assert_eq(_player.health.current_health, 100.0)


func test_the_edge_of_the_radius_counts_as_inside() -> void:
	var zone := _zone(_player.global_position + Vector2(40, 0), 40.0)
	zone._process(1.0)
	assert_eq(_player.health.current_health, 80.0)


func test_it_does_not_follow_the_player() -> void:
	var zone := _zone(Vector2(300, 300))
	_player.global_position = Vector2(500, 300)
	zone._process(0.5)
	assert_eq(zone.global_position, Vector2(300, 300))
	zone._process(0.5)
	assert_eq(zone.global_position, Vector2(300, 300))
	assert_eq(_player.health.current_health, 100.0)


func test_a_player_who_moves_in_just_before_the_end_is_hit_and_one_who_moves_out_is_not() -> void:
	var zone := _zone(Vector2(300, 300))
	_player.global_position = Vector2(500, 300)
	zone._process(0.9)
	_player.global_position = Vector2(310, 300)
	zone._process(0.1)
	assert_eq(_player.health.current_health, 80.0)
	var other := _zone(Vector2(300, 300))
	_player.hurtbox._process(1.0)
	_player.health.set_max_health(100.0)
	other._process(0.9)
	_player.global_position = Vector2(600, 300)
	other._process(0.1)
	assert_eq(_player.health.current_health, 100.0)


func test_it_never_hits_twice() -> void:
	var zone := _zone(_player.global_position)
	zone._process(1.0)
	_player.hurtbox._process(2.0)
	zone._process(0.05)
	zone._process(0.05)
	assert_eq(_player.health.current_health, 80.0)


func test_a_fuse_of_zero_detonates_on_the_first_process() -> void:
	var zone := _zone(_player.global_position, 40.0, 15.0, 0.0)
	zone._process(0.0)
	assert_true(zone.is_detonated())
	assert_eq(_player.health.current_health, 85.0)


func test_cancel_frees_it_without_damage_or_the_signal() -> void:
	var zone := _zone(_player.global_position)
	watch_signals(zone)
	zone._process(0.5)
	zone.cancel()
	zone._process(5.0)
	assert_true(zone.is_queued_for_deletion())
	assert_false(zone.is_detonated())
	assert_signal_not_emitted(zone, "detonated")
	assert_eq(_player.health.current_health, 100.0)


func test_detonated_is_emitted_once() -> void:
	var zone := _zone(_player.global_position)
	watch_signals(zone)
	zone._process(1.0)
	zone._process(0.05)
	zone._process(1.0)
	assert_signal_emit_count(zone, "detonated", 1)


func test_a_dead_player_is_not_hit() -> void:
	_player.health.take_damage(1000.0)
	var zone := _zone(_player.global_position)
	zone._process(1.0)
	assert_true(zone.is_detonated())
	assert_eq(_player.health.current_health, 0.0)


func test_an_invulnerable_player_takes_nothing() -> void:
	_player.hurtbox.grant_invulnerability(5.0)
	var zone := _zone(_player.global_position)
	zone._process(1.0)
	assert_eq(_player.health.current_health, 100.0)


func test_the_zone_frees_itself_shortly_after_detonating() -> void:
	var zone := _zone(_player.global_position)
	zone._process(1.0)
	assert_false(zone.is_queued_for_deletion())
	zone._process(BlastZone.FLASH_TIME + 0.01)
	assert_true(zone.is_queued_for_deletion())


func test_the_cap_frees_the_oldest_zone() -> void:
	var first := _zone(Vector2(10, 10))
	for i in BlastZone.MAX_ALIVE:
		_zone(Vector2(20 + i, 10))
	assert_true(first.is_queued_for_deletion())
	assert_eq(_live().size(), BlastZone.MAX_ALIVE)


func test_it_uses_process_deltas_not_real_time() -> void:
	var zone := _zone(_player.global_position, 40.0, 20.0, 0.3)
	await wait_seconds(0.5)
	assert_false(zone.is_detonated(), "no stepping, no detonation, however long the real wait")
	assert_eq(_player.health.current_health, 100.0)


func test_place_puts_the_zone_where_asked_with_its_numbers() -> void:
	var zone := _zone(Vector2(123, 45), 36.0, 24.0, 0.8)
	assert_eq(zone.global_position, Vector2(123, 45))
	assert_eq(zone.radius, 36.0)
	assert_eq(zone.damage, 24.0)
	assert_eq(zone.fuse_time, 0.8)
	assert_true(zone.is_in_group(&"blast_zones"))


func test_a_player_without_a_hurtbox_stand_in_is_ignored_safely() -> void:
	_player.remove_from_group(&"player")
	var stand_in := Node2D.new()
	_root.add_child(stand_in)
	stand_in.add_to_group(&"player")
	stand_in.global_position = Vector2(300, 300)
	var zone := _zone(Vector2(300, 300))
	zone._process(1.0)
	assert_true(zone.is_detonated(), "no crash with a non-Player in the group")


func test_the_cap_evicts_a_detonated_zone_before_a_live_one() -> void:
	var live_first := _zone(Vector2(10, 10))
	var spent := _zone(Vector2(500, 500), 5.0, 1.0, 0.0)
	spent._process(0.0)
	assert_true(spent.is_detonated())
	for i in BlastZone.MAX_ALIVE - 2:
		_zone(Vector2(20 + i, 10))
	assert_eq(_live().size(), BlastZone.MAX_ALIVE)
	_zone(Vector2(900, 10))
	assert_true(spent.is_queued_for_deletion(), "the zone that already blasted goes first")
	assert_false(live_first.is_queued_for_deletion(), "a zone still warning is kept")
	assert_eq(_live().size(), BlastZone.MAX_ALIVE)


func after_each() -> void:
	SpriteLibrary.root = "res://assets/sprites"


func _effects() -> Array:
	return get_tree().get_nodes_in_group(&"effect_sprites").filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())


func test_the_warning_has_two_rings_of_marks_that_scale_with_the_radius() -> void:
	var small := _zone(Vector2(100, 100), 12.0)
	var big := _zone(Vector2(500, 100), 48.0)
	assert_eq(small.outer_marks().size(), 8, "at least eight marks")
	assert_gt(big.outer_marks().size(), small.outer_marks().size(), "a bigger zone has more marks")
	assert_eq(big.inner_marks().size(), big.outer_marks().size())
	for mark in big.outer_marks():
		assert_almost_eq(mark.global_position.distance_to(big.global_position), 48.0, 1.0, "on the circle")
		assert_almost_eq(mark.global_transform.get_scale().x, 1.0, 0.001)


func test_the_inner_ring_grows_with_the_fuse() -> void:
	var zone := _zone(Vector2(100, 100), 40.0, 20.0, 1.0)
	zone._process(0.5)
	for mark in zone.inner_marks():
		assert_almost_eq(mark.global_position.distance_to(zone.global_position), 20.0, 1.5, "half way through the fuse, half way out")
	zone._process(0.4)
	for mark in zone.inner_marks():
		assert_almost_eq(mark.global_position.distance_to(zone.global_position), 36.0, 1.5)


func test_detonation_shows_the_burst_and_the_zone_still_hits_once() -> void:
	var zone := _zone(_player.global_position)
	assert_eq(_effects().size(), 0)
	zone._process(1.0)
	assert_gt(_effects().size(), 0, "a burst sprite appears")
	assert_eq(_player.health.current_health, 80.0, "and the hit is unchanged")
	assert_eq(zone.outer_marks().filter(func(mark: Sprite2D) -> bool: return mark.visible).size(), 0, "the warning marks are gone")


func test_a_cancelled_zone_shows_no_burst() -> void:
	var zone := _zone(Vector2(100, 100))
	zone._process(0.5)
	zone.cancel()
	assert_eq(_effects().size(), 0)


func test_a_zone_without_art_still_draws_its_circles() -> void:
	SpriteLibrary.root = "res://.godot/art_tests/no_such_folder"
	var zone := _zone(Vector2(100, 100), 40.0)
	assert_eq(zone.outer_marks().size(), 0)
	assert_true(zone.draws_circles(), "the old drawn warning stands in")
	zone._process(1.0)
	assert_eq(_effects().size(), 0)

