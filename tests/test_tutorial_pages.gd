extends GutTest

const TEXT_WIDTH := 440.0


func test_there_are_four_pages_with_titles_lines_and_sprites() -> void:
	var pages := TutorialPages.pages()
	assert_eq(pages.size(), 4)
	for page in pages:
		assert_ne(page.title, "")
		assert_between(page.lines.size(), 1, 4, page.title)
		assert_between(page.sprites.size(), 1, 4, page.title)


func test_every_sprite_exists() -> void:
	for page in TutorialPages.pages():
		for sprite in page.sprites:
			assert_not_null(SpriteLibrary.find(sprite), "%s on %s" % [sprite, page.title])


func test_lines_are_ascii_and_fit_the_page_width() -> void:
	for page in TutorialPages.pages():
		var texts: Array[String] = [page.title]
		texts.append_array(page.lines)
		for text in texts:
			for i in text.length():
				assert_between(text.unicode_at(i), 32, 126, "ASCII only: %s" % text)
			var width := UiFont.plain().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.SIZE).x
			assert_lte(width, TEXT_WIDTH, text)


func test_key_names_come_from_the_input_map() -> void:
	var all := "\n".join(_all_lines())
	assert_string_contains(all, ControlsText.keys_for([&"move_up", &"move_left", &"move_down", &"move_right"]))
	assert_string_contains(all, ControlsText.key_for(&"interact"))
	assert_string_contains(all, ControlsText.key_for(&"cast"))


func test_the_pages_say_mana_never_comes_back_and_potions_last_one_run() -> void:
	var all := "\n".join(_all_lines()).to_lower()
	assert_string_contains(all, "mana never comes back")
	assert_string_contains(all, "one run")


func _all_lines() -> Array[String]:
	var lines: Array[String] = []
	for page in TutorialPages.pages():
		lines.append_array(page.lines)
	return lines


func test_the_merchant_numbers_come_from_the_game_data() -> void:
	var stock := (load("res://resources/points_of_interest/merchant.tres") as PointOfInterestData).stock_per_potion
	var potions_page := TutorialPages.pages()[3]
	var text := "\n".join(potions_page.lines)
	assert_string_contains(text, "%d of each" % stock)
	assert_string_contains(text, "up to %d" % RunPotions.MAX_POTIONS)
	assert_string_contains(text.to_lower(), "one run")
