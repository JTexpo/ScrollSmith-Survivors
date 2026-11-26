extends GutTest
## The art the home stage needs: the title banner (with a travelling sparkle), two clouds and a bush.

const BANNER_MAX := Vector2i(256, 46)


func before_each() -> void:
	SpriteLibrary.root = "res://assets/sprites"


func _frames(name: StringName) -> Array[Image]:
	var set_data := SpriteLibrary.find(name, &"base")
	var sheet := set_data.sheet.get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	var found: Array[Image] = []
	for i in set_data.frame_count():
		found.append(sheet.get_region(Rect2i(i * set_data.frame_size.x, 0, set_data.frame_size.x, set_data.frame_size.y)))
	return found


func test_every_stage_sprite_resolves() -> void:
	for name in [&"banner_title", &"cloud_small", &"cloud_large", &"bush"]:
		assert_not_null(SpriteLibrary.find(name, &"base"), String(name))


func test_the_banner_fits_between_the_corner_buttons_and_has_a_four_frame_shimmer() -> void:
	var set_data := SpriteLibrary.find(&"banner_title", &"base")
	assert_lte(set_data.frame_size.x, BANNER_MAX.x)
	assert_lte(set_data.frame_size.y, BANNER_MAX.y)
	assert_eq(set_data.frame_count(), 4)
	assert_true(set_data.has_animation(&"shimmer"))


func test_each_banner_frame_differs_from_the_next_by_at_least_four_pixels() -> void:
	var frames := _frames(&"banner_title")
	for i in frames.size():
		var next := frames[(i + 1) % frames.size()]
		var differing := 0
		for y in frames[i].get_height():
			for x in frames[i].get_width():
				if frames[i].get_pixel(x, y) != next.get_pixel(x, y):
					differing += 1
		assert_gte(differing, 4, "frame %d and the next" % i)


func test_the_banner_is_bright_and_not_flat() -> void:
	var colours := {}
	for image in _frames(&"banner_title"):
		for y in image.get_height():
			for x in image.get_width():
				var pixel := image.get_pixel(x, y)
				if pixel.a > 0.0:
					colours[pixel.to_html()] = true
	assert_gte(colours.size(), 6, "yellow lettering, a shadow, a red ribbon and white sparkles")


func test_the_clouds_and_the_bush_are_small() -> void:
	for name in [&"cloud_small", &"cloud_large", &"bush"]:
		var set_data := SpriteLibrary.find(name, &"base")
		assert_lte(set_data.frame_size.x, 48, String(name))
		assert_lte(set_data.frame_size.y, 18, String(name))
		assert_eq(set_data.frame_count(), 1, String(name))
