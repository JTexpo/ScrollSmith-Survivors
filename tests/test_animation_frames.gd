extends GutTest
## The audit that the 16c mimic bug called for: no two-frame animation in any enemy or boss sprite has identical (or almost identical) frames.
## An animation whose frames do not change is a bug (the mimic's first build had two identical move frames).
const SpriteHelpers := preload("res://tests/helpers/sprite_helpers.gd")

const MIN_DIFFERENCE := 4
const SPRITE_DIR := "res://art/sprites"


func _enemy_and_boss_sprites() -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(SPRITE_DIR):
		if file.ends_with(".sprite") and (file.begins_with("enemy_") or file.begins_with("boss_")):
			found.append(file.get_basename())
	found.sort()
	return found


func test_the_audit_finds_the_enemy_and_boss_sprites() -> void:
	var names := _enemy_and_boss_sprites()
	assert_gte(names.size(), 24, "the 7 plain, 4 forest, 3 ruins and 7 maze enemy sprites and the three bosses")
	assert_true(names.has("enemy_ruins_chaser") and names.has("enemy_maze_support") and names.has("boss_tempest_dragon") and names.has("boss_dire_minotaur"))


func test_no_two_frame_animation_has_identical_frames() -> void:
	var checked := 0
	for sprite_name in _enemy_and_boss_sprites():
		var set_data := SpriteLibrary.find(StringName(sprite_name), &"none")
		if set_data == null:
			set_data = SpriteLibrary.find(StringName(sprite_name), &"base")
		assert_not_null(set_data, sprite_name)
		if set_data == null:
			continue
		for animation in set_data.animations:
			if animation.last_frame - animation.first_frame != 1:
				continue
			checked += 1
			var difference := SpriteHelpers.frame_difference(set_data, animation.first_frame, animation.last_frame)
			assert_gte(difference, MIN_DIFFERENCE, "%s %s: the two frames differ by only %d pixels" % [sprite_name, animation.name, difference])
	assert_gt(checked, 55, "the audit really looked at the animations")
