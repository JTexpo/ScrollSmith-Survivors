extends GutTest

var _body: BodyView


func before_each() -> void:
	_body = BodyView.new()
	add_child_autofree(_body)


func _make_set(frames: int = 3) -> SpriteSetData:
	var set_data := SpriteSetData.new()
	set_data.sheet = ImageTexture.create_from_image(Image.create(4 * frames, 4, false, Image.FORMAT_RGBA8))
	set_data.frame_size = Vector2i(4, 4)
	var loop := SpriteAnimationData.new()
	loop.name = &"a"
	loop.first_frame = 0
	loop.last_frame = 1
	loop.fps = 10.0
	loop.loop = true
	var once := SpriteAnimationData.new()
	once.name = &"b"
	once.first_frame = 2
	once.last_frame = 2
	once.fps = 30.0
	once.loop = false
	set_data.animations = [loop, once] as Array[SpriteAnimationData]
	return set_data


func _sprite() -> AnimatedSprite2D:
	return _body.get_node("Sprite") as AnimatedSprite2D


func test_without_art_it_shows_the_fallback_square_and_never_fails() -> void:
	var fallback := _body.get_node("Fallback") as ColorRect
	_body.fallback_color = Color(0.2, 0.4, 0.6)
	assert_false(_body.set_look(&"nothing_like_this", &"fire"))
	assert_false(_body.has_art())
	assert_true(fallback.visible)
	assert_false(_sprite().visible)
	assert_eq(fallback.color, Color(0.2, 0.4, 0.6))
	_body.play(&"a")
	_body.set_outline(Color.YELLOW, true)
	_body.set_facing(-1.0)
	_body.set_tint(Color.RED)
	_body.counter_scale(Vector2(1.5, 1.5))
	assert_eq(_body.current_animation(), &"")
	assert_false((_body.get_node("Outline") as Node2D).visible)


func test_set_set_shows_the_sprite_and_hides_the_fallback() -> void:
	_body.set_set(_make_set())
	assert_true(_body.has_art())
	assert_true(_sprite().visible)
	assert_false((_body.get_node("Fallback") as ColorRect).visible)
	assert_true(_body.has_animation(&"a"))
	assert_false(_body.has_animation(&"z"))


func test_play_switches_animation_and_does_not_restart_the_same_one() -> void:
	_body.set_set(_make_set())
	_body.play(&"a")
	assert_eq(_body.current_animation(), &"a")
	_sprite().frame = 1
	_body.play(&"a")
	assert_eq(_sprite().frame, 1, "playing the same animation again must not restart it")
	_body.play(&"b")
	assert_eq(_body.current_animation(), &"b")


func test_playing_a_missing_animation_keeps_the_current_one() -> void:
	_body.set_set(_make_set())
	_body.play(&"a")
	_body.play(&"nonsense")
	assert_eq(_body.current_animation(), &"a")


func test_facing_flips_by_the_sign_and_zero_keeps_it() -> void:
	_body.set_set(_make_set())
	_body.set_facing(-3.0)
	assert_true(_sprite().flip_h)
	_body.set_facing(0.0)
	assert_true(_sprite().flip_h, "zero keeps the last facing")
	_body.set_facing(2.0)
	assert_false(_sprite().flip_h)


func test_the_tint_and_the_flash_do_not_fight() -> void:
	_body.set_set(_make_set())
	var tint := Color(0.5, 0.5, 1.0)
	_body.set_tint(tint)
	# HitFlashComponent sets the target's modulate and then puts it back to white.
	_body.modulate = Color(2, 2, 2, 1)
	assert_eq(_sprite().self_modulate, tint, "the flash does not touch the tint")
	_body.modulate = Color.WHITE
	assert_eq(_sprite().self_modulate, tint, "and the tint survives the flash ending")
	var shown := _body.modulate * _sprite().self_modulate
	assert_eq(shown, tint)


func test_a_once_animation_emits_done_exactly_once() -> void:
	_body.set_set(_make_set())
	watch_signals(_body)
	_body.play(&"b")
	await wait_seconds(0.6)
	assert_signal_emit_count(_body, "animation_done", 1)
	assert_signal_emitted_with_parameters(_body, "animation_done", [&"b"])


func test_a_looping_animation_never_emits_done() -> void:
	_body.set_set(_make_set())
	watch_signals(_body)
	_body.play(&"a")
	await wait_seconds(0.6)
	assert_signal_not_emitted(_body, "animation_done")


func test_the_outline_uses_the_silhouette_in_its_color_and_hides_when_disabled() -> void:
	var outline := _body.get_node("Outline") as AnimatedSprite2D
	_body.set_set(_make_set())
	_body.set_outline(Color.YELLOW, true)
	assert_false(outline.visible, "no silhouette yet")
	_body.set_outline_set(_make_set())
	_body.set_outline(Color.YELLOW, true)
	assert_true(outline.visible)
	assert_eq(outline.self_modulate, Color.YELLOW)
	_body.set_outline(Color.YELLOW, false)
	assert_false(outline.visible)


func test_counter_scale_keeps_the_sprite_one_to_one_but_not_the_fallback() -> void:
	_body.set_set(_make_set())
	_body.set_outline_set(_make_set())
	_body.counter_scale(Vector2(1.5, 1.5))
	assert_almost_eq(_sprite().scale.x, 1.0 / 1.5, 0.0001)
	assert_almost_eq((_body.get_node("Outline") as Node2D).scale.y, 1.0 / 1.5, 0.0001)
	assert_eq((_body.get_node("Fallback") as Control).scale, Vector2.ONE, "the fallback square still scales with its owner")


func test_it_ignores_the_mouse() -> void:
	for child in _body.get_children():
		if child is Control:
			assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, child.name)


func test_set_sprite_material_applies_to_the_sprite_and_its_outline() -> void:
	var material := ShaderMaterial.new()
	_body.set_sprite_material(material)
	assert_eq(_sprite().material, material)
	assert_eq((_body.get_node("Outline") as AnimatedSprite2D).material, material)

