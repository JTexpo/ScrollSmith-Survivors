class_name SaveGame
extends RefCounted
## Reads and writes the PlayerProfile as one JSON file. The path is a parameter so tests never touch
## the player's real save. A bad file is renamed to `.bak` (never deleted) and a fresh profile starts.

const VERSION := 1
const DEFAULT_PATH := "user://save.json"


## Never null: a missing file is a fresh profile, and so is one that cannot be used (it is kept as .bak).
static func load_profile(path: String) -> PlayerProfile:
	if not FileAccess.file_exists(path):
		return PlayerProfile.new()
	# A JSON instance reports a parse error as a return value, where JSON.parse_string also logs an engine error.
	var json := JSON.new()
	var parsed = json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
	var profile: PlayerProfile = PlayerProfile.from_dict(parsed) if parsed is Dictionary else null
	if profile != null:
		return profile
	_keep_as_backup(path)
	return PlayerProfile.new()


## Writes a temporary file and renames it over the old one, so a crash mid-write cannot destroy the
## old save. False on any failure, leaving the old file alone.
static func save_profile(profile: PlayerProfile, path: String) -> bool:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path.get_base_dir())):
		return false
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(profile.to_dict()))
	file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path)) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return false
	return true


## New game: moves the save aside as `.bak` (replacing an older backup) so nothing is deleted and a mistake can be undone by hand.
## True when the save is gone afterwards, including when there was none.
static func erase(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	_keep_as_backup(path)
	return not FileAccess.file_exists(path)


static func _keep_as_backup(path: String) -> void:
	var backup := ProjectSettings.globalize_path(path + ".bak")
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(backup)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path), backup)
