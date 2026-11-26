extends GutTest
## Gameplay never knows achievements exist: only Main (which makes the tracker), the sound board (which plays its chime) and the
## tracker itself may name it, and no gameplay script mentions achievements at all.

const ALLOWED_TRACKER_USERS := [
	"res://scripts/progression/achievement_tracker.gd",
	"res://scripts/main/main.gd",
	"res://scripts/audio/sound_board.gd",
]
const GAMEPLAY_FOLDERS := ["components", "entities", "systems", "enemies", "spells", "crafting", "potions", "shop", "points_of_interest", "world"]


func _scripts(folder: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append("%s/%s" % [folder, file])
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_scripts("%s/%s" % [folder, sub]))
	return found


func test_only_main_and_the_sound_board_name_the_tracker() -> void:
	var checked := 0
	for path in _scripts("res://scripts"):
		checked += 1
		if ALLOWED_TRACKER_USERS.has(path) or path.get_file().begins_with("achievement"):
			continue
		assert_false(FileAccess.get_file_as_string(path).contains("AchievementTracker"), "%s names the tracker" % path)
	assert_gt(checked, 100)


func test_no_gameplay_script_mentions_achievements() -> void:
	var checked := 0
	for folder in GAMEPLAY_FOLDERS:
		for path in _scripts("res://scripts/%s" % folder):
			checked += 1
			assert_false(FileAccess.get_file_as_string(path).to_lower().contains("achievement"), "%s mentions achievements" % path)
	assert_gt(checked, 50)
