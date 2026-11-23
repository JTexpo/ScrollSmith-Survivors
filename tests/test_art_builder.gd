extends GutTest

const ROOT := "res://.godot/art_tests"
const PALETTE_TEXT := """
color K #101010
color W #ffffff
variant fire #aa0000 #bb0000 #cc0000 #dd0000 #ee0000
variant sea #0000aa #0000bb #0000cc #0000dd #0000ee
"""
## Two 4x4 frames. Frame 0 has a ramp pixel at (1, 1), frame 1 has a single pixel at (2, 2).
const RAMP_SPRITE := """
size 4 4
anim idle 0 1 4 loop
anim pop 1 1 10 once
frame
....
.2K.
....
....
frame
....
....
..W.
....
"""
const PLAIN_SPRITE := """
size 2 2
anim a 0 0 1 loop
frame
KW
WK
"""

var _dir: String


func before_each() -> void:
	_dir = "%s/b_%s" % [ROOT, str(randi())]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir + "/sources"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir + "/out"))
	SpriteLibrary.root = "res://assets/sprites"


func after_each() -> void:
	SpriteLibrary.root = "res://assets/sprites"
	for folder in ["/sources", "/out"]:
		var absolute := ProjectSettings.globalize_path(_dir + folder)
		for file in DirAccess.get_files_at(absolute):
			DirAccess.remove_absolute("%s/%s" % [absolute, file])
		DirAccess.remove_absolute(absolute)
	var top := ProjectSettings.globalize_path(_dir)
	for file in DirAccess.get_files_at(top):
		DirAccess.remove_absolute("%s/%s" % [top, file])
	DirAccess.remove_absolute(top)


func _palette() -> ArtPalette:
	return ArtPalette.parse(PALETTE_TEXT)


func _write(file: String, text: String) -> void:
	var handle := FileAccess.open("%s/%s" % [_dir, file], FileAccess.WRITE)
	handle.store_string(text)
	handle.close()


func test_a_sheet_has_the_frames_side_by_side_with_the_right_colors() -> void:
	var source := SpriteSource.parse(RAMP_SPRITE, _palette())
	var sheet := ArtBuilder.build_sheet(source, _palette(), &"fire")
	assert_eq(sheet.get_size(), Vector2i(8, 4))
	assert_eq(sheet.get_pixel(2, 1), Color.html("#101010"), "frame 0's K")
	assert_eq(sheet.get_pixel(4 + 2, 2), Color.html("#ffffff"), "frame 1's W is shifted by one frame width")


func test_a_ramp_slot_takes_the_variants_color() -> void:
	var source := SpriteSource.parse(RAMP_SPRITE, _palette())
	var fire := ArtBuilder.build_sheet(source, _palette(), &"fire")
	var sea := ArtBuilder.build_sheet(source, _palette(), &"sea")
	assert_eq(fire.get_pixel(1, 1), Color.html("#bb0000"))
	assert_eq(sea.get_pixel(1, 1), Color.html("#0000bb"))
	assert_eq(fire.get_pixel(2, 1), sea.get_pixel(2, 1), "fixed colours are the same in every variant")


func test_transparent_pixels_stay_transparent() -> void:
	var source := SpriteSource.parse(RAMP_SPRITE, _palette())
	var sheet := ArtBuilder.build_sheet(source, _palette(), &"fire")
	assert_eq(sheet.get_pixel(0, 0).a, 0.0)
	assert_eq(sheet.get_pixel(7, 3).a, 0.0)


func test_the_silhouette_grows_the_shape_by_one_pixel_in_white() -> void:
	var source := SpriteSource.parse(RAMP_SPRITE, _palette())
	var silhouette := ArtBuilder.build_silhouette(source)
	assert_eq(silhouette.get_size(), Vector2i(8, 4))
	assert_eq(silhouette.get_pixel(1, 1), Color.WHITE, "a sprite pixel")
	assert_eq(silhouette.get_pixel(0, 0), Color.WHITE, "one pixel diagonally out")
	assert_eq(silhouette.get_pixel(3, 2), Color.WHITE, "one pixel out of the K")
	assert_eq(silhouette.get_pixel(3, 3).a, 0.0, "two pixels away")
	assert_eq(silhouette.get_pixel(4 + 0, 0).a, 0.0, "frame 1 does not inherit frame 0's shape")


func test_set_text_names_the_sheet_the_frame_size_and_every_animation() -> void:
	var source := SpriteSource.parse(RAMP_SPRITE, _palette())
	var text := ArtBuilder.set_text("res://assets/sprites/x_fire.png", source)
	assert_string_contains(text, 'path="res://assets/sprites/x_fire.png"')
	assert_string_contains(text, "frame_size = Vector2i(4, 4)")
	assert_string_contains(text, 'name = &"idle"')
	assert_string_contains(text, 'name = &"pop"')
	assert_string_contains(text, "loop = false")
	assert_string_contains(text, "fps = 10.0")


