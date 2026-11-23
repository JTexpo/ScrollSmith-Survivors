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
	var beard := _sheet("beard_white")
	var hat := _sheet("hat_starter")
	var original := _sheet("player")
	assert_eq(body.get_size(), original.get_size())
	assert_eq(original.get_width(), 16 * FRAMES)
	var composed := Image.create(original.get_width(), original.get_height(), false, Image.FORMAT_RGBA8)
	for layer in [body, robe, beard, hat]:
		composed.blend_rect(layer, Rect2i(Vector2i.ZERO, layer.get_size()), Vector2i.ZERO)
	var differing := 0
	for y in original.get_height():
		for x in original.get_width():
			if composed.get_pixel(x, y) != original.get_pixel(x, y):
				differing += 1
	assert_eq(differing, 0, "the body, starter robe, beard and starter hat make the wizard pixel for pixel, in all eight frames")


func test_the_body_robe_and_hat_do_not_overlap() -> void:
	# The beard hangs over the robe on purpose, so it is left out.
	var sheets := [_sheet("player_body"), _sheet("robe_starter"), _sheet("hat_starter")]
	for y in sheets[0].get_height():
		for x in sheets[0].get_width():
			var drawn := 0
			for sheet in sheets:
				if sheet.get_pixel(x, y).a > 0.0:
					drawn += 1
			assert_lte(drawn, 1, "pixel %d, %d belongs to one layer" % [x, y])


func test_every_layer_set_has_the_players_animations_and_frame_count() -> void:
	for sprite_name in [&"player_body", &"robe_starter", &"hat_starter", &"beard_white"]:
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
	assert_eq(body.layer_names(), [&"robe", &"beard", &"headwear", &"weapon"] as Array[StringName])
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
	assert_eq(body.layer_names().size(), 4)
	assert_eq((body.get_node("Layer_robe") as AnimatedSprite2D).sprite_frames.get_frame_count(&"idle"), frames.get_frame_count(&"idle"))


func test_the_player_wears_the_starters_when_the_scene_loads() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child_autofree(player)
	var body := player.get_node("Body") as BodyView
	assert_true(body.has_art())
	assert_eq(body.layer_names(), [&"robe", &"beard", &"headwear", &"weapon"] as Array[StringName])
	assert_true((body.get_node("Layer_robe") as AnimatedSprite2D).visible)


func _profile_with(ids: Array) -> PlayerProfile:
	var profile := PlayerProfile.new()
	var catalog := EquipmentCatalog.default_catalog()
	for id in ids:
		profile.grant(id)
		profile.equip(int(catalog.find(id).slot()), id)
	return profile


func _frames_of(body: BodyView, layer_name: String) -> SpriteFrames:
	return (body.get_node("Layer_%s" % layer_name) as AnimatedSprite2D).sprite_frames


func _sheet_of(body: BodyView, layer_name: String) -> String:
	return ((_frames_of(body, layer_name).get_frame_texture(&"idle", 0) as AtlasTexture).atlas).resource_path


func test_each_equipped_robe_headwear_and_weapon_replaces_its_slot_only() -> void:
	var catalog := EquipmentCatalog.default_catalog()
	var body := _body_view()
	PlayerLook.apply(body, _profile_with([&"robe_ember"]), catalog)
	assert_string_contains(_sheet_of(body, "robe"), "robe_wizard_fire")
	assert_string_contains(_sheet_of(body, "headwear"), "hat_starter", "the headwear stays the starter")
	assert_false((body.get_node("Layer_weapon") as AnimatedSprite2D).visible)
	PlayerLook.apply(body, _profile_with([&"robe_ember", &"hood_mana", &"staff_oak"]), catalog)
	assert_string_contains(_sheet_of(body, "robe"), "robe_wizard_fire")
	assert_string_contains(_sheet_of(body, "headwear"), "hood_soft_mana")
	assert_string_contains(_sheet_of(body, "weapon"), "staff_tall_oak")
	assert_true((body.get_node("Layer_weapon") as AnimatedSprite2D).visible)
	PlayerLook.apply(body, _profile_with([&"hat_swift", &"wand_quick"]), catalog)
	assert_string_contains(_sheet_of(body, "robe"), "robe_starter", "taking the robe off brings the starter back")
	assert_string_contains(_sheet_of(body, "headwear"), "hat_pointed_swift")
	assert_string_contains(_sheet_of(body, "weapon"), "wand_short_quick")


func test_a_hood_replaces_the_starter_hat_so_no_hat_shows_through() -> void:
	var body := _body_view()
	PlayerLook.apply(body, _profile_with([&"hood_hardy"]), EquipmentCatalog.default_catalog())
	assert_eq(body.layer_names().count(&"headwear"), 1, "one headwear layer, never a hat and a hood together")
	assert_string_contains(_sheet_of(body, "headwear"), "hood_soft_hardy")


