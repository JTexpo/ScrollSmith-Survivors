extends GutTest

var _root: Node2D


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)


func after_each() -> void:
	for sprite in get_tree().get_nodes_in_group(&"effect_sprites"):
		sprite.queue_free()


func test_a_missing_sprite_spawns_nothing() -> void:
	assert_null(EffectSprite.spawn(_root, &"no_such_effect", Vector2(10, 10), 0.0, 0.1))


func test_it_waits_then_plays_once_then_fades_and_frees() -> void:
	var sprite := EffectSprite.spawn(_root, &"fx_fire_burst", Vector2(50, 60), 0.2, 0.1)
	assert_not_null(sprite)
	assert_false(sprite.visible, "hidden while it waits")
	assert_false(sprite.is_playing())
	sprite._process(0.1)
	assert_false(sprite.visible, "still waiting")
	sprite._process(0.15)
	assert_true(sprite.visible)
	assert_true(sprite.is_playing(), "it plays once its delay is over")
	await wait_seconds(0.9)
	assert_false(is_instance_valid(sprite) and not sprite.is_queued_for_deletion(), "it frees itself after it has played and faded")


func test_it_is_never_scaled_or_rotated_even_under_a_scaled_rotated_parent() -> void:
	_root.scale = Vector2(3, 3)
	_root.rotation = 1.0
	var sprite := EffectSprite.spawn(_root, &"fx_fire_burst", Vector2(40, 40), 0.0, 0.1)
	assert_eq(sprite.scale, Vector2.ONE)
	assert_almost_eq(sprite.global_transform.get_scale().x, 1.0, 0.001)
	assert_almost_eq(sprite.global_rotation, 0.0, 0.001)


func test_its_base_sits_on_the_spot() -> void:
	var sprite := EffectSprite.spawn(_root, &"fx_fire_burst", Vector2(100, 100), 0.0, 0.1)
	var height := float(sprite.sprite_frames.get_frame_texture(&"play", 0).get_height())
	assert_almost_eq(sprite.global_position.y + height / 2.0 - 2.0, 100.0, 0.6, "the sprite stands on the spot (a few px of ground below)")
	assert_eq(sprite.global_position.x, roundf(sprite.global_position.x), "snapped to whole pixels")


func test_the_live_cap_frees_the_oldest() -> void:
	var first := EffectSprite.spawn(_root, &"fx_fire_burst", Vector2.ZERO, 5.0, 0.1)
	for i in EffectSprite.MAX_LIVE + 5:
		EffectSprite.spawn(_root, &"fx_fire_burst", Vector2(i, 0), 5.0, 0.1)
	var live := get_tree().get_nodes_in_group(&"effect_sprites").filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())
	assert_lte(live.size(), EffectSprite.MAX_LIVE)
	assert_true(first.is_queued_for_deletion(), "the oldest went first")
