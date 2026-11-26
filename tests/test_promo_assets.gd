extends GutTest
## The itch.io pictures in docs/release-planning/promo/: a cover, five screenshots and a short GIF of a fight, all taken from the real game.

const DIR := "res://docs/release-planning/promo"
const SHOTS := ["shot_1.png", "shot_2.png", "shot_3.png", "shot_4.png", "shot_5.png"]
const MAX_BYTES := 3 * 1024 * 1024


func _size(file: String) -> Vector2i:
	var image := Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [DIR, file]))
	return image.get_size() if image != null else Vector2i.ZERO


func _bytes(file: String) -> int:
	var handle := FileAccess.open("%s/%s" % [DIR, file], FileAccess.READ)
	return handle.get_length() if handle != null else -1


func test_every_file_exists_and_is_under_three_megabytes() -> void:
	for file in ["cover.png", "fight.gif"] + SHOTS:
		assert_gt(_bytes(file), 0, "%s exists" % file)
		assert_lte(_bytes(file), MAX_BYTES, "%s is under 3 MB" % file)


func test_the_cover_is_630_by_500() -> void:
	assert_eq(_size("cover.png"), Vector2i(630, 500))


func test_each_screenshot_is_a_whole_multiple_of_480_by_270() -> void:
	for file in SHOTS:
		var size := _size(file)
		assert_gt(size.x, 0, file)
		assert_eq(size.x % 480, 0, file)
		assert_eq(size.y % 270, 0, file)
		assert_eq(size.x / 480, size.y / 270, "%s keeps the 16 by 9 shape" % file)


func test_the_gif_is_a_gif_at_the_real_size() -> void:
	var handle := FileAccess.open("%s/fight.gif" % DIR, FileAccess.READ)
	assert_not_null(handle)
	var head := handle.get_buffer(10)
	assert_eq(head.slice(0, 6).get_string_from_ascii(), "GIF89a")
	var width := head[6] + head[7] * 256
	var height := head[8] + head[9] * 256
	assert_eq(Vector2i(width, height), Vector2i(480, 270))


func test_the_page_document_lists_the_pictures() -> void:
	var text := FileAccess.get_file_as_string("res://docs/release-planning/itchio-page.md")
	for file in ["cover.png", "fight.gif"] + SHOTS:
		assert_true(file in text, file)