func test_an_unowned_or_misplaced_item_is_ignored() -> void:
	var catalog := EquipmentCatalog.default_catalog()
	var body := _body_view()
	var profile := PlayerProfile.new()
	profile.equip(int(EquipmentData.Slot.ROBE), &"robe_ember")
	PlayerLook.apply(body, profile, catalog)
	assert_string_contains(_sheet_of(body, "robe"), "robe_starter", "an equipped but unowned robe is ignored")
	profile.grant(&"hat_hardy")
	profile.equip(int(EquipmentData.Slot.ROBE), &"hat_hardy")
	PlayerLook.apply(body, profile, catalog)
	assert_string_contains(_sheet_of(body, "robe"), "robe_starter", "a hat in the robe slot is ignored")
	profile.equip(int(EquipmentData.Slot.WEAPON), &"no_such_item")
	PlayerLook.apply(body, profile, catalog)
	assert_false((body.get_node("Layer_weapon") as AnimatedSprite2D).visible)


func test_every_equipment_layer_set_matches_the_players_animations_and_frames() -> void:
	var reference := SpriteLibrary.find(&"player")
	for item in EquipmentCatalog.default_catalog().items:
		var set_data := SpriteLibrary.find(item.sprite_name, item.sprite_variant)
		assert_eq(set_data.frame_count(), FRAMES, str(item.id))
		assert_eq(set_data.frame_size, Vector2i(16, 16), str(item.id))
		for i in reference.animations.size():
			assert_eq(set_data.animations[i].name, reference.animations[i].name, str(item.id))
			assert_eq(set_data.animations[i].first_frame, reference.animations[i].first_frame, str(item.id))
			assert_eq(set_data.animations[i].last_frame, reference.animations[i].last_frame, str(item.id))
			assert_eq(set_data.animations[i].fps, reference.animations[i].fps, str(item.id))


## The band row of the hat in each frame of the bare wizard's source (the walk bounce moves it up one row).
func _band_rows() -> Array[int]:
	var rows: Array[int] = []
	var source := SpriteSource.parse(FileAccess.get_file_as_string("res://art/sprites/player.sprite"), ArtPalette.parse(FileAccess.get_file_as_string("res://art/palette.txt")))
	for frame in source.frames:
		for y in frame.size():
			if frame[y].contains("YYYRRYYY"):
				rows.append(y)
				break
	return rows


func test_layers_are_anchored_in_every_frame() -> void:
	var bands := _band_rows()
	assert_eq(bands.size(), FRAMES)
	for item in EquipmentCatalog.default_catalog().items:
		var sheet := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/%s_%s.png" % [item.sprite_name, item.sprite_variant]))
		sheet.convert(Image.FORMAT_RGBA8)
		for frame in FRAMES:
			var low := Vector2i(99, 99)
			var high := Vector2i(-1, -1)
			for y in 16:
				for x in 16:
					if sheet.get_pixel(frame * 16 + x, y).a > 0.0:
						low = Vector2i(mini(low.x, x), mini(low.y, y))
						high = Vector2i(maxi(high.x, x), maxi(high.y, y))
			var band := bands[frame]
			assert_gt(high.x, -1, "%s frame %d draws something" % [item.id, frame])
			assert_true(low.x >= 1 and low.y >= 1 and high.x <= 14 and high.y <= 14, "%s frame %d is inside the margin" % [item.id, frame])
			match item.slot():
				EquipmentData.Slot.HEADWEAR:
					assert_lte(high.y, band + 6, "%s frame %d stays on the head" % [item.id, frame])
					assert_lt(low.y, band, "%s frame %d reaches above the hat band" % [item.id, frame])
				EquipmentData.Slot.ROBE:
					assert_gte(low.y, band + 6, "%s frame %d stays below the collar line" % [item.id, frame])
				EquipmentData.Slot.WEAPON:
					assert_gte(low.x, 11, "%s frame %d is held at the right hand" % [item.id, frame])
					assert_gte(high.y, band + 6, "%s frame %d reaches down to the hand" % [item.id, frame])


func test_the_pointed_hat_has_exactly_the_starter_hats_shape_in_every_frame() -> void:
	var starter := _sheet("hat_starter")
	var pointed := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/hat_pointed_mana.png"))
	pointed.convert(Image.FORMAT_RGBA8)
	for y in starter.get_height():
		for x in starter.get_width():
			assert_eq(pointed.get_pixel(x, y).a > 0.0, starter.get_pixel(x, y).a > 0.0, "pixel %d, %d" % [x, y])


