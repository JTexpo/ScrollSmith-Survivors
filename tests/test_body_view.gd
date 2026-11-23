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


func _shadow() -> Sprite2D:
	return _body.get_node_or_null("Shadow") as Sprite2D


func test_a_shadow_is_drawn_behind_the_sprite_below_its_feet() -> void:
	_body.shadow_enabled = true
	_body.set_look(&"player")
	var shadow := _shadow()
	assert_not_null(shadow)
	assert_true(shadow.visible)
	assert_lt(shadow.get_index(), _sprite().get_index(), "the shadow is under the sprite")
	assert_lt(shadow.get_index(), (_body.get_node("Outline") as Node).get_index(), "and under the elite outline")
	assert_gt(shadow.modulate.a, 0.0)
	assert_lt(shadow.modulate.a, 1.0, "a soft shadow, not a black blob")
	assert_gt(shadow.position.y, 0.0, "on the ground, below the middle of the sprite")


func test_there_is_no_shadow_when_disabled_or_when_there_is_no_art() -> void:
	_body.set_look(&"player")
	assert_true(_shadow() == null or not _shadow().visible, "a body shadows only when asked")
	var other := BodyView.new()
	add_child_autofree(other)
	other.shadow_enabled = true
	assert_false(other.set_look(&"no_such_sprite"))
	assert_true(other.get_node_or_null("Shadow") == null or not (other.get_node("Shadow") as Sprite2D).visible, "no art, no shadow")


func test_the_shadow_is_as_wide_as_the_sprite_allows() -> void:
	_body.shadow_enabled = true
	_body.set_look(&"player")
	var player_width := _body.shadow_width()
	_body.set_look(&"enemy_swarmer", &"none")
	var swarmer_width := _body.shadow_width()
	_body.set_look(&"boss_ember_titan")
	var boss_width := _body.shadow_width()
	assert_gt(player_width, swarmer_width, "a 16 px player has a wider shadow than a 10 px slime")
	assert_gt(boss_width, player_width, "and the boss a wider one still")
	assert_lte(player_width, 16, "never wider than the sprite")


func test_the_shadow_stays_one_to_one_and_on_the_ground_under_a_scaled_owner() -> void:
	var owner_node := Node2D.new()
	add_child_autofree(owner_node)
	var body := BodyView.new()
	owner_node.add_child(body)
	body.shadow_enabled = true
	body.set_look(&"enemy_tank", &"none")
	owner_node.scale = Vector2(1.5, 1.5)
	body.counter_scale(owner_node.scale)
	var shadow := body.get_node("Shadow") as Sprite2D
	assert_almost_eq(shadow.global_transform.get_scale().x, 1.0, 0.001)
	var sprite_height := float((body.get_node("Sprite") as AnimatedSprite2D).sprite_frames.get_frame_texture(&"move", 0).get_height())
	assert_almost_eq(shadow.global_position.y - body.global_position.y, sprite_height / 2.0 - 1.0, 0.6, "at the feet in world pixels, however the owner is scaled")


func test_every_shadow_is_drawn_at_one_depth_just_under_the_world() -> void:
	# One shared depth keeps all the shadows together in the draw order, so they batch into a few draws instead of
	# alternating with every sprite (which cost about half the frame rate at 300 enemies).
	_body.shadow_enabled = true
	_body.set_look(&"player")
	var shadow := _shadow()
	assert_eq(shadow.z_index, BodyView.SHADOW_Z)
	assert_false(shadow.z_as_relative, "the same depth whatever its owner's depth")
	assert_lt(BodyView.SHADOW_Z, 0, "under the sprites, which are at depth 0")


func _two_frame_set(first: Color) -> SpriteSetData:
	var set_data := SpriteSetData.new()
	var image := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(0, 0, 4, 4), first)
	image.fill_rect(Rect2i(4, 0, 4, 4), Color.WHITE)
	set_data.sheet = ImageTexture.create_from_image(image)
	set_data.frame_size = Vector2i(4, 4)
	var idle := SpriteAnimationData.new()
	idle.name = &"idle"
	idle.first_frame = 0
	idle.last_frame = 1
	idle.fps = 5.0
	idle.loop = true
	set_data.animations = [idle] as Array[SpriteAnimationData]
	return set_data


func _layer_sprite(layer_name: StringName) -> AnimatedSprite2D:
	return _body.get_node("Layer_%s" % layer_name) as AnimatedSprite2D


func _save_layer_art(file: String, root: String) -> void:
	assert_eq(ResourceSaver.save(_two_frame_set(Color.RED), "%s/%s" % [root, file]), OK)


func test_a_layer_follows_the_bodys_animation_frame_and_flip() -> void:
	var root := "res://.godot/art_tests/layers_%s" % str(randi())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	_save_layer_art("hat_base.tres", root)
	SpriteLibrary.root = root
	_body.set_set(_two_frame_set(Color.BLUE))
	_body.add_layer(&"headwear")
	assert_true(_body.set_layer(&"headwear", &"hat"))
	_body.play(&"idle")
	_sprite().frame = 1
	_body.set_facing(-1.0)
	_body._process(0.0)
	var layer := _layer_sprite(&"headwear")
	assert_true(layer.visible)
	assert_eq(layer.animation, &"idle")
	assert_eq(layer.frame, 1, "it shows the body's frame")
	assert_true(layer.flip_h, "and flips with it")
	SpriteLibrary.root = "res://assets/sprites"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/hat_base.tres" % root))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root))


