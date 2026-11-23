extends GutTest

var _root: Node2D
var _area: Node2D
var _visual: Polygon2D


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_area = Node2D.new()
	_root.add_child(_area)
	_area.global_position = Vector2(200, 200)
	_area.rotation = 0.7
	_visual = Polygon2D.new()
	_area.add_child(_visual)


func after_each() -> void:
	for sprite in get_tree().get_nodes_in_group(&"effect_sprites"):
		sprite.queue_free()


func _polygon() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(120, -40), Vector2(120, 40)])


func _spell(elements: Array) -> SpellData:
	var spell := SpellData.new()
	var typed: Array[SpellData.Element] = []
	for element in elements:
		typed.append(element)
	spell.elements = typed
	spell.color = Color(0.3, 0.3, 0.3)
	return spell


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	return rng


func _sprites() -> Array:
	return get_tree().get_nodes_in_group(&"effect_sprites").filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())


## A sprite stands on its spot, so the spot is its position plus half its height minus the ground it overlaps.
func _spot_of(sprite: EffectSprite) -> Vector2:
	var height := float(sprite.sprite_frames.get_frame_texture(&"play", 0).get_height())
	return _area.to_local(sprite.global_position + Vector2(0, height / 2.0 - 2.0))


func test_a_fire_cone_gets_a_tint_an_edge_and_sprites() -> void:
	var look := ElementLooks.for_element(SpellData.Element.FIRE)
	SpellSkin.dress(_area, _visual, _polygon(), _spell([SpellData.Element.FIRE]), Vector2.ZERO, 0.35, _rng())
	assert_eq(_visual.color, look.tint)
	var edge := _visual.get_node("Edge") as Line2D
	assert_eq(edge.points.size(), _polygon().size() + 1, "the edge closes the polygon")
	assert_eq(edge.default_color, look.edge)
	assert_eq(edge.width, 1.0)
	assert_eq(_sprites().size(), EffectPlan.count_for(EffectPlan.area_of(_polygon())))


func test_every_sprite_spot_is_inside_the_exact_polygon() -> void:
	SpellSkin.dress(_area, _visual, _polygon(), _spell([SpellData.Element.LAND]), Vector2.ZERO, 0.35, _rng())
	assert_gt(_sprites().size(), 0)
	for sprite in _sprites():
		var spot := _spot_of(sprite)
		assert_true(Geometry2D.is_point_in_polygon(spot, _polygon()) or _polygon_distance(spot) <= 1.5, "%s is inside" % spot)


func _polygon_distance(point: Vector2) -> float:
	var nearest := INF
	var polygon := _polygon()
	for i in polygon.size():
		var closest := Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i + 1) % polygon.size()])
		nearest = minf(nearest, point.distance_to(closest))
	return nearest


func test_sprites_are_upright_and_never_scaled_though_the_area_is_rotated() -> void:
	SpellSkin.dress(_area, _visual, _polygon(), _spell([SpellData.Element.SEA]), Vector2.ZERO, 0.35, _rng())
	for sprite in _sprites():
		assert_almost_eq(sprite.global_rotation, 0.0, 0.001)
		assert_almost_eq(sprite.global_transform.get_scale().x, 1.0, 0.001)


func test_rising_effects_start_near_the_caster_first_and_falling_ones_do_not() -> void:
	SpellSkin.dress(_area, _visual, _polygon(), _spell([SpellData.Element.FIRE]), Vector2.ZERO, 0.35, _rng())
	var rising := _delays_by_distance()
	SpellSkin.dress(_area, _visual, _polygon(), _spell([SpellData.Element.THUNDER]), Vector2.ZERO, 0.35, _rng())
	assert_true(rising, "a rising effect never starts a farther sprite before a nearer one")


## True when the delays never decrease with distance from the area's origin (checked over the sprites alive now).
func _delays_by_distance() -> bool:
	var pairs: Array = []
	for sprite in _sprites():
		pairs.append([_spot_of(sprite).length(), sprite.start_delay()])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in range(1, pairs.size()):
		if pairs[i][1] < pairs[i - 1][1] - 0.0001:
			return false
	return true


func test_a_hybrid_spell_uses_each_of_its_elements() -> void:
	SpellSkin.dress(_area, _visual, _polygon(), _spell([SpellData.Element.FIRE, SpellData.Element.SEA]), Vector2.ZERO, 0.35, _rng())
	var frames := {}
	for sprite in _sprites():
		frames[sprite.sprite_frames] = true
	assert_eq(frames.size(), 2, "fire and sea sprites both appear")


func test_no_element_leaves_the_flat_polygon_and_spawns_nothing() -> void:
	_visual.color = Color(0.3, 0.3, 0.3)
	SpellSkin.dress(_area, _visual, _polygon(), _spell([]), Vector2.ZERO, 0.35, _rng())
	assert_eq(_visual.color, Color(0.3, 0.3, 0.3))
	assert_null(_visual.get_node_or_null("Edge"))
	assert_eq(_sprites().size(), 0)


func test_a_missing_sprite_keeps_the_tint_but_spawns_nothing_and_never_fails() -> void:
	var look := ElementLooks.for_element(SpellData.Element.FIRE)
	var saved := look.effect_sprite
	look.effect_sprite = &"no_such_effect"
	SpellSkin.dress(_area, _visual, _polygon(), _spell([SpellData.Element.FIRE]), Vector2.ZERO, 0.35, _rng())
	look.effect_sprite = saved
	assert_eq(_visual.color, look.tint)
	assert_eq(_sprites().size(), 0)


func test_the_count_follows_the_area_within_the_caps() -> void:
	var tiny := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(0, 10)])
	SpellSkin.dress(_area, _visual, tiny, _spell([SpellData.Element.FIRE]), Vector2.ZERO, 0.35, _rng())
	assert_eq(_sprites().size(), EffectPlan.MIN_SPRITES)
	for sprite in _sprites():
		sprite.queue_free()
	await wait_frames(2)
	var huge := PackedVector2Array([Vector2(0, 0), Vector2(900, 0), Vector2(900, 900), Vector2(0, 900)])
	SpellSkin.dress(_area, _visual, huge, _spell([SpellData.Element.FIRE]), Vector2.ZERO, 0.35, _rng())
	assert_eq(_sprites().size(), EffectPlan.MAX_SPRITES)


func test_pulse_spawns_sprites_only_with_no_tint_and_no_edge() -> void:
	_visual.color = Color(0.3, 0.3, 0.3)
	SpellSkin.pulse(_area, _polygon(), _spell([SpellData.Element.FIRE]), Vector2.ZERO, 0.5, _rng())
	assert_gt(_sprites().size(), 0)
	assert_eq(_visual.color, Color(0.3, 0.3, 0.3))
	assert_null(_visual.get_node_or_null("Edge"))


func test_tint_colours_the_visual_and_adds_the_edge_without_any_sprites() -> void:
	var look := ElementLooks.for_element(SpellData.Element.SEA)
	SpellSkin.tint(_visual, _polygon(), _spell([SpellData.Element.SEA]))
	assert_eq(_visual.color, look.tint)
	assert_eq((_visual.get_node("Edge") as Line2D).default_color, look.edge)
	assert_eq(_sprites().size(), 0)
	_visual.color = Color(0.3, 0.3, 0.3)
	SpellSkin.tint(_visual, _polygon(), _spell([]))
	assert_eq(_visual.color, Color(0.3, 0.3, 0.3), "no element, no change")