func test_build_all_writes_a_sheet_per_variant_a_silhouette_and_a_tres_for_each() -> void:
	_write("palette.txt", PALETTE_TEXT)
	_write("sources/ramped.sprite", RAMP_SPRITE)
	_write("sources/plain.sprite", PLAIN_SPRITE)
	var problems := ArtBuilder.build_all(_dir + "/sources", _dir + "/palette.txt", _dir + "/out")
	assert_eq(problems.size(), 0, str(problems))
	var files := Array(DirAccess.get_files_at(ProjectSettings.globalize_path(_dir + "/out")))
	for expected in ["ramped_fire.png", "ramped_fire.tres", "ramped_sea.png", "ramped_sea.tres", "ramped_silhouette.png", "ramped_silhouette.tres", "plain_base.png", "plain_base.tres", "plain_silhouette.png", "plain_silhouette.tres"]:
		assert_true(files.has(expected), "missing %s" % expected)
	assert_false(files.has("plain_fire.png"), "a sprite without ramps is built once")
	assert_eq(ArtBuilder.files_written, 10)


func test_a_bad_source_writes_nothing_and_reports() -> void:
	_write("palette.txt", PALETTE_TEXT)
	_write("sources/broken.sprite", "size 2 2\nframe\nKK\nKQ")
	_write("sources/fine.sprite", PLAIN_SPRITE)
	var problems := ArtBuilder.build_all(_dir + "/sources", _dir + "/palette.txt", _dir + "/out")
	assert_gt(problems.size(), 0)
	assert_string_contains(problems[0], "broken")
	var files := Array(DirAccess.get_files_at(ProjectSettings.globalize_path(_dir + "/out")))
	for file in files:
		assert_false(String(file).begins_with("broken"), "wrote %s for a bad source" % file)
	assert_true(files.has("fine_base.png"), "the good source is still built")


func test_a_bad_palette_is_reported_and_nothing_is_written() -> void:
	_write("palette.txt", "color KK #fff")
	_write("sources/fine.sprite", PLAIN_SPRITE)
	var problems := ArtBuilder.build_all(_dir + "/sources", _dir + "/palette.txt", _dir + "/out")
	assert_gt(problems.size(), 0)
	assert_eq(DirAccess.get_files_at(ProjectSettings.globalize_path(_dir + "/out")).size(), 0)


func test_a_set_resource_builds_sprite_frames_with_the_animations() -> void:
	var image := Image.create(12, 4, false, Image.FORMAT_RGBA8)
	var set_data := SpriteSetData.new()
	set_data.sheet = ImageTexture.create_from_image(image)
	set_data.frame_size = Vector2i(4, 4)
	var idle := SpriteAnimationData.new()
	idle.name = &"idle"
	idle.first_frame = 0
	idle.last_frame = 1
	idle.fps = 4.0
	idle.loop = true
	var pop := SpriteAnimationData.new()
	pop.name = &"pop"
	pop.first_frame = 2
	pop.last_frame = 2
	pop.fps = 10.0
	pop.loop = false
	set_data.animations = [idle, pop] as Array[SpriteAnimationData]
	var frames := set_data.frames()
	assert_eq(frames.get_frame_count(&"idle"), 2)
	assert_eq(frames.get_frame_count(&"pop"), 1)
	assert_eq(frames.get_animation_speed(&"idle"), 4.0)
	assert_true(frames.get_animation_loop(&"idle"))
	assert_false(frames.get_animation_loop(&"pop"))
	assert_false(frames.has_animation(&"default"), "the empty default animation is removed")
	assert_eq((frames.get_frame_texture(&"pop", 0) as AtlasTexture).region, Rect2(8, 0, 4, 4))
	assert_same(set_data.frames(), frames, "built once and cached")


func test_has_animation_and_frame_count() -> void:
	var set_data := SpriteSetData.new()
	set_data.sheet = ImageTexture.create_from_image(Image.create(12, 4, false, Image.FORMAT_RGBA8))
	set_data.frame_size = Vector2i(4, 4)
	var idle := SpriteAnimationData.new()
	idle.name = &"idle"
	set_data.animations = [idle] as Array[SpriteAnimationData]
	assert_eq(set_data.frame_count(), 3)
	assert_true(set_data.has_animation(&"idle"))
	assert_false(set_data.has_animation(&"run"))


func test_the_library_finds_a_variant_falls_back_to_base_and_returns_null_when_missing() -> void:
	var base := SpriteSetData.new()
	base.frame_size = Vector2i(5, 5)
	assert_eq(ResourceSaver.save(base, _dir + "/out/thing_base.tres"), OK)
	var fire := SpriteSetData.new()
	fire.frame_size = Vector2i(6, 6)
	assert_eq(ResourceSaver.save(fire, _dir + "/out/thing_fire.tres"), OK)
	var silhouette := SpriteSetData.new()
	silhouette.frame_size = Vector2i(7, 7)
	assert_eq(ResourceSaver.save(silhouette, _dir + "/out/thing_silhouette.tres"), OK)
	SpriteLibrary.root = _dir + "/out"
	assert_eq(SpriteLibrary.find(&"thing", &"fire").frame_size, Vector2i(6, 6))
	assert_eq(SpriteLibrary.find(&"thing", &"sea").frame_size, Vector2i(5, 5), "no sea variant: the base")
	assert_eq(SpriteLibrary.find(&"thing").frame_size, Vector2i(5, 5))
	assert_eq(SpriteLibrary.find_silhouette(&"thing").frame_size, Vector2i(7, 7))
	assert_null(SpriteLibrary.find(&"nothing", &"fire"))
	assert_null(SpriteLibrary.find_silhouette(&"nothing"))