func test_layers_draw_above_the_body_in_the_order_added() -> void:
	_body.set_set(_make_set())
	for layer_name in [&"robe", &"headwear", &"weapon"]:
		_body.add_layer(layer_name)
	assert_eq(_body.layer_names(), [&"robe", &"headwear", &"weapon"] as Array[StringName])
	assert_gt(_layer_sprite(&"robe").get_index(), _sprite().get_index())
	assert_gt(_layer_sprite(&"headwear").get_index(), _layer_sprite(&"robe").get_index())
	assert_gt(_layer_sprite(&"weapon").get_index(), _layer_sprite(&"headwear").get_index())
	_body.add_layer(&"robe")
	assert_eq(_body.layer_names().size(), 3, "adding a layer twice changes nothing")


func test_a_layer_is_never_scaled_under_a_scaled_owner() -> void:
	var owner_node := Node2D.new()
	add_child_autofree(owner_node)
	var body := BodyView.new()
	owner_node.add_child(body)
	body.set_set(_make_set())
	body.add_layer(&"robe")
	owner_node.scale = Vector2(2, 2)
	body.counter_scale(owner_node.scale)
	assert_almost_eq((body.get_node("Layer_robe") as Node2D).global_transform.get_scale().x, 1.0, 0.001)


func test_a_layer_with_no_art_is_hidden_and_never_fails() -> void:
	_body.set_set(_make_set())
	_body.add_layer(&"robe")
	assert_false(_body.set_layer(&"robe", &"no_such_sprite"))
	assert_false(_layer_sprite(&"robe").visible)
	assert_false(_body.set_layer(&"never_added", &"no_such_sprite"), "a layer that was never added is added, and still hidden")
	assert_false(_layer_sprite(&"never_added").visible)


func test_clear_layer_hides_it() -> void:
	var root := "res://.godot/art_tests/layers_%s" % str(randi())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	_save_layer_art("hat_base.tres", root)
	SpriteLibrary.root = root
	_body.set_set(_two_frame_set(Color.BLUE))
	_body.add_layer(&"headwear")
	_body.set_layer(&"headwear", &"hat")
	assert_true(_layer_sprite(&"headwear").visible)
	_body.clear_layer(&"headwear")
	assert_false(_layer_sprite(&"headwear").visible)
	SpriteLibrary.root = "res://assets/sprites"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/hat_base.tres" % root))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root))


func test_only_a_shown_layer_turns_processing_on() -> void:
	_body.set_set(_make_set())
	assert_false(_body.is_processing(), "a plain body runs nothing each frame")
	_body.add_layer(&"robe")
	assert_false(_body.is_processing(), "an empty layer does not either")


func test_a_layer_changes_frame_in_the_same_moment_as_the_body_not_a_frame_later() -> void:
	var root := "res://.godot/art_tests/layers_%s" % str(randi())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	_save_layer_art("hat_base.tres", root)
	SpriteLibrary.root = root
	_body.set_set(_two_frame_set(Color.BLUE))
	_body.add_layer(&"headwear")
	_body.set_layer(&"headwear", &"hat")
	_body.play(&"idle")
	_sprite().frame = 1
	assert_eq(_layer_sprite(&"headwear").frame, 1, "no wait for the next _process: a hat that lags the head by a frame jumps off it")
	_sprite().frame = 0
	assert_eq(_layer_sprite(&"headwear").frame, 0)
	SpriteLibrary.root = "res://assets/sprites"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/hat_base.tres" % root))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root))


func test_a_jitter_moves_the_body_and_everything_in_it_together_and_zero_restores_it() -> void:
	var body := BodyView.new()
	add_child_autofree(body)
	body.position = Vector2(10, 20)
	var sprite := body.get_node("Sprite") as Node2D
	var before := sprite.global_position
	body.set_jitter(Vector2(2, 0))
	assert_eq(sprite.global_position, before + Vector2(2, 0))
	body.set_jitter(Vector2.ZERO)
	assert_eq(sprite.global_position, before)
	assert_eq(body.position, Vector2(10, 20))


func test_the_jitter_is_whole_pixels_and_never_scales_the_body() -> void:
	var body := BodyView.new()
	add_child_autofree(body)
	body.set_jitter(Vector2(1.6, -0.4))
	assert_eq(body.position, Vector2(2, 0))
	assert_eq(body.scale, Vector2.ONE)
	body.set_jitter(Vector2.ZERO)
	assert_eq(body.position, Vector2.ZERO)


func test_a_tint_reaches_every_worn_layer() -> void:
	var root := "res://.godot/art_tests/layers_%s" % str(randi())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	_save_layer_art("hat_base.tres", root)
	SpriteLibrary.root = root
	_body.set_set(_two_frame_set(Color.BLUE))
	_body.add_layer(&"headwear")
	assert_true(_body.set_layer(&"headwear", &"hat"))
	_body.set_tint(Color(1.0, 0.5, 0.5))
	assert_eq(_layer_sprite(&"headwear").self_modulate, Color(1.0, 0.5, 0.5), "the hat turns red with the body")
	_body.set_tint(Color.WHITE)
	assert_eq(_layer_sprite(&"headwear").self_modulate, Color.WHITE, "and clears with it")
	SpriteLibrary.root = "res://assets/sprites"