func test_the_player_scene_applies_the_profile_through_run_start() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child_autofree(player)
	var catalog := EquipmentCatalog.default_catalog()
	var profile := _profile_with([&"robe_storm", &"hat_hardy", &"wand_flicker"])
	RunStart.prepare(player, profile, LevelTrack.default_track(), RunBuffs.new(), catalog)
	var body := player.get_node("Body") as BodyView
	assert_string_contains(_sheet_of(body, "robe"), "robe_wizard_thunder")
	assert_string_contains(_sheet_of(body, "headwear"), "hat_pointed_hardy")
	assert_string_contains(_sheet_of(body, "weapon"), "wand_short_flicker")
	RunStart.prepare(player, profile, LevelTrack.default_track(), RunBuffs.new(), catalog)
	assert_eq(body.layer_names().size(), 4, "running it twice changes nothing")


## True when a pixel is one of the two skin tones of the palette.
func _is_skin(pixel: Color) -> bool:
	var palette := ArtPalette.parse(FileAccess.get_file_as_string("res://art/palette.txt"))
	return pixel.a > 0.0 and (pixel.to_html(false) == (palette.colors["S"] as Color).to_html(false) or pixel.to_html(false) == (palette.colors["s"] as Color).to_html(false))


func test_the_wizard_shows_no_skin_at_all() -> void:
	# The face is in the hat's shadow with only the eyes showing, and the beard covers the rest, so no one is left out.
	for sprite_name in ["player_body", "robe_starter", "beard_white", "hat_starter", "player"]:
		var sheet := _sheet(sprite_name)
		for y in sheet.get_height():
			for x in sheet.get_width():
				assert_false(_is_skin(sheet.get_pixel(x, y)), "%s has a skin-coloured pixel at %d, %d" % [sprite_name, x, y])
	for path in ["hat_pointed_hardy", "hat_pointed_mana", "hat_pointed_swift", "hood_soft_hardy", "hood_soft_mana", "hood_soft_swift", "robe_wizard_fire", "robe_wizard_none"]:
		var sheet := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/%s.png" % path))
		sheet.convert(Image.FORMAT_RGBA8)
		for y in sheet.get_height():
			for x in sheet.get_width():
				assert_false(_is_skin(sheet.get_pixel(x, y)), path)


## The width in pixels of the widest row a layer draws in a frame.
func _widest_row(sheet: Image, frame: int) -> int:
	var widest := 0
	for y in 16:
		var low := 99
		var high := -1
		for x in 16:
			if sheet.get_pixel(frame * 16 + x, y).a > 0.0:
				low = mini(low, x)
				high = maxi(high, x)
		if high >= 0:
			widest = maxi(widest, high - low + 1)
	return widest


func test_the_hat_and_every_hood_are_wider_than_the_head_so_the_head_reads_small() -> void:
	var head := _widest_face_row(_sheet("player_body"), 0)
	assert_lte(head, 10, "the face is ten pixels wide at most")
	for sprite_name in ["hat_starter"]:
		assert_gte(_widest_row(_sheet(sprite_name), 0), head + 4, "%s is at least four pixels wider than the head" % sprite_name)
	for path in ["hat_pointed_hardy", "hood_soft_hardy", "hood_soft_mana", "hood_soft_swift"]:
		var sheet := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/%s.png" % path))
		sheet.convert(Image.FORMAT_RGBA8)
		assert_gte(_widest_row(sheet, 0), head + 4, "%s is at least four pixels wider than the head" % path)


## The width of the face rows of the bare wizard in a frame (its rows below the brim, above the collar).
func _widest_face_row(sheet: Image, frame: int) -> int:
	var widest := 0
	for y in range(8, 12):
		var low := 99
		var high := -1
		for x in 16:
			if sheet.get_pixel(frame * 16 + x, y).a > 0.0:
				low = mini(low, x)
				high = maxi(high, x)
		if high >= 0:
			widest = maxi(widest, high - low + 1)
	return widest


func test_the_beard_is_white_and_hangs_over_the_robe() -> void:
	var beard := _sheet("beard_white")
	var bands := _band_rows()
	for frame in FRAMES:
		var white := 0
		var lowest := -1
		for y in 16:
			for x in 16:
				var pixel := beard.get_pixel(frame * 16 + x, y)
				if pixel.a > 0.0:
					lowest = maxi(lowest, y)
					if pixel.get_luminance() > 0.7:
						white += 1
		assert_gte(white, 14, "frame %d: the beard is mostly white" % frame)
		assert_gte(lowest, bands[frame] + 7, "frame %d: it hangs down over the robe" % frame)

