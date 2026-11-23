extends GutTest

const AREA := Rect2(40, 60, 400, 240)


func _tile_set() -> SpriteSetData:
	var set_data := SpriteSetData.new()
	set_data.sheet = ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	set_data.frame_size = Vector2i(16, 16)
	set_data.tile = true
	return set_data


func _patch(area: Rect2 = AREA, soft: bool = true, seed_value: int = 1) -> FloorPatch:
	var patch := FloorPatch.new()
	add_child_autofree(patch)
	patch.setup(area, _tile_set(), soft, seed_value)
	return patch


func test_a_hard_patch_omits_nothing_and_draws_the_whole_area() -> void:
	var patch := _patch(AREA, false)
	assert_eq(patch.area, AREA)
	assert_eq(patch.omitted_cells().size(), 0)
	assert_eq(patch.interior_rect(), Rect2(Vector2.ZERO, AREA.size), "one tiled rectangle, in the patch's own coordinates")


func test_a_soft_patch_leaves_gaps_only_in_the_outer_16_pixels() -> void:
	var patch := _patch()
	var gaps := patch.omitted_cells()
	assert_gt(gaps.size(), 0)
	var inner := patch.interior_rect()
	for cell in gaps:
		assert_false(inner.intersects(cell), "%s is in the interior" % cell)
		assert_true(Rect2(Vector2.ZERO, AREA.size).encloses(cell), "%s is inside the area" % cell)


func test_the_interior_is_the_area_shrunk_by_16() -> void:
	assert_eq(_patch().interior_rect(), Rect2(Vector2(16, 16), AREA.size - Vector2(32, 32)))


func test_the_outer_row_has_more_gaps_than_the_second_row() -> void:
	var big := Rect2(0, 0, 1200, 800)
	var gaps := _patch(big).omitted_cells()
	var outer := 0
	var second := 0
	for cell in gaps:
		var depth := minf(minf(cell.position.x, cell.position.y), minf(big.size.x - cell.end.x, big.size.y - cell.end.y))
		if depth < 8.0:
			outer += 1
		else:
			second += 1
	assert_gt(outer, second, "the edge is rougher than just inside it")
	assert_gt(second, 0, "the second row has some gaps too")


func test_the_same_seed_gives_the_same_gaps_and_another_seed_differs() -> void:
	assert_eq(_patch(AREA, true, 5).omitted_cells(), _patch(AREA, true, 5).omitted_cells())
	assert_ne(_patch(AREA, true, 5).omitted_cells(), _patch(AREA, true, 6).omitted_cells())


func test_a_tiny_area_never_fails() -> void:
	for size in [Vector2(10, 10), Vector2(30, 30), Vector2(33, 5), Vector2(0, 0)]:
		var patch := _patch(Rect2(0, 0, size.x, size.y))
		assert_not_null(patch.omitted_cells(), "%s" % size)
		assert_lte(patch.interior_rect().size.x, maxf(size.x - 32.0, 0.0))
