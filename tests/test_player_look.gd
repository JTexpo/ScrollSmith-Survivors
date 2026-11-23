extends GutTest

const FRAMES := 8
const PLAYER_ANIMATIONS := [&"idle", &"move", &"cast"]


func _sheet(sprite_name: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/%s_base.png" % sprite_name))
	image.convert(Image.FORMAT_RGBA8)
	return image


func test_the_starter_layers_compose_to_exactly_todays_wizard() -> void:
	var body := _sheet("player_body")
	var robe := _sheet("robe_starter")
	var hat := _sheet("hat_starter")
	var original := _sheet("player")
	assert_eq(body.get_size(), original.get_size())
	assert_eq(original.get_width(), 16 * FRAMES)
	var composed := Image.create(original.get_width(), original.get_height(), false, Image.FORMAT_RGBA8)
	for layer in [body, robe, hat]:
		composed.blend_rect(layer, Rect2i(Vector2i.ZERO, layer.get_size()), Vector2i.ZERO)
	var differing := 0
	for y in original.get_height():
		for x in original.get_width():
			if composed.get_pixel(x, y) != original.get_pixel(x, y):
				differing += 1
	assert_eq(differing, 0, "the body, starter robe and starter hat make today's wizard pixel for pixel, in all eight frames")


func test_the_layers_do_not_overlap() -> void:
	var sheets := [_sheet("player_body"), _sheet("robe_starter"), _sheet("hat_starter")]
	for y in sheets[0].get_height():
		for x in sheets[0].get_width():
			var drawn := 0
			for sheet in sheets:
				if sheet.get_pixel(x, y).a > 0.0:
					drawn += 1
			assert_lte(drawn, 1, "pixel %d, %d belongs to one layer" % [x, y])


func test_every_layer_set_has_the_players_animations_and_frame_count() -> void:
	for sprite_name in [&"player_body", &"robe_starter", &"hat_starter"]:
		var set_data := SpriteLibrary.find(sprite_name)
		assert_not_null(set_data, str(sprite_name))
		assert_eq(set_data.frame_count(), FRAMES, str(sprite_name))
		var reference := SpriteLibrary.find(&"player")
		for animation in PLAYER_ANIMATIONS:
			assert_true(set_data.has_animation(animation), "%s has %s" % [sprite_name, animation])
		for i in reference.animations.size():
			assert_eq(set_data.animations[i].first_frame, reference.animations[i].first_frame)
			assert_eq(set_data.animations[i].last_frame, reference.animations[i].last_frame)
			assert_eq(set_data.animations[i].fps, reference.animations[i].fps)
			assert_eq(set_data.animations[i].loop, reference.animations[i].loop)


func _body_view() -> BodyView:
	var body := BodyView.new()
	add_child_autofree(body)
	body.set_look(&"player_body")
	return body


func test_with_nothing_equipped_the_starters_show_and_the_weapon_does_not() -> void:
	var body := _body_view()
	PlayerLook.apply(body, PlayerProfile.new(), EquipmentCatalog.default_catalog())
	assert_eq(body.layer_names(), [&"robe", &"headwear", &"weapon"] as Array[StringName])
	assert_true((body.get_node("Layer_robe") as AnimatedSprite2D).visible)
	assert_true((body.get_node("Layer_headwear") as AnimatedSprite2D).visible)
	assert_false((body.get_node("Layer_weapon") as AnimatedSprite2D).visible)


func test_applying_with_no_profile_shows_the_starters() -> void:
	var body := _body_view()
	PlayerLook.apply(body)
	assert_true((body.get_node("Layer_robe") as AnimatedSprite2D).visible)
	assert_true((body.get_node("Layer_headwear") as AnimatedSprite2D).visible)


func test_applying_twice_changes_nothing() -> void:
	var body := _body_view()
	PlayerLook.apply(body)
	var frames := (body.get_node("Layer_robe") as AnimatedSprite2D).sprite_frames
	PlayerLook.apply(body)
	assert_eq(body.layer_names().size(), 3)
	assert_eq((body.get_node("Layer_robe") as AnimatedSprite2D).sprite_frames.get_frame_count(&"idle"), frames.get_frame_count(&"idle"))


func test_the_player_wears_the_starters_when_the_scene_loads() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child_autofree(player)
	var body := player.get_node("Body") as BodyView
	assert_true(body.has_art())
	assert_eq(body.layer_names(), [&"robe", &"headwear", &"weapon"] as Array[StringName])
	assert_true((body.get_node("Layer_robe") as AnimatedSprite2D).visible)
