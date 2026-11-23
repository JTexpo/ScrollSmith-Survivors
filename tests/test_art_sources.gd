extends GutTest

const PALETTE_TEXT := """
# a tiny palette
color K #1b1226
color W #ffffffff
color R #ff0000
variant none #111111 #222222 #333333 #444444 #555555
variant fire #aa1100 #cc3300 #ee5500 #881100 #ffcc00
"""

const SPRITE_TEXT := """
size 3 2
anim idle 0 1 4 loop
anim pop 1 1 12 once
frame
KWK
.R.
frame
KWK
.1.
"""


func _palette() -> ArtPalette:
	return ArtPalette.parse(PALETTE_TEXT)


func test_a_palette_parses_colors_and_variants() -> void:
	var palette := _palette()
	assert_eq(palette.errors.size(), 0, str(palette.errors))
	assert_eq(palette.colors.size(), 3)
	assert_eq(palette.colors["K"], Color.html("#1b1226"))
	assert_eq(palette.colors["W"], Color.html("#ffffffff"))
	assert_eq(palette.variants.size(), 2)
	assert_eq((palette.variants[&"fire"] as Array).size(), 5)
	assert_eq(palette.variants[&"fire"][4], Color.html("#ffcc00"))


func test_palette_color_for_uses_the_variant_for_ramp_slots_and_the_fixed_color_otherwise() -> void:
	var palette := _palette()
	assert_eq(palette.color_for("3", &"fire"), Color.html("#ee5500"))
	assert_eq(palette.color_for("3", &"none"), Color.html("#333333"))
	assert_eq(palette.color_for("K", &"fire"), Color.html("#1b1226"))
	assert_true(palette.has_letter("K"))
	assert_true(palette.has_letter("."))
	assert_true(palette.has_letter("5"))
	assert_false(palette.has_letter("Z"))


func test_a_dot_is_transparent() -> void:
	assert_eq(_palette().color_for(".", &"fire"), Color(0, 0, 0, 0))


func test_the_palette_reports_bad_lines() -> void:
	var bad := {
		"a letter longer than one character": "color KK #ffffff",
		"a reserved letter": "color 1 #ffffff",
		"the transparent letter": "color . #ffffff",
		"a bad hex": "color K #nothex",
		"a variant with four colours": "variant fire #111111 #222222 #333333 #444444",
		"an unknown directive": "palette K #ffffff",
	}
	for label in bad:
		assert_gt(ArtPalette.parse(bad[label]).errors.size(), 0, label)
	assert_gt(ArtPalette.parse("color K #ffffff\ncolor K #000000").errors.size(), 0, "a duplicate letter")
	assert_gt(ArtPalette.parse("variant fire #1 #2 #3 #4 #5").errors.size(), 0, "bad variant hex")
	assert_gt(ArtPalette.parse("variant a #111111 #222222 #333333 #444444 #555555\nvariant a #111111 #222222 #333333 #444444 #555555").errors.size(), 0, "a duplicate variant")


func test_distinct_color_count_removes_duplicates() -> void:
	var palette := ArtPalette.parse("color K #111111\ncolor W #111111\nvariant a #111111 #222222 #333333 #444444 #555555")
	assert_eq(palette.distinct_color_count(), 5, "#111111 is counted once")
	assert_eq(_palette().distinct_color_count(), 3 + 10)


func test_a_sprite_parses_size_animations_and_frames() -> void:
	var source := SpriteSource.parse(SPRITE_TEXT, _palette())
	assert_eq(source.errors.size(), 0, str(source.errors))
	assert_eq(source.frame_size, Vector2i(3, 2))
	assert_eq(source.frames.size(), 2)
	assert_eq(source.frames[0][0], "KWK")
	assert_eq(source.frames[1][1], ".1.")
	assert_eq(source.animations.size(), 2)
	assert_eq(source.animations[0], {"name": &"idle", "first": 0, "last": 1, "fps": 4.0, "loop": true})
	assert_eq(source.animations[1]["loop"], false)


func test_uses_ramp_decides_the_variants_needed() -> void:
	var palette := _palette()
	var with_ramp := SpriteSource.parse(SPRITE_TEXT, palette)
	assert_true(with_ramp.uses_ramp())
	assert_eq(with_ramp.variants_needed(palette), [&"none", &"fire"] as Array[StringName])
	var plain := SpriteSource.parse("size 2 1\nanim a 0 0 1 loop\nframe\nKW", palette)
	assert_eq(plain.errors.size(), 0, str(plain.errors))
	assert_false(plain.uses_ramp())
	assert_eq(plain.variants_needed(palette), [&"base"] as Array[StringName])


func test_a_sprite_reports_each_kind_of_error() -> void:
	var palette := _palette()
	var cases := {
		"no size": "anim a 0 0 1 loop\nframe\nK",
		"a non-positive size": "size 0 1\nframe\n",
		"a frame with too few rows": "size 2 2\nframe\nKK",
		"a row of the wrong width": "size 2 1\nframe\nKKK",
		"a letter the palette does not know": "size 2 1\nframe\nKZ",
		"an animation naming a frame that does not exist": "size 1 1\nanim a 0 3 1 loop\nframe\nK",
		"a duplicate animation": "size 1 1\nanim a 0 0 1 loop\nanim a 0 0 1 loop\nframe\nK",
		"no frames": "size 1 1\nanim a 0 0 1 loop",
		"rows before any frame": "size 1 1\nK",
		"a bad animation line": "size 1 1\nanim a zero 0 1 loop\nframe\nK",
		"a bad animation mode": "size 1 1\nanim a 0 0 1 forever\nframe\nK",
	}
	for label in cases:
		var source := SpriteSource.parse(cases[label], palette)
		assert_gt(source.errors.size(), 0, label)


func test_animation_ranges_must_exist() -> void:
	var palette := _palette()
	assert_gt(SpriteSource.parse("size 1 1\nanim a 1 0 1 loop\nframe\nK\nframe\nK", palette).errors.size(), 0, "first after last")
	assert_eq(SpriteSource.parse("size 1 1\nanim a 0 1 1 loop\nframe\nK\nframe\nK", palette).errors.size(), 0)
