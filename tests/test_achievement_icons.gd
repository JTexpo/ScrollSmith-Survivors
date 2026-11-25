extends GutTest
## Every icon the achievement catalog names exists, fits the card and the three boss heads can be told apart.

const BOSS_ICONS := [&"icon_ach_boss_tempest_dragon", &"icon_ach_boss_ember_titan", &"icon_ach_boss_dire_minotaur"]
const MAX_SIZE := Vector2i(16, 16)
const MIN_DIFFERENCE := 20


func before_each() -> void:
	SpriteLibrary.root = "res://assets/sprites"


func _image(name: StringName) -> Image:
	var image := SpriteLibrary.find(name, &"base").sheet.get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func test_every_catalog_icon_resolves_and_fits() -> void:
	var seen := {}
	for data in AchievementCatalog.default_catalog().achievements:
		seen[data.icon] = true
		var set_data := SpriteLibrary.find(data.icon, &"base")
		assert_not_null(set_data, "%s names the icon %s, which has no sprite" % [data.id, data.icon])
		if set_data == null:
			continue
		assert_gte(set_data.frame_count(), 1, String(data.icon))
		assert_lte(set_data.frame_size.x, MAX_SIZE.x, String(data.icon))
		assert_lte(set_data.frame_size.y, MAX_SIZE.y, String(data.icon))
	assert_gte(seen.size(), 6, "star, hourglass, coin and the three boss heads")


func test_the_three_boss_heads_differ_by_at_least_twenty_pixels() -> void:
	for i in BOSS_ICONS.size():
		for j in range(i + 1, BOSS_ICONS.size()):
			var a := _image(BOSS_ICONS[i])
			var b := _image(BOSS_ICONS[j])
			assert_eq(a.get_size(), b.get_size())
			var differing := 0
			for y in a.get_height():
				for x in a.get_width():
					if a.get_pixel(x, y) != b.get_pixel(x, y):
						differing += 1
			assert_gte(differing, MIN_DIFFERENCE, "%s and %s are too alike" % [BOSS_ICONS[i], BOSS_ICONS[j]])


func test_the_new_icons_are_sixteen_by_sixteen_with_one_idle_frame() -> void:
	for name in [&"icon_ach_star", &"icon_ach_hourglass"] + BOSS_ICONS:
		var set_data := SpriteLibrary.find(name, &"base")
		assert_not_null(set_data, String(name))
		assert_eq(set_data.frame_size, Vector2i(16, 16), String(name))
		assert_eq(set_data.frame_count(), 1, String(name))
