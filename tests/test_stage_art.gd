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
	for name in [&"banner_title", &"cloud_small", &"cloud_large", &"bush", &"tree_side", &"tree_side_small"]:
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


func test_the_side_view_trees_have_a_trunk_and_a_crown() -> void:
	for name in [&"tree_side", &"tree_side_small"]:
		var set_data := SpriteLibrary.find(name, &"base")
		assert_lte(set_data.frame_size.x, 34, String(name))
		assert_lte(set_data.frame_size.y, 46, String(name))
		assert_gt(set_data.frame_size.y, set_data.frame_size.x, "%s is taller than wide, a tree seen from the side" % name)
		var image := _frames(name)[0]
		var brown := 0
		var green := 0
		for y in image.get_height():
			for x in image.get_width():
				var pixel := image.get_pixel(x, y)
				if pixel.a == 0.0:
					continue
				if pixel.r > pixel.g and pixel.r > pixel.b:
					brown += 1
				elif pixel.g > pixel.r and pixel.g > pixel.b:
					green += 1
		assert_gt(brown, 20, "%s has a trunk" % name)
		assert_gt(green, 100, "%s has a crown" % name)

