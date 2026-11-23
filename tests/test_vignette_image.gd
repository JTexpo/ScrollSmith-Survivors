extends GutTest

const RED := Color("e0483c")
var _image: Image


func before_each() -> void:
	_image = VignetteImage.build()


func test_the_image_is_480_by_270() -> void:
	assert_eq(_image.get_size(), Vector2i(480, 270))


func test_the_middle_is_fully_transparent() -> void:
	var depth := VignetteImage.DEPTH
	for y in range(depth, 270 - depth):
		for x in range(depth, 480 - depth):
			assert_eq(_image.get_pixel(x, y).a, 0.0, "%d,%d" % [x, y])


func test_only_the_palette_red_is_used() -> void:
	for y in 270:
		for x in 480:
			var pixel := _image.get_pixel(x, y)
			if pixel.a > 0.0:
				assert_true(pixel.is_equal_approx(RED), "%d,%d is %s" % [x, y, pixel.to_html()])


func _ring_density(ring: int) -> float:
	var filled := 0
	var total := 0
	for y in 270:
		for x in 480:
			if mini(mini(x, 479 - x), mini(y, 269 - y)) == ring:
				total += 1
				if _image.get_pixel(x, y).a > 0.0:
					filled += 1
	return float(filled) / float(total)


func test_the_edge_is_solid_and_density_falls_inward() -> void:
	assert_eq(_ring_density(0), 1.0, "the outermost ring is solid")
	var previous := 1.0
	for group in range(0, VignetteImage.DEPTH - 3, 4):
		var total := 0.0
		for ring in range(group, group + 4):
			total += _ring_density(ring)
		var density := total / 4.0
		assert_lte(density, previous + 0.0001, "rings %d to %d are no denser than the four outside them (a 4 by 4 dither is quantised per row)" % [group, group + 3])
		previous = density
	assert_lt(_ring_density(VignetteImage.DEPTH - 1), 0.5, "the inner rim is sparse")
	assert_gt(_ring_density(VignetteImage.DEPTH - 1), 0.05, "but not empty")


func test_the_pattern_is_a_dither() -> void:
	# In the middle of the top edge, a mid ring has both filled and empty pixels that alternate (a dither, not a flat band).
	var ring := VignetteImage.DEPTH / 2
	var changes := 0
	var last := _image.get_pixel(100, ring).a > 0.0
	for x in range(101, 300):
		var now := _image.get_pixel(x, ring).a > 0.0
		if now != last:
			changes += 1
		last = now
	assert_gt(changes, 40, "neighbouring pixels alternate")


func test_it_is_deterministic() -> void:
	assert_true(VignetteImage.build().get_data() == VignetteImage.build().get_data())


func test_a_smaller_size_is_supported() -> void:
	var small := VignetteImage.build(Vector2i(64, 48), 8)
	assert_eq(small.get_size(), Vector2i(64, 48))
	assert_eq(small.get_pixel(32, 24).a, 0.0)
